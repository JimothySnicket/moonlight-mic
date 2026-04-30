# moonlight-mic

Microphone passthrough for the Sunshine + Moonlight game streaming stack — talk into your mic on the Moonlight client, hear yourself on the Apollo host.

> **Status: in active development.** Not yet released. The proof-of-concept demonstrated end-to-end mic audio working through the [Apollo](https://github.com/ClassicOldSong/Apollo) host (a Sunshine fork) with a modified Moonlight Qt client. This umbrella project is the clean rewrite targeting public release.

## What this is

A modified Moonlight Qt client + a modified Apollo host that together let you stream microphone audio from the streaming client to the host PC. On the host, the audio shows up as **"Microphone (Steam Streaming Microphone)"** — capture it with Discord, OBS, or any voice chat app, and you'll be heard as if you were sitting at the host PC.

The feature does not exist anywhere in the open-source Sunshine/Moonlight stack. Parsec (commercial, Unity-owned) is currently the only game-streaming setup that ships it. This project adds it.

## What's in this repo

This is the umbrella project. The actual code lives in three component forks tracked here as submodules:

- [`moonlight-common-c`](https://github.com/JimothySnicket/moonlight-common-c) — protocol changes (the wire format)
- [`moonlight-qt`](https://github.com/JimothySnicket/moonlight-qt) — client UI + capture
- [`Apollo`](https://github.com/JimothySnicket/Apollo) — host receive + audio routing (fork of [ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo))

This repo carries the design specification, build orchestration, release packaging, and overall documentation.

## Getting it

Not yet released. Watch this repo for the v0.1.0 tag.

## License

MIT for this umbrella repo (docs, scripts, CI). Component forks retain their upstream licenses (BSD for `moonlight-common-c`, GPLv3 for `moonlight-qt` and `Apollo`).

## Acknowledgments

Built on top of the [moonlight-stream](https://github.com/moonlight-stream) project (Moonlight Qt and moonlight-common-c) and [ClassicOldSong](https://github.com/ClassicOldSong)'s [Apollo](https://github.com/ClassicOldSong/Apollo) (a Sunshine fork). Steam Streaming Microphone driver and integration originally from [LizardByte's Sunshine](https://github.com/LizardByte/Sunshine).
