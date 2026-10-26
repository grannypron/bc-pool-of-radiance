# Shared gameplay core across the five Gold Box ports (analysis, 2026-10-26)

Scope: combat (Combat, CombatSt, CombatAi, CbtActs, CbtMap, Pathing, PostCbt, CbtLog); effects (FxEngine, EffHndlr, the
effect handler table); magic (Magic, UsualSpl, SpellInf, the spell handler table); characters (CharHlp, ClassCal's
logic, ChgClass, CharGen, CharEdit, Stats, Party, AbilAdj); the party screens (ViewChar, CharDisp, PartyMnu); Camp,
Explore/Wilds, Shop, Temple, Money/MoneyCal, GameTime's rest and time parts, RandItem; training.

Sources: each repo's `origin/main`, exported with `git archive` (no worktrees, nothing modified): PoR 109f2c2, Curse
34eaebd, Secret b49f824, Pools 33ddd3b, CoK f132af3. Abbreviations: PoR, Curse (cab), Secret (ssb), Pools (pod), CoK.

Method. `gp/routines.py` tokenises every unit, strips comments and unit qualifiers (`GDVars.`, `Types.`), and extracts
every routine, nested ones included. `gp/match.py` groups routines into families across games: first by name, then by
fuzzy body match (difflib ratio of at least 0.62) for renamed routines. Each pair is scored two ways:

- **token**: the exact normalized code.
- **shape**: every identifier replaced by `I`. Two routines that differ only in variable, field or local names score
  1.0 on shape.

The family list is in `gp/families.json`; `gp/summ.py <unit>` prints it and `gp/show.py <routine> [games]` diffs one
family. Each sub-section's findings come from reading the diffs, not just from the scores. The effect and spell
handler tables were extracted by id (`gp/eff-table.txt`, `gp/spell-table.txt`).

## 1. Headline findings

1. **The gameplay engine is one engine in five sets of names.**
   - Scope: 1,507 routine families in these units. 382 are in all five games and 478 in all four non-PoR ports.
   - Exact matches are rare: 24 families are token-identical across every game that has them, and 28 among the four
     non-PoR ports.
   - Shape matches are common:
     - Among the four ports, 371 families score at least 0.85 on shape for the worst pair, 254 score 0.70–0.85, and 215
       score below 0.70.
     - PoR against its closest port: 431 families score at least 0.85 on shape, 141 score 0.70–0.85, and 98 below 0.70.
   - The gap between shape and token is almost all naming:
     - Character-record fields: `hostile`/`side`, `hpCur`/`hpCurrent`, `enabled`/`inPlay`, `curAttacks`/`attacksLeft`,
       `strCur` against `stats[i].current`.
     - Globals: `spellId`/`spellBeingCast`/`currentSpell`/`currentSpellBeing`, and
       `creatureList`/`partyHead`/`creatureListHead`.
     - Locals: `cr`/`creature`/`character`.
     - Literal ids against named constants.
2. **Naming comes before sharing.** One shared source file compiled once per game needs one field, global and constant
   vocabulary. The cleanup spec deliberately unifies only routine names across games (scope cut of 2026-10-11), and only
   in the byte-matched disassembly trees. For the ports (these repos) unifying field and global names is allowed and is
   step 1. It is mechanical (`pas_rename`-style), proven by each port's tests and regression scenarios, and must never
   reach the disassembly trees.
3. **Ids are game data and must stay per game, because saves and ECL scripts hold them.**
   - **Spell ids:**
     - Ids 1–35, 37–55, 57, 59–62, 64 and 65 are the same spell, with the same handler, in all five games. Ids 68–89 are
       the same in Curse, Secret, Pools and CoK.
     - They differ at 36 (Animate Dead / Heal), 56 (Restoration / Harm), 63 (Dust / Youth), PoR's 58/66/67, and
       90–126 (Curse/CoK set against Secret/Pools set; CoK's 101–107 are Krynn copies).
   - **Effect ids:**
     - 43 of ids 1–56 mean the same in all five games.
     - Above 56 there are three numberings (PoR's own; Curse's; Secret's, which Pools extends and CoK partly shares).
     - Only 61, 62, 64 and 89 agree in all five above 56.
   - **What does agree:** the 9-byte effect node and the condition ids (`C_Cond` 0..19) are the same in all five.
   - **Shared code shape:** shared code names spells and effects symbolically, and each game supplies a
     name-to-id table (and back), its spell-property array and its handler-table init.
4. **The character record differs per game, and so do saves.**

   | Game | Ability scores | Spells known | Memorized slots | Slot table | Coins | Other |
   |---|---|---|---|---|---|---|
   | PoR | flat current-only bytes (`strCur`..`chaCur`) | 56 | 21 | `clericSpells`/`mageSpells[1..3]` | 7 kinds | |
   | Curse | `stats[0..5]` of {permanent, current} | 100 | 84 | | 7 kinds | `oldClassLevels` for class change |
   | Secret | as Curse | 117 | | `[0..3,1..7]` | 7 kinds | `V1`/`V2` variant views over a $1B7-byte record |
   | Pools | as Curse | 126 | 141 | `[0..2,1..9]` | 3 kinds (platinum, gems, jewelry) | `spellResistance` and `levelCapped` fields |
   | CoK | as Curse | 107 | 58 | `[0..3,1..5]` | 7 kinds, steel standard | `knightOrder`, `deity`, `robeOrder`, `levelBucket` |

   Curse already separates the two: its in-memory `TCreature` is distinct from its on-disk `TCharRecord` (the PoR import
   layout). That is the model:
   - a superset in-memory creature sized to Pools' maxima;
   - each game's on-disk layout converted in its SaveLoad.

   ECL reads the record by offset (EclVars' GBVM map, `SpecialReadZ1`), so that map stays per game and points into the
   per-game disk-layout view.
5. **Fixes have flowed both ways, and the shared core is where they would stop drifting.**
   - Most CURSE-NNNN fixes were found in Curse and mirrored into PoR, and most are already in every port. Several fixes
     (touch wards, cloud numbering, the Dispel Magic walk) were made separately in several ports, each its own way.
   - About a third of PoR's town and camp fixes repair v1.3-only bugs that the later SSI engines never had (ShareMoney
     divisor, 65535 coin cap, rest clock, scribe slot, Knock offer).
   - The fixes still missing per port are tallied in section 3.
6. **PoR-only features to share later:**
   - Dual-class UI: ChgClass and PartyMnu. The four later ports already have SSI's own human class change with
     near-identical rules logic, so the shared form is their rules under PoR's screen.
   - AbilAdj's ability tables to 25 (partly in Secret, Pools and CoK).
   - SpellInf: ported separately into Pools and CoK, and the three copies now differ.
   - MoneyCal's pure money calculations.
   - Pathing's BFS `RouteStep`/`MarkGoals`/`RouteToEnemy` (#668/#769): Curse has it, Secret and Pools partly, CoK not.
   - CbtLog: also in Pools.
   - The area-spell catch tally (#840).
   - Stats counters: in four games, not CoK.
   - CharEdit: also in Curse.
   - The native FPC/SDL3 layer: PoR only.

## 2. The proposed shared gameplay core

Shared units, each compiled per game against that game's `Types`, `GDConsts`, `GDVars` and `includes/c_*.pas`:

| Shared unit | Built from | Holds |
|---|---|---|
| `CharRules` (resident) | PoR CharHlp + AbilAdj, the four ports' CharHlp | ability adjustments to 25, damage/healing (`InflictDamage`), teams (`Team`, `EnemyTeam`, `CountTeams`), `RecalcStats`, `WeaponAdjust`, encumbrance, `PermanentStrength`, `HasteSlowRate`, `IsPerson` |
| `ClassRules` | PoR ClassCal logic | caster level, THAC0/saves/thief skills lookups over Pools-sized tables, `AtLevelCap`, `TrainClasses`, `ExperienceShare`, `ClassAbilityMin`, `SpellFailureChance` |
| `Training` | CharGen's TrainingMenu / GainLevels in each port | level-up flow; fee, hall and cap from the game's rules record |
| `FxCore` (resident) | PoR FxEngine | Add/Remove effect, `HasEffectNode`, condition dispatch from a per-game condition table, `RollToHit`, saving throws, magic resistance (two models behind a switch), auras from a per-game aura table, clouds through one area-list model |
| `FxHandlers` | handlers common to all five (43 low ids plus about 40 more by name) | handlers keyed by effect name; game-only handlers stay in per-game `GameFx` units (overlay budget) |
| `MagicCore` | PoR Magic | `CastSpell` skeleton, `ResolveSpell` (save byte against `SAVE_*`), `UseItemSpell`, scrolls, cone/bolt/cloud geometry, Dispel Magic, about 45 common handlers, UsualSpl, SpellInf |
| `CombatCore` | PoR Combat/CombatSt/CombatAi/CbtActs/CbtMap/Pathing/PostCbt | round loop, menus, placement, attack and step, opportunity attacks, the AI's move/attack/route, loot and experience |
| `TownCore` | PoR Camp, GameTime+Clock, Money+MoneyCal, Shop/Temple `CounterMenu`, Explore's doors and movement, RandItem; Wilds optional | rest, memorize and scribe, Fix, coin arithmetic and menus, the shop/temple loop, door menus |

Each game supplies four things.

**A `GameRules` record of constants and switches.** The values that are known so far:

| Setting | Values |
|---|---|
| `MAX_LEVEL` | per game |
| `THAC0_LEVEL_CAP` | 12 / 18 / 21 |
| `TRAIN_LEVEL_CAP` | 12 / 18 / 40 |
| `TRAIN_NEEDS_HALL` | Pools trains without one |
| `ITEM_CASTER_LEVEL` | per game |
| `CASTER_LEVEL_CAP` | 15, or 31 in Pools: effect-strength packing |
| `FOUR_ATTACKS_AT` | Secret, Pools |
| `BACKSTAB_MAX` | x5 in Pools |
| `TURN_ORDER` | pick-next (PoR, Curse) / sort-once (Secret, Pools, CoK) |
| `HAS_TURN_UNDEAD` | Secret has none |
| `HAS_WILDERNESS` | PoR, Pools, CoK |
| `MAGIC_RES_MODEL` | effect (PoR, Curse) / field (Secret, Pools, CoK) |
| `ABILITY_MODEL` | stored restore values (PoR) / recomputed from effects (Curse onward); PoR should move to Curse's |
| `PRICE_MODE` | Secret, Pools, CoK |
| Rule switches | `WIS_SPELL_FAILURE`, `INT_SCRIBE_ROLL`, `SILENCE_SAVE_NEGATES`, `SYSTEM_SHOCK`; deliberate 1st-edition rule changes, so they are per-game choices, not "fixes" |

**Tables.** All are sized to Pools' maxima, with each game enforcing its own level and gear limits on top:
- spell properties, the spell-id map and the spell handler init;
- the effect-id map, the condition table and the aura table;
- XP/THAC0/saves/slots/thief/turning rows;
- coin kinds and values;
- the temple price list (nil means free, as in Secret) and its extra services (Pools);
- shop price scaling;
- terrain classes;
- the Alter item table;
- the random-item table.

**Hooks**, procedure variables set by the game's init, the way PoR already sets `CbtMap.aimReport` and `boltTracer`:

| Area | Hooks |
|---|---|
| Magic | `CasterLevelAdjust` (CoK moons), `SaveAdjust` (CoK robes, Pools' Dancing), `BonusMemorizeSlots` (CoK `MoonBonusSpells`), `HealBonus` (CoK deity 4), `MiscastCheck` (Curse effect 74), `CastAnimation` (Pools VGA) |
| Effects | `ItemEffectOverride` |
| Combat | `OnCombatStart`, `AfterAction`, `OnRoundEnd` (CoK exploders and acid pools; Curse eye rays, engulf, hug), `AiPickSpell`/`AiPickItem` (Pools' priority picker, AI that uses no items) |
| Characters | `XpRowFor` (knight and robe rows), `AfterLevelUp`, `StartingKit` |
| Temple | `CanBeRaised` and the raise outcome (four rules today; Krynn refuses races below half-elf) |
| Camp | Fix's curable set (three generations of Fix) |

## 3. Where sharing brings PoR's fixes to all

Each slice below has its own fixes-against-ports table (spot-checked in code, about 120 fixes in all). These were
missing in **every** other port at origin/main:

| Fix | What it does |
|---|---|
| #877 | Fix refuses in an anti-magic area (`CharHlp.AntiMagicArea`) |
| a050ead | the temple's Stone to Flesh rolls system shock |
| POR-0210 / #890 | Shield and Magic Missile immunity stop the Wand of Magic Missiles |
| #931 (d4d12bf) | Bless and Haste reach only the caster's side; Curse and Slow only the other |
| #931 (167be29) | a spell with no targets clears its element |
| #860 | Silence's save, read from the save byte against `SAVE_*` (Curse still compares the byte with True, which depends on the compiler) |
| CURSE-0333 | curing a disease gives back the Strength it took |
| 15d62e6 | the aura range test gives the caller its target count back |
| #981 | a silver shield turns a petrifying gaze |
| #954 (07b3721) | a dying creature hit again goes further below 0 |
| #945 (d1f03cc) | a multiclass starts at its oldest class's age |
| CURSE-0066 | paladins carry effect 45, the 10' radius; Curse itself still gives 8 |
| POR-0215, #933 | combat-core review fixes |
| 6995f80, 401f1fc | `ParseMoneyType` returns -1; one coin-menu builder |

Per port, beyond those:
- **Curse:**
  - Snake Charm by `charType` (POR-0193).
  - Wisdom spell failure (#61).
  - `IsPerson` (POR-0185).
  - Paralysis touch save modifier (POR-0180).
  - Door/Knock menu.
  - Temple cure prompt.
  - Camp id and slot bounds.
- **Secret** (lags most on combat and protections):
  - RouteStep goals (#769).
  - AI turn guard (#803).
  - FindPlacement (POR-0201) and bestDist (POR-0195).
  - Prime-requisite reads the current score (POR-0174).
  - Auras and protections (POR-0177/0178/0183/0184/0192).
  - Haste/Slow cancel (POR-0173) and re-run (POR-0188).
  - Cleric true neutral (#202).
  - `hostile * 128` in Charm Person.
- **Pools:**
  - AI pending spell first (POR-0150).
  - #769.
  - Duel XP inside the loop (f19da0e).
  - POR-0214.
  - POR-0173.
  - The cast-facing loop that can spin forever (167be29).
  - Camp bounds.
- **CoK:**
  - BFS routing (#668/#769).
  - POR-0195.
  - Aborted item spell still spent (#697).
  - Rear AC Dex penalty (CURSE-0064).
  - Launcher plus (CURSE-0071).
  - `teamCount` indexed by the raw `hostile` byte (CURSE-0261).
  - POR-0199, POR-0173 and POR-0180.
  - `IsPerson`.
  - Door/Knock.
  - Temple cure prompt.
- **To verify:** CoK's cleric prime-requisite tests Wisdom > 14, against > 15 elsewhere. It could be an SSI quirk or a
  Krynn rule.

The slices give the per-port fix counts:

| Slice | Curse missing | Secret missing | Pools missing | CoK missing |
|---|---|---|---|---|
| Characters (28 applicable) | 9 | 11 | 7 | 12 |
| Combat (24 checked) | 2 | 7 | 6 | 5 |

The effects slice counted present and partly present instead (28 checked per port):

| Port | Present | Partly present |
|---|---|---|
| Curse | 14 | 6 |
| Secret | 9 | 5 |
| Pools | 14 | 5 |
| CoK | 12 | 2 |

The rest of the 28 were not applicable to that game or not found.

## 4. Risks and constraints

- **Save formats.**
  - Record layouts differ (section 1.4).
  - Spell and effect ids are stored in saves.
  - Effect strength packs the caster level: 4 bits, or 5 in Pools.
  - The coin array's length differs (7 kinds, or 3 in Pools).
  - A shared in-memory superset needs per-game converters, and no id may ever be renumbered.
- **ECL.** Scripts read globals and the character record by GBVM address. Per-game address maps stay per game
  (EclVars). The GBVM zone band's layout (anti-magic word, price mode, door flags, CoK's moon phases) differs, and is
  read through accessors.
- **DOS memory.**
  - Data segment free: Curse 11.3 KB, Secret 21.9 KB, PoR about 19 KB.
  - Overlay buffers are 160 KB in Curse and Secret, 100 KB in PoR. Pools overlays only 9 units.
  - Most gameplay units are overlaid in Curse, Secret and CoK; in PoR, CharHlp and FxEngine are resident.
  - A shared unit carrying every game's specials would bloat each game's overlays and `Prime*` working sets, so
    game-only handlers and features stay in per-game units behind the hooks.
  - Making `CharRules`/`FxCore` resident costs Curse's tight data and code budget; measure with each `build.sh` size
    report.
- **Toolchain.** Secret is built with Turbo Pascal 5.5 (per its refactor plan), the others with TP 6. Shared source must
  compile under 5.5: no `Break`/`Continue`, `const` parameters or open arrays. PoR's native FPC build must keep both
  compilers agreeing (#860 is the cautionary tale).
- **Behaviour.** Every shared rule changes SSI's behaviour somewhere. Each port needs its "Differs from SSI" entry and a
  Forge issue per bug (POR-/CURSE-/SECRET-/POOLS-NNNN). Deliberate differences such as Secret's free temple, Krynn's
  prices and race limits, and Pools' training without a hall must stay explicit rule switches, never be "fixed".
- **In-flight work.** The Curse agent is migrating PoR's work into Curse now. These findings are against origin/main
  as of this morning, so Curse's gaps may be closing as you read.

## 5. Suggested order

1. Unify field, global and constant names across the ports (mechanical; no behaviour change).
2. Symbolic spell and effect names, with per-game id maps; a per-game condition table and aura table.
3. Introduce the `GameRules` record and the hook variables in each port, still with local code.
4. Lift the units in the order with the most shape agreement and the least game branching:
   1. Pathing and CbtMap;
   2. CharRules and ClassRules;
   3. FxCore, then the common FxHandlers;
   4. MagicCore;
   5. Camp, Money and GameTime;
   6. CombatCore;
   7. the screens (ViewChar, CharDisp, CharGen) last, since they are the most diverged and closest to the segment limits.
5. Each lift brings the PoR fixes above to every port in one change. Each fix gets a per-game issue.

---

The five slice reports follow, each with a table per unit and its own fixes table and proposal.


## 6. Combat group: Combat, CombatSt, CombatAi, CbtActs, CbtMap, Pathing, PostCbt (+ CbtLog)

Sources: each port at origin/main (PoR 109f2c2, Curse 34eaebd, Secret b49f824, Pools 33ddd3b, CoK f132af3), routine
families matched by name and then by token similarity (`gp/families.json`, `gp/summ.py <unit>`, `gp/show.py <routine>`).
"tok" is the token similarity after comments and unit qualifiers are stripped; "shape" is the same with every
identifier replaced by a placeholder, so it measures the logic regardless of naming.

### The headline

- **The logic is shared; the names are not.** Over the 7 units, pairs of the four non-PoR ports average 0.75 to 0.86
  token similarity and 0.83 to 0.92 shape similarity. PoR against each of them averages 0.68 to 0.78 tok and 0.77 to
  0.85 shape (PoR has been refactored the most). Curse and Secret are the closest pair: 92 of 140 shared routines are at
  0.9 shape or more. Only one routine in the group is token-identical in all five ports (`CbtMap.ViewCoordsValid`).
  Most of the gap is identifiers. The same field is `curAttacks` / `attacksLeft`, `acCur` / `armorClass`, `enabled` /
  `inPlay`, `hostile` / `side`, `other` / `otherV1`, `direction` / `facing`, and the creature list is `creatureList` /
  `partyHead` / `creatureListHead`; locals are `creature` / `cr` / `character`. Condition ids are literals (7, 15, 19,
  21, 24) in Curse, Secret and CoK, and `C_Cond` names in PoR and Pools. **The ids are the same in every game**: TURN_START 7,
  ACTION_START 15, MORALE_CHECK 17, ROUND_END 19.
- The cleanup spec unifies only routine names across games (scope cut 2026-10-11). A shared core therefore needs one
  step first that the spec does not give: one name for each `Types` field, `GDVars` variable and `C_*` constant that
  the combat code touches. Without that step, no combat routine can be shared verbatim.
- Under the naming, roughly 60% of the group's routine families are the same rule set with small, game-flagged
  branches. About 25% are generational rewrites: turn order, AI spell choice and area clouds. About 15% are
  game-only features.

Line counts per unit (whole file, comments included), in the order PoR / Curse / Secret / Pools / CoK:
CbtActs 2079/2578/2123/2845/2152, CbtMap 999/1197/1225/1152/780, Combat 517/585/711/700/623,
CombatAi 919/1105/846/1094/940, CombatSt 897/919/698/943/914, Pathing 583/600/517/494/334,
PostCbt 554/704/689/633/726.

### Combat (round loop, menus)

| Routine | Lines P/C/S/Pl/K | Class | What differs |
|---|---|---|---|
| CombatMain | 35/34/40/58/44 | branches | Turn order: PoR and Curse pick the next creature each step (`NextCreature`, 29/32 lines, not in the others); Secret, Pools and CoK sort once (`OrderCreatures`, 46-54 lines, 0.95 Secret~Pools) and walk `initOrder[1..72]`. Secret and Pools have `AgingDeaths` after combat (Haste aging, 80/69 lines). Pools runs `UseLeadership` before the fight, condition 24 at combat start, a combat log (`CbtLog`, also in PoR) and an end test mid-round. CoK runs condition 24 and `FxEngine.ProcessExplodingCreatures` after each action (draconians). |
| CreatureAction | 29/35/28/36/38 | same logic | Curse onward add `mapVisible := friendly or icon visible` (hidden monsters) and condition 21 when no spell is pending. PoR uses `ResetFlanking`. |
| EndOfRound | 39/44/37/46/44 | same logic, branches | The round limit (`roundLimit` / `fightEndRound`; Curse reads it from `combatTargetSlots[0]`, a naming slip) and the demo-mode guard are in Curse onward. Pools also runs `CountDownAreaEffects`. Stinking cloud (PoR) becomes `ConsiderTerrainEffects` (Curse onward). CoK has no Died counter (no Stats unit). |
| ManualControl, CombatMenu | 88-120, 34-53 | branches | The menu items are game data: Turn (absent in Secret), Yell (CoK), Quick (not in CoK's), `*` debug (Secret), and Pools reads `GDConsts.combatMenuItems`. The key sets differ. |
| MoveMenu (+UndoMove) | 76/112/119/128/114 | same logic | Secret, Pools and CoK split out `UndoMove`. PoR now steps through `CbtActs.StepCreature`. |
| MeleeAttack, TurnOnAuto, SpeedMenu | ~10-34 | near/same | SpeedMenu differs in Pools (0.40 tok: its own menu text). |
| DoneMenu | 39/43/51/-/54 | same logic | Pools has none (Done is direct). |
| CombatDoneCleanup | 20/22/35/35/35 | branches | Frees each game's area lists: stink (PoR); stink and cloudkill (Curse); stink and blast (Secret); `cellPatchList` (Pools); cloud and acid pool (CoK). Secret, Pools and CoK also release charmed creatures and run `RemoveEffectsHp0`. |
| BandageDying | PoR Combat; Curse and Secret CharDisp; Pools and CoK CharHlp | same | PoR took it from Curse (#654). |

### CombatSt (arena build, placement)

| Routine | Lines | Class | What differs |
|---|---|---|---|
| BuildDungeonArena (+DrawNorthWall, DrawFloorWestWall, FillCorner*) | 202/202/173/212/211 | near to same | DrawNorthWall and DrawFloorWestWall are at 0.95 to 1.0. The arena tile set is game data. |
| WallBetween(+GetWallKind), PlotCell, QuadFullyOff, TryPlaceAt | 13-35 | data-only to near | WallBetween is shape-identical in all 5. |
| PlaceRiver, PlaceTrees, ScatterFeatures, BuildWildernessArena, TerrainClassOf | 8-63 | diverged | **Secret has no wilderness arena.** PoR rewrote the terrain classing (`TerrainClass`, 67 lines, plus `SprinkleRareFeatures`). Curse, Pools and CoK are close to each other (0.87 to 0.94 on ScatterFeatures). The terrain-char-to-class table is game data. |
| FindPlacement | 141/123/115/150/126 | same logic | Pools and CoK are 0.94 to each other. |
| PlaceAllCreatures | 96/111/118/166/117 | branches | Pools adds `PrepareCombatOccupancy` (32 lines). |
| CombatStart, InitCreatureCombatData, LoadCombatTileSet | 23-65 | branches | Per-game GBVM fields, tile sets and reset fields (Secret's `usedTurnUndead` stays though Secret has no Turn). |

### CombatAi

| Routine | Lines | Class | What differs |
|---|---|---|---|
| CombatAiControl | 55/58/56/65/58 | same logic | Pools tries an item before a pending spell (POR-0150 is missing there; see the fixes table). |
| AiMoveAttack | 114/119/104/126/129 | same logic | The same loop and target-lock test in all five. Bandaging is in all five. |
| AiMoveStep, CanStepDir, AiCanStep | 100-115, 32-54, 12-62 | branches | CoK's AiCanStep is 62 lines (it folds CanStepDir in). Cloud avoidance: `AvoidsCloud` (PoR) versus `AvoidsStinkingCloud` and `AvoidsCloudkill` (Curse); the others test inline. |
| RouteToEnemy | 57/65/-/-/- | same (PoR from Curse) | Only PoR and Curse (#769). |
| SelectSpellToCast | 51/91/64/48/61 | diverged | PoR, Curse, Secret and CoK use SSI's list scan. Pools has a priority picker (`PickCastableSpell`, `SortCastableSpells`, `PickInnatePower`, `IsPureMage`) with a fighter-level damper. Curse and Pools have innate powers (`CastInnatePower`, `InnateCasterLevel`). |
| SelectItemToUse | 41/48/42/14/52 | diverged | **Pools' always returns False** (SSI's Pools never lets the AI use items). |
| DecideCastSpell (+AreaHitsNonEnemy) | 34/54/50/-/57 | same logic | Pools replaced it with `CbtActs.RateSpell` and `RateSpellTarget`. |
| CheckMorale | 61/50/46/50/60 | same logic | Same rule. Pools drops the IsNpc check for `npc <= $7F`. PoR no longer removes bite-hold twice. |
| EquipWeaponAndShield / EquipWeaponAndArmor, CalcWeaponPriority | 135/125/119/228/150 | same logic, branches | Pools' version is twice the size (weapon classes, two-handed and multi-attack). |
| TurnUndeadAI, QuickLine, AllToManual, CheckKeystroke, FinishRound, ToggleQuickMagic | 9-50 | near/same | |

### CbtActs (attacks, movement, aiming, turning)

| Routine | Lines | Class | What differs |
|---|---|---|---|
| DoAttack / RollAttacks | 136/136/116/116/124 | same logic | Almost all of the difference is naming (diff read). PoR adds its rules fixes: Large bit only, IsBackstab once. |
| CombatAttack / MakeAttack, ProcessAttackResult, NoteAttackDirection, GuardersAttack | 14-82 | same logic | ProcessAttackResult is 0.85 to 0.95 among the four ports. |
| CalcWeaponDamage | 25/34/26/31/38 | branches | Backstab multiplier: (thief level - 1) div 4 + 2, held to 255 in a LongInt (Curse, Secret, CoK; PoR now uses `WeaponDamage`). **Pools caps the multiplier at 5** and keeps damage in an Integer. Secret and Curse add the earlier-class thief levels (dual class). |
| AttacksOfOpportunity / MoveOpportunityAttacks | -/123/133/136/138 (PoR 107) | same logic | All five give one attack and restore the attacker's state (CURSE-0279, from Curse). Pools restores no sweep because it has none. |
| AttemptFlee / CombatFleeAttempt | 26-30 | near | 0.95 to 0.98 among the four ports. |
| RecalcAttacksLeft, AttacksFromRate | 11-45 | data-only/near | AttacksFromRate is identical in Curse and Secret. |
| SweepAttack | 56/55/55/-/52 | same logic | No sweep in Pools. |
| CanTarget | -/29/35/31/23 | same logic | PoR's is `CanAttackTarget` (0.78 shape). Pools adds an allowAlly parameter. |
| CombatTurnUndead, FindTurnUndeadTarget | 59/88/-/78/71 | diverged in rules | **Secret has no Turn Undead** (no menu item, no routine). Curse has `PaladinTurningLevel` and `TurningLevel`. Pools has the paladin at level - 2, an ECL penalty (`turnUndeadPenalty`), repeated attempts, 1d6+6 destroyed, and a level cap of 13. CoK is like Pools with a level cap. PoR moved the tables to ClassCal (`TurnLevel`, `TurnValue`). The turning table is game data. |
| SelectSpellTarget (+AimMarker, StartAimPreview, Bolt, Cone), TraceAimBolt, TraceAimCone, FaerieFireWeight | 7-149 | same or data-only in Curse, Secret, Pools | The aim preview is shared by Curse, Secret and Pools (Bolt and Cone 0.97 to 1.0). CoK has no preview. PoR rewrote its own (`AimMarker`, `AreaRuleOf`, `ShowAreaTally`). Pools has its own area tally, `ReportAreaCatch` (129 lines, PoR's `ShowAreaTally.Add` at 0.91), and `TraceAimMeteor`. |
| SelectCombatTargets / CombatCastTargetMenu | -/151/148/152/150 (PoR 113) | branches | The cast-target menu hook. |
| CastSpellCombat, IsBackstab, AnimateMissile, CheckAttackAlly, AimTargetMenu, ManualAimCursor, CombatAimMenu, AcquireTarget, ConfirmAttackTarget | 25-236 | same logic, branches | CombatAimMenu is 127/133/187/236/178 (Pools' groundOk and extra modes). |
| DirTowardTarget | 8/47/44/36/45 | moved | It lives in CbtActs, CbtMap or CharHlp per port. PoR's is a wrapper (`Pathing.DirToward`). |
| VictoryCheat / StingVictoryCheat | 28/28/28/37/29 | near | |
| Game-only specials | | game data | Curse: AttackEngulf, AttackHug, AttackClawRake, LoseMirrorImage, ListAdjacentEnemies. Curse and Pools: AttackEyeRays (+RayBeam, LosTrace; beholders). PoR and Curse: BiteAndHold. PoR: RearClawRake. Pools: UseLeadership (+LeadershipRoll), AimImmune, RateSpell, RateSpellTarget, AimAreaSpell. All are reached through each game's effect-handler table (effect ids 57, 87, 96, 139, 144 in Curse; 117 in Pools; 73 and 74 in PoR). |

### CbtMap

| Routine | Lines | Class | What differs |
|---|---|---|---|
| ViewCoordsValid | 9 x5 | **identical** | |
| CalcGridDeltas, CombatCellX, CombatCellY, GetIconSize, DrawCellCreature, DrawCellTop | 9-16 | data-only | |
| BuildViewBuffer, ScrollView, SetCreatureFacing, CombatIconVisible, CombatSlot, ProbeDirection, IsValidCreatureLoc, TickSpellPreview, EraseSpellPreview, InAimFootprint | 9-63 | near/same | CoK's ScrollView also shows EXPLODED creatures. |
| RestartSpellPreview, StartSpellPreview, StopSpellPreview, AddAreaCell, DrawAreaCell, RepaintCell | 12-64 | same in Curse, Secret, Pools; none in CoK | PoR reports area catches through the `aimReport` hook. |
| CreatureDowned, NewBodyEntry / DownedEntry / RegisterDowned | 59-78, 17-27 | same logic | The downed-body table. |
| CountTargets, CalcDistance | 21-49 | same logic | They live in CbtMap or CharHlp. |
| SetCombatPalette, SetNoncombatPalette | 5-11 | data | Secret and Pools have none (VGA). |
| Cloud layers | | diverged | Curse: CloudCell, CloudTile, CloudHasCell, TopCloudAt, AddCloudCells, GroundAt. Secret: CloudCellAt, CloudList, CloudTileAt, IsCloudTile. CoK: CloudCovers, GroundAt. Pools: DrawTerrainCell, ResolveTerrain (generic cell patches). Each game draws its own set of lingering area spells (stinking cloud, cloudkill, blast, acid pool) over the arena. |

### Pathing

| Routine | Lines | Class | What differs |
|---|---|---|---|
| SignOf, SortTargets, PathFind, NextPathStep | 11-55 | data-only (four ports) | PoR restructured them (0.38 to 0.62 tok). Among the others, PathFind and NextPathStep are shape-identical. |
| WalkLine, IsDirToward, BuildTargetList | 32-83 | same logic | Curse, Secret and CoK are at 0.93 to 1.0. |
| CanStand, Reaches, RouteStep (#668) | 29/74 | same, except CoK | **CoK has no RouteStep**: SSI's straight-line step. |
| MarkGoals, NearGoal, GoalReached (#769) | PoR and Curse | same | |
| GetIconTileDelta / FootprintCell, GetArenaContents | 12-19 | data-only | |
| PoR-only | | | OnArena, LastSlot, SaveTargets, RestoreTargets, DirToward, TargetArea, BuildAreaList (09af182; helpers worth taking with the core). |

### PostCbt

| Routine | Lines | Class | What differs |
|---|---|---|---|
| AwardExperience | 15/33/32/50/39 | same rule, branches | The prime-requisite 10% and the multiclass div 2 / div 3. PoR moved it into `ClassCal.ExperienceShare` (permanent Strength, POR-0174). Curse reads `.permanent`, Pools and CoK `.base`, **Secret `.cur` (POR-0174 bug present)**. **CoK's cleric threshold is Wisdom > 14** where every other class and game uses > 15 (check against the disassembly). Secret skips the award on `zone0.noXpAward`, Pools and CoK on `mirrorDuel`. Pools sets `levelCapped`. |
| DetermineLootExp | 59/68/67/76/76 | branches | The per-hit-point XP term (Byte x Byte product, #459) is in PoR, Curse, Secret and CoK. **Pools has no per-hp term and adds coin and gem XP** (`moneyPool[0]*2`, `[1]*250`). |
| DetermineCombatResults | 108/157/105/93/130 | branches | Only Curse and Pools have the duel / mirror-duel branch (`C_Gbvm.MIRROR_DUEL`). The revive flag is in Curse onward. |
| PostCombat, PostCombatSummary, LootMenu, LootTakeMenu, LootTakeItemMenu, LootTakeItemSelection, PostCombatCreatureCleanup, NpcTreasureShare | 19-83 | same logic, branches | LootTakeItemMenu is at 0.88 to 0.95 everywhere. NpcTreasureShare is at 0.93 to 0.96 (Pools has none). |
| Game-only | | | Curse: StripFightEffects. Secret: PurgeTreasureItems. Pools: CoalesceItem. CoK: BankPoolClone. |

### CbtLog

PoR and Pools only: Clear, Add, NextLine, Heading and Entry match (Heading is identical). PoR adds the EMS paging (Ems,
DriverThere, FreePage, MovePage, Startup, GetSlot, PutSlot, Usable, Active, Count). It is shareable as is. Curse, Secret
and CoK have no combat log.

### PoR-only routines with equivalents elsewhere under other names

MoveOpportunityAttacks = AttacksOfOpportunity (0.84 shape). CanAttackTarget = CanTarget (0.78).
CombatCastTargetMenu = SelectCombatTargets (0.53, rewritten). RearClawRake ~ Curse AttackClawRake (0.49).
AreaHitsNonEnemy = DecideCastSpell.AreaHitsNonEnemy (0.61). RegisterDowned ~ NewBodyEntry / DownedEntry.
TerrainClass replaces TerrainClassOf. AvoidsCloud replaces Curse's AvoidsStinkingCloud and AvoidsCloudkill.
AimMarker = SelectSpellTarget.AimMarker. ShowAreaTally ~ Pools ReportAreaCatch.

Genuinely new in PoR (the 2026-10-25 review's shared helpers): StepCreature, AttackWithReadied, WeaponDamage, AmmoLeft,
ResetFlanking, WeaponCanStrike, ShowRange, HostileSpell, AimSpellName, OccupantAt, AddCaught, ReportCaught,
DrawPreviewArt, Pathing.OnArena, LastSlot, SaveTargets and RestoreTargets. Each gathers code the other ports still have
written out inline.

### PoR fixes against the ports (spot-checked in the code)

✓ fixed; ✗ the bug is present; n/a the code path does not exist in that game. "Origin" says which way the fix travelled.

| Fix | Origin | Curse | Secret | Pools | CoK | Evidence |
|---|---|---|---|---|---|---|
| Free attack on a creature stepping away is one attack, state restored (CURSE-0279, #711; sweep #770) | Curse to PoR | ✓ | ✓ | ✓ (no sweep to restore) | ✓ | `savedAttacks`, `savedSweep` in AttacksOfOpportunity |
| Escape after a bump attack restores only the later steps (CURSE-0280) | Curse | ✓ | ✓ | ✓ | ✓ | MoveMenu resets saved* after MeleeAttack |
| AI target lock tests `hostile = own side` (CURSE-0286) | Curse | ✓ | ✓ | ✓ | ✓ | AiMoveAttack |
| Hostile cleric heals only its own side's downed (CURSE-0285) | Curse | ✓ | ✓ | n/a (no downed-cure AI) | ✓ | FindCureTarget |
| AI bandages a dying teammate (#654) | Curse | ✓ | ✓ | ✓ | ✓ | AiMoveAttack |
| RemoveSpell takes the interrupted creature (POR-0148) | ports to PoR | ✓ | ✓ | ✓ | ✓ | `RemoveSpell(cr, id)` |
| AI copies and clears spellCast before casting (POR-0149) | ports | ✓ | ✓ | ✓ | ✓ | CombatAiControl |
| AI resolves a pending spell before an item (POR-0150) | PoR | ✓ | ✓ | **✗** (item first; harmless while SelectItemToUse is a stub) | ✓ | pod combatai:175 |
| BFS route round walls and bodies (#668) | Curse/PoR | ✓ | ✓ | ✓ | **✗** | no RouteStep in CoK |
| Route to the nearest of a goal set, through own side, around clouds (#769) | PoR, Curse | ✓ | **✗** | **✗** | **✗** | RouteStep(slot, targetSlot) only |
| Runaway-turn guard follows movement (#803) | PoR | ✓ | **✗** (`rounds > 20`) | ✓ | ✓ | ssb combatai:538 |
| Runaway guard ends the pass (POR-0215, 82449ee) | PoR, 2026-10-25 | **✗** | **✗** | **✗** | **✗** | the pass continues after FinishRound |
| A mover left helpless by free attacks does not step (#933, 3b068af) | PoR, 2026-10-25 | **✗** | **✗** | **✗** | **✗** | only `enabled`/`inPlay` is tested before CombatMoveCreature (the AI path tests IsHelpless after the step in Secret, Pools and CoK) |
| FindPlacement starts with nothing placed (POR-0201, #813) | PoR | ✓ | **✗** | ✓ | ✓ | ssb sets `placed := 0` only in the off-grid arm |
| CalcDistance on an empty target list (POR-0196, #808) | PoR | ✓ (count guard) | ✓ | ✓ | ✓ | |
| BuildTargetList records a line of sight of any length (POR-0195, #807) | PoR | ✓ | **✗** | ✓ (Word $FFFF) | **✗** | `bestDist := 255` |
| Per-hp XP product cannot wrap (#459) | PoR | ✓ | ✓ | n/a (no per-hp term) | ✓ | `LongInt(...) *` |
| Won duel awards loot and XP once (f19da0e, #930) | Curse/PoR | ✓ | n/a | **✗** (awards inside the loop) | n/a | pod postcbt DetermineCombatResults |
| Backstab damage held to 0..255 (8826849) | Curse to PoR | ✓ | ✓ | n/a (Integer, x5 cap) | ✓ | CalcWeaponDamage |
| ScrollView tests nil and size before the creature (POR-0214, 70a78e0) | PoR | ✓ | ✓ | **✗** (`p^.inPlay` first, loops to arenaCount) | ✓ | pod cbtmap ScrollView |
| Died count only on death (#790) | PoR-only bug | ✓ | ✓ | ✓ | n/a (no Stats) | EndOfRound |
| ACTION_START effects once a turn (POR-0204) | PoR-only quirk | n/a | n/a | n/a | n/a | no CombatMenu fires them |
| Space and Alt-M the same from the menu and the AI turn; extended '2' and '-' (POR-0166, POR-0154) | PoR | ✓ | ✓ | ✓ | ✓ | CheckKeystroke `ext` |
| Prime-requisite bonus on permanent Strength (POR-0174) | PoR | ✓ (`.permanent`) | **✗** (`.cur`) | ✓ (`.base`) | ✓ (`.base`) | AwardExperience |

Missing fixes by port: Curse 2 (POR-0215, #933). Secret 7 (#769, #803, POR-0215, #933, POR-0201, POR-0195,
POR-0174). Pools 5 (POR-0150, #769, POR-0215, #933, duel once, POR-0214). CoK 5 (#668, #769, POR-0215, #933,
POR-0195). One shared core closes all of them.

### Proposed shared combat core

The shared part is one engine. Turn loop: CreatureAction, EndOfRound, ManualControl, MoveMenu and MeleeAttack. Attack
resolution: RollAttacks, MakeAttack, ProcessAttackResult, CalcWeaponDamage, AttacksOfOpportunity, AttemptFlee and
Recalc/AttacksFromRate. Then CombatSt's placement, CbtMap's view, cells and downed bodies, all of Pathing (PoR's version
with RouteStep and goal sets), CombatAi's move/attack loop and morale, PostCbt's results and loot, and CbtLog. Before
any of it can be shared:

1. **Name unification (step 0, outside the cleanup spec).** One name per creature field, combat-record field, GDVars
   list or counter, and `C_Cond` / `C_Status` / `C_Side` constant. The values agree, so this is a source-only change.
   The record layouts can differ per game, provided each field keeps its name.
2. **Per-game parameters (a `GameRules` record or consts):** round limit on or off; demo mode; the turn-order scheme
   (`PICK_NEXT` for PoR and Curse, `SORTED_QUEUE` for Secret, Pools and CoK); haste aging deaths (Secret, Pools);
   backstab multiplier cap (none, or 5 in Pools); prime-requisite threshold (CoK's Wisdom 14 to verify); the XP
   source (per-hp term, or Pools' coin and gem XP); the no-XP flag's GBVM address; whether there is a duel branch;
   Turn Undead on or off (off in Secret); turning-table columns, paladin offset, level cap and the ECL penalty
   address; whether there is a sweep (none in Pools); whether there is a wilderness arena (none in Secret); the
   combat menu item string (Turn/Yell/Quick/`*`).
3. **Per-game hooks (procedure variables, as PoR's `aimReport` and `boltTracer` already are):**
   - `OnCombatStart` (Pools UseLeadership; condition 24 in Pools and CoK), `AfterAction` (CoK exploding creatures),
     `OnRoundEnd` (Pools CountDownAreaEffects).
   - `AiPickSpell` and `AiPickItem`: SSI's list scan for PoR to CoK, Pools' priority picker and its no-items stub.
   - Area layers: one generic "lingering area" list `(kind, cells, owner, strength)` with a per-game kind table
     (stink, cloudkill, blast, acid pool, Pools' cell patch) to replace the five cloud implementations in CbtMap,
     CombatDoneCleanup, AvoidsCloud and ConsiderTerrainEffects.
   - Special attacks stay effect handlers: eye rays, engulf, hug, claw rake and bite-hold are installed by each
     game's effect table, as now.
   - The terrain-class table for the wilderness arena and the arena tile sets are game data (GDConsts).
4. **What stays per game:** the menu text, the specials listed above, Pools' Leadership and spell rating, and CoK's
   exploding creatures and acid pools.

**Risks.**
- The save format is not touched: combat state is not saved (only `combatAddr`, rebuilt each fight).
- The `Types` creature and combat records differ per game in field order and size (Secret's `flankCountV1` and
  `otherV1`). Shared code needs field names only, but any code that relies on offsets (`Mem` or `Move` over records)
  must be found first.
- DOS overlays: CbtActs is 2.1k to 2.8k lines per game. A shared CbtActs carrying every game's branches grows the
  overlay. Game-only specials should live in per-game units that the hooks reach, not in `case game of` arms.
- The byte-matched disassembly trees are unaffected; this is about the ports.
- Secret has no Turn Undead. That may be faithful to SSI or a port gap; check it against Secret's disassembly before
  making it a rule switch. Check CoK's Wisdom > 14 the same way.

## 7. Effects: FxEngine, EffHndlr and the effect handler table

Sources: each repo at origin/main (PoR 109f2c2, Curse 34eaebd, Secret b49f824, Pools 33ddd3b, CoK f132af3), exported
under `gp/<game>/src`. Tools: `gp/tables.py effect` (id -> handler), `gp/effconc.py`, `gp/summ.py fxengine|effhndlr`,
`gp/show.py <routine> raw`. Similarity figures are difflib ratios on comment-stripped tokens. "Shape" means the same
ratio with identifiers replaced by a placeholder, so it measures logic and ignores naming.

### 1. The effect record, the handler type and the table

| | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| Effect node | `TEffectRec` id:Byte, duration:Word, strength:Byte, onRemove:Boolean, next | `TEffect`, same layout | same (field `minutes`, onRemove Byte) | same (onRemove Byte) | same |
| Handler type | `(creature: PCharRecord; effectData: Pointer; removed)` | `(cr: PCreature; effectNode; removed)` | `(var cr: PCharRecord; p; removed)` | `(var cr; p; removed)` untyped | `(var creature; handlerData; removed)` untyped |
| Table | `GameVars.effectFns[BLESS..RECENT_CURE]` (1..141) | `GDVars.effectHandlers[1..150]` | `effectHandlers[1..119]` | `effectFns[1..LAST_ID=130]` | `effectHandlers[1..119]` |
| Filled by | `GameInit.InitEffectHandlers` | `GameInit.InitEffectHandlers`, Magic overrides some in `InitSpellFns` | `GameInit.InitEffectHandlers` | `EffHndlr.InitEffectHandlers` | `EffHndlr.InitEffectHandlers`, Magic overrides 4/6/104 |
| Item-granted effects | ids 128..139 (READY_*) all route to `EffReadyItem` | `overrideFlag` + `overrideEffectHandler` (EffGrantItemEffect) | `overrideFlag` + `overrideHandler` | `itemEffectOverride` routes to id 127 ITEM_EFFECT | `overrideFlag` + `overrideHandler` |
| Ids named in `C_Effect` | 141 (all) | ~35 | ~15 | 130 (all) | ~10 (rest are literals) |

The node is the same 9 bytes everywhere, so the save format of an effect list is common; only the meaning of the id
byte differs. The handler signatures differ only in parameter passing (value pointer, `var` typed, `var` untyped);
that is a mechanical unification, but untyped `var` in Pools/CoK changes every handler's casts.

### 2. Effect id concordance

Full table: `gp/eff-table.txt` (id -> handler in each game) and `gp/effconc.json` (handler family -> ids per game).

| Range | Finding |
|---|---|
| 1..56 | The PoR block every game inherits. **43 of 56 ids mean the same in all five** (1 Bless, 2 Curse, 5, 8-12, 14-17, 19-26, 28-31, 33-34, 36-39, 41-47, 49, 51-53, 55-56). Some are null handlers in one game (Secret 12/14/16/55, PoR 16/55) but the id still names the same thing. |
| 1..56 differing (13) | 3 (PoR Undead Slayer / others Sticks to Snakes), 4 (PoR Train Start / Dispel Evil / CoK breath), 6 (Flame Tongue PoR+Curse / Immune Electricity Secret+Pools / CoK Dragon Breath), 7 (PoR Train Manual / Curse Faerie Fire / Secret, Pools gnome to-hit / CoK set attack damage), 13 (Reduce / Engulfed / Barkskin / Revive as Mad), 18 (gnome THAC0 PoR+Curse / half-elf resistance Secret, Pools, CoK), 27 (Feather Fall null / helpless / confused lose turn), 32 (Animate Dead PoR+Curse / Dispel Evil touch Secret+Pools / CoK Animated), 35 (Allied Prayer / Confusion), 40 (cast Stinking Cloud / Rakshasa in Pools), 48 (gnome AC / CoK Immolate), 50 and 54 (PoR rot and dragon aura / fire and cold vulnerable / Pools fire shield hot, cold). |
| 57..max | Three numberings. PoR's own (57..141: its monsters, READY_* item ids). Curse's (57..150). A Secret numbering (57..119) that Pools extends to 130 and CoK shares in part. **Only 4 ids above 56 mean the same in all five**: 61 fire resistance ring, 62 regeneration, 64 poison attack, 89 displacement. Secret, Pools and CoK share 63, 73, 86, 95, 105, 111, 112, 113 among others. |
| Renumbered (same handler, different id) | elf resistance PoR, Curse 107 / Secret, Pools, CoK 95; half-elf resistance PoR, Curse 124 / others 18; ranger damage bonus Curse 134 / others 105; fear Curse 142 / others 111; zap attacker Curse 143 / others 112; recent cure PoR, Curse 141 / Secret, Pools 110; dispel evil touch Curse 145 / Secret, Pools 32; immune electricity Curse 135 / Secret, Pools 6; giant strength Curse 146 / Secret, Pools, CoK 113; strong poison PoR 70 / Curse 70 / others 86; dragon fear PoR 81, Curse 149, Secret 82, Pools 100, CoK 72; need-magic-weapon PoR 119, Curse 119, Secret 60, CoK 103. |
| Game-only | PoR about 40 (its monster touches, trolls, mummy, READY_*), Curse about 30 (engulf, hug, eye rays, aimed gazes, spit acid), Secret about 12 (swallow whole, delayed blast fireball, iron golem), Pools about 20 (dragon breaths by colour, vorpal, dancing, mind blank, iron skin, beholder rays), CoK about 22 (Krynn: Dragonlance, draconian transform/explode on death, acid pool, disruption, evil stench, level bucket). |

**Saves.** A character's effect list goes into the save file as raw (id, duration, strength, onRemove). The ids
must stay per game, as each game's saves and ECL scripts (which add effects by number) use them. A shared catalogue
therefore sits beside the ids, never in place of them:

- a semantic enum `TFx` (fxBless, fxCurse, fxProtEvil, ..., one member per distinct handler across the five games,
  about 230);
- per game, `fxId: array[TFx] of Byte` (0 = not in this game) and its inverse `fxOf: array[1..LAST_ID] of TFx`, both
  typed consts in the game layer;
- shared code names effects by `TFx` and turns them into ids through `fxId`; save files and ECL keep the bytes.

Packing in `strength` is also per game and goes with the catalogue: caster level is the low nibble (cap 15) in PoR,
Curse, Secret and CoK but 5 bits (`and $1F`) in Pools, which has casters above 15; Haste's "aged" bit is $10 except in
Pools ($20, for the same reason); the Prayer side bit is $10 in PoR/Curse/CoK and $80 in Pools.

### 3. Handler bodies

Counts are over EffHndlr routine families matched across games by name, then by body (`gp/families.json`).

| Class (median pairwise shape ratio) | Families | Examples |
|---|---|---|
| In all five games | 41 | EffBless, EffCurse, EffShield, EffHasted, EffDisplaced, EffPrayer, NullifyAttack, AddEffectIfNoLock |
| Same logic (>= 0.95) | 7 | NullifyAttack, EffImmobile, EffCamouflage, EffFightOn, ResetDisplacement (Pools, CoK) |
| Small differences (0.80-0.95) | 93 | most of the 1..56 block |
| Medium (0.60-0.80) | 36 | |
| Diverged (< 0.60) | 2 | EffMirrorImage (PoR's ImageStruck/LoseImage), EffDragonFear (PoR team compare, per-game fear rules) |
| One game only | 115 | PoR 54, Curse 25, Secret 13, Pools 13, CoK 10 after matching |

What the "small differences" are, read across the 1..56 block:

1. **Naming of globals:** `GDVars.attackRoll` / `gAttackRoll` / `lastAttackRoll`; `saveRoll` / `modifiedSaveRoll` /
   `FxEngine.gSaveRoll`; `damage` / `pendingDamage` / `currentDamage`; `combatMorale` / `morale` / `moraleCheck` /
   `effectScratch.morale`. One name per concept in the shared unit.
2. **`if removed then Exit` guards** in Secret and Pools (an SSI change after Curse); PoR, Curse and CoK leave them out.
   Behaviour-neutral where the effect has onRemove = False, so the guard can be universal.
3. **Ids written as literals or constants:** `spellId = 15` (Pools, CoK) / `C_Spell.MAGIC_MISSILE` (Curse, Secret) /
   `currentSpellBeing in C_SPELL.MAGIC_MISSILES` (PoR, the wand fix).
4. **Record layout:** PoR `acCur` is a scalar; the others have `acCur[0]` / `acCurArr[0]` / `armorClass[0]` (front and rear AC
   in one array). Same rule, different field.
5. **Real rule differences inside a shared handler**, each one a game parameter or a PoR fix:
   - EffHasted: PoR and Curse go through `CharHlp.HasteSlowRate` (POR-0173); Secret and CoK double the rate, Pools
     doubles both rates, Secret and Pools set an aging flag that `AgingDeaths` reads.
   - EffProtEvil: Pools needs the attacker on the other side; Curse, Secret and CoK don't; PoR's `Protection` does
     (POR-0183).
   - EffDiseaseStrength: Curse, Pools and CoK add HELPLESS once; Secret adds it every hour (no HasEffect test). PoR
     counts the Strength taken (CURSE-0333).
   - EffPetrifyingGaze: same core (gazes, animation, mirror reflection, save vs petrify, stone). It differs in the
     target picker (Curse/Pools `AcquireTarget(range 3)`, Secret the cast menu for spell 61, PoR `PetrifyGazeReaches`),
     the mirror test (Curse item name 118, Secret/Pools effect 72 MIRROR_READY, PoR `IsMirror`), Pools'
     IMMUNE_GAZE and PoR's silver shield (#981).
   - Poison and paralysis touches (`PoisonTarget`/`ParalyzeTarget`; PoR `PoisonTouch`/`ParalysisTouch`): the same fix
     for wards was written four ways. Curse tests ids 111/125 inline; Secret routes through AddEffectWithMessage;
     Pools uses AddEffectWithMessage with `mundaneTouch`; CoK tests id 99 inline; PoR has `TouchImmune` on
     `FxEngine.EffectImmune` plus the Con poison save (25 rule) and the Bestiary hook. Secret and Pools ignore
     ParalyzeTarget's `minutes` (always 10).

### 4. FxEngine core

| Routine | Status across games | Hooks it needs |
|---|---|---|
| AddEffect | Same logic in all five (shape 0.94); CoK lacks the `Stats.Count(POISONED)` line (CoK has no Stats unit). | Stats hook (no-op in CoK). |
| RemoveEffect | Two orders. PoR and Secret run the handler before unlinking and re-check the node; Curse and Pools unlink and then run it. All four of Curse-Pools then call `RecalcAbility` for Friends/Enlarge/Strength/Giant Strength (ids 14, 12, 38, plus 146 Curse or 113 Secret/Pools). PoR has no RecalcAbility; it restores stored values (`AdjustForNewStrength`). CoK walks with a `Listed` test like PoR's `HasEffectNode`. | List of ability-affecting effect ids per game, or one ability model (see risks). |
| CallEffectHandler | Range check plus the item-effect override (above), different in each game. PoR has no override. | `itemEffectHook`. |
| TriggerEffect / EffectFires / EffectSource | One idea in five versions: own effect first, else an aura from a carrier in range (1 square, Prayer 6). Curse `EffectFires(side)`, Secret `EffectFires` (no side), Pools/CoK/PoR `EffectSource(side, var eff)`. Paladin aura rule in Curse/Secret/Pools. | Aura id set per game (21, 45, 46, 49 plus 8 for the paladin). |
| TriggerEffectsWithCondition | Conditions 0..19 mean the same in all five (PoR names them in `C_COND`; Pools/CoK name some; Curse/Secret use literals). Curse, Secret, Pools and CoK add 20..24. The body is a per-game list of effect ids per condition, in an order that matters (CURSE-0329). Specials in the lists: TriggerPrayer, TriggerProtection(FromEvil), CheckSpellResistance (Secret/Pools/CoK), CancelIfImmune and ResetDisplacement (Pools). Shape ratio 0.05 to 0.69: this is data, not logic. | Per-game condition table (below). |
| AttackRoll / AttackRollNoAttacker | Same in all: d20, 1 misses, 20 becomes 100, conditions 10 and 16, `forcedMiss`, `>=`. Differences: zone THAC0 modifiers (Curse `PARTY_THAC0_MODIFIER`); Secret/Pools/CoK add a difficulty adjustment (+2..-2, named ATTACK_STYLE / difficulty / LIGHT_LEVEL); Pools' `beheadEligible` (vorpal, roll > 16); Secret also triggers condition 16 on a natural 1. PoR folds both into `RollToHit`. | Difficulty hook, a post-roll hook for vorpal. |
| RollSavingThrow | Same skeleton (1 fails, 20 saves, saveBonus + modifier, condition 12, saves[type]). Pools: DANCING forces a 1. **CoK: a mage's robe order and the moon phase (GBVM var robeOrder + $1F8) give -1/+1.** | Pre-roll hook (Pools dancing) and a modifier hook (Krynn moons and robes). |
| Magic resistance | **Two models.** PoR and Curse: MR is an effect (PoR 104/105, Curse 105/106) whose handler `MagicResistance(n)` rolls. Secret, Pools, CoK: a `magicResistance` byte on the creature record, checked by `CheckSpellResistance` under conditions 6 and 9. | A field in the record in three games: the record layout decides, so both models stay behind one call. |
| KillCreature (PoR `InflictStatusMsg`) | Same core in all (shape 0.83 to 0.92 among Curse-CoK). Curse, Secret and Pools count deaths through `Stats.Downed`; PoR `Stats.Death`; CoK none. | Stats hook. |
| TimeOutEffects | Four placements (PoR FxEngine, Curse/Secret Clock, Pools/CoK GameTime), all with a LongInt total (#444 is everywhere). Secret's `EXPIRING` marker loop differs from PoR's MAX_EXPIRING batch. | None. Pick one. |
| StrengthModifier, StrengthEffectToStrength, ClampScore, SurvivesRaise, RemoveInvisibility, RemoveEffectWithMessage | Identical or nearly so (shape >= 0.95); PoR moved the first three to AbilAdj. | Share as is. |
| InflictNonWeaponDamage, ToggleItemEffect, HasDisease/RemoveDiseases | Diverged (shape < 0.6): PoR split NonWeaponDamage out, Secret/Pools/CoK inline 70-84 lines with their element and MR model; item readying sits in ViewChar in Pools/CoK. | Element bits (ELEM_*) per game. |

### 5. PoR's fixes in the other ports

The CURSE-NNNN numbers are quirk ids from Curse's catalogue; many were fixed in Curse first and mirrored into PoR, and
several were then carried into Secret, Pools and CoK by their own agents, often written differently. Key: Y present;
N missing; ~ present by another route or partly; n/a (the feature is not in that game).

| Fix | Curse | Secret | Pools | CoK |
|---|---|---|---|---|
| CURSE-0331 forced miss is a flag, not roll -1 | Y `forcedMiss` | Y | Y | Y |
| CURSE-0332 no-attacker roll uses `>=` | Y | Y | Y | Y |
| CURSE-0329 cough before Blind/Shield under DEFENDER_AC | Y | Y | Y | Y |
| CURSE-0086/0336 wards against poison and paralysis touches | Y inline ids 111/125 | Y via AddEffectWithMessage | Y plus mundaneTouch | Y inline id 99 |
| POR-0180 paralysis touch passes its save modifier | N (save at 0, "unused") | Y | Y | N (save at 0) |
| CURSE-0338 acid spit sets an element | Y ($10) | n/a | ? | n/a |
| CURSE-0296/0357 free cloud number, level cap 15 | Y `FreeCloudNumber` | Y (also Delayed Blast) | ~ own cell-patch clouds | Y inline loop + cap |
| CURSE-0370 Dispel walks no freed node | Y probe walk | Y | Y snapshot then re-find | Y |
| POR-0182 Dispel leaves diseases | Y | Y | Y | Y |
| CURSE-0259 hold released when no longer IMMOBILE | Y (CbtActs.BiteAndHold) | n/a | n/a | n/a |
| CURSE-0261 Animate Dead level cap and `and 1` side | Y (cap 15) | n/a | n/a | N (`teamCount[hostile]` raw) |
| CURSE-0326 read the side before KillCreature frees | ~ safe: unlink-first RemoveEffect | n/a | n/a | ? |
| CURSE-0333 disease gives back its Strength on cure | N | N | N | N |
| POR-0177 protection aura only for the carrier's side | Y | ~ paladin 8 only; 45/46 lent to anyone | Y | Y |
| POR-0178 own protection or the aura, once | Y (evil and good) | ~ evil only | Y `TriggerProtection` | Y |
| POR-0183 protection -2 under ATTACK_ROLL_DEF, attacker on the other side | ~ condition 16 yes, side no | N (under DEFENDER_AC 11; no side) | Y | ~ condition 16 yes, side no |
| POR-0184 displacement reset at combat start, not round 0 roll 0 | ~ per-combat `displacementSpent` | N (SSI's round-0 test) | Y `ResetDisplacement` | Y |
| POR-0179 readying the cloak doesn't spend the free miss; CURSE-0114 nil node | Y (nil guard in EffDisplaced) | ? | ? | ? |
| POR-0181/0190/0191 MR: a non-spell meets the listed figure | n/a (MR as effect) | N (`GetCasterLevel(spellId)` with no spell) | Y mundaneTouch | Y (level 11 when no spell) |
| POR-0192 one Prayer per side | Y side parameter | N (no side) | Y loop over sides | Y |
| cd47b95 auras lapse with a carrier not in action | ~ protection only, not Prayer | ~ paladin only | ~ paladin only | N |
| 15d62e6 aura range test restores targetCount | N | N | N | N |
| #796 every death counted | ~ `Stats.Downed` | ~ `Stats.Downed` | ~ `Stats.Downed` | n/a (no Stats) |
| #444 TimeOutEffects LongInt | Y | Y | Y | Y |
| POR-0173 HasteSlowRate (Haste and Slow cancel) | Y | N | N | N |
| POR-0210 Shield and MM immunity stop the wand | N | N | N | N |
| 15038d4 petrifying gaze with no target | Y nil exit | n/a (menu) | Y nil exit | n/a |
| e4739e2 gaze only within 3 squares and in sight | ~ AcquireTarget range 3 (no line test) | ~ spell range | ~ range 3 | n/a |
| #981 a silver shield turns a petrifying gaze | N | N | N | n/a |

Of 28 fixes checked: Curse has 14 fully and 6 partly; Secret 9 and 5; Pools 14 and 5; CoK 12 and 2 (the rest are
n/a or not found). Fixes missing in every port: CURSE-0333 (disease Strength), POR-0210 (wand vs Shield), 15d62e6
(targetCount), #981 (silver shield). Secret lags most on the aura and protection fixes (POR-0177/0178/0183/0184/0192).
The same fix written four different ways (touch wards, cloud numbers, dispel walk) is the clearest case for one
shared copy.

### 6. Proposal: the shared effects core

**Shared unit `FxCore`** (from PoR's FxEngine as the base, as it has every fix): AddEffect, RemoveEffect (PoR's
handler-then-unlink order with `HasEffectNode`), HasEffectNode, CallEffectHandler, TriggerEffect, EffectSource (side
filter, carrier in action, range from the aura table), TriggerProtection, TriggerPrayer, RollToHit, AttackRoll,
AttackRollNoAttacker, RollSavingThrow, KillCreature/InflictStatusMsg, RemoveInvisibility, RemoveEffectWithMessage,
AddEffectWithMessage/EffectImmune, TimeOutEffects, StrengthModifier, StrengthEffectToStrength, ClampScore,
SurvivesRaise, FreeCloudNumber/CloudStrength.

**Shared unit `FxHandlers`**: the handlers whose logic agrees (the 41 five-game families and most of the 93 with small
differences: Bless, Curse, protections, resistances, Charm, Shield, Silence, Slow Poison, Invisible, Mirror Image,
Enfeeble, cough, Blind, diseases, Bestow Curse, Blinking, Haste/Slow via HasteSlowRate, Prayer, displacement,
poison and paralysis touches through one TouchImmune, Feeblemind, the immunities and half-damage family as one
parameterised `ElementImmunity`/`HalfDamage(kind)`, as PoR's 15038d4 consolidation already did). Each handler names
effects by `TFx`, never by number.

**Per game (thin layer):**

| Hook / table | Fills it |
|---|---|
| `fxId[TFx]`, `fxOf[id]`, `LAST_ID` | the id concordance of section 2 |
| `RegisterHandlers`: game-only handlers into the table (PoR trolls, mummies, READY_*; Curse engulf, hug, eye rays; Pools dragon colours, vorpal, dancing; CoK draconians, Dragonlance, acid pool) | game EffHndlr unit |
| `condTable: array[0..24] of list of (TFx or special)`, in order | replaces each TriggerEffectsWithCondition body |
| `auraTable`: which TFx lend to neighbours, range, side rule (paladin 8, 45/46 side only, Prayer per side, Silence all) | data |
| `itemEffectHook` (PoR READY_* ids, Curse/Secret/CoK override handler, Pools ITEM_EFFECT id 127) | game |
| `saveModifierHook(cr, type, var mod)`: CoK moons and robes; `saveRollHook`: Pools dancing | game, nil elsewhere |
| `attackRollHook`: difficulty adjustment (Secret/Pools/CoK), zone THAC0 modifiers, Pools behead window | game |
| `magicResistance`: effect model (PoR/Curse) or record-field model (Secret/Pools/CoK) behind one `ResistsMagic(cr)` | game picks |
| Strength-nibble packing: `CASTER_LEVEL_MASK` ($0F or $1F), haste aged bit, prayer side bit | consts per game |
| `abilityRecalc`: the list of effects that change an ability (RecalcAbility games) | data |
| `statsHook` (death, poisoned counts): PoR Stats.Death, Curse-Pools Stats.Downed, CoK none | game |

**Risks.**
- Saves: ids and the strength packing stay per game; the shared code must never write a `TFx` ordinal into a node.
  PoR's CURSE-0333 count in the disease node's high nibble and its displacement bit only work if the game's packing
  leaves those bits free; Pools uses 5 bits for the level.
- The ability model is a real divergence: PoR stores restore values in Strength effects, the others recompute from
  base plus effects (`RecalcAbility`, 144 to 221 lines). Pick one before sharing EffExtraStr/Enlarge/Strength/Giant
  Strength; Curse-CoK's RecalcAbility is the more general and suits Pools' 25-Strength giants.
- Magic resistance as a record field (Secret/Pools/CoK) versus an effect (PoR/Curse) touches the creature record and
  monster data; keep both behind one call rather than converting saves.
- RemoveEffect order: Curse and Pools unlink first, which makes some fixes unnecessary there (CURSE-0326); moving them
  to PoR's order needs PoR's `HasEffectNode` re-checks with it.
- DOS: FxEngine and EffHndlr are overlays in every game; one shared EffHndlr with every game's handlers would not fit
  the overlay buffer. Keep game-only handlers in the game unit and only the shared ones in `FxHandlers`. The TFx
  tables are about 2 x 256 bytes of DGROUP per game.
- The handler signature (value vs `var`, typed vs untyped) is a mechanical change, but Pools/CoK cast through
  `Pointer(creature)` everywhere; convert in one pass with the token-proving tools.
- The byte-matched disassembly trees are untouched; this is for the port repos only.

## 8. Gameplay: magic (Magic, UsualSpl, SpellInf, spell tables, casting)

Read at origin/main of each port (PoR 109f2c2, Curse 34eaebd, Secret b49f824, Pools 33ddd3b, CoK f132af3), exported
under `gp/<game>/src`. Families and ratios come from `gp/families.json` (token ratio on comment-stripped, unit-qualifier-
stripped tokens; "shape" maps every identifier to one token, so it measures logic independently of naming). The spell-id
concordance is `gp/spell-table.txt`, handler shape ratios by id `gp/spellcmp.txt`.

Headline: the magic engine is one SSI engine under five sets of names. Every port keeps the same 16-byte spell record,
the same `ResolveSpell(spell, level, onRemove, damage, element, msg)` primitive and the same dispatch-by-spell-id table;
spell ids 1..55 and 57..62, 64, 65 name the same spell in all five games. Token-identical routines are almost nil (0 in
Magic), because each port renamed globals independently (`spellId` / `spellBeingCast` / `currentSpell` /
`currentSpellBeing`; `spellTargets` / `castTargets` / `spellTargetList` / `targetCreaturePtr`). The real differences are
few and nameable: the castClass encoding, per-spell special cases written as `case spell of` with literal ids, Secret's
messages built from tables, Krynn's moons/robes/deities, Pools' 9 spell levels, caster-level cap and VGA cast animations,
and a handful of SSI bug fixes that each port has or lacks.

### 1. Routine groups

Counts from `summ.py magic` (204 Magic families; "similar" = worst pair ≥ 0.70 token ratio, "diverged" < 0.70; the
fuzzy matcher mis-pairs many 6-line handlers, so the handler rows below are by spell id instead).

| Group (routines) | Lines (cab/pod) | Classification | What differs |
|---|---|---|---|
| Effect-applying handlers: Detection, Protection, ResistCold/Fire, Shield, Silence, Invisibility, Knock, Blink, BestowCurse, CauseBlindness, WandOfParalyzation, DustOfDisappearance, MinorGlobe, ImmuneBreath, TurnInvisible, IceStorm... (~30 ids) | 6 each | identical but for names and data. Shape vs Curse: PoR 1.00, Pools/CoK 0.97, Secret 0.80-0.86 | Secret passes `GDConsts.msgIs + GDConsts.effectNames[n]` where the others pass a literal ('is shielded'). One body: `ResolveSpell(curSpell, 0, False, 0, 0, msg)` with msg from a per-game message table. |
| Damage handlers: MagicMissile, BurningHands, ShockingGrasp, CauseLight/Serious/Critical, Fireball, LightningBolt, ConeOfCold, FlameStrike, JavelinOfLightning, WandOfMagicMissiles | 6-30 | same logic; shape 0.87-0.99 among Curse/Secret/Pools; CoK stubs for ids it does not ship | Pools' `GetCasterLevel(spell, capped)` second parameter; dice routine lives in Dice (Curse/Secret/Pools/PoR) or FxEngine (CoK). |
| Target-filter handlers: Bless, Curse, CastOneSide, HasteSlowLogic, Haste, Slow, Sleep, Hold, CharmPerson, SnakeCharm, Enlarge, Reduce, Strength | 6-55 | same logic with game branches | CoK treats spell 105 as a second Bless (`(currentSpell = 1) or (currentSpell = 105)`); Secret/Pools/CoK test a creature-type snake bit (`and $10`) and Curse `charType = 14` in Snake Charm; Secret/Pools test race/creature-type flags in Charm Person where Curse/CoK test `charType > 1 or iconDim > 1`; HasteSlowLogic's rate re-run differs (see §4). |
| Per-spell special durations `CalcSpellDuration` | 17-32 | data-only in content, code-shaped | Curse/Secret/CoK: `case spell of 26: 3780; 40: 1d6*10; 57,61: 5d4; 59: ...; 63: ...; 67: 1440 else base+perLevel*CL`; PoR and Pools already turned it into a `TDurDice` per spell (`SpellDuration`), which SpellInf reuses. Secret has no 63/67 (Youth at 63) and adds 26. |
| Area/geometry: WalkCone (Curse/Secret/Pools 163-194 lines; CoK inlines it as CollectConeTargets 155), WalkBolt/TraceBolt/LightningPath/LightningAttackAt, StinkingCloud/Cloudkill nodes (FreeCloudNumber, AppendCloudNode) | 8-194 | similar (0.72-0.94) except CoK's inlined cone and Pools' cloud | Pools replaces the cloud node list with `TCellPatch` (stinking cloud 34, cloudkill 91, Blade Barrier 101 paints terrain, ttl*3): diverged. CoK's LightningPath is 80 lines vs 10. |
| Casting flow: CastSpell / PoR CastSpellNC, ResolveSpell, ApplyEffectToTargets, NoncombatCastTargetMenu, UseItemSpell | 33-136 | same skeleton, game branches | See §3. |
| Spell lists: SpellSelection, SpellMark, AddSpellToList, AddScrollSpells, AddAllScrollSpells, AddAvailableSpells, GenerateSpellList, ClassCanCastSpell | 13-143 | diverged in detail (0.5-0.9) | number of spell classes/levels (PoR 2 lists x 3 levels; Curse+ cleric/druid/mage; CoK cleric/druid/special/mage by robe order; Pools levels 1..9), and PoR's rewrite (shared spell screen layout #906). |
| Dispel Magic (SpellDispelMagic 107-174) | | similar Curse/Secret/CoK (0.75), Pools different | all four skip the disease effects and guard the freed-node walk (Curse/Secret/CoK via a probe walk, Pools by restarting). PoR's 53-line DispelMagicHandler is its own rewrite. |
| Ports' breath effects living in Magic (EffBreatheLightning/Acid/Fire/Poison, EffDragonBreath, EffSpitAcidBreath, EffThrowFireball) | 25-67 | similar across the games that have them | installed into the effect table by Magic's init (`effectHandlers[83..90]`), i.e. game data: which effect id gets which breath. |
| UsualSpl (Find/Get/Set/Forget/Read/WriteUsualSpells) | 10-36 | near: Curse~CoK 0.93-1.00 | file layout per game (Pools 33-35 lines with rename/size checks; Curse/Secret add WriteUsualSpellsAs). Shareable as is; the usual-spells file name and record size are parameters. |
| SpellInf (PoR #839 feature; Pools #331 and CoK #354 ported it) | PoR 695, Pools 611, CoK 455 | three independent copies, diverged (0.6-0.95) | Pools keeps a hand-written save-result table (`SaveResult`: case of spell ids); PoR reads the spell record's saveResult; CoK adds moon level in caster level text. Strong candidate to become one shared unit. |

Only-in-one-port routines in Magic: PoR 25 (its refactor helpers: CureDiseaseOf, StandUpOrWake, ShowCombatOnly...), Pools
21 (PickCastableSpell, SortCastableSpells, Meteor Swarm/Monster Summoning helpers), CoK 7, Secret 4, Curse 4
(NaturalAbility, EffSpitAcidBreath...).

### 2. The spell table

#### Dispatch table (handler per spell id)

All five fill an array of `procedure` by spell id at start-up (PoR `GameVars.spellFns` in GameInit; Curse
`GDVars.spellHandlers.spells[1..100]` in GameInit; Secret `GDVars.spellFns[1..117]`, Pools `GDVars.spellFps.spells`,
CoK `GDVars.spellDispatch[1..107]`, all three in Magic's init). PoR's names are `XxxHandler`, the others `SpellXxx`.

| Ids | Concordance |
|---|---|
| 1-35, 37-55, 57, 59-62, 64, 65 | same spell, same handler, all five |
| 36 | Animate Dead: PoR, Curse, CoK (CoK's is an empty stub). Heal: Secret, Pools |
| 56 | Restoration: PoR, Curse, CoK (CoK stub). Harm: Secret, Pools |
| 58 | Cure Serious Wounds in Curse+; PoR names it KeoghtomsOintmentHandler (the item that casts it) |
| 63 | Dust of Disappearance: PoR, Curse, CoK. Youth: Secret, Pools |
| 66, 67 | Cause Serious Wounds, Neutralize Poison in Curse+; PoR uses the slots for an unused stub and the Manual of Bodily Health |
| 68-89 | same in Curse, Secret, Pools, CoK (78 Entangle; Secret has SpellNoEffect) |
| 90-100 | split: Curse/CoK one set (AnimateDead, Cloudkill, ConeBlast, BestowCurse); Secret and Pools another (Heal/Barkskin, druid cures, potions, MageBestowCurse) |
| 101-107 | CoK: Krynn's duplicate ids for Protection, Silence, Detection, RemoveCurse, Bless, CharmPerson, BurningHands (special/deity copies); Secret 101-109 SpellNoEffect; Pools 101-109 druid/cleric high-level |
| 110-117 | Secret and Pools: DeathSpell, Disintegrate, Globe, StoneToFlesh, FleshToStone, DelayedBlast (Pools: plain Fireball), MassInvisibility, PowerWordStun |
| 118-126 | Pools only: FireTouch, IronSkin, MassCharm, IrresistibleDance, Protection, PowerWordBlind, MeteorSwarm, PowerWordKill, MonsterSummoning |

CoK keeps Curse's whole table but its handlers for spells Krynn does not ship are empty (`SpellAnimateDead`,
`SpellRestoration`) or 3-line stubs documented "does nothing" (71-80, 90-93, 98).

#### Spell property record

Same 16 bytes in all five, same order: castClass, level, range base/per level, duration base/per level, area (low nibble
area mode), targeting, saveResult, saveType, effect id, when-cast (0 camp only / 1 combat / 2 either), cast time, AI
priority, offensive, AI radius. Field names differ per port (`spellTable`/`spellProperties`/`spellDefs`/`spellTbl`,
`rangeFixed`/`rangeBase`, `saveResult`/`saveEffect`, `whenCast`/`combatOk`/`castContext`). Sizes: PoR 67, Curse 100,
Secret 117, Pools 126, CoK 107.

The one incompatible field is **castClass**:

| Port | 0 | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|
| PoR | cleric | magic-user | item | | |
| Curse, Secret, Pools | cleric | druid | magic-user | item/special (caster level 12) | |
| CoK | cleric | druid (ranger) | special (deity) | magic-user | item (level 12) |

Every `case castClass of` (GetCasterLevel, AddSpellToList, Camp slot counting, ClassCanCastSpell, SpellInf) reads these
literals, so a shared core needs named per-game constants (C_Spell.CLASS_CLERIC/DRUID/SPECIAL/MAGE/ITEM) before
anything else.

### 3. Casting flow and its game branches

`CastSpell` (PoR `CastSpellNC`) is one skeleton in all five: refuse a camp-only spell in combat ("can't be cast
here... Lose it?/Use it?"), announce, loop on the target picker hook (`castTargets`/`castMenu`, swapped between
`NoncombatCastTargetMenu` and `CbtActs.SelectCombatTargets` when combat starts), face the target, sound, animate, remove
invisibility, spend the spell, count `SPELLS_CAST`, dispatch, clear. Branches:

| Branch | Where | Hook that absorbs it |
|---|---|---|
| Spell failure on low Wisdom (PoR #59/#61 rule) | Secret (`Magic.SpellFailureChance`), Pools (`ClassCal.SpellFailureChance`), CoK (`ClericSpellFails`); absent in Curse | shared rule; already mirrored three times under three names |
| Curse effect 74 (EffSpellFailure): 50% "miscasts" | Curse only | an effect, not casting code: an `OnBeforeCast` test reading a per-game "miscast effect id" (0 = none) |
| Cast animation: Pools builds 30 frames for 47/64/74/115, scatters icons for 34/91/47/64/115/87 by indoor/outdoor, skips 124 (Meteor Swarm) | Pools | `CastAnimation(spell, caster, target)` per game (presentation layer, VGA) |
| Sound by spell (Fireball, Lightning) | all; ids and sound-table indices differ | per-game `spellSound[spell]` table |
| `ExtendFight` after an offensive spell | Pools | rule switch |
| Caster level: knight-8 (CoK), paladin-8 (Pools), ranger-7/-8, item spells at 6 (CoK), `itemCasterLevel` (Pools), cap at 31 (Pools `capped`), robe-order moon adjustment (CoK) | CharHlp.GetCasterLevel | one shared GetCasterLevel with a per-game class->caster table (which class levels count, the offset) and a `CasterLevelAdjust(char, spell)` hook (CoK moons) |
| Messages: literal strings vs `msgIs + effectNames[n]` | Secret | per-game message table indexed by effect id |
| Usual-spells file and the AI's spell choice (Pools' PickCastableSpell, SortCastableSpells) | Pools | AI is combat's slice; note only |

`ResolveSpell` is the same 25 lines in all five (shape 0.77-0.89). Differences: Secret sets
`currentEffectId := SPELL_ATTACK` around the damage; PoR reads the save byte against named SAVE_* values (#860), the
others pass the raw byte.

#### Krynn (CoK) specifics

- Robe order on the character (`robeOrder` 1 White/good, 2 Red/neutral; set at creation from alignment, ChgClass picks
  it for a new magic-user); moon phase per order in GBVM zone words (`zone0^.vars[robeOrder + $4CF8]`, values 0/1/2).
- Moon effects: `CharHlp.GetCasterLevel` -1 at phase 0, +1 at phase 2 above level 5; `FxEngine.RollSavingThrow` -1/+1;
  `Camp.MoonBonusSpells` 1 or 2 extra memorizations; `ClassCal` slot progression 7 or 8 by order;
  `GDConsts.knownSpellTable[order]` the spells a mage knows per order; scribing refused without an order.
- Deities: castClass 2 "special" spells (ids 101-107 reuse handlers), deity 4 adds healing dice to Cure Light/Serious
  (`if deity = 4 then +1d8`), the special list shows for clerics not of deity 6.
- Hooks: `CasterLevelAdjust`, `SaveAdjust`, `BonusMemorize`, `HealBonus(caster, spell)`, `KnownSpells(char)`, all
  identity in the other games. The moon words are GBVM addresses and should get C_Gbvm names.

#### Secret and Pools' higher levels

Pools: spell level 1..9 (record comment), 126 spells, caster level capped at 31 for effect strength packing,
`itemCasterLevel` for scrolls, Meteor Swarm (90 lines), Monster Summoning (72), Power Words, Mass Charm, Irresistible
Dance; clouds as terrain patches. Secret: 117 spells, Delayed Blast Fireball (55), Death Spell, Disintegrate,
Stone/Flesh. These are new handlers in the table, not changes to the core: a shared core that dispatches by id needs
only the per-game table and the per-game spell record array sized by `SPELL_LAST`.

### 4. PoR magic fixes against the other ports

"Present" means the port has the behaviour (often SSI's own later code, or mirrored); "missing" means the port has the
PoR-fixed bug. Origin: P = PoR-originated, C = mirrored into PoR from Curse's record (CURSE-NNNN), S = SSI already right
in later games.

| Fix | Origin | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| Magic Missile (CL+1) div 2 (POR-0208) | S | present | present | present | present |
| ResolveSpell save byte read as a byte (#860) | P | **missing**: `Boolean(saveResult)`, and AddEffectWithMessage tests `saveNegates = True` (compiler-dependent) | SSI byte test (`= 1`), Silence never negated | as Secret | as Secret |
| Silence negated by a save (SAVE_SPECIAL, #860 ruling) | P (rule) | missing | missing | missing | missing |
| Cleric spell failure on Wisdom (POR-0061/#61) | P | **missing** | present | present | present |
| Scribe roll on Intelligence (#59) | P | missing | missing | present (GameTime) | missing |
| Aborted item spell not spent (#697) | Curse/Secret | present | present | present | **missing** (spends on `cast`, ignores EndActions; check `done`) |
| Slow Poison stands up only the downed (#698) | Secret | present | present | present | present |
| Keoghtom's Ointment only for poison deaths (#475) | P | n/a (no ointment handler at 58) | n/a | n/a | n/a |
| Haste/Slow cancel one rule, HasteSlowRate (POR-0173) | P/C | present (CharHlp.HasteSlowRate) | not found | not found | not found |
| HasteSlowLogic sets the rates before re-running (POR-0188) | S | no re-run at all | **missing** (triggers condition 18 without setting rates) | present | present |
| Snake Charm by snake, not charType 14 (POR-0193) | P | **missing** (`charType = 14`) | present (snake bit $10) | present | present |
| Charm/Hold Person by person (IsPerson, POR-0185) | P | missing (`charType > 1 or iconDim > 1`) | different SSI rule (race/flags) | different SSI rule | missing (as Curse) |
| Shield and MM immunity stop the Wand of MM (POR-0210) | P | **missing** (`spellId = MAGIC_MISSILE`) | missing | missing (`= 15`) | missing (`= 15`) |
| Burning Hands sets the damage dice to 1 (CURSE-0152) | C | present | present | present | present |
| Lowest free stinking-cloud number, level capped at 15 (CURSE-0296/0357) | C | present (FreeCloudNumber) | present (FreeCloudNumber, CloudStrength) | n/a (patch model) | present inline (caps level for the duration too) |
| Dispel Magic: no freed-node walk (CURSE-0370) | C | present | present | present (restart) | present |
| Dispel Magic leaves diseases (POR-0182) | S | present | present | present | present |
| Animate Dead side byte `and 1` (CURSE-0261) | C | present (`hostile and 1`) | missing in CharmPerson (`hostile * 128`) | present | missing in CharmPerson (`hostile * 128`) |
| #931 Bless/Haste only the caster's side, Curse/Slow only the other, by Team (d4d12bf) | P | missing (raw `hostile` byte) | missing | missing (`side`) | missing |
| #931 spell with no targets clears its element (167be29) | P | missing (sets element, exits) | missing | missing | missing |
| #931 cast facing cannot spin (167be29) | P | present (`k < 8`) | present | **missing** (`while not IsDirToward ... Inc(k)` unbounded) | present |
| #931 Friends gives back what it gave (80affe6) | P | n/a: Curse+ recompute Charisma from effects (`FxEngine.RecalcAbility`), which never had the stacking bug; PoR could adopt that model | n/a | n/a | n/a |
| #931 one cure of disease (80affe6) | P | Magic.RemoveDiseaseEffects plus separate temple/paladin paths | same | same | same |
| #931 cloud rolls once per creature (80affe6) | P | not checked in detail | not checked | present (dedups the creature per cell) | dedups per cell (dirs[]) |
| #931 SpellInf no read past the table (976ae6b) | P | n/a | n/a | n/a (hand table) | not checked |

Spot-checked per port: Curse 16, Secret 15, Pools 16, CoK 16 rows. The new bugs found while checking: CoK's item spell
spent on abort, Pools' unbounded facing loop, Secret's Haste/Slow re-run, Curse's Boolean save view.

### 5. Proposal: a shared Magic core

**Shared unit `Magic` (core)**, one body for every game:
- `ResolveSpell`, `ApplyEffectToTargets`, `CastOneSide`, `HasteSlowLogic`, `CalcSpellDuration` (driven by a per-spell
  `TDurDice` table, PoR/Pools form), `CalcSpellRange`, `LightningPath`/`WalkBolt`/`WalkCone` geometry, the cast skeleton
  (`CastSpell`), `UseItemSpell`, scroll handling (`AddScrollSpells`, `RemoveSpellFromScroll`), Dispel Magic, the cloud
  node list (FreeCloudNumber/CloudStrength), the ~45 handlers shared by id (1-35, 37-55, 57, 59-62, 64, 65 plus 68-89
  for the Curse-and-later games).
- `UsualSpl` as is, with the file name and record count as parameters.
- `SpellInf` (PoR's, which already reads the spell record; Pools' hand save table becomes the record's saveResult).

**Per game (thin layer)**:
- `SPELL_LAST`, the spell record array, spell names, the per-spell duration-dice table, the per-spell sound/animation
  table and message table (Secret's effect-name messages become just data).
- `InitSpellHandlers`: fills `spellFns[1..SPELL_LAST]` from the shared handlers plus the game's own (Secret/Pools high
  levels, Krynn specials 101-107, PoR's ointment and manual); unused ids point at `SpellNoEffect`.
- castClass constants (§2) and a class->caster table for `GetCasterLevel` (which classes cast which list, the
  level offsets, item level 6 or 12 or `itemCasterLevel`, Pools' cap).
- Hooks, identity unless a game sets them: `CasterLevelAdjust`, `SaveAdjust`, `BonusMemorize`, `KnownSpells` (Krynn
  moons and robes), `HealBonus` (Krynn deity), `CastAnimation` (Pools VGA), `MiscastEffect` (Curse effect 74).
- Rule switches: Wisdom spell failure, Intelligence scribe roll, Silence negated by save, ExtendFight after offensive
  spells, Bless/Curse sides by Team. PoR's 1st-edition rulings (tabletop rules govern) turn them on everywhere.

**Order of work**: (1) name the castClass values and spell ids per game (no behaviour change); (2) unify the global
names of the casting state (current spell, targets, element mask) so the handlers become text-identical; (3) move the
shared handlers and ResolveSpell; (4) table-drive CalcSpellDuration and messages; (5) the hooks.

**Risks**:
- Save format: memorized-spell bytes and scroll spell ids are spell ids, so the id concordance must stay per game; never
  renumber. Effect strength packs caster level (Animate Dead `hostile*16+level`, cloud number `*16`), so the 15/31 caps
  are format constraints, not style.
- Effect ids differ per game above ~56 (`gp/eff-table.txt`): handlers that name effect ids (Snake Charm's 51, Shield's
  17) must use per-game C_Effect names.
- DOS: Magic is an overlay in every port and the largest gameplay unit (PoR 2268 lines, Pools 3896). Moving all
  handlers into one shared overlay plus a per-game handler overlay keeps the size; a handler table of far procedure
  pointers works across overlays (all ports already do this), but the init must run from a resident unit.
- The byte-matched disassembly trees are untouched; this is port-only work.

## 9. Gameplay: characters and the party screens

Scope: CharHlp, ClassCal (logic), ChgClass, CharGen, CharEdit, ViewChar, CharDisp, PartyMnu, Stats, Party, AbilAdj and
training. Sources are each repo's origin/main as of 2026-10-26: PoR 109f2c2, Curse 34eaebd, Secret b49f824,
Pools 33ddd3b, CoK f132af3. The method: every routine is extracted, comments and whitespace are stripped, unit
qualifiers are dropped, and routines are paired across games by name or, failing that, by fuzzy body match (≥0.62).
Each pair gets two scores. The token ratio compares the code exactly. The shape ratio replaces every identifier with
`I`, so renamed fields and locals do not count. I then read the differences. The tools are in this folder:
routines.py, match.py, summ.py and show.py, with the results in families.json.

### Headline

- **Names hide the sharing.** Few routines are token-identical: 6 of 362 character-area families across all five
  games. Most of the remaining gap is naming. Each port names the record fields itself: `classLevels`/`oldClassLevels`
  (Curse), `classLevelA`/`classLevelB` and `...V1` (Secret), `classLevels`/`oldLevels` plus `EffectiveClassLevel`
  (Pools), `classLevels`/`classLevels2` (CoK), and `strCur` with `portExt.formerClasses` (PoR). Locals and globals
  differ the same way (`curChar`/`currentChar`, `hostile`/`side`, `enabled`/`inPlay`, `ifcState`/`interfaceState`).
  By shape, most of the four non-PoR ports agree to 0.85 or better: CharHlp has 38 of 67 families there.
- **The skeleton is one routine; the games differ in data and a few rule switches.** TrainingMenu, RecalcClassStats,
  GetCasterLevel, InflictDamage, CountTeams, ConHpPerDie, WeaponAdjust, RecalcStats and the ability-adjustment
  functions follow the same code path in all five. The differences are:
  - level caps (12 / 18 / 21 / 40) and level-indexed tables;
  - class and race ids, which CoK renumbers completely;
  - a few game features: Krynn's knights, moons and robes, Kender caps and the hoopak; Secret's scroll bundles; Pools'
    level-40 formula and training anywhere.
- **PoR has moved furthest from the others** (its best match is under 0.7 for many routines). It split CharHlp into
  CharHlp, ClassCal and AbilAdj, introduced named helpers (`TrainClasses`, `AtLevelCap`, `PermanentStrength`,
  `DiceConBonus`...) and has 33 CharHlp, 25 ClassCal, 13 ChgClass, 10 PartyMnu and 5 AbilAdj routines found nowhere
  else.
- **Fixes have already been crossing ports by hand,** unevenly. Several started as CURSE-NNNN entries (an id in
  Curse's quirk register) and are now in Curse, Secret and Pools. Most of the PoR-originated rules fixes, and all of
  the 2026-10-25 review fixes, are missing from all four other ports (table below).

### Per unit (5-game families; "4-port" means Curse, Secret, Pools and CoK only)

| Unit (home) | Families | In all 5 | 4-port identical / same shape / ≥.9 / .7–.9 / <.7 | PoR-only | Notes |
|---|---|---|---|---|---|
| CharHlp | 124 | 28 | 4 / 5 / 3 / 25 / 30 | 33 | ability adjustments, item and weapon math, damage, teams, caster level, thief skills, HP/Con |
| ClassCal | 40 | 1 | 0 / 0 / 1 / 5 / 4 | 25 | ports: RecalcClassStats, RecalcSaves, RecalcSpellSlots, dual-class tests; PoR: the rest |
| CharGen | 84 | 8 | 14 / 3 / 7 / 13 / 10 | 8 | the icon customizer is identical (PoR, Curse, Secret); creation, modify and training diverge |
| CharEdit | 18 | 0 | n/a (PoR and Curse only) | 0 | PoR↔Curse ≥0.9 in 11 of 18 routines: Curse took PoR's editor |
| ViewChar | 58 | 18 | 1 / 2 / 2 / 13 / 21 | 8 | item menus diverge most (Secret bundles, CoK steel coins, Pools HP caps) |
| CharDisp | 34 | 17 | 0 / 1 / 0 / 10 / 9 | 10 | Pools and CoK keep these in CharHlp |
| Stats | 33 | 1 | 4 / 6 / 4 / 2 / 7 | 2 | in PoR, Curse, Secret and Pools; not in CoK; Curse↔Secret mostly identical |
| Party | 4 | 1 | – | 3 | PoR's Next/Prev/LastCreature |
| ChgClass | 13 | 0 | – | 13 | PoR's dual-class screen |
| PartyMnu | 10 | 0 | – | 10 | PoR only |
| AbilAdj | 5 (+8 moved from CharHlp) | – | – | 5 | moved routines match the ports' CharHlp at 0.82–0.98 |

#### CharHlp / AbilAdj / ClassCal logic: groups and classification

| Group | Routines | Class | Game-specific branches and the hook or parameter that absorbs them |
|---|---|---|---|
| Ability adjustments | StrToHitAdjust, StrDamageAdjust, TranslatedStrength, WeightAllowance, DexMissileAdjust, DexterityArmorAdjustment | near-identical (0.85–0.99), already to 25 everywhere | none. Data and code are the same; only POR-0199 differs (Dex 0 gives -4: Secret and CoK still use `1..3`) |
| Con HP per die | ConHpPerDie (Pools: ClassConAdj), ConHpTotal | ConHpPerDie identical logic in PoR, Curse, Secret and Pools (CoK has it in FxEngine) | ConHpTotal reads per-game hit-dice limits (`constitutionBonusLevelCaps`, `firstFixedHpLevel`, `hitDiceLimit`): a table. Dual-class terms differ by record layout |
| HP floor, Con regen, Con poison save | HitDieFloor, ConRegenMinutes, ConPoisonSave | Secret and CoK have identical copies (Secret in CharHlp, CoK in FxEngine); Curse and Pools lack them | none: drop-in |
| Racial level limits | AtLevelCap (PoR) / AtTrainingLevelLimit + LimitByScore (Curse, Secret) / inline in TrainingMenu (Pools) / Kender only (CoK) | same idea, different tables | **per-game table** `raceClassCap[race, class, band]`. Each game's rows differ: Secret adds dwarf/elf/gnome cleric caps, Pools a gnome cleric 7, PoR half-orc caps, CoK only Kender fighter/ranger 7/6/5. Curse, Secret and Pools band on the permanent score; PoR on `PermanentStrength` |
| Caster level | GetCasterLevel | same logic, branched | Curse, Secret, Pools, CoK: paladin -8 / ranger -7/-8 casting, special list = 12. PoR: cleric/mage only. Secret and Pools add `if b < 1 then b := 1`. Pools adds a `capped` parameter (31). CoK uses Knight for paladin and has the **moon/robe modifier** (`robeOrder`, GBVM var 19200+504+order: -1 or +1). Item caster level is 6 (Secret, CoK), a variable (Curse, Pools) or a constant (PoR). Hooks: `CasterLevelAdjust(cr, list, lvl)` for CoK's moons; table `halfCasterOffset[class]`; parameter `ITEM_CASTER_LEVEL` |
| Damage and teams | InflictDamage, CountTeams, EnemyTeam/NotHostile, EndActions, IsHelpless | same logic | field names only. CoK lacks Stats calls and the "already dead" guard. CoK and Pools index teams by side byte |
| Weapon / AC / encumbrance | WeaponAdjust, ArmorMoveAdjust, AddItemArmorAdjust, EncumbranceAdjust, RecalcStats | similar 0.6–0.9 | racial weapon bonus: Curse elf +1 with bows/swords; CoK Silvanesti and Qualinesti elf +1, Kender hoopak +2. Hook: table `raceWeaponBonus[race] → (item set, bonus)`. Pools: `FIRES_AMMO` prop test |
| Thief skills | ThiefSkillParts, RecalcThiefSkills, ArmorBarsThiefSkills | diverged (PoR <0.3) | armor bars skills in all five (CURSE-0068 spread). Secret uses a class mask instead of "leather". PoR moved the tables into ClassCal. Hook: none; the race/Dex tables are data |
| Dual class | CurrentDualClassLevel, EarlierClassActive, FirstEarlierClass, FirstCurrentClass, DualClassAbilitiesMet, ChangeClass | Curse, Secret, Pools, CoK similar 0.72–0.99 (SSI's own human dual class, from Curse on) | PoR rebuilt it from scratch (ChgClass, `formerClasses` mask, GetClassLevel). CoK: HumanChangeClassMenu plus knight orders |
| Spell slots / saves / THAC0 | RecalcClassStats, RecalcSaves, RecalcSpellSlots/RecalcClericSlots/RecalcSpellLists, TrimMageSpells | same skeleton, branched by level cap | THAC0 cap level 12 (Curse) / 18 (Secret) / 21 (Pools); 4 attacks at fighter/paladin 13+ and ranger 15+ (Secret, Pools only); Pools' `EffectiveClassLevel`. **Absorbed by tables to Pools' maximum** plus `MAX_LEVEL[game]` |
| Item helpers | ItemLabel, BaseItem, ItemReadable, ScrollLegible, CastableScroll, HasScrollSpells, Add/Append/Prepend copies, FreeItemList | similar | Secret's scroll bundles (kind 'I', 10 a bundle) are a game feature; flag `HAS_SCROLL_BUNDLES` |

#### CharGen / training

| Group | Class | Branches |
|---|---|---|
| TrainingMenu | one skeleton in all five: trainable mask → best XP cap → hall mask → Yes/No → raise levels | **Curse:** 1000 gp fee in code, cap 12, `autoTraining`. **Secret:** cap 18, `freeTraining`, `newCharTraining`. **Pools:** no hall, no fee, cap 40, `XpForLevel` formula past level 11, `CanLevelUp`/`AdjustLevelHitPoints`/`HitPointCap`, prunes spells. **CoK:** `ClassSuborderIndex` (knight and robe orders choose the XP row), Kender caps, `knightTrainingMode` grants fixed mage spells. **PoR:** refactored into `TrainClasses` + `GainLevels`, has dropped SSI's "highest single class" pass, and adds the "No class can train further" stop |
| GainLevels / level-up tail | in PoR and Curse a routine; Secret, Pools and CoK inline | drained-level restore (Curse, Secret, CoK), ranger/paladin dual-class effect re-add (Pools), first-level HP roll |
| CreateCharacterMenu | diverged (0.41–0.70) | race/class lists (CoK races 0..6 = Silvanesti, Qualinesti, half-elf, mountain/hill dwarf, Kender, human; Knight class 7; robe order on mages), starting money (CoK steel), starting items (Pools). Shared: the age-category ability loop (same text in all, incl. the CURSE-0318 young-adult +1) |
| CustomizeIcon/Portrait | 14 nested routines identical in PoR, Curse and Secret | Pools and CoK have their own VGA icon editors |
| HpMinimum / HpMaximum / RollFirstLevelHp / ConHpBonus | diverged | per-game hit-die tables; CoK Knight d10; Pools HitPointCap |

### PoR fixes vs the other ports

Key: ✓ present, ✗ missing, ~ partly or a different mechanism, n/a the game lacks the feature. "Origin" says where the
bug was first recorded (CURSE-NNNN is an id in Curse's quirk register, so Curse does not always have the fix).

| Fix | Origin | Curse | Secret | Pools | CoK | Evidence |
|---|---|---|---|---|---|---|
| ConHpPerDie warrior bonus to 25 (#616) | Curse | ✓ | ✓ | ✓ | ✓ | `24, 25: Inc(share, 5)` in all |
| HitDieFloor (D&DG) | PoR #646 | ✗ | ✓ | ✗ | ✓ | |
| ConRegenMinutes | PoR #646 | ✗ | ✓ | ✗ | ✓ | identical text |
| ConPoisonSave | PoR #646 | ✗ | ~ (EffConPsnSave scale) | ~ | ✗ | |
| ClampScore 3..25 (#615) | PoR | ✓ | ✓ | ✓ | ✓ | FxEngine.ClampScore |
| Racial caps by permanent Str (CURSE-0315) | Curse | ✓ | ✓ | ✓ | ✓ | `.permanent` / `.base` |
| AtLevelCap ">=" table (f8bcdf0) | PoR | ✓ (`>=`) | ✓ | ✓ | ✓ (Kender only) | |
| Half-orc caps (bcd152d, #956) | PoR review | n/a | n/a | n/a | n/a | no half-orcs offered |
| XP cut after Yes (CURSE-0313) | Curse | ✓ | ✓ | ✓ | ✓ | `experience := bestXp` after YesNo |
| Free training stops (CURSE-0317) | Curse | ~ ("Not Enough Experience") | ~ | ~ | ~ | |
| Young-adult +1 Con (CURSE-0318) | Curse | ✓ | ✓ | ✓ | ✓ | same comment in all |
| Cleric not TN (#202) | PoR | ✓ | ✗ (row 0 lists 9) | ✓ | n/a (Krynn alignment masks) | |
| classMin PHB, Cha 6 (CURSE-0058) | Curse | ✓ | ✓ | ✓ | ✓ (own knight row) | data |
| Half-elf cleric-multi Wis 13 only (POR-0175) | PoR | ✓ (`ClassAbilityMin`) | ✗ | ✗ | ✗ | SSI forces 13 on every cleric multiclass |
| Thief skills barred by armor (CURSE-0068) | Curse | ✓ | ✓ | ✓ | ✓ | |
| Paladin effect 45 at creation (CURSE-0066) | Curse | ✗ (adds 8) | ✗ | ✗ | n/a (Knight) | |
| Launcher plus to hit only (CURSE-0071) | Curse | ✓ | ✓ | ✓ | ✗ | CoK WeaponAdjust adds the full plus |
| Rear AC keeps a Dex penalty (CURSE-0064) | Curse | ✓ | ✓ | ✓ | ✗ | CoK `acCur[1]` has no Dex term |
| Dex 0 AC -4 (POR-0199) | PoR | ✓ | ✗ | ✓ | ✗ | |
| HasteSlowRate one rule (POR-0173) | PoR | ✓ | ✗ | ✗ | ✗ | Secret, Pools and CoK double or halve inline |
| Prime-req XP reads permanent score (POR-0174) | PoR | ✓ | ✗ (`.cur`) | ✓ | ✓ (but cleric Wis `> 14`) | CoK's 14 needs checking: quirk or Krynn rule |
| CountTeams / InflictDamage `hostile and 1` (CURSE-0261) | Curse | ✓ | ✓ (`Ord(<>0)`) | ✓ | ✗ | CoK `teamCount[hostile]` |
| FixAmmoBits / javelin (POR-0186/0189) | PoR | ✓ | ✗ | ✓ | ✗ | |
| FixWeaponClasses (CURSE-0082) | Curse | ✗ | ✗ | ✓ | ✗ | |
| IsPerson for Charm/Hold (POR-0185) | PoR | ✗ (`charType > 1`) | ~ (data flag bit 2) | ~ (data flag) | ✗ | Secret and Pools solve it in monster data |
| Dying creature hit again goes further below 0 (07b3721, #954) | PoR review | ✗ | ✗ | ✗ | ✗ | all set overkill from the new hit alone |
| Drained caster trims slots and spells (ae0740c, #955) | PoR review | n/a | n/a | ✓ (PruneSpells) | n/a | drain exists only in PoR and Pools |
| HP limits add Con on every die (be41552, #957) | PoR review | ~ (Max per die, Min once) | ~ | ~ | ~ | matters only for editors and Modify |
| Multiclass starts at the oldest class age (d1f03cc, #945) | PoR review | ✗ | ✗ | ✗ | ✗ | all use SSI's fixed cleric/mage/fighter map |
| Editor level-down: no negative XP (f7febf0) | PoR review | ✗ (latent, `TopLevel`) | n/a | n/a | n/a | Curse's CharEdit |
| Editor Wis change keeps cleric slots (b963b24) | PoR review | ~ (RecalcClassStats) | n/a | n/a | n/a | |
| Party.NextCreature(nil) (ba7e804) | PoR review | n/a | n/a | n/a | n/a | PoR-only unit |
| EVIL_ALIGNMENTS, abilityNames, recentSaved (b3e31b0, f03964b, 7e7d15f) | PoR review | n/a | n/a | n/a | n/a | PoR-only cleanups |
| Join keeps Ready (#595) | PoR | ✓ | ~ (bundles rewrite) | ✓ | ✓ | |

Count over the 28 rows a port could take: Curse lacks 9, Secret 11, Pools 7 and CoK 12. Rows a port lacks for want of
the feature count as n/a and are left out.

### PoR-only features, and the ports that have part of them

- **Dual class (ChgClass, `formerClasses`).** Curse, Secret, Pools and CoK already have SSI's own human class change
  (ChangeClass, CurrentDualClassLevel, EarlierClassActive), with near-identical logic among the four (0.72–0.99).
  Share their rules core and PoR's screen (`Obstacle`, `ShowClassStatus`) on top. PoR's `formerClasses` mask must be
  reconciled with their `oldClassLevels` arrays.
- **AbilAdj to 25, D&DG.** Secret and CoK have taken HitDieFloor and ConRegenMinutes; Pools has IntKnowSpellChance
  identical; Curse, Secret and Pools have resurrectionSurvival and SurvivesRaise; WisSpellFailure is in Secret and
  Pools. Curse is missing most of it.
- **Stats counters.** In PoR, Curse, Secret and Pools (AddTo, AddSigned identical; most of the rest same shape). Not
  in CoK.
- **CharEdit (Companion Tools editor).** Curse only, close to PoR's copy (0.8–1.0).
- **PartyMnu, Party Next/Prev, CharDisp's PrintTwoLines/AnimateBetween, ViewChar DrawDualClass/LayOnHands.** PoR
  only.

### Proposal: one character core, per-game data and hooks

**Shared units.**
- `CharRules`: AbilAdj plus the CharHlp ability, weapon, AC, damage and team routines.
- `ClassRules`: ClassCal's RecalcClassStats, RecalcSaves, slots, ConHp, HitDieFloor, caster level, dual-class
  tests and ExperienceShare.
- `Training`: TrainClasses, the training menu skeleton and GainLevels.
- `CharUi`: the ViewChar, CharDisp and CustomizeIcon screens, keeping CharGen's per-game creation flow.

All read one in-memory character through accessors or a unified record:
- `ClassLevel(cr, cls)` and `EarlierLevel(cr, cls)` (today `EffectiveClassLevel` in Pools, `GetClassLevel` in PoR);
- `Ability(cr, a)` and `PermanentAbility(cr, a)`;
- `Side(cr)`, `InPlay(cr)`, `Overkill(cr)`.

**Per-game data, consolidated to Pools' maxima and filled per game:**
- XP by class, to 40, or Pools' formula;
- THAC0 by class and level (to 21, then flat);
- attacks by level (3 at 7/8, 4 at 13/15);
- saves, spell slots and bonus spells to 25;
- thief skills by level, race and Dex;
- hit dice and the fixed-HP level per class;
- turning;
- `raceClassCap[race, class, band]`;
- class minimums and alignments;
- age dice and age categories;
- race weapon bonuses;
- caster offsets for half-casters.

**Per-game enforcement parameters:**
- `MAX_LEVEL[class]` (PoR 9/8 by its tables, Curse 12, Secret 18, Pools 40, CoK 12);
- `THAC0_LEVEL_CAP`;
- `ITEM_CASTER_LEVEL`;
- `TRAIN_FEE` (Curse and PoR in code; Secret, Pools and CoK: 0 or ECL);
- `TRAIN_NEEDS_HALL` (False in Pools);
- the item class mask and the readiable-gear limits;
- `HAS_DRAIN`, `HAS_SCROLL_BUNDLES`, `HAS_KNIGHTS`.

**Hooks (procedure variables set by each game's GameInit, as PoR already does with `aimReport`):**
- `CasterLevelAdjust`: CoK's moons and robes.
- `XpRowFor(cr, cls)`: CoK's knight and robe orders; Pools' formula.
- `AfterLevelUp(cr, mask)`: CoK knight spell grants; Pools HitPointCap and pruning.
- `IsPerson(cr)`: PoR's name list or the Secret/Pools data flag.
- `RacialLevelCap`: table, plus Kender as data.
- `StartingKit`: Pools' items; CoK's steel and robes.

**Risks.**
- **Saves.** Record layouts and save formats differ per game:
  - PoR keeps only current scores (`strCur`; no base/current pair) and a 56-entry spellsKnown;
  - Secret has `V1` overlay fields and a variant record;
  - CoK renumbers races (0 = Silvanesti elf) and puts Knight at class 7;
  - Pools has 7 classes (0..6).

  A unified in-memory record needs per-game load/save translation (SaveLoad), which a gameplay core must not break.
- **Effects.** Effect ids and strength bit layouts differ: Haste's aged flag is $10, and $20 in Pools. Handler
  signatures differ too (`var cr` in Secret and Pools, an untyped `var creature` in CoK). The effects report should
  settle one TEffectHandler signature first.
- **Unit placement.** It differs: ConHpTotal and HitDieFloor are in FxEngine in Pools and CoK, and CharDisp
  routines are in CharHlp in Pools and CoK. A shared unit changes the overlay and stub tables in each DOS build.
  CharGen and ViewChar are overlay units near the 64K segment limit in DOS, so moving tables into them needs a size
  check per game.
- **Behaviour changes.** Every shared rule changes behaviour in some game: those games' SSI quirks become fixes.
  Each needs a "Differs from SSI" entry and a Forge issue per game, per the issue-per-bug rule.

**Order of work (cheap first).**
1. Copy the drop-in pure functions: ability tables, HitDieFloor, ConRegen, ConPoisonSave, ClampScore,
   DexterityArmorAdjustment 0..3, HasteSlowRate. They are identical or one-line ports.
2. Port the fixes from the table, CoK first. It lacks the most: CURSE-0064, CURSE-0071, CURSE-0261 and POR-0173.
3. Unify RecalcClassStats, RecalcSaves and slots with Pools-sized tables.
4. Merge TrainingMenu into `TrainClasses` + hooks.
5. Last, the creation flow, which is mostly per-game.

## 10. Camp, exploring, town and time: shared vs per-game (slice of shared-gameplay)

Sources: each repo at origin/main (PoR 109f2c2, Curse 34eaebd, Secret b49f824, Pools 33ddd3b, CoK f132af3), exported
under `gp/<game>/src`. Families are matched by name and, for renamed routines, by token similarity (`gp/match.py`,
`gp/families.json`). "tok" is a token-sequence similarity after comments and unit qualifiers are stripped; "shape"
replaces identifiers, so it measures logic independent of naming. Curse's names are the family key.

Overall finding: there are no byte-identical routines in this slice. The five ports were named and cleaned
independently: `cr` / `creature` / `character` / `target`, `GDVars.curChar` / `GameVars.curChar` /
`GDVars.currentChar`, `enabled` / `inPlay`, `hpCur` / `hpCurrent`. Under that noise the logic is mostly the same SSI
routine. There are four real structural seams:

1. **The character record.** PoR keeps v1.3's flat fields (`conCur`, `strCur`, `coins[COPPER..JEWELRY]`). Curse, Secret
   and CoK use `stats[C_Stat.X].permanent/base` plus `coinsA`/`coins[0..6]`. Pools has `coins[0..2]`.
2. **The GBVM zone band.** The same flag is read as `zone0^[C_Gbvm.ANTI_MAGIC]` (Curse), `zone0^.antimagic` (Secret),
   `vmBand.zone0^.antiMagic` (Pools) and `zone0^.vars[...]` (CoK).
3. **The menu API.** Pools' `MenuHorizontal`/`MenuVertical` return item indexes, not hot-key letters, and every
   Pools menu `case` is on `0..n`.
4. **Message output.** `CharDisp.PrintNameString` in PoR, `PrintCreatureMessage` in CharDisp or CharHlp elsewhere, and
   string constants in Pools' GDConsts.

None of these is gameplay. All four are accessor or naming layers that a shared unit would sit on.

### Unit tables

Counts are routine families. "4-port" is the worst pair among Curse, Secret, Pools and CoK. "PoR best" is PoR against
its closest port.

| Unit | Families | In all 5 | 4-port shape =1 / >=.95 / .85-.95 / .7-.85 / <.7 | PoR-only | PoR best shape >=.95 / .85-.95 / .7-.85 / <.7 |
|---|---|---|---|---|---|
| Camp | 55 | 21 | 4 / 3 / 8 / 11 / 11 | 7 | 10 / 8 / 5 / 3 |
| Explore (+Wilds) | 24 (+3) | 4 | 2 / 5 / 5 / 1 / 3 | 8 (+3 Wilds) | 3 / 3 / 3 / 4 |
| Shop | 11 | 4 | 1 / 0 / 1 / 1 / 3 | 0 | 2 / 3 / 1 / 0 |
| Temple | 17 | 10 | 0 / 1 / 2 / 2 / 9 | 1 | 3 / 3 / 4 / 3 |
| Money (+MoneyCal) | 37 (+8) | 14 | 7 / 3 / 5 / 12 / 2 | 4 (+8) | 8 / 11 / 3 / 4 |
| GameTime | 22 | 10 | 1 / 3 / 8 / 4 / 1 | 1 | 4 / 7 / 2 / 1 |
| RandItem | 3 | 0 (Pools has none) | 0 / 0 / 0 / 1 / 1 | 0 | 0 / 2 / 1 / 0 |

#### Camp (`camp.pas`: PoR 1139 lines, Curse 1289, Secret 1318, Pools 1273, CoK 1279)

| Group | Classification | Notes, and the hook that absorbs the difference |
|---|---|---|
| `CanDoSpellActivity`, `CampFixMenu.CanCast`, `CampDisplayMenu.AddToList`, `OrderMoveUp/Down`, `RememberUsualSpells`, `SortMemorizedSpells`, `RollCureSlots`, `HealParty` | identical but for naming and data (tok .86-1.0 among the ports) | Only the anti-magic flag's address differs (seam 2): one `AntiMagicArea` accessor per game, which PoR already has. |
| `CampMainMenu` | same logic; the menu is "Save View Magic Rest Alter Fix Exit" in all five | Pools is index-driven (seam 3). Curse adds `CompTool.ToolsMenu` (F-keys), PoR `Explore.SideScreen`. |
| `CampAlterMenu` | game-specific branches | PoR/Curse: Order Drop Char(Icon Portrait) Settings. Secret, Pools and CoK add **L(evel) → `CampDifficultyMenu`**, and CoK adds **S(peed) → `CampSpeedMenu`** and Pics/Animation toggles. Hook: an Alter item table per game (key, label, proc). |
| `CampMagicMenu`, `CampMemorizeMenu`, `CampScribeMenu`, `QueueUsualSpells`, `DisplaySpellSlots`, `SpellSlotsRemaining` | same rule, but they differ in the slot layout and the spell table | The slot arrays differ (`slots[class, level]` with 3 cleric + 5..9 mage levels in later games). The spell table is `spellProperties` / `spellDefs` / `spellTable` / `spellTbl`. Hook: `MaxSpellLevel(class)` and `SpellLevelOf(id)` from the game's tables. CoK adds `MoonBonusSpells` (extra mage slots by the robe order's moon, read from GBVM var `$4CF8 + robeOrder`), which is called from Memorize. Hook: `BonusMemorizeSlots(char)` returning 0 elsewhere. |
| `CampSpellPrepTime`, `RestForSpellPrep` (PoR: `CampRestMenu` in camp) | same; all already count in Words (POR-0200 is in every port) | Only Secret bounds the spell id (`in [1..LAST_ID]`), as PoR's 6d00536 `PendingLevel` does. Curse, Pools and CoK still index `spellTable` with an unbounded id. |
| `CampFixMenu` | **diverged** (tok .13-.70) | Three generations. (a) PoR/Curse: Curse's planner (`HasCondition`, `CureSpell`, `AssignCure`, `PlanCures`, `ApplyCures`) cures disease, blindness and curse as well as hit points; PoR has a 208-line port of it (`Treatable`, `CasterTime`). (b) Secret/Pools: SSI's later Fix (`ComputeCureTime`, `CureStatusEffects`, `CountCureNeeds`; Pools adds `AccumResources`). (c) CoK: hit points only (`RollMemorizedCures`, `PartyHitPointsMissing`, `ComputeFixTime`). Shareable: one Fix with a per-game set of curable conditions and the cure spells' ids. |
| PoR-only | `PendingLevel`, `SlotsUsed`, `PutPending`, `HasSlotKind`, `SelectOtherChar` | These are the 2026-10-25 bounds helpers (6d00536). They carry over as they are once slot dimensions are parameters. |

#### Explore and Wilds (`explore.pas`: PoR 552, Curse 467, Secret 496, Pools 353, CoK 559; `wilds.pas` PoR only, 131)

| Group | Classification | Notes |
|---|---|---|
| `BashDoor`, `PickLock`, `FindMemorizedSpell`, `FindCharWithSpell`, `PartyHasClass`, `ChangeBarrier(Im)Passable` | same logic (shape .8-.97) in PoR, Curse, Secret and CoK | **Pools has no door code in Explore** (its doors are scripted). Thief and Knock tests are by class or spell constant. |
| `PartyCastsKnock` + locked-door menu | same in Curse, Secret and CoK; PoR diverged (2026-10-25) | The ports duplicate the "Locked." menu for barrier kinds 2 and 3 inside `ResolveMovement`. PoR folds both into `DoorMenu` (f2f4bd4) and adds Knock from a scroll (`FindKnockCaster`, 6166fe7). The door-option flags live in different places (`lockOptions[]`, `bashOffered`/`pickOffered`/`knockOffered`, `doorOpen[]`). |
| `ResolveMovement`, `MapMainMenu`, `MovePartyForward3D`, `MoveForward` | diverged (tok .22-.80) | These differ in their input layers (Pools' mouse, CoK's speed and clock display, PoR's Companion side screen and `AskQuickLoad`). The movement core (barrier check, then a step, then events) is common. Hook: an extra-keys handler per game. |
| `MovePartyWilderness` | Pools ~ CoK (.78) | PoR's version lives in `Wilds` with `ViewCorner` and `BuildWildernessMap` (PoR-only, with the 2026-10-25 clamp bce47c7). Curse and Secret have no wilderness. Shareable as an optional `Wilds` unit for PoR, Pools and CoK, with the map size as a parameter. |

#### Shop (`shop.pas`: PoR 193, Curse 273, Secret 256, Pools 314, CoK 270)

| Group | Classification | Notes |
|---|---|---|
| `GoBackForIt` | identical (Curse = Secret, tok 1.00; PoR .93, moved to Money) | CoK writes the same two messages inline in both Shop and Temple; Pools uses `GDConsts.leftMoneyMsg`. |
| `ShopMainMenu` | PoR/Curse: a 6-line call to a shared `CounterMenu` (shop and temple); Secret, Pools and CoK: 74-85 lines inline | Shareable: PoR's `CounterMenu` with a per-building menu string and handler. |
| Price | **game rule switch** | PoR/Curse: list price. Secret (`ScaledPrice`), Pools (`ItemPrice`) and CoK (`ShopPrice`) scale by the GBVM price mode (div 16..x8), all the same table. Pools also multiplies by the bundle quantity and floors at 1; PoR's `MoneyCal.ItemValue`/`ItemBundle` do the bundle division. Hook: `PriceMode` from the zone (constant 0 in PoR/Curse). |
| `ShopBuyMenu`, `ShopBuyItemSelection`, `GiveItemCopyToCreature` | similar to diverged | Pools/CoK `GiveItemCopyToCreature` is 32-34 lines against 13-16 (it stacks bundles). |

#### Temple (`temple.pas`: PoR 414, Curse 391, Secret 359, Pools 471, CoK 501)

| Group | Classification | Notes |
|---|---|---|
| Menu (`HealMenu` items 0..9: Blindness, Disease, Cure L/S/C, Heal, Neutralize, Raise, Remove Curse, Stone to Flesh) | same list in all | Pools adds item 10, **Restoration**, and a **RepairParty** building command. |
| Prices | **data** | PoR/Curse: 1000, 1000, 100/350/600/5000, 1000, 5500, 3500, 2000 (PoR scales them by `TemplePrice` mode, #682). CoK: exactly half (500, 50/175/300/2500, 2750, 1750, 1000), its steel standard. **Secret: free**: no `PayCureCost` anywhere; the cure just happens and prints a message. **Pools: no fee**; each cure runs the spell handler (`spellFps.spells[75]` Raise Dead, `[102]` Restoration, `[105]`). Hook: a price table per game (nil means free), and "cure by spell handler" as Pools does it. |
| `RaiseDead` | diverged: four rules | PoR: refuses elves (before the fee) and poisoned corpses; rolls `ConResurrectionSurvival`; a failure is GONE; costs Con and hp. Curse: refuses poisoned, Con 0 and elves; `FxEngine.SurvivesRaise`; a failure stays dead. Secret: free; the same tests and `SurvivesRaise`. Pools: casts spell 75. CoK: `race < HALF_ELF` cannot be raised (Krynn's race ids), poisoned refused, `SurvivesRaise`, 2750. The shared rule needs hooks: `CanBeRaised(race)`, `RaiseFailure = Dead/Gone`, and the cost. |
| `CureWounds` | diverged | Secret already says why a cure does nothing (dead, petrified, gone, full). Curse and CoK take the fee whatever happens: the bug PoR fixed in 2985bd0 (`NoWoundCure`). |
| `StoneToFlesh` | same in Curse/CoK (and Pools without the fee), Secret free | **No port rolls system shock**: PoR a050ead is missing in all four. |
| `PayCureCost`, `ReportCure`, `ConfirmCureCost`, `ConfirmCureAnyway` | PoR ~ Curse ~ CoK (.78-.98) | Secret has `Magic.PromptCastAnyway`; Pools has no pay step. |

#### Money (`money.pas` PoR 611 + `moneycal.pas` 232; Curse 778, Secret 785, Pools 601, CoK 945)

| Group | Classification | Notes |
|---|---|---|
| Coin set | **data** | PoR, Curse and Secret: 7 kinds (copper 1, silver 10, electrum 100, gold 200, platinum 1000 cp; gems, jewelry), `TMoney = array[0..6]`. CoK: 7 slots, but the values are **1, 5, 10, 25, 50** with names copper/bronze/silver/steel/platinum: the steel standard. `CoinValueInSteel`, `SetCreatureCoinsInSteel`, `SetTreasureCoinsInSteel` and `GiveSteel` replace the gold routines. Pools: **3 kinds** (platinum, gems, jewelry), `TMoney = array[0..2]`, `GivePlatinum`. Secret has `GivePlatinum` too. Hook: a coin table (count, names, value, "base coin" index) per game. The record's coin array length is save format. |
| `CarryingCapacity`, `SpareCapacity`, `CoinsOf`, `CoinValueInGold`, `WhoPays`, `PayBy`, `PayGold`, `CreatureGold` | identical but for data (4-port shape 1.0 where present) | These are exactly the routines PoR moved to `MoneyCal`. |
| `Takable` (bound to 65535) | present in Curse, Pools (`CoinTakable`) and CoK | This is SSI's later code. Secret bounds inline (`if pp > 65535`). PoR's POR-0176 fix brought PoR up to them. |
| `CountPoolers`/`ShareMoney` | **already right in the ports** | Curse, Secret and CoK count and pay the same test (`npc = 0 or npc = $B3`); Pools uses `SharesMoney`. POR-0151 was a v1.3-only bug. |
| `ParseMoneyType` | same in the ports | PoR's -1 for an unknown name (6995f80) is missing in all; they read past a blank string. |
| `TakeMoneyMenu`, `DetermineTreasure`, `PoolMoney`, `TradeMoney`, `DropMoney`, `AppraiseMenu` | similar (4-port .80-.94) | PoR's are rewritten through `CoinMenu`/`PoolHasMoney` (401f1fc). |

#### GameTime (rest and time)

| Group | Classification | Notes |
|---|---|---|
| `ValidateRestTime`, `DecrementRestTime`, `DisplayRestTime`, `CheckRestingHeal`, `AdvanceSpellPrep(Base)`, `CampRest`, `CheckMemorizeDone` | similar to near (4-port .75-.99; Pools ~ CoK .93-.99) | The same rest clock (days, hours, tens of minutes, minutes). `SetFromMinutes` is in Curse/Secret `Clock` and Pools `GameTime`; CoK has `Camp.SetRestClock`. So **#644 is already SSI's code in the later games**. |
| `TimeOutEffects` | same fix, different code | PoR is in FxEngine; Curse/Secret in `Clock`; Pools/CoK in `GameTime`. All four ports have the LongInt total and segments taken as tenths of a minute (#444 mirrored). They guard a freed node by marking, then re-finding each effect; PoR checks `HasEffectNode` plus the id and duration. Shareable as one routine. |
| `CheckScribeDone` | ports remove the exact slot (`RemoveScrollSlot`) | PoR caught up in bb8b1a0. **No port rolls the scribe failure** (`IntKnowSpellChance`, #59) **except Pools**, which has `ClassCal.IntKnowSpellChance` and `SpellFailureChance`. Secret and CoK have the cleric Wisdom failure in Magic but no scribe roll; Curse has neither. |
| `AgeParty`, `ClockDisplay` (CoK), `TwoDigitStr` | Pools/CoK only | Aging over time is in Secret/Pools (`Combat.AgingDeaths`). |

#### RandItem (PoR, Curse and Secret `randitem.pas`; CoK in `money.pas`; Pools none)

`GenerateRandomItem` is the same machine (kind → bonus, name ids and template) but its case arms are game data.
PoR's POR-0165 (javelin template 144) and POR-0205 (kind 78's 1d3+1) are bugs in PoR's own template table. Curse
selects its javelin template correctly (49 → template 7). Secret and CoK draw scroll spells from `spellsByLevel` /
`knownSpellTable`, while PoR and Curse use literal ranges. Hook: the kind → template table and the scroll spell
tables per game, with the code shared.

### PoR fixes against the ports (spot-checked in each port's source)

Y = present; N = missing; SSI = the port already had SSI's own correct code; n/a = no such code in that game.

| Fix | Curse | Secret | Pools | CoK |
|---|---|---|---|---|
| #877 Fix refuses in anti-magic (`AntiMagicArea`; Fix checks it) | N | N (has `AntiMagicArea`, Fix doesn't ask) | N (same) | N |
| #644 rest clock via `SetFromMinutes` | SSI | SSI | SSI | SSI (`SetRestClock`) |
| POR-0151 ShareMoney divisor = payees | SSI | SSI | SSI | SSI |
| POR-0176 coins stop at 65535 | SSI (`Takable`) | SSI (inline) | SSI (`CoinTakable`) | SSI |
| POR-0200 prep-time counts in Words | Y | Y | Y | Y |
| 6d00536 camp bounds spell ids and slot kinds | N | partly (ids bounded) | N | N |
| POR-0157 GoBackForIt keeps the priest's words | Y | Y | Y (constants) | Y (inline, duplicated) |
| CURSE-0168/#751 raise: survival roll, poisoned refused | Y (Curse origin; a failure stays dead) | Y | via spell 75 | Y |
| #61 raise refuses elves | Y | Y | n/a (spell) | Krynn rule (race < half-elf) |
| a050ead Stone to Flesh system shock | N | N | N | N |
| 2985bd0 temple Cure Wounds asks first, says why | N | SSI (says why; free) | n/a | N |
| bb8b1a0 scribe takes its own scroll slot | SSI (`RemoveScrollSlot`) | SSI | SSI | SSI |
| #59 scribe can fail on Intelligence | N | N | Y | N |
| #60 cleric spell failure on Wisdom | N | Y (`Magic.SpellFailureChance`) | Y | Y |
| 6166fe7 Knock offered only to a real caster; scroll Knock | SSI (memorized only); no scrolls N | same | n/a | same |
| f2f4bd4 one door menu (no duplicated kind-2/3 menus) | N | N | n/a | N |
| #444 TimeOutEffects LongInt, tenths | Y | Y | Y | Y |
| 6995f80 ParseMoneyType -1 on an unknown name | N | N | N | N |
| 401f1fc one coin menu builder | N | N | N | N |
| e32bc5b, POR-0165, POR-0205 random items | n/a (Curse's table is correct) | n/a | n/a | n/a |
| 15383a2 3D view wraps far rows right | not checked (view slice) | | | |

The direction is two-way. About a third of PoR's town and camp fixes were bugs only in v1.3, which SSI had already
fixed in the later engines (ShareMoney, 65535, rest clock, scribe slot, Knock offer). PoR imported those from Curse,
and they need no backport. The fixes that are genuinely missing everywhere else are PoR's own rule additions: Fix in
anti-magic, system shock, the temple's cure prompt, the scribe failure roll (Pools has it), the camp bounds, the
`ParseMoneyType` guard and the door-menu consolidation.

### Proposal: the shared core and per-game hooks

**Shared units** (one copy, written against accessors):
- `Camp`: the menus, memorize/scribe queues, prep-time, Order, Drop and the rest loop. Fix becomes the Curse/PoR planner
  generalised over a condition list.
- `GameTime` + `Clock`: the rest clock, `SetFromMinutes`, `TimeOutEffects` (PoR's or the ports' node guard, one of
  them), `CheckMemorizeDone`, `CheckScribeDone` with the optional failure roll, `CampRest`, `AdvanceSpellPrep`.
- `Money` + `MoneyCal`: everything coin-count generic. PoR's MoneyCal split is the right seam: the pure calculations
  are testable and table-driven.
- `Shop`/`Temple`: PoR's `CounterMenu` (shared building loop), `GoBackForIt`, and the pay, confirm and report helpers.
- `Explore`: doors (Bash, Pick, Knock, `DoorMenu`) and the movement core. `Wilds` is optional.
- `RandItem`: the generator, with its table as data.

**Per-game layer:**

| Hook or data | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| Coin table (count, names, cp values, base coin) | 7, gold | 7, gold | 7, gold | 3, platinum | 7, steel (1/5/10/25/50) |
| Temple price list (nil = free) and price mode | full or tenth off | full | free | by spell handler (free) | half |
| Temple extra services | – | – | – | Restoration, RepairParty | – |
| `CanBeRaised(race)`; raise failure → dead or gone | not elf; gone | not elf; dead | not elf; dead | spell | not < half-elf; dead |
| Shop price scaling by GBVM mode | off | off | on | on (× bundle) | on |
| Alter menu items | Settings | Settings, Tools | + Level | + Level | + Level, Speed, Pics/Anim |
| `BonusMemorizeSlots` | 0 | 0 | 0 | 0 | moons by robe |
| Fix curable conditions | disease, blind, curse | same | + status | + status | hp only |
| Rule switches: scribe failure, cleric failure, system shock, anti-magic Fix | on (PoR) | off | Wisdom failure on | scribe + Wisdom on | Wisdom failure on |
| Door code present | yes | yes | yes | no | yes |
| Wilderness unit | yes | no | no | yes | yes |
| Zone-band accessors (anti-magic, price mode, door flags, moon vars) | `CharHlp.AntiMagicArea` etc. | one function per flag over each game's GBVM layout | | | |

**Risks:**
- **The save format.** The character record's coin array (5/7/3 entries), `stats[]` against flat fields, and slot array
  sizes are all on disk. The shared code must reach them through accessors, never by sharing the record type.
- **Menu API (Pools).** An index-returning menu needs either a letter adaptor or a Pools shim for every shared menu.
- **DOS overlays.** Camp, Temple and Shop are `{$O+}` overlays in every port. Moving shared code into one bigger unit
  must keep each overlay under the ports' sizes, which are tightest in Pools/CoK. Splitting pure calculation (as
  MoneyCal does) keeps the overlays thin.
- **Rule drift.** Several SSI rules differ on purpose per game (Secret's free temple, Krynn's prices and race limit,
  Pools' spell-driven cures). They must become explicit switches, not "fixes".
- **Byte-matched trees.** Nothing here touches the disassembly trees. The shared core is for the ports only.
