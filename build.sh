#!/usr/bin/env bash
#
# build.sh -- build Pool of Radiance from src/ into obj/START.EXE and obj/GAME.OVR.
#
#   ./build.sh              build
#   ./build.sh --install    build, then copy the two files into drive_c/POOLRAD to play
#   ./build.sh --test       build, then compile and run the unit tests in tests/ (TestKit) under the same Turbo Pascal
#
# --install replaces the play install in this checkout's drive_c/POOLRAD; scripts and worktrees should not pass it.
#
# DOSBox-X runs build/build.bat with these drives:
#   D:  $TOOLS/<compiler>       Turbo Pascal (TPC.EXE, TURBO.TPL); build/toolchain names the folder, TP50 if absent
#   E:  this repository         src\, build\ and obj\
#   F:  $TOOLS/TASM             Turbo Assembler (TASM.EXE)
#   G:  $TOOLS/EXEPACK          Microsoft EXEPACK (EXEPACK.EXE)
# TOOLS is the folder holding the DOS toolchains, drive_c unless set (the CI workflow sets it to /drive_d).
#
# Everything the build needs is checked first; every missing piece is reported before the script stops.

set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
drive_c="$root/drive_c"
game="$drive_c/POOLRAD"
tools="${TOOLS:-$drive_c}"
# The source's compiler: build/toolchain holds a line like "compiler=TP6-1991".
compiler="$(sed -n 's/^compiler=\([A-Za-z0-9._-]*\).*/\1/p' "$root/build/toolchain" 2> /dev/null | head -n 1)"
compiler="${compiler:-TP50}"
tp="$tools/$compiler"
tasm="$tools/TASM"
exepack="$tools/EXEPACK"
dosbox_min="2025.02.01"

install=0
run_tests=0
for arg in "$@"; do
    case "$arg" in
        --install) install=1 ;;
        --test) run_tests=1 ;;
        *) echo "build.sh: unknown option $arg (the options are --install and --test)" >&2; exit 2 ;;
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
need_dir "$tp" "Turbo Pascal ($compiler), which compiles the game."
need_file "$tp/TPC.EXE" "the Turbo Pascal command-line compiler."
need_file "$tp/TURBO.TPL" "the Turbo Pascal runtime library, which TPC.EXE needs."
need_dir "$tasm" "Turbo Assembler, which assembles src/sounddrv.asm."
need_file "$tasm/TASM.EXE" "the Turbo Assembler executable."
need_dir "$exepack" "Microsoft EXEPACK, which packs START.EXE."
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
command -v timeout > /dev/null 2>&1 \
    || problem "timeout (GNU coreutils) is not on PATH: build.sh uses it to stop a DOSBox-X that never exits."
command -v flock > /dev/null 2>&1 \
    || problem "flock (util-linux) is not on PATH: build.sh uses it to keep two builds in this checkout apart."

if [ ${#problems[@]} -gt 0 ]; then
    echo "build.sh: cannot build. Fix these first:" >&2
    for p in "${problems[@]}"; do
        echo "  - $p" >&2
    done
    exit 1
fi

# --- build -------------------------------------------------------------------------------------

# One build at a time in this checkout: two would delete and write the same obj/, build/logs and src/*.TPU. gametools
# takes the same lock (goldbox.treelock); a build it starts carries its token for this lock and goes ahead under it.
lock="$root/.build.lock"
token="${GOLDBOX_TREE_LOCK_TOKEN:-}"
if [ -z "$token" ] || [ "${token%#*}" != "$(cd "$root" && pwd -P)/.build.lock" ] \
        || [ "${token##*#}" != "$(cat "$lock" 2> /dev/null)" ]; then
    exec 9<> "$lock"
    flock -n 9 || { echo "build.sh: another build is running in this checkout (it holds .build.lock)." >&2; exit 1; }
fi

mkdir -p "$root/obj" "$root/build/logs"
rm -f "$root/obj/START.EXE" "$root/obj/GAME.OVR" "$root"/build/logs/*.OUT

# obj/BUILDID.INC names the source for the Options screen: BUILD_VERSION is the last release tag (v1.3, not tags with a
# hyphen such as v0.0-ci-test) and the commits since it, BUILD_COMMIT the commit, with MODIFIED when src/ or build/ has
# changes git has not committed. Without git, or outside a repository, both read UNKNOWN. A source that does not
# include the file, as SSI's tags do not, builds the same bytes as before.
describe="$(git -C "$root" describe --tags --long --match 'v[0-9]*' --exclude '*-*' HEAD 2> /dev/null)"
build_version="UNKNOWN"
if [ -n "$describe" ]; then
    # vX.Y-N-gHASH: the tag alone when N is 0, else the tag and N
    build_version="$(printf '%s' "$describe" | sed -e 's/-g[0-9a-f]*$//' -e 's/-0$//')"
fi
build_commit="$(git -C "$root" rev-parse --short=7 HEAD 2> /dev/null)" || build_commit=""
build_commit="${build_commit:-UNKNOWN}"
if [ "$build_commit" != "UNKNOWN" ] && [ -n "$(git -C "$root" status --porcelain -- src build 2> /dev/null)" ]; then
    build_commit="$build_commit MODIFIED"
fi
# Only characters a Pascal string and the game font take, and no longer than the screen shows.
build_version="$(printf '%s' "$build_version" | tr -cd 'A-Za-z0-9.+-' | cut -c 1-23)"
build_commit="$(printf '%s' "$build_commit" | tr -cd 'A-Za-z0-9 ' | cut -c 1-23)"
printf "const\r\n  BUILD_VERSION = '%s';\r\n  BUILD_COMMIT = '%s';\r\n" "$build_version" "$build_commit" \
    > "$root/obj/BUILDID.INC"

echo "build.sh: compiling in DOSBox-X..."
# DOSBox-X's own messages go to build/logs/DOSBOX.OUT. A build takes seconds; one that has not finished in ten minutes
# is stuck (DOSBox-X waiting at a prompt, say) and is stopped. --foreground keeps Ctrl-C reaching DOSBox-X.
# -defaultconf: DOSBox-X's built-in settings, not the user's config file, so a local build runs as CI's does.
dosbox_timeout=600
timeout --foreground -k 10 $dosbox_timeout dosbox-x -defaultconf -silent -exit -noautoexec -set "cpu cycles=max" \
    -c "mount d \"$tp\"" \
    -c "mount e \"$root\"" \
    -c "mount f \"$tasm\"" \
    -c "mount g \"$exepack\"" \
    -c "e:" \
    -c "cd \\src" \
    -c "call \\build\\build.bat" \
    -c "exit" > "$root/build/logs/DOSBOX.OUT" 2>&1
dosbox_status=$?

# DOSBox-X's own exit status says nothing about the build; the logs and the outputs do. It does say when timeout
# stopped it, and a missing TPC.OUT means build.bat never ran.
if [ $dosbox_status -eq 124 ] || [ $dosbox_status -eq 137 ]; then
    echo "build.sh: DOSBox-X had not finished after $dosbox_timeout seconds and was stopped;" \
        "see build/logs/DOSBOX.OUT." >&2
    exit 1
fi
if [ ! -f "$root/build/logs/TPC.OUT" ]; then
    echo "build.sh: DOSBox-X did not run build.bat; see build/logs/DOSBOX.OUT:" >&2
    tail -n 20 "$root/build/logs/DOSBOX.OUT" >&2
    exit 1
fi
# TPC reports "FILE.PAS(12): Error 3: ..."; TPC.OUT also names every file it opens, so a bare "error" is not enough.
tpc_error='(^|\): )(Error|Fatal)'
failed=0
if grep -qE "$tpc_error" "$root/build/logs/TPC.OUT" 2> /dev/null; then
    echo "build.sh: the compiler reported errors (build/logs/TPC.OUT):" >&2
    grep -E -B1 -A2 "$tpc_error" "$root/build/logs/TPC.OUT" >&2
    failed=1
fi
if grep -qiE "^\*+(error|fatal)" "$root/build/logs/TASM.OUT" 2> /dev/null; then
    echo "build.sh: the assembler reported errors (build/logs/TASM.OUT):" >&2
    grep -iE "error|fatal" "$root/build/logs/TASM.OUT" >&2
    failed=1
fi
if grep -qi "error" "$root/build/logs/PACK.OUT" 2> /dev/null; then
    echo "build.sh: EXEPACK reported errors (build/logs/PACK.OUT):" >&2
    grep -i "error" "$root/build/logs/PACK.OUT" >&2
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

# The sizes a change has to watch (docs/refactor-plan.md): the resident code, the data segment's 64 KB, and the
# overlays, read from TPC's last line ("N lines, S seconds, C bytes code, D bytes data.") and the overlay stubs.
sizes="$(tail -n 1 "$root/build/logs/TPC.OUT" | sed -n 's/.* \([0-9]*\) bytes code, \([0-9]*\) bytes data.*/\1 \2/p')"
if [ -n "$sizes" ]; then
    set -- $sizes
    echo "build.sh: code $1 bytes; data $2 of 65520 bytes ($((65520 - $2)) free)"
fi
if command -v python3 > /dev/null 2>&1 && [ -f "$root/obj/FIXMAIN.EXE" ] && [ -f "$root/obj/FIXMAIN.MAP" ]; then
    python3 -I "$root/build/ovlsizes.py" "$root/obj/FIXMAIN.EXE" "$root/obj/FIXMAIN.MAP" | sed 's/^/build.sh: /'
fi

# --- unit tests ----------------------------------------------------------------------------------

if [ $run_tests -eq 1 ]; then
    tests=()
    for t in "$root"/tests/*.pas; do
        name="$(basename "$t" .pas)"
        if [ ${#name} -gt 8 ]; then
            echo "build.sh: tests/$name.pas: DOS cannot open a name longer than 8 characters" >&2
            exit 1
        fi
        # a unit the tests use (TestKit, SndTrc) is not a test
        grep -qiE '^unit ' "$t" || tests+=("${name^^}")
    done
    mkdir -p "$root/obj/tests"
    # each test's compiler output is build/logs/tests/<name>.OUT: a DOS name, so a test's name is at most 8 characters
    mkdir -p "$root/build/logs/tests"
    rm -f "$root"/obj/tests/* "$root"/build/logs/tests/*.OUT "$root"/build/logs/TEST_*.OUT
    # RUNTESTS.BAT compiles each test program (with every unit it uses, /B) into obj\tests and runs it there; each
    # appends its checks to TEST.LOG. Objects come from obj\tests, then obj, where the build assembles SOUNDDRV.OBJ.
    {
        printf '@echo off\r\npath d:\\\r\n'
        for t in "${tests[@]}"; do
            printf 'cd \\tests\r\ntpc %s.pas /B /E..\\obj\\tests /O..\\obj\\tests;..\\obj > e:\\build\\logs\\tests\\%s.OUT\r\n' "$t" "$t"
            printf 'cd \\obj\\tests\r\nif exist %s.EXE %s\r\n' "$t" "$t"
        done
    } > "$root/obj/tests/RUNTESTS.BAT"
    echo "build.sh: running ${#tests[@]} test programs in DOSBox-X..."
    timeout --foreground -k 10 $dosbox_timeout dosbox-x -defaultconf -silent -exit -noautoexec -set "cpu cycles=max" \
        -c "mount d \"$tp\"" \
        -c "mount e \"$root\"" \
        -c "e:" \
        -c "call \\obj\\tests\\RUNTESTS.BAT" \
        -c "exit" > "$root/build/logs/DOSBOX_TEST.OUT" 2>&1
    log="$root/obj/tests/TEST.LOG"
    test_failed=0
    for t in "${tests[@]}"; do
        if grep -qE "$tpc_error" "$root/build/logs/tests/$t.OUT" 2> /dev/null; then
            echo "build.sh: $t did not compile (build/logs/tests/$t.OUT):" >&2
            grep -E -B1 -A2 "$tpc_error" "$root/build/logs/tests/$t.OUT" >&2
            test_failed=1
        elif ! grep -q "^DONE $t:" "$log" 2> /dev/null; then
            echo "build.sh: $t did not finish (no DONE line in obj/tests/TEST.LOG)." >&2
            test_failed=1
        fi
    done
    if [ -f "$log" ]; then
        grep -E "^(FAIL|DONE) " "$log" | sed 's/^/  /'
        grep -q "^FAIL " "$log" && test_failed=1
    fi
    if [ $test_failed -ne 0 ]; then
        echo "build.sh: the unit tests failed." >&2
        exit 1
    fi
    echo "build.sh: the unit tests passed."
fi
[ $install -eq 1 ] || exit 0

# --- install -----------------------------------------------------------------------------------

# Keep SSI's originals once, the first time a build replaces them. Nothing is installed unless both are kept: SSI/
# left half-filled would stop every later run from trying again.
if [ ! -d "$game/SSI" ]; then
    if ! mkdir "$game/SSI"; then
        echo "build.sh: could not create drive_c/POOLRAD/SSI for the originals; nothing installed." >&2
        exit 1
    fi
    if ! cp -p "$game/START.EXE" "$game/GAME.OVR" "$game/SSI/"; then
        rm -rf "$game/SSI"
        echo "build.sh: could not back up the original START.EXE and GAME.OVR; nothing installed." >&2
        exit 1
    fi
    echo "build.sh: kept the original START.EXE and GAME.OVR in drive_c/POOLRAD/SSI"
fi
if ! cp "$root/obj/START.EXE" "$root/obj/GAME.OVR" "$game/"; then
    echo "build.sh: could not copy the build into drive_c/POOLRAD; the install there may be incomplete." >&2
    exit 1
fi

echo "build.sh: installed into drive_c/POOLRAD"
