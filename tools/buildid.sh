#!/usr/bin/env bash
#
# buildid.sh -- write obj/BUILDID.INC, which names the source for the Options screen. build.sh and build-native.sh run
# it before compiling; gamedefs.pas and options.pas include the file from obj/.
#
#   tools/buildid.sh

set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$root/obj"

# BUILD_VERSION is the last release tag (v1.3, not tags with a hyphen such as v0.0-ci-test) and the commits since it,
# BUILD_COMMIT the commit, with MODIFIED when src/ or build/ differs from it. The commit is BUILD_REF, or HEAD when that
# is unset: a release of an older tag checks out only that tag's src/ and build/, and names the tag in BUILD_REF (#849).
# Without git, or outside a repository, both read UNKNOWN. A source that does not include the file, as SSI's tags do
# not, builds the same bytes as before.
ref="${BUILD_REF:-HEAD}"
describe="$(git -C "$root" describe --tags --long --match 'v[0-9]*' --exclude '*-*' "$ref" 2> /dev/null)"
build_version="UNKNOWN"
if [ -n "$describe" ]; then
    # vX.Y-N-gHASH: the tag alone when N is 0, else the tag and N
    build_version="$(printf '%s' "$describe" | sed -e 's/-g[0-9a-f]*$//' -e 's/-0$//')"
fi
build_commit="$(git -C "$root" rev-parse --short=7 "$ref^{commit}" 2> /dev/null)" || build_commit=""
build_commit="${build_commit:-UNKNOWN}"
if [ "$build_commit" != "UNKNOWN" ] && { ! git -C "$root" diff --quiet "$ref" -- src build 2> /dev/null \
        || [ -n "$(git -C "$root" ls-files --others --exclude-standard -- src build 2> /dev/null)" ]; }; then
    build_commit="$build_commit MODIFIED"
fi
# Only characters a Pascal string and the game font take, and no longer than the screen shows.
build_version="$(printf '%s' "$build_version" | tr -cd 'A-Za-z0-9.+-' | cut -c 1-23)"
build_commit="$(printf '%s' "$build_commit" | tr -cd 'A-Za-z0-9 ' | cut -c 1-23)"
printf "const\r\n  BUILD_VERSION = '%s';\r\n  BUILD_COMMIT = '%s';\r\n" "$build_version" "$build_commit" \
    > "$root/obj/BUILDID.INC"
