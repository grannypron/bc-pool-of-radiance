#!/usr/bin/env bash
#
# List what changed from one release to another as Markdown bullets, for release notes.
#
#   .forgejo/scripts/changes.sh v1.3-1560 [REF]
#
# One bullet per commit on REF's first-parent line (HEAD by default) since BASE: a merged pull request appears as its
# title and number, any other commit as its subject. Newest first; past 200 the rest are counted, not listed. Prints
# nothing when REF is BASE.

set -euo pipefail

base="${1:?Usage: changes.sh BASE [REF]}"
ref="${2:-HEAD}"
max=200

git log --first-parent --format='%s' "$base..$ref" \
    | sed -E "s/^Merge pull request '(.*)' \((#[0-9]+)\) from .*$/\1 (\2)/" \
    | awk -v max="$max" 'NR <= max { print "- " $0 } END { if (NR > max) print "- ...and " NR - max " more" }'
