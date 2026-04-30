# wire-format.md — moonlight-mic Client-to-Host Microphone Stream Protocol

Version: 1.0 (rewrite; reconciled with P1–P3 / H1–H4 implementation)
Scope: JimothySnicket/moonlight-common-c + JimothySnicket/Apollo forks. Upstream PR readiness
is an explicit goal; this document is written to be shared with Apollo's ClassicOldSong and
moonlight-stream's cgutman.

> **POC relationship.** The POC design document at `Z:\Dev\sunshine-mic\WIRE.md` (version 0.1,
> T6 design draft) was the source of truth during initial implementation. Three details diverged
> between POC design and the rewrite; they are documented under each section where they appear.

---

## 1. Overview

The moonlight-mic extension adds a client-to-host microphone audio stream to the Moonlight
protocol so the user's voice reaches the host PC during a gaming session. The client (patched
Moonlight Qt) captures mic audio via SDL2, encodes it to mono Opus at 48 kHz with a fixed 20 ms
frame size, and sends each encoded frame to the host as a single application-layer packet inside
the host's existing per-session AES-GCM encrypted control tunnel.

The host (patched Apollo) decrypts the packet, validates header fields, decodes the Opus frame,
and pushes the resulting PCM into the "Microphone (Steam Streaming Microphone)" render endpoint
that Apollo bundles via the Steam audio driver. On Windows this gives any host application that
selects Steam Streaming Microphone as its input device real-time access to the client's voice.
On Linux and macOS, Apollo compiles clean but the render path is not yet implemented; a one-shot
warning is logged and the decoded PCM is discarded.

The extension deliberately avoids new sockets, ports, pairing flows, and authentication. It rides
the same authenticated session that already protects video, host-to-client audio, and input. Mic
traffic is gated on a two-sided SDP capability handshake so stock peers in either direction are
never affected.

---

## 2. Packet header

### 2.1 Outer control-stream framing (pre-existing, not new)

Mic packets use the same outer framing as all other Sunshine/Apollo control-stream extension
messages. This section lists it for byte-level completeness; none of these structures are new.

Every control-stream message travels inside `NVCTL_ENCRYPTED_PACKET_HEADER`
(`moonlight-common-c/src/ControlStream.c:26-32`) which wraps an inner
`NVCTL_ENET_PACKET_HEADER_V2` (`ControlStream.c:20-23`):

| Offset | Size | Field | Notes |
|--------|------|-------|-------|
| 0 | 2 | `encryptedHeaderType` | Always `0x0001` LE — selects the encrypted variant |
| 2 | 2 | `length` | Payload length excluding these first 4 bytes |
| 4 | 4 | `seq` | Monotonic AES-GCM IV counter |
| 8 | 16 | AES-GCM tag | Written by `encryptControlMessage()` |
| 24 | 4 | Inner V2 header | `type` (LE16) + `payloadLength` (LE16) |
| 28 | N | Mic frame header + Opus payload | See section 2.2 |

Inner V2 header fields for mic packets:

| Field | Value |
|-------|-------|
| `type` | `0x5510` LE |
| `payloadLength` | `8 + opusFrameLength` LE |

### 2.2 Packet type allocation

The Sunshine extension packet-type space lives in the `0x55xx` range. Allocated values:

| Value | Purpose | Source |
|-------|---------|--------|
| `0x5500` | Rumble triggers | `ControlStream.c:213` |
| `0x5501` | Set motion event | `ControlStream.c:214` |
| `0x5502` | Set RGB LED / `SS_FRAME_FEC_PTYPE` | `ControlStream.c:215`, `Video.h:57` |
| `0x5503` | Set adaptive triggers | `ControlStream.c:216` |
| `0x5504`–`0x550F` | (gap; reserved for upstream Sunshine additions) | |
| `0x5510` | **`SS_MIC_OPUS_PTYPE` — client-to-host mic audio** | `moonlight-common-c/src/Mic.h` |

The 12-value gap between `0x5503` and `0x5510` is intentional — it leaves room for upstream
Sunshine extensions without requiring renumbering.

### 2.3 Mic frame header — `SS_MIC_FRAME_HEADER`

This is the only new on-the-wire structure. It lives immediately after the inner V2 header and
immediately before the Opus payload bytes. All multi-byte fields are **big-endian**, matching the
RTP audio convention used in the host-to-client direction (`RtpAudioQueue.c:18-19`,
`AudioStream.c`).

```c
#pragma pack(push, 1)
typedef struct _SS_MIC_FRAME_HEADER {
    uint16_t sequenceNumber;   // BE16; monotonic, wraps at 65535; first packet = 0
    uint16_t opusFrameLength;  // BE16; byte length of the Opus payload following this struct
    uint32_t timestampSamples; // BE32; 48 kHz sample count since first frame this session
} SS_MIC_FRAME_HEADER, *PSS_MIC_FRAME_HEADER;
#pragma pack(pop)
```

Source: `moonlight-common-c/src/Mic.h`

Byte layout (all big-endian):

```
Offset  Size  Field
------  ----  -----
     0     2  sequenceNumber   (BE16)
     2     2  opusFrameLength  (BE16)
     4     4  timestampSamples (BE32)
     8     N  Opus frame bytes (N == opusFrameLength)
```

Field semantics:

| Field | Semantics |
|-------|-----------|
| `sequenceNumber` | Increments by 1 per packet; wraps at 65535. The host uses this for drop detection, mirroring `lastSeq` handling in `AudioStream.c:172-176`. Caller (Moonlight Qt's `MicAudioSender`) owns and increments the counter; it is passed into `LiSendMicAudioFrame` as a parameter. |
| `opusFrameLength` | Byte count of the Opus frame that follows. Host MUST validate `sizeof(SS_MIC_FRAME_HEADER) + opusFrameLength == inner_payloadLength` and reject the packet if the check fails. |
| `timestampSamples` | 48 kHz sample count since the first mic frame in this session; increments by 960 per packet (48000 Hz × 0.020 s). Derived internally by `LiSendMicAudioFrame` as `seqNumber * 960` — callers do not need to track it separately. |

**Header size:** 8 bytes, verified by a compile-time assertion in both `Mic.h` (C typedef trick) and
`stream.cpp` (`static_assert`).

> **POC reconciliation — `seqNumber` parameter:** POC WIRE.md section 4 sketched the public API
> as `LiSendMicAudioFrame(opusData, opusLen)` without an explicit sequence-number argument. The
> rewrite added `uint16_t seqNumber` as a third parameter so the caller (Moonlight Qt's
> `MicAudioSender`) owns the counter and `LiSendMicAudioFrame` is a stateless dispatch function.
> This is the actual shipped signature.

---

## 3. Opus payload framing

Fixed parameters enforced on both sides:

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Sample rate | 48000 Hz | Matches `NormalQualityOpusConfig.sampleRate` and `HighQualityOpusConfig.sampleRate` in `RtspConnection.c:754`. No resampling needed on host before pushing to Steam virtual mic. |
| Channels | 1 (mono) | Speech capture. The host-to-client path uses `OPUS_MULTISTREAM_CONFIGURATION` for surround; the mic stream is a single mono Opus stream. |
| Frame duration | 20 ms | Yields 960 samples per frame (48000 × 0.020). Fixed by the wire spec; the host always passes 960 to `opus_decode` regardless of header values. |
| Encoder application | `OPUS_APPLICATION_VOIP` | Speech-tuned. `OPUS_APPLICATION_AUDIO + OPUS_SET_DTX` was tested during the POC and hit a crash whose root cause was never isolated; `OPUS_APPLICATION_VOIP` is the stable default. |
| Bitrate target | 24000 bps CBR | Comfortable for VOIP-grade speech; small relative to control-stream budget (~3 KB/s, 50 packets/s of ~70 bytes each). |
| FEC | Off | The control stream is reliable (ENet). Opus inband FEC is for lossy transports. |
| DTX | On (encoder-side) | Saves bandwidth during silence. The host treats sequence-number gaps as silence (no PLC call needed — the WASAPI buffer simply isn't written during gaps). |
| Max encoded payload | 1500 bytes (`LI_MIC_MAX_OPUS_BYTES`) | Validated in `LiSendMicAudioFrame`; any caller-supplied length above this is rejected with error code −2 before a packet is built. |

**Frame size is fixed at the spec level.** The host calls `opus_decode` with `MIC_SAMPLES_PER_FRAME = 960` as the `frame_size` argument, not with any value parsed from the packet header. This is defensive: a malformed `opusFrameLength` cannot cause `opus_decode` to overshoot its output buffer.

---

## 4. Channel selection

Mic packets ride the existing encrypted control stream on `CTRL_CHANNEL_GENERIC`
(`Limelight-internal.h:57`). They do not open a new UDP socket and do not create a new
RTP-style stream.

### Justification

1. **Precedent within the control stream.** `SS_FRAME_FEC_PTYPE` (0x5502) is sent client-to-host
   on `CTRL_CHANNEL_GENERIC` with `ENET_PACKET_FLAG_UNSEQUENCED` as a periodic, lightweight,
   sequenced data stream (`ControlStream.c:1408-1418`). Mic follows the same pattern.

2. **New RTP socket would require RTSP SETUP changes.** The existing audio port is negotiated via
   `streamid=audio` (`RtspConnection.c:1175-1196`). Adding `streamid=mic` would break the
   "stock-peer must not crash" requirement — stock Apollo would error the RTSP handshake or
   the mic packets would arrive at an unknown port.

3. **Bandwidth is negligible.** At 24 kbps (50 packets/s of ~70 bytes each) the mic stream adds
   less than 1% of a typical streaming session's control-stream load.

4. **AES-GCM is already in place.** Control-stream packets are encrypted per-packet at no
   additional setup cost to the mic feature.

### Reliability flag

Mic packets are sent as `ENET_PACKET_FLAG_UNSEQUENCED` (no reliable retransmit), matching the
FEC status path. A re-sent voice frame arriving 200 ms late is worse than silence.

### Send-side funnel

> **POC reconciliation — `sendMessageEnet` funnel:** POC WIRE.md section 4 noted "it does NOT
> funnel through `sendInputPacketOnControlStream()`" but described the internal call as going
> directly to `sendMessageEnet`. The rewrite formalises this: `LiSendMicAudioFrame` calls a new
> internal helper `sendMicPacketOnControlStream` (in `ControlStream.c`) which wraps
> `sendMessageEnet` directly. `sendInputPacketOnControlStream` (`ControlStream.c:1693`) is
> not used — it is hardcoded to `packetTypes[IDX_INPUT_DATA]` and cannot dispatch a custom packet
> type. The helper name `sendMicPacketOnControlStream` makes the separation explicit.

---

## 5. Crypto interaction

Mic packets sit inside the existing encrypted control tunnel. They are not encrypted separately
and are not sent in the clear.

Specifically:

1. The plaintext built by `LiSendMicAudioFrame` is the inner-V2 header (`type=0x5510`,
   `payloadLength`) followed by the 8-byte `SS_MIC_FRAME_HEADER` followed by the Opus bytes.

2. This plaintext is passed to `sendMicPacketOnControlStream` → `sendMessageEnet` →
   `encryptControlMessage` (`ControlStream.c:548-591`).

3. `encryptControlMessage` AES-GCM-encrypts the payload using `StreamConfig.remoteInputAesKey`
   (the per-session key established during pairing) with a 12-byte IV that includes the monotonic
   `seq` counter. Mic packets are client-originated control packets, so their IV uses the existing
   `'C','C'` tag bytes at offsets 10-11. No new IV tag is introduced for mic.

4. The AES-GCM tag (16 bytes) is written into the encrypted-packet header; any tampering or
   truncation is rejected by the host's `decryptControlMessageToV1` (`ControlStream.c:594-663`).

5. **`SS_ENC_AUDIO` is unrelated.** That flag (`Limelight-internal.h:50`) controls encryption of
   the host-to-client RTP audio stream. The mic stream rides the control channel, which is
   encrypted whenever `SS_ENC_CONTROL_V2` is enabled — in practice always, on any modern
   Sunshine/Apollo.

6. **No new key material.** The existing per-session `remoteInputAesKey` and `remoteInputAesIv`
   are reused.

**Replay protection** comes free from the monotonic `seq` field in `NVCTL_ENCRYPTED_PACKET_HEADER`
(`ControlStream.c:32`), used as IV input. The host's `decryptionCtx` fails to decrypt any IV
reuse.

---

## 6. Capability negotiation

The client MUST NOT send `0x5510` packets unless the host has advertised mic-input support.
The host MUST NOT allocate decode/render resources unless the client has advertised mic
capability. Both gates are enforced independently.

### 6.1 Host advertises support

Apollo adds a new bit to `x-ss-general.featureFlags`, parsed by the client in
`RtspConnection.c:1145-1147`:

```c
/* moonlight-common-c/src/Mic.h */
#define SS_FF_MIC_INPUT 0x0100
```

Bit value confirmed free against existing `LI_FF_*` allocations:
- `0x01` = `LI_FF_PEN_TOUCH_EVENTS`
- `0x02` = `LI_FF_CONTROLLER_TOUCH_EVENTS`
- `0x0100` = **`SS_FF_MIC_INPUT`** (new; Windows host only in v0.1.0)

Apollo's `get_capabilities()` (`src/platform/windows/input.cpp`) sets this bit on Windows.
It is NOT set on Linux or macOS — those platforms do not yet have a render path, so advertising
would mislead capable clients into sending mic audio that Apollo cannot route.

The Apollo `platform_caps::mic_input` constant (`src/platform/common.h`) is verified equal to
`SS_FF_MIC_INPUT` via a `static_assert` in `stream.cpp`:

```cpp
/* Apollo/src/platform/common.h */
namespace platform_caps {
    constexpr caps_t mic_input = 0x0100;
}

/* Apollo/src/stream.cpp */
static_assert(platf::platform_caps::mic_input == SS_FF_MIC_INPUT, ...);
```

### 6.2 Client advertises intent

The client adds a new bit to `x-ml-general.featureFlags` (`SdpGenerator.c:274`):

```c
/* moonlight-common-c/src/Mic.h */
#define ML_FF_MIC_INPUT 0x04
```

Bit value confirmed free against existing `ML_FF_*` allocations:
- `0x01` = `ML_FF_FEC_STATUS` (`Limelight-internal.h:88`)
- `0x02` = `ML_FF_SESSION_ID_V1` (`Limelight-internal.h:89`)
- `0x04` = **`ML_FF_MIC_INPUT`** (new)

The bit is emitted unconditionally when the client identifies a Sunshine/Apollo host
(`IS_SUNSHINE()`). Even if the user has the mic toggle OFF, the bit is emitted — the toggle
controls whether capture starts, not whether capability is advertised.

### 6.3 Gate enforcement

**Client side** — `LiSendMicAudioFrame` (`moonlight-common-c/src/Mic.c`):

```c
if (!(SunshineFeatureFlags & SS_FF_MIC_INPUT)) {
    return 0;  // silent no-op; 0x5510 never sent to stock host
}
```

The Moonlight Qt session manager (`C3`) additionally checks both the host flag and the user
toggle before starting `MicAudioSender`, so `LiSendMicAudioFrame` is not called at all when
either gate is false. The check inside `LiSendMicAudioFrame` is belt-and-braces.

**Host side** — `stream.cpp:1504`:

```cpp
if (!session->mic.client_advertised) {
    // one-shot debug log guarded by warn_once_no_capability
    return;
}
```

`session->mic.client_advertised` is set once at `session::alloc()` time from
`config.mlFeatureFlags & ML_FF_MIC_INPUT`. When false, the dispatch handler returns immediately
without allocating decoder or WASAPI resources. A one-shot debug log fires on the first ignored
packet; subsequent ignored packets from the same session are silent to avoid log spam.

---

## 7. Mixed-version behaviour

### 7.1 Patched Moonlight + stock Apollo/Sunshine (host has no mic support)

Stock host does not advertise `SS_FF_MIC_INPUT`. The client's gate in `LiSendMicAudioFrame`
evaluates false → no `0x5510` packets are ever sent. Stock host is unaffected.

If a `0x5510` packet were somehow sent to stock Apollo, the host-side control-stream dispatcher
(`src/stream.cpp:1096` registration site) simply has no handler registered for the unknown type
and discards it — confirmed by Apollo's `map`/`call` dispatch pattern (unknown types are not
mapped, not acted on, and not crashed on).

### 7.2 Patched Apollo + stock Moonlight (client has no mic capability)

Stock Moonlight does not advertise `ML_FF_MIC_INPUT`. At `session::alloc()`, Apollo sets
`session->mic.client_advertised = false`. No OpusDecoder is allocated. No WASAPI endpoint is
opened. The `0x5510` dispatch handler fires only if a stock client were somehow to send the
packet; in that case the early gate at line 1504 drops it silently with one debug log.

### 7.3 Both stock

No `0x5510` packets exist; behaviour is identical to unpatched Apollo + unpatched Moonlight.

### 7.4 Both patched, host Windows

Both peers advertise their flags. Moonlight Qt's `MicAudioSender` starts at session begin,
captures 20 ms frames, calls `LiSendMicAudioFrame`. Apollo allocates an OpusDecoder at
`session::alloc()`, opens the Steam Streaming Microphone render endpoint lazily on the first
`0x5510` packet arrival, and routes decoded PCM into the WASAPI buffer. Mic audio is audible
in any host application that selects "Microphone (Steam Streaming Microphone)" as its input.

### 7.5 Both patched, host Linux or macOS (H4 stubs)

Apollo's Linux/macOS `get_capabilities()` does not set `platform_caps::mic_input`, so the host
does not advertise `SS_FF_MIC_INPUT`. A compliant client never sends `0x5510`. If an
unconditional or buggy client does send the packet anyway, it is accepted (the `client_advertised`
gate passes if the client advertised, but the platform `#ifdef _WIN32` else branch fires, logs
one warning per session, and discards the decoded PCM.

> **POC reconciliation — buffer-too-large policy:** POC WIRE.md deferred T11's exact backpressure
> policy. The rewrite's H2 implementation uses `IAudioClient::GetCurrentPadding` before each
> `GetBuffer` call. If the available frames are fewer than the decoded frame count (960), the
> frame is dropped at debug log level rather than calling `GetBuffer` and getting
> `AUDCLNT_E_BUFFER_TOO_LARGE`. If `GetCurrentPadding` itself fails, the frame is dropped with
> a warning. If a race between `GetCurrentPadding` and `GetBuffer` still produces
> `AUDCLNT_E_BUFFER_TOO_LARGE`, that specific HRESULT is caught and logged at debug level. The
> streaming session is never torn down by a WASAPI render failure.

---

## 8. Implementation references

The following files constitute the complete implementation. Line ranges are indicative; they
will drift as the codebase evolves.

### moonlight-common-c (client-side protocol layer)

| File | What it contains |
|------|-----------------|
| `moonlight-common-c/src/Mic.h` | `SS_MIC_OPUS_PTYPE = 0x5510`, `SS_FF_MIC_INPUT = 0x0100`, `ML_FF_MIC_INPUT = 0x04`, `SS_MIC_FRAME_HEADER` struct with compile-time size assertion |
| `moonlight-common-c/src/Mic.c` | `LiSendMicAudioFrame(opusData, opusLen, seqNumber)` — capability gate, input validation, header construction, dispatch via `sendMicPacketOnControlStream` |
| `moonlight-common-c/src/SdpGenerator.c` (around line 274) | `ML_FF_MIC_INPUT` bit ORed into `x-ml-general.featureFlags` for Sunshine/Apollo hosts |
| `moonlight-common-c/src/ControlStream.c` (around line 1693) | `sendMicPacketOnControlStream` helper wrapping `sendMessageEnet` with `ENET_PACKET_FLAG_UNSEQUENCED` |

### Apollo (host-side decode and render)

| File | What it contains |
|------|-----------------|
| `Apollo/src/stream.cpp` (around line 266–305) | `SS_MIC_OPUS_PTYPE`, `SS_FF_MIC_INPUT`, `ML_FF_MIC_INPUT` constants; `mic_frame_header_t` struct with `static_assert`; `opus_decoder_t` RAII typedef |
| `Apollo/src/stream.cpp` (around line 322–654) | `mic_endpoint_t` struct, `open_steam_mic_endpoint()` (Windows only) — enumerates render endpoints, matches "Steam Streaming Microphone" by friendly-name substring, negotiates format via `GetMixFormat`, primes buffer with silence, calls `Start()` |
| `Apollo/src/stream.cpp` (around line 1494–1682) | `server->map(packetTypes[IDX_MIC_OPUS_DATA], ...)` — the dispatch handler: capability gate, header validation, `opus_decode`, `GetCurrentPadding` backpressure, WASAPI write, H4 Linux/macOS stub |
| `Apollo/src/stream.cpp` (around line 2850–2877) | `session::alloc()` — reads `config.mlFeatureFlags & ML_FF_MIC_INPUT`, conditionally calls `opus_decoder_create(48000, 1, ...)` |
| `Apollo/src/platform/common.h` (around line 280–286) | `platform_caps::mic_input = 0x0100` with comment requiring sync with `SS_FF_MIC_INPUT` |
| `Apollo/src/platform/windows/input.cpp` (around line 1780–1784) | `platf::get_capabilities()` sets `platform_caps::mic_input` on Windows |

---

## 9. Security considerations

This section consolidates the security properties of the extension for reviewers evaluating a
potential upstream PR. The design goal is: a user running patched Apollo + patched Moonlight Qt
is at most as exposed as a user running stock Apollo + stock Moonlight Qt. New attack surface is
introduced only at two bounded points: the host-side packet parser and the WASAPI write path.

### 9.1 Authentication and encryption

The mic stream rides the existing per-session AES-GCM control tunnel established by Sunshine/
Apollo's pairing flow. There is no new pairing protocol, no new key material, no new IV scheme,
no new sockets, and no new ports. Replay protection comes free from the monotonic IV counter
already in `NVCTL_ENCRYPTED_PACKET_HEADER`'s `seq` field (`ControlStream.c:32`). Only a client
that has successfully completed the pairing handshake can produce packets that decrypt correctly
on the host.

### 9.2 Input validation at the trust boundary

Being inside an authenticated tunnel does not mean the source is trusted to send well-formed
packets. The host-side dispatch handler validates every field of `SS_MIC_FRAME_HEADER` before
passing the payload to the Opus decoder:

- **Runt check:** `payload.size() < sizeof(mic_frame_header_t)` → warning log + drop.
- **`opusFrameLength` bounds:** `< 1` or `> MIC_PACKET_MTU - sizeof(mic_frame_header_t)` → warning + drop.
- **Length consistency:** `sizeof(mic_frame_header_t) + opusFrameLength != payload.size()` → warning + drop.
- **Decoder null check:** if `opus_decoder_create` failed at session start, warn + drop.

After validation, `opus_decode` is called with the wire-spec frame size (`MIC_SAMPLES_PER_FRAME = 960`)
as the `frame_size` argument — never with any value parsed from the packet. This prevents a
crafted `opusFrameLength` from influencing the amount of memory `opus_decode` writes to its
output buffer.

### 9.3 Capability-gate enforcement (resource allocation)

Resource allocation (OpusDecoder, WASAPI endpoint) is gated on the two-sided SDP handshake
described in section 6. When `session->mic.client_advertised` is false:

- No OpusDecoder is allocated at `session::alloc()`.
- No WASAPI endpoint enumeration or COM activation occurs.
- The `0x5510` dispatch handler exits immediately on the first packet.
- A one-shot debug log fires; subsequent packets from the same session are silent (no log spam
  that could be used to infer session activity).

A paired client that advertises `ML_FF_MIC_INPUT = 0x04` is trusted to be a patched Moonlight
Qt. That client cannot allocate unbounded resources on the host: one OpusDecoder and one WASAPI
render endpoint per session are the fixed bounds.

### 9.4 No voice data in logs or error output

The host logs sequence numbers, Opus frame lengths, and decoded sample counts at debug level.
It never logs PCM sample values, Opus frame bytes, or any representation of the audio content.
WASAPI error paths log HRESULT values only. This prevents voice audio from appearing in log
files, crash dumps, or support bundles.

The POC carried a host-side `mic-tap.pcm` file writer for diagnostics. That code does not exist
in the rewrite.

### 9.5 Resource exhaustion bounds

Mic packets arrive at at most 50 packets per second, fixed by the 20 ms frame cadence. A paired
client cannot increase this rate without the server ignoring the extra packets (the ENet
`UNSEQUENCED` flag means the channel cannot be used as a congestion lever). The WASAPI render
buffer is bounded by its allocated frame count (200 ms); frames that would overflow it are
dropped by the `GetCurrentPadding` pre-check rather than queued. Opus decoder state is O(1)
memory allocated once at session start.

### 9.6 No new dependencies

The implementation reuses libopus (already bundled in Apollo and moonlight-common-c builds),
SDL2 (already bundled in Moonlight Qt), ENet (already bundled), and WASAPI/CoreAudio/PipeWire
(OS-level platform APIs). No new third-party libraries are introduced.

### 9.7 Threat model summary

New attack surface reachable only by a paired client over an AES-GCM-authenticated tunnel:

| Surface | Bound |
|---------|-------|
| Host-side `SS_MIC_FRAME_HEADER` parser | Validated before any decoding; see 9.2 |
| `opus_decode` call | Frame size fixed at 960 by spec; not taken from packet |
| WASAPI `GetBuffer` / `ReleaseBuffer` | Gated by `GetCurrentPadding` pre-check; failures non-fatal |

A malicious paired client cannot crash Apollo via the mic path because all three surfaces are
bounded and WASAPI failures are caught and logged rather than propagated as exceptions.

---

## 10. Open questions and future work

**Linux and macOS host audio routing.** `Apollo/src/stream.cpp`'s `#ifdef _WIN32` / `#else`
blocks leave a clearly delimited stub for non-Windows routing. The natural implementation
targets PipeWire (modern Linux) with a PulseAudio fallback for broader compatibility; CoreAudio
for macOS. Once implemented, the platform's `get_capabilities()` would set `platform_caps::mic_input`
and the host would advertise `SS_FF_MIC_INPUT` to clients.

**Encoder configuration sweet spot.** The POC hit a crash with
`OPUS_APPLICATION_AUDIO + OPUS_SET_DTX(0)` at 64 kbps; root cause was never isolated.
`OPUS_APPLICATION_VOIP` at 24 kbps is the stable default in v0.1.0. A standalone Opus encoder
harness would be the cleanest way to isolate the failure mode and test higher-quality configs.

**Bit-space coordination with upstream Sunshine (LizardByte).** `SS_FF_MIC_INPUT = 0x0100`
was chosen against the `LI_FF_*` allocations visible at rewrite time. If LizardByte/Sunshine
ever adopts mic input independently, a bit-value collision is possible. Coordinating the
allocation is a cheap ask — an issue comment or PR comment to LizardByte before any upstream PR
would be sufficient to reserve the space.

**Mid-session toggle.** The mic toggle is read at session start. Toggling it mid-stream is not
acted on until the next session. An "explicit mic-off" control packet is not in scope; the
current behaviour (stop sending, host WASAPI buffer drains, silence) is correct and simple.

**Mic device selection.** Moonlight Qt uses SDL2's default recording device. A UI to pick the
device is a natural future addition to the Audio Settings page.

For the current project state (completed tasks, deferred work, and community phase plans) see
`C:\Users\Jamie\SecondBrain\projects\moonlight-mic.md`.

---

*For user-facing setup instructions see [`docs/using/setup.md`](../using/setup.md).*
