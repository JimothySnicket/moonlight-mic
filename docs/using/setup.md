# Setup guide

End-to-end setup for mic passthrough between a Moonlight Qt client and an Apollo host.

## Pre-requisites

**Host (Windows only):**
- Windows 10 or 11, 64-bit.
- Administrator rights — required to install the Steam audio drivers and start Apollo as a service.
- A working Apollo install — not stock Sunshine. Apollo ships the receive path and the Steam audio driver integration. It can run side-by-side with an existing Sunshine installation on a separate port (default Apollo port is 47989; Sunshine's default is 47984).
- The Steam audio drivers must be present on the host. Apollo bundles an installer at `tools/install_steam_audio_drivers.bat` inside the Apollo install directory. Run it once, as administrator, before starting Apollo. Without the drivers the "Microphone (Steam Streaming Microphone)" virtual device will not appear.

**Client (Windows / Linux / macOS):**
- Patched Moonlight Qt. The upstream Moonlight Qt release does not include the mic passthrough feature. Use the patched build from this project: watch [this repo](https://github.com/JimothySnicket/moonlight-mic) for the v0.1.0 tag. Build-from-source instructions are in [`docs/building/`](../building/) (in progress — see D3).
- A default microphone configured at the OS level. Moonlight uses SDL2 to open the OS default recording device. If no default mic is set, capture silently fails.

**Both ends:**
- Paired as normal — nothing changes in the Moonlight pairing flow.
- Both client and host must be patched builds. A patched client + stock host: no mic forwarding (capability negotiation degrades gracefully, no error). A stock client + patched host: same — the host never receives `0x5510` packets so the virtual mic shows no activity.

---

## Installing Apollo on the host

Apollo is a fork of Sunshine with additional features including the mic receive path used by this project.

1. Download Apollo from [JimothySnicket/Apollo releases](https://github.com/JimothySnicket/Apollo/releases) (watch for the `moonlight-mic` tagged build).
2. Run the Apollo installer. The default install path is `C:\Program Files\Apollo\`.
3. Open an administrator command prompt and run:
   ```
   "C:\Program Files\Apollo\tools\install_steam_audio_drivers.bat"
   ```
   This installs the Steam virtual audio device. A reboot is not required but the virtual device may take a few seconds to appear in Sound Settings.
4. Start Apollo. It listens on its own port and does not conflict with a running Sunshine instance.
5. Open Apollo's web UI (default: `https://localhost:47990`) and verify it shows your machine's name and display.

Apollo's own README has full configuration and firewall documentation. Nothing special is required for mic passthrough beyond the steps above.

---

## Installing the patched Moonlight Qt on the client

**From a release (v0.1.0 or later):**

Watch [JimothySnicket/moonlight-mic](https://github.com/JimothySnicket/moonlight-mic) for the v0.1.0 tag. The release will include pre-built Moonlight Qt installers for Windows, Linux, and macOS. Download the installer for your client OS and install it.

**From source:**

See [`docs/building/`](../building/) — build-from-source instructions are being written as part of this project's documentation sprint (D3) and are not yet complete.

---

## Pairing client and host

Nothing changes here. Use Moonlight's standard Add PC flow:

1. Open Moonlight Qt on the client.
2. Click the `+` button (Add PC) and enter the host's IP address.
3. Moonlight shows a PIN. Enter it in Apollo's web UI under Pair.
4. The host appears in the Moonlight main screen.

Refer to [Moonlight's pairing documentation](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide) for full detail including mDNS discovery and firewall notes.

---

## Enabling the mic toggle

The mic toggle is off by default. It persists across Moonlight launches once enabled.

1. Open Moonlight Qt on the client.
2. Click the gear icon (Settings) in the top-right corner.
3. Select **Audio** from the left sidebar.
4. Find **"Stream client microphone to host"** and check the box.
5. Click OK or close Settings.

The setting takes effect on the next stream start. Toggling it mid-stream is not supported in v0.1.0 — stop and restart the stream if you change it.

---

## Verifying the round-trip

After starting a stream:

1. On the host, open `mmsys.cpl` (Run → `mmsys.cpl`), go to the **Recording** tab.
2. Confirm **"Microphone (Steam Streaming Microphone)"** appears in the list. If it is missing, see [troubleshooting](troubleshooting.md#mic-doesnt-appear-in-host-recording-tab).
3. Speak into the client mic. The level meter next to "Microphone (Steam Streaming Microphone)" should move in real time.
4. Alternatively: right-click the device → **Test** — you should hear your voice played back on the host.

To use the mic in Discord, OBS, or a game on the host:
- Point that application's microphone input at **"Microphone (Steam Streaming Microphone)"**.
- Some applications cache the device list at startup — if it doesn't appear, restart the app after the stream is established.
