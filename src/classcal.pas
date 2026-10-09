{ Recalculate class skills, saving throws and thief abilities, including wisdom bonuses. }
{$O+,F+}
unit ClassCal;

interface

uses Types, GDConsts, GDVars, C_Class, C_Race;

procedure RecalcBaseSkills(creature: Types.PCharRecord);

procedure AwardWisdomBonus(creature: Types.PCharRecord);

procedure RecalcSaves(creature: Types.PCharRecord);

procedure RecalcThiefSkills(creature: Types.PCharRecord);

implementation

{ Recompute base THAC0 (the highest 60 - THAC0 value across all eight class slots), raise levelHighest, set fighter
  attacks (stored doubled: 3 above level 6, else 2; set for every character), and for cleric or magic-user levels above
  1 set the spell slots (clerics also get the Wisdom bonus and every cleric spell of a level with slots marked known).
  The slot table fills only levels 2..6, the player cap, so a higher-level caster (Genheeris, a level 7 magic-user who
  joins the party) takes the level 6 row. thac0Tbl covers levels 0..10, and a level outside that uses the nearer end.
  Then call RecalcSaves and, if the character has thief levels, RecalcThiefSkills. }
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
  { 7 = High(classLevels) }
  for i := 0 to 7 do begin
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
      C_Class.LEVEL_FIGHTER:
        if lvl > 6 then creature^.attacks := 3 else creature^.attacks := 2;
      C_Class.LEVEL_CLERIC:
        if lvl > 1 then begin
          { 3 = High(clericSpells) }
          for k := 1 to 3 do
            creature^.clericSpells[k] := GDConsts.dsExperienceSpellsClass[C_Class.CLERIC].slots[slotLvl, k];
          ClassCal.AwardWisdomBonus(creature);
          { Mark known every cleric spell (castClass 0) of a level with slots; slots exist for levels 1..3 only.
            56 = High(spellsKnown) }
          for m := 1 to 56 do
            with GDConsts.spellTable[m] do
              if (castClass = 0) and (levelSp >= 1) and (levelSp <= 3) and (creature^.clericSpells[levelSp] > 0) then
                creature^.spellsKnown[m] := 1;
        end;
      C_Class.LEVEL_MAGE:
        if lvl > 1 then
          { 3 = High(mageSpells) }
          for k := 1 to 3 do
            creature^.mageSpells[k] := GDConsts.dsExperienceSpellsClass[C_Class.MAGE].slots[slotLvl, k];
    end;
  end;
  ClassCal.RecalcSaves(creature);
  if creature^.classLevels[C_Class.LEVEL_THIEF] > 0 then
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
    { 7 = High(classLevels) }
    for k := 0 to 7 do
      if creature^.classLevels[k] > 0 then begin
        lvl := creature^.classLevels[k];
        if lvl > 9 then
          lvl := 9;
        if creature^.saves[i] > GDConsts.saveTbl[k, lvl, i] then
          creature^.saves[i] := GDConsts.saveTbl[k, lvl, i];
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
  tl := creature^.classLevels[C_Class.LEVEL_THIEF];
  if tl < 1 then
    Exit;
  if tl > 9 then
    tl := 9;
  with creature^ do
    { 8 = High(thiefSkills) }
    for j := 1 to 8 do
      if (GDConsts.raceAdj[r, j] < 0) and (Abs(GDConsts.raceAdj[r, j]) > GDConsts.thiefBase[tl, j]) then
        thiefSkills[j] := 0
      else begin
        total := GDConsts.thiefBase[tl, j] + GDConsts.raceAdj[r, j];
        { dexAdj covers skills 1..5 only }
        if j < 6 then
          total := total + GDConsts.dexAdj[dex, j];
        if total < 0 then
          total := 0;
        thiefSkills[j] := total;
      end;
end;

end.
