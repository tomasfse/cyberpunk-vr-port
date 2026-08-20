---
name: deploy-to-game
description: Install, refresh, or uninstall the mod in a Cyberpunk 2077 game root, and keep game-side assets in step with the repo. Use when asked to deploy, install, push a build to the game, revert an install, sync assets, or when diagnosing a mod that loads but does nothing.
---

# Deploying to a game root

```powershell
pwsh scripts/deploy_stereo.ps1 -GameRoot "<game root>"   # install / refresh
pwsh scripts/revert_stereo.ps1 -GameRoot "<game root>"   # uninstall, restore stashed dxgi.dll
pwsh scripts/sync_assets.ps1   -GameRoot "<game root>"   # pull game-authored assets into the repo
```

The game root is the folder containing `bin\`, `r6\`, `red4ext\` and `archive\`. Build first —
`deploy_stereo.ps1` refuses to run if the plugin is missing, and refuses if `Cyberpunk2077.exe` is
running because the DLL is locked.

## Two invariants that have each caused a crash

**A spare `.dll` in a plugin folder is a second copy of the plugin, not a backup.** RED4ext loads
every `.dll` under `red4ext\plugins\`, by file, not by folder name. A renamed backup beside the
real build gets loaded too: two sets of registered natives and two sets of pattern-scan detours
over the same addresses, the second writing its jump over the first's trampoline. The observed
symptom was a read of inaccessible data at `0xFFFFFFFFFFFFFFFF` with no stack. The deploy script
moves strays into `<game root>\_vrport_disabled\` — it moves rather than deletes, because the
difference between a backup and a second plugin is only which directory RED4ext scans.

**Nothing else may proxy dxgi.** This build is a RED4ext plugin and does not proxy anything. R.E.A.L.
VR and similar mods install a `bin\x64\dxgi.dll`; two VR paths in one process fight over the same
engine hooks. The deploy stashes it as `dxgi.dll.disabled_by_stereo` and `revert_stereo.ps1` puts
it back.

## What the deploy actually touches

- `red4ext\plugins\CyberpunkVR_Stereo\` — the DLL, both `.dxil` sight shaders, and the staged
  `UserSettings.json`. **Both shader blobs must be present**: the PSO replacement is skipped
  entirely if either is missing, and the only symptom is one line in the log.
- `bin\x64\plugins\cyber_engine_tweaks\mods\CyberpunkVRPort_Stereo\` — replaced wholesale, but
  `bridge\vrcam_enable.txt` / `vrcam_active.txt` and the user's resolution pick out of `vrcam.json`
  are carried across. The pick is carried, not the whole file: keeping the installed `vrcam.json`
  wholesale is how the catalogue goes stale and the launcher stops offering a newly added
  resolution.
- The other CET mods (`Smoking`, `Holster`, `Weapon`, `HUD`, `VRIK`, `Crosshair`, `WorldMap`) are
  **refreshed only if already installed**. This script is not a mod installer; it exists to stop
  the copies drifting apart. A bridge left on an old copy keeps logging per frame regardless of the
  launcher's DEBUG checkbox.
- Game-side assets, via `sync_assets.ps1 -Push`.

`UserSettings.json` is staged, not applied. The plugin copies it over the player's own settings
exactly once, on the first launch with `first_launch=0` in `vrport.ini`, keeping a timestamped
backup. That decision belongs to the flag, not to whoever ran the deploy.

## Asset sync direction

`sync_assets.ps1` defaults to **pull** (game → repo) and takes `-Push` for the reverse.

The TweakXL yamls are edited by hand game-side and the two `.archive`s are produced by WolvenKit's
packer, which writes to `packed\archive\pc\mod` in the WolvenKit project and stops there. So:

- **Before committing asset changes**: run the pull. A stale repo copy is worse than none — it
  ships an old cigarette definition alongside a new archive.
- The pull also checks the WolvenKit project (`~\Documents\CyberpunkVRPort` by default) for a
  fresher pack and pushes it to the game first, so it does not copy a stale one back into the repo.
- The captured grip poses (`CyberpunkVR_*Grip*.ini`) are written next to the exe by
  `VRSmokeDumpFingers` and exist **only game-side** until something pulls them. Without them the
  smoking mod loads, reports its poses resolved, and holds nothing.

## Where to look when something is wrong

| File | What it holds |
|---|---|
| `bin\x64\cyberpunkvrport.log` | the plugin's own log — start here, and the right file for a bug report |
| `red4ext\logs\` | plugin load errors and **redscript compilation** errors |
| per-mod CET folders | one log each, gated on the same DEBUG switch |

If redscript compilation fails, **every** redscript mod is off, not just the one that failed — so a
cluster of unrelated features breaking at once points at `red4ext\logs\`, not at the features.

The launcher's DEBUG tick-box arms every diagnostic probe at once and costs both frame time and a
very large log. It is for diagnosis, not for play.
