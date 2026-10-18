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
  **Fixed** in 206471b.
- #644: Camp converts rest minutes into the rest timer two ways (`CampRestMenu` and the Fix rest). They differ once
  the total passes a day.
- POR-0168 (#643): `heapFailureSaveEnabled` is never set, so HeapErr's out-of-memory save can never run: enable it or
  remove it.
- #616: the Constitution hit-point bonus.

## Phase 6: a video driver, and VGA

Written 2026-10-16 from two surveys: PoR's video code at 486aa52, and the later Gold Box games' video layers
(pools-disassembly, treasures-disassembly, gateway-disassembly, curse-disassembly).

**What the later games do.** None of Curse, Secret, Gateway, Treasures or Pools loads a video driver at run time.
- Each links a resident `Blit` unit with TASM routines, one set of entry points per display class: a cell blit, a masked
  cell blit, a clipped blit, a glyph draw and a palette set. It picks the set with a `case` on the mode byte.
- Pools' `EGA.DRV`, `VGA.DRV` and `TGA.DRV` (63-entry near-jump tables, about 30 KB of assembly each) belong to
  `VACE.EXE`, the intro and ending player, not to the game.
- The goldbox-wiki's Pools pages say otherwise; the reconstructed source and the binaries contradict them.
- VGA (mode 13h, 256 colours) first appears in Gateway. Treasures and Pools drop CGA.

What they do better than PoR is organisation: the mode-specific code stays inside the video units.

**PoR today.** CGA (mode 4), EGA (0Dh) and Tandy (9), chosen from POOL.CFG line 2 by GameBoot.
- All video code is Pascal, with no inline assembly: `Mem[]`, `Port[]`, `absolute` arrays over the banks, `Move`,
  `FillChar` and INT 10h.
- About 970 lines are mode-specific. 70% are in Blit (about 520) and TextRend (about 190), both resident. The rest is
  small branches in about twelve units:
  - CharGen's `Recolor`, `MaskSize`, `Overlay` and `Place`.
  - Portrait's frame sizes and remap.
  - BldShow's `PutPixels`, a second pixel converter.
  - SaveLoad's icon merge.
  - The mask sizes in MapTiles, CharDisp and CbtActs.
  - DaxIo's `WriteChar`.
  - The EGA-only palette calls in CbtMap and Intro.
  - Options' mode name.
- There is no indirection: every branch reads `GDVars.videoMode`. Every unit is compiled `{$F+}`, so procedure
  variables cost nothing new.

**The goal.** Game code that does not know the mode, one driver per mode behind one interface, and a fourth driver for
VGA. No new assembly: PoR's video is all Pascal now, and stays so unless a measured hot path needs it.

The steps are in order. Every step keeps the CGA, EGA and Tandy screens pixel-identical (the regression suite compares
them), except where a step says otherwise.

0. **Measure first.**
   - Time the hot primitives per mode: `RenderChar` (every character), `BlitTileCell`/`BlitTileClipped` (every tile,
     glyph and icon), `FillPicRect` (every 3D view) and `FlushView` (every frame; 21 call sites).
   - Add a scenario that runs in each of the three modes, so the suite sees CGA and Tandy as well as EGA.

   **Done.**
   - `bench/vidbench.sh` times the hot primitives in each mode under DOSBox-X at a fixed 10,000 cycles: the EGA
     machine for CGA and EGA, the Tandy machine for Tandy. Runs repeat to the hundredth.
   - `VIDEO=cga` and `VIDEO=tandy` run the regression suite in those modes. Tandy uses goldbox-player's
     `por-v13-tandy` title, because an EGA machine cannot set mode 9.
   - All nine scenarios pass in CGA and in Tandy against the golden 7e2f186, so phases 1 to 5 changed neither mode's
     screens.
   - `loadsave` needed goldbox-player 14eda0e: the QUIT TO DOS prompt sits over the animated camp picture, which
     never settles in CGA or Tandy, so a key that stays unsettled is now forced.

   The baseline at 486aa52, per call:

   | | CGA | EGA | Tandy |
   | --- | --- | --- | --- |
   | `RenderChar`, a character | 189 us | 216 us | 205 us |
   | `BlitTileCell`, an 8x8 masked tile | 91 us | 149 us | 134 us |
   | `FillPicRect`, the 168x168 view | 2.6 ms | 11.8 ms | 2.6 ms |
   | `FlushView`, the whole view | 2.0 ms | 25.7 ms | 2.9 ms |

   EGA is the slowest mode at everything. Its flush is about ten times the others': it writes a byte at a time
   through `Mem[]`, plane by plane, then latch-copies. That is the first primitive for EGA's driver to widen in
   step 3, and the strongest case for VGA's linear screen.
1. **Mode-independent game code.** Move every branch outside Blit and TextRend behind a Blit routine:
   - `Blit.MaskBytes(imageBytes)` for the mask-size arithmetic (about seven sites), and a row stride.
   - One icon-merge routine (OR the data, AND the mask) for SaveLoad's merge and CharGen's `Overlay`.
   - CharGen's `Recolor` merged into `RemapPic`; BldShow's `PutPixels` into the picture converter.
   - The palette calls through one Blit routine that does nothing where the mode has no palette.
   - `GameInit` builds only the active mode's row table.

   After this step only Blit, TextRend, DaxIo's `WriteChar` and GameBoot know the mode.

   **Done.**
   - Blit answers the size and capability questions: `FrameBytes`, `MaskBytes`, `ColourCount` and `HasPalette`.
     `SetPaletteRegister` does nothing without a palette.
   - The cold operations are in a new overlaid unit, `VidOps`: `ModeName`, `InitRowTables` (the active mode's table
     only), `MergePic` (SaveLoad's `MergeIcon` and CharGen's `Merge`), `OverlayPic`, `RecolorPic` (CharGen's
     `Recolor`) and `PutPixelRow` (BldShow's `PutPixels`).
   - Only Blit, TextRend, DaxIo, GameBoot and VidOps read `videoMode`.
   - Sizes: resident code +128 bytes, overlays -468.
   - The suite passes in all three modes, and ssiformat passes. BldShow's converter runs only when the data
     archives are built, which no scenario does.

   The split also sets a pattern for step 2: a driver's hot entries are resident, and its cold ones can point into an
   overlay.
2. **The driver interface.** `TVideoDriver`, a record of procedure variables in a resident unit, with these entry
   points:
   - Mode set and restore, page setup and the heap reserve (Tandy's 16 KB).
   - The row tables.
   - Picture size and mask size.
   - Convert DAX frames (`ExpandPicFrames`), mirror, remap and fill rectangle.
   - Tile blit (masked and clipped) into the view buffer.
   - Flush the view's dirty spans, show a picture on screen, draw a character, clear a rectangle.
   - Set the palette.

   The mode-independent work stays in Blit and TextRend: clipping, the dirty-span bookkeeping, word wrap, picture
   loading and caching. The spans' offsets become the driver's own units (bytes or cells today).

   **How it is being done.** Steps 2 and 3 go together, a group of entries at a time, each group with its per-mode
   code and a regression in all three modes:
   - 2a: the record and the layout.
   - 2b: the screen routines.
   - 2c: the cold picture routines.

   **2a done.**
   - `TVideoDriver` (Types) lives in `GDVars.video`. Three resident units fill it, `VidCga`, `VidEga` and `VidTdy`, and
     GameBoot installs the one POOL.CFG names.
   - The record holds the name, the colour count, the palette flag, and the picture layout as shift counts: `cellShift`,
     `screenShift` and `maskShift`. On the 8086 a shift is a few cycles, where a multiply or divide is about a hundred.
     It also holds `CellFill`, a cell row in one colour.
   - With them, `BlitTile`, `FillPicRect`, `OverlayPic` and the size questions have no mode branches.
   - EGA's fill stores four-byte cells as LongInts.
   - Speed against the step 0 baseline:

     | | CGA | EGA | Tandy |
     | --- | --- | --- | --- |
     | tiles | -7% | -4% | -4% |
     | fill | +54% | +144% | same |
     | fill and flush | +24% | +21% | same |

     The tiles' loss is the generic per-tile setup.
   - Sizes: resident code -496 bytes.
   - The suite passes in all three modes. The extra frame warnings are animation timing: they move from run to run on
     the same build.

   **2b done.**
   - The record gained `biosMode` and `ramVideoParas` (Tandy's screen in system RAM, kept from the heap), plus these
     entries:
     - `Start` (EGA's pages)
     - `FlushSpans`
     - `ShowPic`
     - `DrawGlyph`
     - `ClearRect` and `ClearScreen`
     - `WriteChar`, using DaxIo's new mode-independent `BiosWriteChar`.
   - The drivers hold that code, with EGA's page and graphics-controller helpers and the CGA and Tandy bank arrays.
   - Blit, TextRend and DaxIo keep the span reset, the glyph lookup and loop, and the range check.
   - GameBoot sets any mode from the record: it picks the driver, keeps a RAM screen out of the heap, sets the BIOS
     mode and calls `Start`.
   - Speed is unchanged from 2a. Resident code +720 bytes, from the drivers' entry routines.
   - The suite passes in all three modes, and ssiformat passes.

   **2c done.**
   - The cold entries are `ExpandFrames`, `MirrorFrame`, `RemapColour` (one colour pair of `RemapPic`),
     `RecolorFrame`, `PutPixelRow` and `InitRowTables`.
   - They live in an overlaid unit per mode, `PicCga`, `PicEga` and `PicTdy`, which the resident driver points the
     record into.
   - Blit and VidOps keep the nil checks, RemapPic's scratch copy and colour-pair loop, and the copy back.
   - Nothing reads the video mode any more, so `GDVars.videoMode` and `Types.TVideoMode` are gone. The installed driver
     is the mode.
   - Sizes: resident code -3,072 bytes (62,656). Overlays +3,731, but only the mode's own unit loads.
   - Overlay loads against 2b: areachange 27 to 29, combat 44 to 48, vault 30 to 32. That is the Pic unit, for the
     icon and portrait remaps and the combat icons' mirrors, and all three are still below the golden build's.
   - Speed is unchanged. The suite passes in all three modes, and ssiformat passes.

   **Steps 2 and 3 are done.** Video code that knows the mode is only in VidCga/VidEga/VidTdy (resident) and
   PicCga/PicEga/PicTdy (overlaid).
3. **One unit per mode.**
   - `VidCga`, `VidEga` and `VidTdy` each fill the record from the code now in Blit's and TextRend's `case` arms.
   - GameBoot installs the one POOL.CFG names.
   - All three stay resident: overlaying a driver would reload its hot paths, so resident code stays about what it is
     (the code moves, it does not grow).
   - Check the calls' cost against step 0. An indirect far call replaces a `case`. If a primitive is slower, it gets
     a wider entry point (a row or a span per call) before any assembly.
4. **Tests.** Picture conversion, mirroring, remapping and the mask sizes become TestKit programs per driver, run
   without video hardware against known DAX frames. Screen output stays with the regression scenarios.

   **Done.**
   - TVidPic installs each driver in turn. Installing only fills the record, so no video hardware is needed.
   - It converts a one-cell, two-row DAX picture: colours 0..7 and then 7..0, with 0 transparent.
   - It checks, in every mode, against bytes worked out by hand from the mode's layout:
     - the frame and mask sizes;
     - the converted data and mask;
     - a mirror (row 0 mirrored is row 1), and mirrored twice;
     - a one-colour remap;
     - a one-cell fill;
     - the picture blitted through its mask over another colour.
   - 39 checks pass.
   - build.sh's test runner now finds objects in `obj` as well as `obj\tests`, for the sound driver the video units
     link through GameIo.
5. **VGA (mode 13h).** A fourth driver, `VidVga`, chosen by a new POOL.CFG letter. Its settings:
   - The art is 16-colour, so the DAC is loaded with the EGA palette.
   - Pictures are stored one byte per pixel, 8 bytes per 8-pixel cell, with colour 0 or a key byte as transparency.
   - The screen is linear at $A000:0, 320 bytes per row, with no planes.
   - The view flushes by `Move` per dirty span.

   What VGA gives:
   - Faster, simpler blits and flushes than EGA's planes.
   - Free palette control: the combat and non-combat palettes and the intro flash work as on EGA, and later fades are
     possible.
   - A place for 256-colour art if the project ever has any.

   What it costs:
   - Pictures take twice EGA's memory, 8 bytes per cell against 4 plus a mask. Measure the heap at the busiest screen
     (combat with portraits and animations) before committing. The view buffer and the portrait cache are the large
     ones.
   - Mode 13h has one page where EGA has two, so anything that draws to the hidden page (EGA's `$A200` staging) needs
     a heap buffer or a different order.
   - The settings menu, Options' mode name and the regression suite (a fourth mode to compare) grow to match.

   Pools, Treasures and Gateway are the references for the VGA cell layout and the palette programming
   (`ProgramPaletteOnRetrace`); their designs inform this one but are not copied.

   **Measured.**
   - STING Ctrl-Y now shows the heap pictures hold (`GDVars.picBytes`, counted by AllocPic and FreePic) and their peak.
   - At the end of each scenario in EGA:

     | scenario | heap free | pictures |
     | --- | --- | --- |
     | combat | 215,120 | 133,882 |
     | areachange | 230,128 | 122,174 |
     | vault | 234,000 | 118,302 |

     The pictures stay cached, so the figure is also the peak.
   - Pictures at a byte a pixel with a byte-a-pixel mask would need about 330 KB in combat, more than the heap has.
   - With a colour key and no mask they would need about 240 KB, leaving about 108 KB free.
   - The alternative is to keep pictures in Tandy's layout (4 bits a pixel) and convert to a byte a pixel only when
     copying to the screen, a 256-entry word table per byte. That costs no more memory than Tandy, and gives up only
     256-colour art, which PoR does not have.

   **Chosen: a byte a pixel with a colour key**, as Dark Queen of Krynn keeps its pictures, so the driver carries to
   later games with 256-colour art. Done:
   - `VidVga` (resident) and `PicVga` (overlaid), POOL.CFG letter V.
   - Pictures take 8 bytes a cell row. A transparent pixel holds `Types.PIC_KEY` ($FF).
   - The mask is kept a bit a pixel, a byte a cell row, so code that checks or copies masks works unchanged. Keyed
     drawing does not read it.
   - The record gained `keyed` and `SetPalette`: VGA writes DAC entries 0..15, and EGA's BIOS palette call moved into
     VidEga.
   - Blit's tile loop and VidOps' merge and overlay have keyed paths, and `Blit.ClearPic` clears a picture to
     transparent (CharGen's icons).
   - `TCellBytes` grew to 8 bytes.
   - A picture larger than one 64 KB heap block continues in `TImgBuf.more`. AllocPic, FreePic, ExpandPicFrames,
     BlitTile and RemapPic follow it, and `Blit.FrameBlock` and `FrameCount` serve MapTiles. Of the game's 809 DAX
     pictures, only SQRPACI's two wilderness tile sheets need it: 128 frames of 24 x 24, 73,758 bytes each in VGA.
   - TVidPic checks VGA and the split sheet: 58 checks.
   - goldbox-player's `por-v13-vga` title (a VGA machine) and `VIDEO=vga` run the suite.
   - Against the golden build, which reads V as CGA, VGA's screens differ only in the settings' video line and in
     picture pixels the screen reader takes for glyphs. EGA, CGA and Tandy still pass, as does ssiformat.

   **Memory in VGA**, at the scenarios' ends:

   | scenario | heap free | largest block | pictures |
   | --- | --- | --- | --- |
   | combat | 84,896 | 56,280 | 261,768 |
   | areachange | 111,552 | 79,608 | 238,428 |
   | vault | 119,296 | 79,608 | 230,684 |

   - Boot leaves 156,864 free, against EGA's 302,408.
   - Pictures cost about 1.95 times EGA's.
   - The wilderness tile sheets, loaded at boot and kept all game, are 148 KB of that.
   - The ending's full-screen pictures need 64 KB blocks, which combat's largest block (56 KB) could not give. No
     scenario reaches the ending.

   **The second tile set loads when it is needed.**
   - SQRPACI block 2, tile IDs 128 and up, is drawn only by the wilderness and the ending.
   - `MapTiles.SecondSheet` loads it the first time it is needed, combat setup frees it (`FreeSecondSheet`), and
     GameInit no longer loads it at boot.
   - The first set stays loaded: combat draws its terrain from tiles 0..39, which it overwrites with its own sets, and
     the wilderness overwrites them with BACPAC.
   - VGA at the scenarios' ends:

     | scenario | heap free, before -> after | largest block, before -> after |
     | --- | --- | --- |
     | combat | 84,896 -> 158,672 | 56,280 -> 134,920 |
     | areachange | 111,552 -> 185,328 | 79,608 -> 166,032 |
     | vault | 119,296 -> 193,072 | 79,608 -> 181,600 |

     Every mode gains the same 37 KB (EGA) to 74 KB (VGA).
   - No scenario reaches the wilderness or the ending, where SecondSheet loads.

   **Overlays load from EMS when there is room.**
   - GameBoot calls `OvrInitEMS` after `OvrInit`, before CountOvrRead hooks in, so the count covers both sources.
   - Without an EMS driver, or with too little EMS, overlays load from GAME.OVR as before.
   - STING Ctrl-Y's buffer line ends "from EMS" or "from disk".
   - Conventional memory is unchanged; only the loads get faster. GOG's DOSBox configurations for PoR and Curse have
     EMS on.
   - goldbox-player's sessions take a memory size (12d1bd4). `MEMSIZE=16 tests/regress.sh` runs the suite with EMS;
     at the default 1 MB there is none.
   - The suite passes at 1 MB in EGA, CGA and Tandy, and at 16 MB in EGA (overlays from EMS). VGA differs only where
     it did before, and ssiformat passes.

**Status.**
- Steps 0 to 5 are done: a VGA driver, the second tile set loaded when needed, and overlays from EMS.
- Left:
  - A scenario for the ending, which no scenario reaches. The wilderness has one now (`wilderness`, from a save of
    the owner's in the central wilderness): it passes in all four modes, at 1 and 16 MB, and leaves VGA 134,192 bytes
    of heap free, the largest block 70,904 (EGA: 237,520 and 227,080), with pictures holding 211,735 (EGA 108,417). A
    fight there (`wildfight`) leaves VGA more, 199,312 free and a 180,880 block, since combat frees the second tile
    set: the wilderness map is VGA's tightest spot measured.
  - Freeing the picture caches, for more VGA headroom: pictures held never fall from their peak.

**What could change behaviour.** None of steps 1 to 4 should: the regression suite pins the three modes' screens. VGA is
new behaviour by definition and gets its own issue. A wiki correction for the Pools pages is separate too.

## Phase 7: a sound driver, and AdLib

Written 2026-10-17 from a survey of PoR's sound code at aea6554, and of Pools of Darkness's.

**What the later games do.** Pools of Darkness does not keep its sound in the game: it loads an external TSR driver
(`ADLIB.COM`, `SND.COM` for the Sound Blaster, `IBMSND.COM` for the speaker) chosen at its startup menu, and its music
comes from `MUSIC.DAX`. That is a different design from PoR's and not one to copy: PoR's tunes are in its own
sequencer's streams, and a TSR would need a loader and a data format of its own.

**PoR today.**
- `SoundDrv` (250 lines of Pascal) sits over `sounddrv.asm` (4,244 lines of TASM, linked as SOUNDDRV.OBJ).
- The assembly reprograms the timer to 236.7 Hz (channel 0 divisor 5041), chains the BIOS every thirteenth tick, and
  steps four voices from tune streams: notes, envelopes, an LFO, loops and calls.
- Each device has its own tune table and note table:
  - `songTableA` holds the speaker's tunes. They play on voice 0; tunes 20 to 28 also set up other voices.
  - `songTableB` holds the Tandy SN76489's: three tone voices and a noise voice.
- One `device` byte picks what the interrupt routine ticks: `tick_speaker` drives PIT channel 2 from the first active
  voice, and `tick_tandy` writes the SN76489 at port C0h.
- The mode branches are few, and all close to the sound code:
  - three `case`s in SoundDrv (`SoundCommand`, `PlayMusic`, `StopMusic`);
  - the POOL.CFG letter in GameBoot (T Tandy, P speaker, anything else none);
  - the on/off setting and the suspended device in GameIo (`SetSound`, `soundSaved`);
  - the device name and the Sound setting in Options.
- About forty calls in twelve other units go through SoundDrv's entries (`SoundCommand`, `PlayMusic`, `StopMusic` and
  the timing ones). They do not know the device already.
- Nothing tests sound. The regression suite compares screens and saves only.

**The goal.**
- One sound driver per device behind one interface, as phase 6 did for video.
- A sequencer core that does not know the device.
- A new **AdLib (OPL2)** driver that plays the Tandy arrangements, three tones and noise, through FM synthesis. Sound
  Blaster cards carry the same OPL2, so it serves them too.

The steps are in order. Every step until 3 keeps the speaker's and the Tandy's output identical, write for write (the
trace test of step 0 pins it).

0. **A safety net for sound.**
   - A trace build of the sequencer: the output instructions go through one routine that, in a test build, records
     each port and value with the tick number in a buffer instead of writing to the hardware.
   - A test program (`TSndSeq`) loads every tune and sound effect for each device, runs the tick routine a fixed
     number of times, and checks the trace's length and CRC against a record taken from today's code.
   - `bench`: the interrupt routine's cost per tick on each device, so the core's split can be seen not to slow it.

   **Done.**
   - `sounddrv.asm`'s port writes and its one read while ticking go through the macros `PORT_OUT` and `PORT_IN`.
     - The game's build assembles them to the same `out` and `in`. SOUNDDRV.OBJ's code and data records are identical
       to 30614a4's; only TASM's dated comment record differs.
     - `build.bat` also assembles `/dTRACE` into SNDTRACE.OBJ. There the writes go to a buffer (`SetTraceBuffer`,
       `TraceCount`), and `TraceTick` runs one tick's sequencing on demand.
   - `tests/sndtrc.pas` binds the trace object, and `TSndSeq` plays tunes 0 to 28 on the Tandy and the speaker.
     - Each tune runs until every voice has run out, at most 6,000 ticks.
     - Each tick's writes go into a CRC-32 with their count.
     - The 58 digests, taken from 30614a4's sequencer, are the record: 174 checks.
     - Changing one byte of the Tandy's silence write fails exactly that tune's check.
     - The music (tunes 21 to 28) runs 1,681 to 4,753 ticks and ends inside the limit.
   - `build.sh` now skips any `tests/*.pas` that is a unit, not just TestKit.
   - `bench/sndbench.sh` measures the interrupt's share of the processor at 10,000 cycles: a busy loop's count over
     54 BIOS ticks with the timer off, on and silent, and on and playing the title music.

     | Device | Silent | Playing |
     | --- | --- | --- |
     | Tandy | 0.20% | 0.82% |
     | Speaker | 0.16% | 0.52% |
1. **A driver record.**
   - `Types.TSoundDriver` holds the device's name and its entries:
     - start and stop the timer;
     - load a tune or sound effect;
     - silence;
     - the output routine the interrupt calls.
   - `SndSpk`, `SndTdy` and a silent `SndNone` fill it.
   - GameBoot installs the driver from POOL.CFG's letter.
   - SoundDrv's three `case`s go, and Options takes the device name from the driver.
   - `soundMode` remains only as the Sound setting's on/off.

   **Done.**
   - `Types.TSoundDriver` holds the device's name, the sequencer's device value (`mode`) and `Play`, which loads a tune
     into the device's voices.
     - Starting and stopping the timer stays in SoundDrv: it is the same for every device.
     - The output routine is step 2's, in the assembly.
   - `SndTdy`, `SndSpk` and `SndNone` are resident units of a few lines each. GameBoot installs one into
     `GDVars.sound` from POOL.CFG's sound letter, and `soundMode` takes its mode.
   - SoundDrv's three `case`s became `GDVars.sound.Play`. The stop and disable commands still silence both devices'
     voices, as before (`SilenceAll`).
   - Options' device-name `case` is gone (the Settings screen shows `GDVars.sound.name`), and GameIo's on/off asks the
     driver whether there is a device.
   - Only the driver units name a device now.
   - Resident code +96 bytes, data +26.
   - The unit tests (`TSndSeq` included) and the suite in EGA and Tandy pass.
     - The suite's configurations all name the speaker, so a boot with Tandy sound was run by hand: the title music
       starts through SndTdy, and Settings shows Sound Device Tandy.
2. **The sequencer core apart from the devices.**
   - `sounddrv.asm` is split three ways:
     - the core: voice stepping, streams, envelopes, LFO, loops;
     - each device's output routine and note table, which the interrupt reaches through a pointer the driver sets,
       not by comparing `device`;
     - the tune streams, one include file per arrangement.
   - The trace test shows the output unchanged.

   **Done.**
   - `sounddrv.asm` (749 lines) is the core:
     - the voice stepping, the stream interpreter, envelopes and LFO;
     - the stream macros;
     - the timer interrupt and the Pascal entries.
   - Each device's part is an include, `sndspk.inc` and `sndtdy.inc`: its note table, voice blocks, song table,
     streams, tick routine, and the entry that loads a tune.
     - The move was checked line for line: every line of the old file is in exactly one of the three.
     - The trace test passed on the move alone, before anything else changed.
   - The interrupt (and `TraceTick`) calls the device's tick through `tickProc`, which `SetSoundDevice` sets from
     `tickTable` by device value. A value past the table is no device, with a `tick_none` that returns. The ticks no
     longer compare `device`.
   - UninstallSoundTimer still silences the Tandy chip by comparing `device`; that is once at exit, not a tick, and is
     left for AdLib's silence entry.
   - `TSndSeq`'s 174 checks pass, and so does the suite in EGA.
     - A boot and the combat scenario were run by hand with Tandy sound.
   - The benchmark finds the interrupt a little cheaper, since it makes one call instead of two that each tested the
     device: Tandy 0.18% silent and 0.81% playing (0.20% and 0.82% before), speaker 0.15% and 0.51% (0.16% and
     0.52%).
3. **The AdLib driver.**
   - Detection by the OPL2 timer test at ports 388h/389h. With no card, the game falls back to the speaker and says so
     on the Settings screen.
   - POOL.CFG's sound letter **A** selects it.
   - It plays the Tandy streams:
     - each tone voice's period becomes an OPL F-number and block, from a table built for the SN76489's periods;
     - its level becomes the operator's total level;
     - the noise voice plays through the OPL's rhythm section (snare or hi-hat) or a noise-like patch, whichever
       sounds closer.
   - One simple instrument patch per voice to start, tuned by ear against the Tandy recording.
   - Each OPL write waits the times the chip needs (3.3 us after the address, 23 us after the data). Four voices of
     two or three writes each fit easily within a 236.7 Hz tick.
   - The trace test gains the AdLib's writes once its sound is settled.
   - goldbox-player's DOSBox-X needs OPL emulation on in its configuration (`sbtype`, `oplmode`) for a scenario to run
     with A. That is a change for the GoldBox Tester to make and coordinate.
   - Listening needs the emulator's AVI capture, which records the mixer's audio.

4. **Sound Blaster effects, AdLib music** (added 2026-10-18, the owner's direction after the AdLib effects came out
   "tinny"). No Gold Box game played its effects through FM:
   - Secret and the Krynn games play AdLib music and send effects to the speaker.
   - Pools, Gateway and Treasures play recorded samples (ZOUNDS.DAX through DIGPAK; `SND.COM` is its Sound Blaster
     driver, 9000 Hz in Pools).
   - Dark Queen plays them from `SFXDQ.VOC` on a Sound Blaster.
   - POOL.CFG's sound letters:

     | Letter | Device | Music | Effects | Without the card |
     | --- | --- | --- | --- | --- |
     | **S** | Sound Blaster | AdLib, on the card's OPL2 | SSI's recorded samples | **A**'s behaviour |
     | **A** | AdLib | AdLib | the speaker, as in Secret | the speaker alone |

   - The samples are in `SBSFX.DAT`, built by `tools/sbsfx.py` from the owner's copies of the games. Like all game
     data it is not in git (drive_c is ignored).
     - Dark Queen's effects (SFXDQ.VOC, the file FRUA also ships) are kept in their own 4-bit ADPCM, which the DSP plays
       itself (command 75h).
     - The step is the first of Pools' three thumps ("pad2", 50 ms, 8-bit).
     - Pools' full set was tried first; the owner preferred Dark Queen's, with a single step. Dark Queen's own
       footstep was never a favourite.

     | Tune | Event | Dark Queen's sound |
     | --- | --- | --- |
     | 1 | cast | Cast |
     | 2 | non-weapon damage | Blast |
     | 3 | spell effect on a creature | Sorcery |
     | 4 | downed | Death |
     | 5 | missile launched | Missile |
     | 6 | hit, and bumping a wall | Hit |
     | 7 | Lightning Bolt | Lightning |
     | 8 | miss | Swish |
     | 9 | step | Pools' first thump |
     | 10 | Fireball and the scripts' cue | Fireball |
     | 11 | missile lands | Hit |

     A tune with no sample plays on the speaker. The file comes to 29,912 bytes.
   - Each effect is one single-cycle DMA transfer started on the DSP (time constant, command 14h). The driver
     therefore never hooks the card's IRQ: it needs only the port and DMA channel, from `BLASTER`, or 220h and 1.
     The samples load at the first effect, and only for the Sound Blaster driver (about 30 KB). A sample whose bytes
     cross a 64 KB page (which one DMA transfer cannot) is copied to a bounce buffer, as long as the longest sample,
     placed so that it crosses none.
   - The sequencer switches device per sound: the AdLib for music, the speaker for an effect with no sample.
     Leaving the AdLib silences it.
   - goldbox-player needs Sound Blaster emulation for a scenario to run with S; the GoldBox Tester has the request.

   **Steps 3 and 4 done.**
   - **AdLib.** `sndopl.inc` and `SndOpl` render the Tandy arrangements in FM.
     - The tone voices sit on channels 0 to 2 with one sustained patch. The owner finds the title and battle music
       "sounds great", and it stays PoR's own, note for note.
     - The noise voice plays the rhythm section's snare. Its first FM rendering came out "tinny".
     - `TSndOpl` decodes the Tandy and the AdLib output of every tune from the trace build: pitches within 1%, the
       mapped levels, silent voices silent, and the snare following the noise voice (87 checks).
   - **Effects.** None of the Gold Box games played effects in FM.
     - A now plays its effects on the speaker.
     - S (`SndSb`) plays them as Dark Queen's samples on the DSP, with the footstep the stronger hit of Pools' first
       thump, at a quarter of its level so it sits with Dark Queen's (measured in the owner's recording).
     - The owner listened to each change in DOSBox-X: "Sounds better now".
   - **POR-0170 (#678).** SSI plays the step sound twice on every step forward in the 3D map. The Sound Blaster driver
     sets `singleStep`, so it plays once there; the speaker and the Tandy keep SSI's double tick.
   - **Fallbacks.** Measured in the emulator with no card: A without an OPL2 shows "Speaker (no AdLib)" on the settings
     screen and plays on the speaker. S falls back the same way.
   - **goldbox-player.** It now has `opl=` and `sb=` session options and `regress.py --opl` and `--sb` (01e8a63,
     e36c212, by the GoldBox Tester). A scenario run with A or S waits on two things: the shared checkout's pull, and
     the harness installing SBSFX.DAT beside the build.
   - **Sizes.** Resident code 65,648 -> 69,520 bytes: the AdLib and Sound Blaster drivers stay resident, because effects
     are too frequent for overlay loads. Data 36,440 bytes.

**What could change behaviour.**
- Steps 0 to 2 should change nothing: the trace test compares every port write.
- AdLib is new behaviour by definition and gets its own issue.
- The Settings screen's device line gains "AdLib", and "PC Speaker (no AdLib found)" when detection fails.

**Approved** 2026-10-17. With no OPL2 answering, A falls back to the **speaker**, and the Settings screen says so. The
speaker and Tandy arrangements stay as SSI wrote them; AdLib borrows the Tandy streams.

## Phase 8: the Companion tools

Written 2026-10-18 at the owner's request. These are features, not refactoring; they are planned here like a phase.

**Why.**
- Gold Box Companion (GBC, gbc.zorbus.net) attaches to a running Gold Box game and reads and writes its memory at the
  original executables' addresses.
- The port's memory layout is its own, so GBC no longer works with it.
- Players expect three of GBC's tools: a character editor, a full automap, and a map marked with where things happen.
  The port gets its own.

**Decided with the owner (2026-10-18).**
- **Access:** a **Companion Tools** line on the Settings screen, off by default and kept in POOLOPT.CFG like the
  others. When it is on, a key on the map and camp menus opens a Tools screen, anywhere outside combat. When it is
  off, the game plays as SSI's.
- **Character editor:** everything GBC's covers.
  - Abilities (exceptional Strength included), current and maximum hit points, age, alignment.
  - Each class's level and experience, re-deriving THAC0, saves, spell slots and hit points as training would. That
    includes GBC's level-up anywhere, past racial limits.
  - Gear and money: add any item type with its plus and charges, remove and identify items, set coins, gems and
    jewelry.
  - Spells known and memorized; status (dead, stoned, level drain).
- **Full automap:** a screen of its own, not the 3D view's window. It shows the whole 16x16 area with every wall and
  door, secret ones too. Squares the party has visited are drawn bright and the rest dimmer, and the party's square
  and facing are marked.
- **Markup:**
  - squares with an event, from the map's event plane;
  - what kind of event each is, worked out from the area's script;
  - players' own notes on squares, saved with the game.

**The steps.**
0. **The switch and the Tools screen.**
   - The Settings line and its POOLOPT.CFG key.
   - F6 on the map and camp menus, unlisted.
   - A Tools screen listing Map, Notes and Character.
   - The tools go in overlaid units: they are rarely open, and resident code is at 69.5 KB.

   **Done.**
   - `GDVars.companionOn`, off by default, is the Settings screen's **Companion Tools** line, kept as `COMPANION=` in
     POOLOPT.CFG. With eight settings, the last now sits against the split border.
   - F6 (`C_Keys.F6`) opens `CompTool.ToolsMenu` from the 3D map menu, the wilderness menu and camp while the setting is
     on, and redraws the screen afterwards. The unit is overlaid, and named CompTool because DOS names stop at 8.
   - The Tools screen lists Map, Notes and Character, each "Not built yet" until its step.
   - Checked in the emulator: the setting turns on, F6 opens Tools from New Phlan, and Exit returns to the map.
   - The boot scenario records the Settings screen apart for each build.
1. **Where the party has been.**
   - A 16x16 bit map per area (32 bytes), keyed as AreaName keys areas: the script, and the map for the scripts that
     run two.
   - Set on every arrival in a square, in GameLoop beside the step.
   - Saved in a file beside each save, `SAVGAMx.MAP` (the quick save's too), versioned like `.INF` and `.STS`. SSI's
     own files stay as they are.
   - A save made before this has none, and its areas start unexplored.

   **Done.**
   - `Explored` (resident, about 2.2 KB of data) holds up to 64 areas of 16x16 bits, keyed by the script and the GBVM
     mapId.
   - `View3D.Display3DMapView` marks the square it is drawn from, so moves, turns, arrivals and teleports all count.
   - SaveToSlot writes `savgam<x>.map` (2,183 bytes; quick saves too), LoadSlot reads it, and a new game clears it.
   - `TExplore` (9 checks) covers marking, keeping areas apart, and the file's round trip.
   - Checked in the emulator: a save from camp writes SAVGAMD.MAP.
   - `loadsave` compares the save's files by kind, without the .MAP the golden build lacks.
2. **The full automap screen.**
   - The current area's 16x16 grid, full screen, in every video mode, drawn with the existing picture and text
     routines.
   - Wall and door types as the 3D view and the automap read them.
   - Visited squares bright, the rest dim; the party's square and facing; a legend.
   - Cell size and symbols decided in this step: 16 cells of 11 or 12 pixels fit the 200-pixel screen with room for
     the legend.
   - The wilderness is not in scope; it has its own map.

   **Done.**
   - `CompTool`'s Map draws the area's 16x16 squares in the automap's own 8x8 symbols (set 4: the sixteen wall
     combinations and the party's arrows), straight to the screen at column 2, row 3. The area's name is above it and a
     legend beside it.
   - Visited squares keep their colours. The rest are dimmed through `Blit.RemapPic`: the dark grey square goes black
     and the grey walls dark grey.
   - In CGA's four colours both greys look alike, so there a visited square's walls turn white instead. The glyph takes
     the symbol set's colour map, which CGA's remap translates through.
   - Checked in EGA, VGA and CGA after a walk in New Phlan.
   - The `companion` scenario turns the tools on, walks, and opens Tools and Map. Those screens are recorded for our
     build alone; the walk is compared.
3. **Event markup.**
   - Every square whose event byte is set gets a mark.
   - Classifying them:
     - Each area script dispatches its events through an `ON GOTO` on the event number (Podal Plaza's, for example,
       at `$9AB7`).
     - Following that dispatch, a classifier scans each event's code until it leaves the event (EXIT, or a jump past
       it).
     - It sorts each event by what it finds: **fight** (COMBAT, LOAD MONSTER), **treasure** (items or money given),
       **service** (shop, temple, training, the vault), **exit** (NEWECL, an area change), **trap** (damage, a save),
       or **message** (text only).
   - It runs in the game, on the loaded script, so it needs no shipped data.
   - Unit tests pin it against known squares: Podal Plaza's tavern (a fight), the training hall's notice board (an
     exit), the arms shop (a service).
   - Squares the player has not visited still show their marks. That is GBC's "where things occur".

   **Done.**
   - `EvtKind` (overlaid) reads the loaded script without running it, decoding with `EclVars.SkipEclCmd`.
     - `Prepare` walks the script from its five entry points. From each read of the event byte (an AND of it into a
       variable, or a COMPARE of it) it scans on, tracking which variables still hold the event on each path.
     - The scripts dispatch three ways, all found:
       - an ON GOTO or ON GOSUB on such a variable;
       - a COMPARE with a number, then IF =;
       - a counted copy: New Phlan counts a variable up until it equals the event, then goes ON GOTO on it. The
         training hall counts from 10 and takes 10 off first, so an ADD or SUBTRACT in place moves the variable's
         offset.
     - Any other write to a variable ends its holding the event. Podal Plaza's goes on to hold menu answers.
     - SkipEclCmd loads an ON GOTO's address list over its variable and count, so those two are read from the
       script bytes.
   - `Kind` follows each matching dispatch's code (jumps, calls, both ways past an IF, at most 160 instructions). The
     strongest kind found wins: exit (NEWECL), then service, fight, treasure, trap (DAMAGE), message.
     - A shop or temple sets ENTER_SHOP or ENTER_TEMPLE before the COMBAT that opens it, so service ranks above
       fight. PROGRAM (the training hall, the vault) counts as service too.
     - An event whose code shows none of these (New Phlan's building squares, which only clear flags) is not marked.
       One with no dispatch found is a plain "event".
   - The Map colours each event square's background by kind and lists the kinds the area has in its legend.
     Unvisited squares keep their colour, with dimmed walls.
   - Squares are classified by the running script. On the training hall's notice board, the hall's script runs on
     New Phlan's map, so only its own squares are named and the rest show as plain events.
   - `TEvtKind` (8 checks) lays a script out by hand: ON GOTO, COMPARE and IF =, the counted copy with an offset, a
     variable written over, and a shop's COMBAT.
   - Checked in the emulator in New Phlan and the training hall, in EGA and CGA. CGA has three colours besides black,
     so kinds share them: cyan for events and messages, magenta for traps and fights, white for treasure, services
     and exits.
4. **Player notes.**
   - A note of up to 30 characters on any square, added, changed or removed from the map screen with a cursor.
   - Kept per area in `SAVGAMx.NTS` beside the save.

   **Done.**
   - `MapNotes` (resident, as Explored is) keeps up to 128 notes of 30 characters, each on a square of an area keyed
     by script and map.
     - It costs 4,487 bytes of the data segment (20,766 bytes are left free).
     - SaveToSlot writes `savgam<x>.nts`; LoadSlot reads it; a new game clears it.
   - **Notes** on the Tools screen opens the Map with a cursor on the party's square, moved with the arrows.
     - The cursor's square and its note show below the map. Write types a note and Clear removes it.
     - A noted square's walls are yellow on both the Map and Notes screens (light magenta in CGA), and the legend
       says so.
   - The Map now draws square by square (`DrawSquare`), as Notes redraws the squares the cursor leaves.
   - `TMapNote` (12 checks) covers setting, changing and removing notes, keeping areas apart, the file's round trip,
     and a full set of notes.
   - The `companion` scenario writes a note.
5. **The character editor.**
   - CharGen's Modify Character, split into a facade (today's checks) and the modifying routine the editor calls
     without the experience check, extended to levels, experience, gear, money, spells and status.
   - A screen on the character sheet's layout. Each field is chosen and changed in place, and values are held to the
     game's limits: abilities 3 to 25, as the rules run.
   - Levels and experience go through ClassCal's rules, so a raised level gets its hit points, THAC0, saves and spell
     slots as training gives them.
   - Items are made from the base item table, with their name parts, plus and charges, as RandItem builds them.
   - Not in combat.

   **Done.** `CharEdit` (overlaid), Character on the Tools screen. The party's characters are edited on their sheets
   (Up, Down, Home and End pick another) through `Abilities Levels Gear Magic Health Exit`.
   - **Abilities** is `CharGen.ModifyCharacter(True)`. The main menu's Modify Character is now a facade: no experience
     and `CharGen.Modifiable` (a player race and class), then `ModifyCharacter(False)`, unchanged.
     - Levelled, a Constitution change moves hpMax by what it gives over every hit die (`ClassCal.ConHpTotal`, as
       Temple and EffHndlr do). The hit-point row runs between `HpMinimum` and `HpMaximum` for the levels.
     - Damage taken stays taken, and Exit restores hpCur too. Keep leaves `npcTreasureShare` alone.
   - **Levels** lists each class with its level, the experience and hit points.
     - Right raises a level through `CharGen.GainLevels`: training's level gain, moved out of TrainingMenu, without its
       drained-level restore. That covers hit dice, skills and a magic-user's new spell.
     - Left lowers one. Hit points drop by a hit die's average plus the Con bonus, divided by the class count, and the
       skills are recalculated. A cleric or magic-user back at level 1 gets level 1's slot.
     - Levels run 1 to `C_Level.LEVEL_LAST` (9), past the racial limits. The experience follows into the new level's
       range, and Experience types a total.
     - `ClassCal.HpMaximum` now reads `GDConsts.hpDice` and `hpSides` instead of its own copy of them.
   - **Gear: Add** lists every weapon and armour RandItem makes, the magic items of its templates (all but the
     Scroll of Restoring Levels, which nothing makes), and the two scrolls.
     - Weapons and armour then take a plus from 0 to 5 with Left and Right; the name and value follow.
     - The item comes identified and goes to the character if it can carry it. `RandItem.ApplyTemplate` is the
       template step, split out of GenerateRandomItem.
   - **Gear: Money** sets each of the seven coin counts. The Items menu already drops what is not wanted.
   - **Magic** toggles the magic-user's or cleric's known spells of levels 1 to 3.
   - **Health:** Heal restores the hit points and wakes the unconscious and dying. Status steps through okay,
     unconscious, dying, dead, stoned and gone.
   - `TRandItm` checks ApplyTemplate. The `companion` scenario walks every tool on Talonia.

**Testing.**
- Unit tests for the visited and notes files, and for the classifier against known squares.
- Scenarios for each tool screen, recorded for the candidate only, since the golden build has none.
- The regression suite with Companion Tools off must pass unchanged.

**What could change behaviour.** Nothing with the setting off. With it on, only what a player does in the tools.

**Approved** 2026-10-18, with the owner's answers:
- **F6** opens the Tools screen from the map and camp menus. It is not listed on either.
- An edited character is not marked.
- The editor builds on CharGen's Modify Character.
  - Its modifying part becomes a routine of its own. `ModifyCharacterMenu` stays as a facade that keeps today's checks
    (no experience yet, a player character) and then calls it.
  - The Companion editor calls it directly, with no experience check.
  - Hit points need care once a character has levels: Modify was written for a fresh character's single roll.
- GBC's other tools (teleport, party heal, auto-identify) are not asked for and are left out.

## Working method

One branch and one PR per phase, an issue per item, each change checked against the tests, the regression suite and
the size report. Phase 0 first.
