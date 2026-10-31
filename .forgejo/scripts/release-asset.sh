#!/usr/bin/env bash
#
# Attach another file to an existing Forgejo release.
#
#   .forgejo/scripts/release-asset.sh v1.4 dist/pool-of-radiance-v1.4-macos.zip
#
# REPO_API is the event's repository URL and TOKEN is the job token, as in release.sh. Upload the replacement before
# deleting an older asset with the same name so a failed upload leaves the release intact. The script also replaces
# that asset's checksum block in the release notes, in place (notes.sh).

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/notes.sh"

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

# Delimit the checksum block with the asset name so a rerun can replace it cleanly.
sum="$(cd "$(dirname "$file")" && sha256sum "$asset")"
begin="<!-- $asset -->"
end="<!-- /$asset -->"
notes="$(jq -r '.body // ""' <<< "$release" \
    | notes_put "$begin" "$end" "$(printf '%s\n%s, SHA-256:\n\n```\n%s\n```\n%s' "$begin" "$asset" "$sum" "$end")")"
curl -fsS -X PATCH -H "$auth" -H 'Content-Type: application/json' \
    -d "$(jq -n --arg notes "$notes" '{body: $notes}')" "$api/releases/$id" > /dev/null
echo "release-asset.sh: added $asset's SHA-256 to the notes of the release for $tag"
