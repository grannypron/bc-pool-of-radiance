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

# README.TXT says the files are built from the source tagged $version. The release workflow's dispatch path builds the
# tag's src/ in another commit's checkout and sets SOURCE_DATE_EPOCH, so the check is left to it there.
if [ -z "${SOURCE_DATE_EPOCH:-}" ] \
        && [ "$(git -C "$root" rev-parse -q --verify "refs/tags/$version^{commit}" 2> /dev/null)" \
            != "$(git -C "$root" rev-parse -q --verify HEAD 2> /dev/null)" ]; then
    echo "package.sh: warning: HEAD is not the commit tagged $version, which README.TXT names as the source." >&2
fi

for f in START.EXE GAME.OVR; do
    [ -f "$root/obj/$f" ] || { echo "package.sh: obj/$f is missing; run ./build.sh first." >&2; exit 1; }
done

name="pool-of-radiance-$version-dos"
# The game version whose data the build expects: v1.1 and v1.2 are SSI's own; every later tag is built on v1.3.
case "$version" in
    v1.1) game="1.1" release="" ;;
    v1.2) game="1.2" release="" ;;
    *) game="1.3" release=" (the GOG and Steam release)" ;;
esac
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

cp "$root/obj/START.EXE" "$root/obj/GAME.OVR" "$stage/"
(cd "$stage" && sha256sum START.EXE GAME.OVR) > "$stage/SHA256.TXT"

cat > "$stage/README.TXT" <<EOF
Pool of Radiance $version for DOS
=================================

START.EXE and GAME.OVR, built from the source tagged $version, for
Pool of Radiance $game$release.

To install, back up START.EXE and GAME.OVR in your Pool of Radiance
$game folder, then copy these two over them. The game's data files
are not included: you need your own copy of Pool of Radiance.

SHA256.TXT holds the SHA-256 of each file.
EOF
# Sources with src/databld.pas build the combined data files at startup (older tags do not).
if [ -f "$root/src/databld.pas" ]; then
    cat >> "$stage/README.TXT" <<EOF

The first time you start the game, it builds combined data files
from your copy, one for each kind of data (ECL.DAX from ECL1.DAX to
ECL8.DAX, MONCHA.DAX from MON1CHA.DAX to MON8CHA.DAX and so on,
fourteen in all), and then reads them in place of the per-disk
files. This takes a little while, once: the screen shows how far it
has got and the time left, and DATABLD.LOG in the game folder lists
every step. Later starts keep the files and go straight on; a file
that is missing, cut short or out of date is built again. Your
original files are only read. If the game folder cannot be written,
the game reads them as before.
EOF
fi
# DOS reads CRLF line endings.
sed -i 's/$/\r/' "$stage/README.TXT" "$stage/SHA256.TXT"

# Stamp every file with the commit's time and give it the same mode whatever the umask, so the same source gives the
# same zip on any machine, on any day.
stamp="${SOURCE_DATE_EPOCH:-$(git -C "$root" log -1 --format=%ct 2> /dev/null)}" || stamp=""
[ -n "$stamp" ] || { echo "package.sh: cannot date the zip from git; set SOURCE_DATE_EPOCH." >&2; exit 1; }
chmod 0644 "$stage"/*
touch -d "@$stamp" "$stage"/*

mkdir -p "$root/dist"
rm -f "$root/dist/$name.zip"
(cd "$stage" && TZ=UTC zip -q -X "$root/dist/$name.zip" START.EXE GAME.OVR README.TXT SHA256.TXT)
echo "package.sh: dist/$name.zip"
