#!/usr/bin/env bash
#
# build-native.sh -- build Pool of Radiance with Free Pascal as a native program, and run the unit tests natively.
#
#   ./build-native.sh [TARGET...]           build the game for each target (the default: x86_64-linux)
#   ./build-native.sh --test [TARGET...]    build each target's unit tests from tests/ and run them
#
# The targets are i386-linux, x86_64-linux, i386-win32 and x86_64-win64. Windows tests run under Wine. Output goes to
# obj/native/<target>/ (the game) and obj/native/<target>/tests/ (the tests, each test's compiler output beside it as
# <name>.OUT, and TEST.LOG).
#
# The toolchain comes from tools/fpc-setup.sh (Free Pascal) and tools/sdl3-setup.sh (SDL3); FPC_PREFIX moves both.
# This script is the exploration-time driver; build.sh --target takes it over when the port joins the main build.

set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fpc_home="$("$root/tools/fpc-setup.sh" --print)"
fpc="$fpc_home/bin/fpc"
fpc_cfg="$fpc_home/etc/fpc.cfg"

run_tests=0
targets=()
for arg in "$@"; do
    case "$arg" in
        --test) run_tests=1 ;;
        i386-linux | x86_64-linux | i386-win32 | x86_64-win64) targets+=("$arg") ;;
        *) echo "build-native.sh: unknown option $arg" \
               "(the options are --test and the targets i386-linux, x86_64-linux, i386-win32, x86_64-win64)" >&2
           exit 2 ;;
    esac
done
[ ${#targets[@]} -gt 0 ] || targets=(x86_64-linux)

problems=()
[ -x "$fpc" ] || problems+=("Free Pascal is not in $fpc_home: run tools/fpc-setup.sh.")
[ -f "$fpc_cfg" ] || problems+=("$fpc_cfg is missing: run tools/fpc-setup.sh.")
for t in "${targets[@]}"; do
    case "$t" in
        *-win*) [ $run_tests -eq 0 ] || command -v wine > /dev/null 2>&1 \
                    || problems+=("Wine is not on PATH: the $t tests run under it.") ;;
    esac
done
if [ ${#problems[@]} -gt 0 ]; then
    echo "build-native.sh: cannot build. Fix these first:" >&2
    printf '  - %s\n' "${problems[@]}" >&2
    exit 1
fi

# fpc_for <target>: the compiler command for a target. -Mtp keeps Turbo Pascal's 16-bit Integer, short strings and
# procedure variables; -gl puts line numbers in a runtime error's trace; COMPILER.INC (included by every unit) sets the
# rest; TpCompat (-Fa) supplies the System routines Free Pascal lacks.
fpc_for() {
    local cpu="${1%%-*}" os="${1#*-}"
    echo "$fpc -n @$fpc_cfg -Mtp -gl -P$cpu -T$os -Fu$root/src -Fu$root/src/includes -Fu$root/src/native" \
        "-Fi$root/src/includes -Fi$root/obj -FaTpCompat"
}

# run_exe <target> <folder> <program>: run a built program from its folder, under Wine for Windows.
run_exe() {
    case "$1" in
        *-win*) (cd "$2" && WINEDEBUG=-all wine "./$3.exe" > /dev/null 2>&1) ;;
        *) (cd "$2" && "./$3" > /dev/null 2>&1) ;;
    esac
}

# The headless tests. A unit in tests/ (TestKit, SndTrc) is not a test. A test that uses SndTrc links the TASM trace
# build of the sound driver, which a native build does not have until the sequencer is ported to Pascal: skipped.
tests=()
skipped=()
for t in "$root"/tests/*.pas; do
    grep -qiE '^unit ' "$t" && continue
    if grep -qiE '^uses .*\bSndTrc\b' "$t"; then
        skipped+=("$(basename "$t" .pas)")
    else
        tests+=("$(basename "$t" .pas)")
    fi
done

# Compiler output mentions every file; a line of this shape is a real failure.
fpc_error='(Error|Fatal):'
failed=0
"$root/build/buildid.sh"

for target in "${targets[@]}"; do
    if [ $run_tests -eq 1 ]; then
        out="$root/obj/native/$target/tests"
        rm -rf "$out"
        mkdir -p "$out"
        echo "build-native.sh: $target: building and running ${#tests[@]} test programs..."
        for t in "${tests[@]}"; do
            if ! $(fpc_for "$target") -FU"$out" -FE"$out" "$root/tests/$t.pas" > "$out/$t.OUT" 2>&1 \
                    || grep -qE "$fpc_error" "$out/$t.OUT"; then
                echo "build-native.sh: $target: ${t^^} did not compile (obj/native/$target/tests/$t.OUT):" >&2
                grep -E "$fpc_error" "$out/$t.OUT" | head -n 5 | sed 's/^/    /' >&2
                failed=1
                continue
            fi
            run_exe "$target" "$out" "$t"
            if ! grep -q "^DONE ${t^^}:" "$out/TEST.LOG" 2> /dev/null; then
                echo "build-native.sh: $target: ${t^^} did not finish (no DONE line in TEST.LOG)." >&2
                failed=1
            fi
        done
        [ ${#skipped[@]} -eq 0 ] || echo "build-native.sh: $target: skipped (they need the TASM sound driver):" \
            "${skipped[*]^^}"
        if [ -f "$out/TEST.LOG" ]; then
            grep -E "^(FAIL|DONE) " "$out/TEST.LOG" | sed 's/^/  /'
            grep -q "^FAIL " "$out/TEST.LOG" && failed=1
        fi
    else
        out="$root/obj/native/$target"
        units="$out/units"
        rm -rf "$units"
        mkdir -p "$units"
        # Windows: poolrad.exe, a GUI program (no console window opens beside the game's)
        exe=poolrad
        extra=""
        case "$target" in
            *-win*) exe=poolrad.exe; extra="-WG" ;;
        esac
        echo "build-native.sh: $target: compiling the game..."
        if ! $(fpc_for "$target") $extra -FU"$units" -FE"$out" -o"$exe" "$root/src/fixmain.pas" > "$out/FPC.OUT" 2>&1 \
                || grep -qE "$fpc_error" "$out/FPC.OUT"; then
            echo "build-native.sh: $target: the game did not compile (obj/native/$target/FPC.OUT):" >&2
            grep -E "$fpc_error" "$out/FPC.OUT" | head -n 20 | sed 's/^/    /' >&2
            failed=1
            continue
        fi
        echo "build-native.sh: $target: built obj/native/$target/$exe"
    fi
done

if [ $failed -ne 0 ]; then
    echo "build-native.sh: failed." >&2
    exit 1
fi
[ $run_tests -eq 0 ] || echo "build-native.sh: the unit tests passed."
