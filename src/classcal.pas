{ Recalculate class skills, saving throws and thief abilities, including wisdom bonuses. }
{$O+,F+}
{$I COMPILER.INC}
unit ClassCal;

interface

uses Types, C_ALIGN, C_RACE, C_SPELL;

const
  { The cleric spells Wisdom adds, by spell level 1..7, at each score from 13: the 1st-edition PHB to 18, Deities &
    Demigods for 19..25. Each score's row adds to those below it. }
  wisBonusSpells: array[13..25, 1..7] of Byte = (
    (1, 0, 0, 0, 0, 0, 0),
    (1, 0, 0, 0, 0, 0, 0),
    (0, 1, 0, 0, 0, 0, 0),
    (0, 1, 0, 0, 0, 0, 0),
    (0, 0, 1, 0, 0, 0, 0),
    (0, 0, 0, 1, 0, 0, 0),
    (1, 0, 0, 1, 0, 0, 0),
    (0, 1, 0, 1, 0, 0, 0),
    (0, 0, 1, 0, 1, 0, 0),
    (0, 0, 0, 1, 1, 0, 0),
    (0, 0, 0, 0, 2, 0, 0),
    (0, 0, 0, 0, 0, 2, 0),
    (0, 0, 0, 0, 0, 1, 1));
  { The classes each race can take, in the order the class menu lists them. Humans take paladins and rangers, and
    half-elves rangers and cleric/rangers, in Curse's order. }
  classesByRace: array[1..7] of Types.TRuleRaceClasses = (
    { dwarf }
    (count: 3; classes: (2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
    { elf }
    (count: 7; classes: (2, 5, 6, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0)),
    { gnome }
    (count: 3; classes: (2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
    { half-elf }
    (count: 13; classes: (0, 2, 5, 6, 4, 8, 10, 9, 11, 13, 14, 15, 16)),
    { halfling }
    (count: 3; classes: (2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
    { half-orc }
    (count: 6; classes: (0, 2, 6, 8, 12, 14, 0, 0, 0, 0, 0, 0, 0)),
    { human }
    (count: 6; classes: (0, 2, 5, 6, 3, 4, 0, 0, 0, 0, 0, 0, 0)));
  { The alignments each class can take, in the order the alignment menu lists them. A cleric cannot be true neutral (1e
    PHB p.13), and a multiclass takes only the alignments all of its classes allow, so cleric/thief has neither true
    neutral nor the thief's LG and CG. Druid and monk are not offered at creation and keep SSI's rows. }
  alignByClass: array[0..16] of Types.TRuleClassAlignments = (
    { cleric }
    (count: 8; alignments: (C_ALIGN.LG, C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.NE,
                            C_ALIGN.CG, C_ALIGN.CN, C_ALIGN.CE, 0)),
    { druid }
    (count: 5; alignments: (C_ALIGN.LN, C_ALIGN.NG, C_ALIGN.TN, C_ALIGN.NE, C_ALIGN.CN, 0, 0, 0, 0)),
    { fighter }
    (count: 9; alignments: (C_ALIGN.LG, C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.TN,
                            C_ALIGN.NE, C_ALIGN.CG, C_ALIGN.CN, C_ALIGN.CE)),
    { paladin }
    (count: 1; alignments: (C_ALIGN.LG, 0, 0, 0, 0, 0, 0, 0, 0)),
    { ranger }
    (count: 3; alignments: (C_ALIGN.LG, C_ALIGN.NG, C_ALIGN.CG, 0, 0, 0, 0, 0, 0)),
    { magic-user }
    (count: 9; alignments: (C_ALIGN.LG, C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.TN,
                            C_ALIGN.NE, C_ALIGN.CG, C_ALIGN.CN, C_ALIGN.CE)),
    { thief }
    (count: 7; alignments: (C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.TN, C_ALIGN.NE,
                            C_ALIGN.CN, C_ALIGN.CE, 0, 0)),
    { monk }
    (count: 9; alignments: (C_ALIGN.LG, C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.TN,
                            C_ALIGN.NE, C_ALIGN.CG, C_ALIGN.CN, C_ALIGN.CE)),
    { cleric/fighter }
    (count: 8; alignments: (C_ALIGN.LG, C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.NE,
                            C_ALIGN.CG, C_ALIGN.CN, C_ALIGN.CE, 0)),
    { cleric/fighter/magic-user }
    (count: 8; alignments: (C_ALIGN.LG, C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.NE,
                            C_ALIGN.CG, C_ALIGN.CN, C_ALIGN.CE, 0)),
    { cleric/ranger }
    (count: 3; alignments: (C_ALIGN.LG, C_ALIGN.NG, C_ALIGN.CG, 0, 0, 0, 0, 0, 0)),
    { cleric/magic-user }
    (count: 8; alignments: (C_ALIGN.LG, C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.NE,
                            C_ALIGN.CG, C_ALIGN.CN, C_ALIGN.CE, 0)),
    { cleric/thief }
    (count: 6; alignments: (C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.NE, C_ALIGN.CN,
                            C_ALIGN.CE, 0, 0, 0)),
    { fighter/magic-user }
    (count: 9; alignments: (C_ALIGN.LG, C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.TN,
                            C_ALIGN.NE, C_ALIGN.CG, C_ALIGN.CN, C_ALIGN.CE)),
    { fighter/thief }
    (count: 7; alignments: (C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.TN, C_ALIGN.NE,
                            C_ALIGN.CN, C_ALIGN.CE, 0, 0)),
    { fighter/magic-user/thief }
    (count: 7; alignments: (C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.TN, C_ALIGN.NE,
                            C_ALIGN.CN, C_ALIGN.CE, 0, 0)),
    { magic-user/thief }
    (count: 7; alignments: (C_ALIGN.LN, C_ALIGN.LE, C_ALIGN.NG, C_ALIGN.TN, C_ALIGN.NE,
                            C_ALIGN.CN, C_ALIGN.CE, 0, 0)));

procedure RecalcBaseSkills(creature: Types.PCharRecord);

procedure AwardWisdomBonus(creature: Types.PCharRecord);

{ Work creature's cleric spell slots out again from its cleric level (CharHlp.GetClassLevel) and its Wisdom, as a
  Wisdom change or a lowered level needs: at level 1 the one first-level slot, and above it the level's slots
  (RecalcBaseSkills), each with the Wisdom bonus (AwardWisdomBonus). No usable cleric level leaves them as they are. }
procedure ResetClericSlots(creature: Types.PCharRecord);

{ A new character's age in years, by race (Dwarf..Human) and charClass, from the DMG's Character Age table (p.12): a
  single class rolls its dice on its base, and a multiclass takes the oldest of its classes, the largest base plus the
  dice's maximum (POR-0221, #945). }
function StartingAge(race, charClass: ShortInt): Word;

procedure RecalcSaves(creature: Types.PCharRecord);

procedure RecalcThiefSkills(creature: Types.PCharRecord);

{ True when creature's readied armor bars its thief abilities: body armor other than leather, or a shield. A thief
  works only in leather or no armor and with no shield (1st-edition PHB), which binds a multiclass thief too (#743). The
  equipment slots must be linked (CharHlp.LinkEquipped). }
function ArmorBarsThiefSkills(creature: Types.PCharRecord): Boolean;

{ The parts of creature's thief skill j (1..8, thiefSkills' order): base, thiefBase's value for the thief level; racial,
  raceAdj's; dexterity, dexAdj's for skills 1..5 and 0 for the others. A creature without thief levels takes the level
  1 row. }
procedure ThiefSkillParts(creature: Types.PCharRecord; j: Byte; var base, racial, dexterity: ShortInt);

{ The thief skill its parts (ThiefSkillParts) make, as RecalcThiefSkills stores it: their sum stopped at 0, or 0 when
  the racial penalty is larger than the base, so it need not equal the sum. }
function ThiefSkill(base, racial, dexterity: ShortInt): Byte;

{ The cleric level creature turns undead at: the cleric level it can use (CharHlp.GetClassLevel, so a dual-classed
  human's resting cleric levels give none, #838), or its paladin level less 2 when that is higher, so a paladin turns
  from level 3 as the 1st-edition PHB has it; 0 when it cannot turn. Combat and the More Info Cleric page (#904) read
  it. }
function TurnLevel(creature: Types.PCharRecord): ShortInt;

const
  { the turning table's undead rows: level 1 (skeleton) to 10 (vampire) }
  TURN_UNDEAD_KINDS = 10;
  { TurnValue for undead the cleric cannot turn }
  TURN_IMMUNE = 99;

{ The turning table's entry for undead of level undeadLevel (1..12; above 10 reads row 10, the vampire's) against turn
  level lvl (TurnLevel; its columns are levels 1..8 one each, then 9..13, then 14 and up). A d20 roll of Abs(value) or
  more succeeds: a positive value turns, zero or a negative one destroys, so 1 turns automatically, 0 destroys
  automatically and TURN_IMMUNE cannot succeed. A level below 1 gives TURN_IMMUNE. Combat and the More Info Cleric
  page (#904) read it. }
function TurnValue(undeadLevel, lvl: ShortInt): ShortInt;

{ The racial limits on ability (C_STAT) for race 1..7 (C_RACE.DWARF..HUMAN) and gender (C_GENDER, which only Strength
  depends on), from GameDefs.minimumMaximumStatistics. }
function RaceAbilityMin(race, gender, ability: ShortInt): Byte;
function RaceAbilityMax(race, gender, ability: ShortInt): Byte;

const
  { a half-elf's multiclass with cleric needs this much Wisdom, more than the cleric's 9; a half-orc's needs only the 9
    (the 1st-edition PHB, p. 20) }
  HALFELF_MULTI_CLERIC_WIS = 13;

{ The class minimum on ability (C_STAT) for charClass (C_CLASS) of race (C_RACE): a single class's from
  classMin, a multiclass's the highest of its classes' (GameDefs.classParts), as the 1st-edition PHB has it,
  and a half-elf's multiclass with cleric at least HALFELF_MULTI_CLERIC_WIS Wisdom. }
function ClassAbilityMin(race, charClass, ability: ShortInt): Byte;

{ The Constitution hit-point adjustment class cls (C_LEVEL) gets per hit die: conBonusTbl's, plus, for the
  fighter, paladin and ranger classes, 1 at Con 17, 2 at 18, 3 at 19..20, 4 at 21..23 and 5 at 24..25. The warrior
  bonus goes with the class, so a multi-class character's fighter, paladin or ranger levels get it too: the 1st-edition
  PHB works the bonus out per class, then divides by the class count (#616). A Constitution outside the table's 3..25
  uses the nearer end, so Con 0..2 (Raise Dead takes a point each time) keep Con 3's penalty. }
function ConHpPerDie(cls: ShortInt; con: Byte): ShortInt;

{ Sum ConHpPerDie over the hit dice each class with levels whose classBits shares a bit with mask ($FF = all) rolls for
  its level now (RollFirstLevelHp's dice), leaving out the classes a dual-classed human has left, which gain no more hit
  dice: once a class, twice for a first-level ranger or monk, which rolls two dice. }
function ConHpBonus(creature: Types.PCharRecord; mask: Byte): ShortInt;

{ The hit dice class cls (C_LEVEL) has given creature: its level, with the ranger's and monk's second die at level 1.
  A dual-classed human's (#838) class left gives its level's dice, and the class it follows now only its levels past
  that one, none until it passes it, as the 1st-edition PHB has it. }
function HitDice(creature: Types.PCharRecord; cls: ShortInt): Byte;

{ The count hit points are divided by: the classes with levels, as a multi-class character shares them; 1 for a
  dual-classed human, whose classes add their dice one after another. }
function HpClassCount(creature: Types.PCharRecord): Byte;

{ (sum + conB) div clsCount, the hit points a multi-class character's classes share: 1 when a negative conB would leave
  sum no more than |conB| + clsCount, a clsCount of 0 counts as 1, and more than 255 gives 255. }
function DivideAmongClasses(sum, conB: Integer; clsCount: Byte): Byte;

function HpMinimum(creature: Types.PCharRecord): Byte;

function HpMaximum(creature: Types.PCharRecord): Byte;

function RollFirstLevelHp(creature: Types.PCharRecord; mask: Byte): Byte;

{ The least a hit die rolls for Constitution con, in any class (Deities & Demigods): 1 to Con 18, 2 at 19..20 (no 1s),
  3 at 21..22 (no 1s or 2s) and 4 at 23 and up (no 1s, 2s or 3s). }
function HitDieFloor(con: Byte): Byte;

{ The hit points Constitution con gives creature over all its hit dice, as creation and training bank them (CharGen's
  ConHpBonus at each level): each class's ConHpPerDie once per hit die (HitDice: a ranger's or monk's level + 1),
  divided by the class count (HpClassCount). The difference between two Constitutions is the hit-point change a change
  of Constitution makes. }
function ConHpTotal(creature: Types.PCharRecord; con: Byte): Integer;

const
  { a prime attribute above this earns a single-class character 10% more experience }
  PRIME_STAT_THRESHOLD = 15;

{ The creature's share of experience: a single-class cleric, fighter, magic-user or thief whose prime attribute
  (Wisdom, Strength, Intelligence, Dexterity) is above PRIME_STAT_THRESHOLD gets 10% more (experience div 10 added), as
  does a paladin with Strength and Wisdom or a ranger with Strength, Intelligence and Wisdom above it; other single
  classes get experience unchanged; two-class characters get experience div 2, three-class (cleric/fighter/magic-user,
  fighter/magic-user/thief) experience div 3. Strength is the character's own (CharHlp.PermanentStrength), so Enlarge,
  the Strength spell or Gauntlets of Ogre Power earn no bonus, as SSI's strCur did (#779); nothing raises Wisdom,
  Intelligence or Dexterity by magic, so their current scores are the character's own. }
function ExperienceShare(creature: Types.PCharRecord; experience: LongInt): LongInt;

const
  { TCharRecord.itemLimits usability bit for each class-level slot (C_LEVEL). The ranger shares the paladin's bit: the
    item data gives it to the fighter's weapons and armor, and no item type carries 1 shl 7. }
  usabilityBit: array[0..7] of Byte = (
    1 shl 1, 1 shl 4, 1 shl 3, 1 shl 6, 1 shl 6, 1 shl 0, 1 shl 2, 1 shl 5);
  { Each class's prime requisites (C_LEVEL slot), one bit per ability (1 shl C_STAT): cleric Wisdom, druid Wisdom and
    Charisma, fighter Strength, paladin Strength and Wisdom, ranger Strength, Intelligence and Wisdom, magic-user
    Intelligence, thief Dexterity, monk Strength, Wisdom and Dexterity (1st-edition PHB; the Curse port's
    primeRequisites). ExperienceShare's bonus asks the same abilities. }
  primeRequisites: array[0..7] of Byte = (4, 36, 1, 5, 7, 2, 8, 13);
  { A human leaves a class with LEAVE_CLASS_SCORE or more in each of its prime requisites, and takes another with
    TAKE_CLASS_SCORE or more in each of the new class's (1st-edition PHB, p.33, "Characters With Two Classes") }
  LEAVE_CLASS_SCORE = 15;
  TAKE_CLASS_SCORE = 17;

{ The itemLimits creature's class levels give: usabilityBit of each class it has a level in and can use
  (CharHlp.GetClassLevel), so a dual-classed human's resting class lends it no weapons or armor (#838). }
function ItemLimitsFor(creature: Types.PCharRecord): Byte;

{ The spell slots of a first-level caster in class cls (C_LEVEL): a cleric's one first-level slot and its Wisdom bonus
  (AwardWisdomBonus), a magic-user's one first-level slot, and none of a higher level; other classes are left alone.
  Creation and a change of class (StartCasterClass), a class that wakes at level 1 (ChgClass.AnnounceWoken) and one
  drained back to level 1 (FitSpellsToLevel) set them, as RecalcBaseSkills sets only the slots of level 2 and up. }
procedure FirstLevelSlots(creature: Types.PCharRecord; cls: ShortInt);

{ Bring creature's spells into line with the cleric and magic-user levels it can use after losing levels (a drain,
  EffHndlr.DrainLevels, after RecalcBaseSkills): a class back at level 1 has level 1's slots (FirstLevelSlots), as
  RecalcBaseSkills sets only those of level 2 and up, and the memorized spells, pending ones too, past the slots of
  their class and spell level are cleared, the last first. So a caster drained from level 2 keeps no second slot, and
  no spell it could not have memorized at its new level (POR-0223, #955). }
procedure FitSpellsToLevel(creature: Types.PCharRecord);

{ A caster's first level in class cls (C_LEVEL), as creation gives it and a change of class does: its first-level slots
  (FirstLevelSlots); a cleric knows every first-level cleric spell, a magic-user Detect Magic, Read Magic, Shield and
  Sleep. Other classes get nothing. }
procedure StartCasterClass(creature: Types.PCharRecord; cls: ShortInt);

{ True when creature has every prime requisite of class cls (primeRequisites) at score or more: its own Strength
  (CharHlp.PermanentStrength), Intelligence, Wisdom, Dexterity, Constitution and Charisma. }
function PrimesAtLeast(creature: Types.PCharRecord; cls: ShortInt; score: Byte): Boolean;

{ True when creature may leave the class it follows (#838): a human of one class (charClass CLERIC..MONK) that has
  never changed class (CharHlp.IsDualClass), whose prime requisites are all LEAVE_CLASS_SCORE or more. A human changes
  class once, as in Curse, Secret and Pools (#879). No level is asked for: Curse, Secret and Pools ask none, nor does
  the PHB. }
function CanChangeClass(creature: Types.PCharRecord): Boolean;

{ True when creature may change to class cls (C_LEVEL): it may change (CanChangeClass); cls is a class a human takes at
  creation (classesByRace, which offers paladins and rangers, as Curse does) other than the one it follows; its prime
  requisites for cls are all TAKE_CLASS_SCORE or more, its abilities meet cls's minimums (ClassAbilityMin), and cls
  allows its alignment (alignByClass). }
function CanTakeClass(creature: Types.PCharRecord; cls: ShortInt): Boolean;

{ Change creature's class to cls, the record's part of it (ChgClass does the rest): the class it followed becomes
  portExt.formerClasses with its level kept; cls starts at level 1 with no experience and becomes charClass; drained
  levels are forfeit (Pools zeroes its drain record at the change); memorized spells and spell slots are emptied, and a
  new caster's first level set up (StartCasterClass); itemLimits and the skills follow (RecalcBaseSkills). Hit points
  stay as they are. }
procedure ChangeClass(creature: Types.PCharRecord; cls: ShortInt);

{ The chance, in percent, that creature's casting of spell from memory fails: AbilAdj.WisSpellFailure for its Wisdom
  when the spell is clerical (C_SPELL.CLASS_CLERIC) and the creature has cleric levels, which in AD&D 1st edition is
  the rule for clerics (#60); 0 otherwise. A paladin without cleric levels is not subject to it (he needs Wisdom 13, at
  which it is 0 anyway), and neither is a spell read from a scroll, which the caller does not ask about. 0 for an id
  outside 1..C_SPELL.LAST. }
function SpellFailureChance(creature: Types.PCharRecord; spell: Byte): Byte;

{ The experience level lvl of class slot cls (C_LEVEL) starts at: 0 for level 1 or below, the 1st-edition PHB's figure
  (GameDefs.classExperience) for levels 2..C_LEVEL.LEVEL_LAST, and -1 for a class without a table (druid, monk) or a
  level past LEVEL_LAST. It holds for a level a creature already has; whether a class may train to it is LevelOpen's. }
function LevelXp(cls: ShortInt; lvl: Integer): LongInt;

{ The highest level class slot cls trains to (#1121): SSI's while the Game Level Cap setting is on (GameVars.levelCapOn:
  cleric and magic-user 6, paladin and ranger 7, fighter 8, thief 9), and C_LEVEL.LEVEL_LAST for every class with a
  table while it is off. The racial limits are CharHlp.AtLevelCap's, a test of their own (#1176). }
function MaxLevel(cls: ShortInt): ShortInt;

{ True when class slot cls has a level lvl to train to: lvl is 2..MaxLevel and has a LevelXp figure. Training, its
  experience clamp and Restoration ask it. }
function LevelOpen(cls: ShortInt; lvl: Integer): Boolean;

{ lvl, or C_LEVEL.LEVEL_LAST for one past it: the last row of the tables that run to it. }
function MinLevel(lvl: ShortInt): ShortInt;

implementation

uses GameDefs, GameVars, C_CLASS, C_LEVEL, C_STAT, C_EQUIP, C_ITEM, C_SAVE, Dice, CharHlp, AbilAdj;

const
  { the highest level each class slot reached in SSI's game, where its experience table stopped: MaxLevel's with the
    Game Level Cap setting on (#1121); the druid and monk have no table }
  ssiLevelCaps: array[C_LEVEL.CLERIC..C_LEVEL.MONK] of ShortInt = (6, 0, 8, 7, 7, 6, 9, 0);
  { StartingAge's dice: the DMG's starting ages (p.12), by race and class (C_LEVEL); the monk column (7) has only the
    DMG's human monk, 21 + 1d4, as creation offers no monk }
  ageDice: array[C_RACE.DWARF..C_RACE.HUMAN, C_LEVEL.CLERIC..C_LEVEL.MONK] of Types.TRuleAge = (
    ((base: 250; num: 2; sides: 20), (base: 0; num: 0; sides: 0), (base: 40; num: 5; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 75; num: 3; sides: 6), (base: 0; num: 0; sides: 0)),
    ((base: 650; num: 10; sides: 10), (base: 0; num: 0; sides: 0), (base: 130; num: 5; sides: 6),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 150; num: 5; sides: 6),
     (base: 100; num: 5; sides: 6), (base: 0; num: 0; sides: 0)),
    ((base: 300; num: 3; sides: 12), (base: 0; num: 0; sides: 0), (base: 60; num: 5; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 100; num: 2; sides: 12),
     (base: 80; num: 5; sides: 4), (base: 0; num: 0; sides: 0)),
    ((base: 40; num: 2; sides: 4), (base: 0; num: 0; sides: 0), (base: 22; num: 3; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 22; num: 3; sides: 4), (base: 30; num: 2; sides: 8),
     (base: 22; num: 3; sides: 8), (base: 0; num: 0; sides: 0)),
    ((base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 20; num: 3; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 40; num: 2; sides: 4), (base: 0; num: 0; sides: 0)),
    ((base: 20; num: 1; sides: 4), (base: 0; num: 0; sides: 0), (base: 13; num: 1; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 20; num: 2; sides: 4), (base: 0; num: 0; sides: 0)),
    ((base: 18; num: 1; sides: 4), (base: 18; num: 1; sides: 4), (base: 15; num: 1; sides: 4),
     (base: 17; num: 1; sides: 4), (base: 20; num: 1; sides: 4), (base: 24; num: 2; sides: 8),
     (base: 18; num: 1; sides: 4), (base: 21; num: 1; sides: 4)));

function StartingAge(race, charClass: ShortInt): Word;
var
  p: Byte;
  part: ShortInt;
  oldest: Word;
begin
  if charClass <= C_CLASS.MONK then
    with ageDice[race, charClass] do
      StartingAge := Dice.RollDice(num, sides) + base
  else begin
    oldest := 0;
    for p := 1 to 3 do begin
      part := GameDefs.classParts[charClass].values[p];
      if (part >= C_LEVEL.CLERIC) and (part <= C_LEVEL.MONK) then
        with ageDice[race, part] do
          if base + sides * num > oldest then
            oldest := base + sides * num;
    end;
    StartingAge := oldest;
  end;
end;

function ItemLimitsFor(creature: Types.PCharRecord): Byte;
var
  limits: Byte;
  cls: ShortInt;
begin
  limits := 0;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if CharHlp.GetClassLevel(creature, 1 shl cls) > 0 then
      limits := limits or usabilityBit[cls];
  ItemLimitsFor := limits;
end;

procedure FirstLevelSlots(creature: Types.PCharRecord; cls: ShortInt);
begin
  case cls of
    C_LEVEL.CLERIC: begin
        CharHlp.ClearSpellSlots(creature, C_SPELL.CLASS_CLERIC);
        CharHlp.SetSpellSlots(creature, C_SPELL.CLASS_CLERIC, 1, 1);
        ClassCal.AwardWisdomBonus(creature);
      end;
    C_LEVEL.MAGE: begin
        CharHlp.ClearSpellSlots(creature, C_SPELL.CLASS_MAGE);
        CharHlp.SetSpellSlots(creature, C_SPELL.CLASS_MAGE, 1, 1);
      end;
  end;
end;

{ Mark known every cleric and druid spell (castClass C_SPELL.CLASS_CLERIC, CLASS_DRUID) of a level creature has slots of
  that kind for: a cleric, a paladin and a ranger know every spell of their lists they can cast, as a magic-user does
  not. }
procedure KnowClericSpells(creature: Types.PCharRecord);
var
  m: Byte;
begin
  for m := 1 to C_SPELL.LAST do
    if CharHlp.IsSpell(m) then
      with GameDefs.spellTable[m] do
        if (castClass = C_SPELL.CLASS_CLERIC) or (castClass = C_SPELL.CLASS_DRUID) then
          if CharHlp.SpellSlots(creature, castClass, levelSp) > 0 then
            CharHlp.SetSpellKnown(creature, m, True);
end;

procedure FitSpellsToLevel(creature: Types.PCharRecord);
var
  kind: ShortInt;
  lvl: ShortInt;
  room: Byte;
  have: Byte;
  i: Byte;
  id: Byte;
begin
  if CharHlp.GetClassLevel(creature, C_LEVEL.CLERIC_BIT) = 1 then
    ClassCal.FirstLevelSlots(creature, C_LEVEL.CLERIC);
  if CharHlp.GetClassLevel(creature, C_LEVEL.MAGE_BIT) = 1 then
    ClassCal.FirstLevelSlots(creature, C_LEVEL.MAGE);
  for kind := C_SPELL.CLASS_CLERIC to C_SPELL.SLOT_KIND_LAST do
    for lvl := 1 to Types.CASTER_LEVEL_LAST do begin
      room := CharHlp.SpellSlots(creature, kind, lvl);
      have := 0;
      for i := 0 to Types.MEMORIZED_LAST do begin
        id := CharHlp.MemorizedAt(creature, i) and C_SPELL.ID_MASK;
        if CharHlp.IsSpell(id) then
          if (GameDefs.spellTable[id].castClass = kind) and (GameDefs.spellTable[id].levelSp = lvl) then begin
            Inc(have);
            if have > room then
              CharHlp.SetMemorizedAt(creature, i, 0);
          end;
      end;
    end;
end;

procedure StartCasterClass(creature: Types.PCharRecord; cls: ShortInt);
begin
  ClassCal.FirstLevelSlots(creature, cls);
  case cls of
    C_LEVEL.CLERIC: ClassCal.KnowClericSpells(creature);
    C_LEVEL.MAGE: begin
        CharHlp.SetSpellKnown(creature, C_SPELL.DETECT_MAGIC_MU, True);
        CharHlp.SetSpellKnown(creature, C_SPELL.READ_MAGIC, True);
        CharHlp.SetSpellKnown(creature, C_SPELL.SHIELD, True);
        CharHlp.SetSpellKnown(creature, C_SPELL.SLEEP, True);
      end;
  end;
end;

function PrimesAtLeast(creature: Types.PCharRecord; cls: ShortInt; score: Byte): Boolean;
var
  ab: ShortInt;
  have: Byte;
  ok: Boolean;
begin
  ok := True;
  for ab := C_STAT.STRENGTH to C_STAT.CHARISMA do
    if primeRequisites[cls] and (1 shl ab) <> 0 then begin
      if ab = C_STAT.STRENGTH then
        have := CharHlp.PermanentStrength(creature)
      else
        have := creature^.stats[ab];
      if have < score then
        ok := False;
    end;
  PrimesAtLeast := ok;
end;

function CanChangeClass(creature: Types.PCharRecord): Boolean;
begin
  CanChangeClass := (creature^.race = C_RACE.HUMAN) and (creature^.charClass >= C_CLASS.CLERIC) and
                    (creature^.charClass <= C_CLASS.MONK) and not CharHlp.IsDualClass(creature) and
                    ClassCal.PrimesAtLeast(creature, creature^.charClass, LEAVE_CLASS_SCORE);
end;

function CanTakeClass(creature: Types.PCharRecord; cls: ShortInt): Boolean;
var
  ok: Boolean;
  i: ShortInt;
begin
  ok := ClassCal.CanChangeClass(creature) and (cls <> creature^.charClass) and (creature^.classLevels[cls] <= 0);
  if ok then begin
    ok := False;
    with classesByRace[C_RACE.HUMAN] do
      for i := 1 to count do
        if classes[i] = cls then
          ok := True;
  end;
  if ok then
    ok := ClassCal.PrimesAtLeast(creature, cls, TAKE_CLASS_SCORE);
  if ok then
    for i := C_STAT.STRENGTH to C_STAT.CHARISMA do
      if creature^.stats[i] < ClassCal.ClassAbilityMin(creature^.race, cls, i) then
        ok := False;
  if ok then begin
    ok := False;
    with alignByClass[cls] do
      for i := 1 to count do
        if alignments[i] = creature^.alignment then
          ok := True;
  end;
  CanTakeClass := ok;
end;

procedure ChangeClass(creature: Types.PCharRecord; cls: ShortInt);
begin
  with creature^ do begin
    portExt.formerClasses := 1 shl charClass;
    charClass := cls;
    classLevels[cls] := 1;
    experience := 0;
    drainedLevels := 0;
    drainedHps := 0;
  end;
  CharHlp.ClearMemorized(creature);
  CharHlp.ClearSpellSlots(creature, C_SPELL.CLASS_CLERIC);
  CharHlp.ClearSpellSlots(creature, C_SPELL.CLASS_MAGE);
  CharHlp.ClearSpellSlots(creature, C_SPELL.CLASS_DRUID);
  ClassCal.StartCasterClass(creature, cls);
  ClassCal.RecalcBaseSkills(creature);
end;

const
  { dice per class, used by creation and training }
  hpDice: array[0..7] of Byte = (
    { Cleric: 1d8 }
    1,
    { Druid: 1d8 }
    1,
    { Fighter: 1d10 }
    1,
    { Paladin: 1d10 }
    1,
    { Ranger: 2d8 }
    2,
    { Magic-User: 1d4 }
    1,
    { Thief: 1d6 }
    1,
    { Monk: 2d4 }
    2);

{ Recompute base THAC0 (the highest 60 - THAC0 value across all eight class slots), raise levelHighest, set warrior
  attacks (stored doubled: 3 for a fighter or paladin above level 6 or a ranger above level 7, else 2; set for every
  character), and set the spell slots (CasterSlots). classThac0 covers levels 0..10, and a level outside that uses the nearer end. A dual-classed human's itemLimits are set
  (ItemLimitsFor). Each class counts at the level the creature can use
  (CharHlp.GetClassLevel): a class a dual-classed human has left and cannot use yet gives nothing, and a resting
  cleric's or magic-user's slots are emptied (#838); levelHighest takes the levels as they are. Then call RecalcSaves
  and RecalcThiefSkills. }
{ A row of a class's slots by spell level, to Types.CASTER_LEVEL_LAST. }
type
  TSlotRow = array[1..Types.CASTER_LEVEL_LAST] of Byte;

{ Set creature's slots of kind to row, or add row to them when add. }
procedure PutSlotRow(creature: Types.PCharRecord; kind: ShortInt; var row: TSlotRow; add: Boolean);
var
  k: ShortInt;
begin
  for k := 1 to Types.CASTER_LEVEL_LAST do
    if add then
      CharHlp.SetSpellSlots(creature, kind, k, CharHlp.SpellSlots(creature, kind, k) + row[k])
    else
      CharHlp.SetSpellSlots(creature, kind, k, row[k]);
end;

{ Set creature's spell slots from the class levels it can use (CharHlp.GetClassLevel), the 1st-edition PHB's to level
  9 (#1121). A cleric or magic-user above level 1 takes its level's row of GameDefs.classExperience (a level past the
  table its last), a cleric with the Wisdom bonus (AwardWisdomBonus) and a fifth-level slot only at Wisdom
  GameDefs.CLERIC_FIFTH_LEVEL_WISDOM; a level-1 caster's slots are FirstLevelSlots' and left as they are, and so are a
  creature's with no cleric or magic-user, paladin or ranger levels (a monster's from its record). A paladin from level
  9 adds GameDefs.paladinSlots' cleric slots, and a ranger from level 8 GameDefs.rangerMageSlots' magic-user slots and
  rangerDruidSlots' druid slots, which no Wisdom bonus adds to; a paladin or ranger without cleric or magic-user levels
  has its row alone, none below that level. A cleric or druid knows every spell of a level it has slots for
  (KnowClericSpells). }
procedure CasterSlots(creature: Types.PCharRecord);
var
  clr: ShortInt;
  mag: ShortInt;
  pal: ShortInt;
  rng: ShortInt;
  row: TSlotRow;
  k: ShortInt;
begin
  clr := CharHlp.GetClassLevel(creature, C_LEVEL.CLERIC_BIT);
  mag := CharHlp.GetClassLevel(creature, C_LEVEL.MAGE_BIT);
  pal := CharHlp.GetClassLevel(creature, C_LEVEL.PALADIN_BIT);
  rng := CharHlp.GetClassLevel(creature, C_LEVEL.RANGER_BIT);
  if clr > 1 then begin
    if clr > C_LEVEL.LEVEL_LAST then
      clr := C_LEVEL.LEVEL_LAST;
    for k := 1 to Types.CASTER_LEVEL_LAST do
      row[k] := GameDefs.classExperience[C_LEVEL.CLERIC].slots[clr, k];
    if creature^.wisCur < GameDefs.CLERIC_FIFTH_LEVEL_WISDOM then
      row[5] := 0;
    ClassCal.PutSlotRow(creature, C_SPELL.CLASS_CLERIC, row, False);
    ClassCal.AwardWisdomBonus(creature);
  end;
  if (clr > 1) or ((clr <= 0) and (pal > 0)) then begin
    FillChar(row, SizeOf(row), 0);
    if pal >= GameDefs.PALADIN_SPELLS_FROM then
      for k := 1 to Types.CASTER_LEVEL_LAST do
        row[k] := GameDefs.paladinSlots[ClassCal.MinLevel(pal), k];
    ClassCal.PutSlotRow(creature, C_SPELL.CLASS_CLERIC, row, clr > 1);
  end;
  if mag > 1 then begin
    if mag > C_LEVEL.LEVEL_LAST then
      mag := C_LEVEL.LEVEL_LAST;
    for k := 1 to Types.CASTER_LEVEL_LAST do
      row[k] := GameDefs.classExperience[C_LEVEL.MAGE].slots[mag, k];
    ClassCal.PutSlotRow(creature, C_SPELL.CLASS_MAGE, row, False);
  end;
  FillChar(row, SizeOf(row), 0);
  if rng >= GameDefs.RANGER_SPELLS_FROM then
    for k := 1 to Types.CASTER_LEVEL_LAST do
      row[k] := GameDefs.rangerMageSlots[ClassCal.MinLevel(rng), k];
  if (mag > 1) or ((mag <= 0) and (rng > 0)) then
    ClassCal.PutSlotRow(creature, C_SPELL.CLASS_MAGE, row, mag > 1);
  FillChar(row, SizeOf(row), 0);
  if rng >= GameDefs.RANGER_SPELLS_FROM then
    for k := 1 to Types.CASTER_LEVEL_LAST do
      row[k] := GameDefs.rangerDruidSlots[ClassCal.MinLevel(rng), k];
  ClassCal.PutSlotRow(creature, C_SPELL.CLASS_DRUID, row, False);
  if (clr > 1) or (pal > 0) or (rng > 0) then
    ClassCal.KnowClericSpells(creature);
end;

procedure RecalcBaseSkills(creature: Types.PCharRecord);
var
  i: ShortInt;
  lvl: ShortInt;
  tl: ShortInt;
begin
  creature^.thac0Base := 0;
  for i := C_LEVEL.CLERIC to C_LEVEL.MONK do begin
    if creature^.levelHighest < creature^.classLevels[i] then
      creature^.levelHighest := creature^.classLevels[i];
    lvl := CharHlp.GetClassLevel(creature, 1 shl i);
    if CharHlp.ClassResting(creature, i) then
      case i of
        C_LEVEL.CLERIC: CharHlp.ClearSpellSlots(creature, C_SPELL.CLASS_CLERIC);
        C_LEVEL.MAGE: CharHlp.ClearSpellSlots(creature, C_SPELL.CLASS_MAGE);
      end;
    tl := lvl;
    if tl < 0 then
      tl := 0
    else if tl > 10 then
      tl := 10;
    if GameDefs.classThac0[i, tl] > creature^.thac0Base then
      creature^.thac0Base := GameDefs.classThac0[i, tl];
    case i of
      C_LEVEL.FIGHTER:
        if lvl > 6 then creature^.attacks := 3 else creature^.attacks := 2;
      { after the fighter's slot, so these only raise it }
      C_LEVEL.PALADIN:
        if lvl > 6 then creature^.attacks := 3;
      C_LEVEL.RANGER:
        if lvl > 7 then creature^.attacks := 3;
    end;
  end;
  ClassCal.CasterSlots(creature);
  { a dual-classed human's weapons and armor follow the classes it can use; anyone else keeps creation's }
  if CharHlp.IsDualClass(creature) then
    creature^.itemLimits := ClassCal.ItemLimitsFor(creature);
  ClassCal.RecalcSaves(creature);
  ClassCal.RecalcThiefSkills(creature);
end;

{ Add the Wisdom bonus cleric slots, cumulative over wisBonusSpells' rows from 13 to the creature's Wisdom
  (above 25 counts as 25): Wisdom 13 and 14 each add a first-level slot, 15 and 16 a second-level slot, 17 a third-level
  slot, 18 a fourth, and so on to 25. Only the spell levels a cleric has slots for here (1..Types.CASTER_LEVEL_LAST)
  take them, and each only where that level's slot count is already non-zero. }
procedure AwardWisdomBonus(creature: Types.PCharRecord);
var
  w: Byte;
  wis: Byte;
  lvl: Byte;
begin
  with creature^ do begin
    wis := wisCur;
    if wis > 25 then
      wis := 25;
    for w := 13 to wis do
      for lvl := 1 to Types.CASTER_LEVEL_LAST do
        if CharHlp.SpellSlots(creature, C_SPELL.CLASS_CLERIC, lvl) > 0 then
          CharHlp.SetSpellSlots(creature, C_SPELL.CLASS_CLERIC, lvl,
                                CharHlp.SpellSlots(creature, C_SPELL.CLASS_CLERIC, lvl) + wisBonusSpells[w, lvl]);
  end;
end;

procedure ResetClericSlots(creature: Types.PCharRecord);
var
  lvl: ShortInt;
begin
  lvl := CharHlp.GetClassLevel(creature, C_LEVEL.CLERIC_BIT);
  if lvl > 1 then
    ClassCal.RecalcBaseSkills(creature)
  else if lvl = 1 then
    ClassCal.FirstLevelSlots(creature, C_LEVEL.CLERIC);
end;

{ Start every saving throw at 20 and take the best (lowest) across all classes with a level above 0 the creature can
  use (CharHlp.GetClassLevel). saveTbl covers levels 1..9, and a higher level uses the level 9 row. }
procedure RecalcSaves(creature: Types.PCharRecord);
const
  { Saving throws indexed by class-level slot (C_LEVEL), level 1..9 and save column 0..4. The paladin's row is
    the fighter's less 2. }
  saveTbl: array[C_LEVEL.CLERIC..C_LEVEL.MONK, 1..9] of Types.TRuleSaves = (
    { cleric }
    ((paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12)),
    { druid }
    ((paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12)),
    { fighter }
    ((paralyze: 14; petrify: 15; wand: 16; breath: 17; spell: 17),
     (paralyze: 14; petrify: 15; wand: 16; breath: 17; spell: 17),
     (paralyze: 13; petrify: 14; wand: 15; breath: 16; spell: 16),
     (paralyze: 13; petrify: 14; wand: 15; breath: 16; spell: 16),
     (paralyze: 11; petrify: 12; wand: 13; breath: 13; spell: 14),
     (paralyze: 11; petrify: 12; wand: 13; breath: 13; spell: 14),
     (paralyze: 10; petrify: 11; wand: 12; breath: 12; spell: 13),
     (paralyze: 10; petrify: 11; wand: 12; breath: 12; spell: 13),
     (paralyze: 8; petrify: 9; wand: 10; breath: 9; spell: 11)),
    { paladin }
    ((paralyze: 12; petrify: 13; wand: 14; breath: 15; spell: 15),
     (paralyze: 12; petrify: 13; wand: 14; breath: 15; spell: 15),
     (paralyze: 11; petrify: 12; wand: 13; breath: 14; spell: 14),
     (paralyze: 11; petrify: 12; wand: 13; breath: 14; spell: 14),
     (paralyze: 9; petrify: 10; wand: 11; breath: 11; spell: 12),
     (paralyze: 9; petrify: 10; wand: 11; breath: 11; spell: 12),
     (paralyze: 8; petrify: 9; wand: 10; breath: 10; spell: 11),
     (paralyze: 8; petrify: 9; wand: 10; breath: 10; spell: 11),
     (paralyze: 6; petrify: 7; wand: 8; breath: 7; spell: 9)),
    { ranger }
    ((paralyze: 14; petrify: 15; wand: 16; breath: 17; spell: 17),
     (paralyze: 14; petrify: 15; wand: 16; breath: 17; spell: 17),
     (paralyze: 13; petrify: 14; wand: 15; breath: 16; spell: 16),
     (paralyze: 13; petrify: 14; wand: 15; breath: 16; spell: 16),
     (paralyze: 11; petrify: 12; wand: 13; breath: 13; spell: 14),
     (paralyze: 11; petrify: 12; wand: 13; breath: 13; spell: 14),
     (paralyze: 10; petrify: 11; wand: 12; breath: 12; spell: 13),
     (paralyze: 10; petrify: 11; wand: 12; breath: 12; spell: 13),
     (paralyze: 8; petrify: 9; wand: 10; breath: 9; spell: 11)),
    { magic-user }
    ((paralyze: 14; petrify: 13; wand: 11; breath: 15; spell: 12),
     (paralyze: 14; petrify: 13; wand: 11; breath: 15; spell: 12),
     (paralyze: 14; petrify: 13; wand: 11; breath: 15; spell: 12),
     (paralyze: 14; petrify: 13; wand: 11; breath: 15; spell: 12),
     (paralyze: 14; petrify: 13; wand: 11; breath: 15; spell: 12),
     (paralyze: 13; petrify: 11; wand: 9; breath: 13; spell: 10),
     (paralyze: 13; petrify: 11; wand: 9; breath: 13; spell: 10),
     (paralyze: 13; petrify: 11; wand: 9; breath: 13; spell: 10),
     (paralyze: 13; petrify: 11; wand: 9; breath: 13; spell: 10)),
    { thief }
    ((paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 11; petrify: 10; wand: 10; breath: 14; spell: 11)),
    { monk }
    ((paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 11; petrify: 10; wand: 10; breath: 14; spell: 11)));
var
  i: ShortInt;
  k: ShortInt;
  lvl: ShortInt;
begin
  for i := C_SAVE.PARALYZE to C_SAVE.SPELL do begin
    creature^.saves[i] := 20;
    for k := C_LEVEL.CLERIC to C_LEVEL.MONK do begin
      lvl := CharHlp.GetClassLevel(creature, 1 shl k);
      if lvl > 0 then begin
        if lvl > 9 then
          lvl := 9;
        if creature^.saves[i] > saveTbl[k, lvl].values[i] then
          creature^.saves[i] := saveTbl[k, lvl].values[i];
      end;
    end;
  end;
end;

{ Set each thief skill (ThiefSkillParts, ThiefSkill) to its base for the thief level plus the racial adjustment (a
  racial penalty larger than the base zeroes the skill), plus the Dexterity adjustment for skills 1..5, stopping at 0
  (a Dexterity 9 human's Move Silently would be -5). Armor that bars them (ArmorBarsThiefSkills) zeroes every skill, so
  every reader of thiefSkills (Open Locks, the scripts' party checks) sees it. A creature without thief levels keeps
  its skills as they are, but a dual-classed human's resting thief levels (CharHlp.ClassResting) give none: its skills
  are 0 until it can use them again (#838). }
procedure RecalcThiefSkills(creature: Types.PCharRecord);
var
  j: Byte;
  base: ShortInt;
  racial: ShortInt;
  dexterity: ShortInt;
  barred: Boolean;
begin
  if CharHlp.ClassResting(creature, C_LEVEL.THIEF) then
    FillChar(creature^.thiefSkills, SizeOf(creature^.thiefSkills), 0);
  if CharHlp.GetClassLevel(creature, C_LEVEL.THIEF_BIT) < 1 then
    Exit;
  barred := ClassCal.ArmorBarsThiefSkills(creature);
  { thiefSkills holds a byte a skill }
  for j := 1 to SizeOf(creature^.thiefSkills) do begin
    ClassCal.ThiefSkillParts(creature, j, base, racial, dexterity);
    if barred then
      creature^.thiefSkills[j] := 0
    else
      creature^.thiefSkills[j] := ClassCal.ThiefSkill(base, racial, dexterity);
  end;
end;

function ArmorBarsThiefSkills(creature: Types.PCharRecord): Boolean;
begin
  ArmorBarsThiefSkills := (creature^.equipped[C_EQUIP.SHIELD] <> nil) or
                          ((creature^.equipped[C_EQUIP.ARMOR] <> nil) and
                           (creature^.equipped[C_EQUIP.ARMOR]^.itemType <> C_ITEM.LEATHER_ARMOR));
end;

{ dexAdj covers Dexterity 9..25, a thief's minimum to Deities & Demigods' highest; a Dexterity outside that range uses
  the nearer end. thiefBase covers thief levels 1..9, and a higher level uses the level 9 row; a race outside the player
  races (raceAdj covers 1..7) takes the human row, which adjusts nothing. }
procedure ThiefSkillParts(creature: Types.PCharRecord; j: Byte; var base, racial, dexterity: ShortInt);
const
  { Base thief abilities by thief level }
  thiefBase: array[1..9] of Types.TRuleThief = (
    (pickPockets: 30; openLocks: 25; findTraps: 20; moveSilently: 15; hideShadows: 10;
     hearNoise: 10; climbWalls: 85; readLanguages: 0),
    (pickPockets: 35; openLocks: 29; findTraps: 25; moveSilently: 21; hideShadows: 15;
     hearNoise: 10; climbWalls: 86; readLanguages: 0),
    (pickPockets: 40; openLocks: 33; findTraps: 30; moveSilently: 27; hideShadows: 20;
     hearNoise: 15; climbWalls: 87; readLanguages: 0),
    (pickPockets: 45; openLocks: 37; findTraps: 35; moveSilently: 33; hideShadows: 25;
     hearNoise: 15; climbWalls: 88; readLanguages: 20),
    (pickPockets: 50; openLocks: 42; findTraps: 40; moveSilently: 40; hideShadows: 31;
     hearNoise: 20; climbWalls: 90; readLanguages: 25),
    (pickPockets: 55; openLocks: 47; findTraps: 45; moveSilently: 47; hideShadows: 37;
     hearNoise: 20; climbWalls: 92; readLanguages: 30),
    (pickPockets: 60; openLocks: 52; findTraps: 50; moveSilently: 55; hideShadows: 43;
     hearNoise: 25; climbWalls: 94; readLanguages: 35),
    (pickPockets: 65; openLocks: 57; findTraps: 55; moveSilently: 62; hideShadows: 49;
     hearNoise: 25; climbWalls: 96; readLanguages: 40),
    (pickPockets: 70; openLocks: 62; findTraps: 60; moveSilently: 70; hideShadows: 56;
     hearNoise: 30; climbWalls: 98; readLanguages: 45));
  { Racial thief ability adjustments: dwarf, elf, gnome, half-elf, halfling, half-orc, human }
  raceAdj: array[1..7] of Types.TRuleThief = (
    (pickPockets: 0; openLocks: 10; findTraps: 15; moveSilently: 0; hideShadows: 0;
     hearNoise: 0; climbWalls: -10; readLanguages: -5),
    (pickPockets: 5; openLocks: -5; findTraps: 0; moveSilently: 5; hideShadows: 10;
     hearNoise: 5; climbWalls: 0; readLanguages: 0),
    (pickPockets: 0; openLocks: 5; findTraps: 10; moveSilently: 5; hideShadows: 5;
     hearNoise: 10; climbWalls: -15; readLanguages: 0),
    (pickPockets: 10; openLocks: 0; findTraps: 0; moveSilently: 0; hideShadows: 5;
     hearNoise: 0; climbWalls: 0; readLanguages: 0),
    (pickPockets: 5; openLocks: 5; findTraps: 5; moveSilently: 10; hideShadows: 15;
     hearNoise: 5; climbWalls: -15; readLanguages: -5),
    (pickPockets: -5; openLocks: 5; findTraps: 5; moveSilently: 0; hideShadows: 0;
     hearNoise: 5; climbWalls: 5; readLanguages: -10),
    (pickPockets: 0; openLocks: 0; findTraps: 0; moveSilently: 0; hideShadows: 0;
     hearNoise: 0; climbWalls: 0; readLanguages: 0));
  { Dexterity thief ability adjustments for Dexterity 9..25 }
  dexAdj: array[9..25] of Types.TRuleThiefDex = (
    (pickPockets: -15; openLocks: -10; findTraps: -10; moveSilently: -20; hideShadows: -10),
    (pickPockets: -10; openLocks:  -5; findTraps: -10; moveSilently: -15; hideShadows:  -5),
    (pickPockets:  -5; openLocks:   0; findTraps:  -5; moveSilently: -10; hideShadows:   0),
    (pickPockets:   0; openLocks:   0; findTraps:   0; moveSilently:  -5; hideShadows:   0),
    (pickPockets:   0; openLocks:   0; findTraps:   0; moveSilently:   0; hideShadows:   0),
    (pickPockets:   0; openLocks:   0; findTraps:   0; moveSilently:   0; hideShadows:   0),
    (pickPockets:   0; openLocks:   0; findTraps:   0; moveSilently:   0; hideShadows:   0),
    (pickPockets:   0; openLocks:   5; findTraps:   0; moveSilently:   0; hideShadows:   0),
    (pickPockets:   5; openLocks:  10; findTraps:   0; moveSilently:   5; hideShadows:   5),
    (pickPockets:  10; openLocks:  15; findTraps:   5; moveSilently:  10; hideShadows:  10),
    (pickPockets:  15; openLocks:  20; findTraps:  10; moveSilently:  12; hideShadows:  12),
    { 20..25 from Deities & Demigods }
    (pickPockets:  20; openLocks:  25; findTraps:  15; moveSilently:  15; hideShadows:  15),
    (pickPockets:  25; openLocks:  30; findTraps:  20; moveSilently:  18; hideShadows:  18),
    (pickPockets:  30; openLocks:  35; findTraps:  25; moveSilently:  20; hideShadows:  20),
    (pickPockets:  35; openLocks:  40; findTraps:  30; moveSilently:  23; hideShadows:  23),
    (pickPockets:  40; openLocks:  45; findTraps:  35; moveSilently:  25; hideShadows:  25),
    (pickPockets:  45; openLocks:  50; findTraps:  40; moveSilently:  30; hideShadows:  30));
var
  dex: Byte;
  r: ShortInt;
  tl: ShortInt;
begin
  dex := creature^.dexCur;
  if dex < 9 then
    dex := 9
  else if dex > 25 then
    dex := 25;
  r := creature^.race;
  if (r < C_RACE.DWARF) or (r > C_RACE.HUMAN) then
    r := C_RACE.HUMAN;
  tl := CharHlp.GetClassLevel(creature, C_LEVEL.THIEF_BIT);
  if tl < 1 then
    tl := 1
  else if tl > 9 then
    tl := 9;
  base := thiefBase[tl].values[j];
  racial := raceAdj[r].values[j];
  dexterity := 0;
  { dexAdj covers skills 1..5 only }
  if j < 6 then
    dexterity := dexAdj[dex].values[j];
end;

function ThiefSkill(base, racial, dexterity: ShortInt): Byte;
var
  total: Integer;
begin
  if (racial < 0) and (Abs(racial) > base) then
    ThiefSkill := 0
  else begin
    total := base + racial + dexterity;
    if total < 0 then
      total := 0;
    ThiefSkill := total;
  end;
end;

function TurnLevel(creature: Types.PCharRecord): ShortInt;
var
  lvl: ShortInt;
  paladin: ShortInt;
begin
  lvl := CharHlp.GetClassLevel(creature, C_LEVEL.CLERIC_BIT);
  paladin := CharHlp.GetClassLevel(creature, C_LEVEL.PALADIN_BIT) - 2;
  if paladin > lvl then
    lvl := paladin;
  if lvl < 0 then
    lvl := 0;
  TurnLevel := lvl;
end;

function TurnValue(undeadLevel, lvl: ShortInt): ShortInt;
const
  { Rows by undead level, columns by turn level, as TurnValue reads them. A negative value lets
    CbtActs.CombatTurnUndead go on past its 1d12 targets until six succeed. }
  turnUndeadResults: Types.TTurnUndeadTable = (
    { 1: Skeleton }
    (10, 7, 4, 1, 1, 0, 0, -1, -1, -1),
    { 2: Zombie }
    (13, 10, 7, 1, 1, 0, 0, 0, -1, -1),
    { 3: Ghoul }
    (16, 13, 10, 4, 1, 1, 0, 0, 0, -1),
    { 4: Shadow }
    (19, 16, 13, 7, 4, 1, 1, 0, 0, -1),
    { 5: Wight }
    (20, 19, 16, 10, 7, 4, 1, 1, 0, 0),
    { 6: Ghast }
    (99, 20, 19, 13, 10, 7, 4, 1, 1, 0),
    { 7: Wraith }
    (99, 99, 20, 16, 13, 10, 7, 4, 1, 0),
    { 8: Mummy }
    (99, 99, 99, 20, 16, 13, 10, 7, 4, 1),
    { 9: Spectre }
    (99, 99, 99, 99, 20, 16, 13, 10, 7, 1),
    { 10: Vampire }
    (99, 99, 99, 99, 99, 20, 16, 13, 10, 4));
var
  col: ShortInt;
begin
  if (lvl < 1) or (undeadLevel < 1) then begin
    TurnValue := TURN_IMMUNE;
    Exit;
  end;
  case lvl of
    1..8: col := lvl;
    9..13: col := 9;
  else
    col := 10;
  end;
  if undeadLevel > TURN_UNDEAD_KINDS then
    undeadLevel := TURN_UNDEAD_KINDS;
  TurnValue := turnUndeadResults[undeadLevel, col];
end;

function RaceAbilityMin(race, gender, ability: ShortInt): Byte;
begin
  with GameDefs.minimumMaximumStatistics[race] do
    case ability of
      C_STAT.STRENGTH: RaceAbilityMin := strMin[gender];
      C_STAT.INTELLIGENCE: RaceAbilityMin := intMin;
      C_STAT.WISDOM: RaceAbilityMin := wisMin;
      C_STAT.DEXTERITY: RaceAbilityMin := dexMin;
      C_STAT.CONSTITUTION: RaceAbilityMin := conMin;
    else
      RaceAbilityMin := chaMin;
    end;
end;

function RaceAbilityMax(race, gender, ability: ShortInt): Byte;
begin
  with GameDefs.minimumMaximumStatistics[race] do
    case ability of
      C_STAT.STRENGTH: RaceAbilityMax := strMax[gender];
      C_STAT.INTELLIGENCE: RaceAbilityMax := intMax;
      C_STAT.WISDOM: RaceAbilityMax := wisMax;
      C_STAT.DEXTERITY: RaceAbilityMax := dexMax;
      C_STAT.CONSTITUTION: RaceAbilityMax := conMax;
    else
      RaceAbilityMax := chaMax;
    end;
end;

function ClassAbilityMin(race, charClass, ability: ShortInt): Byte;
const
  { Ability minimums by single class (C_CLASS.CLERIC..MONK), the 1st-edition PHB's: every class needs at least 3, and
    most 6, in each ability (#740). A multiclass needs the highest of its classes' (ClassCal.ClassAbilityMin). }
  classMin: array[C_CLASS.CLERIC..C_CLASS.MONK] of Types.TRuleAbilities = (
    { cleric }
    (strength: 6; intelligence: 6; wisdom: 9; dexterity: 3; constitution: 6; charisma: 6),
    { druid }
    (strength: 6; intelligence: 6; wisdom: 12; dexterity: 6; constitution: 6; charisma: 15),
    { fighter }
    (strength: 9; intelligence: 3; wisdom: 6; dexterity: 6; constitution: 7; charisma: 6),
    { paladin }
    (strength: 12; intelligence: 9; wisdom: 13; dexterity: 6; constitution: 9; charisma: 17),
    { ranger }
    (strength: 13; intelligence: 13; wisdom: 14; dexterity: 6; constitution: 14; charisma: 6),
    { magic-user }
    (strength: 3; intelligence: 9; wisdom: 6; dexterity: 6; constitution: 6; charisma: 6),
    { thief }
    (strength: 6; intelligence: 6; wisdom: 3; dexterity: 9; constitution: 6; charisma: 6),
    { monk }
    (strength: 15; intelligence: 6; wisdom: 15; dexterity: 15; constitution: 11; charisma: 6));
var
  p: Byte;
  part: ShortInt;
  least: Byte;
begin
  least := 0;
  for p := 1 to 3 do begin
    part := GameDefs.classParts[charClass].values[p];
    if part >= C_CLASS.CLERIC then
      if classMin[part].values[ability] > least then
        least := classMin[part].values[ability];
  end;
  if (race = C_RACE.HALF_ELF) and (ability = C_STAT.WISDOM)
     and (charClass in [C_CLASS.CLERIC_FIGHTER..C_CLASS.CLERIC_THIEF]) and (least < HALFELF_MULTI_CLERIC_WIS) then
    least := HALFELF_MULTI_CLERIC_WIS;
  ClassAbilityMin := least;
end;

function ConHpPerDie(cls: ShortInt; con: Byte): ShortInt;
const
  conBonusTbl: array[3..25] of ShortInt = (
    -2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2);
var
  share: ShortInt;
begin
  if con < 3 then
    con := 3
  else if con > 25 then
    con := 25;
  share := conBonusTbl[con];
  if (cls = C_LEVEL.FIGHTER) or (cls = C_LEVEL.PALADIN) or (cls = C_LEVEL.RANGER) then
    case con of
      17: Inc(share);
      18: Inc(share, 2);
      19, 20: Inc(share, 3);
      21..23: Inc(share, 4);
      24, 25: Inc(share, 5);
    end;
  ConHpPerDie := share;
end;

{ True when class cls rolls hit dice for creature's level in it now: it has a level, its classBits shares a bit with
  mask ($FF = all), and it is not a class a dual-classed human has left. }
function RollsHitDice(creature: Types.PCharRecord; cls: ShortInt; mask: Byte): Boolean;
begin
  RollsHitDice := (creature^.classLevels[cls] > 0) and (GameDefs.classBits[cls] and mask > 0) and
                  (creature^.portExt.formerClasses and (1 shl cls) = 0);
end;

{ The hit dice class cls rolls for creature's level in it now: hpDice's at level 1 (two for the ranger and monk), one at
  each level after. }
function DiceAtLevel(creature: Types.PCharRecord; cls: ShortInt): Byte;
begin
  if creature^.classLevels[cls] > 1 then
    DiceAtLevel := 1
  else
    DiceAtLevel := hpDice[cls];
end;

function ConHpBonus(creature: Types.PCharRecord; mask: Byte): ShortInt;
var
  bonus: ShortInt;
  cls: ShortInt;
begin
  bonus := 0;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if ClassCal.RollsHitDice(creature, cls, mask) then
      Inc(bonus, ClassCal.ConHpPerDie(cls, creature^.stats[C_STAT.CONSTITUTION]) * ClassCal.DiceAtLevel(creature, cls));
  ConHpBonus := bonus;
end;

function DivideAmongClasses(sum, conB: Integer; clsCount: Byte): Byte;
var
  hp: Integer;
begin
  if clsCount = 0 then
    clsCount := 1;
  if (conB < 0) and (sum <= Abs(conB) + clsCount) then
    hp := 1
  else
    hp := (sum + conB) div clsCount;
  if hp > 255 then
    hp := 255;
  DivideAmongClasses := hp;
end;

function HitDice(creature: Types.PCharRecord; cls: ShortInt): Byte;
var
  lvl: ShortInt;
  before: ShortInt;
  other: ShortInt;
begin
  HitDice := 0;
  lvl := creature^.classLevels[cls];
  if lvl <= 0 then
    Exit;
  { the level of the class left, for the class followed now }
  before := 0;
  if creature^.portExt.formerClasses and (1 shl cls) = 0 then
    for other := C_LEVEL.CLERIC to C_LEVEL.MONK do
      if (creature^.portExt.formerClasses and (1 shl other) <> 0) and (creature^.classLevels[other] > before) then
        before := creature^.classLevels[other];
  if before = 0 then
    HitDice := lvl + hpDice[cls] - 1
  else if lvl > before then
    HitDice := lvl - before;
end;

function HpClassCount(creature: Types.PCharRecord): Byte;
var
  n: Byte;
  cls: ShortInt;
begin
  n := 0;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if creature^.classLevels[cls] > 0 then
      Inc(n);
  if (n > 1) and (creature^.portExt.formerClasses <> 0) then
    n := 1;
  HpClassCount := n;
end;

{ ConHpPerDie for Constitution con on every hit die creature's classes have given it (HitDice), before the division
  by the class count: what creation and training have banked, which HpMinimum, HpMaximum and ConHpTotal add. }
function DiceConBonus(creature: Types.PCharRecord; con: Byte): Integer;
var
  bonus: Integer;
  cls: ShortInt;
begin
  bonus := 0;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    Inc(bonus, ClassCal.HitDice(creature, cls) * ClassCal.ConHpPerDie(cls, con));
  DiceConBonus := bonus;
end;

{ The lowest legal hpMax: one point per hit die (HitDice: a level in each class, plus 1 for a ranger or monk), plus the
  Con bonus on each of them (DiceConBonus), divided by the class count (HpClassCount); 1 if a negative bonus would leave
  too little. }
function HpMinimum(creature: Types.PCharRecord): Byte;
var
  sum: Integer;
  cls: ShortInt;
begin
  sum := 0;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    Inc(sum, ClassCal.HitDice(creature, cls));
  HpMinimum := ClassCal.DivideAmongClasses(sum, ClassCal.DiceConBonus(creature, creature^.stats[C_STAT.CONSTITUTION]),
                                           ClassCal.HpClassCount(creature));
end;

{ The highest legal hpMax: the top of each class's hit dice (HitDice and hpSides: cleric and druid d8 per level,
  fighter and paladin d10, ranger d8 on level + 1, magic-user d4, thief d6, monk d4 on level + 1) plus the Con bonus on
  each of them (DiceConBonus), divided by the class count (HpClassCount). }
function HpMaximum(creature: Types.PCharRecord): Byte;
var
  sum: Integer;
  cls: ShortInt;
begin
  sum := 0;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    Inc(sum, ClassCal.HitDice(creature, cls) * GameDefs.hpSides[cls]);
  HpMaximum := ClassCal.DivideAmongClasses(sum, ClassCal.DiceConBonus(creature, creature^.stats[C_STAT.CONSTITUTION]),
                                           ClassCal.HpClassCount(creature));
end;

function HitDieFloor(con: Byte): Byte;
begin
  case con of
    19, 20: HitDieFloor := 2;
    21, 22: HitDieFloor := 3;
    23..255: HitDieFloor := 4;
  else
    HitDieFloor := 1;
  end;
end;

{ Roll the hit dice of each class with levels whose classBits shares a bit with mask ($FF = all), but for a class a
  dual-classed human has left (#838): hpDice d hpSides at
  level 1, and one die at each level after, so the two-dice ranger and monk gain one die a level as the others do. Each
  die rolls at least HitDieFloor for the creature's Constitution, and a class at level 1 gets at least
  hpSides * 2 div 3, two thirds of one die even for the ranger and monk. The dice are rolled one at a time, as
  Dice.RollDice rolls them, so below Constitution 19 the rolls are the same. }
function RollFirstLevelHp(creature: Types.PCharRecord; mask: Byte): Byte;
var
  roll: Byte;
  die: Byte;
  floor: Byte;
  sum: Byte;
  cls: ShortInt;
  i: Byte;
begin
  sum := 0;
  floor := ClassCal.HitDieFloor(creature^.stats[C_STAT.CONSTITUTION]);
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if ClassCal.RollsHitDice(creature, cls, mask) then begin
      roll := 0;
      for i := 1 to ClassCal.DiceAtLevel(creature, cls) do begin
        die := Dice.RollDice(1, GameDefs.hpSides[cls]);
        if die < floor then
          die := floor;
        Inc(roll, die);
      end;
      if creature^.classLevels[cls] = 1 then
        if roll < GameDefs.hpSides[cls] * 2 div 3 then
          roll := GameDefs.hpSides[cls] * 2 div 3;
      Inc(sum, roll);
    end;
  RollFirstLevelHp := sum;
end;

function ConHpTotal(creature: Types.PCharRecord; con: Byte): Integer;
var
  total: Integer;
  clsCount: Byte;
begin
  total := ClassCal.DiceConBonus(creature, con);
  clsCount := ClassCal.HpClassCount(creature);
  if clsCount > 0 then
    total := total div clsCount;
  ConHpTotal := total;
end;

function ExperienceShare(creature: Types.PCharRecord; experience: LongInt): LongInt;
var
  share: LongInt;
begin
  share := experience;
  case creature^.charClass of
    { a single class is its C_LEVEL slot; the druid and monk earn no bonus }
    C_CLASS.CLERIC, C_CLASS.FIGHTER, C_CLASS.PALADIN, C_CLASS.RANGER, C_CLASS.MAGE, C_CLASS.THIEF:
      if ClassCal.PrimesAtLeast(creature, creature^.charClass, PRIME_STAT_THRESHOLD + 1) then
        share := experience div 10 + experience;
    { 2-class multi }
    C_CLASS.CLERIC_FIGHTER, C_CLASS.CLERIC_RANGER, C_CLASS.CLERIC_MAGE, C_CLASS.CLERIC_THIEF, C_CLASS.FIGHTER_MAGE,
      C_CLASS.FIGHTER_THIEF, C_CLASS.MAGE_THIEF: share := experience div 2;
    { 3-class multi }
    C_CLASS.CLERIC_FIGHTER_MAGE, C_CLASS.FIGHTER_MAGE_THIEF:
      share := experience div 3;
  end;
  ExperienceShare := share;
end;

function SpellFailureChance(creature: Types.PCharRecord; spell: Byte): Byte;
begin
  SpellFailureChance := 0;
  if CharHlp.IsSpell(spell) then
    if (GameDefs.spellTable[spell].castClassSp = C_SPELL.CLASS_CLERIC) and
        (CharHlp.GetClassLevel(creature, C_LEVEL.CLERIC_BIT) > 0) then
      SpellFailureChance := AbilAdj.WisSpellFailure(creature^.wisCur);
end;

function LevelXp(cls: ShortInt; lvl: Integer): LongInt;
begin
  if lvl < 2 then
    LevelXp := 0
  else if lvl > C_LEVEL.LEVEL_LAST then
    LevelXp := -1
  else
    LevelXp := GameDefs.classExperience[cls].xp[lvl];
end;

function MaxLevel(cls: ShortInt): ShortInt;
begin
  if GameVars.levelCapOn <> 0 then
    MaxLevel := ssiLevelCaps[cls]
  else
    MaxLevel := C_LEVEL.LEVEL_LAST;
end;

function LevelOpen(cls: ShortInt; lvl: Integer): Boolean;
begin
  LevelOpen := (lvl >= 2) and (lvl <= ClassCal.MaxLevel(cls)) and (ClassCal.LevelXp(cls, lvl) > 0);
end;

function MinLevel(lvl: ShortInt): ShortInt;
begin
  if lvl > C_LEVEL.LEVEL_LAST then
    MinLevel := C_LEVEL.LEVEL_LAST
  else
    MinLevel := lvl;
end;

end.
