#!/usr/bin/env bash
#
# Package a DOS build as dist/pool-of-radiance-<version>-dos.zip.
#
#   scripts/package.sh v1.1
#
# Run this after build.sh. The archive contains START.EXE, GAME.OVR, and, when available, POOLCFG.EXE. It also includes
# the project-generated files from src/binaries, a README, and SHA-256 checksums. All archive names fit DOS's 8.3
# limit so DOSBox sees them unchanged.

set -eu

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -ne 1 ]; then
    echo "package.sh: give the version, for example: scripts/package.sh v1.1" >&2
    exit 2
fi
version="$1"

# README.TXT claims the archive was built from $version. Warn when a local build's HEAD is not that tag. Dispatched
# release builds intentionally use a tag's source in another commit's checkout and set SOURCE_DATE_EPOCH, so skip the
# warning there.
if [ -z "${SOURCE_DATE_EPOCH:-}" ] \
        && [ "$(git -C "$root" rev-parse -q --verify "refs/tags/$version^{commit}" 2> /dev/null)" \
            != "$(git -C "$root" rev-parse -q --verify HEAD 2> /dev/null)" ]; then
    echo "package.sh: warning: HEAD is not the commit tagged $version, which README.TXT names as the source." >&2
fi

# Include the setup program when this source tree provides it (#876).
files=(START.EXE GAME.OVR)
[ -f "$root/src/poolcfg.pas" ] && files+=(POOLCFG.EXE)
for f in "${files[@]}"; do
    [ -f "$root/obj/$f" ] || { echo "package.sh: obj/$f is missing; run scripts/build.sh first." >&2; exit 1; }
done
# Include project-generated data files. Older tags do not have this directory.
data=()
dos_name='^[A-Z0-9_]{1,8}(\.[A-Z0-9_]{1,3})?$'
if [ -d "$root/src/binaries" ]; then
    for f in "$root"/src/binaries/*; do
        [ -f "$f" ] || continue
        f="$(basename "$f")"
        [[ "$f" =~ $dos_name ]] \
            || { echo "package.sh: src/binaries/$f is not an 8.3 name in capitals, as DOS reads it." >&2; exit 1; }
        data+=("$f")
    done
fi

name="pool-of-radiance-$version-dos"
# v1.1 and v1.2 use their matching retail data. Later releases are based on the v1.3 data sold by GOG and Steam.
case "$version" in
    v1.1) game="1.1" release="" ;;
    v1.2) game="1.2" release="" ;;
    *) game="1.3" release=" (the GOG and Steam release)" ;;
esac
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

(cd "$root/obj" && cp "${files[@]}" "$stage/")
[ ${#data[@]} -eq 0 ] || (cd "$root/src/binaries" && cp "${data[@]}" "$stage/")
files+=(${data[@]+"${data[@]}"})
(cd "$stage" && sha256sum "${files[@]}") > "$stage/SHA256.TXT"

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
if [ -f "$root/src/poolcfg.pas" ]; then
    cat >> "$stage/README.TXT" <<EOF

POOLCFG.EXE sets the video mode, sound device, folders and game
settings. Copy it into the game's folder with the other two, and run
it there before the first START, and whenever you want to change
them. With no POOL.CFG, START runs it itself first. It creates no
folders: a folder you type must already exist.
EOF
fi
if [ ${#data[@]} -gt 0 ]; then
    cat >> "$stage/README.TXT" <<EOF

$(printf '%s, ' "${data[@]}" | sed 's/, $//; s/\(.*\), /\1 and /') are data files of this release
(the title picture, the Sound Blaster's recorded effects): copy them
into the game's folder too. The game runs without them, with SSI's
title and the speaker's effects.
EOF
fi
# Newer sources combine the per-disk archives at startup; historical tags do not.
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

# Normalize timestamps and permissions so the same source produces the same archive on any machine.
stamp="${SOURCE_DATE_EPOCH:-$(git -C "$root" log -1 --format=%ct 2> /dev/null)}" || stamp=""
[ -n "$stamp" ] || { echo "package.sh: cannot date the zip from git; set SOURCE_DATE_EPOCH." >&2; exit 1; }
chmod 0644 "$stage"/*
touch -d "@$stamp" "$stage"/*

mkdir -p "$root/dist"
rm -f "$root/dist/$name.zip"
(cd "$stage" && TZ=UTC zip -q -X "$root/dist/$name.zip" "${files[@]}" README.TXT SHA256.TXT)
echo "package.sh: dist/$name.zip"
