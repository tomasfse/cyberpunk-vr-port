# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A 6-DoF VR mod for Cyberpunk 2077 (PC, **2.31**), shipped as two RED4ext plugins plus CET/redscript
mods. There is no `dxgi.dll` proxy — that shape was removed in 0.1.0 and must not come back.

## Build

**There are two separate CMake projects, not one tree.** They are configured and built
independently, in different configurations, and `scripts/build_dist.ps1` hard-codes both output
paths. Building only the root project produces a package that silently ships a stale
`CyberpunkVR_Hands.dll`.

```powershell
# 1. CyberpunkVR_Stereo.dll  (root project, Release)
cmake -S . -B build -A x64
cmake --build build --config Release --parallel

# 2. CyberpunkVR_Hands.dll  (src/red4ext_plugin, RelWithDebInfo -- the config is load-bearing,
#    build_dist.ps1 looks for the DLL under src\red4ext_plugin\build\RelWithDebInfo\)
cmake -S src/red4ext_plugin -B src/red4ext_plugin/build -A x64
cmake --build src/red4ext_plugin/build --config RelWithDebInfo --parallel

# 3. Package exactly as it must land in the game root
pwsh scripts/build_dist.ps1 -Version 0.1.2 -Zip
```

The **CMake target name and the shipped DLL name differ** (`cyberpunkvrport_stereo` →
`CyberpunkVR_Stereo.dll`). Conflating them is what once installed the plugin to a folder RED4ext
then ignored.

Root-project dependencies come down through `FetchContent` on configure (OpenXR-SDK 1.0.34, imgui
v1.90.9); MinHook and RED4ext.SDK are git submodules, so a fresh clone needs
`git submodule update --init --recursive`.

Release builds carry `/Zi` + `/DEBUG` with `/OPT:REF /OPT:ICF` restored explicitly — the PDB is
required to read a crash dump and does **not** change the binary. It ships nowhere.

## Dependencies: development vs installation

Keep these two apart — the README's requirement list used to conflate them, and the packaged
`INSTALL.txt` shipped a shorter list than the README.

**Development** (contributors only, never a player's problem): CMake 3.24+, MSVC x64, Windows SDK,
`pwsh`; MinHook and RED4ext.SDK as submodules; OpenXR-SDK 1.0.34 and imgui 1.90.9 via FetchContent;
`im3d` vendored in `externals/`. Separately, and needed **only** to re-author game assets: Python 3
for `tools/gen_vrcam_assets.py`, and WolvenKit to repack the `.archive`. You can build every line of
C++ without either.

Note there is **no shader compilation step**. The sight shaders are pre-built `.dxil` blobs
committed to the repo, so editing `src/vr/shaders/*.hlsl` means compiling them by hand — the
command is not recorded anywhere. The depth-resolve, colour-blit and sharpen passes are different:
they compile their HLSL at runtime through `d3dcompiler`.

**Installation** (what a player needs). Required: CP2077 2.31, RED4ext, CET, redscript, ArchiveXL,
TweakXL, Codeware 1.20+, and an OpenXR runtime. Optional: Equipment-EX (outfit slots the smoking
props attach to) and Visual Holsters (immersive holster mode only — simple mode does not need it).

Two things that are easy to get wrong here:

- **Codeware's failure mode is inverted.** The HUD reds guard their Codeware use with
  `@if(ModuleExists("Codeware"))`, so an *absent* Codeware just switches those blocks off. An
  *older* one compiles against a mismatched API and kills redscript compilation for every mod in
  the game. Absent is safe; stale is catastrophic.
- **Nothing in this repo references Visible Bullets or Nova Optics** — not the Lua, the reds, the
  yamls or the C++. They are recommended setup, not dependencies, and listing them as requirements
  imposes a lighting mod on players for no technical reason.

There are also **no third-party `import`s in the redscript at all**; every cross-mod touchpoint is
either an `@if(ModuleExists(...))` guard, a native game symbol, or a `t"..."` TweakDBID literal
that compiles regardless and simply resolves to nothing when the mod is missing.

## Install / deploy

```powershell
pwsh scripts/deploy_stereo.ps1 -GameRoot "<game root>"   # install (calls sync_assets -Push)
pwsh scripts/revert_stereo.ps1 -GameRoot "<game root>"   # undo, restores any stashed dxgi.dll
pwsh scripts/sync_assets.ps1   -GameRoot "<game root>"   # pull game-side assets back into the repo
```

Two install-time invariants that have each caused a crash:

- **RED4ext loads every `.dll` under `red4ext\plugins\`, by file, not by folder name.** A renamed
  backup beside the real build loads as a *second copy of the plugin*: two sets of natives, two
  sets of detours, the second writing its jump over the first's trampoline. `deploy_stereo.ps1`
  moves strays to `_vrport_disabled\` rather than deleting them.
- **Nothing else may proxy dxgi.** R.E.A.L. VR installs a `bin\x64\dxgi.dll`; two VR paths in one
  process fight over the same engine hooks. The deploy script stashes it as
  `dxgi.dll.disabled_by_stereo`.

Assets (TweakXL yamls, the packed `.archive`s, captured grip poses) are authored **game-side** —
by hand and by WolvenKit's packer — so the repo copy goes stale the moment anything is repacked.
`sync_assets.ps1` is the only thing that moves them; run the pull before committing.

## Tests

**There are none.** No test target, no test framework, nothing to run. `src/red4ext_plugin/vrik/
vrik_solver.h` (109 lines of two-bone IK, no game coupling) is the one piece that is testable
as-is if tests are ever added.

There is also no lint step. `/W4 /permissive-` is on for the root project but warnings do not fail
the build.

## Versioning and release

`VERSION` at the repo root holds a bare `X.Y.Z`, and **`scripts/ci_version.sh` is the only thing
that computes a version** — never invent one in a workflow step.

| Ref | Version | Effect |
|---|---|---|
| feature branch / PR | `0.1.2-dev.<short-sha>` | artifact only |
| `main` | `0.1.2-rc.N` | artifact + a bare `0.1.2-rc.N` tag, N counts commits since the VERSION bump |
| manual dispatch | `0.1.2` | `release.yml` **promotes** an existing rc |

The release **does not rebuild**. It downloads the zip that rc's build run produced, rewrites the
version where the package names it (`INSTALL.txt`, `fomod/info.xml`), and publishes those exact
binaries — so a player runs what a tester ran. Preserving that property matters more than any
convenience in `release.yml`.

**Tags carry no `v` prefix**, matching the historical ones (`0.0.2` … `0.1.1`). One namespace, and
the duplicate-guard in `release.yml` is correct by construction: it checks the same form the
history already uses, so a version released before CI existed still blocks a re-release. A `v`
typed into the `rc_tag` input is stripped rather than rejected.

## Architecture

### The two plugins and the bridge between them

`CyberpunkVR_Stereo.dll` (OpenXR, the second eye, HUD composite, F10 overlay, XInput merge) and
`CyberpunkVR_Hands.dll` (VRIK avatar, weapon aim, smoking) are **separate RED4ext plugins in
separate folders**. The stereo project must not absorb the hands project.

They communicate through a **1024-byte named shared memory block** (256 floats), created by
whichever module maps it first. `src/common/shared_slots.h` is the single source of truth for the
slot numbering, and **that numbering is frozen** — shipped CET Lua reads raw indices through
`GetVRSharedSlot`, so renumbering breaks installed mods. There is no version field, no magic value
and no size check: a mismatched pair of DLLs maps the same block and reads whatever the other side
now means by that index, silently. Only two slots are seqlock-protected (`[127]` hands, `[143]`
view packet); everything else is a relaxed float write. Take new space from the documented
graveyard or from `>= [151]`, and verify with grep rather than trusting the comment block.

### How the second eye is produced

Not reprojection — it is a real engine view, and understanding it requires reading
`plugin_main.cpp`, `swapchain_hooks.cpp` and `sync_stereo.cpp` together:

1. `src/red4ext_stereo/plugin_main.cpp` hooks `D3D12CreateDevice` **before** the game creates its
   device, to capture the device and queue. RED4ext hands over what the proxy used to intercept.
2. The DXGI factory and swapchain vtables are patched in `src/vr/core/swapchain_hooks.cpp` — the
   swapchain vtable is process-wide, so a throwaway swapchain exposes the table the game presents
   through.
3. An `entRenderToTextureCameraComponent` on the player entity renders the second eye. It is
   identified **by CName hash, never by offset** (`src/vr/stereo/sync_stereo.cpp`) — the one
   version-resistant piece of the design. The CET mod `CyberpunkVRPort_Stereo` exists only to flip
   that component's `isEnabled` via RTTI, which native code cannot do.
4. At the end of that view's `RenderFinal2D` node, a `CopyResource` is appended **into the
   engine's own command list** and a tick is stamped.
5. `CyberpunkVR_GetVrcamEyeTextureFresh` returns `nullptr` once that tick is older than
   `StereoEyeMaxAgeMs` — **that return is the mono fallback** (menus, loading screens).

One VRCAM component is authored per supported resolution. A resolution the launcher offers but the
`.ent` does not carry is a dead menu entry with no second view at all, so
`tools/gen_vrcam_assets.py` reads the resolution ladders **straight out of `launcher_dialog.cpp`**
and regenerates the assets. The launcher is the single source of truth for that list.

### What is pinned to game build 2.31

~130 `_RVA` constants applied as `base + RVA`, plus struct field offsets poked directly (bone
buffers walked at a 48-byte stride, camera object fields, etc.). **There is no game-version guard
anywhere** — no `GetFileVersionInfo`, no byte verification at the hook site — and both plugins
declare `RED4EXT_V1_RUNTIME_VERSION_INDEPENDENT`. On any game patch MinHook will hook whatever now
lives at those addresses. Only the ~18 AOB scans in `src/vr/core/vr_core.cpp` degrade gracefully.
Treat every new hardcoded offset as a liability and prefer a pattern scan or a name hash.

### Global state

The de facto architecture is a bus of ~637 exported `CyberpunkVR_*` mutable globals, not the
mutexes. `src/vr/stereo/sync_stereo.cpp` alone is 13.4k lines with 815 statics and 170 atomics.
Config lives in `bin\x64\vrport.ini`, mtime-polled into a struct of `volatile` fields (volatile is
not synchronisation) and rewritten wholesale by the overlay.

## Repo conventions

- **`.gitignore` ignores `*.ps1` and `*.py` globally**, with per-file negations. A new script is
  invisible to git until it is explicitly un-ignored — check `git status` after adding one.
- `.gitattributes` marks `.archive`/`.dtex`/`.ent`/`.dxil` binary; a WolvenKit repack can produce a
  blob git would otherwise guess as text and corrupt via CRLF conversion on checkout.
- `docs/` holds 84 reverse-engineering notes, roughly half of them recording **dead ends**. Check
  there before re-investigating an engine path — `docs/ida-no-decompile-rule.md` and
  `docs/workflow-static-reverse-first.md` describe the RE workflow in use.
- Comment density runs 21-39% and the comments explain *why*, usually citing the symptom that
  forced the code. Match that when editing; a bare mechanical change in this codebase loses the
  reason it exists.
