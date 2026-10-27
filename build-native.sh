#!/usr/bin/env bash
#
# Build the native Pool of Radiance ports with Free Pascal, or run their unit tests.
#
#   ./build-native.sh [TARGET...]           build the game for each target (the default: x86_64-linux)
#   ./build-native.sh --test [TARGET...]    build each target's unit tests from tests/ and run them
#
# Supported targets are i386-linux, x86_64-linux, i386-win32, and x86_64-win64. Apple Silicon Macs also support
# aarch64-darwin and macos; the latter packages the executable as obj/native/macos/Pool of Radiance.app. Intel Macs
# are not supported because Apple deprecated them in macOS 26.
#
# Windows tests run under Wine. Linux and macOS link SDL3 statically, so they do not need an SDL library beside the
# executable. Builds go to obj/native/<target>/. Tests and their logs go to obj/native/<target>/tests/. On macOS,
# poolcfg remains in the aarch64-darwin output directory beside the packaged app (#894).
#
# The toolchain comes from tools/fpc-setup.sh (Free Pascal) and tools/sdl3-setup.sh (SDL3); FPC_PREFIX moves both.
# This is the native port's development build driver. It can eventually be folded into the main build script.

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
        i386-linux | x86_64-linux | i386-win32 | x86_64-win64 | aarch64-darwin) targets+=("$arg") ;;
        macos) targets+=(aarch64-darwin); make_app=1 ;;
        *) echo "build-native.sh: unknown option $arg (the options are --test and the targets i386-linux," \
               "x86_64-linux, i386-win32, x86_64-win64, aarch64-darwin and macos)" >&2
           exit 2 ;;
    esac
done
if [ ${#targets[@]} -eq 0 ]; then
    case "$(uname -s)" in
        Darwin) targets=(aarch64-darwin); make_app=1 ;;
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

# Print the compiler command for a target, optionally adding a library search directory. -Mtp preserves Turbo
# Pascal's 16-bit Integer, short strings, and procedure variables. -gl adds source lines to runtime stack traces.
# COMPILER.INC sets the remaining compatibility options, and TpCompat supplies missing System routines.
fpc_for() {
    local cpu="${1%%-*}" os="${1#*-}" extra="" libs=""
    # Match SDL's minimum macOS version and add clang's runtime library directory. The generated FPC configuration
    # does not include libclang_rt.osx.a for aarch64.
    [ "$os" = darwin ] && extra="-WM11.0 -Fl$(xcrun clang -print-runtime-dir)"
    # The 32-bit C runtime is wherever the distribution keeps it (/usr/lib32 on Arch, /usr/lib/i386-linux-gnu on
    # Debian). FPC would take /lib's 64-bit crti.o first: -Xd keeps it from its default folders, and gcc names the one.
    [ "$1" = i386-linux ] && command -v gcc > /dev/null 2>&1 \
        && extra="-Xd -Fl$(dirname "$(gcc -m32 -print-file-name=crti.o)")"
    [ -n "${2:-}" ] && libs="-Fl$2"
    echo "$fpc $libs -n @$fpc_cfg -Mtp -gl -P$cpu -T$os -Fu$root/src -Fu$root/src/includes -Fu$root/src/native" \
        "-Fi$root/src/includes -Fi$root/obj -FaTpCompat $extra"
}

# Print the SDL3 library directory for a target.
sdl_lib_for() {
    case "$1" in
        *) echo "$sdl_home/$1/lib" ;;
    esac
}

# Uppercase text without Bash 4's ${value^^}, which is unavailable in macOS's Bash 3.2.
upper() {
    echo "$*" | tr '[:lower:]' '[:upper:]'
}

# Run a built program from its output directory. Windows targets use Wine.
run_exe() {
    case "$1" in
        *-win*) (cd "$2" && WINEDEBUG=-all wine "./$3.exe" > /dev/null 2>&1) ;;
        *) (cd "$2" && "./$3" > /dev/null 2>&1) ;;
    esac
}

# Collect the headless test programs, skipping support units. TSndOpl is also skipped because the native port does
# not play AdLib output; its Digital Audio mode uses Tandy music and Sound Blaster samples instead.
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
"$root/tools/buildid.sh"
# Generate the DOS sound driver's data image used by the native sequencer.
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
                echo "build-native.sh: $target: $(upper "$t") did not compile (obj/native/$target/tests/$t.OUT):" >&2
                grep -E "$fpc_error" "$out/$t.OUT" | head -n 5 | sed 's/^/    /' >&2
                failed=1
                continue
            fi
            run_exe "$target" "$out" "$t"
            if ! grep -q "^DONE $(upper "$t"):" "$out/TEST.LOG" 2> /dev/null; then
                echo "build-native.sh: $target: $(upper "$t") did not finish (no DONE line in TEST.LOG)." >&2
                failed=1
            fi
        done
        [ ${#skipped[@]} -eq 0 ] || echo "build-native.sh: $target: skipped (the AdLib is not played natively):" \
            "$(upper "${skipped[*]}")"
        if [ -f "$out/TEST.LOG" ]; then
            grep -E "^(FAIL|DONE) " "$out/TEST.LOG" | sed 's/^/  /'
            grep -q "^FAIL " "$out/TEST.LOG" && failed=1
        fi
    else
        out="$root/obj/native/$target"
        units="$out/units"
        rm -rf "$units"
        mkdir -p "$units"
        # POOLCFG is a terminal program on every platform (#894). It uses Free Pascal's Video unit rather than SDL,
        # so build it first without SDL. The Windows version remains a console application and does not use -WG.
        cfg_exe=poolcfg
        case "$target" in *-win*) cfg_exe=poolcfg.exe ;; esac
        if ! $(fpc_for "$target") -FU"$units" -FE"$out" -o"$cfg_exe" "$root/src/poolcfg.pas" > "$out/POOLCFG.OUT" 2>&1 \
                || grep -qE "$fpc_error" "$out/POOLCFG.OUT"; then
            echo "build-native.sh: $target: POOLCFG did not compile (obj/native/$target/POOLCFG.OUT):" >&2
            grep -E "$fpc_error" "$out/POOLCFG.OUT" | head -n 20 | sed 's/^/    /' >&2
            failed=1
            continue
        fi
        echo "build-native.sh: $target: built obj/native/$target/$cfg_exe"
        # The Windows game uses the GUI subsystem so it does not open a console window.
        exe=poolrad
        extra=""
        lib_dir=""
        case "$target" in
            *-win*) exe=poolrad.exe; extra="-WG" ;;
            *)
                # Give the static library a unique name. Sdl3Min links -lSDL3static, which prevents an installed
                # shared SDL3 library from being selected accidentally.
                mkdir -p "$out/sdl"
                [ -f "$(sdl_lib_for "$target")/libSDL3.a" ] \
                    || { echo "build-native.sh: $target: no libSDL3.a: run tools/sdl3-setup.sh." >&2; failed=1; continue; }
                if [ "$target" = i386-linux ]; then
                    # SDL3's C needs 32-bit libgcc for its 64-bit division (__udivdi3), after SDL3 on the link line:
                    # the "library" is a GNU ld script that groups the two.
                    echo "GROUP ( $(sdl_lib_for "$target")/libSDL3.a $(gcc -m32 -print-libgcc-file-name) )" \
                        > "$out/sdl/libSDL3static.a"
                else
                    cp "$(sdl_lib_for "$target")/libSDL3.a" "$out/sdl/libSDL3static.a"
                fi
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

# Package the macos target as Pool of Radiance.app and apply an ad-hoc signature for local use. tools/macos-sign.sh
# replaces it with a Developer ID signature and notarizes release builds. NatFile finds the game data beside the app.
if [ $failed -eq 0 ] && [ $run_tests -eq 0 ] && [ $make_app -eq 1 ]; then
    app="$root/obj/native/macos/Pool of Radiance.app"
    version="$(sed -n "s/.*BUILD_VERSION = 'v\([0-9.]*\)-\([0-9]*\)'.*/\1.\2/p" "$root/obj/BUILDID.INC")"
    # Untagged source reports UNKNOWN; use a valid fallback bundle version in that case.
    [ -n "$version" ] || version=0.0
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$root/obj/native/aarch64-darwin/poolrad" "$app/Contents/MacOS/poolrad" || failed=1
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
