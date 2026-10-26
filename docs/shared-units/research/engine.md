# Shared engine core across the five ports: analysis

Area: engine core (Types, GDVars/GameVars, the ECL VM, data loading, saving/loading, startup, GameIo, GameTime,
Dice/TpRand). Read from each repo's origin/main on 2026-10-25: pool-of-radiance 109f2c2, curse-of-the-azure-bonds
34eaebd, secret-of-the-silver-blades b49f824, pools-of-darkness 33ddd3b, champions-of-krynn b142dd6. Nothing in any
repository was modified; sources were exported with `git archive` into the scratchpad.

Method:
- Each unit's implementation was split into top-level routines.
- Each routine was compared across games by name on two token streams:
  - **exact**: the tokens as written, with unit qualifiers dropped.
  - **shape**: identifiers, numbers and strings replaced by placeholders, so renamed variables, other GBVM addresses
    and other message text do not count.
- Shape >= 95% means "identical but for names and data". 75-94% means "same logic with game-specific branches". Below
  75% means diverged. The low cells were read as diffs.
- Record sizes were measured, not counted by hand. Each game's `types.pas` and includes were compiled with Free Pascal
  for i386 (`-Mtp`, `{$PACKRECORDS 1}`, so 4-byte pointers like DOS far pointers), and `SizeOf` was printed for every
  record type.
- Tools and raw tables: `.../scratchpad/engtools/` (`rc2.py`, `rc3.py`, `rd2.py`; `ecl.txt`, `data.txt`, `save.txt`,
  `boot.txt`).

The cleanup spec (goldbox-re-tools/docs/superpowers/specs/2026-10-04-cross-game-cleanup-design.md) governs the
byte-matched disassembly trees (`por-disassembly/v13` and so on), not these ports. Nothing proposed here touches those
trees, and they must stay byte-matched. Two points of the spec do bear on this work:
- Its scope cut unifies routine names across games (1.7, 10.x). The ports already share most routine names, which is
  what makes name-keyed matching work here.
- It names variables, fields and types per game. The ports followed that, and it is now the main obstacle to sharing
  code (see section 2).

Build order matters for "which copy is newest". The ports did not evolve in SSI's order. Curse took PoR's refactor
plan and pushed it further (DataChk split, SaveJrn), Secret copied Curse's, and Pools did its own. Champions is the
least refactored (no SaveMenu, SaveJrn, FileUtil, Dice unit or EclVars).

---

## 1. Headline findings

1. **The logic is shared and the names are not.** Across the engine units, 486 top-level routines were matched by
   name. 178 exist in only one port. Of the 308 found in two or more ports, the worst-case shape similarity against
   the reference copy breaks down as:
   - **108** (35%) are identical but for names and data (>= 95%).
   - **101** (33%) are the same logic with game branches (75-94%).
   - **99** (32%) have diverged in at least one game.

   Most of the "diverged" cells come from one port, and that port is nearly always Pools: its ECL memory model was
   rewritten. The same variable has five names across the ports. The current opcode is `curOpcode`, `scriptOpcode`,
   `curOp`, `curEclOpcode` and `eclOpcode`. The current disk is `virtualDisk`, `diskIndex`, `diskNum`, `currentDisk`
   and Pools' `vmBand`. The party list head is `creatureList`, `partyHead` and `creatureListHead`. Field names in
   Types differ the same way. **Unifying the names of the engine's shared state and record fields is the
   prerequisite** for any shared source. It is mechanical, but it touches every file.
2. **The character record is one design at five sizes.** SSI's disk sizes, measured:

   | Game | Character | Item | Effect |
   |---|---|---|---|
   | PoR | 285 | 63 | 9 |
   | Curse | 422 | 63 | 9 |
   | Secret | 439 | 67 | 9 |
   | Champions | 409 | 63 | 9 |
   | Pools | 510 | 63 (with a 17-byte TItemDef inside) | 9 |

   Every field sequence is the same skeleton: name, stats, memorized spells, prep, THAC0, race, class, age, hpMax,
   known spells, saves, thief skills, effects pointer, NPC, coins, class levels, ... 13 equipped pointers, next,
   combat, current values. They differ in:
   - Array bounds: known spells 56/100/117/107/126; memorized 21/21/?/58/141; class levels 8/8/7+7/8+8/7x3.
   - Coins: 7, except 3 in Pools.
   - Spell-slot grids: 2x3, 3x5, 4x7, 4x5, 3x9.
   - Game fields: Krynn's knightOrder, deity and robeOrder; Pools' oldExperience, peakClassLevels and levelCapped.

   **Save compatibility forbids one record layout. Each game keeps its own Types with SSI's bytes, and the shared code
   compiles against it** (section 9).
3. **The ECL opcode set is one table with three revisions.**
   - PoR: $00..$3D, with $1F unused.
   - Curse: adds $3E DUMP, $3F FIND_SPECIAL and $40 DESTROY_ITEMS.
   - Secret and Champions: add $41 AWARD_EXPERIENCE.
   - Pools: renumbers eight slots:

     | Opcode | Was | Now |
     |---|---|---|
     | $1D | PARTY_STRENGTH | WAIT_KEY |
     | $1F | unused | JOURNAL_ENTRY |
     | $22 | PARTY_SURPRISE | YES_NO |
     | $23 | SURPRISE | REDRAW_EXIT |
     | $2C | PARLAY | PLAY_SOUND |
     | $31 | SPRITE_OFF | HMENU (the other variant) |
     | $37 | LOAD_PIECES | FIND_NPC |
     | $3C | PROTECTION | STORE |

   The dispatcher becomes a per-game opcode table (data). Most handlers are shared.
4. **The GBVM address space has three layouts.**
   - PoR: zones at $4900/$6B00/$9700/$9900.
   - Curse, Secret and Champions: $4B00/$7C00/$7A00/$8000, with Word cells.
   - Pools: a byte-addressed bank 0 at $0001..$0400, a character window at $0401..$0800 and the script at $8000..$9DFF.
     ReadGbvm takes a width, and there is no zone 1 or zone 2.

   The address maps (ReadGbvm, WriteGbvm, SpecialReadZ1, SpecialWriteZ1, EclCall's service addresses) are game data
   wrapped round shared logic. Pools' memory model is a real divergence and needs its own EclVars.
5. **Data loading is the most shareable area.**
   - DataArc, DataBld and DataChk (merged archives, data fixes, CRC stamps) and the DaxIo core are 90-100% shape-equal
     across PoR, Curse, Secret and Champions.
   - Curse's copy is the most refactored: DataChk is split out and AddSpareBlock extracted.
   - The game data is C_Data (14/14/12/7/14 families and 6/5/3 source disks), DataPat's fix table, and file names.
   - Pools went its own way (a fixed copy per family, `.FIX`, BuildCopy, CheckCopy and UseFixedCopy). It is the one
     port to bring over to the shared design or keep as an override.
6. **There are two crash-safe save designs to pick between.**
   - PoR's FileUtil file sets: temporary copies with a '$' mark and backups with a '%' mark, plus RecoverSet.
   - Curse, Secret and Pools' SaveJrn: a phase journal `savjrn<x>.j0..j4`, pure decision logic, already
     unit-tested in three ports.

   Champions has neither. One of them should become the shared unit.
7. **Only PoR has the 64-bit native layer** (DiskRec, TpRand, COMPILER.INC, `{$IFDEF FPC}`). Every other port writes
   `SizeOf(TCharRecord)` straight to disk. Built natively, that would grow each file by 4 bytes per pointer: about 68
   bytes per character in Curse. DiskRec is written against field names alone, so once the names are unified it is
   shareable as it stands, with per-game `*_DISK_BYTES`.
8. **The compiler floor is Turbo Pascal 5.5, not 6.** Secret's HEAD builds with TP 5.5, and Curse v1.0/1.1 with TP 5.0.
   Shared source must therefore avoid:
   - `asm` blocks, which arrived in TP6.
   - `Break`/`Continue`, `const` parameters, open arrays, `High`/`Low` and `Exit(value)`, as the ports already do.

   It must also compile under FPC `-Mtp` for the native build.

---

## 2. Naming: the obstacle, measured

| State | PoR | Curse | Secret | Pools | Champions |
|---|---|---|---|---|---|
| storage unit (vars / typed consts) | GameVars / GameDefs | GDVars / GDConsts | GDVars / GDConsts | GDVars / GDConsts | GDVars / GDConsts |
| vars in the vars unit (approx.) | 132 (55 made private) | 207 | 230 | 369 | 350 |
| current opcode | curOpcode | scriptOpcode | curOp | curEclOpcode | eclOpcode |
| instruction pointer | eclIp | eclIp | eclIp | vmBand.eclIp | eclIp |
| zones | zone0..3 | zone0..2, scriptCode | zone0..3 | vmBand.zone0, zone3 | zone0..3 |
| current disk | virtualDisk | diskIndex | diskNum | (none by that name) | currentDisk |
| party list head | creatureList | partyHead | creatureList | creatureListHead | partyHead |
| save directory | (SaveMenu) | savedGamePath | saveDir | saveDir | saveDir |
| map position | gMapX, gMapY, gFacing, wallAhead, eventAtCell | partyPos record | partyPos | mapState record | mapState |
| character record type | TCharRecord | TCreature (TCharRecord = PoR's, for import) | TCharRecord | TCharRecord | TCharRecord |
| next character / items / effects | nextCharAddr / itemsAddr / effectsAddr | next / itemsAddr / effects | nextCharAddr / itemsAddr / effectsAddr | next / items / effects | next / itemsAddr / effects |
| ECL operand arrays | gbvmType / gbvmLowerByte / gbvmUpperByte | varLo / varHi ... | ... | eclVarTypes / eclVarLo / eclVarHi | ... |

Routine names are already mostly common: every ECL handler, LoadDax, OpenDax, SanitizeFileName, CampRest and so on.
The divergence is in variables, fields and types.

---

## 3. Types: record layouts

Sizes in bytes, measured with 4-byte pointers (the DOS far-pointer size):

| Record | PoR | Curse | Secret | Pools | Champions | On disk? |
|---|---|---|---|---|---|---|
| Character | 285 (+1 portExt, not saved) | 422 (TCreature) | 439 | 510 | 409 | yes: roster file, save member, MONxCHA.DAX |
| Previous game's character, for import | none | 285 (PoR) and Hillsfar | 422 as TSvRec (Curse) | 439 legacy (Secret) | none | read only |
| Item | 63 | 63 | **67** (trailing `bundleNext` pointer) | 63 (41-byte name block, inUse, next, 17-byte TItemDef) | 63 | yes: item file, ITEMx.DAX, MONxITM.DAX |
| Effect | 9 | 9 | 9 | 9 | 9 | yes: effect file, MONxSPC.DAX |
| Combat record | 22 | 23 | 23 | 22 | 22 | no |
| Arena / combat map | 1257 | 1257 | 1257 | 1257 | 1257 | no |
| Spell definition | 16 | 16 | 16 | 16 | 16 | no (GDConsts) |
| Base item | 16 | 16 | 16 | 16 (+17 TItemDef) | 16 | no |
| Item list node | 46 | 46 | 46 | 46 | 46 | no |
| Wall graphics | (PWallSlices) | 2340 | 2340 | 3120 | 3120 | no |
| Zone 0 (GBVM) | 2048 (Word cells $4900..$4CFF) | 2048 ($4B00..$4EFF) | 2048 | **1024 Byte cells** | 2048 | yes, in SAVGAM |
| Zone 1 | 2048 ($6B00..$6EFF) | 2048 ($7C00..$7FFF) | 2048 | none | 2048 | yes |
| Zone 2 | 1024 ($9700..$98FF) | 1024 ($7A00..$7BFF) | 1024 | none | 1024 | yes |
| Script (zone 3) | $9900..$BFFF; 7680 bytes saved | $8000..$BFFF; 7680 saved | $8000..$BFFF; not saved | $8000..$9DFF; not saved | $8000..; not saved | PoR and Curse only |
| Map state (x, y, facing, wallAhead, event) | 5 separate globals | 5 (TPartyPosition) | 5 | 5 (TMapState) | 5 (TMapState) | yes |

Layout differences that affect save files:
- **Character record.** Each game's SSI layout must stay byte-exact.

  | | PoR | Curse | Secret | Champions | Pools |
  |---|---|---|---|---|---|
  | memorized spells | 21 | 21 | SPELL_SLOT_LAST+1 | 58 | 141 |
  | known spells | 56 | 100 | 117 | 107 | 126 |
  | class levels | 8 | 8 + 8 old | 7 + 7 | 8 + 8 | 7 + 7 old + 7 peak |
  | coins | 7 Words | 7 | 7 | 7 | 3 Words |
  | spell slots | 2x3 | 3x5 | 4x7 | 4x5 | 3x9 |

  Fields only some games have:
  - Strength split into current/base pairs (TStatPair) from Curse on.
  - Krynn's knightOrder, deity, robeOrder and levelBucket.
  - Pools' poisonCount, oldExperience, oldHpMax, levelCapped and immunities.
  - Secret, Champions and Pools: magicResistance, also called spellResistance.
- **Item.** Secret's record is 67 bytes and is written as `SizeOf(TItemRec)`. Pools reads Secret's items when it
  imports them. Verify that SSI's `.stf` items really are 67 bytes before a shared Types assumes 63 everywhere.
- **Pointers in saved records.** Every game saves records that hold far pointers:
  - character: effects, items, 13 equipped, next and combat (17 pointers);
  - item: next (Secret also bundleNext);
  - effect: next.

  The DOS builds clear them before saving (PoR fixed a bug here: `equipped[]` used to be saved as heap pointers).
  A native build must pack them (DiskRec).
- **PoR's `portExt`**, the port's own fields after the saved bytes, kept in a `.chx` sidecar, is the pattern every
  game needs once dual-classing and similar features reach it. Curse is receiving these now.

Overlays in Types: PoR keeps view records (variant `case` arms with pads) sized by `PTR_GROWTH`, so the ECL's raw
character window and the attack-phase view stay right natively. Secret's TCharRecord and TItemRec use many such
variant views named by offset (`chaCurLead: array[$000..$01A]` and so on), a byte-match residue that a shared Types
should replace with named fields.

---

## 4. ECL VM (EclVm, EclMenu, EclVars, EclTrace, EvtKind, C_Ecl, C_Gbvm)

### 4.1 Units

| Unit | PoR | Curse | Secret | Pools | Champions | Note |
|---|---|---|---|---|---|---|
| EclVm (lines) | 1899 | 2122 | 2349 | 1864 | 2285 | handlers, dispatcher, GameLoop |
| EclMenu | 656 | 652 | 592 | 1100 | 1295 | Pools and Champions keep the variable layer here (no EclVars) |
| EclVars | 622 | 687 | 747 | none | none | operand decoding and the GBVM address map; PoR's split, followed by Curse and Secret |
| EclTrace | 84 | 99 | 121 | none | none | OpName (Curse's spellings, "SUBTRAT") |
| EvtKind | 560 | 583 | none | none | none | Companion: event-square classifier walking scripts with SkipEclCmd |
| C_Ecl | 88 | 135 | none (literals) | 51 + EclVm-local constants | none (literals) | opcode numbers |
| C_Gbvm | 281 | 208 | in Types | none | 29 (zone bases only) | addresses |

### 4.2 Opcodes

| Op | PoR | Curse | Secret | Champions | Pools |
|---|---|---|---|---|---|
| $00..$1C | common | common | common | common | common |
| $1D | PARTY_STR | = | = | = | **WAIT_KEY** (EclContinuePrompt) |
| $1E | CHECK_PARTY | = | = | = | = |
| $1F | unused | unused | unused | unused | **JOURNAL_ENTRY** |
| $20, $21 | NEWECL, LOADFILES | = | = | = | = |
| $22 | PARTY_SURPRISE | = | = | = | **YES_NO** |
| $23 | SURPRISE | = | = | = | **REDRAW_EXIT** |
| $24..$2B | common | = | = | = | = |
| $2C | PARLAY | = | = | = | **PLAY_SOUND** |
| $2D..$30 | CALL, DAMAGE, AND, OR | = | = | = | = |
| $31 | SPRITE_OFF | = | = | = | **HMENU(True)** |
| $32..$36 | common | = | = | = | = |
| $37 | LOADPIECES (= LOADFILES) | = | = | = | **FIND_NPC** |
| $38..$3B | common | = | = | = | = |
| $3C | PROTECTION | = | = | = | **STORE** (EclShop) |
| $3D | CLEAR_BOX | = | = | = | = |
| $3E | none | DUMP | DUMP | DUMP | REMOVE_CHARACTER (EclDump) |
| $3F | none | FIND_SPECIAL | = | = | HAS_EFFECT (EclFindSpecial) |
| $40 | none | DESTROY_ITEMS | = | = | TAKE_ITEMS (EclDestroyItems) |
| $41 | none | none | AWARD_EXPERIENCE | = | = |

Every port now steps over an unknown opcode instead of hanging (SkipEclCmd, or Champions' `Inc(eclIp)`): a shared fix
already made five times. SkipEclCmd's operand counts per opcode are game data and follow this table.

### 4.3 Routines

The full table is in `engtools/ecl.txt` (151 routines). The cells below are shape % against the PoR copy, or against
the first game that has the routine.

- **Identical but for names (>= 95% in every game that has it):**
  - EclGoto, EclGosubCmd, EclSave, EclSaveTable, EclGetTable, EclAndOr, EclDelay.
  - EclCompareInt, EclCompareStr, EclMoveForward, MaxMonsterDist.
  - DecodeGameCharacter, CombineBytesToWord, ConvGbString, FindCurCharIdx.
  - EclDump, EclParlay, EclSurprise.
  - LoadEclVars: 89-97%, and the difference is the Pools field path.
- **Same logic, game data or branches (75-94%):**
  - EclApproach, EclRandom, EclReturn, EclFindItem, EclRob, EclDamage, EclPrint, EclOnGoto, EclAddNpc,
    EclSetupMonster, EclLoadCharacter.
  - EclVMenu, EclHMenu, InitCreature, EclInflictDamage, RobMoney, RobItems.
  - EclFindSpecial, EclDestroyItems, EclAwardExperience.

  What varies is GBVM addresses, message strings, menu colours, and Pools' width-aware memory access. All of it can be
  absorbed by per-game constants (C_Gbvm, GDConsts strings), with one hook in the Pools memory case.
- **Diverged (data-heavy or feature):**
  - **EclCall** (46-60%): a `case` on magic service addresses that differ per game (Curse $AE11, Secret $ADCC, ...),
    each calling game services. Make it a per-game unit. The service bodies are partly shared (view refresh,
    CharFightsAlone).
  - **ReadGbvm, WriteGbvm, SpecialReadZ1, SpecialWriteZ1, GbvmZone, SkipEclCmd, WriteGbvmString, DerefGbString**
    (18-70%): the address map, which is game data. PoR, Curse, Secret and Champions share the structure: zone
    dispatch, special cells in zone 4, and the character window in zone 1 as a `case` on fields. Pools is a different
    memory model.
  - **GameLoop and PlayArea** (12-66%): the exploration loop. Curse and Secret moved it into PlayArea, and each game
    adds its own idle handling (mouse, map pane, demo mode).
  - **EclEncounter** (2% in Pools), **EclTreasure** (31% in Pools), **EclPicture** (18% in Pools): Pools rewrote
    them.
  - **EclProtection**: copy protection (codewheel or manual). Per game, and largely removed or bypassed in the ports.
  - **EclCombat, EclNewEcl, NewEclDone, EclInit, LoadEclScript, EclExit** (42-68%): the same skeleton with
    game-specific area, music and picture handling. Shared candidates once there are hooks for "on area load" and "on
    combat start".
  - **Pools-only:** EclJournalEntry, EclYesNo, EclContinuePrompt, EclPlaySound, EclShop, EclFindNpc, EclRedrawExit,
    EclBuildRandomScroll, UpdateEclDisplay.
  - **PoR-only:** EvtKind (Curse has it too), PartyEffectsTable, ZoneLast, GetCell, PutCell, Reloading.
- **Overlay preloading:** Curse and Champions have `Prime*` routines, empty procedures called to pull overlays in
  ahead of time (34 units in Curse, 65 declarations in Champions). That is per-game working-set tuning. Secret and PoR
  do without.

### 4.4 Proposal for the ECL

- **Shared `EclCore`:** operand decoding (LoadEclVars, ConvGbString, DecodeGameCharacter, CombineBytesToWord,
  GetEclVar, DerefGbString minus the zone test), the comparison flags, the GOSUB stack, CallEclScript and the ~40
  shared handlers.
- **Per-game `EclMap` unit (same name in every game):**
  - GbvmZone, ReadGbvm, WriteGbvm, SpecialReadZ1, SpecialWriteZ1, WriteGbvmString.
  - SkipEclCmd's operand table.
  - EclCall's service map.
  - The dispatcher (DispatchEclCommand), as a `case` per game. A `case` costs no data segment. A procedure-variable
    table would cost 4 bytes x 66 in DGROUP.
- **Per-game handler units** for Pools' new opcodes and for any handler whose game branch is a feature, not data.
- **Opcode numbers in each game's C_Ecl.** The shared handlers never name an opcode number except through C_Ecl.
  EclIf and EclOnGoto read `curOpcode` against C_Ecl.IF_EQ and the others, so Pools' numbering, which keeps $16..$1B,
  still works.
- **Pools' byte-width memory** goes behind ReadGbvm(addr, width) everywhere. The Word-cell games pass width 2. The
  signature then is the same in every game, and the shared handlers call it uniformly.

---

## 5. Data loading (DaxIo, DataArc, DataBld, DataChk, DataPat, DiskRec)

Full table: `engtools/data.txt` (182 routines).

| Unit | PoR | Curse | Secret | Pools | Champions | Classification |
|---|---|---|---|---|---|---|
| DaxIo | 649 | 795 | 801 | 588 | 720 | **Shared core:** DaxHeaderFits, DaxEntryFits, DaxBlockFits, CloseDax, WriteString, WriteBlock, RemapId, Remapped, ResetArchiveCache, TrustFamily, SourcesMatch, FamilyUsable (90-100%). **Diverged:** DecompressDax (Curse decodes from a buffer, the rest from the file); OpenWithRetry and the disk prompts (37-52%: PoR rewrote them for native folders with ArchiveName, DataDrive, FolderOf, AskForDisk and WaitForFile; Secret and Champions show the path with PathTail); LoadDax (58-69%: merged archives in all but Pools, Pools' UseFixedCopy). **Game data:** archive names, prompts, disk counts. |
| DataArc | 201 | 215 | 214 | none | 232 | Identical but for data (ArchiveIntact, HasBlock, MatchFamily, MergedName, SourceName, FileLength: 82-100%). |
| DataBld | 1188 | 1145 | 1142 | 934 | 1168 | PoR, Curse, Secret and Champions are one design, mostly at 95-100%. Curse's is the newest (AddSpareBlock extracted; SplitBlock is PoR's same logic inlined). BuildDataFiles (50%) is the per-game driver (families, messages). **Pools diverged:** a fixed copy per family, `.FIX`; BuildCopy, CheckCopy, ReadDirectory, WriteCopy, PatchBlocks, SameAt. |
| DataChk | folded into DataBld | 1 unit | 1 unit | in DataBld | 1 unit | CRC stamps: identical (AddCrc, ApplyFix, ArchiveSound, ReadStamps, WriteStamps, SourcesCurrent: 87-100%). |
| DataPat | 1069 | 1249 | 84 | 526 | 47 | **Pure game data:** each game's table of data fixes. PoR uses FillBytes and FillParts code (7,460 tokens), Curse typed constants, Pools BytesAt and PartsAt "kept in code" to free the data segment. One shared *format* (code-held rows, as in PoR and Pools), with per-game content. |
| DiskRec | 262 | none | none | none | none | PoR's native record codec. Game-neutral given unified field names. |
| C_Data | 14 families, version 40 | 14, 6 disks, v47 | 12, 5 disks, v4 | 7, `.FIX`, v8 | 14, 3 disks, v1 | Per-game data. |

Proposal:
- **Shared:** DataArc, DataChk, DataBld's engine, the DaxIo core, DecompressDax (one form, the buffer one, with the
  bounds hardening every port already has) and DiskRec.
- **Per game:** C_Data, DataPat's rows, BuildDataFiles' family list and messages, and the disk-prompt strings.
- **Pools** either moves to the merged-archive design (a behaviour change: its own issue) or keeps DataBld and DaxIo
  as overriding units. The archive format (DAX directory entries of 9 bytes, RLE) is common to all five.

---

## 6. Saving and loading (SaveLoad, SaveMenu, FileUtil, SaveJrn, formats)

### 6.1 Files per game (SSI's files keep SSI's names and layouts; everything else is the ports' own sidecars)

| File | PoR | Curse | Secret | Pools | Champions |
|---|---|---|---|---|---|
| saved game | SAVGAMx.DAT (13,137 bytes) | SAVGAMx.DAT | SAVGAMx.DAT | **savgamx.PTY** | SAVGAMx.DAT |
| roster character / save member | .cha / CHRDATxN.sav | .guy / .sav | .who / .sav | .pc / .sav | .who / .sav |
| items | .itm | .swg | .stf | .thg | .stf |
| effects | .spc | .fx | .sfx | .efx | .sfx |
| usual spells (port) | .mem | .mem | .mem | .mem | .mem |
| statistics (port) | .sts | .sts | .sts | .sts | none |
| slot description (port) | savgamx.inf | .inf | .inf | .inf | none |
| explored map / notes (port) | .map / **.nts** | .map / **.nte** | none | none | none |
| character extension (port) | .chx | none | none | none | none |
| vault (port) | vault<x>.dat, tmpvault.dat | none | vault (PutVaultInPlace) | vault<x>.dat, tmpvault.dat | none |
| atomic-save mechanism | FileUtil sets: name with last char '$' (temporary) or '%' (backup) | SaveJrn: savjrn<x>.j0..j4 + `$`/`%` | SaveJrn | SaveJrn | none (writes in place) |
| bestiary, config | BESTIARY.DAT, POOLOPT.CFG | CURSEOPT.CFG, CURSE.CFG | BLADEOPT.CFG, blades.cfg | in Options | KRYNN.CFG |

The map-notes extension differs between the two ports that have it (`.nts` in PoR, `.nte` in Curse). Pick one for
writing and read both: existing players' saves must keep loading.

### 6.2 SAVGAM layout

Every game writes, in order:
1. disk number
2. zones
3. script (PoR and Curse only)
4. map position (5 bytes)
5. previous and current interface state
6. wall-set slots (3 id/slot pairs; Pools 1)
7. member count
8. 8 member names as String[40]

| Game | Disk | Zones | Script | Map position | Interface | Wall slots | Count + names |
|---|---|---|---|---|---|---|---|
| PoR | 1 | 0,1,2 (2048+2048+1024) | 7680 | gMapX..eventAtCell + gLocType + ifcState | | (none) | 1 + 328 |
| Curse | diskIndex | 0,1,2 | 7680 | partyPos (5) | prevIfcState, ifcState | 3 pairs | 1 + 8x41 |
| Secret | diskNum | 0,1,2 | none | partyPos | savedInterface, interfaceState | 3 pairs | 1 + 8x41 |
| Champions | currentDisk | 0,1,2 | none | mapState | previousLocationType, interfaceState | 3 pairs | count + names |
| Pools | none | bank 0 only (1024) | none | mapState | saved + current | 1 (id, slot) | count + names |

**Shared writer and reader:** each game's layer supplies a block list (address, size) built at init. The shared
LoadSlot and SaveToSlot then read the whole file into a buffer, check it against SaveMinSize (which becomes the sum of
the list) and copy the blocks out. Curse, Secret and Pools already read the whole file before using any of it, and PoR
checks a minimum size. The block lists are game data and keep each SSI layout byte-exact.

### 6.3 Routines

Full table: `engtools/save.txt` (79 routines).

- **Shared (>= 85%):**
  - AddCharToParty, LoadCharIconAnim, MergeIcon.
  - SaveMenu's whole UI: AskDescription, ChooseSlot, DrawList, DrawDescLine, MoveTo, ReadSlot, ReadSlotInfo,
    WriteSlotInfo, SlotFile. These are 87-96% in PoR, Curse and Secret; Pools is at 61-94 and adds DrawMore.
  - SaveJrn: NextStep, ApplyStep, Run, InPlace, JournalName (100% across Curse, Secret and Pools).
  - JournalStep, PutSaveInPlace, RecoverSaves, ObserveSlot, SavedFileSize, DeleteTempCopies.
- **Same logic, per-game data:** CharFileName, DeleteCharacterFiles, QuickSave, QuickLoad, LoadGame and SaveGame. The
  differences are file extensions and slot letters, plus the vault and transfer modes in Pools.
- **Diverged and game-specific:**
  - **LoadChar** (12-54%): reading a character of this game's format and importing the previous game's.
    - PoR has no import.
    - Curse imports PoR's 285 and Hillsfar's .hil.
    - Secret imports Curse's 422, field by field at fixed offsets.
    - Pools imports Secret's 439 and drops legacy NPCs.
    - Champions has no import.
  - **SaveChar** (20-32%) writes the game's files.
  - **LoadCharList** (29-35%): the roster scan by extension.
  - **SaveToSlot / LoadSlot**: see 6.2.
  - **LoadCreatureData**: PoR moved it to EclMenu; Pools and Champions keep it in SaveLoad.
- **Two atomic-save implementations** (FileUtil sets in PoR; SaveJrn in Curse, Secret and Pools). Choose one:
  - SaveJrn is pure decision logic, already tested and shared verbatim three times.
  - FileUtil's set API (NewSet, AddToSet, WriteToSet, CommitSet, RecoverSet) is the more general one: any group of
    files, used for character files and the vault too.

  The recommendation is FileUtil's API as the front, with SaveJrn's explicit phase journal as its engine. That lifts
  the 44-file index from DaxIo.SaveFileName (Curse/Secret) and SaveJrn.FileName (Pools) into a per-game file-name
  table. Recovery must read both the old PoR marks and the journals for one release.

Proposal:
- **Shared:** FileUtil + SaveJrn (merged), SaveMenu, the SAVGAM block reader and writer, the party add and remove and
  free routines, LoadCharIconAnim and MergeIcon, the save sidecar code (Stats' .sts, UsualSpl's .mem, .inf), and
  DiskRec.
- **Per game:**
  - Types.
  - The block list.
  - A TSaveNames table: extensions, slot letters (A..J, Q quick, Z transfer in Pools), file count.
  - LoadChar's format reader.
  - Import converters. In one repository these can all live in one `CharConv` unit:
    PoR285 -> Curse422 -> Secret439 -> Pools510, Hillsfar -> Curse, each keyed by file size as today.

---

## 7. Startup (FixMain, GameBoot, GameInit, HeapErr, overlays)

| Unit | Shared | Per game |
|---|---|---|
| FixMain | The main loop's shape (InitializeGame, recover saves, title, menu loop, GameLoop, ResetGameState) is common. | The uses list (initialization order) and the `{$O Unit}` list: residency is a per-game memory decision. The title, demo mode (Pools) and Champions' ShowVersion also differ. **FixMain stays per game.** |
| GameBoot | OvrInit, OvrInitEMS, OvrSetBuf, the OvrReadBuf wrap (CountOvrRead or OverlayReadWithBeep), ShowMemory (84-91%), ReadDigit. | OVERLAY_BUF_BYTES: PoR 100,352; Curse, Secret and Champions 163,840; Pools 143,360. PoR's NativeFolders, ReadConfig and RunSetup (the native and config front end); NormalizePath (diverged, 6-9%); the config file names. |
| GameInit | ResetGameState's skeleton (38-45%: it clears per-game state lists). | InitializeGame (45-71%): the allocation list, data loads and dispatch tables. InitEffectHandlers and InitSpellFns are per-game tables (spell and effect ids), which PoR and Curse keep here so the code stays out of the overlays (PoR's refactor-plan decision). |
| HeapErr | KeepReserve (90-100%) and HeapErrorHandler (77-87%: an "Insufficient memory" fallback when no game is in progress, and the save call's signature). | Message colours. The save hook: `SaveLoad.SaveGame` versus `SaveGame(True, False)` plus `justSaved`. Make the save a procedure variable set by the game, which also breaks the HeapErr -> SaveLoad dependency. |

Constraints for a shared startup:
- Overlay residency is decided per game in FixMain, so shared units must all carry `{$O+,F+}` and be safe whichever
  way they land.
- Initialization order follows FixMain's uses list. The shared units with `initialization` code (GDVars' clear in
  Pools, HeapErr's hook, GameBoot's overlay start, DiskRec's FindPointers natively) must not depend on game units
  initialising first.
- Heap: data segment use at HEAD (from each repo's docs):

  | | PoR | Curse | Secret | Pools |
  |---|---|---|---|---|
  | used / free (bytes) | 35,892 / 29,628 | 43,298 / 22,222 | 43,660 / 21,860 | 48,602 / 16,918 |

  A shared core adds no data segment if variables keep one home, a unified GDVars. Each procedure-variable hook costs
  4 bytes.

---

## 8. GameIo, GameTime, Clock, Dice, TpRand

| Unit | Shared (>= 90% shape) | Same logic, game data | Diverged / game feature |
|---|---|---|---|
| GameIo (220 / 287 / 353 / 373 / 304 lines) | FatalError (85-89%), SetSound (81-92%), FlushKeys, OverlayReadWithBeep | DiscardPendingKeys and ExitGame (44-58%: names and exit codes) | ReadGameKey (41-72%): Secret, Pools and Champions translate the joystick and mouse (TranslateJoystick, TranslateMouse, InputPending); PoR and Curse are keyboard only. PoR's DumpEffects versus the others' DumpSpells. Pools' AllocSlot, FreeSlot and ZeroFill (the heap work-slot pool). |
| GameTime | AdvanceSpellPrep, AdvanceSpellPrepBase, DecrementRestTime, DisplayRestTime, CheckRestingHeal, CheckMemorizedOne (89-100%) | CampRest and CampRestMenu (70-94%: Curse on adds an `interactive` parameter for the Fix rest; strings; addresses) | CheckScribeDone (Secret 51%: scribing reworked); Champions' ClockDisplay. |
| Clock (PoR, Curse, Secret) / in GameTime (Pools, Champions) | AdvanceTime, AgeParty, SetFromMinutes, TimeOutEffects (85-100%) | ValidateClock (73-81%) | PoR moved AdvanceTime and TimeOutEffects to FxEngine for the overlay working set. Which unit holds them is a per-game residency choice, so the shared unit should be small and resident (PoR's Clock). |
| Dice | RollDice (100% in PoR, Secret and Pools; 94% in Curse, a parameter name) | RollDamageDice: PoR stores the dice count only; Curse, Secret and Pools also count dice rolling >= 2 (`damageDiceOver1`), and Pools returns Word | PoR's ReduceDamagePerDie. Champions has no Dice unit (RollDice lives in FxEngine). |
| TpRand | PoR only: Turbo Pascal's LCG for the native build, so `STING NORAND` replays match | none | Shared verbatim: it is game-neutral. |

The superset RollDamageDice (counting the over-1 dice) is harmless for PoR: one extra global it never reads.
ReduceDamagePerDie can sit beside it.

---

## 9. Proposal: the shared core and the per-game layer

### 9.1 Mechanism: same-named units chosen by the unit search path

Turbo Pascal 5.5 and 6 resolve `uses Types` through `/U` in order, and FPC through `-Fu`. Each game build puts its
own directory first:

```
/U..\GAME\SRC;..\GAME\SRC\INCLUDES;..\CORE\SRC;..\CORE\SRC\INCLUDES
```

- **Per-game units, same name in every game:** Types, GDVars, GDConsts, C_Gbvm, C_Ecl, C_Data, C_Level, C_Class and
  the other C_ units, DataPat, EclMap, CharConv's game half, GameInit, FixMain.
- **Core units** are written against those names and compiled once per game. This is compile-time polymorphism: no
  `{$IFDEF}`, no procedure-variable cost, and no change to any record's bytes.
- **Override:** a game can shadow any core unit by putting a same-named unit in its own directory. This is the escape
  hatch for real divergence (Pools' EclVars memory model, Pools' DataBld) and the way to adopt the core one unit at a
  time.
- **8.3 names hold.** All of these unit names already fit.

The core cannot simply be a superset record shared by all games: the save formats differ and the ECL's character
window is a raw view of each game's layout. Instead, the per-game Types gives every shared field the same name and
the same meaning, and its array bounds come from per-game constants.

The constants are where Brian's "tables up to Pools" fit. The rule tables that run to Pools' limits (another area's
report) take their bounds from `C_Level.LEVEL_MAX`, `C_Spell.KNOWN_LAST` and so on, and each game's Types sizes its
saved arrays from its own SSI values. A level cap above what a record can store is a per-game check, not a layout
change.

### 9.2 What goes where

| Layer | Units | Notes |
|---|---|---|
| **Core, game-neutral** (verbatim now, after renames) | TpRand, StrUtil, FileUtil+SaveJrn, DiskRec, DataArc, DataChk, DataBld engine, DaxIo core, Dice, HeapErr (with a save hook), Clock, the GameTime rest core, SaveMenu, EclTrace (names from C_Ecl), EvtKind (opcode-dependent: it uses SkipEclCmd), TestKit | DiskRec needs only `*_DISK_BYTES` and field names. |
| **Core, parameterised by per-game constants** | EclCore (operand decoding, flags, the GOSUB stack, about 40 handlers), the SAVGAM block reader and writer, party add and remove, LoadCharIconAnim, GameBoot's overlay start (buffer size from a per-game constant) | Absorbs the 75-94% band: addresses, strings, colours. |
| **Per game** | Types, GDVars, GDConsts, the C_ includes, EclMap (address map, dispatcher, SkipEclCmd table, EclCall), DataPat rows, C_Data, the SAVGAM block list and TSaveNames, the LoadChar and SaveChar format code, CharConv, GameInit (allocation and dispatch tables), FixMain (uses order, overlay list, main loop), the Prime* chains if kept | All of it is data or a feature. |
| **Per game for now, shareable later** | GameLoop and PlayArea, EclEncounter, EclTreasure, EclPicture, EclCombat, EclNewEcl, GameIo input (mouse and joystick from Secret, Pools and Champions), Pools' new opcodes | They need hooks (on area load, on combat start, idle) before they can be shared. |

### 9.3 Hooks needed (procedure variables, 4 DGROUP bytes each, `{$F+}`)

- `HeapErr.SaveHook`: the game's save routine.
- `EclCore.OnAreaLoad` and `OnCombatStart`: picture, music and map-pane handling.
- `GameIo.InputDevices`: mouse and joystick translation.
- `SaveCore.ImportChar`: the previous game's formats.

Fewer than ten in all. Where the choice is fixed per build, prefer the per-game unit to a hook: it costs no data
segment.

### 9.4 Order of work

1. **Leaf units first:** TpRand, StrUtil, FileUtil+SaveJrn, DataArc, DataChk and DataBld, the DaxIo core, Dice and
   HeapErr. Pick the newest copy, mostly Curse's or PoR's, and point the other ports at it. These need few renames.
2. **One rename pass per port** for the engine's shared state (GDVars core names) and the record field names in
   Types. This is the expensive step. Do it after Curse's in-flight migration lands, and let it ride on each port's
   normal "rename when touching" rule.
3. **DiskRec into every port.** Character, item and effect writes go through it. No bytes change under TP.
4. **The SAVGAM block list and SaveMenu.**
5. **EclCore and the per-game EclMap.**
6. **Pools' overrides last.**

---

## 10. Risks

- **Save formats.**
  - Every SSI record stays byte-exact per game. The core must never use a literal size: SizeOf of the game's type, or
    `*_DISK_BYTES`.
  - The TP build and the native build must write identical files. That is DiskRec's job, and PoR's TRecLay and
    TSaveLay tests pin it; carry them to every game.
  - Sidecar formats (.sts, .mem, .inf, .map, .nts/.nte, .chx) are the ports' own. A shared writer must keep reading
    every older version (PoR, Curse and Secret each extended theirs).
  - The `.nts`/`.nte` and FileUtil-mark/SaveJrn differences need dual-read migrations.
- **The ECL character window.** GBVM zone 1 is a raw view of TCharRecord in PoR, Curse, Secret and Champions, and
  $0401..$0800 in Pools. Scripts depend on each game's offsets, so the address map must stay per game. If a field is
  ever moved out of the saved part of a record (into portExt), its window arm has to follow it.
- **Secret's 67-byte item.** Confirm against SSI's files before relying on it.
- **DOS memory.**
  - Moving code into a shared unit changes neither residency nor size, but each game's FixMain must keep its
    `{$O}` list and order, and initialization order follows the uses list.
  - Combat and explore overlay working sets are tight (PoR measured them with STING Ctrl-Y).
  - A shared unit that pulls in more callees than a game's copy did grows that game's working set. Measure per game.
  - Data segment: typed-constant tables in shared units cost every game. Keep per-game tables in code (Pools' DataPat
    rows) or on the heap (Pools' work slots and strings, Secret's #409).
  - Stack: 16 KB with `{$S-}`, and an overflow is silent.
- **Compilers.**
  - The core must build on TP 5.5 (Secret HEAD), on TP 6 (the rest) and on FPC `-Mtp`, and on TP 5.0 if Curse
    v1.0/1.1 ever builds from it, which it should not: old versions stay frozen trees.
  - No `asm` and no `Break`/`Continue`.
  - `{$IFDEF FPC}` already appears in PoR's units, and TP 5.5 accepts it.
- **Coordination.** Curse is mid-migration from PoR, and Champions lacks most of the refactored units. Sharing too
  early forks the shared copy. Gate on Curse finishing.

---

## 11. Shareable PoR-only and partly-ported features in this area

- **DiskRec and TpRand** (native layer): game-neutral, every port.
- **`portExt` and `.chx`** (port fields after a character's saved bytes): every port, once dual-class and similar
  features arrive.
- **EvtKind** (the Companion's event classifier): Curse has it. It needs a per-game opcode table for Pools.
- **Explored and MapNotes sidecars:** PoR and Curse only, under two extensions.
- **The vault** (vault<x>.dat with saves): PoR and Pools, partly Secret.
- **The bestiary** (BESTIARY.DAT): PoR only.
- **The ECL trace log** (EclTrace, Ctrl-L): PoR, Curse and Secret.
