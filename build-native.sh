#!/usr/bin/env bash
#
# build-native.sh -- build Pool of Radiance with Free Pascal as a native program, and run the unit tests natively.
#
#   ./build-native.sh [TARGET...]           build the game for each target (the default: x86_64-linux)
#   ./build-native.sh --test [TARGET...]    build each target's unit tests from tests/ and run them
#
# The targets are i386-linux, x86_64-linux, i386-win32 and x86_64-win64, and on a Mac aarch64-darwin, x86_64-darwin and
# macos (both of those, merged by lipo into one program in obj/native/macos/Pool of Radiance.app). Windows tests run
# under Wine, x86_64-darwin's on an Apple Silicon Mac under Rosetta. On Linux and macOS SDL3 is linked in statically
# (from tools/sdl3-setup.sh's libSDL3.a), so the program needs no SDL library beside it. Output goes to
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
make_app=0
targets=()
for arg in "$@"; do
    case "$arg" in
        --test) run_tests=1 ;;
        i386-linux | x86_64-linux | i386-win32 | x86_64-win64 | aarch64-darwin | x86_64-darwin) targets+=("$arg") ;;
        macos) targets+=(aarch64-darwin x86_64-darwin); make_app=1 ;;
        *) echo "build-native.sh: unknown option $arg (the options are --test and the targets i386-linux," \
               "x86_64-linux, i386-win32, x86_64-win64, aarch64-darwin, x86_64-darwin and macos)" >&2
           exit 2 ;;
    esac
done
if [ ${#targets[@]} -eq 0 ]; then
    case "$(uname -s)" in
        Darwin) targets=(aarch64-darwin x86_64-darwin); make_app=1 ;;
        *) targets=(x86_64-linux) ;;
    esac
fi
sdl_home="$("$root/tools/sdl3-setup.sh" --print)"

problems=()
[ -x "$fpc" ] || problems+=("Free Pascal is not in $fpc_home: run tools/fpc-setup.sh.")
[ -f "$fpc_cfg" ] || problems+=("$fpc_cfg is missing: run tools/fpc-setup.sh.")
command -v python3 > /dev/null 2>&1 || problems+=("python3 is not on PATH: tools/snd2pas.py needs it.")
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

# fpc_for <target> [library folder]: the compiler command for a target, with a folder for the linker to search. -Mtp
# keeps Turbo Pascal's 16-bit Integer, short strings and procedure variables; -gl puts line numbers in a runtime
# error's trace; COMPILER.INC (included by every unit) sets the rest; TpCompat (-Fa) supplies the System routines Free
# Pascal lacks.
fpc_for() {
    local cpu="${1%%-*}" os="${1#*-}" extra="" libs=""
    # macOS: the oldest version the program runs on, SDL3's own (sdl3-setup.sh)
    [ "$os" = darwin ] && extra="-WM11.0"
    [ -n "${2:-}" ] && libs="-Fl$2"
    echo "$fpc $libs -n @$fpc_cfg -Mtp -gl -P$cpu -T$os -Fu$root/src -Fu$root/src/includes -Fu$root/src/native" \
        "-Fi$root/src/includes -Fi$root/obj -FaTpCompat $extra"
}

# sdl_lib_for <target>: the folder of SDL3's libraries for a target
sdl_lib_for() {
    case "$1" in
        *-darwin) echo "$sdl_home/universal-darwin/lib" ;;
        *) echo "$sdl_home/$1/lib" ;;
    esac
}

# run_exe <target> <folder> <program>: run a built program from its folder, under Wine for Windows.
run_exe() {
    case "$1" in
        *-win*) (cd "$2" && WINEDEBUG=-all wine "./$3.exe" > /dev/null 2>&1) ;;
        x86_64-darwin) (cd "$2" && arch -x86_64 "./$3" > /dev/null 2>&1) ;;
        *) (cd "$2" && "./$3" > /dev/null 2>&1) ;;
    esac
}

# The headless tests. A unit in tests/ (TestKit, SndTrc) is not a test. TSndOpl checks the AdLib's output, which the
# native build does not play (its Digital Audio is the Tandy's music and the Sound Blaster's samples): skipped.
tests=()
skipped=()
for t in "$root"/tests/*.pas; do
    grep -qiE '^unit ' "$t" && continue
    case "$(basename "$t" .pas)" in
        tsndopl) skipped+=("$(basename "$t" .pas)") ;;
        *) tests+=("$(basename "$t" .pas)") ;;
    esac
done

# Compiler output mentions every file; a line of this shape is a real failure.
fpc_error='(Error|Fatal):'
failed=0
"$root/build/buildid.sh"
# the sound sequencer's tunes, as SndSeq's image of the driver's segment
python3 -I "$root/tools/snd2pas.py" --src "$root/src" --out "$root/obj/SNDIMAGE.INC" || exit 1

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
        [ ${#skipped[@]} -eq 0 ] || echo "build-native.sh: $target: skipped (the AdLib is not played natively):" \
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
        lib_dir=""
        case "$target" in
            *-win*) exe=poolrad.exe; extra="-WG" ;;
            *)
                # the static library under a name of its own (Sdl3Min links -lSDL3static), so no shared libSDL3 in
                # a system folder can be taken instead
                mkdir -p "$out/sdl"
                cp "$(sdl_lib_for "$target")/libSDL3.a" "$out/sdl/libSDL3static.a" \
                    || { echo "build-native.sh: $target: no libSDL3.a: run tools/sdl3-setup.sh." >&2; failed=1; continue; }
                lib_dir="$out/sdl" ;;
        esac
        echo "build-native.sh: $target: compiling the game..."
        if ! $(fpc_for "$target" "$lib_dir") $extra -FU"$units" -FE"$out" -o"$exe" "$root/src/fixmain.pas" > "$out/FPC.OUT" 2>&1 \
                || grep -qE "$fpc_error" "$out/FPC.OUT"; then
            echo "build-native.sh: $target: the game did not compile (obj/native/$target/FPC.OUT):" >&2
            grep -E "$fpc_error" "$out/FPC.OUT" | head -n 20 | sed 's/^/    /' >&2
            failed=1
            continue
        fi
        echo "build-native.sh: $target: built obj/native/$target/$exe"
    fi
done

# macos: the two programs as one (lipo) in Pool of Radiance.app, signed ad hoc so it runs here (tools/macos-sign.sh
# signs it with a Developer ID and notarizes it). The game's data is found beside the app (NatFile.EnterGameFolder).
if [ $failed -eq 0 ] && [ $run_tests -eq 0 ] && [ $make_app -eq 1 ]; then
    app="$root/obj/native/macos/Pool of Radiance.app"
    version="$(sed -n "s/.*BUILD_VERSION = 'v\([0-9.]*\)-\([0-9]*\)'.*/\1.\2/p" "$root/obj/BUILDID.INC")"
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    lipo -create "$root/obj/native/aarch64-darwin/poolrad" "$root/obj/native/x86_64-darwin/poolrad" \
        -output "$app/Contents/MacOS/poolrad" || failed=1
    cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Pool of Radiance</string>
    <key>CFBundleDisplayName</key><string>Pool of Radiance</string>
    <key>CFBundleIdentifier</key><string>com.brazencrows.poolofradiance</string>
    <key>CFBundleExecutable</key><string>poolrad</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$version</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.role-playing-games</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
    codesign --force --sign - "$app" > /dev/null 2>&1 || failed=1
    [ $failed -ne 0 ] || echo "build-native.sh: macos: built obj/native/macos/Pool of Radiance.app ($version," \
        "$(lipo -archs "$app/Contents/MacOS/poolrad"))"
fi

if [ $failed -ne 0 ]; then
    echo "build-native.sh: failed." >&2
    exit 1
fi
[ $run_tests -eq 0 ] || echo "build-native.sh: the unit tests passed."
