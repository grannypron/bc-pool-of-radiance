#!/usr/bin/env bash
#
# fpc-setup.sh -- download and build the Free Pascal toolchain the native build uses.
#
#   tools/fpc-setup.sh            build the compiler for this host and the cross compilers build/toolchain lists
#   tools/fpc-setup.sh --print    print the folder the toolchain is (or would be) installed in, and stop
#
# build/toolchain names the source: "fpc=<branch>@<commit>" (the fixes_3_2 branch, pinned) and "fpc_bootstrap=<version>"
# (the released compiler that compiles it the first time). The toolchain installs into
# $FPC_PREFIX/<branch>-<first 7 of commit>, FPC_PREFIX being ~/fpc unless set; a second run with the same pin finds it
# there and does nothing.
#
# Downloads go to $FPC_PREFIX/cache, each into its own folder. Nothing outside FPC_PREFIX is changed.
#
# Cross compilers built on a Linux x86_64 host: i386-linux (the first native target: 4-byte pointers keep the save
# file's records as TP lays them out), i386-win32 and x86_64-win64. macOS (x86_64-darwin, aarch64-darwin) is built on a
# Mac, where this script builds the host compiler and the other macOS architecture.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
toolchain="$root/build/toolchain"

setting() {
    sed -n "s/^$1=\([A-Za-z0-9._@-]*\).*/\1/p" "$toolchain" 2> /dev/null | head -n 1
}

pin="$(setting fpc)"
bootstrap="$(setting fpc_bootstrap)"
[ -n "$pin" ] || { echo "fpc-setup.sh: build/toolchain has no fpc=<branch>@<commit> line." >&2; exit 1; }
[ -n "$bootstrap" ] || { echo "fpc-setup.sh: build/toolchain has no fpc_bootstrap=<version> line." >&2; exit 1; }
branch="${pin%@*}"
commit="${pin#*@}"
prefix_root="${FPC_PREFIX:-$HOME/fpc}"
prefix="$prefix_root/$branch-${commit:0:7}"

if [ "${1:-}" = "--print" ]; then
    echo "$prefix"
    exit 0
fi
[ $# -eq 0 ] || { echo "fpc-setup.sh: unknown option $1 (the only option is --print)" >&2; exit 2; }

host_os="$(uname -s)"
host_cpu="$(uname -m)"
case "$host_os-$host_cpu" in
    Linux-x86_64)
        boot_dist="x86_64-linux" boot_pp="ppcx64"
        crosses=("i386 linux" "i386 win32" "x86_64 win64") ;;
    Darwin-arm64)
        boot_dist="aarch64-darwin" boot_pp="ppca64"
        crosses=("x86_64 darwin") ;;
    Darwin-x86_64)
        boot_dist="x86_64-darwin" boot_pp="ppcx64"
        crosses=("aarch64 darwin") ;;
    *) echo "fpc-setup.sh: no recipe for a $host_os $host_cpu host." >&2; exit 1 ;;
esac

problems=()
for tool in curl tar git make; do
    command -v "$tool" > /dev/null 2>&1 || problems+=("$tool is not on PATH.")
done
if [ ${#problems[@]} -gt 0 ]; then
    echo "fpc-setup.sh: cannot set up Free Pascal. Fix these first:" >&2
    printf '  - %s\n' "${problems[@]}" >&2
    exit 1
fi

# written last, so an install a failure cut short is built again
stamp="$prefix/.complete"
if [ -f "$stamp" ]; then
    echo "fpc-setup.sh: Free Pascal $pin is already in $prefix"
    exit 0
fi

cache="$prefix_root/cache"
mkdir -p "$cache"
jobs="$(getconf _NPROCESSORS_ONLN 2> /dev/null || echo 4)"

# --- the bootstrap compiler ---------------------------------------------------------------------

# Only its compiler binary is used: it compiles the pinned source, which then compiles itself.
boot="$cache/bootstrap-$bootstrap-$boot_dist"
if [ ! -x "$boot/$boot_pp" ]; then
    echo "fpc-setup.sh: downloading the Free Pascal $bootstrap compiler to bootstrap with..."
    rm -rf "$boot" "$boot.download"
    mkdir -p "$boot.download"
    # the release's tar (Linux and macOS alike): an installer's tar of tars, the compiler in base's
    url="https://downloads.freepascal.org/fpc/dist/$bootstrap/$boot_dist/fpc-$bootstrap.$boot_dist.tar"
    curl -fsSL "$url" -o "$boot.download/fpc.tar"
    tar -xf "$boot.download/fpc.tar" -C "$boot.download"
    tar -xf "$boot.download"/fpc-*/binary.*.tar -C "$boot.download"
    tar -xzf "$boot.download"/base.*.tar.gz -C "$boot.download" "lib/fpc/$bootstrap/$boot_pp"
    mkdir -p "$boot"
    cp "$boot.download/lib/fpc/$bootstrap/$boot_pp" "$boot/"
    rm -rf "$boot.download"
fi

# --- the pinned source --------------------------------------------------------------------------

source="$cache/source-$branch-$commit"
if [ ! -d "$source/compiler" ]; then
    echo "fpc-setup.sh: fetching the Free Pascal source, $branch at $commit..."
    rm -rf "$source"
    git init -q "$source"
    git -C "$source" fetch -q --depth 1 https://gitlab.com/freepascal.org/fpc/source.git "$commit"
    git -C "$source" checkout -q FETCH_HEAD
fi

# --- build and install --------------------------------------------------------------------------

log="$cache/build-$branch-$commit.log"
: > "$log"
# macOS: the C library and the frameworks are in Xcode's SDK, not in /usr/lib, so every link is given its root
opt=""
if [ "$host_os" = Darwin ]; then
    sdk="$(xcrun --show-sdk-path)" || { echo "fpc-setup.sh: no macOS SDK: install Xcode or its tools." >&2; exit 1; }
    opt="-XR$sdk"
fi
echo "fpc-setup.sh: building the compiler for this host (log: $log)..."
make -C "$source" -j "$jobs" FPMAKEOPT="-T $jobs" PP="$boot/$boot_pp" OPT="$opt" all >> "$log" 2>&1 \
    || { echo "fpc-setup.sh: the host build failed; see $log" >&2; tail -n 20 "$log" >&2; exit 1; }
make -C "$source" PP="$boot/$boot_pp" OPT="$opt" INSTALL_PREFIX="$prefix" install >> "$log" 2>&1 \
    || { echo "fpc-setup.sh: installing the host build failed; see $log" >&2; exit 1; }

version="$(sed -n 's/^version=\([0-9.]*\).*/\1/p' "$source/compiler/Makefile.fpc" | head -n 1)"
lib="$prefix/lib/fpc/$version"
# The newly installed compiler builds the cross compilers, so every one comes from the pinned source.
newpp="$lib/$boot_pp"

for cross in "${crosses[@]}"; do
    set -- $cross
    echo "fpc-setup.sh: building the $1-$2 cross compiler..."
    xopt="$opt"
    # a host without the x87's 80-bit extended (Apple Silicon) builds an x86 compiler with it emulated, or the compiler
    # stops on the RTL's extended constants (internal error 2014051001)
    [ "$host_cpu" = arm64 ] && [ "$1" = x86_64 ] && xopt="$opt -dFPC_SOFT_FPUX80"
    make -C "$source" -j "$jobs" FPMAKEOPT="-T $jobs" PP="$newpp" OPT="$xopt" CPU_TARGET="$1" OS_TARGET="$2" crossall \
        >> "$log" 2>&1 \
        || { echo "fpc-setup.sh: the $1-$2 build failed; see $log" >&2; tail -n 20 "$log" >&2; exit 1; }
    make -C "$source" PP="$newpp" OPT="$xopt" CPU_TARGET="$1" OS_TARGET="$2" INSTALL_PREFIX="$prefix" crossinstall \
        >> "$log" 2>&1 \
        || { echo "fpc-setup.sh: installing the $1-$2 build failed; see $log" >&2; exit 1; }
done

# fpc (the driver) finds the compilers in bin/, and its units through etc/fpc.cfg.
for pp in "$lib"/ppc*; do
    ln -sf "$pp" "$prefix/bin/$(basename "$pp")"
done
mkdir -p "$prefix/etc"
"$prefix/bin/fpcmkcfg" -d "basepath=$lib" -o "$prefix/etc/fpc.cfg" >> "$log" 2>&1
[ -z "$opt" ] || echo "$opt" >> "$prefix/etc/fpc.cfg"

touch "$stamp"
echo "fpc-setup.sh: Free Pascal $version ($pin) installed in $prefix"
echo "fpc-setup.sh: compilers: $(cd "$prefix/bin" && ls ppc* | tr '\n' ' ')"
