#!/usr/bin/env bash
#
# Build a historical tag with the current scripts and verify SSI's exact bytes.
#
#   .forgejo/scripts/reproduce.sh v1.3
#
# The tag is checked out in a temporary worktree and built with this checkout's build.sh. START.EXE and GAME.OVR
# must match the hashes in .forgejo/ssi-releases.txt. This catches toolchain or script changes that break historical
# reproduction without touching the current checkout's src/, build/, or obj/. TOOLS has the same meaning as in
# build.sh and defaults to this checkout's drive_c.

set -eu

tag="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
list="$root/.forgejo/ssi-releases.txt"

expected="$(awk -v t="$tag" '$1 == t { print $3 "  " $2 }' "$list")"
[ -n "$expected" ] || { echo "reproduce.sh: $tag has no lines in .forgejo/ssi-releases.txt" >&2; exit 2; }

# Reuse this checkout's DOS toolchain because the temporary worktree has no drive_c.
export TOOLS="${TOOLS:-$root/drive_c}"

work="$(mktemp -d)"
trap 'git -C "$root" worktree remove --force "$work" 2> /dev/null || rm -rf "$work"; git -C "$root" worktree prune' EXIT
git -C "$root" worktree add --quiet --detach "$work" "$tag" \
    || { echo "reproduce.sh: cannot check out $tag into a worktree" >&2; exit 2; }
# Keep the tag's src/ and build/ directories, but replace its build driver with the current one.
cp "$root/build.sh" "$work/build.sh"
"$work/build.sh"

if (cd "$work/obj" && echo "$expected" | sha256sum --check --strict); then
    echo "reproduce.sh: $tag is byte-identical to SSI's release"
else
    echo "reproduce.sh: $tag no longer matches SSI's release" >&2
    exit 1
fi
