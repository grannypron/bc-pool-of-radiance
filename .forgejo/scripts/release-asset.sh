#!/usr/bin/env bash
#
# release-asset.sh -- attach one more file to the Forgejo release for a tag, which release.sh has made.
#
#   .forgejo/scripts/release-asset.sh v1.4 dist/pool-of-radiance-v1.4-macos.zip
#
# As release.sh: REPO_API is the event's repository.url and TOKEN the job's token. The release must exist (the job
# runs after release). The new file is attached before an older asset of the same name is removed, so a failed upload
# leaves the release as it was, and its SHA-256 is added to the notes once.

set -euo pipefail

tag="$1"
file="$2"
asset="$(basename "$file")"
api="${REPO_API:?REPO_API is not set: the workflow sets it to the event repository.url}"
auth="Authorization: token $TOKEN"

[ -f "$file" ] || { echo "release-asset.sh: $file is missing." >&2; exit 1; }

release="$(curl -fsS -H "$auth" "$api/releases/tags/$tag")" \
    || { echo "release-asset.sh: no release for $tag: release.sh makes it first." >&2; exit 1; }
id="$(jq -r .id <<< "$release")"

new="$(curl -fsS -X POST -H "$auth" -F "attachment=@$file" "$api/releases/$id/assets?name=$asset" \
    | jq -r '.id // empty')"
[ -n "$new" ] || { echo "release-asset.sh: the upload of $asset returned no asset id; nothing removed." >&2; exit 1; }
echo "release-asset.sh: attached $asset to the release for $tag"

old="$(curl -fsS -H "$auth" "$api/releases/$id/assets" \
    | jq -r --arg n "$asset" --arg new "$new" '.[] | select(.name == $n and (.id | tostring) != $new) | .id')"
for a in $old; do
    curl -fsS -X DELETE -H "$auth" "$api/releases/$id/assets/$a" > /dev/null
    echo "release-asset.sh: removed the earlier $asset (asset $a)"
done

# The notes give the file's SHA-256 in a block marked with its name, which a re-run replaces whole.
sum="$(cd "$(dirname "$file")" && sha256sum "$asset")"
begin="<!-- $asset -->"
end="<!-- /$asset -->"
notes="$(jq -r '.body // ""' <<< "$release" \
    | awk -v b="$begin" -v e="$end" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }')"
notes="$(printf '%s\n\n%s\n%s, SHA-256:\n\n```\n%s\n```\n%s\n' "$notes" "$begin" "$asset" "$sum" "$end")"
curl -fsS -X PATCH -H "$auth" -H 'Content-Type: application/json' \
    -d "$(jq -n --arg notes "$notes" '{body: $notes}')" "$api/releases/$id" > /dev/null
echo "release-asset.sh: added $asset's SHA-256 to the notes of the release for $tag"
