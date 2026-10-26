# Fleet: the other Gold Box games, and how five ports share one core

Analysis only, 2026-10-26. Nothing in any repository was changed. Scratch extracts and the similarity script are in
`/tmp/claude-1000/-home-brian-repos-pool-of-radiance/76f98367-99ca-4028-b60d-7be679625eb9/scratchpad/fleet/` and
`.../scratchpad/tools/sim.py`.

Target layout as Brian corrected it: **each game stays its own repository and builds by itself.** "Versions overlaid"
means that inside one game's repository, v10/v11/v12 stop being separate folders and become one source tree that
records only where the versions differ. It does **not** mean all games go into one repository. Part 2 compares ways
for separate per-game repositories to consume a shared core.

## 0. Read this first: origin is stale for six disassembly repos

The brief says to read every repo at `origin/main`. For most disassembly repos that ref is out of date. Local `main` is
ahead and clean (no uncommitted changes). These commits have not been pushed:

| repo | branch | local commits not on origin | effect |
|---|---|---|---|
| curse-disassembly | master | 78 | origin still has GameDat1..5; local has GDConsts/GDVars and finished S13 (2026-10-18) |
| secret-disassembly | main | 32 | same: origin stops at run 1 (2026-10-10) |
| gateway-disassembly | main | 29 | same |
| matrix-disassembly | main | 28 | same |
| treasures-disassembly | main | 27 | same |
| dqk-disassembly | main | 10 | |
| buck-disassembly | main | no remote at all | |
| frua-disassembly | struct-cleanup | no upstream | |
| champions, dkk, pools | main | 0 | in sync |

So the forge copy shows five games stuck partway through run 1. Locally, every Turbo Pascal disassembly has reached
S13 (2026-10-18). **Brian should push these.** buck-disassembly has no remote, so it exists only on succubus.
The figures below were taken from local HEAD, which is the true state. The five port repos were read at `origin/main`
as the brief asked.

Also: `~/repos/death-knights-of-krynn` is an empty folder (no git, no files), so DKK has no port yet. The spec's PoR
trees (`por-disassembly/v11..v13`) are not checked out under `~/repos`.

---

# Part 1: the other games

## 1.1 What each disassembly contains

"Byte-matched" means the gate rebuilds every shipped file byte for byte (`N of N shipped files match`). Lines are
`.pas` + `.asm` (+ `.c`) under `vNN/src`, local HEAD.

| repo | language / form | versions (compiler) | size | state |
|---|---|---|---|---|
| curse | TP Pascal + 3 TASM; GDConsts/GDVars | v10, v11 (TP 5.0), v12 (TP 5.5), v13 (TP 6.0-1990) | ~38.1k lines × 4, 50 units | byte-matched all 4; cleanup S13 done locally |
| secret | TP Pascal + 5 TASM | v10–v13 (all TP 5.5) | ~42.2k × 4, 53 units | byte-matched; S13 done locally |
| champions (champs) | TP Pascal + 5 TASM | v10, v11 (TP 5.5), v12 (TP 6.0-1991) | ~38.0k × 3, 51 units | byte-matched; S13 done |
| dkk | TP Pascal + 4 TASM | v10 (TP 5.5), v11 (TP 6.0-1991) | ~37.5k × 2, 52 units | byte-matched; S13 done (S10/S11 ran before S9, spec 4.2) |
| pools | TP Pascal + 6 TASM; three programs (FixMain, CONTROL, STARTUP) | v10, v11 (TP 6.0-1990) | ~40.6k × 2, 57 units | byte-matched (CONTROL/STARTUP provenance UNCHECKED); S13 done |
| gateway | TP Pascal + 6 TASM | v10, v12 (TP 6.0-1990) | ~42.0k × 2, 59 units | byte-matched (v10 has no witness, "UNCHECKED"); S13 done locally |
| treasures | TP Pascal + 5 TASM; three programs | v10 (TP 6.0-1990 for GAME, TP 5.5 for CONTROL/STARTUP) | 43.9k, 60 units | byte-matched; S13 done locally |
| buck | TP Pascal + 5 TASM | v10, v13 (TP 5.5) | ~34.7k × 2, 52 units | byte-matched; S13 done; **no remote** |
| matrix | TP Pascal + 6 TASM (+ Miles AIL asm) | v10 (TP 6.0-1990, TASM + TASM 3.1) | 37.5k, 52 units | byte-matched; S13 done locally |
| dqk | **C** (Turbo C 2.01, `-ml`) + TASM 3.1 + NASM; RTLink/Plus internal overlays; one `dqk.h` | v11 only | 86 `.c` (1.56 MB) + 102 `.asm` | **whole EXE byte-matched**: 1,384 routines proven C, 172 assembly, 206 linker (census 2026-10-09); about 396k of 450k bytes built from C. Remaining work is naming. Outside the TP cleanup spec (0.3) |
| frua | **C** (Turbo C 2.01) + asm + NASM listing; RTLink/Plus; shares the MicroMagic library with DQK | v12 only (CKIT.EXE; v1.0 not started) | 113 `.c` (2.6 MB) + 112 `.asm` | byte gate green on the whole image; "every overlay module is C" (handoff 2026-10-03); further along on a branch with no upstream. Outside the spec |

Every Pascal tree has the same shape (spec §E): `vNN/src/{fixmain,types,gdconsts,gdvars,…}.pas`,
`includes/c_*.pas`, `TPC.CFG`, `vNN/build/BUILD.BAT`, and the wheel's `gametools/{build,gate,preflight}.sh`. Every
one is cleaned to the spec's end state and is read-only except through the gate.

### How much the versions of each game differ

This decides how "versions overlaid" can work.

| game | files | identical in every version | differ | first→last version, +/- lines |
|---|---|---|---|---|
| buck v10/v13 | 94 | 90 | 4 | 34 |
| pools v10/v11 | 82 | 76 | 6 | 86 |
| secret v10–v13 | 75 | 59 | 16 | 329 |
| gateway v10/v12 | 88 | 68 | 20 | 434 |
| champs v10–v12 | 76 | 42 | 34 | 3,551 (TP 5.5 → 6.0 across the line) |
| curse v10–v13 | 69 | 16 | 52 (+1 file only v12 has: `stamp.pas`) | 6,704 (TP 5.0 → 5.5 → 6.0) |
| dkk v10/v11 | 73 | 24 | 49 | 13,176 (TP 5.5 → 6.0) |

Where the compiler stayed the same, the versions differ by a few files and a few hundred lines (buck, pools, secret,
gateway). Where SSI changed compiler, much of the text differs, because the reconstruction had to be rewritten to
make the new compiler emit the shipped bytes (champs, curse, dkk).

## 1.2 Engine generation: which port's engine each game is closest to

Lineage here is measured, not assumed (spec 3.4). The measure is the atlas
(`~/repos/goldbox-atlas/decisions.json`, 2,490 routine families): the number of routine families two games share.

|  | por | curse* | champs | secret | buck | dkk | gateway | pools | matrix | treasures |
|---|---|---|---|---|---|---|---|---|---|---|
| **por** | 805 | 132 | 646 | 608 | 96 | 582 | 660 | 586 | 96 | 587 |
| **champs** | 646 | 292 | 915 | **752** | 120 | **744** | 685 | 650 | 120 | 644 |
| **secret** | 608 | 299 | 752 | 891 | 132 | 698 | 661 | 658 | 132 | 648 |
| **pools** | 586 | 184 | 650 | 658 | 177 | 726 | 722 | 957 | 171 | **914** |
| **gateway** | 660 | 228 | 685 | 661 | 125 | 633 | 1049 | 722 | 121 | **758** |
| **dkk** | 582 | 229 | **744** | 698 | 163 | 933 | 633 | **726** | 154 | 717 |
| **buck** | 96 | 67 | 120 | 132 | 766 | 163 | 125 | 177 | **717** | 171 |

\* Curse is under-registered in the atlas: v11–v13 have only about 142 member routines each, against about 490 for
v10. Its column understates it.

Families shared by every game in a group:
- the four ports apart from Curse (por, champs, secret, pools): **502**
- those four plus dkk: 479
- plus gateway and treasures: 466
- plus buck and matrix: **84**
- in all ten Pascal games: 38

The 502 families the four ports share fall mostly in these units (counted in pools v11): Magic 66, EclVM 38,
EffHndlr 34, CharHlp 31, CbtActs 30, Camp 21, EclMenu 20, CbtMap 20, ViewChar 19, TextRend 18, Blit 16, CombatSt 16,
MenuCore 16, ChrGen 14, GameTime 14, Money 14, DaxIO 12, View3D 11, CombatAI 11, SaveLoad 10, PostCbt 10. The rest
are in single figures.

Class numbers are the same in every D&D game: CLERIC=0, FIGHTER=2, PALADIN=3, RANGER=4, MAGE=5, THIEF=6, and the
multiclass ids 8–16. KNIGHT=7 exists only in Krynn. Race numbers are **not** the same:

| race numbering | games |
|---|---|
| MONSTER=0, DWARF=1, ELF=2, … | por, curse, gateway |
| ELF=0, … | pools, treasures |
| TRIBBLE=0, ELF=1, … | secret |
| Krynn's own list (SILVANESTI_ELF=0 … KENDER=5, HUMAN=6, MONSTER=7) | champs, dkk |

Both numbers are stored in save files and game data. A shared table can index classes directly but needs a per-game
race map.

| game | closest port engine | why |
|---|---|---|
| Treasures of the Savage Frontier | **Pools** (914 of Treasures' 1,094 families are Pools families) | same TP 6.0-1990 FBOV/VROOMM toolchain, same three programs, Vault, Music/MusDrv, VgaFrame. Adds Romance, GeoEdit, DevMenu, Restart. |
| Gateway to the Savage Frontier | **Pools** (722); closest overall to Treasures (758) | Pools-generation engine with Curse-era leftovers: GameDat1..6 history, race order MONSTER=0 like PoR/Curse, Config/InputCfg, KbdCore/Raster asm |
| Death Knights of Krynn | between **CoK** (744) and **Pools** (726) | v10 is CoK's TP 5.5 engine; v11 moves to TP 6.0-1991 with Vault, Music, MusDrv, Mouse (Pools-era units). Krynn classes and races (Knight, Kender, moons). |
| Buck Rogers: Countdown to Doomsday / Matrix Cubed | the **sci-fi variant**; only each other (717). Next nearest is Pools/DKK at about 170 | careers and skills instead of classes (`c_career`, `c_skill`, `skills.pas`), ship combat (`shipcbt`), `orbitmap`, no Magic/Camp/Temple/ClassCal. Shares mainly EclVM (39 families), Blit (23), CbtActs (22), MenuCore (14), Border (9), TextRend (8) |
| Dark Queen of Krynn | **none**: DQK's later engine | C rewrite on the MicroMagic library under RTLink/Plus. Unrelated code, related rules |
| FRUA | **none**: DQK's engine, generalised | same MicroMagic library and Turbo C as DQK; an editor plus engine |

## 1.3 Can the proposed shared units serve each game?

The other areas will name the actual units. The categories below are those the brief lists. Key:

- **as-is**: the unit can be used unchanged
- **params**: per-game caps, tables or race maps passed in
- **hooks**: per-game branches through a hook unit or a procedure variable
- **no**: the unit cannot serve that game

None of this applies to the **byte-matched trees** (see 2.4). The table answers: if this game got a port, could it
build on the core?

| shared unit group | treasures | gateway | dkk | buck / matrix | dqk / frua |
|---|---|---|---|---|---|
| Rules tables (levels to Pools' caps; XP, THAC0, saves, spell slots, thief skills, turning) | params: FR rules like Pools, its own caps | params: as Treasures; Curse-like race order needs the race map | params + hooks: Knight, moon-phase magic, Krynn races; take CoK's tables | **no**: careers and skills, no D&D tables | **no** as code. The tables could serve as reference data to check DQK/FRUA's values (DQK `v11/analysis/data-tables`) |
| `C_*` constant families | per game (spec 9.2: never borrow another game's numbering) | per game | per game | per game | n/a |
| Leaf infrastructure (Dice/TPRand, StrUtil, HeapErr, LogWrap, TuiKit/LineEdit) | as-is | as-is | as-is | as-is | no (C) |
| Sound drivers (SndSB/SndOPL/SndSpk/SndTdy/SndNone, the SoundDrv sequencer) | params (Music/MusDrv era: DIGPAK driver handoff) | params | params | params (Matrix uses Miles AIL/XMIDI: hooks) | no |
| Video drivers (VidVGA/EGA/CGA/Tdy, Blit, Sym8x8, TextRend) | params: VGA-only engine, VgaFrame | params | params | params: VgaFrame, OrbitMap | no |
| DaxIO / DataArc / DataBld (resource reading) | as-is to params (same DAX format) | as-is to params | as-is to params | params | no (FRUA/DQK formats differ; not measured) |
| EclVM (script VM) and EclMenu | hooks: opcode table per game | hooks | hooks | hooks: the most-shared engine unit with sci-fi (39 families) | no |
| Magic / EffHndlr (spells, effects) | hooks: Pools-like spell list | hooks | hooks: moon magic, Krynn spells | **no** | no |
| Combat (CbtActs, CbtMap, CombatAI, CombatSt, PostCbt) | hooks | hooks | hooks | partly: CbtActs/CbtMap shared, plus ship combat | no |
| Char gen / sheets / camp / shop / temple / vault | params + hooks | params + hooks | params + hooks | no for camp/temple; Shop and ViewChar heavily changed | no |
| PoR-only features (bestiary, journal quests, vault menu, dual-class, native FPC/SDL3 layer) | shareable later with hooks | same | same | journal/bestiary maybe; dual-class no | the native layer's idea only |

Summary: Treasures and Gateway would ride on the Pools port's core almost directly, DKK on CoK's. Buck and Matrix can
share only the infrastructure and EclVM layer, so they would need their own rules layer. DQK and FRUA cannot share Pascal
code at all; at most they share rules data, and only if the core's tables are also published as data.

---

# Part 2: how the five Pascal ports could share a core

## 2.1 How each port builds today

All five use the same pipeline, which started from one template and has since drifted. `build.sh` mounts the
repository in DOSBox-X as drive E and the toolchains as D (TPC), F (TASM) and G (EXEPACK). It runs `build/build.bat`
from `E:\SRC`. That batch file assembles the `.asm` files into `E:\OBJ`, runs `tpc fixmain.pas /B /E..\obj /O..\obj`,
renames `FIXMAIN.OVR` to `GAME.OVR`, and EXEPACKs `FIXMAIN.EXE` into `START.EXE` (`GAME.EXE` for Pools). `--test`
compiles and runs `tests/*.pas` (TestKit) in DOSBox. `build/ovlsizes.py` reports overlay sizes. `.forgejo/workflows/build.yml`
runs each job in a private CI image (`vars.CI_IMAGE`, toolchains at `/drive_d`). Checkout is a hand-written `git fetch`,
not `actions/checkout`.

| | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| compiler (`build/toolchain`) | TP6-1991 | TP6-1990 | **TP55** | TP6-1990 | TP6-1991 |
| `src/*.pas` / lines (pas+asm+inc) | 162 / 63.7k (+3.5k `src/native`) | 111 / 63.0k | 98 / 56.3k | 91 / 53.1k | 87 / 46.2k |
| asm units | sounddrv only | blit, sounddrv, textrend | blit, coreinp, joystick, sounddrv, textrend | blit, sounddrv, joystick, keyboard, textrend, vgaframe | blit, joystick, sndload, sounddrv, textrend |
| programs | FixMain + POOLCFG | FixMain | FixMain | FixMain + CONTROL + STARTUP (+`build/fillmem.pas`) | FixMain |
| DGROUP used, of 65,520 (last local `TPC.OUT`; may be stale) | 41,762 | 43,234 | 43,660 | **48,602** (tightest) | 36,012 |
| TPC.CFG | `/U.;INCLUDES /I.;INCLUDES;..\OBJ /L /$F+ /$A- /$E+ /$N- /GD /$D+ /$L- /$R- /$S- /$V+` | same, without `/I` | same | same | same (plus `tests/TPC.CFG`) |
| `build.sh` lines differing from PoR's | — | 101 | 94 | 125 | 98 |
| CI jobs | build+test, reproduce v1.1–1.3, release, **macos native**, release-macos | build+test, reproduce v1.0–1.3, release | same, v1.0–1.3 | same, v1.0–1.1 | same, v1.0–1.2 |
| conditionals | 117 `{$IFDEF FPC}`, plus UNIX/WINDOWS/DARWIN (native build) | none | none | none | none |

Facts that constrain any sharing scheme:

1. **Only the tags are byte-matched, not main.** Each port's history begins with the SSI versions as tagged commits
   ("Pools of Darkness v1.1 source"). For Pools and CoK, those tags are blob-for-blob copies of the disassembly's
   `vNN/src` (83 of 83 files and 77 of 77). Curse and Secret were seeded from earlier disassembly states. The
   `reproduce` job checks out each tag into a worktree, **copies today's `build.sh` into it**, builds, and requires
   SSI's SHA-256s. Main has diverged freely: it uses `.inc` files and `{$IFDEF FPC}`, and spec 1.8 does not govern the
   ports.
   Consequence: any build change must still build an old tag that has no core folder. Fixing a bug in shared code
   cannot break a byte match, because no tag ever contains the core.
2. TP finds a unit by file name, `<unit>.PAS`, searching **the current directory first (`E:\SRC`), then the `/U`
   directories in order**. Objects for `{$L}` are looked up in the source directory before `/O`.
   - A file in `src/` with the same name as a core unit therefore silently replaces the core's copy. That can be
     used as a deliberate per-game override, or it can be a trap.
   - Unit names are at most 8 characters, and DOS file names are 8.3.
   - Do not leave stale `.TPU` files in the core folder. `/B` together with `/E..\obj` keeps unit files in `obj`.
3. TPU files from TP 5.5 and TP 6.0 cannot be mixed, but `/B` rebuilds everything from source, so that is harmless. The
   real constraint is the language: core source must compile under **TP 5.5 (Secret), TP 6.0-1990, TP 6.0-1991, and
   FPC `-Mtp` (PoR's native build)**. That means no `asm` blocks and no TP 6.0-only syntax, unless Secret's main moves
   to TP 6.0 first. Its tags keep their own `build/toolchain`, so the move would not touch them.
4. **Overlays are chosen per program.** `{$O UnitName}` in each game's `fixmain.pas` decides what goes into the overlay;
   the unit itself only needs `{$O+,F+}`. A core unit can be overlaid in one game and resident in another, so the
   overlay lists stay per game.
5. **64 KB DGROUP.** Typed constants and variables in a core unit land in every game that references them. Per the
   spec's facts, the smart linker drops a section nothing references. So give each core table its own `const`
   section; a game then pays only for the tables it uses. Tables sized to Pools' level caps cost every port that uses
   them, and Pools itself has the least room (about 17 KB free). Measure DGROUP per table with the existing
   `build.sh` size line before and after each move.
6. PoR's native build compiles the same units with FPC: `build-native.sh` passes `-Fu$root/src -Fu$root/src/includes
   -Fu$root/src/native -Fi…` and each unit includes `COMPILER.INC`. The core needs the same paths added there, and
   core units must include its `COMPILER.INC` (TP ignores the `{$IFDEF FPC}` body inside it).

## 2.2 Ways to consume one core from five separate repositories

Assume a new repository (call it `goldbox-core`) containing `core/*.pas`, `core/includes/`, its own `COMPILER.INC`,
and core tests (TestKit). Each game gets it as a folder named `CORE` at the repository root. That keeps the DOS path
`E:\CORE` short: Pools' BUILD.BAT warns that long paths use up memory the whole-image link needs. TPC.CFG becomes
`/U.;INCLUDES;..\CORE;..\CORE\INCLUDES` (plus `/I` the same), and `build-native.sh` gains matching `-Fu`/`-Fi`
entries. That edit is the same for every option below; what differs is how `CORE` gets its contents.

| | A. git submodule | B. git subtree | C. vendored copy, synced by script, pin checked | D. fetched at build time |
|---|---|---|---|---|
| How `CORE` appears | gitlink to a pinned commit; `git submodule update --init` | real files, with core history merged into each game repo | real files written by `tools/core-sync.sh <ref>`; `core.ref` records the core commit and the **git tree id** of `CORE` | `build.sh` clones or downloads the pinned ref into a cache, mounted as drive H: |
| TP build (`/U`, 8.3, overlays, DGROUP) | identical in all four: the same `/U` edit; overlays and DGROUP per game, as in 2.1 | same | same | needs an absolute `/U H:\` path and another DOSBox mount |
| Reproduce of old tags | OK: tags have no gitlink. Future tags need `git submodule update` inside the reproduce worktree | OK | OK: plain files in the tag | needs the network to rebuild a tag that names a core ref |
| CI checkout | must add a submodule fetch with auth. The hand-written fetch uses a per-repo token, so the core repo must be public or reachable with that token. A relative URL (`../goldbox-core.git`) works on both forges | nothing changes | nothing changes; add a check that `git rev-parse HEAD:CORE` equals `core.ref`'s tree id (offline, one line) | network at build time; the CI image or a cache must reach the forge |
| Local work (Brian's habits) | worktrees (`ck-wt-*`, `por-wt-*`) each need `submodule update`; detached-HEAD surprises; `git archive` and the atlas don't see the content | edits in a game repo can drift silently; `subtree push` is slow and easy to get wrong | grep, worktrees, archive, the atlas and the gate tools all see plain files. A local edit to `CORE` fails CI (tree id mismatch) until it goes upstream and is re-synced | builds fail offline; the cache needs managing |
| Changing the core | PR in core, then a one-line pointer bump in each game | PR in any game, then `subtree push`; or PR in core, then `subtree pull` ×5 | PR in core, then `core-sync` ×5 (or an agent edits `CORE` in a game, tests it, and upstreams the same diff) | PR in core, then a ref bump ×5 |
| Precedent in the fleet | none | none | **yes**: the wheel's T10 `install_build` template and the identical `gametools/*.sh` are already vendored copies kept in step by the tool | the wheel itself (`requirements.txt`, venv) for Python tools, not for DOS builds |
| Fit with overlaid versions in each game repo | OK, but a second layer of indirection | OK | best: the same "list of folders, first one wins" resolution serves both (2.4) | poor |

**Recommendation: C, a vendored copy synced by a script, with the pin checked in CI.** It is the only option that
changes nothing in the checkout, worktree, archive, reproduce or atlas paths. It follows the fleet's existing
`install_build` pattern. It stays fully offline: the tree-id check needs no network. It also makes drift loud.

A (submodule) is the fallback if Brian wants the pin to be a gitlink rather than a recorded hash. Its cost is in CI
checkout and in the many worktrees. B and D are not recommended. Subtree allows silent drift, and a build-time fetch
breaks offline builds and the reproducibility of tags.

Two companion changes help a lot whichever option is chosen:
- **One `build.sh` for the five ports.** They now differ from PoR's by 94–125 lines each. Unify them first, so the
  `CORE` path, the shadowing check and the DGROUP report land once. The same `install_build` approach works.
- **A shadowing check in `build.sh`.** List every `src/*.pas` whose name matches a `CORE/*.pas`, and fail unless it
  is named in `src/OVERRIDE.LST`. That turns TP's "current directory wins" rule from a trap into the documented way a
  game overrides a core unit.

## 2.3 Migration order, with all five ports building at every step

Each step lands as one core commit plus one sync PR per port (Brian's one-branch-per-batch rule applies within each
repo). Each port's PR must pass `./build.sh --test` and the reproduce matrix, plus PoR's macOS native job. Report the
DGROUP before/after line in every PR.

1. **Plumbing, no code.** Unify `build.sh`. Add `CORE/` (empty apart from `COMPILER.INC` and a README), the TPC.CFG
   `/U`/`/I` entries, the FPC `-Fu`/`-Fi` entries, the `core.ref` tree-id check and the shadowing check. All five
   build; the reproduce jobs prove old tags are untouched.
   Decide now whether **Secret's main moves to TP 6.0**. If it does not, the core must stay TP 5.5-clean, and the
   core repo's CI must compile its tests under TP55, TP6-1990, TP6-1991 and FPC.
2. **One trivially identical leaf, to prove the loop.** LogWrap (PoR and Pools copies are already 1.00 identical
   after normalisation) or HeapErr (0.72–0.78 across all five). Move it to the core, delete the five copies, and the
   five sync PRs go green.
3. **Constants and rules tables: Brian's main wish.** Add a core `Rules` unit (name to be chosen, 8 characters at
   most) with typed tables running to Pools' maximums, and the ability tables to 25 (memory: ability-tables-to-25).
   Index by class directly, since class ids are common to all D&D games. Index by race through a per-game map, since
   race order differs.
   Per-game caps (level limits, gear limits, allowed race/class combinations) come from a **per-game hook unit with a
   fixed name**, say `GameRule` in each port's `src/`, which the core unit `uses`. That is compile-time dependency
   inversion with no runtime cost and no procedure-variable bytes in DGROUP. It works as long as `GameRule` uses only
   `Types` and the include units, never core engine units, which would be Error 68, a circular `uses`.
   Keep each game's `C_*` families per game (spec 9.2's warning holds for the ports too, because numbers are on disk).
   Only constants that are genuinely identical (class ids) go in a core `C_` family, under a new name that collides
   with no game's.
   Each table goes in its own const section, so a port that doesn't use it pays nothing.
4. **Remaining leaf units**, highest normalised similarity first, so each move is mostly deleting code:
   - BldShow (0.85–0.91)
   - DataArc / DataBld (0.76–0.82; Pools' DataBld 0.24 needs a look)
   - sound drivers SndSB/SndOPL/SndSpk/SndTdy/SndNone (0.5–0.8)
   - video drivers VidVGA/EGA/CGA/Tdy (Curse 0.67–0.77, CoK 0.26–0.41)
   - StrUtil, Dice/TPRand, TuiKit, LineEdit, SavEMenu-style UI widgets
   - then the PoR-only features other ports are receiving now: journal views, bestiary, vault menu, Options/CfgFile
   Each is overlaid or resident per game through that game's `fixmain`.
5. **Engine, last and by family.** Use the 502 routine families the four non-Curse ports share; once Curse is
   registered in the atlas, its share of them will show:
   - EclVM/EclMenu first (the most shared; an opcode-table hook)
   - then Money, GameTime, PostCbt, Temple, Shop (small, with params)
   - then Magic/EffHndlr and the combat units (CbtActs/CbtMap/CombatAI/CombatSt), which carry most of the per-game
     branches; these need `GameRule`-style hooks or procedure variables
   - SaveLoad stays per game: the save formats differ
   - Blit/TextRend asm stay per game until the asm sets converge (PoR has replaced its asm except `sounddrv.asm`; the
     others have three to six asm files)

   Don't start this stage while the Curse agent is still porting PoR's work into Curse: wait for that branch to land,
   then use Curse as the second consumer of each engine unit.

Risks to track:
- **Save and data layout.** Records shared between games must keep each game's byte layout (`/$A-`, and FPC's
  `PACKRECORDS 1`). Shared record types go in the core only when they are byte-identical across games.
- **DGROUP.** Pools has about 17 KB free; check every table move.
- **TP 5.5.** Covered in step 1.
- **Overlay working set.** Moving a routine into a different unit changes which overlay holds it. Watch
  `build/ovlsizes.py` and the overlay buffer size per game.
- **Silent shadowing.** Covered by the shadowing check.
- **Two forges** (memory: forge-hosts). The core repository must exist on the public forgejo.brazencrows.com, because
  that is where every port's CI checks out from.

## 2.4 How the core fits per-game repositories with overlaid versions, and the byte-matched trees

- **The core never enters a byte-matched build.** The disassembly trees and each port's SSI tags are built only from
  their own sources. Shared code bytes cannot reproduce eleven games' differing SSI bytes. The fleet already shares
  everything that *can* be shared there: routine names (spec 1.7), doc text word for word (12.4), and the tooling (the
  wheel, `build.sh`/`gate.sh` templates). Keep it that way. Neither BUILD.BAT nor TPC.CFG in a disassembly tree should
  ever name `CORE`.
- **Overlaying versions inside one game repo can use the same mechanism as the core.** Lay each tree out as layers
  searched in order: `src/base` (the files every version shares), then `src/v12` (only that version's differing
  files). The build runs TPC from a neutral directory (e.g. `E:\OBJ`, not a source folder) with
  `/U..\SRC\V12;..\SRC\BASE`, so the first file found wins.
  - The build must not run from inside a source folder, since TP searches the current directory first.
  - Unit link order comes from the `uses` clauses, not from where a file sits, so moving files between layer folders
    should be byte-neutral. The gate proves it per tree (spec 1.1).
  - The measurements in 1.1 say this works well for buck (90 of 94 files shared), pools (76/82), secret (59/75) and
    gateway (68/88). It is weak for champs (42/76), dkk (24/73) and curse (16/69), where a compiler change rewrote
    most files: those would keep a near-full layer per compiler generation.
  - In a port repo the same rule gives `src` → `CORE`, so one resolver in the shared `build.sh` (an ordered list of
    folders per build target, read from `goldbox.toml`) serves both.
- **The finer-grained alternative is `{$IFDEF V12}` in one file per unit.** TP 5.0 and later support `$IFDEF`, with
  symbols set by `/D` in TPC.CFG, and predefine `VER50`/`VER55`/`VER60`, so compiler-driven differences could key off
  those. Conditional directives emit no code, so it should be byte-neutral. **But the cleanup spec forbids it in
  byte-matched trees: 1.8 says "no `.inc` files, no `{$IFDEF}`".** Per-version layer folders comply with 1.8 as
  written; `$IFDEF` overlays would need Brian to change the rule. By the spec's freeze, that can happen only between
  runs. The plan's S13 close-out says the spec gets rewritten once S13 is done for every game, which is now locally
  true. The ports are not bound by 1.8 and already use `{$IFDEF FPC}`.
- **CI for a layered disassembly tree:** the gate builds each version from its own layer list. A change to `src/base`
  re-gates every version (spec 1.7 already demands that all versions move together), so the fleet gate's per-tree
  verdicts carry over unchanged.

## Headline numbers

- Eleven disassembly repos:
  - 9 Turbo Pascal (21 version trees), all byte-matched and through cleanup S13 locally
  - 2 C (DQK v11, FRUA v12): byte-matched whole images on Turbo C 2.01 / RTLink, outside the spec
- Engine families by shared routines:
  - Pools ↔ Treasures 914; Gateway ↔ Treasures 758; CoK ↔ Secret 752; CoK ↔ DKK 744; Buck ↔ Matrix 717
  - sci-fi ↔ D&D games at most 177
  - 502 families shared by PoR/CoK/Secret/Pools; 84 by all nine non-Curse Pascal games
- Six disassembly repos have unpushed work (27–78 commits); buck has no remote.
- Ports' DGROUP: 36.0–48.6 KB of 65.5 KB. Pools is tightest. Secret alone is on TP 5.5.
- Recommendation: a separate `goldbox-core` repository, vendored into each port as `CORE/` by a sync script, with a
  git tree-id pin checked offline in CI, plus one unified `build.sh` with a shadowing check. Migrate in this order:
  plumbing → one identical leaf → rules tables (with a per-game `GameRule` hook unit) → remaining leaves → engine by
  atlas family. Never put the core into a byte-matched build. Use ordered layer folders, not `$IFDEF`, for overlaid
  versions unless spec 1.8 is changed.
