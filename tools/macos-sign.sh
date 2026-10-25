#!/usr/bin/env bash
#
# macos-sign.sh -- sign Pool of Radiance.app with a Developer ID, notarize it with Apple and staple the ticket, so
# Gatekeeper opens it on any Mac. Run on a Mac after ./build-native.sh macos.
#
#   tools/macos-sign.sh [APP]
#
# APP defaults to obj/native/macos/Pool of Radiance.app. The environment chooses the credentials:
#   SIGN_IDENTITY    the signing identity (default: the keychain's first "Developer ID Application" one)
#   SIGN_KEYCHAIN    a keychain to sign from instead of the login keychain: the Forgejo runner's
#                    ~ci-runner/Library/Keychains/signing.keychain-db. It is unlocked with the password in
#                    SIGN_KEYCHAIN_PASSWORD_FILE, put in the search list for the signing (codesign finds Apple's
#                    intermediate there) and locked again afterwards.
#   NOTARY_KEY       an App Store Connect API key (.p8) to notarize with, with NOTARY_KEY_ID and NOTARY_ISSUER (the
#                    runner's /etc/forgejo-runner/signing/notary-key.p8, notary-key-id and notary-issuer); or else
#   NOTARY_PROFILE   a notarytool keychain profile, made once with
#                      xcrun notarytool store-credentials <name> --apple-id <id> --team-id <team>
#                    (default: poolrad); with NOTARY_PROFILE=none the app is signed but not notarized
# Over SSH the login keychain is locked: unlock it first (security unlock-keychain ~/Library/Keychains/login.keychain-db).
# The notarized app is zipped beside it as Pool of Radiance.zip (ditto keeps what the signature covers).

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${1:-$root/obj/native/macos/Pool of Radiance.app}"
profile="${NOTARY_PROFILE:-poolrad}"
keychain="${SIGN_KEYCHAIN:-}"

[ "$(uname -s)" = Darwin ] || { echo "macos-sign.sh: run this on a Mac." >&2; exit 1; }
[ -d "$app" ] || { echo "macos-sign.sh: no $app: run ./build-native.sh macos first." >&2; exit 1; }

keychain_args=()
if [ -n "$keychain" ]; then
    [ -f "$keychain" ] || { echo "macos-sign.sh: no keychain $keychain." >&2; exit 1; }
    [ -r "${SIGN_KEYCHAIN_PASSWORD_FILE:-}" ] \
        || { echo "macos-sign.sh: SIGN_KEYCHAIN needs SIGN_KEYCHAIN_PASSWORD_FILE." >&2; exit 1; }
    saved_list="$(security list-keychains -d user | tr -d '"' | xargs)"
    restore_keychain() {
        # shellcheck disable=SC2086
        security list-keychains -d user -s $saved_list
        security lock-keychain "$keychain"
    }
    trap restore_keychain EXIT
    security unlock-keychain -p "$(cat "$SIGN_KEYCHAIN_PASSWORD_FILE")" "$keychain"
    # shellcheck disable=SC2086
    security list-keychains -d user -s "$keychain" $saved_list
    keychain_args=(--keychain "$keychain")
fi

identity="${SIGN_IDENTITY:-}"
if [ -z "$identity" ]; then
    identity="$(security find-identity -v -p codesigning ${keychain:+"$keychain"} \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1)"
fi
[ -n "$identity" ] || { echo "macos-sign.sh: no Developer ID Application identity in the keychain" \
    "(over SSH, unlock the login keychain first), and SIGN_IDENTITY is not set." >&2; exit 1; }

echo "macos-sign.sh: signing with $identity..."
# the hardened runtime, which notarization requires; a secure timestamp, likewise
codesign --force --options runtime --timestamp ${keychain_args[@]+"${keychain_args[@]}"} --sign "$identity" "$app"
codesign --verify --strict --verbose=2 "$app"

zip="$(dirname "$app")/Pool of Radiance.zip"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
if [ -n "${NOTARY_KEY:-}" ]; then
    [ -r "$NOTARY_KEY" ] && [ -n "${NOTARY_KEY_ID:-}" ] && [ -n "${NOTARY_ISSUER:-}" ] \
        || { echo "macos-sign.sh: NOTARY_KEY needs NOTARY_KEY_ID and NOTARY_ISSUER, and a readable key." >&2; exit 1; }
    notary=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
    how="API key $NOTARY_KEY_ID"
elif [ "$profile" = none ]; then
    echo "macos-sign.sh: signed, not notarized (NOTARY_PROFILE=none): $zip"
    exit 0
else
    notary=(--keychain-profile "$profile")
    how="profile $profile"
fi

echo "macos-sign.sh: notarizing ($how); Apple usually answers within minutes..."
xcrun notarytool submit "$zip" "${notary[@]}" --wait
xcrun stapler staple "$app"
# the zip again, now with the stapled ticket inside
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
spctl --assess --type execute --verbose=2 "$app"
echo "macos-sign.sh: signed, notarized and stapled: $zip"
