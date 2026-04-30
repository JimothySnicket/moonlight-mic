# CLAUDE.md — moonlight-mic workspace

## What this is

The PR-ready rewrite of the Sunshine + Moonlight microphone passthrough feature. The proof-of-concept lives at `\\HOST-PC\shared\Dev\sunshine-mic\` and `<poc-build-dir>\` (build artefacts) and is preserved as reference. This umbrella repo is the clean rewrite targeting Apollo (host) and Moonlight Qt (client), with three component forks bound here as submodules.

## Read these first (in order)

1. `C:\Users\<user>\SecondBrain\CLAUDE.md` — vault navigation rules
2. `C:\Users\<user>\SecondBrain\projects\moonlight-mic.md` — current project state (renamed from `sunshine-mic.md` after the rewrite phase began)
3. `C:\Users\<user>\SecondBrain\plans\2026-04-30-moonlight-mic-rewrite.md` — the plan to execute against
4. `C:\Users\<user>\SecondBrain\landmines.md` — relevant entries: SDL2-compat dequeue, WASAPI WAVE_FORMAT_EXTENSIBLE, Sunshine `csrf_allowed_origins`, Write tool UNC paths

## POC reference (look but don't copy wholesale)

POC implementation lives at:

- Source: `\\HOST-PC\shared\Dev\sunshine-mic\` (<your-drive> drive when working from client-pc)
- Build artefacts: `<poc-build-dir>\` on each machine
- POC GitHub forks: `JimothySnicket/moonlight-common-c`, `JimothySnicket/moonlight-qt`, `JimothySnicket/Sunshine` — uncommitted POC work currently lives only on local disk

The POC's `WIRE.md` is the design source of truth — it gets cleaned up and republished as the canonical spec under this repo's `docs/design/`. The POC code itself carries diagnostic detritus (per-frame info logs, host-side PCM tap, hard-coded settings) and shouldn't be ported verbatim. Lift patterns and learnings, not files.

Key POC learnings worth preserving:

- **SDL2-compat returns audio in 960-byte chunks, not 1920.** Accumulate dequeue calls; clamp `got` to `to_read` defensively. See landmine "SDL2-compat (sdl2-compat / SDL3) — DequeueAudio returns smaller chunks than requested".
- **WASAPI shared mode wants `GetMixFormat`-negotiated format.** Don't hardcode `WAVEFORMATEX`. See landmine "WASAPI shared mode — `WAVE_FORMAT_EXTENSIBLE` mismatch".
- **OPUS_APPLICATION_AUDIO + OPUS_SET_DTX combination crashed.** Investigate carefully before enabling those settings; default to `OPUS_APPLICATION_VOIP` until you've isolated the cause with a standalone harness.

## Project shape

- `JimothySnicket/moonlight-mic` — this umbrella repo (you're in it)
- `JimothySnicket/moonlight-common-c` — fork; new `moonlight-mic` branch will be cut off freshly-synced upstream master
- `JimothySnicket/moonlight-qt` — same pattern
- `JimothySnicket/Apollo` — new fork of `ClassicOldSong/Apollo`; new `moonlight-mic` branch
- `JimothySnicket/Sunshine` — POC reference fork; deprecation README pointing at Apollo for active dev

## Machines and side-by-side install

- **client-pc** (Windows 11) — Moonlight Qt client builds and runs here
- **host-pc** (Windows 11) — Apollo host build runs here. Apollo will be installed **side-by-side** with the existing Sunshine production install, on a different port. Production Sunshine stays untouched (no service binPath swap this time)
- **<your-drive>** is shared between both PCs, physically on host-pc. Build outputs are local on each machine
- SSH from client-pc to host-pc is set up with passwordless SSH key

## First action

Once JimothySnicket says go, run `/dispatch` against the plan doc. S1 setup tasks are mostly already done (umbrella repo + Apollo fork created, this CLAUDE.md and README in place). Dispatcher should pick up at S2 (sync forks, cut clean `moonlight-mic` branches off upstream masters) or wherever the plan picks up.

## Don't

- Don't push to `JimothySnicket/Sunshine`. It's a POC reference; active host work happens on `JimothySnicket/Apollo`.
- Don't install Apollo over the running Sunshine on host-pc. They run side-by-side on different ports.
- Don't reuse POC's `mic-passthrough-poc` branches as the rewrite base. Cut new branches off freshly-synced upstream master.
- Don't push to the umbrella with submodule commits that haven't themselves been pushed first — the multi-push hook (when it lands in I1) will block this, but the rule applies before the hook exists too.
