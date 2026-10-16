{ Recalculate class skills, saving throws and thief abilities, including wisdom bonuses. }
{$O+,F+}
unit ClassCal;

interface

uses Types;

procedure RecalcBaseSkills(creature: Types.PCharRecord);

procedure AwardWisdomBonus(creature: Types.PCharRecord);

procedure RecalcSaves(creature: Types.PCharRecord);

procedure RecalcThiefSkills(creature: Types.PCharRecord);

{ The racial limits on ability (C_Abil) for race 1..7 (C_Race.DWARF..HUMAN) and gender (C_Gender, which only Strength
  depends on), from GDConsts.dsMinimumMaximumStatistics. }
function RaceAbilityMin(race, gender, ability: ShortInt): Byte;
function RaceAbilityMax(race, gender, ability: ShortInt): Byte;

function ConHpBonus(creature: Types.PCharRecord; mask: Byte): ShortInt;

function DivideAmongClasses(sum: Byte; conB: ShortInt; clsCount: Byte): Byte;

function HpMinimum(creature: Types.PCharRecord): Byte;

function HpMaximum(creature: Types.PCharRecord): Byte;

function RollFirstLevelHp(creature: Types.PCharRecord; mask: Byte): Byte;

{ The hit points Constitution con gives creature over all its hit dice, as creation and training bank them (CharGen's
  ConHpBonus at each level): each class's GDConsts.conBonusTbl share, plus 1 at Con 17 and 1 more at 18 for a
  single-class fighter, paladin or ranger, once per level (a ranger's level + 1), divided by the class count. A
  Constitution outside the table's 3..20 uses the nearer end. The difference between two Constitutions is the
  hit-point change a change of Constitution makes. }
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


uses GDConsts, GDVars, C_Class, C_Level, C_Race, C_Abil, Dice;
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

{ Add the Wisdom bonus cleric slots, cumulative: Wisdom 13 and 14 each add a first-level slot, 15 and 16 each add a
  second-level slot, 17 adds a third-level slot; each is awarded only where that level's slot count is already
  non-zero. }
procedure AwardWisdomBonus(creature: Types.PCharRecord);
begin
  with creature^ do begin
    if (wisCur > 12) and (clericSpells[1] > 0) then Inc(clericSpells[1]);
    if (wisCur > 13) and (clericSpells[1] > 0) then Inc(clericSpells[1]);
    if (wisCur > 14) and (clericSpells[2] > 0) then Inc(clericSpells[2]);
    if (wisCur > 15) and (clericSpells[2] > 0) then Inc(clericSpells[2]);
    if (wisCur > 16) and (clericSpells[3] > 0) then Inc(clericSpells[3]);
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

{ Set each thief skill to its base for the thief level plus the racial adjustment (a racial penalty larger than the base
  zeroes the skill), plus the Dexterity adjustment for skills 1..5, stopping at 0 (a Dexterity 9 human's Move Silently
  would be -5). dexAdj covers Dexterity 9..19, a thief's minimum to the highest racial maximum; a Dexterity outside
  that range uses the nearer end. thiefBase covers thief levels 1..9, and a higher level uses the level 9 row; a race
  outside the player races (raceAdj covers 1..7) takes the human row, which adjusts nothing. }
procedure RecalcThiefSkills(creature: Types.PCharRecord);
var
  j: Byte;
  total: Integer;
  dex: Byte;
  r: ShortInt;
  tl: ShortInt;
begin
  dex := creature^.dexCur;
  if dex < 9 then
    dex := 9
  else if dex > 19 then
    dex := 19;
  r := creature^.race;
  if (r < C_Race.DWARF) or (r > C_Race.HUMAN) then
    r := C_Race.HUMAN;
  tl := creature^.classLevels[C_Level.THIEF];
  if tl < 1 then
    Exit;
  if tl > 9 then
    tl := 9;
  with creature^ do
    { 8 = High(thiefSkills) }
    for j := 1 to 8 do
      if (GDConsts.raceAdj[r].values[j] < 0) and
         (Abs(GDConsts.raceAdj[r].values[j]) > GDConsts.thiefBase[tl].values[j]) then
        thiefSkills[j] := 0
      else begin
        total := GDConsts.thiefBase[tl].values[j] + GDConsts.raceAdj[r].values[j];
        { dexAdj covers skills 1..5 only }
        if j < 6 then
          total := total + GDConsts.dexAdj[dex].values[j];
        if total < 0 then
          total := 0;
        thiefSkills[j] := total;
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

{ ConHpBonus: Sum GDConsts.conBonusTbl[Con] once per class with levels whose classBit shares a bit with mask
  ($FF = all), plus 1 at Con 17+ and 1 more at Con 18+ when charClass is a single-class fighter, paladin or ranger. A
  first-level ranger counts its share twice, once for each of its two hit dice. The table covers Con 3..20; a
  Constitution outside it (Raise Dead takes a point each time, down to 0) uses the nearer end, so Con 0..2 keep Con 3's
  penalty. }
function ConHpBonus(creature: Types.PCharRecord; mask: Byte): ShortInt;
var
  bonus: ShortInt;
  cls: ShortInt;
  con: Byte;
  share: ShortInt;
  warrior: Boolean;
begin
  bonus := 0;
  con := creature^.stats[C_Abil.CONSTITUTION];
  if con < 3 then
    con := 3
  else if con > 20 then
    con := 20;
  with creature^ do begin
    warrior := (charClass = C_Class.FIGHTER) or (charClass = C_Class.PALADIN) or (charClass = C_Class.RANGER);
    for cls := C_Level.CLERIC to C_Level.MONK do
      if (classLevels[cls] > 0) and (GDConsts.classBit[cls] and mask > 0) then begin
        share := GDConsts.conBonusTbl[con];
        if (stats[C_Abil.CONSTITUTION] > 16) and warrior then
          Inc(share);
        if (stats[C_Abil.CONSTITUTION] > 17) and warrior then
          Inc(share);
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

{ HpMaximum: Highest legal hpMax: the top of each class's hit dice -- cleric and druid d8 per level, fighter and paladin
  d10, ranger d8 on level + 1, magic-user d4, thief d6, monk d4 on level + 1 -- plus the Con bonus, divided by the class
  count. }
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
        case cls of
          C_Level.CLERIC: Inc(sum, classLevels[cls] * 8);
          C_Level.DRUID: Inc(sum, classLevels[cls] * 8);
          C_Level.FIGHTER: Inc(sum, classLevels[cls] * 10);
          C_Level.PALADIN: Inc(sum, classLevels[cls] * 10);
          C_Level.RANGER: Inc(sum, (classLevels[cls] + 1) * 8);
          C_Level.MAGE: Inc(sum, classLevels[cls] * 4);
          C_Level.THIEF: Inc(sum, classLevels[cls] * 6);
          C_Level.MONK: Inc(sum, (classLevels[cls] + 1) * 4);
        end;
      end;
  end;
  HpMaximum := ClassCal.DivideAmongClasses(sum, ClassCal.ConHpBonus(creature, $FF), clsCount);
end;

{ RollFirstLevelHp: Roll the hit dice of each class with levels whose classBit shares a bit with mask ($FF = all):
  hpDice d hpSides at level 1, and one die at each level after, so the two-dice ranger and monk gain one die a level as
  the others do. A class at level 1 gets at least hpSides * 2 div 3, two thirds of one die even for the ranger and
  monk. }
function RollFirstLevelHp(creature: Types.PCharRecord; mask: Byte): Byte;

var
  roll: Byte;
  sum: Byte;
  cls: ShortInt;
  dieCount: Byte;
begin
  sum := 0;
  for cls := C_Level.CLERIC to C_Level.MONK do
    if (creature^.classLevels[cls] > 0) and (GDConsts.classBit[cls] and mask > 0) then begin
      dieCount := GDConsts.hpDice[cls];
      if creature^.classLevels[cls] > 1 then
        dieCount := 1;
      roll := Dice.RollDice(dieCount, GDConsts.hpSides[cls]);
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
  share: ShortInt;
  warrior: Boolean;
begin
  total := 0;
  clsCount := 0;
  with creature^ do begin
    warrior := (charClass = C_Class.FIGHTER) or (charClass = C_Class.PALADIN) or (charClass = C_Class.RANGER);
    for cls := C_Level.CLERIC to C_Level.MONK do
      if classLevels[cls] > 0 then begin
        Inc(clsCount);
        if con < 3 then
          share := GDConsts.conBonusTbl[3]
        else if con > 20 then
          share := GDConsts.conBonusTbl[20]
        else
          share := GDConsts.conBonusTbl[con];
        if (con > 16) and warrior then
          Inc(share);
        if (con > 17) and warrior then
          Inc(share);
        dice := classLevels[cls];
        { a ranger's first level has two hit dice }
        if cls = C_Level.RANGER then
          Inc(dice);
        Inc(total, dice * share);
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
