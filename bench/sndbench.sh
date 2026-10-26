#!/usr/bin/env bash
#
# Measure the sound interrupt's cost for each supported device (refactor plan, phase 7, step 0).
#
#   bench/sndbench.sh [CYCLES]
#
# Run ./build.sh first because the benchmark links obj/SOUNDDRV.OBJ. The script runs the Tandy driver on an emulated
# Tandy and the speaker driver on an emulated EGA machine. DOSBox-X is fixed at CYCLES emulated cycles per millisecond
# (10,000 by default), so only results recorded with the same value are comparable. SNDBENCH.LOG reports the device,
# state, loop count, and interrupt cost in hundredths of a percent of CPU time.

set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cycles="${1:-10000}"
compiler="$(sed -n 's/^compiler=//p' "$root/build/toolchain" 2> /dev/null)"
tp="${TOOLS:-$root/drive_c}/${compiler:-TP50}"
out="$root/obj/bench"
mkdir -p "$out"
rm -f "$out"/*
printf '@echo off\r\npath d:\\\r\ncd \\bench\r\ntpc sndbench.pas /B /E..\\obj\\bench /O..\\obj > e:\\obj\\bench\\TPC.OUT\r\n' \
    > "$out/COMPILE.BAT"
timeout --foreground -k 10 300 dosbox-x -defaultconf -silent -exit -noautoexec -set "cpu cycles=max" \
    -c "mount d \"$tp\"" -c "mount e \"$root\"" -c "e:" -c "call \\obj\\bench\\COMPILE.BAT" -c "exit" \
    > "$out/DOSBOX.OUT" 2>&1
if [ ! -f "$out/SNDBENCH.EXE" ]; then
    echo "sndbench.sh: sndbench.pas did not compile (obj/bench/TPC.OUT):" >&2
    tail -n 5 "$out/TPC.OUT" >&2
    exit 1
fi
for m in T:tandy P:ega; do
    timeout --foreground -k 10 300 dosbox-x -defaultconf -silent -exit -noautoexec \
        -set "machine=${m#*:}" -set "cpu cycles=fixed $cycles" -set "cpu core=normal" \
        -c "mount e \"$root\"" -c "e:" -c "cd \\obj\\bench" -c "SNDBENCH ${m%%:*}" -c "exit" \
        >> "$out/DOSBOX.OUT" 2>&1
done
echo "sndbench.sh: $cycles cycles"
cat "$out/SNDBENCH.LOG"
