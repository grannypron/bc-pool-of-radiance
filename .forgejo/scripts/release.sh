#!/usr/bin/env bash
#
# Create or update a Forgejo release and attach its DOS archive from dist/.
#
#   .forgejo/scripts/release.sh v1.1
#
# The build workflow supplies the repository API URL as REPO_API and its job token as TOKEN. GITHUB_SERVER_URL cannot
# be used because this runner sets it to Forgejo's loopback address, which jobs cannot reach. Reruns update both the
# archive and release notes. The replacement is uploaded before the old asset is deleted so failed uploads are safe.

set -euo pipefail

tag="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
asset="pool-of-radiance-$tag-dos.zip"
zip="$root/dist/$asset"
api="${REPO_API:?REPO_API is not set: the workflow sets it to the event repository.url}"
auth="Authorization: token $TOKEN"

[ -f "$zip" ] || { echo "release.sh: dist/$asset is missing; run package.sh first." >&2; exit 1; }

# Record checksums for the archive and the two game files package.sh placed in it.
notes="$(printf 'START.EXE and GAME.OVR built from the source tagged %s.\n\nSHA-256:\n\n```\n%s\n%s\n```\n' \
    "$tag" "$(cd "$root/obj" && sha256sum START.EXE GAME.OVR)" "$(cd "$root/dist" && sha256sum "$asset")")"

resp="$(mktemp)"
trap 'rm -f "$resp"' EXIT

# Reuse the tag's release when present. Only HTTP 404 means a new release should be created.
status="$(curl -sS -o "$resp" -w '%{http_code}' -H "$auth" "$api/releases/tags/$tag")"
case "$status" in
    200)
        id="$(jq -r .id "$resp")"
        existed=1
        ;;
    404)
        body="$(jq -n --arg tag "$tag" --arg notes "$notes" \
            '{tag_name: $tag, name: ("Pool of Radiance " + $tag), body: $notes}')"
        id="$(curl -fsS -X POST -H "$auth" -H 'Content-Type: application/json' -d "$body" "$api/releases" | jq -r .id)"
        existed=0
        echo "release.sh: created the release for $tag"
        ;;
    *)
        echo "release.sh: looking up the release for $tag failed (HTTP $status):" >&2
        cat "$resp" >&2
        echo >&2
        exit 1
        ;;
esac

# Upload the replacement first, then update the notes and remove older assets with the same name.
new="$(curl -fsS -X POST -H "$auth" -F "attachment=@$zip" "$api/releases/$id/assets?name=$asset" \
    | jq -r '.id // empty')"
[ -n "$new" ] || { echo "release.sh: the upload of $asset returned no asset id; nothing removed." >&2; exit 1; }
echo "release.sh: attached $asset to the release for $tag"
if [ $existed -eq 1 ]; then
    curl -fsS -X PATCH -H "$auth" -H 'Content-Type: application/json' \
        -d "$(jq -n --arg notes "$notes" '{body: $notes}')" "$api/releases/$id" > /dev/null
    echo "release.sh: updated the notes of the release for $tag"
fi
old="$(curl -fsS -H "$auth" "$api/releases/$id/assets" \
    | jq -r --arg n "$asset" --arg new "$new" '.[] | select(.name == $n and (.id | tostring) != $new) | .id')"
for a in $old; do
    curl -fsS -X DELETE -H "$auth" "$api/releases/$id/assets/$a" > /dev/null
    echo "release.sh: removed the earlier $asset (asset $a)"
done
