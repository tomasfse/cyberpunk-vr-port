# Building and releasing

The mod is built by GitHub Actions and nowhere else. A local `cmake --build` is still the right
way to iterate — `scripts\deploy_stereo.ps1` drops the result straight into the game — but the
package a tester or a player installs always comes out of a CI run, so "which build is that" has
an answer that does not depend on whose machine it was compiled on.

## Versioning

`VERSION` at the repo root holds a bare `X.Y.Z`: the number the **next** release will carry.
Everything else is derived from it by `scripts/ci_version.sh`, which is the only thing in the
repo that decides a version.

| Where the commit lands | Version            | What happens                                    |
| ---------------------- | ------------------ | ----------------------------------------------- |
| feature branch, PR     | `0.1.2-dev.a1b2c3d`| package uploaded as a run artifact               |
| `main`                 | `0.1.2-rc.4`       | package uploaded, commit tagged `v0.1.2-rc.4`    |
| release                | `0.1.2`            | cut by hand from an rc, see below                |

The short sha makes every feature build name the exact commit it came from — two people testing
"the branch" can tell whether they are testing the same thing. The rc number counts commits on
`main` since `VERSION` last changed, so it restarts at `rc.1` on a version bump and never skips.
The ordering falls out of SemVer on its own: `0.1.2-dev.*` < `0.1.2-rc.*` < `0.1.2`.

To aim at a different release number, bump `VERSION` on `main`; that commit becomes `rc.1` of it.

## What CI builds

`.github/workflows/build.yml`, on `windows-latest`:

1. `CyberpunkVR_Stereo.dll` — the root CMake project, `Release`.
2. `CyberpunkVR_Hands.dll` — `src/red4ext_plugin`, its own project, `RelWithDebInfo`.
3. `scripts/build_dist.ps1 -Zip` — assembles the game-root layout and zips it.

Two artifacts come out of each run: `CyberpunkVRPort-<version>` (the installable zip) and
`CyberpunkVRPort-<version>-symbols` (the PDBs). The PDBs ship nowhere, but a crash dump against
that build is unreadable without them and the build tree dies with the runner.

## Cutting a release

Releases are manual and always promote a release candidate that already exists:

> Actions → **release** → Run workflow → `rc_tag: v0.1.2-rc.3`

It does not rebuild. It downloads the package that rc's build run produced, restamps the version
line in `INSTALL.txt`, tags the commit `v0.1.2` and publishes the release with
`CyberpunkVRPort-0.1.2.zip` attached. The DLLs a player downloads are byte-for-byte the ones the
testers ran — recompiling "the same commit" would hand out binaries nobody has tested.

Inputs: `version` overrides the derived number (`v0.1.2-rc.3` → `0.1.2`), and `draft` /
`prerelease` are there when a release wants a second look before it is public.

It refuses to run if the rc tag does not exist, if that commit has no successful build run, or if
`v0.1.2` is already tagged — bump `VERSION` on `main` first in that last case.

Artifacts are kept 90 days. Promoting an rc older than that has nothing left to download; build a
fresh rc from `main` and promote that.
