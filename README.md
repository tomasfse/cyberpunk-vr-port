# CyberpunkVR Port

A 6-DoF **VR mod for Cyberpunk 2077**, built as a **RED4ext plugin** — there is no
`dxgi.dll` proxy any more. `CyberpunkVR_Stereo` drives OpenXR head tracking, real
stereo and the in-headset overlay; `CyberpunkVR_Hands` drives a **full-body VR
avatar with motion-controlled hands**; and a set of CET / redscript mods add VR
weapon aiming, motion melee, hand-to-holster equipping, a VR-friendly HUD and
more. Everything is configured from an in-headset **F10** overlay.

Repository: <https://github.com/dariulone/cyberpunk-vr-port>

> ⚠️ Experimental community mod. Not affiliated with CD PROJEKT RED. Use at your
> own risk and keep backups of your saves.

## Features

- **Real stereo, not reprojection.** The second eye is an actual engine view — a
  render-to-texture camera on the player entity that runs the frame graph for its
  own eye, from its own position, with its own projection. It falls back to mono
  automatically whenever that view has nothing fresh to give (menus, loading).
- **OpenXR head tracking** injected into the REDengine render path, with the
  submitted frustum matching the one the engine actually rendered on both axes,
  plus world-scale / IPD controls.
- **The game HUD in both eyes** — the engine's own HUD composite is ported
  shader-for-shader for the second eye, and placed at a finite distance so icons
  fuse instead of splitting.
- **Full-body VR avatar** (VRIK) — body under the HMD, arm-length calibration,
  leg IK, real-life squat. Hands are with the controllers.
- **Decoupled VR weapon aim** — bullets follow the real weapon muzzle, not the
  camera; optional barrel dot in both eyes, scope-zoom aware.
- **Collimated reflex sights** — the reticle is placed by angle along the sight's
  own optical axis, so it stays on the bore instead of sliding across the glass
  when you look at the sight from the side.
- **VR motion melee** — real swings trigger the game's native melee along the
  blade (native damage/reaction/stamina).
- **Hand-to-holster** equip/unequip on a grip squeeze — *immersive* (by visual
  holster) or *simple* (fixed weapon slots).
- **VR smoking** — cigarette and lighter as real props, with a captured
  finger grip, a hands-free mouth anchor and the game's own FX and audio.
- **VR controller mapping** merged into XInput: full-forward = sprint,
  full-down = crouch, snap or smooth turn, HMD/hand-relative locomotion, D-pad
  chord.
- **VR HUD** with per-element placement & scale, **world-map head-lock**, CAS
  sharpening, and DLSS/NGX handling (the second view gets its own upscaler
  viewport automatically).
- **In-headset F10 overlay** with tabbed, live, persisted settings.
- SteamVR (OpenVR) runtime supported alongside OpenXR; pre-launch resolution
  selector; quiet-by-default logging with a DEBUG toggle in the launcher.

See [`docs/`](docs/) for engineering notes, and
[`docs/RELEASE-0.1.0.txt`](docs/RELEASE-0.1.0.txt) for how the stereo path is
actually built.

## Installation dependencies

All on Nexus except the OpenXR runtime, which comes with your headset software.

**Required**

- Cyberpunk 2077 (PC, **2.31**)
- [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380)
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107)
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [ArchiveXL](https://www.nexusmods.com/cyberpunk2077/mods/4198)
- [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197)
- [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780) — 1.20 or newer
- An OpenXR runtime, started **before** the game

Install RED4ext, CET and redscript first.

**Optional**

- [Equipment-EX](https://www.nexusmods.com/cyberpunk2077/mods/6945) — VR smoking props
- [Visual Holsters](https://www.nexusmods.com/cyberpunk2077/mods/21936) — immersive
  holster mode; simple mode works without it

**Recommended**

- [Visible Bullets](https://www.nexusmods.com/cyberpunk2077/mods/22251)
- [Nova Optics](https://www.nexusmods.com/cyberpunk2077/mods/29190)

## Development dependencies

What a **contributor** needs. None of this is required to play.

To build the plugins:

- CMake 3.24+, MSVC (x64 toolset), the Windows SDK, and `pwsh`.
- Submodules: MinHook, RED4ext.SDK — `git submodule update --init --recursive`.
- Pulled automatically by `FetchContent` on configure: OpenXR-SDK 1.0.34,
  imgui 1.90.9. `im3d` is vendored in `externals/`.

Only to re-author game assets — not needed to build or to change any C++:

- Python 3, for `tools/gen_vrcam_assets.py` (the VRCAM components, one per
  render resolution).
- WolvenKit, to import the generated JSON and repack the `.archive`.

The sight shaders ship as pre-built `.dxil` blobs committed to the repo; there is
no shader compilation step in the build. The other passes (depth resolve, colour
blit, sharpen) compile their HLSL at runtime through `d3dcompiler`.

## Installation

### Before you install

1. Install the required mods and **start the game once**.
2. Turn off overlays — OpenXR Toolkit, RivaTuner, the NVIDIA and Steam overlays,
   Discord.
3. Graphics settings: everything **Low**; Film Grain, Chromatic Aberration,
   Motion Blur, Lens Flare, Depth of Field and Frame Generation **off**; display
   mode **borderless window**.
4. Coming from an earlier build of this mod? Delete `bin\x64\dxgi.dll`.

### With Vortex or MO2

Install the release zip as-is. It does not check the required mods for you —
install those first.

### By hand

Download the release archive and extract its contents into your **Cyberpunk 2077
game root** (the folder that contains `bin\`, `r6\`, `red4ext\`). The files land
as:

```
red4ext\plugins\CyberpunkVR_Stereo\CyberpunkVR_Stereo.dll     # the VR plugin: OpenXR, stereo, overlay
red4ext\plugins\CyberpunkVR_Stereo\CyberpunkVR_Sight*.dxil    # sight shaders, loaded by name at PSO swap
red4ext\plugins\CyberpunkVR_Hands\CyberpunkVR_Hands.dll       # native plugin (avatar/hands, weapon aim, shared bridge)
bin\x64\plugins\cyber_engine_tweaks\mods\CyberpunkVRPort_*\   # CET mods: Stereo (VRCAM select), HUD, Holster, VRIK, Weapon, WorldMap
r6\scripts\CyberpunkVRPort_*\                                 # redscript: HUD, Holster, Melee, NoAnims, WeaponUp, WorldMap
```

Then **start your OpenXR runtime first**, and launch the game.

> There is no `dxgi.dll` any more — this is a RED4ext plugin. Anything else that
> proxies dxgi (R.E.A.L. VR, for one) must be out of `bin\x64` or the two fight
> over the same engine hooks; `scripts\deploy_stereo.ps1` moves one aside for you.

> Keep only one `.dll` in each `red4ext\plugins\CyberpunkVR_*` folder. RED4ext
> loads **every** DLL it finds there, so a renamed backup beside the real build
> loads as a second copy of the plugin and the two fight over the same hooks.

From a source tree, install with:

```
cmake --build build --config Release --target cyberpunkvrport_stereo
pwsh scripts\deploy_stereo.ps1 -GameRoot "<game root>"
```

## Builds and releases

Packages are produced by GitHub Actions, not by hand. Every push gets an
installable zip as a run artifact, versioned from `VERSION` at the repo root:
`0.1.2-dev.<short-sha>` on a feature branch, `0.1.2-rc.N` on `main` (tagged as
it is built), and a plain `0.1.2` release cut manually by promoting one of those
rc builds — the same binaries, not a rebuild. See [docs/BUILD-CI.md](docs/BUILD-CI.md).

## Controls

VR controller input is merged into the native CP2077 gamepad, so the in-game
"Controller" key bindings apply. Default VR mapping:

| Input | Action |
|---|---|
| Left stick | Walk / strafe — **push fully forward = sprint** |
| Right stick X | Turn camera (snap or smooth) |
| Right stick **fully down** | **Crouch** (R3) |
| Right trigger / Left trigger | Fire / Aim |
| Right grip | Hand-to-holster equip / unequip; melee power modifier |
| Left grip | Crouch (shoulder) |
| A / B | Jump / Dodge |
| X / Y | Reload·interact / Weapon switch |
| Right thumb click | Crouch (R3) |
| Left menu button | Pause menu |
| Swing a melee weapon | VR motion melee (native attack along the blade) |

**D-pad chord.** Hold the **left stick clicked in**, then pick the direction with
the **right stick** — up / down / left / right. While the chord is held the right
stick is taken out of the camera, so selecting a direction cannot snap-turn you.
Release the left stick *without* having chosen a direction and it emits the normal
L3 (sprint) press instead, so nothing is lost by using it.

Buttons follow each runtime's interaction profile (Touch / Index / Vive / WMR);
customise the actual actions in the game's *Settings → Key Bindings → Controller*.

Hotkeys:

- `F7` — recenter HMD
- `F10` / `Insert` — open the in-headset settings overlay

## In-headset overlay (F10)

Five tabs, live, and saved to `vrport.ini` — nothing here needs a restart.

- **General** — world scale, IPD scale, stereo separation, VR menu FOV and quad
  size, motion prediction, reuse-last-clean-frame, pose pair-lock, and the head
  offset (X right / Y forward / Z up).
- **Controls** — decoupled weapon aim and its laser dot, locomotion source
  (Game / HMD / left hand / right hand), snap turn and angle, immersive holsters.
- **Stereo** — the second eye itself: which eye VRCAM is sent to, how stale its
  last frame may get before the submit falls back to mono, the HUD composite, and
  the live counters that say whether the second view is producing, being captured
  and reaching the headset.
- **VRIK** — start/stop tracking, IK calibration (reach scale, height, elbow
  swing/pole, wrist offset), diagnostics.
- **HUD** — per-element X / Y / scale for every HUD group.

The launcher (before the game starts) picks the render resolution and carries a
**DEBUG** tick-box that arms every diagnostic probe at once. Leave it off for
play: it is for diagnosis and it costs both frame time and a very large log.

## Mod components

| Component | Type | Purpose |
|---|---|---|
| `CyberpunkVR_Stereo.dll` | RED4ext plugin | OpenXR head tracking, the second engine view, HUD composite, sight shaders, F10 overlay, XInput merge |
| `CyberpunkVR_Hands.dll` | RED4ext plugin | Full-body avatar / hand IK, weapon-aim orientation override, smoking poses, shared-memory bridge |
| `CyberpunkVRPort_Stereo` | CET | Enables the VRCAM component the launcher picked |
| `CyberpunkVRPort_VRIK` | CET | Starts hand tracking, bridges calibration |
| `CyberpunkVRPort_Weapon` | CET | Decoupled weapon aim + VR motion-melee detection |
| `CyberpunkVRPort_Holster` | CET + reds | Hand-to-holster equip/unequip (immersive / simple) |
| `CyberpunkVRPort_Smoking` | CET + reds | Cigarette / lighter props, FX, audio, auto-puff |
| `CyberpunkVRPort_HUD` | CET + reds | VR HUD layout |
| `CyberpunkVRPort_WorldMap` | CET + reds | World-map head-lock |
| `CyberpunkVRPort_Melee` | reds | Native melee along the blade segment |
| `CyberpunkVRPort_WeaponUp` | reds | Stops auto-lower / auto-unequip of drawn weapons |
| `CyberpunkVRPort_NoAnims` | reds | Disables VR-fighting animations (keeps gameplay systems) |

## Logs

- `Cyberpunk 2077\bin\x64\cyberpunkvrport.log` — the plugin's own log, and the
  right file for a bug report. Quiet by default; tick **DEBUG** in the launcher
  for per-frame diagnostics.
- `Cyberpunk 2077\red4ext\logs\` — script validation and plugin load errors. If
  redscript compilation fails, *every* redscript mod is off, not just the one that
  failed, so check here first when something stops working all at once.
- Per-mod CET logs live in each mod folder; they follow the same DEBUG switch.

## Test hardware used during development

- Headset: PICO 4 (via VDXR)
- CPU: AMD Ryzen 7 5800X
- GPU: NVIDIA RTX 5070 Ti
- RAM: 32 GB DDR4
- OS: Windows 11 Pro 25H2 (26200)

## Donations

Donating is your personal choice. It speeds up development and makes new features
possible — nobody is forcing you to do it.

- <https://boosty.to/dariulone>
- <https://dalink.to/dariulone>

| | |
|---|---|
| USDT TRC20 | `TRgmDeRcFumXvsSRqYV5kQAqRAvoFKXJCt` |
| USDT BEP20 | `0x4638c6580d1e684bdc60a1c415e5cb1522b66942` |
| TRX | `TRgmDeRcFumXvsSRqYV5kQAqRAvoFKXJCt` |
| BTC | `13AfpBwZvaezf36FmpjtENHTXjYcnzEsze` |
