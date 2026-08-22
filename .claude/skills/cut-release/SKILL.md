---
name: cut-release
description: Version, tag and publish a CyberpunkVRPort release through GitHub Actions. Use when asked to cut a release, bump the version, promote a release candidate, or diagnose why a build produced the wrong version string or why a promotion failed.
---

# Cutting a release

## The rule the whole design rests on

**A release never rebuilds.** `release.yml` downloads the zip that the rc's build run already
produced, rewrites the version where the package names it (`INSTALL.txt` and `fomod/info.xml`),
and publishes those exact binaries. Recompiling "the same commit" would quietly hand players
binaries nobody tested — different compiler, different runner image, different result. Any change
to `release.yml` must preserve this.

## Where versions come from

`VERSION` at the repo root holds a bare `X.Y.Z`. **`scripts/ci_version.sh` is the only thing that
computes a version**; a number invented in a YAML step is a number that drifts.

| Ref | Version | What happens |
|---|---|---|
| feature branch / PR | `0.1.2-dev.<short-sha>` | artifact only |
| `main` | `0.1.2-rc.N.<short-sha>` | artifact + a bare tag of that name |
| manual dispatch of `release.yml` | `0.1.2` | promotes an existing rc |

`N` counts commits since `VERSION` last changed, so the bump commit is itself `rc.1` and a fresh
`X.Y.Z` never starts at `rc.0`. Bump `VERSION` when the *next* release should carry a different
number — that restarts `N` on its own.

Run it locally to see what a ref would produce:

```bash
VERSION_REF_NAME=main VERSION_REF_TYPE=branch bash scripts/ci_version.sh
```

## Publishing

1. Land the work on `main`. Every push to `main` builds and tags an rc automatically.
2. Have a tester run that rc's artifact. That is the point of the rc existing.
3. `Actions → release → Run workflow`, `rc_tag: 0.1.2-rc.3.a1b2c3d`. Optionally override
   `version`, or tick draft/prerelease.

The workflow refuses to promote a tag that does not exist, a malformed `rc_tag`, or a version that
is already tagged.

## Traps

**Artifacts expire after 90 days.** The run record lives forever, so promoting an older rc gets
past the "no successful build run" check and then fails opaquely inside `gh run download`. If a
release cycle is going to run long, promote sooner or re-run the build.

**Tags are bare — no `v` prefix.** That is the author's existing convention (`0.0.2` … `0.1.1`) and
CI follows it, so there is one namespace and the duplicate-guard sees the hand-made history too.
Do not reintroduce a `v`: it would split the namespace and make the guard blind to everything
released before CI existed.

**The tag is pushed before the release is created.** If `gh release create` fails, the tag is
already on origin and the next attempt hits "already tagged — bump VERSION on main". Recovering
means deleting the remote tag by hand.

**`--generate-notes` measures from the previous tag**, and every build of `main` leaves an rc tag —
so generated notes cover only the commits since the last rc, not since the last release. Write the
notes by hand for anything user-facing.

**Do not cancel a build of `main`.** rc numbers are derived from a commit count, so a cancelled
build leaves a permanent hole in the sequence and an rc that can never be released. The concurrency
group is configured to skip cancellation on `main` for exactly this reason.

## Checklist before promoting

- [ ] `VERSION` reflects the number you intend to ship
- [ ] The rc tag exists and its build run succeeded
- [ ] Someone actually ran that artifact
- [ ] `0.1.2` is not already tagged (the workflow checks this too)
- [ ] The rc build is younger than 90 days
- [ ] `README.md` requirements still match reality (game version, dependency list)
- [ ] Assets were pulled with `sync_assets.ps1` before the commit that produced the rc
