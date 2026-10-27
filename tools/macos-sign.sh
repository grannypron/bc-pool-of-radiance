#!/usr/bin/env bash
#
# Sign Pool of Radiance.app with a Developer ID, submit it for notarization, and staple Apple's ticket. Run this on
# a Mac after ./build-native.sh macos.
#
#   tools/macos-sign.sh [APP]
#
# APP defaults to obj/native/macos/Pool of Radiance.app. Environment variables select the credentials:
#   SIGN_P12         A .p12 containing the Developer ID certificate and private key. Put its password in
#                    SIGN_P12_PASSWORD_FILE. This uses rcodesign and does not require a login keychain. The Forgejo
#                    runner uses this path because codesign launched as a service sees only the System keychain.
#                    rcodesign is downloaded once, verified, and stored below $FPC_PREFIX/tools/bin.
#   SIGN_IDENTITY    Otherwise, use this identity from the login keychain. By default the first Developer ID
#                    Application identity is selected. Unlock the login keychain before signing over SSH.
#   NOTARY_KEY       An App Store Connect API key (.p8), accompanied by NOTARY_KEY_ID and NOTARY_ISSUER; or
#   NOTARY_PROFILE   A notarytool keychain profile created with
#                      xcrun notarytool store-credentials <name> --apple-id <id> --team-id <team>
#                    The default profile is poolrad. Set this to none to sign without notarizing.
# The finished app is zipped beside it as Pool of Radiance.zip. ditto preserves everything covered by the signature.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${1:-$root/obj/native/macos/Pool of Radiance.app}"
profile="${NOTARY_PROFILE:-poolrad}"
# Pin rcodesign and its published Apple Silicon SHA-256.
rcodesign_version=0.29.0
rcodesign_sha=d1a532150adaf90048260d76359261aa716abafc45c53c5dc18845029184334a

[ "$(uname -s)" = Darwin ] || { echo "macos-sign.sh: run this on a Mac." >&2; exit 1; }
[ -d "$app" ] || { echo "macos-sign.sh: no $app: run ./build-native.sh macos first." >&2; exit 1; }

# Download and verify rcodesign on first use, then pass through the caller's arguments.
rcodesign() {
    local bin="${FPC_PREFIX:-$HOME/fpc}/tools/bin" dl name url
    if ! "$bin/rcodesign" --version 2> /dev/null | grep -q " $rcodesign_version"; then
        echo "macos-sign.sh: downloading rcodesign $rcodesign_version..."
        mkdir -p "$bin" "${FPC_PREFIX:-$HOME/fpc}/tools/dl"
        name="apple-codesign-$rcodesign_version-aarch64-apple-darwin"
        dl="${FPC_PREFIX:-$HOME/fpc}/tools/dl/$name.tar.gz"
        url="https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%2F$rcodesign_version"
        curl -fsSL -o "$dl" "$url/$name.tar.gz"
        [ "$(shasum -a 256 "$dl" | cut -d' ' -f1)" = "$rcodesign_sha" ] \
            || { echo "macos-sign.sh: the rcodesign download does not match its SHA-256." >&2; exit 1; }
        tar -xzf "$dl" -C "${FPC_PREFIX:-$HOME/fpc}/tools" "$name/rcodesign"
        mv "${FPC_PREFIX:-$HOME/fpc}/tools/$name/rcodesign" "$bin/rcodesign"
        rmdir "${FPC_PREFIX:-$HOME/fpc}/tools/$name"
    fi
    "$bin/rcodesign" "$@"
}

if [ -n "${SIGN_P12:-}" ]; then
    [ -r "$SIGN_P12" ] && [ -r "${SIGN_P12_PASSWORD_FILE:-}" ] \
        || { echo "macos-sign.sh: SIGN_P12 needs a readable .p12 and SIGN_P12_PASSWORD_FILE." >&2; exit 1; }
    echo "macos-sign.sh: signing with $SIGN_P12 (rcodesign)..."
    # Notarization requires the hardened runtime. rcodesign requests Apple's secure timestamp by default.
    rcodesign sign --p12-file "$SIGN_P12" --p12-password-file "$SIGN_P12_PASSWORD_FILE" \
        --code-signature-flags runtime "$app"
else
    identity="${SIGN_IDENTITY:-}"
    if [ -z "$identity" ]; then
        identity="$(security find-identity -v -p codesigning \
            | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1)"
    fi
    [ -n "$identity" ] || { echo "macos-sign.sh: no Developer ID Application identity in the keychain" \
        "(over SSH, unlock the login keychain first), and neither SIGN_IDENTITY nor SIGN_P12 is set." >&2; exit 1; }
    echo "macos-sign.sh: signing with $identity..."
    # Notarization requires both the hardened runtime and a secure timestamp.
    codesign --force --options runtime --timestamp --sign "$identity" "$app"
fi
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
# notarytool can exit successfully for a rejected submission, so require an explicit Accepted status.
result="$(xcrun notarytool submit "$zip" "${notary[@]}" --wait 2>&1)" || { echo "$result" >&2; exit 1; }
echo "$result"
echo "$result" | grep -q "status: Accepted" \
    || { echo "macos-sign.sh: Apple did not accept it; xcrun notarytool log <submission id> says why." >&2
         exit 1; }
xcrun stapler staple "$app"
# Recreate the archive so it includes the stapled ticket.
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
spctl --assess --type execute --verbose=2 "$app"
echo "macos-sign.sh: signed, notarized and stapled: $zip"
