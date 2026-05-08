# moonlight-mic

Microphone passthrough for the Sunshine + Moonlight game streaming stack — talk into your mic on the Moonlight client, hear yourself on the Apollo host.

> **Status: in active development.** Not yet released. The proof-of-concept demonstrated end-to-end mic audio working through the [Apollo](https://github.com/ClassicOldSong/Apollo) host (a Sunshine fork) with a modified Moonlight Qt client. This umbrella project is the clean rewrite targeting public release.

> **Built with [Claude Code](https://claude.com/claude-code) and Codex.** Most code was written by AI agents under maintainer direction; design, testing, and decisions were the maintainer's.

## What this is

A modified Moonlight Qt client + a modified Apollo host that together let you stream microphone audio from the streaming client to the host PC. On the host, the audio shows up as **"Microphone (Steam Streaming Microphone)"** — capture it with Discord, OBS, or any voice chat app, and you'll be heard as if you were sitting at the host PC.

The feature does not exist anywhere in the open-source Sunshine/Moonlight stack. Parsec (commercial, Unity-owned) is currently the only game-streaming setup that ships it. This project adds it.

## How it works

The patched client opens the OS default microphone, encodes 20 ms Opus frames at 48 kHz mono, and sends them as `0x5510` packets over the existing AES-GCM encrypted control tunnel — the same channel Moonlight already uses for input events. No new ports, no new pairing, no new firewall rules. The patched host decodes them and writes the PCM into the **"Microphone (Steam Streaming Microphone)"** virtual recording device that Apollo's Steam audio driver integration provides on Windows.

Capability negotiation via SDP feature flags ensures mixed-version peers degrade gracefully: a patched client paired with a stock host silently skips mic forwarding; a stock client paired with a patched host allocates no mic-side resources.

For deeper detail see [ARCHITECTURE.md](ARCHITECTURE.md) and the wire-format spec at [`docs/design/wire-format.md`](docs/design/wire-format.md).

## Requirements

- **Host OS: Windows.** Linux and macOS host support is planned; the current release is Windows-only.
- **Apollo on the host.** Not stock Sunshine — Apollo ships the Steam audio driver integration the receive path depends on. Apollo can run side-by-side with an existing Sunshine install on a different port; see [`docs/using/setup.md`](docs/using/setup.md).
- **Steam audio drivers installed on the host.** Apollo's `tools/install_steam_audio_drivers` script handles this. Required for the "Microphone (Steam Streaming Microphone)" virtual device to appear.
- **Patched Moonlight Qt client on the client machine.** Cross-platform: Windows, Linux, and macOS. Watch this repo for the v0.1.0 tag for downloadable binaries; for now, build from source — see [CONTRIBUTING.md](CONTRIBUTING.md).
- **Both ends paired as normal.** Nothing changes in the Moonlight pairing flow.
- **Both ends must be patched.** A stock client or stock host on either end means no mic forwarding; neither end errors or breaks.

## Quick start

1. On the host: install Apollo and run `tools/install_steam_audio_drivers` from the Apollo install directory. See [Apollo's README](https://github.com/JimothySnicket/Apollo) for installation steps.
2. On the client: install the patched Moonlight Qt build (watch this repo for the v0.1.0 tag; or build from source via [CONTRIBUTING.md](CONTRIBUTING.md)).
3. Pair client and host as normal via Moonlight's standard Add PC flow — nothing changes here.
4. On the client: open Settings → Audio → enable **"Stream client microphone to host"**. The setting persists across launches and defaults to off.
5. Start a stream. On the host, open `mmsys.cpl` → Recording tab — **"Microphone (Steam Streaming Microphone)"** should appear as an active device. Speak into your client mic and the level meter should move.
6. Point Discord, OBS, or your game's voice chat at "Microphone (Steam Streaming Microphone)" on the host.

For detailed steps, troubleshooting, and driver verification see [`docs/using/setup.md`](docs/using/setup.md) and [`docs/using/troubleshooting.md`](docs/using/troubleshooting.md).

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — project shape, component forks, data flow, support matrix
- [CONTRIBUTING.md](CONTRIBUTING.md) — building from source, branch model, PR workflow
- [`docs/using/setup.md`](docs/using/setup.md) — end-user setup walkthrough
- [`docs/using/troubleshooting.md`](docs/using/troubleshooting.md) — common issues
- [`docs/design/wire-format.md`](docs/design/wire-format.md) — canonical protocol specification

## Getting it

Not yet released. Watch this repo for the v0.1.0 tag.

## License

MIT for this umbrella repo (docs, scripts, CI). Component forks retain their upstream licenses (BSD-3-Clause for `moonlight-common-c`, GPLv3 for `moonlight-qt` and `Apollo`).

## Acknowledgements

Built on top of the [moonlight-stream](https://github.com/moonlight-stream) project ([Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt) and [moonlight-common-c](https://github.com/moonlight-stream/moonlight-common-c)) and [ClassicOldSong](https://github.com/ClassicOldSong)'s [Apollo](https://github.com/ClassicOldSong/Apollo) (a Sunshine fork). Steam Streaming Microphone driver and integration originate from [LizardByte's Sunshine](https://github.com/LizardByte/Sunshine).
