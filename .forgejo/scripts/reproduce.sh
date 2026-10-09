#!/usr/bin/env bash
#
# reproduce.sh -- build a tag's source with the current scripts and require SSI's exact bytes.
#
#   .forgejo/scripts/reproduce.sh v1.3
#
# The tag's src/ and build/ replace the working tree's, build.sh builds them, and obj/START.EXE and obj/GAME.OVR
# must match the tag's lines in .forgejo/ssi-releases.txt. It proves the toolchain and the scripts still reproduce
# SSI's releases as the source moves on.

set -eu

tag="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
list="$root/.forgejo/ssi-releases.txt"

expected="$(awk -v t="$tag" '$1 == t { print $3 "  " $2 }' "$list")"
[ -n "$expected" ] || { echo "reproduce.sh: $tag has no lines in .forgejo/ssi-releases.txt" >&2; exit 2; }

cd "$root"
rm -rf src build
git checkout "$tag" -- src build
./build.sh

if (cd obj && echo "$expected" | sha256sum --check --strict); then
    echo "reproduce.sh: $tag is byte-identical to SSI's release"
else
    echo "reproduce.sh: $tag no longer matches SSI's release" >&2
    exit 1
fi
