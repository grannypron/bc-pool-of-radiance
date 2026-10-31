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

The golden build is this game's own, of a recent commit: the scenarios follow today's menus, and `golden:` steps are
left for a golden build that needs other keys (SSI's, in `ssiformat`). After an interface change that moves a
scenario's keys or waits, fix the scenario, then record fresh goldens from the merge commit, one record a mode:

```
sha=$(git rev-parse --short HEAD); g=.golden/$sha
scripts/build.sh && mkdir -p $g && cp obj/START.EXE obj/GAME.OVR drive_c/POOLRAD/SBSFX.DAT $g/
tests/regress.sh $g $g          # EGA, then each mode the same way:
VIDEO=cga tests/regress.sh $g $g; VIDEO=tandy tests/regress.sh $g $g; VIDEO=vga tests/regress.sh $g $g
SOUND=adlib tests/regress.sh $g $g; SOUND=sb tests/regress.sh $g $g; MEMSIZE=16 tests/regress.sh $g $g
```

With no scenario named, `regress.sh` leaves out `ssiformat`, whose golden is SSI's v1.3; it runs on its own, as its
row below says.

A new scenario should first be run against the golden build twice (`tests/regress.sh GOLDEN GOLDEN scenario.txt`): it
must pass, or it depends on something other than the build (timing, a key arriving early). A frame that differs while
the text matches (an animated picture) is only a warning.

| scenario | covers |
| --- | --- |
| `boot` | the main menu and the settings screen |
| `chargen` | creating a paladin with fixed dice, the portrait picker (Escape doing nothing there) and the icon picker, the `.CHA` file written, adding him |
| `loadsave` | the Load/Save menu, loading A, View and More Info (its saves, statistics and a thief's skills), the save popup, the files a save writes (the `.MAP` with them) |
| `combat` | resting in Podal Plaza until orcs come, a Quick fight, the loot, Take, the statistics |
| `vault` | walking New Phlan to the vault, a deposit, leaving and returning |
| `journal` | the journal list with its first item previewed, and the second selected |
| `camp` | Fix and Rest in Valhingen Graveyard, Scribe's message for a character without magic-user levels, and Escape leaving Alter's portrait picker with the portrait unchanged |
| `companion` | the Companion Tools (phase 8) turned on in Settings: the map, the character editor (levels, Modify, gear with a plus and bracers' AC, money, spells, health) and a note written on the map |
| `shop` | walking to the arms shop, Pool, buying a hand axe, the pack, selling it back |
| `areachange` | New Phlan's script handing over to the training hall's (NEWECL), named in the save popup |
| `wilderness` | the central wilderness from save G (`saves/wild`, put into `SAVE\` by the scenario): the map and its second tile set, three steps, and the overlay loads, heap and picture memory (Ctrl-Y; ours only) |
| `wildfight` | save G again: a 32-step walk that meets a random encounter under NORAND, the fight's start, and the memory there |
| `stojanow` | Stojanow Gate once taken (#683), from save A moved there (`saves/stojanow`): the cheer before the gatehouse and behind it, once a visit, and the guard room become barracks |
| `bane` | the Temple of Bane freed with Dirten in the party (#682), from save A moved beside its altar with a member made Dirten (`saves/bane`): the fight won with Alt-X, the farewell, the day kept in the save, the rebuilding |
| `banetemple` | Dirten's temple 14 days on (#682, `saves/banetemple`): his welcome, the temple, the twelve-line Heal list (#1125), Cure Light Wounds at 90 gold pieces, Repair's quote (this build only), the view restored |
| `banestuck` | a party stuck with Dirten (#1139), from bane's fixture with the temple freed without him and him in the party after (`saves/banestuck`): his farewell at the altar, then the rebuilding |
| `banealtar` | the Temple of Bane's altar destroyed on an earlier visit (#1139, `saves/banealtar`): its remains, not the offer to destroy it again |
| `bishop` | the bishop's study once the temple is freed without Dirten (#1139), save A on its square, (10,5) (`saves/bishop`): the bishop's thanks, Dirten not joining, `[$4A9C]` and `[$4A79]` in the save |
| `madman` | the Temple of Tyr with the Mad Man in the party (#1138), save A on its square, (8,4) (`saves/madman`): the priest's question, No (the greeting and the offer of healing), then Yes (he leaves the party) |
| `ssiformat` | against SSI's own v1.3 (`tests/regress.sh drive_c/POOLRAD/SSI obj tests/scenarios/ssiformat.txt`): the `.CHA` file Remove writes and the files saving A into D writes are SSI's (`CHARLIST.TXT` is left out: a party member stays on the roster, #754), with SSI's heap pointers, the unused name bytes and the saved script masked |
