#!/usr/bin/env bash
#
# vidbench.sh -- time the video primitives in each video mode (refactor plan, phase 6, step 0).
#
#   bench/vidbench.sh [CYCLES]
#
# Compiles bench/vidbench.pas against src, as build.sh compiles the unit tests. SOUNDDRV.OBJ comes from obj, so run
# ./build.sh first. Then runs it once per mode under DOSBox-X at a fixed speed, CYCLES (default 10000) emulated cycles
# a millisecond: CGA and EGA on an EGA machine, Tandy on a Tandy machine. Prints obj/bench/VIDBENCH.LOG: mode,
# workload, runs, BIOS ticks, runs a second. Only rates taken at the same CYCLES compare; the speed is fixed so the
# host's load does not move them.

set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cycles="${1:-10000}"
compiler="$(sed -n 's/^compiler=//p' "$root/build/toolchain" 2> /dev/null)"
tp="${TOOLS:-$root/drive_c}/${compiler:-TP50}"
out="$root/obj/bench"
mkdir -p "$out"
rm -f "$out"/*
printf '@echo off\r\npath d:\\\r\ncd \\bench\r\ntpc vidbench.pas /B /E..\\obj\\bench /O..\\obj > e:\\obj\\bench\\TPC.OUT\r\n' \
    > "$out/COMPILE.BAT"
timeout --foreground -k 10 300 dosbox-x -defaultconf -silent -exit -noautoexec -set "cpu cycles=max" \
    -c "mount d \"$tp\"" -c "mount e \"$root\"" -c "e:" -c "call \\obj\\bench\\COMPILE.BAT" -c "exit" \
    > "$out/DOSBOX.OUT" 2>&1
if [ ! -f "$out/VIDBENCH.EXE" ]; then
    echo "vidbench.sh: vidbench.pas did not compile (obj/bench/TPC.OUT):" >&2
    tail -n 5 "$out/TPC.OUT" >&2
    exit 1
fi
for m in C:ega E:ega T:tandy; do
    timeout --foreground -k 10 300 dosbox-x -defaultconf -silent -exit -noautoexec \
        -set "machine=${m#*:}" -set "cpu cycles=fixed $cycles" -set "cpu core=normal" \
        -c "mount e \"$root\"" -c "e:" -c "cd \\obj\\bench" -c "VIDBENCH ${m%%:*}" -c "exit" \
        >> "$out/DOSBOX.OUT" 2>&1
done
echo "vidbench.sh: $cycles cycles"
cat "$out/VIDBENCH.LOG"
