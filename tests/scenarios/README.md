# Behaviour scenarios

Each `.txt` file here is a scenario that `tests/regress.sh` replays, through goldbox-player's emulator harness,
against a golden build and the build under test, comparing the screen text (read exactly from the game's font) and the
save files at its checkpoints. Every scenario boots with `NORAND`, so the dice fall the same way every run, and starts
from the default saved games the harness copies in (`goldbox-player/saves/`).

The format, one step a line (`#` starts a comment):

| step | does |
| --- | --- |
| `boot WORDS` | start with WORDS after `START STING` (first line) |
| `press KEY...` | press each key: `l`, `ret`, `esc`, `up`, `alt-q`, `ctrl-y`, ... |
| `wait REGEX [SECS]` | until the menu line matches (30 s by default) |
| `checkpoint NAME` | record the screen |
| `saves NAME` | record every file in `SAVE\` (size and sha256) |
| `ignore REGEX` | leave matching text lines out of the comparison (the version string, file times) |
| `saves NAME GLOB...` | record only the files in `SAVE\` matching a glob |
| `mask GLOB [every N] OFF:LEN...` | zero those bytes (in each N-byte record) before files are compared |
| `golden: STEP`, `candidate: STEP` | a step for that build only, where the two need different keys |
| `screens off` | record screen checkpoints without comparing them |

`POOL.CFG` points the game at `C:\POOLRAD\` and `C:\POOLRAD\SAVE\`, where the harness installs it.

`POOL.CFG` runs the game in EGA. `VIDEO=cga tests/regress.sh ...` uses `POOL-CGA.CFG`, and `VIDEO=tandy` uses
`POOL-TANDY.CFG`. Each mode keeps its own golden record, `record-cga.json` or `record-tandy.json`. Tandy runs on
goldbox-player's `por-v13-tandy` title, a Tandy machine, because an EGA machine cannot set mode 9.

`combat`, `vault` and `areachange` end with an `overlay-loads` checkpoint (STING Ctrl-Y), recorded but not compared;
`tests/ovlloads.py` prints both builds' counts from the last run's `obj/regress.json`, the measure of the overlay
working sets.

A new scenario should first be run against the golden build twice (`tests/regress.sh GOLDEN GOLDEN scenario.txt`): it
must pass, or it depends on something other than the build (timing, a key arriving early). A frame that differs while
the text matches (an animated picture) is only a warning.

| scenario | covers |
| --- | --- |
| `boot` | the main menu and the settings screen |
| `chargen` | creating a paladin with fixed dice, the portrait and icon pickers, the `.CHA` file written, adding him |
| `loadsave` | the Load/Save menu, loading A, View and More Info, the save popup, the files a save writes |
| `combat` | resting in Podal Plaza until orcs come, a Quick fight, the loot, Take, the statistics |
| `vault` | walking New Phlan to the vault, a deposit, leaving and returning |
| `journal` | the journal list and an entry |
| `camp` | Fix and Rest in Valhingen Graveyard |
| `shop` | walking to the arms shop, Pool, buying a hand axe, the pack, selling it back |
| `areachange` | New Phlan's script handing over to the training hall's (NEWECL), named in the save popup |
| `wilderness` | the central wilderness from save G (`saves/wild`, put into `SAVE\` by the scenario): the map and its second tile set, three steps, and the overlay loads, heap and picture memory (Ctrl-Y; ours only) |
| `wildfight` | save G again: a 32-step walk that meets a random encounter under NORAND, the fight's start, and the memory there |
| `ssiformat` | against SSI's own v1.3 (`tests/regress.sh drive_c/POOLRAD/SSI obj tests/scenarios/ssiformat.txt`): the `.CHA` file Remove writes and the files saving A into D writes are SSI's, with SSI's heap pointers, the unused name bytes and the saved script masked |
