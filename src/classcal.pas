{ Recalculate class skills, saving throws and thief abilities, including wisdom bonuses. }
{$O+,F+}
{$I COMPILER.INC}
unit ClassCal;

interface

uses Types;

procedure RecalcBaseSkills(creature: Types.PCharRecord);

procedure AwardWisdomBonus(creature: Types.PCharRecord);

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

{ The racial limits on ability (C_Abil) for race 1..7 (C_Race.DWARF..HUMAN) and gender (C_Gender, which only Strength
  depends on), from GDConsts.dsMinimumMaximumStatistics. }
function RaceAbilityMin(race, gender, ability: ShortInt): Byte;
function RaceAbilityMax(race, gender, ability: ShortInt): Byte;

{ The class minimum on ability (C_Abil) for charClass (C_Class): a single class's from GDConsts.classMin, a
  multiclass's the highest of its classes' (GDConsts.classParts), as the 1st-edition PHB has it. }
function ClassAbilityMin(charClass, ability: ShortInt): Byte;

{ The Constitution hit-point adjustment class cls (C_Level) gets per hit die: GDConsts.conBonusTbl's, plus, for the
  fighter, paladin and ranger classes, 1 at Con 17, 2 at 18, 3 at 19..20, 4 at 21..23 and 5 at 24..25. The warrior
  bonus goes with the class, so a multi-class character's fighter, paladin or ranger levels get it too: the 1st-edition
  PHB works the bonus out per class, then divides by the class count (#616). A Constitution outside the table's 3..25
  uses the nearer end, so Con 0..2 (Raise Dead takes a point each time) keep Con 3's penalty. }
function ConHpPerDie(cls: ShortInt; con: Byte): ShortInt;

function ConHpBonus(creature: Types.PCharRecord; mask: Byte): ShortInt;

function DivideAmongClasses(sum: Byte; conB: ShortInt; clsCount: Byte): Byte;

function HpMinimum(creature: Types.PCharRecord): Byte;

function HpMaximum(creature: Types.PCharRecord): Byte;

function RollFirstLevelHp(creature: Types.PCharRecord; mask: Byte): Byte;

{ The least a hit die rolls for Constitution con, in any class (Deities & Demigods): 1 to Con 18, 2 at 19..20 (no 1s),
  3 at 21..22 (no 1s or 2s) and 4 at 23 and up (no 1s, 2s or 3s). }
function HitDieFloor(con: Byte): Byte;

{ The hit points Constitution con gives creature over all its hit dice, as creation and training bank them (CharGen's
  ConHpBonus at each level): each class's ConHpPerDie once per level (a ranger's level + 1), divided by the class
  count. The difference between two Constitutions is the hit-point change a change of Constitution makes. }
function ConHpTotal(creature: Types.PCharRecord; con: Byte): Integer;

const
  { a prime attribute above this earns a single-class character 10% more experience }
  PRIME_STAT_THRESHOLD = 15;

{ The creature's share of experience: a single-class cleric, fighter, magic-user or thief whose prime attribute
  (Wisdom, Strength, Intelligence, Dexterity) is above PRIME_STAT_THRESHOLD gets 10% more (experience div 10 added), as
  does a paladin with Strength and Wisdom or a ranger with Strength, Intelligence and Wisdom above it; other single
  classes get experience unchanged; two-class characters get experience div 2, three-class (cleric/fighter/magic-user,
  fighter/magic-user/thief) experience div 3. }
function ExperienceShare(creature: Types.PCharRecord; experience: LongInt): LongInt;

implementation


uses GDConsts, GDVars, C_Class, C_Level, C_Race, C_Abil, C_Equip, C_Item, Dice;
{ Recompute base THAC0 (the highest 60 - THAC0 value across all eight class slots), raise levelHighest, set warrior
  attacks (stored doubled: 3 for a fighter or paladin above level 6 or a ranger above level 7, else 2; set for every
  character), and for cleric or magic-user levels above 1 set the spell slots (clerics also get the Wisdom bonus and
  every cleric spell of a level with slots marked known). The slot table fills only levels 2..6, the player cap, so a
  higher-level caster (Genheeris, a level 7 magic-user who joins the party) takes the level 6 row. thac0Tbl covers
  levels 0..10, and a level outside that uses the nearer end. Then call RecalcSaves and, if the character has thief
  levels, RecalcThiefSkills. }
procedure RecalcBaseSkills(creature: Types.PCharRecord);
var
  i: ShortInt;
  k: ShortInt;
  lvl: ShortInt;
  slotLvl: ShortInt;
  tl: ShortInt;
  m: Byte;
begin
  creature^.thac0Base := 0;
  for i := C_Level.CLERIC to C_Level.MONK do begin
    lvl := creature^.classLevels[i];
    slotLvl := lvl;
    if slotLvl > 6 then
      slotLvl := 6;
    tl := lvl;
    if tl < 0 then
      tl := 0
    else if tl > 10 then
      tl := 10;
    if GDConsts.thac0Tbl[i, tl] > creature^.thac0Base then
      creature^.thac0Base := GDConsts.thac0Tbl[i, tl];
    if creature^.levelHighest < lvl then
      creature^.levelHighest := lvl;
    case i of
      C_Level.FIGHTER:
        if lvl > 6 then creature^.attacks := 3 else creature^.attacks := 2;
      { after the fighter's slot, so these only raise it }
      C_Level.PALADIN:
        if lvl > 6 then creature^.attacks := 3;
      C_Level.RANGER:
        if lvl > 7 then creature^.attacks := 3;
      C_Level.CLERIC:
        if lvl > 1 then begin
          { 3 = High(clericSpells) }
          for k := 1 to 3 do
            creature^.clericSpells[k] := GDConsts.dsExperienceSpellsClass[C_Level.CLERIC].slots[slotLvl, k];
          ClassCal.AwardWisdomBonus(creature);
          { Mark known every cleric spell (castClass 0) of a level with slots; slots exist for levels 1..3 only.
            56 = High(spellsKnown) }
          for m := 1 to 56 do
            with GDConsts.spellTable[m] do
              if (castClass = 0) and (levelSp >= 1) and (levelSp <= 3) and (creature^.clericSpells[levelSp] > 0) then
                creature^.spellsKnown[m] := 1;
        end;
      C_Level.MAGE:
        if lvl > 1 then
          { 3 = High(mageSpells) }
          for k := 1 to 3 do
            creature^.mageSpells[k] := GDConsts.dsExperienceSpellsClass[C_Level.MAGE].slots[slotLvl, k];
    end;
  end;
  ClassCal.RecalcSaves(creature);
  if creature^.classLevels[C_Level.THIEF] > 0 then
    ClassCal.RecalcThiefSkills(creature);
end;

{ Add the Wisdom bonus cleric slots, cumulative over GDConsts.wisBonusSpells' rows from 13 to the creature's Wisdom
  (above 25 counts as 25): Wisdom 13 and 14 each add a first-level slot, 15 and 16 a second-level slot, 17 a third-level
  slot, 18 a fourth, and so on to 25. Only the spell levels a cleric casts here (1..Types.CASTER_LEVEL_LAST) take them,
  and each only where that level's slot count is already non-zero. }
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
        if clericSpells[lvl] > 0 then
          Inc(clericSpells[lvl], GDConsts.wisBonusSpells[w, lvl]);
  end;
end;

{ Start every saving throw at 20 and take the best (lowest) across all classes with a level above 0. saveTbl covers
  levels 1..9, and a higher level uses the level 9 row. }
procedure RecalcSaves(creature: Types.PCharRecord);
var
  i: ShortInt;
  k: ShortInt;
  lvl: ShortInt;
begin
  { 4 = High(saves) }
  for i := 0 to 4 do begin
    creature^.saves[i] := 20;
    for k := C_Level.CLERIC to C_Level.MONK do
      if creature^.classLevels[k] > 0 then begin
        lvl := creature^.classLevels[k];
        if lvl > 9 then
          lvl := 9;
        if creature^.saves[i] > GDConsts.saveTbl[k, lvl].values[i] then
          creature^.saves[i] := GDConsts.saveTbl[k, lvl].values[i];
      end;
  end;
end;

{ Set each thief skill (ThiefSkillParts, ThiefSkill) to its base for the thief level plus the racial adjustment (a
  racial penalty larger than the base zeroes the skill), plus the Dexterity adjustment for skills 1..5, stopping at 0
  (a Dexterity 9 human's Move Silently would be -5). Armor that bars them (ArmorBarsThiefSkills) zeroes every skill, so
  every reader of thiefSkills (Open Locks, the scripts' party checks) sees it. A creature without thief levels keeps
  its skills as they are. }
procedure RecalcThiefSkills(creature: Types.PCharRecord);
var
  j: Byte;
  base: ShortInt;
  racial: ShortInt;
  dexterity: ShortInt;
  barred: Boolean;
begin
  if creature^.classLevels[C_Level.THIEF] < 1 then
    Exit;
  barred := ClassCal.ArmorBarsThiefSkills(creature);
  { 8 = High(thiefSkills) }
  for j := 1 to 8 do begin
    ClassCal.ThiefSkillParts(creature, j, base, racial, dexterity);
    if barred then
      creature^.thiefSkills[j] := 0
    else
      creature^.thiefSkills[j] := ClassCal.ThiefSkill(base, racial, dexterity);
  end;
end;

function ArmorBarsThiefSkills(creature: Types.PCharRecord): Boolean;
begin
  ArmorBarsThiefSkills := (creature^.equipped[C_Equip.SHIELD] <> nil) or
                          ((creature^.equipped[C_Equip.ARMOR] <> nil) and
                           (creature^.equipped[C_Equip.ARMOR]^.itemType <> C_Item.LEATHER_ARMOR));
end;

{ dexAdj covers Dexterity 9..25, a thief's minimum to Deities & Demigods' highest; a Dexterity outside that range uses
  the nearer end. thiefBase covers thief levels 1..9, and a higher level uses the level 9 row; a race outside the player
  races (raceAdj covers 1..7) takes the human row, which adjusts nothing. }
procedure ThiefSkillParts(creature: Types.PCharRecord; j: Byte; var base, racial, dexterity: ShortInt);
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
  if (r < C_Race.DWARF) or (r > C_Race.HUMAN) then
    r := C_Race.HUMAN;
  tl := creature^.classLevels[C_Level.THIEF];
  if tl < 1 then
    tl := 1
  else if tl > 9 then
    tl := 9;
  base := GDConsts.thiefBase[tl].values[j];
  racial := GDConsts.raceAdj[r].values[j];
  dexterity := 0;
  { dexAdj covers skills 1..5 only }
  if j < 6 then
    dexterity := GDConsts.dexAdj[dex].values[j];
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

function RaceAbilityMin(race, gender, ability: ShortInt): Byte;
begin
  with GDConsts.dsMinimumMaximumStatistics[race] do
    case ability of
      C_Abil.STRENGTH: RaceAbilityMin := strMin[gender];
      C_Abil.INTELLIGENCE: RaceAbilityMin := intMin;
      C_Abil.WISDOM: RaceAbilityMin := wisMin;
      C_Abil.DEXTERITY: RaceAbilityMin := dexMin;
      C_Abil.CONSTITUTION: RaceAbilityMin := conMin;
    else
      RaceAbilityMin := chaMin;
    end;
end;

function RaceAbilityMax(race, gender, ability: ShortInt): Byte;
begin
  with GDConsts.dsMinimumMaximumStatistics[race] do
    case ability of
      C_Abil.STRENGTH: RaceAbilityMax := strMax[gender];
      C_Abil.INTELLIGENCE: RaceAbilityMax := intMax;
      C_Abil.WISDOM: RaceAbilityMax := wisMax;
      C_Abil.DEXTERITY: RaceAbilityMax := dexMax;
      C_Abil.CONSTITUTION: RaceAbilityMax := conMax;
    else
      RaceAbilityMax := chaMax;
    end;
end;

function ClassAbilityMin(charClass, ability: ShortInt): Byte;
var
  p: Byte;
  part: ShortInt;
  least: Byte;
begin
  least := 0;
  for p := 1 to 3 do begin
    part := GDConsts.classParts[charClass].values[p];
    if part >= C_Class.CLERIC then
      if GDConsts.classMin[part].values[ability] > least then
        least := GDConsts.classMin[part].values[ability];
  end;
  ClassAbilityMin := least;
end;

function ConHpPerDie(cls: ShortInt; con: Byte): ShortInt;
var
  share: ShortInt;
begin
  if con < 3 then
    con := 3
  else if con > 25 then
    con := 25;
  share := GDConsts.conBonusTbl[con];
  if (cls = C_Level.FIGHTER) or (cls = C_Level.PALADIN) or (cls = C_Level.RANGER) then
    case con of
      17: Inc(share);
      18: Inc(share, 2);
      19, 20: Inc(share, 3);
      21..23: Inc(share, 4);
      24, 25: Inc(share, 5);
    end;
  ConHpPerDie := share;
end;

{ ConHpBonus: Sum ConHpPerDie once per class with levels whose classBit shares a bit with mask ($FF = all). A
  first-level ranger counts its share twice, once for each of its two hit dice. }
function ConHpBonus(creature: Types.PCharRecord; mask: Byte): ShortInt;
var
  bonus: ShortInt;
  cls: ShortInt;
  share: ShortInt;
begin
  bonus := 0;
  with creature^ do begin
    for cls := C_Level.CLERIC to C_Level.MONK do
      if (classLevels[cls] > 0) and (GDConsts.classBit[cls] and mask > 0) then begin
        share := ClassCal.ConHpPerDie(cls, stats[C_Abil.CONSTITUTION]);
        if (cls = C_Level.RANGER) and (classLevels[cls] = 1) then
          share := share * 2;
        Inc(bonus, share);
      end;
  end;
  ConHpBonus := bonus;
end;

{ (sum + conB) div clsCount, the hit points a multi-class character's classes share; 1 when a negative conB would
  leave sum no more than |conB| + clsCount. }
function DivideAmongClasses(sum: Byte; conB: ShortInt; clsCount: Byte): Byte;
begin
  if conB < 0 then begin
    if sum > Abs(conB) + clsCount then
      DivideAmongClasses := (sum + conB) div clsCount
    else
      DivideAmongClasses := 1;
  end else
    DivideAmongClasses := (sum + conB) div clsCount;
end;

{ HpMinimum: Lowest legal hpMax: one point per level in each class (plus 1 for a ranger or monk), plus the Con bonus,
  divided by the class count; 1 if a negative bonus would leave too little }
function HpMinimum(creature: Types.PCharRecord): Byte;
var
  clsCount: Byte;
  sum: Byte;
  cls: ShortInt;
begin
  with creature^ do begin
    clsCount := 0;
    sum := 0;
    for cls := C_Level.CLERIC to C_Level.MONK do
      if classLevels[cls] > 0 then begin
        Inc(sum, classLevels[cls]);
        Inc(clsCount);
        case cls of
          C_Level.RANGER: Inc(sum);
          C_Level.MONK: Inc(sum);
        end;
      end;
  end;
  HpMinimum := ClassCal.DivideAmongClasses(sum, ClassCal.ConHpBonus(creature, $FF), clsCount);
end;

{ HpMaximum: Highest legal hpMax: the top of each class's hit dice (GDConsts.hpDice and hpSides: cleric and druid d8
  per level, fighter and paladin d10, ranger d8 on level + 1, magic-user d4, thief d6, monk d4 on level + 1) plus the
  Con bonus, divided by the class count. }
function HpMaximum(creature: Types.PCharRecord): Byte;
var
  clsCount: Byte;
  sum: Byte;
  cls: ShortInt;
begin
  with creature^ do begin
    clsCount := 0;
    sum := 0;
    for cls := C_Level.CLERIC to C_Level.MONK do
      if classLevels[cls] > 0 then begin
        Inc(clsCount);
        { hpDice at level 1, one die a level after }
        Inc(sum, (classLevels[cls] + GDConsts.hpDice[cls] - 1) * GDConsts.hpSides[cls]);
      end;
  end;
  HpMaximum := ClassCal.DivideAmongClasses(sum, ClassCal.ConHpBonus(creature, $FF), clsCount);
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

{ RollFirstLevelHp: Roll the hit dice of each class with levels whose classBit shares a bit with mask ($FF = all):
  hpDice d hpSides at level 1, and one die at each level after, so the two-dice ranger and monk gain one die a level as
  the others do. Each die rolls at least HitDieFloor for the creature's Constitution, and a class at level 1 gets at
  least hpSides * 2 div 3, two thirds of one die even for the ranger and monk. The dice are rolled one at a time, as
  Dice.RollDice rolls them, so below Constitution 19 the rolls are the same. }
function RollFirstLevelHp(creature: Types.PCharRecord; mask: Byte): Byte;
var
  roll: Byte;
  die: Byte;
  floor: Byte;
  sum: Byte;
  cls: ShortInt;
  dieCount: Byte;
  i: Byte;
begin
  sum := 0;
  floor := ClassCal.HitDieFloor(creature^.stats[C_Abil.CONSTITUTION]);
  for cls := C_Level.CLERIC to C_Level.MONK do
    if (creature^.classLevels[cls] > 0) and (GDConsts.classBit[cls] and mask > 0) then begin
      dieCount := GDConsts.hpDice[cls];
      if creature^.classLevels[cls] > 1 then
        dieCount := 1;
      roll := 0;
      for i := 1 to dieCount do begin
        die := Dice.RollDice(1, GDConsts.hpSides[cls]);
        if die < floor then
          die := floor;
        Inc(roll, die);
      end;
      if creature^.classLevels[cls] = 1 then
        if roll < GDConsts.hpSides[cls] * 2 div 3 then
          roll := GDConsts.hpSides[cls] * 2 div 3;
      Inc(sum, roll);
    end;
  RollFirstLevelHp := sum;
end;

function ConHpTotal(creature: Types.PCharRecord; con: Byte): Integer;
var
  total: Integer;
  clsCount: Byte;
  cls: ShortInt;
  dice: Byte;
begin
  total := 0;
  clsCount := 0;
  with creature^ do begin
    for cls := C_Level.CLERIC to C_Level.MONK do
      if classLevels[cls] > 0 then begin
        Inc(clsCount);
        dice := classLevels[cls];
        { a ranger's first level has two hit dice }
        if cls = C_Level.RANGER then
          Inc(dice);
        Inc(total, dice * ClassCal.ConHpPerDie(cls, con));
      end;
  end;
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
    C_Class.CLERIC: if creature^.wisCur > PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
    C_Class.FIGHTER: if creature^.strCur > PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
    C_Class.PALADIN:
      if (creature^.strCur > PRIME_STAT_THRESHOLD) and (creature^.wisCur > PRIME_STAT_THRESHOLD) then
        share := experience div 10 + experience;
    C_Class.RANGER:
      if (creature^.strCur > PRIME_STAT_THRESHOLD) and (creature^.intCur > PRIME_STAT_THRESHOLD) and
          (creature^.wisCur > PRIME_STAT_THRESHOLD) then
        share := experience div 10 + experience;
    C_Class.MAGE: if creature^.intCur > PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
    C_Class.THIEF: if creature^.dexCur > PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
    C_Class.CLERIC_FIGHTER, C_Class.CLERIC_RANGER..C_Class.FIGHTER_THIEF,
      { 2-class multi }
      C_Class.MAGE_THIEF: share := experience div 2;
    C_Class.CLERIC_FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF:
      { 3-class multi }
      share := experience div 3;
  end;
  ExperienceShare := share;
end;

end.
