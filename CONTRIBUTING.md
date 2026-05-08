# Contributing to moonlight-mic

Thanks for your interest. This document explains how the project is organised,
how to build it, and how to land changes. For a higher-level orientation read
[ARCHITECTURE.md](ARCHITECTURE.md) first.

## Quick start

Clone the umbrella repository with submodules in one step:

```sh
git clone --recurse-submodules https://github.com/JimothySnicket/moonlight-mic.git
```

This checks out `moonlight-common-c`, `moonlight-qt`, and `Apollo` each on its
`moonlight-mic` feature branch. If you have already cloned without
`--recurse-submodules`, run:

```sh
git submodule update --init --recursive
```

For per-component build commands, see [Building from source](#building-from-source)
below and the per-fork notes under [`docs/building/`](docs/building/).

## Build prerequisites

### Host side (Apollo)

Apollo currently builds on Windows. Build environment:

- **MSYS2 UCRT64** with the toolchain group installed (gcc, ninja, cmake).
- **Boost 1.89** and the other Apollo build dependencies — install via
  Apollo's documented build steps. The umbrella's `scripts/build-apollo.sh` and
  `scripts/build-apollo-v046.sh` drive the full build end-to-end.
- The bundled Steam audio drivers and tools live under `Apollo/tools/`.

Apollo's own `README.md` and `docs/` carry the canonical build documentation;
the per-fork build notes in [`docs/building/`](docs/building/) point at those
sources rather than duplicating them.

### Client side (Moonlight Qt)

Moonlight Qt builds on Windows, Linux, and macOS. Build environment:

- **Qt 6.10.3** (or a compatible 6.x release) with the modules Moonlight Qt
  uses — Qt Quick, Qt Multimedia, Qt SVG.
- **SDL2** is vendored inside the moonlight-qt submodule's third-party tree.
- A C++17 toolchain — MSVC 2022 on Windows, recent GCC or Clang on Linux,
  Xcode on macOS.

Moonlight Qt's upstream `README.md` documents the standard build flow; this
project does not change it.

### Protocol side (moonlight-common-c)

`moonlight-common-c` is the shared protocol library. It builds as part of
Moonlight Qt and links into the client. To build the standalone test binary
for the mic parser and capability gate, see
[Testing](#testing).

For per-fork detail see [`docs/building/`](docs/building/).

## Building from source

### Build the client

Standard Moonlight Qt build flow with the patched submodule:

```sh
cd moonlight-qt
qmake moonlight-qt.pro
make
```

The resulting Moonlight Qt binary includes the mic toggle in
Settings → Audio. See [`docs/building/`](docs/building/) for OS-specific notes.

### Build the host

The umbrella ships a build script that drives the full Apollo build under MSYS2:

```sh
bash scripts/build-apollo.sh
```

For the v0.4.6 daily-driver branch and the v0.4.8-stable comparison branch
there are dedicated helpers — `scripts/build-apollo-v046.sh` and
`scripts/build-apollo-stable.sh` respectively. For any of these scripts to
work, MSYS2 UCRT64 must be on the PATH and the dependencies above must be
installed.

### Build the protocol library

`moonlight-common-c` is built transitively by the Moonlight Qt build. To build
its tests directly:

```sh
cd moonlight-common-c
cmake -S . -B build -DENABLE_MIC_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

## Repository structure for contributors

Each submodule carries the actual code changes. Mic work happens on a feature
branch named `moonlight-mic` (or `moonlight-mic-v046` for Apollo's v0.4.6 line)
inside each submodule. The umbrella's `main` advances by submodule pointer
bumps as upstream work lands.

When you make a change, you almost always make it inside a submodule, not in
the umbrella. The umbrella commit that follows is mechanical — it just bumps
the submodule pointer to the new commit.

## Branch model and the multi-push rule

The umbrella references each submodule by SHA. If the umbrella main pushes a
SHA that has not been pushed in the submodule, anyone who clones with
`--recurse-submodules` will fail at submodule update with "fatal: needed a
single revision". The fix is procedural rather than tooling: **always push
submodule changes before pushing the umbrella pointer bump**.

The full sequence for a change that touches one submodule:

1. Commit your change inside the submodule on its `moonlight-mic` branch.
2. Push that submodule's `moonlight-mic` branch to its origin
   (`JimothySnicket/<submodule>` for in-progress work; upstream when a PR is
   ready).
3. Back at the umbrella root, stage the submodule pointer bump
   (`git add <submodule>`) and commit the umbrella with a one-line subject
   describing what the bump contains.
4. Push the umbrella.

The umbrella's `.githooks/pre-push` enforces this on push: if any submodule
on `moonlight-mic` has unpushed commits, the umbrella push is rejected with a
message naming the offending submodules. To enable the hook, run
`scripts/setup.sh` once after clone — it sets `core.hooksPath` to `.githooks`.
There is also a convenience helper at `scripts/push-all.sh` that pushes the
submodules first, then the umbrella, in one shot.

If a submodule push fails (lint, CI, force-push protection) the umbrella push
should be aborted — never paper over it by force-pushing the umbrella ahead
of the submodule.

## Commit conventions

Commit messages follow plain imperative-mood subject lines, matching the style
already in this repository's history.

- Subject: imperative, around 50 characters, no required scope prefix. Recent
  examples from `git log --oneline`:
  - `Bump Moonlight mic device selector`
  - `Soften deprecation banner language`
  - `Fix control stream sizing and input reset`
  - `Ignore local Apollo web UI probe scripts`
- Body: optional. Use it when the subject is not enough — explain *why* the
  change exists, what alternatives were considered, and what side effects to
  watch for. Wrap at 72 characters. Separate body from subject with a blank
  line.
- One logical change per commit. A commit that bumps a submodule pointer is a
  separate commit from one that adds a doc or a script.

The submodule forks may carry their own additional commit conventions
(co-authoring tags, sign-off requirements). When in doubt, mirror the recent
history of the repo you are committing into.

## Where to file issues

- **Cross-cutting, user-facing, or setup issues** — file at the umbrella:
  [JimothySnicket/moonlight-mic/issues](https://github.com/JimothySnicket/moonlight-mic/issues).
  Examples: "the mic does not appear in the host's recording tab", "build
  script fails on a fresh clone", "documentation question".
- **Repository-specific code-level issues** — file at the relevant submodule's
  fork:
  - Protocol or wire-format bugs:
    [moonlight-common-c/issues](https://github.com/JimothySnicket/moonlight-common-c/issues)
  - Client UI or capture bugs:
    [moonlight-qt/issues](https://github.com/JimothySnicket/moonlight-qt/issues)
  - Host receive or render bugs:
    [Apollo/issues](https://github.com/JimothySnicket/Apollo/issues)

If you are not sure where an issue belongs, file at the umbrella and we will
move it.

## Pull request workflow

1. Fork the relevant submodule on GitHub. Pull requests for code changes go
   against the submodule fork, not against the umbrella.
2. Create a branch off `moonlight-mic` (or `moonlight-mic-v046` for Apollo's
   v0.4.6 line) inside your fork. Keep the branch focused on one change.
3. Open the pull request against `JimothySnicket/<submodule>`'s `moonlight-mic`
   branch. CI runs on the submodule (see `.github/workflows/` inside each
   submodule).
4. Once the submodule PR merges, a maintainer bumps the umbrella pointer in
   a follow-up umbrella commit. You generally do not need to file the umbrella
   bump yourself.

Pull requests against the upstream projects (`moonlight-stream/moonlight-common-c`,
`moonlight-stream/moonlight-qt`, `ClassicOldSong/Apollo`) are coordinated by
project maintainers, not driven by individual contributors. If you are
interested in helping prepare an upstream PR, raise it as an umbrella issue
first so the rollup can be coordinated across all three forks.

## Testing

Each fork has its own test surface. The umbrella does not run tests itself
beyond shape checks on documentation; per-fork tests run in each submodule's
CI.

- **moonlight-common-c**:
  ```sh
  cd moonlight-common-c
  cmake -S . -B build -DENABLE_MIC_TESTS=ON
  cmake --build build
  ctest --test-dir build --output-on-failure
  ```
  Covers the mic parser and the capability gate. CI workflow:
  `moonlight-common-c/.github/workflows/`.

- **moonlight-qt**: QtTest-based suite for the streaming session and
  `MicAudioSender`. Run via the submodule's standard test target.
  CI workflow: `moonlight-qt/.github/workflows/`.

- **Apollo**: GoogleTest suite under `Apollo/tests/unit/`, including
  `test_mic.cpp`. Build with `BUILD_TESTS=ON` and run via `ctest`. CI
  workflow: `Apollo/.github/workflows/`.

When adding a feature or fixing a bug, add or update the relevant tests in
the submodule that owns the change. If the change crosses submodule
boundaries (rare — usually only the wire format), mention the cross-fork
dependency in the PR description so reviewers can land them in the right
order.

## License

Each submodule retains its upstream license:

- `moonlight-common-c` — BSD-3-Clause
- `moonlight-qt` — GPLv3
- `Apollo` — GPLv3 (inherited from Sunshine)

The umbrella repository's own content (this document, `ARCHITECTURE.md`,
`README.md`, scripts, CI workflows) is MIT-licensed; see [LICENSE](LICENSE).

By submitting a pull request you agree that your contribution to a given
submodule is licensed under that submodule's license, and your contribution
to the umbrella is licensed under MIT.
