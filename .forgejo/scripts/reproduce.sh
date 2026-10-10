#!/usr/bin/env bash
#
# reproduce.sh -- build a tag's source with the current scripts and require SSI's exact bytes.
#
#   .forgejo/scripts/reproduce.sh v1.3
#
# The tag is checked out into a temporary worktree, this checkout's build.sh builds it there, and its obj/START.EXE
# and obj/GAME.OVR must match the tag's lines in .forgejo/ssi-releases.txt. It proves the toolchain and the scripts
# still reproduce SSI's releases as the source moves on. This checkout's src/, build/ and obj/ are left as they are.
# TOOLS is the folder holding the DOS toolchains, as for build.sh; it defaults to this checkout's drive_c.

set -eu

tag="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
list="$root/.forgejo/ssi-releases.txt"

expected="$(awk -v t="$tag" '$1 == t { print $3 "  " $2 }' "$list")"
[ -n "$expected" ] || { echo "reproduce.sh: $tag has no lines in .forgejo/ssi-releases.txt" >&2; exit 2; }

# The worktree has no drive_c of its own.
export TOOLS="${TOOLS:-$root/drive_c}"

work="$(mktemp -d)"
trap 'git -C "$root" worktree remove --force "$work" 2> /dev/null || rm -rf "$work"; git -C "$root" worktree prune' EXIT
git -C "$root" worktree add --quiet --detach "$work" "$tag" \
    || { echo "reproduce.sh: cannot check out $tag into a worktree" >&2; exit 2; }
# The tag's src/ and build/, built by the current build.sh.
cp "$root/build.sh" "$work/build.sh"
"$work/build.sh"

if (cd "$work/obj" && echo "$expected" | sha256sum --check --strict); then
    echo "reproduce.sh: $tag is byte-identical to SSI's release"
else
    echo "reproduce.sh: $tag no longer matches SSI's release" >&2
    exit 1
fi
