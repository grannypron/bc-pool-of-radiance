#!/usr/bin/env bash
#
# Benchmark the drawing primitives in each video mode (refactor plan, phase 6, step 0).
#
#   bench/vidbench.sh [CYCLES]
#
# Run ./build.sh first because the benchmark links obj/SOUNDDRV.OBJ. The script tests CGA and EGA on an emulated EGA
# machine and Tandy video on an emulated Tandy. DOSBox-X is fixed at CYCLES emulated cycles per millisecond (10,000
# by default), which keeps host load from affecting the result. VIDBENCH.LOG reports the mode, workload, run count,
# BIOS ticks, and runs per second. Compare only results recorded with the same CYCLES value.

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
