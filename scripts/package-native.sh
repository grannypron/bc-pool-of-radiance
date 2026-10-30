#!/usr/bin/env bash
#
# Package native Linux and Windows builds, as package.sh packages the DOS one and the workflow the macOS app.
#
#   scripts/package-native.sh v1.4 [TARGET...]    the default targets: x86_64-linux i386-linux x86_64-win64 i386-win32
#
# Run this after build-native.sh has built each target. Each archive holds the game and poolcfg, this release's data
# files from src/binaries, a README (scripts/linux-readme.txt or scripts/windows-readme.txt) and SHA256.TXT:
#   x86_64-linux  dist/pool-of-radiance-<version>-linux-x86_64.tar.gz
#   i386-linux    dist/pool-of-radiance-<version>-linux-i386.tar.gz
#   x86_64-win64  dist/pool-of-radiance-<version>-windows-x64.zip, with SDL3.dll
#   i386-win32    dist/pool-of-radiance-<version>-windows-x86.zip, with SDL3.dll
# Linux archives are tarballs so the programs keep their execute bit. Each unpacks into a folder of its own name.

set -eu

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -lt 1 ]; then
    echo "package-native.sh: give the version, for example: scripts/package-native.sh v1.4" >&2
    exit 2
fi
version="$1"
shift
targets=("$@")
[ ${#targets[@]} -gt 0 ] || targets=(x86_64-linux i386-linux x86_64-win64 i386-win32)

# Normalize timestamps and permissions so the same source produces the same archive on any machine.
stamp="${SOURCE_DATE_EPOCH:-$(git -C "$root" log -1 --format=%ct 2> /dev/null)}" || stamp=""
[ -n "$stamp" ] || { echo "package-native.sh: cannot date the archives from git; set SOURCE_DATE_EPOCH." >&2; exit 1; }

data=()
if [ -d "$root/src/binaries" ]; then
    for f in "$root"/src/binaries/*; do
        [ -f "$f" ] && data+=("$(basename "$f")")
    done
fi

mkdir -p "$root/dist"
failed=0
for t in "${targets[@]}"; do
    out="$root/obj/native/$t"
    case "$t" in
        x86_64-linux) name="pool-of-radiance-$version-linux-x86_64" ;;
        i386-linux) name="pool-of-radiance-$version-linux-i386" ;;
        x86_64-win64) name="pool-of-radiance-$version-windows-x64" ;;
        i386-win32) name="pool-of-radiance-$version-windows-x86" ;;
        *) echo "package-native.sh: no package for $t" >&2; failed=1; continue ;;
    esac
    case "$t" in
        *-win*) programs=(poolrad.exe poolcfg.exe SDL3.dll) readme=windows-readme.txt ;;
        *) programs=(poolrad poolcfg) readme=linux-readme.txt ;;
    esac
    stage="$(mktemp -d)"
    dir="$stage/$name"
    mkdir "$dir"
    missing=0
    for f in "${programs[@]}"; do
        src="$out/$f"
        # SDL3.dll is copied from the SDL3 build for the target.
        [ "$f" = SDL3.dll ] && src="$("$root/scripts/sdl3-setup.sh" --print)/$t/bin/SDL3.dll"
        [ -f "$src" ] || { echo "package-native.sh: $t: $src is missing; run scripts/build-native.sh $t." >&2; missing=1; }
        cp "$src" "$dir/" 2> /dev/null || true
    done
    if [ $missing -ne 0 ]; then
        failed=1
        rm -rf "$stage"
        continue
    fi
    [ ${#data[@]} -eq 0 ] || (cd "$root/src/binaries" && cp "${data[@]}" "$dir/")
    cp "$root/scripts/$readme" "$dir/README.TXT"
    files=("${programs[@]}" ${data[@]+"${data[@]}"})
    (cd "$dir" && sha256sum "${files[@]}") > "$dir/SHA256.TXT"
    chmod 0644 "$dir"/*
    case "$t" in
        *-win*)
            sed -i 's/$/\r/' "$dir/README.TXT" "$dir/SHA256.TXT"
            touch -d "@$stamp" "$dir" "$dir"/*
            rm -f "$root/dist/$name.zip"
            (cd "$stage" && TZ=UTC zip -q -X -r "$root/dist/$name.zip" "$name")
            echo "package-native.sh: dist/$name.zip" ;;
        *)
            chmod 0755 "$dir" "$dir/poolrad" "$dir/poolcfg"
            touch -d "@$stamp" "$dir" "$dir"/*
            rm -f "$root/dist/$name.tar.gz"
            tar -C "$stage" --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$stamp" -cf - "$name" \
                | gzip -n -9 > "$root/dist/$name.tar.gz"
            echo "package-native.sh: dist/$name.tar.gz" ;;
    esac
    rm -rf "$stage"
done
exit $failed
