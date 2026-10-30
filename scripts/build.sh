#!/usr/bin/env bash
#
# Build the DOS game as obj/START.EXE and obj/GAME.OVR. Sources that include poolcfg.pas also produce
# obj/POOLCFG.EXE (#876); the historical SSI tags do not contain that program.
#
#   scripts/build.sh              build
#   scripts/build.sh --install    build, then copy the files into drive_c/POOLRAD to play
#   scripts/build.sh --test       build, then compile and run the unit tests in tests/ (TestKit) under the same Turbo Pascal
#
# --install updates the playable copy in drive_c/POOLRAD. Automated scripts and temporary worktrees should not use it.
#
# DOSBox-X runs build/build.bat with these drives:
#   D:  $TOOLS/<compiler>       Turbo Pascal (TPC.EXE, TURBO.TPL); build/toolchain names the folder, TP50 if absent
#   E:  this repository         src\, build\ and obj\
#   F:  $TOOLS/TASM             Turbo Assembler (TASM.EXE)
#   G:  $TOOLS/EXEPACK          Microsoft EXEPACK (EXEPACK.EXE)
# TOOLS is the folder holding the DOS toolchains, drive_c unless set (the CI workflow sets it to /drive_d).
#
# Prerequisites are checked together so one run reports every missing file or tool.

set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
drive_c="$root/drive_c"
game="$drive_c/POOLRAD"
tools="${TOOLS:-$drive_c}"
# build/toolchain selects the compiler directory, for example TP6-1991.
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
    # Arguments: path, followed by its description for an error message.
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

# Only one build may use a checkout at a time because builds share obj/, build/logs/, and src/*.TPU. gametools uses
# the same lock. A build started by gametools inherits a token that lets it continue while that outer lock is held.
lock="$root/.build.lock"
token="${GOLDBOX_TREE_LOCK_TOKEN:-}"
if [ -z "$token" ] || [ "${token%#*}" != "$(cd "$root" && pwd -P)/.build.lock" ] \
        || [ "${token##*#}" != "$(cat "$lock" 2> /dev/null)" ]; then
    exec 9<> "$lock"
    flock -n 9 || { echo "build.sh: another build is running in this checkout (it holds .build.lock)." >&2; exit 1; }
fi

mkdir -p "$root/obj" "$root/build/logs"
rm -f "$root/obj/START.EXE" "$root/obj/GAME.OVR" "$root/obj/POOLCFG.EXE" "$root"/build/logs/*.OUT

# Track the expected outputs. Historical sources do not include the setup program.
outputs=(START.EXE GAME.OVR)
[ -f "$root/src/poolcfg.pas" ] && outputs+=(POOLCFG.EXE)

# Generate the version and commit shown on the Options screen.
"$root/scripts/buildid.sh"

echo "build.sh: compiling in DOSBox-X..."
# Send DOSBox-X's messages to DOSBOX.OUT and stop it after ten minutes. Normal builds take seconds, so reaching the
# timeout usually means DOSBox-X is waiting at a prompt. -defaultconf ignores the user's configuration and keeps
# local builds consistent with CI.
dosbox_timeout=600
# Run DOSBox-X headlessly with standard input closed. Use SIGKILL for timeouts because SIGTERM opens DOSBox-X's
# graphical quit dialog (#775). Limit output files to 2 GB so a test stuck in a write loop cannot fill the disk;
# ulimit -f measures 1 KB blocks here.
run_dosbox() {
    (
        ulimit -f 2097152
        exec env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
            timeout --foreground -s KILL $dosbox_timeout dosbox-x "$@" < /dev/null
    )
}
run_dosbox -defaultconf -silent -exit -noautoexec -set "cpu cycles=max" \
    -c "mount d \"$tp\"" \
    -c "mount e \"$root\"" \
    -c "mount f \"$tasm\"" \
    -c "mount g \"$exepack\"" \
    -c "e:" \
    -c "cd \\src" \
    -c "call \\build\\build.bat" \
    -c "exit" > "$root/build/logs/DOSBOX.OUT" 2>&1
dosbox_status=$?

# DOSBox-X does not propagate the batch file's status, so validate the logs and expected outputs instead. Its status
# still reveals a timeout, and a missing TPC.OUT means build.bat never started.
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
for out in TPC.OUT TPCCFG.OUT; do
    if grep -qE "$tpc_error" "$root/build/logs/$out" 2> /dev/null; then
        echo "build.sh: the compiler reported errors (build/logs/$out):" >&2
        grep -E -B1 -A2 "$tpc_error" "$root/build/logs/$out" >&2
        failed=1
    fi
done
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
for f in "${outputs[@]}"; do
    if [ ! -f "$root/obj/$f" ]; then
        echo "build.sh: the build did not produce obj/$f; see build/logs." >&2
        failed=1
    fi
done
[ $failed -eq 0 ] || exit 1

echo "build.sh: built:"
(cd "$root/obj" && sha256sum "${outputs[@]}" | sed 's/^/  /')

# Report the size limits tracked by the refactor plan: resident code, the 64 KB data segment, and overlay load sizes.
# TPC prints code and data sizes on its final line; ovlsizes.py reads the overlay stubs.
sizes="$(tail -n 1 "$root/build/logs/TPC.OUT" | sed -n 's/.* \([0-9]*\) bytes code, \([0-9]*\) bytes data.*/\1 \2/p')"
if [ -n "$sizes" ]; then
    set -- $sizes
    echo "build.sh: code $1 bytes; data $2 of 65520 bytes ($((65520 - $2)) free)"
fi
if command -v python3 > /dev/null 2>&1 && [ -f "$root/obj/FIXMAIN.EXE" ] && [ -f "$root/obj/FIXMAIN.MAP" ]; then
    python3 -I "$root/scripts/ovlsizes.py" "$root/obj/FIXMAIN.EXE" "$root/obj/FIXMAIN.MAP" | sed 's/^/build.sh: /'
fi
echo "build.sh: files: $(cd "$root/obj" && for f in "${outputs[@]}"; do printf '%s %s bytes; ' "$f" "$(wc -c < "$f")"; done \
    | sed 's/; $//')"

# --- unit tests ----------------------------------------------------------------------------------

if [ $run_tests -eq 1 ]; then
    tests=()
    for t in "$root"/tests/*.pas; do
        name="$(basename "$t" .pas)"
        if [ ${#name} -gt 8 ]; then
            echo "build.sh: tests/$name.pas: DOS cannot open a name longer than 8 characters" >&2
            exit 1
        fi
        # TestKit and SndTrc are support units, not executable tests.
        grep -qiE '^unit ' "$t" || tests+=("${name^^}")
    done
    mkdir -p "$root/obj/tests"
    # Compiler logs use the test name as a DOS filename, so test names must fit in eight characters.
    mkdir -p "$root/build/logs/tests"
    rm -f "$root"/obj/tests/* "$root"/build/logs/tests/*.OUT "$root"/build/logs/TEST_*.OUT
    # Generate a batch file that rebuilds every test and runs it from obj\tests. Tests append their results to
    # TEST.LOG. The compiler searches obj\tests first, then obj for shared objects such as SOUNDDRV.OBJ.
    {
        printf '@echo off\r\npath d:\\\r\n'
        for t in "${tests[@]}"; do
            printf 'cd \\tests\r\ntpc %s.pas /B /E..\\obj\\tests /O..\\obj\\tests;..\\obj > e:\\build\\logs\\tests\\%s.OUT\r\n' "$t" "$t"
            printf 'cd \\obj\\tests\r\nif exist %s.EXE %s\r\n' "$t" "$t"
        done
    } > "$root/obj/tests/RUNTESTS.BAT"
    echo "build.sh: running ${#tests[@]} test programs in DOSBox-X..."
    run_dosbox -defaultconf -silent -exit -noautoexec -set "cpu cycles=max" \
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

# Back up SSI's executables the first time an install replaces them. Do not install anything unless both copies
# succeed; a partially populated SSI directory would prevent later runs from retrying the backup.
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
if ! (cd "$root/obj" && cp "${outputs[@]}" "$game/"); then
    echo "build.sh: could not copy the build into drive_c/POOLRAD; the install there may be incomplete." >&2
    exit 1
fi

echo "build.sh: installed into drive_c/POOLRAD"
