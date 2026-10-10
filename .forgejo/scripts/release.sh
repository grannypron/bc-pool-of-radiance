#!/usr/bin/env bash
#
# release.sh -- create (or update) the Forgejo release for a tag and attach its zip from dist/.
#
#   .forgejo/scripts/release.sh v1.1
#
# Runs in the build workflow, which provides GITHUB_SERVER_URL, GITHUB_REPOSITORY and, in TOKEN, the job's token.
# A re-run replaces the asset and the notes, so a release can be rebuilt without editing it by hand. The new zip is
# attached before the old one is removed, so a failed upload leaves the release as it was.

set -euo pipefail

tag="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
asset="pool-of-radiance-$tag-dos.zip"
zip="$root/dist/$asset"
api="$GITHUB_SERVER_URL/api/v1/repos/$GITHUB_REPOSITORY"
auth="Authorization: token $TOKEN"

[ -f "$zip" ] || { echo "release.sh: dist/$asset is missing; run package.sh first." >&2; exit 1; }

# The zip's own SHA-256, and those of the two files package.sh put in it (obj/ is what it zipped).
notes="$(printf 'START.EXE and GAME.OVR built from the source tagged %s.\n\nSHA-256:\n\n```\n%s\n%s\n```\n' \
    "$tag" "$(cd "$root/obj" && sha256sum START.EXE GAME.OVR)" "$(cd "$root/dist" && sha256sum "$asset")")"

resp="$(mktemp)"
trap 'rm -f "$resp"' EXIT

# The release for the tag, created with the notes if there is none yet. Only a 404 means there is none.
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

# Attach the new zip first; only then bring the notes up to date and remove any other asset of the same name an
# earlier run left.
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
