{ Tests for ClassCal: THAC0, attacks, spell slots and the Wisdom bonus, saving throws and thief skills. }
program TClasCal;

uses Types, C_Level, C_Race, C_Save, C_Class, GDConsts, ClassCal, TestKit;

var
  c: Types.PCharRecord;
  n: Integer;
  roll: Byte;
  inRange: Boolean;

{ A fresh character of race with no class levels. }
procedure Reset(race: ShortInt);
begin
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.race := race;
end;

procedure CheckSaves(paralyze, petrify, wand, breath, spell: Byte; what: String);
begin
  TestKit.CheckEqualsL(paralyze, c^.saves[C_Save.PARALYZE], what + ': paralyze');
  TestKit.CheckEqualsL(petrify, c^.saves[C_Save.PETRIFY], what + ': petrify');
  TestKit.CheckEqualsL(wand, c^.saves[C_Save.WAND], what + ': wand');
  TestKit.CheckEqualsL(breath, c^.saves[C_Save.BREATH], what + ': breath');
  TestKit.CheckEqualsL(spell, c^.saves[C_Save.SPELL], what + ': spell');
end;

procedure CheckSkills(pp, ol, ft, ms, hs, hn, cw, rl: Byte; what: String);
begin
  TestKit.CheckEqualsL(pp, c^.thiefSkills[1], what + ': pick pockets');
  TestKit.CheckEqualsL(ol, c^.thiefSkills[2], what + ': open locks');
  TestKit.CheckEqualsL(ft, c^.thiefSkills[3], what + ': find traps');
  TestKit.CheckEqualsL(ms, c^.thiefSkills[4], what + ': move silently');
  TestKit.CheckEqualsL(hs, c^.thiefSkills[5], what + ': hide in shadows');
  TestKit.CheckEqualsL(hn, c^.thiefSkills[6], what + ': hear noise');
  TestKit.CheckEqualsL(cw, c^.thiefSkills[7], what + ': climb walls');
  TestKit.CheckEqualsL(rl, c^.thiefSkills[8], what + ': read languages');
end;

begin
  TestKit.Start('TCLASCAL');
  GetMem(c, SizeOf(Types.TCharRecord));

  { THAC0 (stored as 60 - THAC0), attacks (stored doubled) and the highest level }
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.FIGHTER] := 1;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(40, c^.thac0Base, 'a level 1 fighter has THAC0 20');
  TestKit.CheckEqualsL(2, c^.attacks, 'a level 1 fighter attacks once');
  TestKit.CheckEqualsL(1, c^.levelHighest, 'levelHighest rises to the fighter level');
  c^.classLevels[C_Level.FIGHTER] := 7;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(46, c^.thac0Base, 'a level 7 fighter has THAC0 14');
  TestKit.CheckEqualsL(3, c^.attacks, 'a level 7 fighter attacks 3/2');
  c^.classLevels[C_Level.FIGHTER] := 12;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(49, c^.thac0Base, 'a level above 10 takes the level 10 THAC0');
  Reset(C_Race.HUMAN);
  c^.levelHighest := 5;
  c^.classLevels[C_Level.FIGHTER] := 1;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(5, c^.levelHighest, 'levelHighest is only raised');
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.PALADIN] := 7;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(3, c^.attacks, 'a level 7 paladin attacks 3/2');
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.RANGER] := 7;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(2, c^.attacks, 'a level 7 ranger attacks once');
  c^.classLevels[C_Level.RANGER] := 8;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(3, c^.attacks, 'a level 8 ranger attacks 3/2');
  Reset(C_Race.ELF);
  c^.classLevels[C_Level.FIGHTER] := 2;
  c^.classLevels[C_Level.MAGE] := 3;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(41, c^.thac0Base, 'a multi-class character takes the best THAC0');
  TestKit.CheckEqualsL(3, c^.levelHighest, 'and its highest level');

  { spell slots and the Wisdom bonus }
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.CLERIC] := 1;
  c^.wisCur := 18;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(0, c^.clericSpells[1], 'a level 1 cleric''s slots are left as they are');
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.CLERIC] := 2;
  c^.wisCur := 14;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(4, c^.clericSpells[1], 'a level 2 cleric with Wisdom 14: 2 first-level slots and 2 bonus');
  TestKit.CheckEqualsL(0, c^.clericSpells[2], 'no bonus at a level without slots');
  TestKit.CheckEqualsL(1, c^.spellsKnown[1], 'Bless is known');
  TestKit.CheckEqualsL(0, c^.spellsKnown[22], 'Find Traps is not');
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.CLERIC] := 4;
  c^.wisCur := 17;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(5, c^.clericSpells[1], 'a level 4 cleric with Wisdom 17: 3 + 2 first-level slots');
  TestKit.CheckEqualsL(4, c^.clericSpells[2], '2 + 2 second-level slots');
  TestKit.CheckEqualsL(0, c^.clericSpells[3], 'no third-level slot to add to');
  TestKit.CheckEqualsL(1, c^.spellsKnown[22], 'Find Traps is known');
  TestKit.CheckEqualsL(0, c^.spellsKnown[36], 'Animate Dead is not');
  TestKit.CheckEqualsL(0, c^.spellsKnown[9], 'nor a magic-user spell');
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.CLERIC] := 6;
  c^.wisCur := 12;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(2, c^.clericSpells[3], 'a level 6 cleric with Wisdom 12: 2 third-level slots, no bonus');
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.MAGE] := 7;
  ClassCal.RecalcBaseSkills(c);
  TestKit.CheckEqualsL(4, c^.mageSpells[1], 'a level 7 magic-user takes the level 6 row: 4 first-level slots');
  TestKit.CheckEqualsL(2, c^.mageSpells[2], '2 second-level');
  TestKit.CheckEqualsL(2, c^.mageSpells[3], '2 third-level');

  { saving throws }
  Reset(C_Race.HUMAN);
  ClassCal.RecalcSaves(c);
  CheckSaves(20, 20, 20, 20, 20, 'no class levels');
  c^.classLevels[C_Level.FIGHTER] := 1;
  ClassCal.RecalcSaves(c);
  CheckSaves(14, 15, 16, 17, 17, 'a level 1 fighter');
  c^.classLevels[C_Level.FIGHTER] := 12;
  ClassCal.RecalcSaves(c);
  CheckSaves(8, 9, 10, 9, 11, 'a level above 9 takes the level 9 row');
  c^.classLevels[C_Level.FIGHTER] := 1;
  c^.classLevels[C_Level.CLERIC] := 1;
  ClassCal.RecalcSaves(c);
  CheckSaves(10, 13, 14, 16, 15, 'a cleric/fighter takes the better of each');

  { thief skills }
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.THIEF] := 1;
  c^.dexCur := 15;
  ClassCal.RecalcBaseSkills(c);
  CheckSkills(30, 25, 20, 15, 10, 10, 85, 0, 'a level 1 human thief, Dexterity 15');
  Reset(C_Race.HALFLING);
  c^.classLevels[C_Level.THIEF] := 1;
  c^.dexCur := 19;
  ClassCal.RecalcThiefSkills(c);
  CheckSkills(50, 50, 35, 37, 37, 15, 70, 0, 'a halfling, Dexterity 19 (read languages penalty above the base)');
  Reset(C_Race.DWARF);
  c^.classLevels[C_Level.THIEF] := 1;
  c^.dexCur := 9;
  ClassCal.RecalcThiefSkills(c);
  CheckSkills(15, 25, 25, 0, 0, 10, 75, 0, 'a dwarf, Dexterity 9 (move silently stops at 0)');
  c^.dexCur := 3;
  ClassCal.RecalcThiefSkills(c);
  CheckSkills(15, 25, 25, 0, 0, 10, 75, 0, 'Dexterity below 9 counts as 9');
  Reset(C_Race.MONSTER);
  c^.classLevels[C_Level.THIEF] := 12;
  c^.dexCur := 25;
  ClassCal.RecalcThiefSkills(c);
  CheckSkills(115, 112, 100, 100, 86, 30, 98, 45, 'a level 12 non-player race, Dexterity 25: level 9, human');
  c^.dexCur := 30;
  ClassCal.RecalcThiefSkills(c);
  CheckSkills(115, 112, 100, 100, 86, 30, 98, 45, 'Dexterity above 25 counts as 25');
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.THIEF] := 1;
  c^.dexCur := 20;
  ClassCal.RecalcThiefSkills(c);
  CheckSkills(50, 50, 35, 30, 25, 10, 85, 0, 'a level 1 human, Dexterity 20 (Deities & Demigods)');
  Reset(C_Race.HUMAN);
  c^.thiefSkills[1] := 77;
  ClassCal.RecalcThiefSkills(c);
  TestKit.CheckEqualsL(77, c^.thiefSkills[1], 'no thief level leaves the skills as they are');

  { the Wisdom bonus cleric slots, on the levels a cleric has slots in }
  Reset(C_Race.HUMAN);
  c^.wisCur := 12;
  c^.clericSpells[1] := 1;
  c^.clericSpells[2] := 1;
  c^.clericSpells[3] := 1;
  ClassCal.AwardWisdomBonus(c);
  TestKit.Check((c^.clericSpells[1] = 1) and (c^.clericSpells[2] = 1) and (c^.clericSpells[3] = 1),
                'Wisdom 12 adds nothing');
  c^.wisCur := 17;
  ClassCal.AwardWisdomBonus(c);
  TestKit.Check((c^.clericSpells[1] = 3) and (c^.clericSpells[2] = 3) and (c^.clericSpells[3] = 2),
                'Wisdom 17: two 1st, two 2nd and a 3rd');
  Reset(C_Race.HUMAN);
  c^.wisCur := 21;
  c^.clericSpells[1] := 1;
  c^.clericSpells[2] := 1;
  c^.clericSpells[3] := 1;
  ClassCal.AwardWisdomBonus(c);
  TestKit.Check((c^.clericSpells[1] = 4) and (c^.clericSpells[2] = 4) and (c^.clericSpells[3] = 3),
                'Wisdom 21: 19 adds a 1st, 20 a 2nd, 21 a 3rd');
  Reset(C_Race.HUMAN);
  c^.wisCur := 30;
  c^.clericSpells[1] := 2;
  ClassCal.AwardWisdomBonus(c);
  TestKit.Check((c^.clericSpells[1] = 5) and (c^.clericSpells[2] = 0) and (c^.clericSpells[3] = 0),
                'above 25 counts as 25, and a level without slots gets none');

  { racial ability limits: a dwarf (8..18 Strength for a man, 8..17 for a woman, Constitution 12..19) and an elf }
  TestKit.CheckEqualsL(8, ClassCal.RaceAbilityMin(C_Race.DWARF, 0, 0), 'a dwarf man''s least Strength');
  TestKit.CheckEqualsL(18, ClassCal.RaceAbilityMax(C_Race.DWARF, 0, 0), 'a dwarf man''s most Strength');
  TestKit.CheckEqualsL(17, ClassCal.RaceAbilityMax(C_Race.DWARF, 1, 0), 'a dwarf woman''s most Strength');
  TestKit.CheckEqualsL(12, ClassCal.RaceAbilityMin(C_Race.DWARF, 0, 4), 'a dwarf''s least Constitution');
  TestKit.CheckEqualsL(19, ClassCal.RaceAbilityMax(C_Race.DWARF, 1, 4), 'a dwarf''s most Constitution');
  TestKit.CheckEqualsL(16, ClassCal.RaceAbilityMax(C_Race.DWARF, 0, 5), 'a dwarf''s most Charisma');
  TestKit.CheckEqualsL(8, ClassCal.RaceAbilityMin(C_Race.ELF, 0, 1), 'an elf''s least Intelligence');
  TestKit.CheckEqualsL(7, ClassCal.RaceAbilityMin(C_Race.ELF, 1, 3), 'an elf''s least Dexterity');
  TestKit.CheckEqualsL(19, ClassCal.RaceAbilityMax(C_Race.ELF, 0, 3), 'an elf''s most Dexterity');
  TestKit.CheckEqualsL(3, ClassCal.RaceAbilityMin(C_Race.ELF, 0, 2), 'an elf''s least Wisdom');

  { hit points: the Constitution bonus per hit die, the warrior bonus by class (#616) }
  TestKit.CheckEqualsL(2, ClassCal.ConHpPerDie(C_Level.CLERIC, 18), 'a cleric at Constitution 18: +2');
  TestKit.CheckEqualsL(3, ClassCal.ConHpPerDie(C_Level.FIGHTER, 17), 'a fighter at 17: +3');
  TestKit.CheckEqualsL(5, ClassCal.ConHpPerDie(C_Level.PALADIN, 19), 'a paladin at 19: +5');
  TestKit.CheckEqualsL(5, ClassCal.ConHpPerDie(C_Level.RANGER, 20), 'a ranger at 20: +5');
  TestKit.CheckEqualsL(6, ClassCal.ConHpPerDie(C_Level.FIGHTER, 21), 'a fighter at 21: +6');
  TestKit.CheckEqualsL(7, ClassCal.ConHpPerDie(C_Level.FIGHTER, 25), 'a fighter at 25: +7');
  TestKit.CheckEqualsL(7, ClassCal.ConHpPerDie(C_Level.FIGHTER, 30), 'above 25 counts as 25');
  TestKit.CheckEqualsL(2, ClassCal.ConHpPerDie(C_Level.MAGE, 25), 'a magic-user at 25: +2');
  TestKit.CheckEqualsL(-2, ClassCal.ConHpPerDie(C_Level.FIGHTER, 0), 'below 3 counts as 3');
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.FIGHTER;
  c^.classLevels[C_Level.FIGHTER] := 1;
  c^.conCur := 18;
  TestKit.CheckEqualsL(4, ClassCal.ConHpBonus(c, $FF), 'a fighter with Constitution 18: +2, +1 at 17, +1 at 18');
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.CLERIC;
  c^.classLevels[C_Level.CLERIC] := 1;
  c^.conCur := 16;
  TestKit.CheckEqualsL(2, ClassCal.ConHpBonus(c, $FF), 'a cleric with Constitution 16: +2');
  c^.conCur := 3;
  TestKit.CheckEqualsL(-2, ClassCal.ConHpBonus(c, $FF), 'Constitution 3: -2');
  c^.conCur := 0;
  TestKit.CheckEqualsL(-2, ClassCal.ConHpBonus(c, $FF), 'Constitution below 3 counts as 3');
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.RANGER;
  c^.classLevels[C_Level.RANGER] := 1;
  c^.conCur := 16;
  TestKit.CheckEqualsL(4, ClassCal.ConHpBonus(c, $FF), 'a first-level ranger counts its share twice');
  c^.classLevels[C_Level.RANGER] := 2;
  TestKit.CheckEqualsL(2, ClassCal.ConHpBonus(c, $FF), 'once from level 2');
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.CLERIC_FIGHTER;
  c^.classLevels[C_Level.CLERIC] := 1;
  c^.classLevels[C_Level.FIGHTER] := 1;
  c^.conCur := 18;
  TestKit.CheckEqualsL(6, ClassCal.ConHpBonus(c, $FF), 'a cleric/fighter at 18: +2 for the cleric, +4 for the fighter');
  TestKit.CheckEqualsL(4, ClassCal.ConHpBonus(c, GDConsts.classBit[C_Level.FIGHTER]), 'the fighter''s share alone');

  TestKit.CheckEqualsL(6, ClassCal.DivideAmongClasses(10, 2, 2), '(10 + 2) div 2');
  TestKit.CheckEqualsL(4, ClassCal.DivideAmongClasses(10, -2, 2), '(10 - 2) div 2');
  TestKit.CheckEqualsL(1, ClassCal.DivideAmongClasses(3, -5, 1), 'at least 1 when the penalty would leave too little');

  { the legal hpMax range }
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.FIGHTER;
  c^.classLevels[C_Level.FIGHTER] := 3;
  c^.conCur := 10;
  TestKit.CheckEqualsL(3, ClassCal.HpMinimum(c), 'a level 3 fighter: at least 1 a level');
  TestKit.CheckEqualsL(30, ClassCal.HpMaximum(c), 'at most 10 a level');
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.RANGER;
  c^.classLevels[C_Level.RANGER] := 2;
  c^.conCur := 10;
  TestKit.CheckEqualsL(3, ClassCal.HpMinimum(c), 'a level 2 ranger: one more for its extra die');
  TestKit.CheckEqualsL(24, ClassCal.HpMaximum(c), 'and d8 on level + 1');
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.CLERIC_FIGHTER;
  c^.classLevels[C_Level.CLERIC] := 2;
  c^.classLevels[C_Level.FIGHTER] := 2;
  c^.conCur := 10;
  TestKit.CheckEqualsL(18, ClassCal.HpMaximum(c), 'a cleric/fighter 2/2: (16 + 20) div 2');

  { the Constitution bonus over every hit die }
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.FIGHTER;
  c^.classLevels[C_Level.FIGHTER] := 3;
  TestKit.CheckEqualsL(9, ClassCal.ConHpTotal(c, 17), 'a level 3 fighter at Constitution 17: 3 a level');
  TestKit.CheckEqualsL(0, ClassCal.ConHpTotal(c, 10), 'at Constitution 10: none');
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.RANGER;
  c^.classLevels[C_Level.RANGER] := 2;
  TestKit.CheckEqualsL(3, ClassCal.ConHpTotal(c, 15), 'a level 2 ranger at Constitution 15: 1 on each of 3 dice');
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.CLERIC_FIGHTER;
  c^.classLevels[C_Level.CLERIC] := 2;
  c^.classLevels[C_Level.FIGHTER] := 2;
  TestKit.CheckEqualsL(5, ClassCal.ConHpTotal(c, 17), 'a cleric/fighter 2/2 at 17: (2 * 2 + 2 * 3) div 2');
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.FIGHTER;
  c^.classLevels[C_Level.FIGHTER] := 2;
  TestKit.CheckEqualsL(2, ClassCal.ConHpTotal(c, 19) - ClassCal.ConHpTotal(c, 18),
                       'Con 18 to 19 gives a fighter 1 a level');

  { first-level hit points: the class's dice, at least two thirds of one at level 1 }
  RandSeed := 1;
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.FIGHTER] := 1;
  inRange := True;
  for n := 1 to 100 do begin
    roll := ClassCal.RollFirstLevelHp(c, $FF);
    if (roll < 6) or (roll > 10) then
      inRange := False;
  end;
  TestKit.Check(inRange, 'a level 1 fighter rolls 6..10 (d10, at least 6)');
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.RANGER] := 1;
  inRange := True;
  for n := 1 to 100 do begin
    roll := ClassCal.RollFirstLevelHp(c, $FF);
    if (roll < 5) or (roll > 16) then
      inRange := False;
  end;
  TestKit.Check(inRange, 'a level 1 ranger rolls 5..16 (2d8, at least 5)');
  Reset(C_Race.HUMAN);
  c^.classLevels[C_Level.CLERIC] := 2;
  inRange := True;
  for n := 1 to 100 do begin
    roll := ClassCal.RollFirstLevelHp(c, $FF);
    if (roll < 1) or (roll > 8) then
      inRange := False;
  end;
  TestKit.Check(inRange, 'from level 2 one die, no floor');

  { experience shares }
  Reset(C_Race.HUMAN);
  c^.charClass := C_Class.FIGHTER;
  c^.strCur := 16;
  TestKit.CheckEqualsL(110, ClassCal.ExperienceShare(c, 100), 'a fighter with Strength 16 gets 10% more');
  c^.strCur := 15;
  TestKit.CheckEqualsL(100, ClassCal.ExperienceShare(c, 100), 'with Strength 15, no bonus');
  c^.charClass := C_Class.PALADIN;
  c^.strCur := 17;
  c^.wisCur := 15;
  TestKit.CheckEqualsL(100, ClassCal.ExperienceShare(c, 100), 'a paladin needs Wisdom above 15 too');
  c^.wisCur := 16;
  TestKit.CheckEqualsL(110, ClassCal.ExperienceShare(c, 100), 'and with it gets the bonus');
  c^.charClass := C_Class.CLERIC_FIGHTER;
  TestKit.CheckEqualsL(50, ClassCal.ExperienceShare(c, 101), 'a two-class character gets half (div 2)');
  c^.charClass := C_Class.CLERIC_FIGHTER_MAGE;
  TestKit.CheckEqualsL(33, ClassCal.ExperienceShare(c, 100), 'a three-class character a third (div 3)');
  c^.charClass := C_Class.DRUID;
  TestKit.CheckEqualsL(100, ClassCal.ExperienceShare(c, 100), 'another single class gets it all');

  FreeMem(c, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.
