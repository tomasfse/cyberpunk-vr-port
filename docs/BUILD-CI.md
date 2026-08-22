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
| `main`                 | `0.1.2-rc.4.a1b2c3d` | tagged, and published as a GitHub **prerelease** |
| release                | `0.1.2`            | cut by hand from an rc, see below                |

The short sha makes every build name the exact commit it came from — two people testing "the
branch" can tell whether they are testing the same thing, and an rc that does not match its own
tag is visible in the filename instead of silent. The rc number counts commits on
`main` since `VERSION` last changed, so it restarts at `rc.1` on a version bump and never skips.
The ordering falls out of SemVer on its own: `0.1.2-dev.*` < `0.1.2-rc.*` < `0.1.2`.

To aim at a different release number, bump `VERSION` on `main`; that commit becomes `rc.1` of it.

## What CI builds

`.github/workflows/build.yml`, on `windows-latest`:

1. `CyberpunkVR_Stereo.dll` — the root CMake project, `Release`.
2. `CyberpunkVR_Hands.dll` — `src/red4ext_plugin`, its own project, `RelWithDebInfo`.
3. `scripts/build_dist.ps1 -Zip` — assembles the game-root layout and zips it.

Two artifacts come out of each run: `CyberpunkVRPort-<version>` (the installable package) and
`CyberpunkVRPort-<version>-symbols` (the PDBs). The PDBs ship nowhere, but a crash dump against
that build is unreadable without them and the build tree dies with the runner.

## Release candidates

Every push to `main` is a candidate. It is tagged, and the package is published as a GitHub
**prerelease** carrying `CyberpunkVRPort-<version>.zip`.

That prerelease is what makes an rc reachable by a tester. A run artifact needs a signed-in GitHub
account to download and is deleted after 90 days; a release asset is a public URL that does not
expire. Prereleases never take the "Latest" badge, so a real release still stands out on the
releases page.

The cost is one prerelease per commit on `main`. That is the intent — every commit on `main` is a
candidate by design — but the releases page grows accordingly.

## Cutting a release

You write the release; CI attaches the binary.

> GitHub → **Releases** → Draft a new release → tag `0.1.3`, write the notes, **Publish**

Publishing fires `release.yml`, which finds the release candidate built from **that same commit**,
restamps the version the package names, and attaches `CyberpunkVRPort-0.1.3.zip`. Nothing is
rebuilt: the zip is the one that rc's build produced, so what ships is what a tester ran.

It matches by commit rather than by "the newest rc" because the release tag already names one —
there is nothing to type and nothing to get wrong, and the newest rc is the wrong answer outright
when a release is cut from an earlier commit. Every commit on `main` gets an rc, so whichever
commit you pick has one waiting.

The package comes from the rc's own **prerelease asset**, not from its build run's artifact, so
there is no 90-day limit on how old a candidate may be.

It refuses, rather than guessing, if the tag is not a bare `X.Y.Z`, if no rc was built from that
commit, or if the rc's asset does not look like a package. The restamp verifies itself in both
`INSTALL.txt` and `fomod/info.xml` and fails rather than publish a mislabelled package.

Two things to know:

- **Drafts do not trigger workflows.** GitHub fires `release` only on publish, so the asset appears
  a minute or two after the release goes public. Write the notes in the draft; publish when ready.
- **Bump `VERSION` on `main`** when a release ships, so the next candidate series is numbered for
  the next version rather than the one just published.
