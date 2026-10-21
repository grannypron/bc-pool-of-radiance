#!/usr/bin/env bash
#
# macos-sign.sh -- sign Pool of Radiance.app with a Developer ID, notarize it with Apple and staple the ticket, so
# Gatekeeper opens it on any Mac. Run on a Mac after ./build-native.sh macos.
#
#   tools/macos-sign.sh [APP]
#
# APP defaults to obj/native/macos/Pool of Radiance.app. The environment chooses the credentials:
#   SIGN_IDENTITY    the signing identity (default: the keychain's first "Developer ID Application" one)
#   NOTARY_PROFILE   a notarytool keychain profile, made once with
#                      xcrun notarytool store-credentials <name> --apple-id <id> --team-id <team>
#                    (default: poolrad); with NOTARY_PROFILE=none the app is signed but not notarized
# Over SSH the login keychain is locked: unlock it first (security unlock-keychain ~/Library/Keychains/login.keychain-db).
# The notarized app is zipped beside it as Pool of Radiance.zip (ditto keeps what the signature covers).

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${1:-$root/obj/native/macos/Pool of Radiance.app}"
profile="${NOTARY_PROFILE:-poolrad}"

[ "$(uname -s)" = Darwin ] || { echo "macos-sign.sh: run this on a Mac." >&2; exit 1; }
[ -d "$app" ] || { echo "macos-sign.sh: no $app: run ./build-native.sh macos first." >&2; exit 1; }

identity="${SIGN_IDENTITY:-}"
if [ -z "$identity" ]; then
    identity="$(security find-identity -v -p codesigning \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1)"
fi
[ -n "$identity" ] || { echo "macos-sign.sh: no Developer ID Application identity in the keychain" \
    "(over SSH, unlock the login keychain first), and SIGN_IDENTITY is not set." >&2; exit 1; }

echo "macos-sign.sh: signing with $identity..."
# the hardened runtime, which notarization requires; a secure timestamp, likewise
codesign --force --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --strict --verbose=2 "$app"

zip="$(dirname "$app")/Pool of Radiance.zip"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
if [ "$profile" = none ]; then
    echo "macos-sign.sh: signed, not notarized (NOTARY_PROFILE=none): $zip"
    exit 0
fi

echo "macos-sign.sh: notarizing (profile $profile); Apple usually answers within minutes..."
xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$app"
# the zip again, now with the stapled ticket inside
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
spctl --assess --type execute --verbose=2 "$app"
echo "macos-sign.sh: signed, notarized and stapled: $zip"
