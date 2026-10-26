# Shared Gold Box units: the plan

The last part of the refactor: one shared core for the five Pascal ports (Pool of Radiance, Curse of the Azure Bonds,
Secret of the Silver Blades, Pools of Darkness, Champions of Krynn), so a rule, a fix or a feature is written once.
Drawn up 2026-10-26 from five surveys of every port at its origin/main (research/: rules, engine, presentation,
gameplay, fleet; brief.md is what they were asked). Not part of the next PoR release: the work lives on
`refactor/shared-units`.

## The shape

- **Each game stays its own repository, built by itself.** Within a game's repository its versions become one source
  tree with the version differences overlaid. There is no repository holding all the games.
- **One shared core, `goldbox-core`**, a repository of its own, copied into each port as `CORE/` by a sync script, with
  CI checking that the copy matches the pinned core (its git tree id), so a local edit fails loudly. A git submodule is
  the fallback; a subtree (silent drift) or a fetch at build time (offline builds and the CI's reproduction of old tags
  break) is not.
- **Per-game units of the same names pick the game.** The unit search path puts the game's own folder before `CORE/`,
  so a game unit replaces a core unit of the same name. That is the override mechanism and the way each port adopts the
  core one unit at a time; a build check lists every override so none is accidental.
- **The byte-matched disassembly trees never use the core.** Version overlays there are ordered folders per version
  (`/U` lists the version's folder before the shared base), byte-neutral and proven by the gate. A finer
  `{$IFDEF V12}` overlay would need the cleanup spec's rule 1.8 (no `{$IFDEF}` in byte-matched trees) changed: Brian's
  call.
- **Compiler floor:** shared source compiles under Turbo Pascal 5.5 (Secret's), TP 6.0 and Free Pascal `-Mtp` (PoR's
  native build): no `Break`/`Continue`, no `asm` blocks in shared code. Moving Secret to TP 6.0 first would raise the
  floor.

## What the surveys found

- **One engine, five vocabularies.** The logic matches far more than the text: of 1,507 gameplay routine families only
  24 are word for word identical, but with identifiers masked 371 of the four non-PoR ports' families agree at 0.85 or
  better. The engine survey: of 308 routines in two or more ports, 108 are identical apart from names and data, 101 the
  same logic with game branches, 99 diverged (mostly in Pools). The presentation survey: 78 identical, 72 nearly so.
  The same variable has a different name in each port (the current ECL opcode has five). **A naming pass is the
  precondition for everything else.**
- **Records differ in size, not design.** The character record is one skeleton at five sizes (PoR 285, Curse 422,
  Secret 439, CoK 409, Pools 510 bytes): different array bounds (known spells, slots, coins) and a few game-only fields
  (Krynn's deity, knight order and robe; Pools' peak levels). SSI's saves must stay byte-exact, so each game keeps its
  own `Types`; shared code works on an in-memory record sized to Pools' maxima with per-game load and save conversion
  (Curse already separates its in-memory creature from its disk record; PoR's DiskRec does the same for 64-bit).
- **Ids are per game and stored in saves, scripts and SSI's data**, so they are mapped, never renumbered: races (four
  orders), the spell-list enum (three), item types (three), effects (two families; three numberings above 56), spells
  (one space but collisions at 36, 56, 58, 63, 66, 67 and from 90). Classes, abilities, saves, alignments, statuses and
  the 9-byte effect node already agree.
- **Rules agree where they overlap** (the four Forgotten Realms games): racial limits and adjustments, class minimums
  and prime requisites, Constitution hit points to 25, saves, XP and slots, the turning table. They differ in range
  (PoR to level 9, Curse 12, Secret 18, Pools 21 to 40) and encoding. Champions of Krynn is a rule set of its own on
  the same skeleton (Krynn XP by order and robe, its races, alignment and hit dice): it shares the types and the
  ability code, few tables.
- **The script VM** has three opcode revisions (PoR $00..$3D; Curse +$3E..$40; Secret and CoK +$41) and Pools'
  renumbering of eight slots; three GBVM address layouts. The address maps and dispatcher are per-game data; about 40
  handlers can be shared.
- **Most shareable now:** data loading (DataArc, DataChk, DataBld, the DaxIo core: 90-100% alike in PoR, Curse, Secret,
  CoK; Curse's copy is the newest), the data-build screen BldShow, PoR's AbilAdj (already runs every ability rule to 25),
  the sound sequencer (four games, byte-identical tables; Pools uses external DOS drivers), the mode-independent half of
  video (picture loading, masks, fills, windows, menus), and the native layer (about 85% game-agnostic already).
- **Two crash-safe save mechanisms**: PoR's FileUtil file sets, and SaveJrn's journal (Curse, Secret, Pools; same
  code). CoK has neither. They become one.
- **Video is organised five ways over one engine**: PoR's Pascal driver record; Curse's record with SSI's assembly
  blitters; CoK's smaller record and 4-bit VGA; Secret's mode branches, no VGA; Pools' own 256-colour VGA with palette
  cycling. Each other game needs only one Pascal VGA path to run natively; DOS keeps its assembly.

## The shared core (target)

| Area | Shared units | Per game |
|---|---|---|
| Rules | `AbilAdj` (PoR's, taking scores, not a record); `RuleTbls` (tables, level 1 to Pools' maxima, by canonical race and class); `RuleCal` (XP, THAC0, saves, slots with gates, thief skills, turning, Con hit points, race level caps, attacks, starting age: levels and scores in, values out) | `GameRules`: maximum class level per class, maximum spell level per list, last spell id, classes and races offered, rule switches; id maps (race, spell list, effect); hooks: hit-die roll, armour vs thief skills, the slot-doubling item, CoK's progression by order and robe. Each game's `RecalcClassStats` stays a short loop over `RuleCal` writing its own record |
| Engine | DaxIo core, DataArc, DataChk, DataBld, BldShow; FileUtil merged with SaveJrn; DiskRec; TpRand, StrUtil, Dice, HeapErr; `EclCore` (the shared handlers) | `Types`, `GDVars`, `GDConsts`, the `C_*` constants, DataPat, `EclMap` (address map, dispatcher, skip table, CALL services), the save block list and file names, character readers and import converters, GameInit, FixMain and its overlay list |
| Gameplay | `CharRules`, `ClassRules`, `Training`, `FxCore`, `FxHandlers`, `MagicCore`, `CombatCore`, `TownCore`, naming spells and effects symbolically | the spell and effect id tables; hooks: CoK's moon caster level and saves, Pools' AI spell picker and cast animation, Curse's miscast, CoK's exploders, the temple's raise rule, Camp's Fix variant; game-only handlers in per-game overlaid units |
| Presentation | TextRend, MenuCore, Border, Blit and the video driver record (with an optional assembly override per entry), the view/map/portrait core, the sound sequencer and its device drivers, key input, CfgFile, TuiKit and a general setup program, the native layer | a constants unit (font archive, frame tables and symbol bases, config names and letters, tune ids, identity strings) and a hooks unit (Pools' backdrop and palette, PoR's wilderness view and merged portraits, the intro); Pools keeps its own picture and sound back ends at first |

Shared tables must not land in the DOS data segment unsized: at Pools' range the rules tables add about 4.6 KB (PoR
about 3.5 KB). Data segment free today: Pools about 17 KB, Curse about 11 KB. Measure first; keep large tables in
overlaid code space or loaded from a file (as PoR's DataPat now does).

## Order of work

0. **Prerequisites.**
   - Push the disassembly repos' unpushed work (curse 78 commits, secret 32, gateway 29, matrix 28, treasures 27,
     dqk 10), give buck-disassembly a remote, give frua's `struct-cleanup` an upstream.
   - Let the Curse agent's migration of PoR's work land; nothing below starts on Curse before it.
   - Brian's rulings R1 to R5 (below).
1. **The mechanism.** Create `goldbox-core` and the sync script; unify the five `build.sh` (they differ from PoR's by
   94-125 lines) with the `CORE/` path and the override check; keep CI's reproduction of old tags (which have no
   `CORE/`) working.
2. **Prove the loop with one identical leaf** (HeapErr or LogWrap) in all five ports.
3. **The naming pass**, port by port (ports only; never in the byte-matched trees): one vocabulary for record fields,
   globals and constants (`GDVars`/`GameVars`, `ESC`/`ESCAPE`, the opcode's five names...), and the text calls'
   background colour (Curse onward) decided once.
4. **Leaf units into the core:** TpRand, StrUtil, Dice, FileUtil + SaveJrn, DataArc, DataChk, DataBld, the DaxIo core,
   BldShow, AbilAdj.
5. **Rules:** `RuleTbls` and `RuleCal` at Pools' range; each port's `GameRules`, id maps and hooks. Here the per-port
   rule bugs the survey found are fixed once (D1..D31 in research/rules.md).
6. **Engine:** DiskRec into every port; the in-memory record at Pools' maxima with per-game conversion; the save block
   list and SaveMenu; `EclCore` with each game's `EclMap`.
7. **Gameplay:** symbolic spell and effect ids with per-game tables; `FxCore`/`FxHandlers`, `MagicCore`,
   `CombatCore`, `CharRules`/`ClassRules`/`Training`, `TownCore`. This step carries PoR's fixes to every port
   (research/gameplay.md section 3: anti-magic Fix, system shock, the wand vs Shield, Bless/Haste sides, Silence's save,
   disease Strength, aura targets, the silver shield, overkill, multiclass age, the combat-core review fixes, money
   parsing).
8. **Presentation:** the text background colour, the video driver record in Secret and in line in CoK and Pools, CoK's
   sequencer split from its 1,554-line file, one sound device numbering (remapped at install, after checking whether
   Secret or CoK store the sound mode in saves), then the native layer for every port (Curse first), with a per-game
   identity record.
9. **Pools' overrides** last (its EclVars, DataBld/.FIX, video and sound back ends).

Every step leaves all five ports building and their tests passing; each port's tag reproduction keeps working.

## Rulings needed

- **R1, THAC0:** the 1st-edition DMG matrix for every class (Pools today; fighters one point worse at even levels in
  PoR, Curse and Secret), or keep 21 minus level for warriors (and the 2nd-edition magic-user and thief rows Curse,
  Secret and CoK use).
- **R2, hit-point rolls:** Pools' best of two, or PoR's Constitution floor.
- **R3, armour and thief skills:** bars all eight, or seven.
- **R4, cleric 7th-level spells:** first slot at level 14 or 16 (Secret and Pools say 16; PHB p.20).
- **R5:** keep "human women reach 18/00".
- **Overlays in the byte-matched trees:** ordered folders only, or allow `{$IFDEF}` (cleanup spec rule 1.8).
- **Secret to TP 6.0** before sharing (raises the compiler floor), or share at TP 5.5.

## Found along the way (to file in each game's tracker)

- Pools: paladin and ranger XP at level 11 (1050000 / 650000 instead of ...001, inherited by every later level);
  level-19 cleric save uses the 16-18 row; the human thief race row holds the half-orc's figures; the cast-facing loop
  can spin forever.
- Secret: paladin level-15 XP 2460001 (2450001); clerics may be true neutral; no Turn Undead routine (check SSI's game
  first) and no wilderness arena.
- Curse: thief read languages at 11-12 (60/65 instead of 55/60); a half-elf ranger may start at age 0.
- CoK (to confirm against its disassembly): the thief race table in PoR's race order under CoK's ids (a kender thief
  gets the half-orc row); `teamCount` indexed by the raw side byte (CURSE-0261); an aborted item spell is still spent
  (#697); the cleric prime requisite tests Wisdom > 14 (Krynn rule or SSI quirk?).
