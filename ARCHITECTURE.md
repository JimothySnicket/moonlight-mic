# Architecture

This document orients new readers to the moonlight-mic project: what it is, how the
pieces fit together, and where to look for detail.

## Overview

moonlight-mic adds client-to-host microphone passthrough to the Sunshine + Moonlight
game-streaming stack. With both ends patched, the user's voice is captured on the
Moonlight client and surfaced on the host as a virtual recording device named
"Microphone (Steam Streaming Microphone)". Any host application that reads from that
device — Discord, OBS, in-game voice chat, `mmsys.cpl` — sees the audio as if a real
microphone were plugged into the host PC.

The feature does not exist anywhere in the open-source Sunshine/Moonlight stack
today. The commercial Parsec product ships microphone passthrough; the open-source
ecosystem does not. This project closes that gap.

**Non-goals:**

- Two-way (host-to-client) microphone audio is out of scope. Host audio already
  reaches the client via Moonlight's existing audio stream.
- Mid-stream device hot-swap is not supported; the capture device is the OS default
  at session start.
- Host platforms other than Windows are not supported in v0.1.0. Linux and macOS
  hosts compile cleanly but the receive path is a stub that logs once and discards
  decoded PCM. See "Cross-platform support matrix" below.
- New pairing flows, ports, sockets, or authentication mechanisms are explicitly
  out of scope. The mic stream rides the existing authenticated control tunnel.

## Repository layout

The umbrella repository binds three component forks as git submodules. Each
submodule carries the actual code changes; the umbrella carries the design
specification, build scripts, release tooling, and cross-cutting documentation.

```
moonlight-mic/                        umbrella repository (this repo)
├── ARCHITECTURE.md                   you are here
├── CONTRIBUTING.md                   build and contribution guide
├── README.md                         user-facing project overview
├── LICENSE                           MIT (umbrella content only)
├── docs/
│   ├── design/wire-format.md         canonical protocol specification
│   ├── using/setup.md                end-to-end user setup
│   ├── using/troubleshooting.md      common issues and fixes
│   └── building/                     per-fork build instructions
├── scripts/                          build orchestration and helpers
├── moonlight-common-c/               submodule (BSD-3-Clause)
├── moonlight-qt/                     submodule (GPLv3)
└── Apollo/                           submodule (GPLv3)
```

Each submodule is pinned to a specific commit on its `moonlight-mic` feature
branch. The umbrella's `main` branch advances by submodule pointer bumps as
upstream work lands.

## Component forks

### moonlight-common-c

- **Role:** the protocol layer shared between Moonlight client implementations.
  Mic-specific work lives here as the wire-format constants, the `LiSendMicAudioFrame`
  public function, the SDP capability bit, and a thin send-side helper that wraps
  the existing ENet control-stream funnel.
- **Upstream:** [moonlight-stream/moonlight-common-c](https://github.com/moonlight-stream/moonlight-common-c)
- **Fork:** [JimothySnicket/moonlight-common-c](https://github.com/JimothySnicket/moonlight-common-c) on the `moonlight-mic` branch
- **License:** BSD-3-Clause (unchanged from upstream)
- **Mic-specific additions:** `Mic.h`, `Mic.c`, an SDP feature-flag bit, a
  `sendMicPacketOnControlStream` helper in `ControlStream.c`, and unit-test
  coverage of the parser and capability gate.

### moonlight-qt

- **Role:** the Qt client. Mic-specific work covers SDL2 capture, the Opus
  encoder, the user-facing toggle in Audio settings, and a `MicAudioSender` class
  that pumps captured frames into `LiSendMicAudioFrame` at the streaming session
  layer.
- **Upstream:** [moonlight-stream/moonlight-qt](https://github.com/moonlight-stream/moonlight-qt)
- **Fork:** [JimothySnicket/moonlight-qt](https://github.com/JimothySnicket/moonlight-qt) on the `moonlight-mic` branch
- **License:** GPLv3 (unchanged from upstream)
- **Mic-specific additions:** mic toggle in `SettingsView` and `StreamingPreferences`,
  `MicAudioSender` class, SDL2 audio-input bring-up, Opus encoder configuration, and
  QtTest coverage of the sender.

### Apollo

- **Role:** the host. Apollo is a community fork of Sunshine maintained by
  ClassicOldSong; this project adds packet receive, capability negotiation, Opus
  decode, and the WASAPI render path that feeds the Steam Streaming Microphone
  virtual device.
- **Upstream:** [ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo)
  (a fork of [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine))
- **Fork:** [JimothySnicket/Apollo](https://github.com/JimothySnicket/Apollo) on the `moonlight-mic` branch
- **License:** GPLv3 (unchanged from upstream)
- **Mic-specific additions:** packet dispatch in `stream.cpp`, `mic_endpoint_t`
  WASAPI render code (Windows only), capability advertisement in
  `platform/windows/input.cpp`, parser extracted to `mic_parser.h`, and GoogleTest
  coverage in `tests/unit/test_mic.cpp`.

## Why submodules

Three considerations drove the choice of git submodules over a monorepo or loose
documentation:

1. **Single source of truth for fork SHAs.** The umbrella pins each submodule to a
   specific commit. A user who clones the umbrella with `--recurse-submodules` gets
   exactly the build the maintainers tested, with no version-skew window between
   the three pieces.
2. **Coherent download story.** Mic passthrough only works when the three pieces
   are in sync. Submodules let the umbrella ship a single version that names the
   tested combination, rather than asking users to pick three compatible commits
   themselves.
3. **Each fork keeps a clean history.** Submodules let each upstream fork retain
   a linear feature branch suitable for an upstream pull request. The umbrella
   never rewrites submodule history.

## Data flow

```
   Moonlight Qt client (cross-platform)              Apollo host (Windows in v0.1.0)
   ┌───────────────────────────┐                     ┌─────────────────────────────┐
   │  SDL2 default capture     │                     │  control-stream dispatcher  │
   │  ↓ 16-bit PCM @ 48 kHz    │                     │  ↓ 0x5510 packet handler    │
   │  Opus encoder (VOIP)      │                     │  validate header, decode    │
   │  ↓ 20 ms frames           │                     │  ↓ 960-sample PCM frame     │
   │  MicAudioSender           │                     │  WASAPI render endpoint     │
   │  ↓ LiSendMicAudioFrame    │                     │  ↓ shared-mode write        │
   │  control-stream send      │  encrypted control  │  Steam Streaming Microphone │
   │  ↓ AES-GCM encrypt        │  tunnel (existing)  │  (virtual recording device) │
   │  ENet UNSEQUENCED ────────┼─── 0x5510 ─────────→│  ↓ Discord / OBS / game     │
   └───────────────────────────┘                     └─────────────────────────────┘
```

Each frame is 20 ms (960 samples at 48 kHz mono), fixed at the spec level. The
encoder runs at 24 kbps CBR with `OPUS_APPLICATION_VOIP`. Bandwidth is negligible:
roughly 50 packets per second of about 70 bytes each, well under 1% of a typical
streaming session's control-stream load.

## Wire format

Each mic packet rides the existing per-session AES-GCM control tunnel as a
`0x5510` packet. Inside the encrypted envelope the layout is an 8-byte big-endian
mic frame header (sequence number, Opus frame length, sample-count timestamp)
followed by the Opus payload bytes. Capability negotiation uses two SDP feature
flags — one advertised by the host, one by the client; both must be present before
either side does any mic-specific work. The full byte-level specification, packet
type allocation, security model, and mixed-version behaviour are documented in
[`docs/design/wire-format.md`](docs/design/wire-format.md), which is the canonical
source of truth for the protocol.

## Capability negotiation

Capability is advertised on both sides and gated on both sides:

- **Host advertises** `SS_FF_MIC_INPUT` (`0x0100`) in `x-ss-general.featureFlags`
  when running on Windows. Other platforms compile but do not advertise; see the
  support matrix below.
- **Client advertises** `ML_FF_MIC_INPUT` (`0x04`) in `x-ml-general.featureFlags`
  unconditionally when paired with a Sunshine or Apollo host. The user-facing mic
  toggle controls whether capture starts, not whether capability is advertised.
- **Client gate:** `LiSendMicAudioFrame` is a silent no-op if the host's flag is
  absent. The client never emits `0x5510` packets toward a stock host.
- **Host gate:** the dispatch handler exits immediately if the client's flag is
  absent at session-allocation time. No decoder, WASAPI endpoint, or COM activation
  is ever set up for a stock client.

Both gates are independent. A patched client paired with a stock host emits no mic
packets; a patched host paired with a stock client allocates no mic resources.
Neither end errors and neither blocks the existing streaming session.

## Cross-platform support matrix

| Side | Windows | Linux | macOS |
|------|---------|-------|-------|
| **Client** (Moonlight Qt) | supported | supported | supported |
| **Host** (Apollo) | supported | stub: compiles, advertises no capability, decodes nothing | stub: compiles, advertises no capability, decodes nothing |

The client side captures via SDL2 and is fully cross-platform — Windows, Linux,
and macOS clients are first-class targets. The host side currently depends on
WASAPI and the Steam audio driver integration that Apollo bundles on Windows;
Linux (PipeWire) and macOS (CoreAudio) host paths are clearly delimited stubs in
`stream.cpp` and are tracked as future work.

## Relationship to upstreams

This is a coordinated proposal across three projects, not a single fork. Each
submodule's `moonlight-mic` branch is sized to be a self-contained, reviewable
pull request against its own upstream:

- `moonlight-common-c/moonlight-mic` is a candidate PR against
  `moonlight-stream/moonlight-common-c` master.
- `moonlight-qt/moonlight-mic` is a candidate PR against
  `moonlight-stream/moonlight-qt` master, dependent on the
  `moonlight-common-c` PR landing first.
- `Apollo/moonlight-mic` is a candidate PR against `ClassicOldSong/Apollo`
  master, dependent on the `moonlight-common-c` PR landing first.

The umbrella repository exists to give all three pieces a single coherent story —
shared design spec, shared user docs, shared release artefacts — while each fork
keeps the clean linear history that an upstream review needs. The umbrella is
not itself a candidate for upstream merge; it is the project page.

## Acknowledgements

This project is built on top of work by:

- **Cameron Gutman ([cgutman](https://github.com/cgutman))** and the
  [moonlight-stream](https://github.com/moonlight-stream) project, who maintain
  `moonlight-common-c` and `moonlight-qt`. The mic feature lives inside the
  protocol and client architecture they designed; every patch in
  `moonlight-common-c` and `moonlight-qt` here is a thin addition on top of their
  existing structure.
- **[ClassicOldSong](https://github.com/ClassicOldSong)**, who maintains
  [Apollo](https://github.com/ClassicOldSong/Apollo), the community fork of
  Sunshine that includes the Steam audio driver integration the host receive
  path depends on. The mic receive code in `Apollo/src/stream.cpp` extends the
  control-stream dispatch pattern Apollo already uses; the WASAPI render code
  feeds the virtual device Apollo's Steam audio driver provides.
- **[LizardByte](https://github.com/LizardByte)**, who maintain
  [Sunshine](https://github.com/LizardByte/Sunshine), the upstream host-side
  stack from which Apollo was forked. Sunshine's control-stream design,
  encrypted-tunnel framing, and overall architecture are the foundation the
  receive path is built on.

The Steam Streaming Microphone driver and integration originate from LizardByte's
Sunshine and reach this project via Apollo.
