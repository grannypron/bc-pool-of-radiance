#!/usr/bin/env bash
#
# sndbench.sh -- the sound interrupt's cost on each device (refactor plan, phase 7, step 0).
#
#   bench/sndbench.sh [CYCLES]
#
# Compiles bench/sndbench.pas, which links obj/SOUNDDRV.OBJ, so run ./build.sh first. Then runs it under DOSBox-X at a
# fixed speed, CYCLES (default 10000) emulated cycles a millisecond: the Tandy on a Tandy machine, the speaker on an EGA
# machine. Prints obj/bench/SNDBENCH.LOG: device, state (off, silent, music), loop count, and the interrupt's cost in
# hundredths of a percent of the processor. Only figures taken at the same CYCLES compare.

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
