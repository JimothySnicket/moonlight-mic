# Upstream drafts — gcc-16 nodejs bad_weak_ptr fix

> **DO NOT FILE.** Nothing in this file is to be posted, opened, or submitted to any
> upstream repository without Jamie's explicit per-action go-ahead. These are review
> drafts only.

> **Major rewrite 2026-05-13.** The original draft assumed we'd be PR'ing a workflow
> change at Apollo or Sunshine. That assumption was wrong:
>
> - **Sunshine already has the fix** in [`ci-windows.yml`](https://github.com/LizardByte/Sunshine/blob/master/.github/workflows/ci-windows.yml): they use `actions/setup-node` and deliberately omit `mingw-w64-*-nodejs` from the MSYS2 install. Their Windows CI passed on 2026-05-13. Filing there is a non-issue.
> - **Apollo has no CI workflows** — `.github/workflows/` doesn't exist in ClassicOldSong/Apollo. Nothing to PR against.
>
> However Apollo has [`docs/building.md`](https://github.com/ClassicOldSong/Apollo/blob/master/docs/building.md) which on line 105 explicitly tells Windows devs to `pacman -S mingw-w64-ucrt-x86_64-nodejs`. **That's the actual upstream bug** — the docs lead developers straight into the trap. The fix is a small docs PR.

---

## Recommended approach

**Single docs PR to ClassicOldSong/Apollo, no Sunshine filing.**

| Property | Value |
|----------|-------|
| Repo | `ClassicOldSong/Apollo` |
| File touched | `docs/building.md` (single file) |
| Lines changed | ~5 lines removed + ~5 lines added |
| Issue companion | Optional. PR description carries the explanation; for a docs PR the diff *is* the conversation. |
| Sunshine cross-file | No. They already have it solved correctly. |
| Coordinate with public flip? | Decouple. Docs PRs are low-risk and don't need a launch-day bundle. File when convenient. |

---

## Open questions for Jamie before filing

1. **Issue-then-PR, or PR-only?** — for a 10-line docs fix the PR diff is self-explanatory. Filing an issue first is more formal but possibly unnecessary noise. I lean PR-only.
2. **Author commit identity** — `JimothySnicket` handle with the GitHub noreply email (resolved 2026-05-08 in hygiene pass: noreply selected).
3. **Decoupled timing or bundle with public flip?** — I lean decoupled. The docs PR is small enough to ship on its own without coordinating with the umbrella going public.

---

## Suggested PR title

`docs(building): drop MSYS2 nodejs from Windows deps to avoid gcc-16 bad_weak_ptr`

(short, action-led, matches the conventional-commit style Apollo's CONTRIBUTING.md implies)

---

## Suggested PR body

> Style note: lifted from how Mitchell Hashimoto, Anthony Fu, and the Rust-lang docs
> PRs write small fixes — prose-first, minimal headings, conversational, citations as
> reference-style links. ~180 words.

```markdown
Hit this while building Apollo locally on Windows for a downstream patch.
`docs/building.md` currently tells Windows devs to `pacman -S mingw-w64-ucrt-x86_64-nodejs`,
which since the MSYS2 toolchain rolled to gcc 16.1 around 2026-04-30 has been crashing
the `web-ui` CMake target with `std::bad_weak_ptr` / `0xc0000409` — Node's own process
init blows up in the gcc-16 libstdc++ before `npm install` produces any output. Apache
Arrow tracked the same toolchain regression in [apache/arrow#49958][1] (CLANG64 / libc++
is unaffected, so it's specifically gcc-16 libstdc++). LizardByte/Sunshine sidesteps
it in [their Windows CI][2] by using `actions/setup-node` and omitting the MSYS2 nodejs
package; this PR brings the build doc into line — drop the MSYS2 nodejs from the deps
list, add a short note pointing at official Node.js / nvm-windows.

The C++ toolchain stays on `mingw-w64-ucrt-x86_64-toolchain` (gcc 16); the regression
only manifests inside Node's own internals, not Apollo's C++ code.

Verified the docs change in a downstream Apollo fork's CI matrix: ~60% failure rate
across rc4-rc11 with the MSYS2 nodejs in place, then 3-of-3 first-attempt passes
(rc13-15) after switching to official Node.

[1]: https://github.com/apache/arrow/issues/49958
[2]: https://github.com/LizardByte/Sunshine/blob/master/.github/workflows/ci-windows.yml
```

---

## Suggested diff for `docs/building.md`

Around line 95-114 (the Windows `dependencies` array):

```diff
 ##### Install dependencies
 ```bash
 dependencies=(
   "git"
   "mingw-w64-ucrt-x86_64-boost"  # Optional
   "mingw-w64-ucrt-x86_64-cmake"
   "mingw-w64-ucrt-x86_64-cppwinrt"
   "mingw-w64-ucrt-x86_64-curl-winssl"
   "mingw-w64-ucrt-x86_64-doxygen"  # Optional, for docs... better to install official Doxygen
   "mingw-w64-ucrt-x86_64-graphviz"  # Optional, for docs
   "mingw-w64-ucrt-x86_64-MinHook"
   "mingw-w64-ucrt-x86_64-miniupnpc"
-  "mingw-w64-ucrt-x86_64-nodejs"
   "mingw-w64-ucrt-x86_64-nsis"
   "mingw-w64-ucrt-x86_64-onevpl"
   "mingw-w64-ucrt-x86_64-openssl"
   "mingw-w64-ucrt-x86_64-opus"
   "mingw-w64-ucrt-x86_64-toolchain"
   "mingw-w64-ucrt-x86_64-nlohmann_json"
 )
 pacman -S "${dependencies[@]}"
 ```

+##### Install Node.js
+Install Node.js separately from [nodejs.org](https://nodejs.org/) (LTS or current) or via
+[nvm-windows](https://github.com/coreybutler/nvm-windows). Don't install MSYS2's
+`mingw-w64-ucrt-x86_64-nodejs` — it's compiled with the MSYS2 gcc-16 libstdc++ which has
+a `std::bad_weak_ptr` regression that crashes Node during process init (see
+[apache/arrow#49958](https://github.com/apache/arrow/issues/49958) for the upstream
+toolchain trail). The official MSVC-built Node.js isn't affected.
+
+Make sure `node.exe` is on `PATH` before running `cmake` — the `web-ui` CMake target
+invokes `npm install` via `find_program(NPM npm)`, so the official Node's `npm` must be
+visible to CMake.
+
 ### Clone
```

---

## (Optional) Companion issue body — only if filing issue-first

If we go issue-first, the PR body above doubles as the issue body — drop the "this PR brings the build doc into line — ..." half-sentence and you're left with the report. Title same.

---

## Filing checklist (when Jamie says go)

- [ ] Confirm with Jamie: PR-only or issue+PR
- [ ] Confirm Jamie has reviewed the PR body verbatim
- [ ] Confirm Jamie has reviewed the docs/building.md diff
- [ ] Branch from `JimothySnicket/Apollo` master (NOT the `moonlight-mic-stable` branch — keep the docs PR independent of the mic feature)
- [ ] Make the doc change locally on `JimothySnicket/Apollo`
- [ ] Push branch to `JimothySnicket/Apollo`
- [ ] `gh pr create --repo ClassicOldSong/Apollo --title "..." --body-file <draft>`
- [ ] Paste link back to Jamie
- [ ] Update `SecondBrain/projects/moonlight-mic.md` Decisions + Completed Work with filing date and PR link

The `gh pr create` is a public-disclosure action and requires its own explicit go-ahead at the time.

---

## Status of drafts

| Artifact | State |
|----------|-------|
| Recommended approach | docs PR to ClassicOldSong/Apollo, no Sunshine filing |
| PR title | Drafted — needs Jamie sign-off |
| PR body | Drafted — needs Jamie review |
| docs/building.md diff | Drafted — needs Jamie review |
| Issue body (if going issue-first) | Reuse PR body, drop "What changes"/"Not changed" |
| Decision on PR-only vs issue+PR | **Open** |
| Decision on timing (decoupled from public flip?) | **Open** |
| rc13 / rc14 / rc15 soak | ✓ all first-attempt pass on all 5 jobs (3-of-3 verified) |
| Verification stats in PR body | Accurate as written (3-of-3) |
