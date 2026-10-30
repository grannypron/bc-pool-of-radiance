#!/usr/bin/env bash
#
# Generate obj/BUILDID.INC for the version information on the Options screen. Both build scripts run this before
# compiling, and gamedefs.pas and options.pas include the result from obj/.
#
#   scripts/buildid.sh

set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$root/obj"

# BUILD_VERSION is the latest release tag plus the number of commits since it. Hyphenated tags such as
# v0.0-ci-test are ignored. BUILD_COMMIT is the short commit hash and gains a MODIFIED suffix when src/ or build/
# differs. BUILD_REF overrides HEAD so release jobs can compile an older tag's source from a newer checkout (#849).
# Both values become UNKNOWN when Git metadata is unavailable. Historical sources do not include this file, so their
# output remains byte-identical.
ref="${BUILD_REF:-HEAD}"
describe="$(git -C "$root" describe --tags --long --match 'v[0-9]*' --exclude '*-*' "$ref" 2> /dev/null)"
build_version="UNKNOWN"
if [ -n "$describe" ]; then
    # Convert vX.Y-N-gHASH to vX.Y at the tag itself, or vX.Y-N after it.
    build_version="$(printf '%s' "$describe" | sed -e 's/-g[0-9a-f]*$//' -e 's/-0$//')"
fi
build_commit="$(git -C "$root" rev-parse --short=7 "$ref^{commit}" 2> /dev/null)" || build_commit=""
build_commit="${build_commit:-UNKNOWN}"
if [ "$build_commit" != "UNKNOWN" ] && { ! git -C "$root" diff --quiet "$ref" -- src build 2> /dev/null \
        || [ -n "$(git -C "$root" ls-files --others --exclude-standard -- src build 2> /dev/null)" ]; }; then
    build_commit="$build_commit MODIFIED"
fi
# Keep only characters supported by Pascal strings and the game font, and fit the text to the screen.
build_version="$(printf '%s' "$build_version" | tr -cd 'A-Za-z0-9.+-' | cut -c 1-23)"
build_commit="$(printf '%s' "$build_commit" | tr -cd 'A-Za-z0-9 ' | cut -c 1-23)"
printf "const\r\n  BUILD_VERSION = '%s';\r\n  BUILD_COMMIT = '%s';\r\n" "$build_version" "$build_commit" \
    > "$root/obj/BUILDID.INC"
