# Shared rules: definitions, tables and constants across the five ports

Area: rules. Read at origin/main of pool-of-radiance (PoR), curse-of-the-azure-bonds (Curse),
secret-of-the-silver-blades (Secret), pools-of-darkness (Pools) and champions-of-krynn (CoK), 2026-10-25. Analysis only;
nothing was changed. Working copies, extraction scripts and raw diffs are in
`/tmp/claude-1000/-home-brian-repos-pool-of-radiance/76f98367-99ca-4028-b60d-7be679625eb9/scratchpad/rules/`
(`out/spcmp.txt` is the full per-spell field diff, `out/eff_*` the effect-id dumps).

## Headlines

1. **The four Forgotten Realms ports run one rule set.** Wherever their tables overlap, PoR, Curse, Secret and Pools
   agree on about 95% of the values: racial ability limits, racial ability adjustments, age categories, class ability
   minimums, prime requisites, dual-class thresholds (15/17), Constitution hit-point bonus (3..25, identical in all
   five), Strength/Dexterity adjustments (identical code in all five), saving throws, experience thresholds, spell slots
   and the turning table. The tables differ mainly in **range** (PoR stops at level 9, Curse at 12, Secret at 18, Pools at
   21/29/40) and in **encoding** (absolute vs per-level deltas, 0 vs 3 for "minimum 3", 0 vs 40 for "unlimited").
   That makes Brian's plan workable: one table set to Pools' range, with each game clamping.
2. **Pools' tables are the right base, but not as they are.** They cover the range, but they hold 8 data errors
   (two of them change play in Pools now) and use the 1st-edition DMG THAC0 matrix while PoR, Curse and Secret use a
   2nd-edition-style per-level progression. **THAC0 is the one real rules fork**, and it needs Brian's ruling
   (below, R1).
3. **Ids are the blocker, not values.** The race numbering has three schemes (PoR/Curse, Secret, Pools), plus CoK's
   own races. The spell-list (castClass) enum has three. Item type ids have three numberings. Effect ids have two
   families that split from id 3 onward. The class enum (0..16) and the ability, save and status enums are the same
   everywhere. Spell ids 1..100 are one id space apart from three slots (36, 56, 90). A shared rules unit has to work
   in a canonical id space and map each game's race, list, item and effect ids at the edge. It cannot renumber them,
   because save files, ECL scripts and the shipped data files store them.
4. **CoK is a different rule set on the same skeleton.** It has Dragonlance races, the knight, Krynn experience tables
   (10 progressions indexed by order/robe, not by class slot), its own alignment bitmask and hit dice. It can share the
   routines and the table *types*, but only a few tables: THAC0, saves, the Dexterity and Constitution tables, the
   Strength and Dexterity code, and the cleric turning rows 1..10.

Counts:
- About 40 rule tables or table-like routines were compared across the five ports.
- 31 value disagreements are listed in §6. 14 are errors against 1st edition, and 6 of those are live in a shipped
  port today. 9 are rule forks that need a ruling. 8 sit in unreachable rows or unused classes.
- 4 id enumerations need a mapping (race, castClass, item type, effect), and 3 spell-id slots collide.
- About 45 pairs of names mean the same thing under different names (§5).

## 1. Per-game ranges and limits (what the game layer must enforce)

| Limit | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| Classes offered | C F P R M T + multis | same | same | same | C F P R M T Knight + multis (Krynn) |
| Druid / monk | slots 1/7, never offered | slots 1/7, never offered | slot 1 unused, no monk | slot 1 unused, no monk | slot 1 unused, slot 7 = knight |
| Races offered | dwarf elf gnome half-elf halfling human (half-orc row exists, skipped) | same, half-orc row exists | elf half-elf dwarf gnome halfling human | same as Secret | Silvanesti, Qualinesti, half-elf, mountain dwarf, hill dwarf, kender, human |
| Class level max (human) | C6 F8 P7 R7 M6 T9 (`experienceSpellsClass` -1s, `C_LEVEL.LEVEL_LAST`=9) | C10 F12 P11 R11 M11 T12 (`classExperience` -1s) | C/F/P/R/M 15, T18 (`classProgression` -1s) | 40 all (`raceCaps` 40, `CanLevelUp` < 40, `XpForLevel` extrapolates past 11) | 8 (thief 9) (`classProgression` -1s) |
| Racial caps (demihuman, by Str/Int band) | `CharHlp.FIGHTER_CAP` table + `HalfOrcCap`; elf MU 11 above PoR's cap | `CharHlp.AtTrainingLevelLimit` case | `CharHlp.RaceLevelLimit` case (+ NPC cleric caps) | `GDConsts.raceCaps` + per-race case in `CharHlp.CanLevelUp` | none found (XP table caps everything) |
| Highest spell level | cleric 3, MU 3 (`Types.CASTER_LEVEL_LAST`) | 5 / 5 | 7 / 7 | 7 / 9 | 5 (slot table; `knownSpellTable` lists 4) |
| Spell ids | 1..56 (+57..67 item spells) | 1..100 | 1..117 | 1..126 | 1..107 |
| Table reach used | THAC0 0..10, saves 1..9, thief 1..9, slots 2..6 | 0..12, 1..12, 1..12, 2..12 | 0..18, 1..18, 1..18, 2..18 | 0..21, 1..21, 1..18, 1..29 | 0..12, 1..12, 1..12, 2..12 |
| Dex for thief adj. | 9..25 | 9..19 | 9..25 | 9..19 | 9..25 |
| Wis bonus spells | 13..25 table, 7 levels | hard-coded 13..18 | 13..25 table | hard-coded 13..18, Wis 17/18 gates for 6th/7th | 13..25 table, 5 levels |
| Turn undead | 10 undead x 10 columns | 10 x 10 | **none in the port** | 13 x 11 (column 0 added) | 12 x 13 (levels 1..13 direct) |
| Attacks | 3/2 only (F/P >6, R >7) | 3/2 only | 3/2 and 2/1 (F/P 13, R 15) | 3/2 and 2/1 | (not compared) |
| Fixed HP past name level | not needed (caps below it) | `constitutionBonusLevelCaps` | `firstFixedHpLevel` | `firstFixedHpLevel` + `+3/+2/+1` case in ViewChar | `hitDiceLimit` |

**Brian's target range** is Pools' maximum. Pools trains humans to 40 in every class. Its own tables cover THAC0
to 21, saves to 21, thief skills to 18, spell slots to 29 and explicit XP to 11, with XP to 40 extrapolated from
`xpIncrement`. A consolidated set therefore runs: XP 2..40, THAC0 0..40, saves 1..40, thief 1..40, slots 1..40. Each is
written out, or written to the last row that changes with a documented "clamp above" rule. Above level 21 (saves),
21 (THAC0), 18 (thief) and 29 (slots) the 1st-edition values stop changing, so clamping is exact rather than an
approximation.

## 2. Class, race and level tables

### 2.1 Experience thresholds

| | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| Record | `Types.TRuleXp` (xp[2..9] + absolute slots[2..9,1..3]) | `Types.TRuleXp` (thresholds[2..12] + **delta** slots[2..12,1..5]), the same name with a different shape | `TClassProgression` (nextLevelXp[2..18] + delta slots[2..18,1..7]) | `TClassLevelTable` (xp[2..11] + absolute spellSlots[1..29,1..9]) + `xpIncrement` | `TClassProgression` (nextLevelXp[2..12] + delta slots[2..12,1..5]), 10 rows indexed by order/robe |
| Where | `GameDefs.experienceSpellsClass` | `GDConsts.classExperience` | `GDConsts.classProgression` | `GDConsts.classLevelTable`, `ClassCal.XpForLevel` | `GDConsts.classProgression` |
| Agreement | all FR values agree where they overlap | | | except paladin L11 **1050000** and ranger L11 **650000** (others and PHB: 1050001, 650001); the error carries into every extrapolated level 12..40 | Krynn values, not comparable |

The PHB's per-level increments past name level are all reproduced by Pools' `xpIncrement`: cleric 225000, fighter
250000, paladin 350000, ranger 325000, magic-user 375000, thief 220000. Secret's written-out L12..18 match them, except
Secret paladin L15 **2460001** (should be 2450001; it is the last level Secret reaches). The druid's `xpIncrement`
750000 is unused.

Shared form: `xpBase[class, 2..11]` + `xpIncrement[class]`, Pools' formula, with the two off-by-one values fixed (or
the full table to 40, which is only 8x39x4 = 1.2 KB).

### 2.2 THAC0 (stored as 60 - THAC0)

| | PoR `GameDefs.thac0Tbl[0..7,0..10]` | Curse `classThac0[0..7,0..12]` | Secret `baseToHitTbl[0..6,0..18]` | Pools `thac0ByLevel[0..6,0..21]` | CoK `thac0Table[0..7,0..12]` |
|---|---|---|---|---|---|
| cleric/druid | DMG (20 x3, 18 x3 ...) | same | same | same, plus 19..21 = 9 (DMG) | same |
| fighter/paladin/ranger | **21 - level** (2e warrior) | 21 - level | 21 - level, to 3 at L18 | **DMG**: 20 at L1-2, 18 at L3-4 ... 4 at 17+ | 21 - level (knight too) |
| magic-user | **DMG** 20 L1-5, 19 L6-10 | **2e**: -1 every 3 levels | 2e | DMG 20/19/16/13/11 | 2e |
| thief | **DMG** 20 L1-4, 19 L5-8, 16 L9-12 | **2e**: -1 every 2 levels | 2e | DMG 20/19/16/14/12/10 | 2e |
| column 0 | 40 | 40 | 40 | fighter and MU **39** (unused: the code takes the best class) | 40 |

Curse, Secret and CoK say in their comments that they follow the 2nd-edition PHB. PoR is mixed: warriors are 2e,
while magic-users and thieves follow the DMG. Pools alone is the 1st-edition DMG matrix throughout. Under the memory
"Tabletop rules govern: 1st edition", **Pools' rows are the correct ones**. Adopting them makes fighters one point worse
at even levels in PoR, Curse and Secret, and magic-users and thieves better at some levels. This is ruling **R1**.

### 2.3 Saving throws

| | PoR `ClassCal.RecalcSaves.saveTbl[0..7,1..9]` | Curse `classSavingThrows[0..7,1..12]` | Secret `saveTbl[0..6,1..18]` | Pools `savingThrowTable[0..6,1..21]` | CoK `savingThrowTable[0..7,1..12]` |
|---|---|---|---|---|---|
| Agreement | all agree in the overlap with the DMG | monk rows 10..12 hold **magic-user** values (monk unused) | agrees | cleric **L19 = (4,7,8,10,9)**; DMG 19+ is (2,5,6,8,7); Pools gives it from L20. Druid flat from 16 (unused) | knight row = fighter |

Shared form: `saves[class, 1..21]` from Pools with the L19 cleric row fixed, clamped at 21. The 1st-edition bands end
at 21+ (magic-user, thief) or 17+/19+ (others).

### 2.4 Spell slots, Wisdom bonus, Intelligence limit

Expanded to absolute counts, every port's cleric, magic-user and paladin slots match the PHB in the overlap (checked
by script: `tools/xp.py`). Differences:
- **Ranger magic-user columns:** Curse and Secret keep the ranger's magic-user slots in columns 4..5 of the row, while
  Pools keeps them in columns 5..6 (`ClassCal.RecalcSpellSlots` / `RecalcSpellLists` map `j - 3` vs `j - 4`). The values
  agree; only the encoding differs.
- **Secret paladin L16..18** deltas give (3,2,1,2), (3,2,2,2), (3,2,2,3), where the PHB and Pools give (3,3,1,1),
  (3,3,2,1), (3,3,3,1). These levels are unreachable in Secret (paladin cap 15).
- **Cleric 7th-level slots** start at L16 in Secret and Pools alike (7,7,7,6,5,3,1). This is worth one check against
  PHB p.20, which may give the first 7th-level slot at L14. Not counted as a disagreement.
- **Wisdom bonus:**
  - PoR and Secret use `wisBonusSpells[13..25, 1..7]` (PHB to 18, D&DG 19..25).
  - CoK uses the same table cut to 5 levels.
  - Curse (`RecalcClericSlots`) and Pools hard-code 13..18 only, so Pools' Wis 19+ clerics get nothing more. That breaks
    the "abilities to 25" rule.
  - Pools and Secret clear 6th-level slots below Wis 17 and 7th-level slots below Wis 18 (PHB).
- **Intelligence spell-level cap** (PHB): Pools `TrimHighSpellSlots` covers 6th..9th (Int 12/14/16/18). Secret has the
  same for 6th/7th inside a routine **misnamed** `ClassCal.RecalcClericSlots` (its cleric routine is called
  `RecalcSpellSlots`, so the names are swapped). PoR and Curse need none.
- **Item $81 (ring of wizardry):** Curse doubles magic-user slots 1..3, while Secret and Pools double level 5 only. This
  is item data, so it stays per game (a parameter).

Shared form:
- `slots[caster, 1..29, 1..9]` as absolute rows (Pools), for cleric, magic-user, paladin (cleric list), ranger (druid
  1..3 + magic-user 1..2).
- Wisdom bonus 13..25 x 7, PoR's.
- Wisdom gates (17/18) and Intelligence gates (12/14/16/18) as small tables.
- The per-game max spell level clips the row.

### 2.5 Thief skills

| | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| Base by level | `thiefBase[1..9]` | `thiefSkillBase[1..12]` | `thiefBase[1..18]` | `thiefSkillsByLevel[1..18]` | `thiefSkillTable[1..12]` |
| Agreement | PHB | **read languages L11 60, L12 65** (PHB and Pools: 55, 60) | PHB | PHB | the same RL error as Curse |
| Race rows | by PoR race 1..7, human 0s | by PoR race 1..7, human 0s | by Secret race 1..6, human 0s | by Pools race 0..5: **human row holds the half-orc figures** (-5,+5,+5,0,0,+5,+5,-10). The comment admits it; Pools human thieves are affected **in play** | indexed by **CoK race** but holding PoR's order (dwarf, elf, gnome, half-elf, halfling, half-orc, human), so a kender thief gets the half-orc row and a hill dwarf the halfling row (probable SSI inheritance; verify against the disassembly) |
| Dex adj. | 9..25 (D&DG) | 9..19 | 9..25 | 9..19 | 9..25 |
| Armour bars | all 8 skills | (not compared) | (not compared) | skills 1..7 (read languages kept) | (not compared) |

Shared form: `thiefBase[1..18]` (Pools/Secret, clamp above 18), `thiefRaceAdj[canonical race]`, `thiefDexAdj[9..25]`.

### 2.6 Turning undead

PoR `ClassCal.TurnValue.turnTable[1..10,1..10]` and Curse `turnUndeadResults[1..10,1..10]` are identical: columns
1..8 by level, 9 = levels 9..13, 10 = 14+. Pools `turnUndeadTable[1..13,0..10]` has the same rows 1..10 and columns
1..10, plus column 0 (level 0, all 99) and undead rows 11..13. CoK `turnUndeadTable[1..12,1..13]` has columns for
levels 1..13 directly. It agrees with the DMG's 9..13 column for those levels but has no 14+ column, and its row 11
differs. **Secret has no turning at all** (only a `usedTurnUndead` field): a port gap, or an omission in the port.

Shared form: Pools' 13 x 0..10 table and PoR's `TurnValue` column map (one routine). CoK keeps its own table as data.

### 2.7 Hit dice, Constitution, hit points

| | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| Level-1 dice | `ClassCal.hpDice` (1,1,1,1,2,1,1,2) | `startingHitDice` same | `firstLevelDiceTbl` (no monk) | `firstLevelHitDice` | `hpDice` **(2,1,1,1,2,1,1,2)**: a cleric rolls 2d8 |
| Die sides | `GameDefs.hpSides` (8,8,10,10,8,4,6,4) | `startingHitDieSides` same (SSI read the monk's from the next byte) | `hitDieSidesTbl` | `hitDieSides` | `hpSides` (knight d10) |
| Last die level + 1 | n/a | `constitutionBonusLevelCaps` (10,15,10,10,11,12,11,19) | `firstFixedHpLevel` (10,15,10,10,11,12,11) | same + `+3/+2/+1` after (ViewChar) | `hitDiceLimit` (knight 10) |
| Con bonus 3..25 | local `conBonusTbl` in `ConHpPerDie` | `constitutionHitPointBonus` | `conBonusTbl` | `conBonusTable` | `conHpTable` |
| Warrior extra 17..25 | `ConHpPerDie` +1/+2/+3/+4/+5 | identical | identical | `CharHlp.ClassConAdj` identical | `ClassConHpBonus` |
| Roll rule | `HitDieFloor` by Con, level 1 at least 2/3 of a die | | `HitDieFloor` | **best of two rolls** per die (ViewChar) | `HitDieFloor` |

The values are identical across the FR games. The rolling rule differs: Pools' best-of-two is an SSI house rule,
while PoR has a Con floor and a 2/3 minimum at level 1. Classify this as a per-game rule hook, or rule on it.

### 2.8 Races

| Table | PoR | Curse | Secret | Pools | CoK | Agreement |
|---|---|---|---|---|---|---|
| Ability min/max | `GameDefs.minimumMaximumStatistics[1..7]` `TRuleRace` | `raceAbilityLimits[1..7]` `TRaceAbilityLimit` | `raceLimits[1..6]` `TRaceLimits` | `raceLimits[0..5]` | `raceLimits[0..6]` (Krynn) | FR identical, including the house rule "human women 18/00" |
| Ability adjustments | `CharGen.raceAbilityAdj` | `raceAbilityAdj[1..7]` | `[1..6]` | `[0..5]` | (not compared) | identical, PHB |
| Age categories | `CharGen.ageCat` | `ageThresholds` | `ageTbl` | `ageThresholds` | `ageLimit` | identical |
| Starting age | `ClassCal.ageDice[race,0..7]` | `startingAgeRolls[1..7,0..7]` | `startAgeTbl[1..6,0..6]` | `startAges[0..5,0..6]` | `startAge` (Krynn) | see §6 D19..D21 |
| Classes by race | `ClassCal.classesByRace` | `raceClassLimits` | `raceClassTbl` | `raceClasses` | `raceClass` | FR identical, same menu order |
| Level caps | `CharGen.raceMaxLevel` (display; 0 = U, -1 = barred) + `CharHlp.FIGHTER_CAP` | `raceMaxLevel` (same encoding) + `AtTrainingLevelLimit` | `RaceLevelLimit` | `raceCaps` (**0 = barred, 40 = U**: the opposite encoding) + `CanLevelUp` | none | FR values identical (PHB by Str/Int band); Secret adds dwarf cleric 8, elf cleric 7, gnome cleric 7 (NPC limits, unreachable); PoR adds half-orc caps (#956) |
| Dwarf/gnome foes | `EffHndlr.dwarfFoes[1..11]`, `gnomeFoes` | `GDConsts` [1..10], [1..5] | same as Curse | (none, by other means) | `dwarfFoes[1..5]` | names differ by game's monster names: per-game data |

### 2.9 Classes

| Table | Where | Agreement |
|---|---|---|
| Ability minimums | PoR `ClassCal.ClassAbilityMin.classMin` (single classes; multis by `classParts`), Curse `classAbilityMinimums[0..16]`, Secret `classMinTbl`, Pools `classMinStats`, CoK `classMin` | FR identical (PoR writes 3 where the others write 0 for "no minimum"); PoR adds the half-elf multi-cleric Wis 13. CoK paladin/knight rows are SSI's own (10,7,10,8,10,6) |
| Alignments | PoR `alignByClass`, Curse `classAlignments`, Pools `classAlignments`, Secret `classAlignTbl` (count in column 0), CoK `classAlignMask` (bitmask) | PoR = Curse = Pools; **Secret lets clerics and every cleric multi be any of 9** (no TN bar; cleric/thief 9 where the others have 6) |
| Prime requisites | `primeRequisites[0..7] = (4,36,1,5,7,2,8,13)` in PoR, Curse, Secret and Pools (four copies) | identical; CoK `(4,6,1,5,7,2,8,1)`: druid Int+Wis (PHB Wis+Cha), knight Str |
| Dual-class 15/17 | PoR `LEAVE_CLASS_SCORE`/`TAKE_CLASS_SCORE`; literal 15/17 elsewhere | identical |
| 10% XP bonus | PoR `PRIME_STAT_THRESHOLD` 15 (16+) | |
| `classParts[0..16,1..3]` | PoR `GameDefs.classParts`, Curse/Secret/Pools `GDConsts.classParts` | identical (Secret's monk row is -1s) |
| Usability bits | PoR `ClassCal.usabilityBit`, Curse `classItemMasks`, Secret `classMaskTbl`, Pools `classMaskBit`, CoK `classMaskTable` | FR identical ($02,$10,$08,$40,$40,$01,$04, monk $20); **CoK ($02,$20,$08,$40,$80,$01,$04,$10)** |
| Training / HP-roll class bits | PoR `GameDefs.classBit` (2,2,8,8,8,1,4,6: the training hall's bits), Curse `classBits[0..16]`, Secret `rollClassMaskTbl`, Pools `levelUpClassBit` ($02,$02,$08,$10,$20,$01,$04) | **different meanings**: PoR's is the GBVM training mask, the others' the level-up roll mask. Do not merge |
| Starting gold | PoR `CharGen.startingGoldClass`, Curse `characterCreationDice`, Secret `startingMoneyDice` (unused), Pools `startingGoldDice` (flat), CoK `startingMoneyDice` | identical, PHB |
| Attacks | inline in `RecalcBaseSkills` / `RecalcClassStats` | PoR and Curse have no 2/1 (irrelevant below 13); Secret and Pools have the PHB's 2/1 |

## 3. Ability adjustments (to 25)

PoR keeps them in `AbilAdj`; the others keep them in `CharHlp`, `FxEngine` and `ClassCal`. Function bodies were compared
after normalization.

| Routine | PoR | Curse | Secret | Pools | CoK | Status |
|---|---|---|---|---|---|---|
| `TranslatedStrength` | AbilAdj | CharHlp | CharHlp | CharHlp | CharHlp | identical; **CoK has no `else` for exceptional > 100 or Str > 25** (undefined result) |
| `StrToHitAdjust`, `StrDamageAdjust` | AbilAdj | CharHlp | CharHlp | CharHlp | CharHlp | identical (PHB + D&DG) |
| `WeightAllowance` | AbilAdj | CharHlp | CharHlp | CharHlp | CharHlp | identical, except **CoK gives Str 19 (24) 4000**; the others give D&DG's 4500 |
| `DexterityArmorAdjustment` | AbilAdj | CharHlp | CharHlp (1..3) | CharHlp | CharHlp (1..3) | identical apart from the Dex-0 edge |
| `DexMissileAdjust` | AbilAdj | CharHlp | CharHlp | CharHlp | CharHlp | identical |
| `ConHpPerDie` / `ClassConAdj` / `ClassConHpBonus` | ClassCal | CharHlp | CharHlp (+ `CharGen.ClassConAdj` wrapper) | CharHlp `ClassConAdj` | CharGen | identical |
| `HitDieFloor`, `ConRegenMinutes` | ClassCal, AbilAdj | n/a | CharHlp | n/a | FxEngine | identical where present |
| Con save bonus 19..25 | `AbilAdj.ConPoisonSave` | inline in `RecalcSaves` (+ dwarf/halfling scale inline) | inline | inline | | same values; Curse also applies the dwarf/halfling Con scale in `RecalcSaves` directly |
| `IntKnowSpellChance`, `WisSpellFailure` | AbilAdj | | | ClassCal (same body) | | identical |
| `ConResurrectionSurvival` | AbilAdj (formula to 25) | `resurrectionSurvival[3..18]` | same table | same | same | same values; PoR's formula extends to 25 |
| `ConSystemShock`, `ChaLoyaltyBase`, `StrengthModifier`, `StrengthEffectToStrength` | AbilAdj | FxEngine (the strength pair) | FxEngine | FxEngine | FxEngine | the strength pair is the same everywhere; system shock and loyalty are PoR-only |

**This is the easiest unit to share: one `AbilAdj` from PoR** (already to 25, D&DG above 18, with tests in TAbilAdj).
Each game passes a score instead of a creature, because the record layouts differ (§7).

## 4. Spells, items, effects: ids and records

### 4.1 Spell ids
One id space. Ids 1..56 are Pool of Radiance's in every game. Ids 57..100 are the same in Curse, Secret, Pools and CoK.
57..67 are the item spells; PoR has them at the same ids as `C_SPELL.ITEM_*`, and Pools names them. Collisions:

| id | PoR / Curse / CoK | Secret / Pools |
|---|---|---|
| 36 | Animate Dead (PoR cleric 3; Curse and CoK "special", level 7) | Heal (cleric 6) |
| 56 | Restoration (cleric 7) | Harm (cleric 6) |
| 90 | Animate Dead (Curse, CoK: special 5) | Barkskin (druid 2) |
| 96, 98 | Curse/CoK: special monster powers | Charm Person or Mammal, Cure Light Wounds (druid 2) |
| 101..107 | CoK: copies of base spells (Prot. Evil 10', Silence, Detect Magic, Remove Curse, Bless, Charm Person, Burning Hands) under castClass 2 | Secret: placeholders "spell 101..109"; Pools: Blade Barrier, Restoration, Energy Drain, Destruction, Resurrection, Cure Disease, Neutralize Poison, Hold Animal, Prot. from Fire |

The spell record (`TSpellRec`; Secret calls it `TSpellDef`) is the same 16 bytes everywhere, but each field has up to
three names (§5). The values are game data: `out/spcmp.txt` lists 72 ids with a field that differs, most of them
`aiPriority` (53) and `target` (21). Secret and Pools systematically recode target 4 to 3 and range-per-level 1 to 4. So
**the spell table stays per game**. Only the id constants and the record type are shared.

### 4.2 Spell-list (castClass) enum: three schemes

| | cleric | druid | magic-user | special/item |
|---|---|---|---|---|
| PoR `C_SPELL` | CLASS_CLERIC 0 | n/a | CLASS_MAGE 1 | CLASS_SPECIAL 2 |
| Curse `C_Spell` | CLERIC_LIST 0 | DRUID_LIST 1 | MAGE_LIST 2 | SPECIAL_LIST 3 |
| Pools `C_Spell` | CLERIC_LIST 0 | DRUID_LIST 1 | MAGIC_USER_LIST 2 | ITEM_LIST 3 |
| Secret `C_Spell` | CLERIC_LIST 0 | DRUID_LIST 1 | **MAGE_LIST 3** | **SPECIAL_LIST 4** |
| CoK (data) | 0 | 1 | 3 | 4 (and 2 for its ids 101..107) |

It is also the first index of `spellSlots`. Secret's `spellSlots[0..3,1..7]` wastes row 2. This needs a mapping.

### 4.3 Item type ids: three numberings
- PoR and Curse use Pool's ITEMS layout: hand axe 2, club 7, dagger 8, ... leather 50, arrow 73, holy water 85.
- Secret and Pools use another: club 3, dagger 4, ... arrow 30, leather 31 (Pools).
- CoK uses its own: holy water 54, hoopak 67.

These ids come from each game's shipped ITEMS file, so they stay per game. Shared code must name them through a
per-game `C_Item` with **the same constant names**. That holds today for most weapons: HAND_AXE, CLUB, DAGGER, DART,
HAMMER, JAVELIN, QUARREL, the swords and bows, SLING, ARROW and LEATHER_ARMOR. Name clashes: PoR `MAGE_SCROLL` vs Pools
`MAGIC_USER_SCROLL`. The property bits share values but not names: PoR `PROP_ARROWS / PROP_STR_BONUS / PROP_FIRES_AMMO
/ PROP_THROWN / PROP_QUARRELS` vs Pools `USES_ARROWS / STRENGTH_BONUS / FIRES_AMMO / THROWN / USES_QUARRELS`.

### 4.4 Effect ids: two families
- **PoR and Curse** share one numbering. Curse extends it to 150, adding INNATE_POWER 147, DISEASE_ON_HIT 148,
  DRAGON_FEAR 149 and COLD_PER_DIE 150.
- **Secret and Pools** share another, which agrees with PoR's only at 1, 2, 5, 8..12, 14..17, 19..26, 28..31, 33, 34, 36..39
  and 41..49. It diverges completely from 50 onward: PoR 50 ROT_NO_HEAL vs Pools 50 FIRE_SHIELD_HOT, PoR 89
  DISPLACED vs Pools 89 MAGIC_CLOAK, and the ranger damage bonus is 134 in Curse vs 105 in Secret and Pools.
- **CoK** follows the PoR/Curse family where checked (32, 36, 39, 42, 55) but has FEEBLEMINDED at 68, as Secret and
  Pools do (PoR 68 = GHOUL_PARA).

Effect ids are stored in save files and monster data, so a shared effect layer needs a per-game id map. Spec 9.2
already says never to borrow another game's numbering. The same effect also goes under different names: PoR
`GNOME_THAC0` / Curse `GNOME_ATTACK_BONUS` / Pools `GNOME_THAC0_BONUS` (18 vs 7), PoR `DWARF_AC_GIANT` / Curse
`DWARF_GIANT_DEFENSE` / Pools `DWARF_GIANT_BONUS`, PoR `CON_PSN_SAVE` 90 / Pools `CON_POISON_SAVE_BONUS` 94, and so on.

### 4.5 Enums that already line up
- Class values 0..16: identical in all five, except that CoK slot 7 is KNIGHT where it is MONK in PoR and Curse.
  Secret and Pools add 17 (Secret's name row 17; Pools `NO_CLASS`).
- The class-level slot equals the single class value everywhere. PoR names the slots `C_LEVEL` and Curse
  `C_Class.*_LEVEL`; the others use `C_Class` directly.
- Abilities 0..5: identical (PoR `C_ABIL`, the others `C_Stat`).
- Saves 0..4: identical (PoR `C_SAVE.PARALYZE..SPELL`, Secret `C_Save.PARALYZATION/BREATH_WEAPON/SPELL`, the others
  literal).
- Alignment 0..8: identical (PoR and Secret have `C_Align`; CoK uses a bitmask over its own six).
- Status 0..8: identical. PoR names `DEAD`, `STONED` and `TEMPGONE` (2); the others name `DEAD_STATUS`, and Secret and
  Pools name 7 `PETRIFIED`. CoK adds `REMOVED` 9 and `EXPLODED` 10.

### 4.6 Race ids: the blocker

| race | PoR / Curse | Secret | Pools | CoK |
|---|---|---|---|---|
| monster | 0 | 7 (0 = TRIBBLE) | 6 | 7 |
| dwarf | 1 | 3 | 2 | 3 mountain / 4 hill |
| elf | 2 | 1 | 0 | 0 Silvanesti / 1 Qualinesti |
| gnome | 3 | 4 | 3 | n/a |
| half-elf | 4 (PoR `HALFELF`, Curse `HALF_ELF`) | 2 | 1 | 2 |
| halfling | 5 | 5 | 4 | 5 kender |
| half-orc | 6 (PoR `HALFORC`) | n/a | n/a | n/a |
| human | 7 | 6 | 5 | 6 |

The race byte is in every saved character, in the import paths (Curse imports PoR; Secret and Pools import their
predecessors) and in the ECL scripts' race tests. So the shared tables must be indexed by a **canonical race**, with
`RaceOf(gameRace)` and its inverse per game. Do not renumber.

## 5. Same meaning, different names (a selection; one line each)

- Ability index unit: `C_ABIL` (PoR) = `C_Stat` (others). Class slot: `C_LEVEL.X` (PoR) = `C_Class.X_LEVEL` (Curse) =
  `C_Class.X` (others).
- THAC0 table: `thac0Tbl` / `classThac0` / `baseToHitTbl` / `thac0ByLevel` / `thac0Table`. Field: `thac0Base` = Secret
  `baseToHit`. Highest level: `levelHighest` = Secret `highestLevel` = Pools `hitDice` (reused field).
- Saves: `saveTbl` / `classSavingThrows` / `saveTbl` / `savingThrowTable` / `savingThrowTable`.
- XP: `experienceSpellsClass` / `classExperience` / `classProgression` / `classLevelTable` / `classProgression`. Record:
  `TRuleXp` (PoR and Curse, **different shapes under one name**) / `TClassProgression` / `TClassLevelTable`.
- Thief: `thiefBase` / `thiefSkillBase` / `thiefSkillsByLevel` / `thiefSkillTable`; `raceAdj` / `thiefRaceAdjustments`
  / `raceSkillAdjust`; `dexAdj` / `thiefDexterityAdjustments` / `dexteritySkillAdjust`. Routine:
  `ClassCal.RecalcThiefSkills` (PoR, Pools, CoK) = `CharHlp.RecalcThiefSkills` (Curse, Secret).
- Con: `conBonusTbl` / `constitutionHitPointBonus` / `conBonusTable` / `conHpTable`; `ConHpPerDie` = `ClassConAdj` =
  `ClassConHpBonus`; `constitutionBonusLevelCaps` (Curse; the name is misleading) = `firstFixedHpLevel` = `hitDiceLimit`.
- Hit dice: `hpDice`/`hpSides` = `startingHitDice`/`startingHitDieSides` = `firstLevelDiceTbl`/`hitDieSidesTbl` =
  `firstLevelHitDice`/`hitDieSides`.
- Usability: `usabilityBit` / `classItemMasks` / `classMaskTbl` / `classMaskBit` / `classMaskTable`; char field
  `itemLimits` (PoR) = `classMask` (others).
- Races: `minimumMaximumStatistics` / `raceAbilityLimits` / `raceLimits`; type `TRuleRace` / `TRaceAbilityLimit` /
  `TRaceLimits`; field `excMax` / `exStrMax` / `strExcMax`. Ages: `ageCat` / `ageThresholds` / `ageTbl` / `ageLimit`;
  `ageDice` / `startingAgeRolls` / `startAgeTbl` / `startAges` / `startAge`; `TRuleAge.num` = `TStartAge.dieCount` =
  `.dice`.
- Class rules: `classesByRace` / `raceClassLimits` / `raceClassTbl` / `raceClasses` / `raceClass`; `classMin` /
  `classAbilityMinimums` / `classMinTbl` / `classMinStats`; `alignByClass` / `classAlignments` / `classAlignTbl` /
  `classAlignMask`.
- Level caps: `raceMaxLevel` (0 = unlimited, -1 = barred) vs `raceCaps` (0 = barred, 40 = unlimited); routines
  `AtLevelCap` = `AtTrainingLevelLimit` = `RaceLevelLimit` + `AtTrainingLevelLimit` = part of `CanLevelUp`.
- Spell record fields: `rangeFixed`/`rangeBase`, `rangeVar`/`rangePerLevel`, `durFixed`/`durBase`/`durationBase`,
  `durVar`/`durPerLevel`/`durationPerLevel`, `area`/`targetType`, `target`/`targeting`/`noncombatTarget`,
  `saveResult`/`saveEffect`, `effect`/`effectId`, `whenCast`/`combatOk`/`castContext`, `castTime`/`castingTime`,
  `offensive`/`targetsEnemy`. Table: `spellTable`/`spellProperties`/`spellDefs`/`spellTbl`. Known spells:
  `spellsKnown`/`knownSpells`/`known`. Memorized: `memorizedSpells`/`spellsMem`.
- Spell ids: `DETECT_MAGIC_MU` (PoR) = `DETECT_MAGIC_MAGE`; PoR `HOLD_PERSON` 23 = `HOLD_PERSON_CLERIC`; PoR
  `ITEM_JAVELIN_LIGHTNING` 60 = `JAVELIN_OF_LIGHTNING`; `ITEM_FIREBALL` 64 = Pools `NECKLACE_OF_MISSILES`; PoR
  `WAND_MAGIC_MISSILES` 65.
- Item special code $81: Pools `ClassCal.DOUBLE_LEVEL_FIVE_SLOTS_ITEM`, a literal elsewhere. Code 6 (saving-throw
  item): Pools `SAVING_THROW_BONUS_ITEM_CODE`, a literal in Curse and Secret.
- Cleric slot routine: Curse `RecalcClericSlots(cr, rebuild)` = Secret `RecalcSpellSlots` = Pools `RecalcClericSlots`
  = PoR `AwardWisdomBonus` + `ResetClericSlots`. Secret's `RecalcClericSlots` is the **Intelligence** trim (= Pools
  `TrimHighSpellSlots`).
- Effective class level for dual-class: PoR `CharHlp.GetClassLevel(mask)` = Pools `ClassCal.EffectiveClassLevel` =
  inline `EarlierClassActive` tests in Curse and Secret (with `oldClassLevels` / `classLevelB` / `oldLevels`).

## 6. Disagreements (game, entry, values, 1st-edition verdict)

Live = changes play in that port today.

| # | Table / entry | Values | Verdict |
|---|---|---|---|
| D1 | THAC0 fighter/paladin/ranger | PoR, Curse, Secret, CoK: 21 - level; Pools: DMG pairs (20,20,18,18,...,4) | **ruling R1**; DMG = Pools |
| D2 | THAC0 magic-user | PoR, Pools: DMG (20 to L5, 19 to L10, 16 ...); Curse, Secret, CoK: 2e (-1 every 3) | R1; DMG = PoR/Pools |
| D3 | THAC0 thief | PoR, Pools: DMG (20 to L4, 19 to L8, 16 ...); Curse, Secret, CoK: 2e (-1 every 2) | R1; DMG = PoR/Pools |
| D4 | THAC0 column 0 | Pools fighter and MU 39; others 40 | harmless (max over classes); use 40 |
| D5 | THAC0 range top | Secret fighter L18 = 57 (THAC0 3); Pools L17+ = 56 (4) | follows R1 |
| D6 | XP paladin L11 | Pools 1050000; Curse, Secret, PHB 1050001 | PHB; Pools wrong, **live** (and every extrapolated level) |
| D7 | XP ranger L11 | Pools 650000; others 650001 | PHB; Pools wrong, **live** |
| D8 | XP paladin L15 | Secret 2460001; PHB and Pools formula 2450001 | PHB; Secret wrong, **live** (last level) |
| D9 | Saves cleric L19 | Pools (4,7,8,10,9); DMG 19+ (2,5,6,8,7) | DMG; Pools wrong, **live** |
| D10 | Saves monk L10..12 | Curse holds magic-user values | unused class; fix in the shared table |
| D11 | Saves druid L19+ | Pools stays at 16-18's row | druid unused |
| D12 | Thief read languages L11, L12 | Curse, CoK 60, 65; PHB, Secret, Pools 55, 60 | PHB; Curse **live** (L11-12 thieves), CoK live if L11 reached (cap 9: not live) |
| D13 | Thief race adj. human row | Pools = half-orc figures; others 0 | PHB (0); Pools **live** |
| D14 | Thief race adj. index | CoK indexes PoR's row order by CoK race (kender gets half-orc's, hill dwarf halfling's) | probably SSI's data; verify; CoK rules differ anyway |
| D15 | Thief Dex adj. range | Curse, Pools 9..19; PoR, Secret, CoK 9..25 | D&DG to 25 (memory "ability tables to 25") |
| D16 | Wis bonus spells range | Curse, Pools hard-coded 13..18; PoR, Secret, CoK table to 25 | to 25 |
| D17 | Ranger MU slot columns | Curse, Secret columns 4..5; Pools 5..6 | encoding only; pick one |
| D18 | Secret paladin slots L16..18 | (3,2,1,2), (3,2,2,2), (3,2,2,3) vs PHB (3,3,1,1), (3,3,2,1), (3,3,3,1) | PHB; unreachable in Secret |
| D19 | Start age, human magic-user | PoR, Curse, Secret 24+2d8; Pools, CoK 24+2d4 (SSI's) | DMG 2d8 (PoR #946) |
| D20 | Start age, half-elf ranger | PoR, Secret 22+3d4; **Curse 0+0d0** (a half-elf ranger starts at age 0); Pools 22+0d0 | 22+3d4 (the DMG has no row; take the fighter's); Curse probably **live** (age 0 + a 0d0 roll; check the reader), Pools a fixed 22 |
| D21 | Start age, half-elf paladin | Pools 22+0d0; others 0 (class barred) | moot |
| D22 | Cleric alignments | Secret: cleric and every cleric multi allow all 9 (TN included; cleric/thief 9); PoR, Curse, Pools: no TN, cleric/thief 6 | PHB (PoR's reading); Secret **live** |
| D23 | Level-1 cleric dice | CoK 2d8; others 1 | CoK-specific? verify against CoK data |
| D24 | Prime requisites | CoK druid Int+Wis, knight Str; FR druid Wis+Cha, monk Str/Wis/Dex | PHB for druid (unused); knight is CoK's |
| D25 | Usability bits | CoK druid $20, ranger $80, knight $10; FR druid $10, ranger $40, monk $20 | item data per game: parameter |
| D26 | Item $81 | Curse doubles MU 1..3; Secret, Pools double 5 | item data: parameter |
| D27 | Weight allowance Str 19 | CoK 4000; others 4500 (D&DG) | D&DG |
| D28 | TranslatedStrength guard | CoK lacks the `else` branches | defensive fix |
| D29 | Turning | Secret has none | port gap; give Secret the shared table |
| D30 | Turning rows 11..13 | Pools rows 11..13; CoK row 11 different, row 12 all 99 | per-game undead roster, so rows are data |
| D31 | Armour barring thief skills | PoR all 8; Pools skills 1..7 | rule fork (minor); pick one |

The hit-point rolling rule (best-of-two in Pools vs Con floor in PoR) and the attacks 2/1 at 13+ (absent in PoR and
Curse, unreachable there) are rule forks without disagreeing table values; they are listed under hooks below.

## 7. Proposal

### 7.1 Shared units

1. **`AbilAdj` (shared verbatim from PoR).** It holds Strength translation, hit, damage and weight, Dexterity AC and
   missile, Con save, regeneration, system shock and resurrection, Int know-spell, Wis failure, loyalty, and the
   strength-effect pack and unpack, all to 25. Every other game's copies are identical or strictly older. Change: pass
   scores (`str, exc, dex, con`) rather than a `PCharRecord`. PoR's `TranslatedStrength(creature)` reads
   `strCur`/`strExc`, while the others read `stats[STRENGTH].cur`/`strExcCur`. A thin per-game `CharHlp` wrapper
   supplies the scores.
2. **`RuleTbls` (new; data only, typed consts).** It holds the full-range 1st-edition tables, indexed by **canonical
   class slot 0..7** (cleric, druid, fighter, paladin, ranger, magic-user, thief, monk/knight) and **canonical race**
   (monster, dwarf, elf, gnome, half-elf, halfling, half-orc, human):
   - `xpBase[0..7, 2..11]` + `xpIncrement[0..7]` (Pools' formula; D6, D7 fixed).
   - `thac0[0..7, 0..21]` (per R1) with "clamp above 21".
   - `saves[0..7, 1..21, 0..4]` (Pools with D9 fixed; monk row from the DMG, not Curse's).
   - `casterSlots[cleric|mage|paladin|rangerDruid|rangerMage, 1..29, 1..9]` (absolute; Pools).
   - `wisBonusSpells[13..25, 1..7]` (PoR/Secret), `wisSpellGate` (6th: 17, 7th: 18), `intSpellGate` (6th..9th:
     12, 14, 16, 18).
   - `thiefBase[1..18, 1..8]` (Pools/Secret), `thiefRaceAdj[canonical race, 1..8]` (PHB, human 0s),
     `thiefDexAdj[9..25, 1..5]`.
   - `turnTable[1..13, 0..10]` (Pools) and the column map from PoR `TurnValue`.
   - `conHpBonus[3..25]`, `hpDice`, `hpSides`, `lastDieLevel`, `hpPerLevelAfter` (+3, +2, +1).
   - `raceLimits[race]`, `raceAbilityAdj[race]`, `ageCategories[race]`, `startAge[race, class]` (D19, D20 fixed).
   - `classesByRace[race]`, `classMin[0..16]`, `classAlign[0..16]`, `classParts[0..16]`, `primeRequisites[0..7]`,
     `startingGold[0..7]`.
   - `raceLevelCap[race, class, band(<17, 17, 18+)]`, one table replacing four implementations (PoR `FIGHTER_CAP` +
     `HalfOrcCap`, Curse/Secret `LimitByScore` cases, Pools `raceCaps` + `CanLevelUp` cases). The band ability
     (Str, Int, Wis, Dex) is a column.
3. **`RuleCal` (from `ClassCal`).** The routines that read only the tables:
   - XpForLevel, Thac0For(cls, lvl), SaveFor, SlotsFor (with gates), ThiefSkill (PoR's `ThiefSkillParts` + `ThiefSkill`
     are already split for reuse), TurnValue, ConHpPerDie, HitDieFloor, ExperienceShare, PrimesAtLeast /
     DualClassAbilitiesMet, ClassAbilityMin, StartingAge, RaceLevelCap, AttacksFor(cls, lvl).
   - These take levels and scores, not records. The per-game `ClassCal.RecalcClassStats` / `RecalcBaseSkills` stays
     per game and becomes a short loop over them, because it writes into five different character layouts.

### 7.2 Per-game layer (parameters and hooks)

- **`GameRules` constants:**
  - `MAX_CLASS_LEVEL[slot]`: PoR (6,-,8,7,7,6,9,-), Curse (10,-,12,11,11,11,12,-), Secret (15,-,15,15,15,15,18,-),
    Pools 40, CoK Krynn.
  - `MAX_SPELL_LEVEL[list]`: 3/3, 5/5, 7/7, 7/9, 5.
  - `SPELL_LAST`: 56/100/117/126/107.
  - `CLASSES_OFFERED`, `RACES_OFFERED`.
  - `TURN_UNDEAD` (absent in Secret today), `ATTACKS_2_PER_ROUND` (on everywhere is harmless).
- **Id maps:**
  - `RaceToCanon[gameRace]` and back.
  - `ListToCanon[castClass]` (§4.2).
  - The effect-id map for whichever shared effect code comes later.
  - Item ids stay per game: shared code names them only through each game's `C_Item` with agreed names.
- **Hooks:**
  - `RollHitDie` (PoR floor and 2/3 vs Pools best-of-two).
  - `ArmourBarsThiefSkills` (PoR: shield or non-leather bars all; Pools 1..7).
  - `ItemDoublesSlots` ($81 behaviour).
  - CoK's `ProgressionFor(char)` (order/robe → progression row).
- **Display-only tables stay per game:** the race screen's max-level column, derived from `raceLevelCap` and
  `MAX_CLASS_LEVEL`.

### 7.3 Risks

- **Save format and imports:**
  - The character records differ: PoR `classLevels[0..7]` ShortInt with separate `clericSpells`/`mageSpells[1..3]`;
    Curse `classLevels`+`oldClassLevels[0..7]`, `spellSlots[0..2,1..5]`; Secret `classLevelA/B[0..6]`,
    `spellSlots[0..3,1..7]`; Pools `classLevels`/`oldLevels[0..6]` Byte, `spellSlots[0..2,1..9]`; CoK
    `classLevels[0..7]`, `spellSlots` deltas `[2..12,1..5]`. Known-spell arrays are 56/100/117/126/107.
  - Shared tables are safe. Shared routines must not take the record (use accessors), or the import paths
    (Curse←PoR, Secret←Curse, Pools←Secret) and SSI-format files break.
  - Clamping a character imported at a higher level into a lower-cap game is a per-game rule (not audited here).
- **DOS memory:** typed consts live in DGROUP (64 KB, shared with all globals). Rough sizes at Pools' range:
  - slots 5x29x9 = 1.3 KB, saves 8x21x5 = 840 B, THAC0 8x22 = 176 B, thief 18x8 + 7x8 + 17x5 = 285 B, turning
    13x11 = 143 B, XP 8x11x4 = 352 B, race/class tables about 1.5 KB. Total about 4.6 KB, against today's 1..3 KB per
    port.
  - PoR, the tightest, gains about 3.5 KB of DGROUP. Measure it before committing. If it is tight, put the large
    tables (slots, saves) in an overlaid code unit as procedure-returned data, or load them from a data file at
    start-up.
  - The FPC/SDL3 native build has no such limit.
- **Behaviour changes on adoption:** R1 changes every warrior's to-hit in PoR, Curse and Secret at even levels, and
  magic-users' and thieves' in Curse and Secret. Fixing D6, D7, D8, D9, D12, D13, D20 and D22 changes play in the port
  that has the error (each is an issue per bug, and checked in every game per memory).
- **The byte-matched disassembly trees** (`*-disassembly` repos) are outside this proposal: they keep SSI's tables and
  bugs per spec 1.5. Sharing applies to the ports only.
- **CoK:** treat it as a sixth rule set using the same types. Sharing `AbilAdj`, THAC0, saves, Dex/Con and turning rows
  1..10 is reasonable. Its XP, race, class, age, alignment and usability tables stay CoK's.

### 7.4 Rulings needed from Brian

- **R1** THAC0: the 1st-edition DMG matrix (Pools) for every class, or keep 21-level for warriors?
- **R2** Hit-point rolls: Pools' best-of-two or PoR's Con-floor rule?
- **R3** Armour and thief skills: bar all eight or seven?
- **R4** Cleric 7th-level slots at L14 (PHB, if that is what it says) or L16 (Secret/Pools)?
- **R5** Human women 18/00 (all four FR ports): keep the house rule? Pools' comment flags it as a departure.
