# Mic A/B capture (debug-only)

A debug feature that captures the same mic audio at two points in the moonlight-mic
chain so the encode/transport/decode chain's effect on quality can be measured
objectively rather than vibe-checked. Both captures land as 48 kHz mono PCM WAV
files that are directly A/B-able in any audio tool.

This is plumbing for [Q1 — mic crackle root-cause](../../README.md#status). It is
NOT a user-facing feature; it is compiled out of any production build and adds
zero overhead to the production audio path.

---

## Capture points

| File | Source | Where in code |
|------|--------|---------------|
| `client-pre-encode-YYYYMMDD-HHMMSS.wav` | Pre-encode samples on the patched Moonlight client | `MicAudioSender::runWorker` — taps `pcmBuf` immediately before `opus_encode` |
| `host-post-decode-YYYYMMDD-HHMMSS.wav` | Post-decode samples on the patched Apollo host | `stream.cpp` 0x5510 dispatch handler — taps `pcmBuffer` immediately after `opus_decode`, before any WASAPI conversion |

The host capture is taken **before** the WASAPI render path's mono → stereo /
s16 → f32 / sample-rate conversions, so the WAV reflects exactly what came out
of the Opus decoder. The client capture is the raw SDL2 mic dequeue exactly as
the encoder will see it on the next call.

Both files are 48 kHz mono signed-16-bit-LE PCM, 10 seconds long (480000
samples), and have valid RIFF/WAVE headers. They open in Audacity, ffmpeg,
Reaper, etc. without any conversion step.

---

## Building with the feature enabled

### Client (moonlight-qt, on client-pc)

Pass `CONFIG+=debug-mic-ab-capture` to qmake:

```bash
qmake "%SOURCE_ROOT%\moonlight-qt.pro" CONFIG+=release CONFIG+=debug-mic-ab-capture
```

The default build script `moonlight-qt/scripts/build-moonlight-mic-win.bat` does
NOT enable the flag; copy it to a one-off build script, or invoke qmake by hand.

When the flag is absent, `DEBUG_MIC_AB_CAPTURE` is not defined, the
`KeyComboMicABCapture` enum entry is removed by the preprocessor, the
`armDebugCapture()` member function does not exist, and the worker thread has
no extra branches in the audio path.

### Host (Apollo, on host-pc)

Pass `-DDEBUG_MIC_AB_CAPTURE=ON` to cmake:

```bash
cmake -B "$BUILD_DIR" -G Ninja -S "$SOURCE_DIR" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DDEBUG_MIC_AB_CAPTURE=ON \
    [...other options...]
```

When the option is OFF (the default), the per-session `mic.capture_file` field
is removed by the preprocessor, the polling and capture branch in the dispatch
handler is removed, and Apollo's compiled binary is byte-equivalent to a build
without this code.

---

## Running a capture

### One-time setup on the host (host-pc)

1. Pick or create an output directory. Anywhere your Apollo process can write —
   e.g. `C:\debug\moonlight-mic-ab\`.
2. Set the env var **before launching Apollo**:

   ```cmd
   set APOLLO_MIC_AB_CAPTURE_DIR=C:\debug\moonlight-mic-ab
   sunshine.exe
   ```

   In a foreground console session this is fine. If Apollo runs as a service,
   set the env var via the service's environment (Apollo's launch mechanism on
   host-pc is documented in `scripts/run-apollo-host-pc.md`).

If `APOLLO_MIC_AB_CAPTURE_DIR` is not set, the host-side capture code is dormant
even when the build was compiled with `DEBUG_MIC_AB_CAPTURE=ON`. The compiled
code is in the binary but never observes a non-empty directory and never opens
a file.

### One-time setup on the client (client-pc)

The client picks an output directory automatically — `SDL_GetPrefPath` returns
something like
`C:\Users\<user>\AppData\Roaming\moonlight-mic\ab-capture\` on Windows.

To override it (e.g. so both files land on the same shared drive), set the env
var before launching Moonlight:

```cmd
set MOONLIGHT_MIC_AB_CAPTURE_DIR=<shared-dir>\moonlight-mic-ab
Moonlight.exe
```

### Per-capture (each time you want a measurement)

1. **Start the stream** from the patched Moonlight client to the patched Apollo
   host with mic streaming enabled in Settings.
2. **Arm the host** — on host-pc, create the trigger file:

   ```cmd
   type nul > C:\debug\moonlight-mic-ab\.arm
   ```

   Apollo polls for this file once per second (50 frames). On detection it
   deletes the file, opens a new WAV, and starts capturing the next
   10 seconds of post-decode mic samples.

3. **Arm the client** — back in the streaming window, press **Ctrl + Alt + Shift + R**.
   The client's mic worker thread captures the next 10 seconds of pre-encode
   samples to its WAV file.
4. **Speak into the mic for at least 10 seconds.** Both ends are now writing.

The two captures don't need to start at exactly the same instant — they only
need to overlap. Aim to do steps 2 and 3 within a few seconds of each other,
then speak continuously. The A/B comparison only needs ~5-10 seconds of
overlapping content.

Apollo and Moonlight will log when capture starts and finishes:

- Client: `MicAudioSender: debug capture STARTED -> ...`
- Client: `MicAudioSender: debug capture COMPLETE (480000 samples = 10 s)`
- Host: `Mic A/B capture STARTED -> ...`
- Host: `Mic A/B capture COMPLETE (480000 samples = 10 s)`

### Re-arming for another capture

- **Host**: just create the `.arm` file again. Each `.arm` arms exactly one
  capture window; the host deletes the file as it starts.
- **Client**: just press the hotkey again. A second press during a capture is a
  no-op (logged as "already armed/in progress, ignoring trigger").

There's no per-Apollo-instance limit. Capture as many windows as you need
without restarting either process.

---

## Comparing the two files

Both files are 48 kHz mono s16 PCM. Useful tools:

- **Audacity** — open both files, lay them on parallel tracks, eyeball the
  waveforms, A/B-listen. Use the spectrogram view to compare frequency content.
- **`ffmpeg -i`** — confirm metadata: `Sample rate: 48000 Hz, mono, s16`.
- **`sox`** — get statistics:
  ```bash
  sox client-pre-encode-*.wav -n stat
  sox host-post-decode-*.wav -n stat
  ```
  Compare RMS, peak amplitude, DC offset.
- **`ffmpeg`-based PESQ / POLQA** — for objective speech-quality scores, if
  going beyond eyeball / vibe.

Expected differences (these are what we're MEASURING, not bugs):
- Some loss of high-frequency content — Opus VOIP mode bandlimits to ~8 kHz.
- Possibly some attack/transient artefacts from the bitrate target (24-48 kbps).
- Latency offset between the two files — they will start at slightly different
  moments. Align by ear or by cross-correlating.

UNexpected differences (these would be Q1 evidence):
- Crackles / clicks present in `host-post-decode-*` that are absent in
  `client-pre-encode-*`. Likely candidates: encoder configuration (DTX,
  application mode, bitrate), packet drop pattern, or WASAPI write timing.
- Sustained tone changes / pitch shifts. Likely a sample-rate negotiation
  problem.
- Long stretches of silence that don't match the input. Likely SDL dequeue
  buffering, sequence-number gap handling, or WASAPI backpressure.

Which one is which is exactly what we use the A/B captures to figure out.

---

## Trigger / sync design

Two design constraints made this simple-and-manual rather than fancy:

1. **No wire-format changes.** The moonlight-mic wire spec is locked at
   `docs/design/wire-format.md` and the moonlight-common-c submodule is off
   limits for this work. Adding a new debug-only control packet would have
   required modifications to moonlight-common-c, which is out of scope.

2. **No production audio overhead.** The flag has to be invisible in the
   production audio path. Trigger files + env vars + a `#ifdef`-gated key
   combo achieve this with no extra branches when the flag is off.

The trade-off is that the two ends are armed independently (host via `.arm`
file, client via hotkey) instead of one master trigger arming both. In practice
this is fine for an audio-quality measurement — sample-aligned sync isn't
needed; only overlapping content is.

---

## Cleanup / opting out

Don't enable the flags in any release build. The defaults are OFF for both
client (qmake `CONFIG+=debug-mic-ab-capture` absent) and host
(`-DDEBUG_MIC_AB_CAPTURE=OFF`). To remove this feature from a working tree
once Q1 is resolved, it's safe to delete the gated blocks — the gates are
already in place and clean.

The captured WAV files are voice audio. Treat them as private; don't ship
them, don't put them in any public log bundle, and clean the capture directory
between sessions if multiple people use the system.
