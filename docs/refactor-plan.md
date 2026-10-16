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

- Turbo Pascal 6: no `Break`/`Continue`, `const` parameters, open arrays, `High`/`Low` or `Exit(value)`; `{$X-}`; lines at most 127
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
   **Done**: `Stats`, `AreaName`, `ClassCal` and DataPat's table (the rules DataBld relies on) as they are; the
   Strength and Dexterity tables moved from CharHlp to a resident `AbilAdj`, and Money's arithmetic (coin values,
   change, who pays, item values, money type names) to an overlaid `MoneyCal`, which also replaces `Stats.CoinWorth`.
2. **Build size report.** `build.sh` prints code and data size from `TPC.OUT` and the overlay sizes, so a change that
   grows the resident program or the data segment is visible. **Done.**
3. **Behaviour regression in goldbox-player.**
   - `session_start` takes boot arguments, so the game can start `STING NORAND` (fixed dice).
   - A runner replays scripted scenarios against two builds (a golden build from the pre-refactor commit and the
     candidate) and compares, at checkpoints: the screen text read from the game font (the main assertion), frame
     hashes (with an allow-list of expected differences), and save files after saving.
   - Scenarios: boot to the main menu; character creation; load and save; a combat under `NORAND`; a shop; the vault;
     the journal; camp, Fix and rest; an area change. **Done** (`tests/scenarios`, `tests/regress.sh`; goldbox-player
     `tools/regress.py`).
4. **CI.** Keep the job that rebuilds v1.1, v1.2 and v1.3 and checks SSI's hashes (it guards the toolchain); add the
   unit tests. The behaviour regression needs the game data and the emulator, so it runs locally or on a runner that
   has them.

## Phase 1: hygiene (mechanical)

- **Explicit `uses`.** About 145 unit pairs call each other by qualified name without listing the unit; it compiles
  only because the unit is loaded through someone else's `uses` (`EclVm` calls `EclMenu` 206 times without naming
  it). List every dependency and break the six implementation cycles (CbtMap–Pathing, CbtMap–Magic, GameIo–TextRend,
  CharGen–SaveLoad, Vault–ViewChar, Vault–SaveLoad). Watch initialization order. **Done** (#617); the cycles, legal
  between implementations, remain. Phase 2 also left each interface naming only the units its declarations use.
- **Named constants**: name length 15, party maximum 8, map wrap 0..15 (20 lines in five blocks), `SPELL_SLOT_LAST`
  for the literal 20, `virtualDisk in [1..8]`, an `IsNpc` test for the raw `$7F` comparisons (9 sites). **Done**
  (#617; `View3D.WrapCoords` for the wrap).
- **`GDVars.stingArg`**, set once at startup, for the 8 `ParamStr(1) = 'STING'` tests. **Done** (#617).
- **`ClearBottomLine` to `TextRend`.** It is in overlaid `MenuCore` and combat calls it. **Done** (#617).
- **Byte-match leftovers**: 18 `deadN` locals, about 40 `pad` locals, about 21 unused globals (first check that none
  is cleared or saved as part of a run of variables). **Pads and unused fields in records that are saved or loaded
  (characters, items, effects, the zones, saved games) stay**: they keep the file layouts, so characters and games
  still save and load, here and in SSI's executable. **Locals done**: 69 in #617, the other 40 unused locals in phase
  2. The unused globals went in phase 3 (15 in GDVars).

## Phase 2: shared helpers (about 400-450 lines)

In order of value:

1. **Shop, temple and vault main loops** (nearly identical), and the "you left money here, go back?" prompt (3
   copies). **Done**: `Shop.CounterMenu` for the shop and the temple, `Money.GoBackForIt` for the three prompts. The
   vault's loop differs (no Appraise, no prompt) and keeps its own.
2. **File helpers in `DaxIo`**: `DeleteFile`, `OpenReadOnly`, `ReadRecord` and `WriteRecord` for the three sidecar
   formats (.mem, .inf, .sts); `SaveLoad.EraseCharFiles` for the 12 erase sites; one "put save disk" rewrite retry.
   Fixes a probable bug: the usual-spells `.mem` file is opened read-write, so a read-only copy is ignored. **Done**,
   in a new resident `FileUtil` (DaxIo would have pulled GameIo into Stats' tests), with `SaveLoad.CharFileBase`,
   `RewriteSaveFile` and `SaveDiskMsg`.
3. **Number formatting in `CharHlp`**: `NumStr`, `ZeroPad2`, `PadLeft`/`PadRight`, for six identical `Str` wrappers
   and seven zero-pad copies. **Done**, in a new resident `StrUtil` that the early units (GameIo, TextRend) can use.
4. **`TextRend.DisplayCentered`** for 13 centring sites and three "(more)" drawers; `CharHlp.ShowMessage` for 29
   repeated message-window calls. **Done**: ten centring sites; `TextRend.ShowMessage` for the 14 calls naming the
   message window's corners, `ViewChar.SayBelow` for its six yellow lines.
5. **Money**: one copper-value helper for three copies; `Money.PayGold` for the three "pay from the character, else the
   pool" blocks. **Done**: `Money.CreatureGold`/`CoinsOf`, `WhoPays`/`PayBy`/`PayGold`.
6. **Lists and effects**: `FreeItemList`/`ClearTreasure` (3 copies), `HasDisease`/`RemoveDiseases` (Temple and the
   paladin), `IsPartyMember` for `SaveLoad.InParty` (which today also matches monsters: verify first). **Done**:
   `CharHlp.FreeItemList`/`ClearTreasure` (4 copies), `FxEngine.HasDisease`/`RemoveDiseases`, and a resident `Party`
   unit for `IsPartyMember` (InParty did match monsters in combat).

Found on the way: `equipped[]` was saved as raw heap pointers and kept on load until a `RecalcStats`; it is now saved
cleared and rebuilt on load (`CharHlp.LinkEquipped`). The regression suite's golden build for saves is
`.golden/8128649-eq` (8128649 with that save-side line).

## Phase 3: structure

- **Split `CharHlp`**: a resident core (stats, inventory, damage, string helpers) and an overlaid unit for screen
  layouts and the party display. Frees resident memory; measure overlay loads with Ctrl-Y.
  **Done**: `CharDisp` (overlaid) holds the 20 drawing routines; resident code went from 73,616 to 67,648 bytes. Ctrl-Y
  counted 28 overlay loads at the first area screen against 27 before; combat was not measured.
- **One typed view per shared global.** The wall cache is overlaid three ways, the icon animations two, `displayMode`
  five times. One view in `Types`; merge the duplicate zone pointer types. Save layout unchanged.
  **Done**: `videoMode`, `treasureMoney`, `dsIconAnimation`, the wall-set cache, `animData` (one `TAnimRec`),
  `effectFns`, the zones (Session and nine zone types gone; C_Gbvm names for the raw offsets) and four flags are
  declared with their types in `GDVars`. Then the last three: `spellFps` became `castTargetMenu` (a `TCastUI`) and
  `spellFns` (`TSpellProc`s), `wallGfx` a `PWallSlices` (one view, by wall type), and Money reads
  `randomItemTemplates` by template and field (which found POR-0165: a javelin made from the wrong template); Magic's
  flat view of `soundIds` went too, for named indexes in `C_Sound`.
- **The interpreter**: the opcode dispatcher in its own unit; `EclMenu` split into variable access, game memory and
  menus; `Magic` and `EffHndlr` grouped by family.
  **Done in part**: `EclVars` holds the variables and game memory; `EclMenu` keeps the menus and opcode helpers.
  Declined: the dispatcher stays in `EclVm` (a unit of its own would put all 55 handlers in EclVm's interface), and
  `Magic`/`EffHndlr` keep their spell- and effect-id order, which matches their dispatch tables.
- **SSI quirks**: each `Note:` is fixed or labelled, one issue each. **Done**: no `Note:` is left. Fixed: Share paying
  more than the pool held with a hired NPC along, CalcDistance's target count, Restoration missing from the spell
  book, a plain '2' or '-' acting as Alt-M or Alt-X in combat, CGA colours on repeated glyphs, dead code and labels.
  Labelled "SSI quirk, kept" where scripts or screens were made with them (Surprise, flight directions and others).

## Phase 4: hidden parameters

`tempCr1/2`, `castScroll` and `usingItem` become parameters first; `curChar` and `dsTargetCreaturePtr` later, a family
of routines at a time. Watch the stack (16 KB, silent overflow) and the fixed `TEffectHandler` signature.

**Done, as far as it pays.** Became parameters or private state: `tempCr1` (ViewChar.DisplayChar's character),
`tempCr2` (ViewChar's private `tradeTarget`), `castScroll` (SpellSelection's and `CastSpellMenu`'s var result),
`RemoveDiseaseEffects`' target, the money routines' payer or payee (`WhoPays`, `PayBy`, `PayGold`, `GivePlatinum`) and
the spell-list builders' character (`GenerateSpellList` and the six routines under it).

Kept global, on purpose: the state of the action in progress that the spell and effect handlers read. `curChar` (the
acting creature), `dsTargetCreaturePtr` (the spell's targets), `dsCurrentSpellBeing` and `usingItem` are read inside
handlers whose signatures the spellFns and effectFns tables fix, and by helpers the handlers call (GetCasterLevel,
ResolveSpell, CastOneSide, HasteSlowLogic, the statistics' attribution in InflictDamage and RestoreHitPoints). As
parameters they would have every handler pass `GDVars.curChar` along, or change 68 spell and 141 effect handler
signatures, for no less coupling.

## Phase 5: working sets, cycles, duplication, testability

Written 2026-10-16 from three surveys of `src/` at 62ec8f6: what duplication is left, structure and coupling, and
memory (code by unit from FIXMAIN.MAP, the data segment, overlay working sets, and stack frames read from the
routines' prologues). The steps are in order. Every step keeps behaviour unless it says otherwise, and anything that
changes behaviour is its own issue and commit.

0. **Measure first.** Add a Ctrl-Y checkpoint to the `combat`, `vault` and `areachange` scenarios, so each run records
   STING's overlay load count as text. The working-set steps below then show their effect in the regression report,
   not only by estimate.
1. **Overlay working sets.** A combat round touches about 130 KB of overlays and an explore step about 114 KB; the
   buffer is 100,352 bytes. The fixes are moves, mostly with no resident cost:
   - **Startup code:** `EffHndlr.InitEffectHandlers` (1,825 bytes) and `Magic.InitSpellFns` (925) move to GameInit.
     They run once, but their bytes load with every combat.
   - **ViewChar (15.4 KB):** it leaves the hot loops.
     - `SelectPrevNextChar` moves to resident `Party` (+339 resident). Every ECL menu, the map menus, the shop, the
       vault, post-combat and camp call it.
     - `ToggleReadyItem` and `UseItem` move to FxEngine; the AI calls them when it changes gear or uses an item.
     - The cast menus and `UseItemSpell` move to Magic, which is loaded anyway when a spell is cast.
   - **Magic (17.2 KB):** six small predicates move to CharHlp (+660 resident): `ItemReadable`, `ScrollLegible`,
     `CastableScroll`, `ScrollSpellAt`, `HasScrollSpells` and `CalcSpellRange`. Ordinary turns call them, and loading
     them brings in all of Magic.
   - **GameTime (4 KB):** the clock path (`AdvanceTime`, `ValidateClock`, `TimeOutEffects`; 1,275 bytes) moves to
     FxEngine, so GameTime no longer loads every round and every step.
   - **Encounters and treasure:** `SaveLoad.LoadCreatureData` moves to EclMenu, its only real caller, which takes
     SaveLoad's 11.6 KB out of encounters. `Money.GenerateRandomItem` moves to MoneyCal, so treasure loads about 3.5 KB
     instead of Money's 9.4 KB.
   - **JrnlList:** it is resident only because `{$O JrnlList}` is missing from fixmain (1,848 bytes).

   The estimate afterwards: a combat round is about 76 KB without spells and 93 KB with them, and an explore step about
   62 KB. Measure before deciding on larger splits (MenuVertical, CharDisp's combat routines, CbtActs' aiming UI) or on
   a bigger `OVERLAY_BUF_BYTES`.
2. **Unit cycles.** All six implementation cycles named in phase 1 are still there, and there are two new ones
   (CharHlp–CharDisp through `Guard`, Shop–Temple through the counter menu). Nine small moves remove every cycle:
   - `GetIconTileDelta` moves to Pathing.
   - CbtMap's spell-aim preview gets a lightning tracer passed in, instead of calling Magic.
   - `GameIo.ShowMemory` moves behind a hook, which also breaks the DaxIo–GameIo–TextRend loop.
   - `RemoveCreature` and `FreeCreature` move to SaveLoad.
   - `VaultMenu` moves to its own small unit.
   - `CheckSaveDir` and `SaveDiskMsg` move to SaveMenu.
   - `Guard`'s message moves to its two callers.
   - `CounterMenu` takes the temple's heal menu as a procedure parameter.
   - `SelectPrevNextChar` moves to Party (step 1).

   Initialization order follows fixmain's `uses` list, so check the units that have initialization sections.
3. **Duplication.** In order of value:
   - **Item and effect lists:** 7 copies of "prepend a heap copy onto a list" (`CharHlp.PrependItemCopy` and an effect
     twin), and 4 copies of "append at the tail".
   - **Blit:** `BlitTileCell` is `BlitTileClipped` without the clipping. One core with a `clip` argument, the span
     marks shared, and the four EGA plane loops made one loop. Measure the cost per row in combat.
   - **Clearing rectangles:** `Border.ClearBox` and `TextRend.ClearRect` are the same routine. Keep TextRend's, with
     ClearBox's clamping.
   - **View3D:** `Display3DMapView`'s mirrored left and right scans become one parameterized scan.
   - **Menus:** the coin menus (ViewChar's two are identical), and line appends through MenuCore helpers.
   - **CharGen:** the racial ability limits, written out three times (pin them with tests first, because the two arrow
     paths differ), and the pick loops for gender, class and alignment.
   - **Smaller ones:**
     - `DaxIo.DiskName` for 16 `Str(virtualDisk)` sites.
     - `GameIo.FatalError` for 8 restore-print-exit blocks.
     - `Party.LastCreature` and `PrevCreature`.
     - The Con save bonus, which is `con * 2 div 7`, into AbilAdj.
     - `FileUtil.OpenReadOnly` in DataArc.
     - CbtMap's pasted `DrawCellCreature`.
     - The remaining raw `Str` calls.
   - **Constants still written as literals:** spell ids, the 72 arena slots, the element-mask bits, the window
     corners, the GBVM zone bounds, `C_Level` loops written as `0 to 7`, and the party limit.
   - **GBVM addresses get names.** Every raw address in EclVars' map and elsewhere (`$18`, `$9B`, `$2CF`, the
     `$6B00`/`$BF68`/`$C04B` bases, the zone bounds) becomes a named `C_Gbvm` constant, so a grep shows every file that
     touches an address. Take the opportunity in any step that passes one.
4. **Testability**, as AbilAdj and MoneyCal were done:
   - **Dice:** `RollDice` and `RollDamageDice` move to a resident unit, so tests can fix `RandSeed`. That is about 150
     call sites in 17 units, so it gets its own issue.
   - **CharHlp:** only five sites keep it out of a test program. `PrintItemString` splits into an `ItemLabel` and the
     print; `CountTargets` and `CalcDistance` move to CbtMap; `Guard`'s message moves (step 2). Then RecalcStats, the
     adjusters, the weights, AtLevelCap and CanTrain get tests.
   - **ClassCal:** gets the hit-point and experience rules (CharGen's HpMinimum, HpMaximum and RollFirstLevelHp,
     `ConHpTotal`, and PostCbt's experience award), extending TClasCal. `HpMaximum` reads curChar instead of its
     parameter; every caller passes curChar, so fixing that changes nothing.
   - **Pathing, after step 2:** PathFind, WalkLine, IsDirToward and the tie rule in SortTargets.
   - **EclVars:** only `SpecialWriteZ1`'s pushes, wall-set loads and RecalcStats reach outside it. Behind hooks, the
     GBVM address map (`ReadGbvm`, `WriteGbvm`, `SkipEclCmd`, `ConvGbString`) gets tests of every special address.
   - **Also:**
     - The clock arithmetic, as a small unit.
     - The usual-spells store, as its own unit with a round-trip test.
     - Tests for JrnlList, DataArc and `EclTrace.OpName`, which can be tested as they are.
5. **GDVars and interfaces.**
   - **Dead globals:** remove the ones that are written but never read (`treasureMoneyFlag`, `unidentified01..03`,
     `itemsOk`, `extFlag`, `attackedAllies`, `prevOpcode`) and four unused constants. `writeReg1/2` and `readReg1..3`
     look dead, but they are ECL registers (GBVM $B8/$B9 written, $FB/$FC/$B1 read as 0), so they stay or become
     explicit arms in EclVars' address map.
   - **Locals:** the loop counters and scratch values become locals (`gi2`, `team`, `gSpellTemp1/2`,
     `dsCurrentPictureNumber`).
   - **Private:** the globals only one unit uses become private to it (CombatSt's placement, PostCbt, EclVm, GameBoot,
     Magic's spell list).
   - **Explicit layouts:** the five party-position bytes that a saved game holds become a record or five reads and
     writes, and `baseItems` becomes one array of 129.
   - **Interfaces:** take the 165 spell and effect handlers out of the EffHndlr and Magic interfaces (the dispatch
     tables stay as they are), and move Magic's and FxEngine's interface `uses` to their implementations.
   - **Forward declarations:** delete the 25 that nothing needs.
6. **Data segment and stack.**
   - **Data segment, about 11 KB:**
     - `gbStrings` moves to the heap (5,116 bytes).
     - `baseItems` moves to the heap (2,060).
     - `nameParts` is packed (about 3 KB).
     - `spellNames`, `spellLevelNames` and `templeSpells` get shorter string types (871).
     - DataPat's tables and DataBld's startup variables move to the heap or a file (about 2.9 KB).
   - **Stack:** `CalcDistance` copies 216 bytes into a 765-byte local, and `PrintHpDebug` and `NonWeaponDamage` have
     string frames on combat paths. 16 KB holds today, with about 6 KB of margin in the worst chain.

**What the ECL can see.** Steps 5 and 6 must keep it working:
- **Globals by name.** Scripts reach globals through EclVars' address map: `ReadGbvm`, `WriteGbvm`, `SpecialReadZ1`,
  `SpecialWriteZ1` and zone 4's arms. A global named there (`gMapX`..`eventAtCell`, `gFacing`, `virtualDisk`,
  `sndEffect`, `redrawSky`, the wall and sky colour selectors, the dump flags, the registers and `gbStrings`) can move
  or change storage, but its arm must keep reading and writing the same value.
- **The character record by layout.** GBVM $6B20..$6B70 is a raw window into the current character's record, from
  `memorizedSpells[1]` on past it, so scripts depend on TCharRecord's layout. TRecLay pins it.
- **Saved games by layout.** The saved game writes the zones and the five map bytes as blocks; TSaveLay pins those.
- **GDConsts.** The ECL reads only `soundIds`, by name.
- **A test of the address map.** Before step 5 touches any global the map names, step 4's EclVars extraction adds
  tests that read and write each special address.

**Done.** Every step was made except the four items below, which were declined for the reasons given. The regression
suite passes at each measured commit, ssiformat included.

- **Overlay working sets (steps 0 and 1):** combat's Ctrl-Y count went from 52 to 41 loads, areachange's from 32 to
  27, and the vault's from 32 to 30. JrnlList is overlaid. Step 4 then put combat back at 45: post-combat loads ClassCal
  for the experience share (+2), and freeing monsters reaches UsualSpl (+2). Both were kept for the tests; making
  UsualSpl resident would save one load for 832 resident bytes.
- **Cycles (step 2):** all eight implementation cycles are gone. ShowMemory went to a resident unit of its own,
  MemShow, so the Ctrl-Y display loads no overlay. VaultMnu is a unit of its own.
- **Duplication and names (step 3):** the list, clearing, menu, View3D and Blit copies became one routine each. The
  GBVM addresses are named in C_Gbvm, with the map checked label by label.
- **Testability (step 4):**
  - New units: Dice (#642) and Clock, both resident; RandItem and UsualSpl, both overlaid.
  - CharHlp now reaches the screen only through a hook. ClassCal holds the hit-point and experience rules. EclVars
    reaches DaxIo and View3D through hooks.
  - Nine new test programs: TCharHlp, TClock, TDataArc, TEclTrc, TEclVars, TJrnl, TPathing, TRandItm and TUsualSp.
    TAbilAdj and TClasCal were extended.
- **GDVars (step 5):**
  - Removed: seven dead globals, the five script registers (now explicit arms of the GBVM map), and three unused
    GDConsts tables.
  - Locals or parameters: six scratch globals.
  - Private to their units: 55 globals, among them CombatSt's placement tables.
  - `baseItems` is one array of 129. The saved game's map position is five reads and writes.
  - Magic's and FxEngine's interfaces use only Types. 24 forward declarations are gone (one fewer than the survey
    counted).
- **Data and stack (step 6):**
  - `gbStrings` and `baseItems` moved to the heap. Three spell-name tables got shorter string types.
  - CalcDistance's 549 extra bytes of stack are gone. NonWeaponDamage's frame is smaller. A level drain no longer
    loads Debug.
- **Sizes:**
  - Resident code: 67,632 → 65,056 bytes.
  - Data: 44,158 → 35,892 bytes (29,628 free).
  - Overlays: about 331,900 → 325,906 bytes.

Declined:
- **The handlers in the EffHndlr and Magic interfaces stay there.** GameInit fills the dispatch tables by name, which
  keeps that code out of the overlays (step 1).
- **`nameParts` is not packed.** TP 6 string literals stop at 255 characters, so the 255 names would become rows of
  run-together text. With 29 KB of data free, that is not worth 3 KB.
- **DataPat's fix table and DataBld's state stay in the data segment.** DataPat's are typed constants, and moving them
  would lose each fix's commented source. DataBld's are about 700 bytes.

Separate, because they change behaviour:
- POR-0166 (#640): Space in combat treats animated creatures differently on the menu and during the AI's turn.
- Camp converts rest minutes into the rest timer two ways (`camp.pas:273` and `:1015`). They differ once the total
  passes a day.
- `heapFailureSaveEnabled` is never set, so HeapErr's out-of-memory save can never run: enable it or remove it.
- #616: the Constitution hit-point bonus.

## Working method

One branch and one PR per phase, an issue per item, each change checked against the tests, the regression suite and
the size report. Phase 0 first.
