# Apollo on host-pc — run/stop runbook

Apollo runs as a **foreground process** from its build directory. It does not replace the
production Sunshine install and does not need to be installed as a Windows service.

## Critical: Apollo must run from its own directory

Apollo opens `assets/apps.json` and related files via relative paths at startup. Always
`cd` into the Apollo build directory before starting it:

```bat
cd /d <build-dir>\apollo-x64-release
sunshine.exe
```

Running `sunshine.exe` from any other CWD fails silently at config load and Apollo exits
immediately without starting any servers.

## Critical: Apollo requires a desktop session (Session 1+)

Apollo's Windows capture subsystem (DXGI, SUDOVDA virtual display driver) requires access to
the interactive desktop session. It **cannot run from an SSH shell** or any Session 0 context
without SYSTEM privileges. Running from an SSH session results in:

```
[ERROR_ACCESS_DENIED] failed to query display paths and modes
[SUDOVDA] Open device failed!
```

...followed by an immediate exit (no web server, no ports opened).

**To run Apollo properly:** use an interactive Windows session on host-pc — either the
physical console, RDP, or the service-swap pattern described below.

## Ports

| Host | Port | Protocol | Purpose |
|------|------|----------|---------|
| host-pc | 47989 | HTTP | Production Sunshine web UI (leave alone) |
| host-pc | 47984 | HTTPS | Production Sunshine HTTPS (leave alone) |
| host-pc | 47980 | HTTP | Apollo web UI (this build) |
| host-pc | 47975 | HTTPS | Apollo HTTPS (this build) |

Port mapping: base `port` in config → HTTP at `port+0`, HTTPS at `port-5`.

## Before starting Apollo

Verify production Sunshine is still responding:

```bat
curl -k -s -o NUL -w "%%{http_code}" http://localhost:47989/
```

Expected: `200` or `302`.

## Configure Apollo to use port 47980

Apollo creates `config\sunshine.conf` in the same directory as `sunshine.exe` on first run
(i.e. `<build-dir>\apollo-x64-release\config\sunshine.conf`).

The config file already exists with `port = 47980` set. To change it, edit the file and
restart Apollo. The config is NOT re-created if the file already exists.

## Start Apollo (foreground — requires interactive desktop session)

Open a Command Prompt **as Administrator** in an **interactive desktop session** (not SSH):

```bat
cd /d <build-dir>\apollo-x64-release
sunshine.exe
```

Apollo prints startup logs to the console. Wait for a log line containing `nvhttp` or
`confighttp` server binding — typically within 15–20 seconds.

## Verify Apollo web UI

```bat
curl -k -s -o NUL -w "%%{http_code}" https://localhost:47975/
```

or via HTTP:

```bat
curl -s -o NUL -w "%%{http_code}" http://localhost:47980/
```

Expected: `200`, `302`, or `401` (any means the web stack is alive; `401` = login required).

## Stop Apollo

Press `Ctrl+C` in the Apollo console window.

Confirm it has stopped:

```bat
tasklist /FI "IMAGENAME eq sunshine.exe"
```

After stopping Apollo, the process list should only show production Sunshine at
`C:\Program Files\Sunshine\Sunshine.exe`.

## Verify production Sunshine is unaffected

After stopping Apollo, confirm production Sunshine still responds:

```bat
curl -s -o NUL -w "%%{http_code}" http://localhost:47989/
```

Expected: `200`.

## Build directory layout

```
<build-dir>\apollo-x64-release\
  sunshine.exe          — main Apollo executable
  sunshinesvc.exe       — service helper (not used in foreground mode)
  audio-info.exe        — audio device info tool
  dxgi-info.exe         — display info tool
  config\
    sunshine.conf       — port = 47980 already set; config/apps.json created on first run
  assets\               — web UI and shaders
  tools\                — install_steam_audio_drivers.bat lives here
```

## Notes

- Do NOT run `scripts\install-service.bat` — that installs Apollo as a Windows service
  and would conflict with the production Sunshine service name.
- Do NOT touch `C:\Program Files\Sunshine\` — that is the production install.
- The Steam audio driver (`install_steam_audio_drivers.bat` in `tools\`) only needs to be
  run once per machine. It was already run during POC testing.
- The port-47989 connections you see in `netstat` (`TIME_WAIT` state) are from Moonlight
  clients connecting to production Sunshine. They are normal.
