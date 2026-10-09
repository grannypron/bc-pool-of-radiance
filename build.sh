#!/usr/bin/env bash
#
# build.sh -- build Pool of Radiance from src/ into obj/START.EXE and obj/GAME.OVR.
#
#   ./build.sh              build
#   ./build.sh --install    build, then copy the two files into drive_c/POOLRAD to play
#
# DOSBox-X runs build/build.bat with these drives:
#   D:  $TOOLS/TP50             Turbo Pascal 5.0 (TPC.EXE, TURBO.TPL)
#   E:  this repository         src\, build\ and obj\
#   F:  $TOOLS/TASM             Turbo Assembler (TASM.EXE)
# TOOLS is the folder holding the DOS toolchains, drive_c unless set (the CI image sets it to /drive_d).
#
# Everything the build needs is checked first; every missing piece is reported before the script stops.

set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
drive_c="$root/drive_c"
game="$drive_c/POOLRAD"
tools="${TOOLS:-$drive_c}"
tp="$tools/TP50"
tasm="$tools/TASM"
exepack="$tools/EXEPACK"
dosbox_min="2025.02.01"

install=0
for arg in "$@"; do
    case "$arg" in
        --install) install=1 ;;
        *) echo "build.sh: unknown option $arg (the only option is --install)" >&2; exit 2 ;;
    esac
done

problems=()

problem() {
    problems+=("$1")
}

need_dir() {
    # need_dir <path> <what it is, for the message>
    [ -d "$1" ] || problem "Missing folder ${1#$root/}: $2"
}

need_file() {
    [ -f "$1" ] || problem "Missing file ${1#$root/}: $2"
}

# --- the toolchains, and the game when installing ---------------------------------------------

if [ -z "${TOOLS:-}" ]; then
    need_dir "$drive_c" "it holds the DOS toolchains; create it in the repository root, or set TOOLS."
else
    need_dir "$tools" "TOOLS names it as the folder holding the DOS toolchains."
fi
if [ $install -eq 1 ]; then
    need_dir "$game" "the Pool of Radiance install --install copies into (named POOLRAD, with no version suffix)."
    need_file "$game/START.EXE" "the game's START.EXE, which --install replaces; copy it from your install."
    need_file "$game/GAME.OVR" "the game's GAME.OVR, which --install replaces; copy it from your install."
fi
need_dir "$tp" "Turbo Pascal 5.0, which compiles the game."
need_file "$tp/TPC.EXE" "the Turbo Pascal 5.0 command-line compiler."
need_file "$tp/TURBO.TPL" "the Turbo Pascal 5.0 runtime library, which TPC.EXE needs."
need_dir "$tasm" "Turbo Assembler, which assembles src/sounddrv.asm."
need_file "$tasm/TASM.EXE" "the Turbo Assembler executable."
need_dir "$exepack" "Microsoft EXEPACK."
need_file "$exepack/EXEPACK.EXE" "the EXEPACK executable."

# --- this repository ---------------------------------------------------------------------------

need_file "$root/src/fixmain.pas" "the program's main file; the source tree is incomplete."
need_file "$root/src/TPC.CFG" "the compiler settings TPC.EXE reads from src."
need_file "$root/build/build.bat" "the DOS build script DOSBox-X runs."

# --- DOSBox-X on this computer -----------------------------------------------------------------

# True when dotted version $1 is at least $2.
version_at_least() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

if ! command -v dosbox-x > /dev/null 2>&1; then
    problem "DOSBox-X is not installed, or not on PATH: install DOSBox-X $dosbox_min or later."
else
    dosbox_version="$(dosbox-x --version 2>&1 | sed -n 's/^DOSBox-X version \([0-9.]*\).*/\1/p' | head -n 1)"
    if [ -z "$dosbox_version" ]; then
        problem "Could not read DOSBox-X's version from 'dosbox-x --version': install DOSBox-X $dosbox_min or later."
    elif ! version_at_least "$dosbox_version" "$dosbox_min"; then
        problem "DOSBox-X $dosbox_version is too old: version $dosbox_min or later is needed."
    fi
fi

if [ ${#problems[@]} -gt 0 ]; then
    echo "build.sh: cannot build. Fix these first:" >&2
    for p in "${problems[@]}"; do
        echo "  - $p" >&2
    done
    exit 1
fi

# --- build -------------------------------------------------------------------------------------

mkdir -p "$root/obj" "$root/build/logs"
rm -f "$root/obj/START.EXE" "$root/obj/GAME.OVR" "$root"/build/logs/*.OUT

echo "build.sh: compiling in DOSBox-X..."
dosbox-x -silent -exit -noautoexec -set "cpu cycles=max" \
    -c "mount d \"$tp\"" \
    -c "mount e \"$root\"" \
    -c "mount f \"$tasm\"" \
    -c "e:" \
    -c "cd \\src" \
    -c "call \\build\\build.bat" \
    -c "exit" > /dev/null 2>&1

# DOSBox-X's own exit status says nothing about the build; the logs and the outputs do.
failed=0
if grep -qi "error" "$root/build/logs/TPC.OUT" 2> /dev/null; then
    echo "build.sh: the compiler reported errors (build/logs/TPC.OUT):" >&2
    grep -i -B1 -A2 "error" "$root/build/logs/TPC.OUT" >&2
    failed=1
fi
if grep -qiE "^\*+(error|fatal)" "$root/build/logs/TASM.OUT" 2> /dev/null; then
    echo "build.sh: the assembler reported errors (build/logs/TASM.OUT):" >&2
    grep -iE "error|fatal" "$root/build/logs/TASM.OUT" >&2
    failed=1
fi
for f in START.EXE GAME.OVR; do
    if [ ! -f "$root/obj/$f" ]; then
        echo "build.sh: the build did not produce obj/$f; see build/logs." >&2
        failed=1
    fi
done
[ $failed -eq 0 ] || exit 1

echo "build.sh: built:"
(cd "$root/obj" && sha256sum START.EXE GAME.OVR | sed 's/^/  /')
[ $install -eq 1 ] || exit 0

# --- install -----------------------------------------------------------------------------------

# Keep SSI's originals once, the first time a build replaces them.
if [ ! -d "$game/SSI" ]; then
    mkdir -p "$game/SSI"
    cp -p "$game/START.EXE" "$game/GAME.OVR" "$game/SSI/"
    echo "build.sh: kept the original START.EXE and GAME.OVR in drive_c/POOLRAD/SSI"
fi
cp "$root/obj/START.EXE" "$root/obj/GAME.OVR" "$game/"

echo "build.sh: installed into drive_c/POOLRAD"
