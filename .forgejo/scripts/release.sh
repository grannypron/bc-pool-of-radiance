#!/usr/bin/env bash
#
# release.sh -- create (or reuse) the Forgejo release for a tag and attach its zip from dist/.
#
#   .forgejo/scripts/release.sh v1.1
#
# Runs in the build workflow, which provides GITHUB_SERVER_URL, GITHUB_REPOSITORY and, in TOKEN, the job's token.
# A re-run replaces the asset, so a release can be rebuilt without editing it by hand.

set -eu

tag="$1"
asset="pool-of-radiance-$tag-dos.zip"
zip="dist/$asset"
api="$GITHUB_SERVER_URL/api/v1/repos/$GITHUB_REPOSITORY"
auth="Authorization: token $TOKEN"

[ -f "$zip" ] || { echo "release.sh: $zip is missing; run package.sh first." >&2; exit 1; }

notes="$(printf 'START.EXE and GAME.OVR built from the source tagged %s.\n\nSHA-256:\n\n```\n%s\n```\n' \
    "$tag" "$(cd obj && sha256sum START.EXE GAME.OVR)")"

# The release for the tag, created if it does not exist yet.
id="$(curl -fsS -H "$auth" "$api/releases/tags/$tag" 2> /dev/null | jq -r '.id // empty' || true)"
if [ -z "$id" ]; then
    body="$(jq -n --arg tag "$tag" --arg notes "$notes" \
        '{tag_name: $tag, name: ("Pool of Radiance " + $tag), body: $notes}')"
    id="$(curl -fsS -X POST -H "$auth" -H 'Content-Type: application/json' -d "$body" "$api/releases" | jq -r .id)"
    echo "release.sh: created the release for $tag"
fi

# Replace an asset of the same name left by an earlier run.
old="$(curl -fsS -H "$auth" "$api/releases/$id/assets" | jq -r --arg n "$asset" '.[] | select(.name == $n) | .id')"
for a in $old; do
    curl -fsS -X DELETE -H "$auth" "$api/releases/$id/assets/$a" > /dev/null
done

curl -fsS -X POST -H "$auth" -F "attachment=@$zip" "$api/releases/$id/assets?name=$asset" > /dev/null
echo "release.sh: attached $asset to the release for $tag"
