#!/usr/bin/env bash
#
# The single place that decides what version a build carries. Both workflows call it and nothing
# else computes a version -- a number invented inside a YAML step is a number that drifts.
#
#   feature branch / PR      X.Y.Z-dev.<short-sha>    0.1.2-dev.a1b2c3d
#   main                     X.Y.Z-rc.N               0.1.2-rc.4
#   tag v<semver>            <semver>                 0.1.2
#
# X.Y.Z is read from the VERSION file at the repo root. Bump it when the NEXT release should carry
# a different number; N restarts at 1 with that bump, because it counts the commits made since
# VERSION last changed. That also makes the ordering come out right on its own: "dev" sorts before
# "rc" as a SemVer pre-release identifier, and both sort before the bare X.Y.Z of the release.
#
# Usage:
#   scripts/ci_version.sh                       # infer from the checkout / GitHub env
#   scripts/ci_version.sh <ref-name> <ref-type> <sha>
#
# Writes `key=value` lines on stdout, ready to be appended to $GITHUB_OUTPUT.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

ref_name=${1:-${VERSION_REF_NAME:-${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD)}}}
ref_type=${2:-${VERSION_REF_TYPE:-${GITHUB_REF_TYPE:-branch}}}
sha=${3:-${VERSION_SHA:-${GITHUB_SHA:-$(git rev-parse HEAD)}}}

default_branch=${VERSION_DEFAULT_BRANCH:-main}

if [[ ! -f VERSION ]]; then
    echo "VERSION file not found at $repo_root/VERSION" >&2
    exit 1
fi
base=$(tr -d '[:space:]' < VERSION)
if [[ ! $base =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must contain a bare X.Y.Z, got: '$base'" >&2
    exit 1
fi

short=$(git rev-parse --short=7 "$sha")
# A pre-release identifier made only of digits may not carry a leading zero, and roughly one short
# sha in 270 is exactly that. Prefixing it the way git-describe does keeps the version valid.
if [[ $short =~ ^[0-9]+$ ]]; then
    short="g$short"
fi

case "$ref_type" in
tag)
    tag=${ref_name#v}
    if [[ ! $tag =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
        echo "tag '$ref_name' is not v<semver>" >&2
        exit 1
    fi
    version=$tag
    channel=release
    ;;
*)
    if [[ $ref_name == "$default_branch" ]]; then
        # Commits on main since VERSION last changed. The commit that does the bump is itself
        # rc.1, so a fresh X.Y.Z never starts at rc.0 or skips a number.
        bump=$(git log -1 --format=%H -- VERSION || true)
        if [[ -n $bump ]]; then
            n=$(git rev-list --count "$bump..$sha")
        else
            n=$(git rev-list --count "$sha")
        fi
        version="$base-rc.$((n + 1))"
        channel=rc
    else
        version="$base-dev.$short"
        channel=dev
    fi
    ;;
esac

echo "version=$version"
echo "base=$base"
echo "channel=$channel"
echo "short_sha=$short"
echo "tag=v$version"
echo "artifact=CyberpunkVRPort-$version"
