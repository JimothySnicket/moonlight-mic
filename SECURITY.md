# Security policy

Thank you for taking the time to disclose security issues responsibly.

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.**

Use GitHub's private vulnerability reporting:

1. Go to the **Security** tab of this repository
2. Click **Report a vulnerability**
3. Describe the issue with as much detail as you can — reproduction steps, affected commit / build, suggested fix if you have one

The maintainer will acknowledge the report within a reasonable timeframe and work with you to validate the issue and coordinate a fix. Please allow time for triage before any public disclosure.

## Scope

This project adds microphone passthrough to the Sunshine + Moonlight game streaming stack. Security-relevant areas include:

- The wire format (`docs/design/wire-format.md`) and its handling on both ends
- Capability negotiation and gating (`SS_FF_MIC_INPUT`, `ML_FF_MIC_INPUT`)
- Memory safety in `moonlight-common-c/Mic.c`, `moonlight-qt/MicAudioSender.cpp`, and the Apollo dispatch / WASAPI render code
- Any path that handles untrusted client-supplied bytes on the host

The mic stream rides the existing AES-GCM control tunnel; if you have findings about the underlying control tunnel itself, please report those upstream:

- [moonlight-stream/moonlight-common-c](https://github.com/moonlight-stream/moonlight-common-c) — protocol library
- [ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo) — host
- [moonlight-stream/moonlight-qt](https://github.com/moonlight-stream/moonlight-qt) — client

## Out of scope

- Issues in stock Apollo or stock Moonlight Qt unrelated to mic passthrough — please report upstream as appropriate.
- Issues in the underlying Sunshine / moonlight-stream stack — please report upstream.
- Denial of service against an already-paired-and-running session by an authenticated client. The threat model assumes paired clients are trusted; the mic stream does not change that assumption.
