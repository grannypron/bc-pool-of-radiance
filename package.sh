#!/usr/bin/env bash
#
# package.sh -- zip a build for release: dist/pool-of-radiance-<version>-dos.zip.
#
#   ./package.sh v1.1
#
# Run it after build.sh. The zip holds START.EXE and GAME.OVR from obj/, a README.TXT and their SHA-256 sums in
# SHA256.TXT; every name fits DOS's 8.3 limit, so the files read the same inside DOSBox.

set -eu

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -ne 1 ]; then
    echo "package.sh: give the version, for example: ./package.sh v1.1" >&2
    exit 2
fi
version="$1"

for f in START.EXE GAME.OVR; do
    [ -f "$root/obj/$f" ] || { echo "package.sh: obj/$f is missing; run ./build.sh first." >&2; exit 1; }
done

name="pool-of-radiance-$version-dos"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

cp "$root/obj/START.EXE" "$root/obj/GAME.OVR" "$stage/"
(cd "$stage" && sha256sum START.EXE GAME.OVR) > "$stage/SHA256.TXT"

cat > "$stage/README.TXT" <<EOF
Pool of Radiance $version for DOS
=================================

START.EXE and GAME.OVR, built from the source tagged $version.

To install, back up START.EXE and GAME.OVR in your Pool of Radiance
folder, then copy these two over them. The game's data files are not
included: you need your own copy of Pool of Radiance.

SHA256.TXT holds the SHA-256 of each file.
EOF
# DOS reads CRLF line endings.
sed -i 's/$/\r/' "$stage/README.TXT" "$stage/SHA256.TXT"

# Stamp every file with the commit's time, so the same source gives the same zip on any machine, on any day.
stamp="${SOURCE_DATE_EPOCH:-$(git -C "$root" log -1 --format=%ct 2> /dev/null || date +%s)}"
touch -d "@$stamp" "$stage"/*

mkdir -p "$root/dist"
rm -f "$root/dist/$name.zip"
(cd "$stage" && TZ=UTC zip -q -X "$root/dist/$name.zip" START.EXE GAME.OVR README.TXT SHA256.TXT)
echo "package.sh: dist/$name.zip"
