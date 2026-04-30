# Troubleshooting

Common issues and fixes for mic passthrough. See [setup.md](setup.md) for initial configuration steps.

---

## Mic doesn't appear in host's Recording tab

**Symptom:** `mmsys.cpl` → Recording tab does not show "Microphone (Steam Streaming Microphone)" at all, even after starting a stream.

**Causes and fixes:**

1. **Steam audio drivers are not installed.** Run `tools/install_steam_audio_drivers.bat` from the Apollo install directory as administrator, then check again. The device should appear within a few seconds without a reboot.
2. **Apollo is not running.** The virtual device only registers when Apollo's service is active. Confirm Apollo shows in `services.msc` as Running.
3. **Wrong Apollo build.** Stock Apollo (ClassicOldSong/Apollo upstream) does not include the mic receive path. Confirm your Apollo build is from `JimothySnicket/Apollo` on the `moonlight-mic` branch or a tagged release from this project.

---

## Toggle is enabled but no audio activity on the host

**Symptom:** "Microphone (Steam Streaming Microphone)" is present in the Recording tab but the level meter doesn't move when speaking.

**Causes and fixes:**

1. **One or both ends are not patched.** Check the version string in Moonlight Qt's About screen and in Apollo's web UI. Both must be patched builds. A patched client + stock Apollo: the host receives `0x5510` packets but has no handler — audio is silently dropped. A stock Moonlight + patched Apollo: no packets are ever sent.
2. **Toggle is off or was changed after stream start.** Open Moonlight Settings → Audio → confirm "Stream client microphone to host" is checked. If you changed it while a stream was running, stop and restart the stream.
3. **No default microphone on the client.** Moonlight uses SDL2 to open the OS default recording device. If the client OS has no default mic configured, capture silently does nothing. Check `mmsys.cpl` → Recording on the client and set a default device.
4. **Capability negotiation fell back.** If the host did not advertise `SS_FF_MIC_INPUT` in its SDP, the client suppresses all `0x5510` output as a protocol safeguard. This should not happen with a patched Apollo, but if the Apollo config was recently changed or the flags file is corrupt, restarting Apollo resets the negotiation.

---

## Audio sounds choppy or has a helicopter-chop artefact

**Symptom:** Audio plays but sounds staccato, repeating, or has a rapid dropout pattern.

**Background:** The proof-of-concept had a known bug where SDL2-compat returned 960-byte chunks instead of the expected 1920-byte frames, causing the accumulation loop to send half-frames and produce chop. This was diagnosed and fixed in the rewrite.

**Fixes:**

- Confirm you are using a build from this project (`JimothySnicket/moonlight-mic`) and not a manually patched build derived from the POC.
- If the chop persists on a release build, [file an issue](https://github.com/JimothySnicket/moonlight-mic/issues) with your client OS and SDL2 version (visible in Moonlight's log output), and include a capture of the audio timing if possible — the accumulation diagnostics log to the client console.

---

## Capture works but other apps on the host don't see it

**Symptom:** The level meter moves in `mmsys.cpl` but Discord, OBS, or another app shows no audio from "Microphone (Steam Streaming Microphone)".

**Causes and fixes:**

1. **App cached the device list at startup.** Many apps — including Discord and OBS — enumerate audio devices once at launch and do not re-scan. Start the stream first, then launch the app (or restart it) so it picks up the active device.
2. **App is set to a different input device.** Check the app's audio input setting explicitly — "Default" may resolve to a different device depending on the OS default. Select "Microphone (Steam Streaming Microphone)" by name in the app's settings.
3. **Exclusive-mode conflict.** If another app has opened "Microphone (Steam Streaming Microphone)" in exclusive mode, shared-mode readers are blocked. Check that no other application is holding the device exclusively (rare with a virtual Steam device, but possible with some ASIO or WASAPI exclusive-mode hosts).

---

## Stream connects but Moonlight immediately disconnects or errors

This is not a mic-specific issue. Check Apollo's web UI log and Moonlight's log output (`%APPDATA%\Moonlight Game Streaming\Moonlight.log` on Windows) for the underlying error. Mic passthrough is established after the stream handshake completes — if the stream itself fails, mic is not involved.

---

## Further help

Open an issue at [JimothySnicket/moonlight-mic](https://github.com/JimothySnicket/moonlight-mic/issues). Include:
- Client OS and Moonlight build version (Settings → About)
- Host OS and Apollo version (Apollo web UI → About)
- Whether "Microphone (Steam Streaming Microphone)" appears in `mmsys.cpl` at all
- Moonlight client log and Apollo server log excerpts around the time of the issue
