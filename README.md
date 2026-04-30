# moonlight-mic

Microphone passthrough for the Sunshine + Moonlight game streaming stack — talk into your mic on the Moonlight client, hear yourself on the Apollo host.

> **Status: in active development.** Not yet released. The proof-of-concept demonstrated end-to-end mic audio working through the [Apollo](https://github.com/ClassicOldSong/Apollo) host (a Sunshine fork) with a modified Moonlight Qt client. This umbrella project is the clean rewrite targeting public release.

## What this is

A modified Moonlight Qt client + a modified Apollo host that together let you stream microphone audio from the streaming client to the host PC. On the host, the audio shows up as **"Microphone (Steam Streaming Microphone)"** — capture it with Discord, OBS, or any voice chat app, and you'll be heard as if you were sitting at the host PC.

The feature does not exist anywhere in the open-source Sunshine/Moonlight stack. Parsec (commercial, Unity-owned) is currently the only game-streaming setup that ships it. This project adds it.

## How it works

The patched Moonlight Qt client opens the OS default microphone and encodes audio into Opus frames at 48 kHz mono. Each frame is sent as a `0x5510` packet over the existing AES-GCM encrypted control tunnel — the same channel Moonlight already uses for input events. No new ports, no new pairing, no new firewall rules.

Apollo receives the `0x5510` packets, decodes them, and writes the PCM into the **"Microphone (Steam Streaming Microphone)"** virtual audio device — a virtual input device that Apollo's Steam audio driver integration provides on Windows. Any app on the host that reads from that device (Discord, OBS, in-game voice, `mmsys.cpl`) sees the audio as if a real mic were plugged into the host.

Both ends must be patched: a stock Moonlight client never emits `0x5510` packets, and a stock Sunshine or Apollo host ignores them even if it received them. Capability negotiation via SDP feature flags ensures mixed-version peers degrade gracefully — a patched client paired with a stock host silently skips mic forwarding.

## Requirements

- **Host OS: Windows.** Linux and macOS host support is planned; the current release is Windows-only.
- **Apollo on the host.** Not stock Sunshine — Apollo ships the Steam audio driver integration that the receive path depends on. Apollo can run side-by-side with an existing Sunshine install on a different port; see [setup docs](docs/using/setup.md).
- **Steam audio drivers installed on the host.** Apollo's `tools/install_steam_audio_drivers` script handles this. Required for the "Microphone (Steam Streaming Microphone)" virtual device to appear.
- **Patched Moonlight Qt client on the client machine.** Cross-platform: Windows, Linux, and macOS. Watch this repo for the v0.1.0 tag for downloadable binaries; for now, [build from source](docs/building/).
- **Both ends paired as normal.** Nothing changes in the Moonlight pairing flow.
- **Both ends must be patched.** A stock client or stock host on either end means no mic forwarding; neither end errors or breaks.

## Quick start

1. On the host: install Apollo and run `tools/install_steam_audio_drivers` from the Apollo install directory. See [Apollo's README](https://github.com/JimothySnicket/Apollo) for installation steps.
2. On the client: install the patched Moonlight Qt build (watch this repo for the v0.1.0 tag; or [build from source](docs/building/)).
3. Pair client and host as normal via Moonlight's standard Add PC flow — nothing changes here.
4. On the client: open Settings → Audio → enable **"Stream client microphone to host"**. This setting persists across launches and defaults to off.
5. Start a stream. On the host, open `mmsys.cpl` → Recording tab — **"Microphone (Steam Streaming Microphone)"** should appear as an active device. Speak into your client mic and the level meter should move.
6. Point Discord, OBS, or your game's voice chat at "Microphone (Steam Streaming Microphone)" on the host.

For detailed steps, troubleshooting, and driver verification see [`docs/using/setup.md`](docs/using/setup.md) and [`docs/using/troubleshooting.md`](docs/using/troubleshooting.md).

## What's in this repo

This is the umbrella project. The actual code lives in three component forks tracked here as submodules:

- [`moonlight-common-c`](https://github.com/JimothySnicket/moonlight-common-c) — protocol changes (the wire format)
- [`moonlight-qt`](https://github.com/JimothySnicket/moonlight-qt) — client UI + capture
- [`Apollo`](https://github.com/JimothySnicket/Apollo) — host receive + audio routing (fork of [ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo))

This repo carries the design specification, build orchestration, release packaging, and overall documentation.

## Getting it

Not yet released. Watch this repo for the v0.1.0 tag.

## Building from source

Clone the umbrella repo with all submodules in one step:

```sh
git clone --recurse-submodules https://github.com/JimothySnicket/moonlight-mic.git
```

This checks out `moonlight-common-c`, `moonlight-qt`, and `Apollo` each on their `moonlight-mic` branch, including Apollo's nested third-party dependencies.

Detailed per-component build instructions will live in `docs/building/` once they are written (tracked in D3).

## License

MIT for this umbrella repo (docs, scripts, CI). Component forks retain their upstream licenses (BSD for `moonlight-common-c`, GPLv3 for `moonlight-qt` and `Apollo`).

## Acknowledgments

Built on top of the [moonlight-stream](https://github.com/moonlight-stream) project (Moonlight Qt and moonlight-common-c) and [ClassicOldSong](https://github.com/ClassicOldSong)'s [Apollo](https://github.com/ClassicOldSong/Apollo) (a Sunshine fork). Steam Streaming Microphone driver and integration originally from [LizardByte's Sunshine](https://github.com/LizardByte/Sunshine).
