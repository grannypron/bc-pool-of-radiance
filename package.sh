#!/usr/bin/env bash
#
# package.sh -- zip a build for release: dist/pool-of-radiance-<version>-dos.zip.
#
#   ./package.sh v1.1
#
# Run it after build.sh. The zip holds START.EXE and GAME.OVR from obj/, the data builder DATABLD.EXE when the source
# has it, a README.TXT and their SHA-256 sums in SHA256.TXT; every name fits DOS's 8.3 limit, so the files read the
# same inside DOSBox.

set -eu

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -ne 1 ]; then
    echo "package.sh: give the version, for example: ./package.sh v1.1" >&2
    exit 2
fi
version="$1"

# The data builder comes from sources that have it (older tags do not).
programs=(START.EXE GAME.OVR)
[ -f "$root/src/databld.pas" ] && programs+=(DATABLD.EXE)
for f in "${programs[@]}"; do
    [ -f "$root/obj/$f" ] || { echo "package.sh: obj/$f is missing; run ./build.sh first." >&2; exit 1; }
done

name="pool-of-radiance-$version-dos"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

for f in "${programs[@]}"; do
    cp "$root/obj/$f" "$stage/"
done
(cd "$stage" && sha256sum "${programs[@]}") > "$stage/SHA256.TXT"

cat > "$stage/README.TXT" <<EOF
Pool of Radiance $version for DOS
=================================

START.EXE and GAME.OVR, built from the source tagged $version.

To install, back up START.EXE and GAME.OVR in your Pool of Radiance
folder, then copy these two over them. The game's data files are not
included: you need your own copy of Pool of Radiance.

SHA256.TXT holds the SHA-256 of each file.
EOF
if [ -f "$stage/DATABLD.EXE" ]; then
    cat >> "$stage/README.TXT" <<EOF

DATABLD.EXE builds combined data files from your copy of the game.
Copy it into your Pool of Radiance folder too, and run it there once:
in DOSBox, change to that folder and type DATABLD. It reads the
game's per-disk files (ECL1.DAX to ECL8.DAX, MON1CHA.DAX to
MON8CHA.DAX and so on) and writes one file for each kind (ECL.DAX,
MONCHA.DAX and so on), which the game then reads in their place.
Your original files are not changed, and none of the game's data is
in this zip: DATABLD builds it from your own copy.

Run DATABLD again after installing a new release, or after changing
any of the game's files; it rebuilds only the files that are out of
date. It shows each step and writes them to DATABLD.LOG. Without the
combined files the game reads its original files as before; to go
back to them, delete the files DATABLD made (DATABLD.LOG names them).
EOF
fi
# DOS reads CRLF line endings.
sed -i 's/$/\r/' "$stage/README.TXT" "$stage/SHA256.TXT"

# Stamp every file with the commit's time, so the same source gives the same zip on any machine, on any day.
stamp="${SOURCE_DATE_EPOCH:-$(git -C "$root" log -1 --format=%ct 2> /dev/null || date +%s)}"
touch -d "@$stamp" "$stage"/*

mkdir -p "$root/dist"
rm -f "$root/dist/$name.zip"
(cd "$stage" && TZ=UTC zip -q -X "$root/dist/$name.zip" "${programs[@]}" README.TXT SHA256.TXT)
echo "package.sh: dist/$name.zip"
