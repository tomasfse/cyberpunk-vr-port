---
name: build-plugins
description: Build the two RED4ext plugins and package an installable zip. Use when asked to build, compile, rebuild, or package the mod, when a build fails, or before deploying to a game root. Covers the two-project layout, the load-bearing build configurations, and the failure modes that produce a package which looks fine and ships a stale DLL.
---

# Building CyberpunkVRPort

## The thing that goes wrong

This repo is **two independent CMake projects**, not one tree with two targets:

| Project | Source | Build dir | Config | Produces |
|---|---|---|---|---|
| root | `.` | `build/` | `Release` | `CyberpunkVR_Stereo.dll` |
| hands | `src/red4ext_plugin` | `src/red4ext_plugin/build/` | `RelWithDebInfo` | `CyberpunkVR_Hands.dll` |

`scripts/build_dist.ps1` hard-codes both output paths, including the configuration directory. Build
the root project only and packaging still succeeds — it picks up whatever `CyberpunkVR_Hands.dll`
was left in the tree from an earlier build. The zip looks correct and ships a stale plugin against
a current shared-memory slot map. Always build both, or delete the hands build dir first so the
packaging step fails loudly instead.

## Full build

```powershell
git submodule update --init --recursive   # only on a fresh clone

cmake -S . -B build -A x64
cmake --build build --config Release --parallel

cmake -S src/red4ext_plugin -B src/red4ext_plugin/build -A x64
cmake --build src/red4ext_plugin/build --config RelWithDebInfo --parallel

pwsh scripts/build_dist.ps1 -Version "$(Get-Content VERSION)" -Zip
```

Output lands in `dist\CyberpunkVRPort-<version>\` laid out exactly as it must sit in the game root,
plus a `.zip` when `-Zip` is passed. The script prints a manifest with byte counts — read it. A
component that silently did not build shows up there as a missing line, and several of them fail
soft at runtime with one line in a log.

## Iterating on one plugin

Stereo plugin only (the common case — it is where most work happens):

```powershell
cmake --build build --config Release --target cyberpunkvrport_stereo
```

The CMake **target** is `cyberpunkvrport_stereo`; the shipped **file** is `CyberpunkVR_Stereo.dll`.
They are not the same string and never have been.

The hands project has no equivalent shortcut — its only target is the plugin.

## What the root build also produces, and why it does not matter

`tools/xr_probe` is added unconditionally, without `EXCLUDE_FROM_ALL`, so a bare
`cmake --build build --config Release` also builds `xr_probe_layer` and `xr_probe_cli` despite the
comments saying to build them by name. They are never packaged. If you are cutting build time,
that is a real target to prune — but it is not a packaging risk.

## Dependencies

- **FetchContent on configure**: OpenXR-SDK `release-1.0.34`, imgui `v1.90.9`. Cached in
  `build/_deps`. Deleting `build/` re-downloads them.
- **Submodules**: MinHook, RED4ext.SDK. Note that RED4ext.SDK points at a personal fork
  (`marklove5102`), not upstream.
- MinHook sources are compiled into the `imgui` static library in the root project and into a
  separate `minhook` target in the hands project. That asymmetry is confusing but intentional-ish;
  do not "fix" it without checking both link lines.

## Symbols

Release builds carry `/Zi` with `/DEBUG /OPT:REF /OPT:ICF`. The optimiser is unaffected — `/DEBUG`
disables `/OPT:REF` and `/OPT:ICF` by default, so they are restored explicitly, and without that
the binary would genuinely change. The PDB stays in the build tree and ships nowhere; CI archives
it as a separate artifact. A crash dump from a build is unreadable without the matching PDB, so
never discard one while a build is still in testers' hands.

## Build failures worth recognising

- **`FetchContent_Populate` deprecation/removal** — the root `CMakeLists.txt` uses the single-arg
  form, deprecated in CMake 3.30 and removed in 4.0. CI does not pin the generator or the CMake
  version, so a runner image bump can break this without a code change.
- **Stale `build/_deps` after a toolchain change** — the CI cache key is
  `deps-<os>-<hash of CMakeLists.txt>` and does not include the MSVC version, so objects built by
  an older compiler can be restored under a newer one. Locally: delete `build/_deps`.
- **A missing submodule** surfaces as a missing `RED4ext.hpp` or MinHook header, not as a git error.
