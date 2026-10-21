#!/usr/bin/env bash
#
# sdl3-setup.sh -- download and build the SDL3 libraries the native build links into the game.
#
#   tools/sdl3-setup.sh            build SDL3 for this host and the cross targets fpc-setup.sh builds compilers for
#   tools/sdl3-setup.sh --print    print the folder SDL3 is (or would be) installed in, and stop
#
# build/toolchain names the version ("sdl3=<version>"). Each target installs into $FPC_PREFIX/sdl3-<version>/<target>
# (FPC_PREFIX is ~/fpc unless set), a static library where the platform allows it so the game is a single file:
#   x86_64-linux    lib/libSDL3.a
#   i386-win32      lib/libSDL3.a (mingw), and bin/SDL3.dll as the fallback
#   x86_64-win64    lib/libSDL3.a (mingw), and bin/SDL3.dll as the fallback
#   aarch64-darwin  lib/libSDL3.a (on an Apple Silicon Mac; there is no Intel Mac target)
# A target already built is skipped.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(sed -n 's/^sdl3=\([0-9.]*\).*/\1/p' "$root/build/toolchain" 2> /dev/null | head -n 1)"
[ -n "$version" ] || { echo "sdl3-setup.sh: build/toolchain has no sdl3=<version> line." >&2; exit 1; }
prefix_root="${FPC_PREFIX:-$HOME/fpc}"
prefix="$prefix_root/sdl3-$version"

if [ "${1:-}" = "--print" ]; then
    echo "$prefix"
    exit 0
fi
[ $# -eq 0 ] || { echo "sdl3-setup.sh: unknown option $1 (the only option is --print)" >&2; exit 2; }

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) targets=(x86_64-linux i386-win32 x86_64-win64) ;;
    Darwin-arm64) targets=(aarch64-darwin) ;;
    *) echo "sdl3-setup.sh: no recipe for this host." >&2; exit 1 ;;
esac

problems=()
for tool in curl tar cmake ninja; do
    command -v "$tool" > /dev/null 2>&1 || problems+=("$tool is not on PATH.")
done
for t in "${targets[@]}"; do
    case "$t" in
        i386-win32) command -v i686-w64-mingw32-gcc > /dev/null 2>&1 \
            || problems+=("i686-w64-mingw32-gcc is not on PATH: install mingw-w64 (Arch: mingw-w64-gcc).") ;;
        x86_64-win64) command -v x86_64-w64-mingw32-gcc > /dev/null 2>&1 \
            || problems+=("x86_64-w64-mingw32-gcc is not on PATH: install mingw-w64 (Arch: mingw-w64-gcc).") ;;
    esac
done
if [ ${#problems[@]} -gt 0 ]; then
    echo "sdl3-setup.sh: cannot build SDL3. Fix these first:" >&2
    printf '  - %s\n' "${problems[@]}" >&2
    exit 1
fi

cache="$prefix_root/cache"
mkdir -p "$cache"
source="$cache/SDL3-$version"
if [ ! -f "$source/CMakeLists.txt" ]; then
    echo "sdl3-setup.sh: downloading SDL3 $version..."
    rm -rf "$source" "$source.download"
    mkdir -p "$source.download"
    curl -fsSL "https://github.com/libsdl-org/SDL/releases/download/release-$version/SDL3-$version.tar.gz" \
        -o "$source.download/SDL3.tar.gz"
    tar -xzf "$source.download/SDL3.tar.gz" -C "$source.download"
    mv "$source.download/SDL3-$version" "$source"
    rm -rf "$source.download"
fi

# Both a static and a shared library: the static one goes into the game, the shared one is the fallback on Windows.
common=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DSDL_STATIC=ON -DSDL_SHARED=ON -DSDL_TEST_LIBRARY=OFF
        -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF -DSDL_INSTALL_DOCS=OFF)

for t in "${targets[@]}"; do
    if [ -f "$prefix/$t/lib/libSDL3.a" ]; then
        echo "sdl3-setup.sh: SDL3 $version for $t is already in $prefix/$t"
        continue
    fi
    build="$cache/build-SDL3-$version-$t"
    log="$build.log"
    rm -rf "$build"
    extra=()
    case "$t" in
        i386-win32) extra=(-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc
                           -DCMAKE_CXX_COMPILER=i686-w64-mingw32-g++
                           -DCMAKE_RC_COMPILER=i686-w64-mingw32-windres) ;;
        x86_64-win64) extra=(-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc
                             -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++
                             -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres) ;;
        aarch64-darwin) extra=(-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0) ;;
    esac
    echo "sdl3-setup.sh: building SDL3 $version for $t (log: $log)..."
    { cmake -S "$source" -B "$build" "${common[@]}" "${extra[@]}" -DCMAKE_INSTALL_PREFIX="$prefix/$t" \
        && cmake --build "$build" \
        && cmake --install "$build"; } > "$log" 2>&1 \
        || { echo "sdl3-setup.sh: the $t build failed; see $log" >&2; tail -n 20 "$log" >&2; exit 1; }
done

echo "sdl3-setup.sh: SDL3 $version installed in $prefix (${targets[*]})"
