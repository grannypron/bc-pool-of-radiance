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
# With no SCENARIO, every tests/scenarios/*.txt runs. Needs goldbox-player's server running (systemctl --user status
# gbplayer) and its checkout at GBPLAYER_HOME (~/repos/goldbox-player unless set). The golden build's results are kept
# in GOLDEN/record.json and reused while the scenario and the build are unchanged, so after the first run only the
# candidate runs. The report goes to obj/regress.json; the exit status is 0 only when every scenario matches.

set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
player="${GBPLAYER_HOME:-$HOME/repos/goldbox-player}"
[ $# -ge 1 ] || { sed -n '3,15p' "$0" >&2; exit 2; }
golden="$1"; shift
candidate="$root/obj"
if [ $# -ge 1 ] && [ -d "$1" ]; then candidate="$1"; shift; fi
scenarios=("$@")
[ ${#scenarios[@]} -gt 0 ] || scenarios=("$root"/tests/scenarios/*.txt)
for f in "$golden/START.EXE" "$golden/GAME.OVR" "$candidate/START.EXE" "$candidate/GAME.OVR"; do
    [ -f "$f" ] || { echo "regress.sh: missing $f" >&2; exit 2; }
done
[ -x "$player/.venv/bin/python" ] || { echo "regress.sh: no goldbox-player checkout at $player" >&2; exit 2; }
exec "$player/.venv/bin/python" "$player/tools/regress.py" --golden "$golden" --candidate "$candidate" \
    --config "$root/tests/scenarios/POOL.CFG" --record "$golden/record.json" --report "$root/obj/regress.json" \
    "${scenarios[@]}"
