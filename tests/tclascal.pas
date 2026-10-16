{ Tests for ClassCal: THAC0, attacks, spell slots and the Wisdom bonus, saving throws and thief skills. }
program TClasCal;

uses Types, C_Level, C_Race, C_Save, ClassCal, TestKit;

var
  c: Types.PCharRecord;

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
  CheckSkills(85, 82, 70, 82, 68, 30, 98, 45, 'a level 12 non-player race, Dexterity 25: level 9, human, Dexterity 19');
  Reset(C_Race.HUMAN);
  c^.thiefSkills[1] := 77;
  ClassCal.RecalcThiefSkills(c);
  TestKit.CheckEqualsL(77, c^.thiefSkills[1], 'no thief level leaves the skills as they are');

  FreeMem(c, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.
