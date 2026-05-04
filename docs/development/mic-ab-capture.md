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

### One-time setup — both ends point at a shared directory

The recommended workflow uses a **shared filesystem path** that both the client
and host can read/write — typically a network share such as JimothySnicket's `<your-drive>\` drive
on client-pc (which is `\\HOST-PC\shared` on the network and `<your-drive>\` from
host-pc itself). This lets a single hotkey press on the client trigger both
captures because the client writes a `.arm` sentinel file that the host's
polling loop sees within ~1 second.

Pick a shared directory (e.g. `<shared-dir>\moonlight-mic-ab\` on client-pc /
`<shared-dir>\moonlight-mic-ab\` on host-pc — same physical files, different drive
letters per machine). Then:

**On the host (host-pc), set the env var system-wide and restart Apollo:**

```powershell
ssh <user>@host-pc 'setx APOLLO_MIC_AB_CAPTURE_DIR "<shared-dir>\moonlight-mic-ab" /M'
ssh <user>@host-pc 'sc stop ApolloService'
Start-Sleep -Seconds 8
ssh <user>@host-pc 'sc start ApolloService'
```

**On the client (client-pc), set the env var (user-level, no admin needed):**

```powershell
[Environment]::SetEnvironmentVariable("MOONLIGHT_MIC_AB_CAPTURE_DIR", "<shared-dir>\moonlight-mic-ab", "User")
$env:MOONLIGHT_MIC_AB_CAPTURE_DIR = "<shared-dir>\moonlight-mic-ab"
```

If `APOLLO_MIC_AB_CAPTURE_DIR` is not set on the host, the host-side capture
code is dormant even when the binary was compiled with `DEBUG_MIC_AB_CAPTURE=ON`.

If `MOONLIGHT_MIC_AB_CAPTURE_DIR` is not set on the client, the client falls
back to `SDL_GetPrefPath` (typically `%APPDATA%\moonlight-mic\ab-capture\`),
and writes the `.arm` file there — which the host won't see, so you'd need
to fall back to the manual two-trigger workflow described below.

### Per-capture (each time you want a measurement)

1. **Start the stream** from the patched Moonlight client to the patched Apollo
   host with mic streaming enabled in Settings.
2. **Press Ctrl + Alt + Shift + R** in the streaming window. That single hotkey:
   - Arms the client's worker thread to capture the next 10 s of pre-encode samples.
   - Writes a `.arm` sentinel file to `MOONLIGHT_MIC_AB_CAPTURE_DIR`.
   - Apollo's polling loop on the host (running once per second) sees the
     `.arm` file in `APOLLO_MIC_AB_CAPTURE_DIR`, deletes it, and starts its own
     10 s post-decode capture.
3. **Speak into the mic for at least 10 seconds.** Both ends are writing.

Realistic timing: the host's capture starts within ~1 second of the client's
(host polls at 1 Hz; SMB write/read sync adds tens of milliseconds). Both
captures are 10 s long, so 9+ seconds of overlapping content is normal — plenty
for an A/B comparison.

Apollo and Moonlight will log when capture starts and finishes:

- Client: `MicAudioSender: debug capture ARMED ...`
- Client: `MicAudioSender: wrote host trigger sentinel -> ...`
- Client: `MicAudioSender: debug capture STARTED -> ...`
- Client: `MicAudioSender: debug capture COMPLETE (480000 samples = 10 s)`
- Host: `Mic A/B capture STARTED -> ...`
- Host: `Mic A/B capture COMPLETE (480000 samples = 10 s)`

### Re-arming for another capture

Just press the hotkey again. The host's `.arm` file from the previous capture
was deleted on detection, so a new one will be written. A second press during
an in-progress capture is a no-op (logged as "already armed/in progress").
There's no per-instance limit; capture as many windows as you need without
restarting either process.

### Manual fallback (no shared directory)

If you can't or don't want to share a directory between the two machines, the
hotkey still arms the client only. To trigger the host manually, create the
`.arm` file on host-pc via SSH **immediately before** pressing the hotkey:

```powershell
ssh <user>@host-pc 'type nul > C:\path\to\apollo-mic-ab-capture\.arm'
# then within ~1 second, alt-tab to Moonlight and press Ctrl+Alt+Shift+R
```

The captures don't need sample-precise sync — they just need to overlap.
Aim to do both within ~5 seconds of each other.

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
