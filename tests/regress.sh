#!/usr/bin/env bash
#
# regress.sh -- replay the behaviour scenarios in tests/scenarios against a golden build and this checkout's build,
# and compare what the screen and the save files show at each checkpoint.
#
#   tests/regress.sh GOLDEN [CANDIDATE] [SCENARIO...]
#
# GOLDEN and CANDIDATE are folders holding START.EXE and GAME.OVR; CANDIDATE is obj/ (./build.sh's output) unless
# given. Keep a golden build of the commit before a refactor, e.g. in .golden/<commit>/ (ignored by git):
#   git stash; ./build.sh; mkdir -p .golden/$(git rev-parse --short HEAD); cp obj/START.EXE obj/GAME.OVR .golden/...
# A change that makes saves differ in a way that is not behaviour (a heap address cleared, say) is applied to the golden
# commit as well, and that build kept beside it with the patch (.golden/<commit>-eq/PATCH.diff).
# With no SCENARIO, every tests/scenarios/*.txt runs. Needs goldbox-player's server running (systemctl --user status
# gbplayer) and its checkout at GBPLAYER_HOME (~/repos/goldbox-player unless set). The golden build's results are kept
# in GOLDEN/record.json and reused while the scenario and the build are unchanged, so after the first run only the
# candidate runs. The report goes to obj/regress.json; the exit status is 0 only when every scenario matches.
# VIDEO=cga, tandy or vga runs the game in that video mode (tests/scenarios/POOL-CGA.CFG, POOL-TANDY.CFG, POOL-VGA.CFG)
# instead of EGA (POOL.CFG), and keeps the golden build's results apart, in GOLDEN/record-<mode>.json. Tandy and VGA
# need goldbox-player's por-v13-tandy and por-v13-vga titles (a Tandy machine, a VGA one).
# SOUND=adlib or sb sets the config's sound letter to A (AdLib music, speaker effects) or S (a Sound Blaster) and
# gives the machine that card (goldbox-player's opl2, or sb2 with its OPL2); the golden build's results are kept apart,
# in record-adlib.json or record-sb.json. With sb, the candidate's SBSFX.DAT is staged too (copied from
# drive_c/POOLRAD, where tools/sbsfx.py writes it, when the candidate folder has none); a golden build without one runs
# without it, its effects on the speaker.
# MEMSIZE=N gives the emulator N MB instead of goldbox-player's 1 MB: more gives the game EMS, which it loads its
# overlays from (STING Ctrl-Y says from EMS or disk). Its golden results are kept apart too: record-16mb.json,
# record-vga-16mb.json and so on.

set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
player="${GBPLAYER_HOME:-$HOME/repos/goldbox-player}"
[ $# -ge 1 ] || { sed -n '3,22p' "$0" >&2; exit 2; }
golden="$1"; shift
candidate="$root/obj"
if [ $# -ge 1 ] && [ -d "$1" ]; then candidate="$1"; shift; fi
scenarios=("$@")
[ ${#scenarios[@]} -gt 0 ] || scenarios=("$root"/tests/scenarios/*.txt)
case "${VIDEO:-ega}" in
    ega) config="$root/tests/scenarios/POOL.CFG"; record="$golden/record.json"; title=por-v13 ;;
    cga) config="$root/tests/scenarios/POOL-CGA.CFG"; record="$golden/record-cga.json"; title=por-v13 ;;
    # an EGA machine cannot set Tandy's mode 9, so Tandy runs on goldbox-player's Tandy machine
    tandy) config="$root/tests/scenarios/POOL-TANDY.CFG"; record="$golden/record-tandy.json"; title=por-v13-tandy ;;
    # mode 13h needs a VGA machine; a golden build without VGA reads V as CGA, so only the screens' text compares
    vga) config="$root/tests/scenarios/POOL-VGA.CFG"; record="$golden/record-vga.json"; title=por-v13-vga ;;
    *) echo "regress.sh: VIDEO is ega, cga, tandy or vga" >&2; exit 2 ;;
esac
memsize=()
if [ -n "${MEMSIZE:-}" ] && [ "$MEMSIZE" != 1 ]; then
    memsize=(--memsize "$MEMSIZE")
    record="${record%.json}-${MEMSIZE}mb.json"
fi
# SOUND: the config's sound letter (its second line) and the card the machine gets
sound=()
case "${SOUND:-}" in
    "") ;;
    adlib) letter=A; sound=(--opl opl2) ;;
    sb) letter=S; sound=(--sb sb2 --stage SBSFX.DAT) ;;
    *) echo "regress.sh: SOUND is adlib or sb" >&2; exit 2 ;;
esac
if [ ${#sound[@]} -gt 0 ]; then
    mkdir -p "$root/obj"
    sed "2s/.*/$letter\r/" "$config" > "$root/obj/regress-$SOUND.CFG"
    config="$root/obj/regress-$SOUND.CFG"
    record="${record%.json}-$SOUND.json"
fi
# the Sound Blaster's samples: tools/sbsfx.py writes them into the play install, and a build without them (the golden)
# runs without them
if [ "${SOUND:-}" = sb ] && [ ! -f "$candidate/SBSFX.DAT" ]; then
    [ -f "$root/drive_c/POOLRAD/SBSFX.DAT" ] || { echo "regress.sh: no SBSFX.DAT; run tools/sbsfx.py" >&2; exit 2; }
    cp "$root/drive_c/POOLRAD/SBSFX.DAT" "$candidate/SBSFX.DAT"
fi
for f in "$golden/START.EXE" "$golden/GAME.OVR" "$candidate/START.EXE" "$candidate/GAME.OVR"; do
    [ -f "$f" ] || { echo "regress.sh: missing $f" >&2; exit 2; }
done
[ -x "$player/.venv/bin/python" ] || { echo "regress.sh: no goldbox-player checkout at $player" >&2; exit 2; }
exec "$player/.venv/bin/python" "$player/tools/regress.py" --golden "$golden" --candidate "$candidate" \
    --title "$title" --config "$config" --record "$record" "${memsize[@]}" "${sound[@]}" --report "$root/obj/regress.json" \
    "${scenarios[@]}"
