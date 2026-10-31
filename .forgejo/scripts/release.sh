#!/usr/bin/env bash
#
# Create or update a Forgejo release and attach its DOS archive from dist/.
#
#   .forgejo/scripts/release.sh v1.1
#
# The build workflow supplies the repository API URL as REPO_API and its job token as TOKEN. GITHUB_SERVER_URL cannot
# be used because this runner sets it to Forgejo's loopback address, which jobs cannot reach. Reruns update both the
# archive and release notes. The replacement is uploaded before the old asset is deleted so failed uploads are safe.
#
# The tag nightly is the rolling pre-release of main (#1108). Its notes list the changes since NIGHTLY_BASE, the last
# production release, when that is set, and every earlier file is removed once the new archive is attached, so a
# native or macOS build that fails tonight leaves its file missing rather than last night's.

set -euo pipefail

tag="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
asset="pool-of-radiance-$tag-dos.zip"
zip="$root/dist/$asset"
api="${REPO_API:?REPO_API is not set: the workflow sets it to the event repository.url}"
auth="Authorization: token $TOKEN"

[ -f "$zip" ] || { echo "release.sh: dist/$asset is missing; run package.sh first." >&2; exit 1; }

nightly=0
name="Pool of Radiance $tag"
[ "$tag" != nightly ] || { nightly=1; name="Pool of Radiance nightly"; }

# Record checksums for the archive and the two game files package.sh placed in it.
notes="$(printf 'START.EXE and GAME.OVR built from the source tagged %s.\n\nSHA-256:\n\n```\n%s\n%s\n```\n' \
    "$tag" "$(cd "$root/obj" && sha256sum START.EXE GAME.OVR)" "$(cd "$root/dist" && sha256sum "$asset")")"
if [ $nightly -eq 1 ]; then
    head="$(printf 'A pre-release of main at %s (%s), rebuilt each night main changes; not a production release.' \
        "$(git -C "$root" rev-parse --short=7 HEAD)" "$(git -C "$root" log -1 --format=%cs HEAD)")"
    if [ -n "${NIGHTLY_BASE:-}" ]; then
        head="$(printf '%s\n\nChanges since %s (%s commits):\n\n%s' "$head" "$NIGHTLY_BASE" \
            "$(git -C "$root" rev-list --count --first-parent "$NIGHTLY_BASE..HEAD")" \
            "$(cd "$root" && .forgejo/scripts/changes.sh "$NIGHTLY_BASE")")"
    fi
    notes="$(printf '%s\n\n%s' "$head" "$notes")"
fi

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
        body="$(jq -n --arg tag "$tag" --arg name "$name" --arg notes "$notes" --argjson pre "$nightly" \
            '{tag_name: $tag, name: $name, body: $notes, prerelease: ($pre == 1)}')"
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
        -d "$(jq -n --arg notes "$notes" --arg name "$name" --argjson pre "$nightly" \
            'if $pre == 1 then {body: $notes, name: $name, prerelease: true} else {body: $notes} end')" \
        "$api/releases/$id" > /dev/null
    echo "release.sh: updated the notes of the release for $tag"
fi
# Remove the earlier copies of this archive; for nightly, every other file too.
old="$(curl -fsS -H "$auth" "$api/releases/$id/assets" \
    | jq -r --arg n "$asset" --arg new "$new" --argjson all "$nightly" \
        '.[] | select((.id | tostring) != $new and ($all == 1 or .name == $n)) | "\(.id) \(.name)"')"
while read -r a file; do
    [ -n "$a" ] || continue
    curl -fsS -X DELETE -H "$auth" "$api/releases/$id/assets/$a" > /dev/null
    echo "release.sh: removed the earlier $file (asset $a)"
done <<< "$old"
