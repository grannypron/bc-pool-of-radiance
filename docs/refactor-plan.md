# Refactor plan

The reconstruction is past byte-for-byte: features have been added on top of SSI's v1.3, so the build no longer matches
SSI's executable and "identical bytes" no longer proves anything about HEAD. This plan replaces that guarantee with
tests, then consolidates the duplication that minimal-footprint changes left behind, then improves the structure.

Written 2026-10-14 from three surveys of `src/` at commit a801a2f (duplication, architecture and constraints, test
tooling).

## Ground rules

These apply to all work in the repository, refactor or feature:

1. **Reuse before writing.** Before adding a helper, look for one. When the same logic exists in two or more places,
   counting the one about to be written, consolidate it in the same change, even when that touches other files. The PR
   says what was consolidated.
2. **Scope.** Consolidating inside the area a change already touches needs no separate approval. A sweep across ten or
   more files, or anything that changes behaviour, gets its own issue first.
3. **Residency decides where shared code lives.** Resident units (`CharHlp`, `TextRend`, `DaxIo`, `GDVars`, `Stats`,
   ...) hold what combat and other hot paths call; overlaid units hold UI-only code. Every PR reports the code and data
   sizes from `build/logs/TPC.OUT` and the overlay sizes.
4. **No hidden behaviour changes.** A refactor keeps behaviour. Fixing an SSI quirk (the `Note:` comments) is its own
   issue.

## Constraints

- Turbo Pascal 6: no `Break`/`Continue`, `const` parameters, open arrays or `Exit(value)`; `{$X-}`; lines at most 127
  characters (the source keeps to 120); 8.3 file names.
- 64 KB data segment: about 45 KB used, about 19 KB free.
- 16 KB stack with `{$S-}`: an overflow is silent. Large locals belong on the heap or in unit variables.
- Heap: about 256 KB free at the main menu.
- Overlays: a 100,352-byte buffer with probation (a third); `GAME.OVR` about 328 KB; working sets for combat (about
  130 KB) and exploring (about 114 KB) already exceed the buffer. STING Ctrl-Y shows the load count.
- Initialization order follows `fixmain.pas`'s `uses` list; `GameBoot`'s initialization starts the overlay manager.
- Save files keep SSI's layout (13,137-byte `SAVGAMx.DAT`); new data goes in sidecar files.

## Phase 0: a safety net

Replaces byte-for-byte as the proof that a change kept behaviour.

1. **Unit tests: `TestKit`.** A small test unit (`Check`, `CheckEquals` for LongInt and strings, counts, a log, an exit
   code) and test programs that use only the units under test plus `TestKit`. Built and run under the same TP 6 in
   DOSBox-X by `build.sh --test`, which fails on any failed check. First targets, all pure logic: `Stats`
   (saturation, kill kinds, net coin), `AreaName`, `Money` arithmetic, Strength encoding, `ClassCal`, the DataPat rule.
2. **Build size report.** `build.sh` prints code and data size from `TPC.OUT` and the overlay sizes, so a change that
   grows the resident program or the data segment is visible.
3. **Behaviour regression in goldbox-player.**
   - `session_start` takes boot arguments, so the game can start `STING NORAND` (fixed dice).
   - A runner replays scripted scenarios against two builds (a golden build from the pre-refactor commit and the
     candidate) and compares, at checkpoints: the screen text read from the game font (the main assertion), frame
     hashes (with an allow-list of expected differences), and save files after saving.
   - Scenarios: boot to the main menu; character creation; load and save; a combat under `NORAND`; a shop; the vault;
     the journal; camp, Fix and rest; an area change.
4. **CI.** Keep the job that rebuilds v1.1, v1.2 and v1.3 and checks SSI's hashes (it guards the toolchain); add the
   unit tests. The behaviour regression needs the game data and the emulator, so it runs locally or on a runner that
   has them.

## Phase 1: hygiene (mechanical)

- **Explicit `uses`.** About 145 unit pairs call each other by qualified name without listing the unit; it compiles
  only because the unit is loaded through someone else's `uses` (`EclVm` calls `EclMenu` 206 times without naming
  it). List every dependency and break the six implementation cycles (CbtMap–Pathing, CbtMap–Magic, GameIo–TextRend,
  CharGen–SaveLoad, Vault–ViewChar, Vault–SaveLoad). Watch initialization order.
- **Named constants**: name length 15, party maximum 8, map wrap 0..15 (20 lines in five blocks), `High(TSpellSlots)`
  for the literal 20, `virtualDisk in [1..8]`, an `IsNpc` test for the raw `$7F` comparisons (9 sites).
- **`GDVars.stingArg`**, set once at startup, for the 8 `ParamStr(1) = 'STING'` tests.
- **`ClearBottomLine` to `TextRend`.** It is in overlaid `MenuCore` and combat calls it.
- **Byte-match leftovers**: 18 `deadN` locals, about 40 `pad` locals, about 21 unused globals (first check that none
  is cleared or saved as part of a run of variables). **Pads and unused fields in records that are saved or loaded
  (characters, items, effects, the zones, saved games) stay**: they keep the file layouts, so characters and games
  still save and load, here and in SSI's executable.

## Phase 2: shared helpers (about 400-450 lines)

In order of value:

1. **Shop, temple and vault main loops** (nearly identical), and the "you left money here, go back?" prompt (3
   copies).
2. **File helpers in `DaxIo`**: `DeleteFile`, `OpenReadOnly`, `ReadRecord` and `WriteRecord` for the three sidecar
   formats (.mem, .inf, .sts); `SaveLoad.EraseCharFiles` for the 12 erase sites; one "put save disk" rewrite retry.
   Fixes a probable bug: the usual-spells `.mem` file is opened read-write, so a read-only copy is ignored.
3. **Number formatting in `CharHlp`**: `NumStr`, `ZeroPad2`, `PadLeft`/`PadRight`, for six identical `Str` wrappers
   and seven zero-pad copies.
4. **`TextRend.DisplayCentered`** for 13 centring sites and three "(more)" drawers; `CharHlp.ShowMessage` for 29
   repeated message-window calls.
5. **Money**: one copper-value helper for three copies; `Money.PayGold` for the three "pay from the character, else the
   pool" blocks.
6. **Lists and effects**: `FreeItemList`/`ClearTreasure` (3 copies), `HasDisease`/`RemoveDiseases` (Temple and the
   paladin), `IsPartyMember` for `SaveLoad.InParty` (which today also matches monsters: verify first).

## Phase 3: structure

- **Split `CharHlp`**: a resident core (stats, inventory, damage, string helpers) and an overlaid unit for screen
  layouts and the party display. Frees resident memory; measure overlay loads with Ctrl-Y.
- **One typed view per shared global.** The wall cache is overlaid three ways, the icon animations two, `displayMode`
  five times. One view in `Types`; merge the duplicate zone pointer types. Save layout unchanged.
- **The interpreter**: the opcode dispatcher in its own unit; `EclMenu` split into variable access, game memory and
  menus; `Magic` and `EffHndlr` grouped by family.
- **SSI quirks**: each `Note:` is fixed or labelled, one issue each.

## Phase 4: hidden parameters

`tempCr1/2`, `castScroll` and `usingItem` become parameters first; `curChar` and `dsTargetCreaturePtr` later, a family
of routines at a time. Watch the stack (16 KB, silent overflow) and the fixed `TEffectHandler` signature.

## Working method

One branch and one PR per phase, an issue per item, each change checked against the tests, the regression suite and
the size report. Phase 0 first.
