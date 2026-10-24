{ Tests for dual-classing (#838): who may leave a class and take another (ClassCal.CanChangeClass, CanTakeClass), what
  the change does to the record (ClassCal.ChangeClass), the levels a resting class lends (CharHlp.GetClassLevel,
  ClassResting) before and after the class followed passes it, the hit dice each class gives (ClassCal.HitDice,
  HpMaximum, HpMinimum), training (CharHlp.CanTrain), a second change, and the .chx file that keeps the classes left
  (CharExt). }
{$I COMPILER.INC}
program TDualCls;

uses Types, C_ABIL, C_ALIGN, C_CLASS, C_LEVEL, C_RACE, GameDefs, FileUtil, CharHlp, ClassCal, CharExt, TestKit;

const
  FN = 'TDC';

var
  c: Types.PCharRecord;
  d: Types.PCharRecord;
  s: FileUtil.TFileSet;
  i: Byte;

{ c: a human fighter of level lvl, Str 18, Int 17, Wis 12, Dex 16, Con 14, Cha 10, lawful neutral. }
procedure Fighter(lvl: ShortInt);
begin
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.name := 'ALIAS';
  c^.randByte := 77;
  c^.race := C_RACE.HUMAN;
  c^.charClass := C_CLASS.FIGHTER;
  c^.alignment := C_ALIGN.LN;
  c^.classLevels[C_LEVEL.FIGHTER] := lvl;
  c^.stats[C_ABIL.STRENGTH] := 18;
  c^.stats[C_ABIL.INTELLIGENCE] := 17;
  c^.stats[C_ABIL.WISDOM] := 12;
  c^.stats[C_ABIL.DEXTERITY] := 16;
  c^.stats[C_ABIL.CONSTITUTION] := 14;
  c^.stats[C_ABIL.CHARISMA] := 10;
  c^.experience := 40000;
  ClassCal.RecalcBaseSkills(c);
end;

{ d: a plain single-class character of class cls at level lvl, its skills worked out, to compare c with. }
procedure Plain(cls, lvl: ShortInt);
begin
  FillChar(d^, SizeOf(Types.TCharRecord), 0);
  d^.race := C_RACE.HUMAN;
  d^.charClass := cls;
  d^.classLevels[cls] := lvl;
  ClassCal.RecalcBaseSkills(d);
end;

function SameSaves: Boolean;
var
  k: Byte;
begin
  SameSaves := True;
  for k := 0 to 4 do
    if c^.saves[k] <> d^.saves[k] then
      SameSaves := False;
end;

begin
  TestKit.Start('TDUALCLS');
  GetMem(c, SizeOf(Types.TCharRecord));
  GetMem(d, SizeOf(Types.TCharRecord));

  { who may leave a class }
  Fighter(5);
  TestKit.Check(not CharHlp.IsDualClass(c), 'a fighter who has never changed is not dual-classed');
  TestKit.Check(ClassCal.CanChangeClass(c), 'a human fighter with Strength 18 may leave the class');
  c^.stats[C_ABIL.STRENGTH] := 14;
  TestKit.Check(not ClassCal.CanChangeClass(c), 'not with Strength 14: leaving needs 15');
  c^.stats[C_ABIL.STRENGTH] := 15;
  TestKit.Check(ClassCal.CanChangeClass(c), 'Strength 15 is enough');
  c^.stats[C_ABIL.STRENGTH] := 18;
  c^.race := C_RACE.HALFELF;
  TestKit.Check(not ClassCal.CanChangeClass(c), 'a half-elf never changes class');
  c^.race := C_RACE.HUMAN;
  c^.charClass := C_CLASS.FIGHTER_MAGE;
  TestKit.Check(not ClassCal.CanChangeClass(c), 'nor does a multi-class character');
  Fighter(1);
  TestKit.Check(ClassCal.CanChangeClass(c), 'no level is asked for: a level 1 fighter may change, as in Curse');

  { which classes it may take }
  Fighter(5);
  TestKit.Check(ClassCal.CanTakeClass(c, C_LEVEL.MAGE), 'Intelligence 17 takes the magic-user');
  TestKit.Check(not ClassCal.CanTakeClass(c, C_LEVEL.CLERIC), 'Wisdom 12 does not take the cleric');
  TestKit.Check(not ClassCal.CanTakeClass(c, C_LEVEL.THIEF), 'Dexterity 16 does not take the thief: it needs 17');
  TestKit.Check(not ClassCal.CanTakeClass(c, C_LEVEL.FIGHTER), 'nor the class it follows');
  TestKit.Check(not ClassCal.CanTakeClass(c, C_LEVEL.DRUID), 'nor a class creation does not offer a human');
  for i := C_ABIL.STRENGTH to C_ABIL.CHARISMA do
    c^.stats[i] := 17;
  c^.stats[C_ABIL.STRENGTH] := 18;
  TestKit.Check(not ClassCal.CanTakeClass(c, C_LEVEL.PALADIN), 'a lawful neutral never becomes a paladin');
  c^.alignment := C_ALIGN.LG;
  TestKit.Check(ClassCal.CanTakeClass(c, C_LEVEL.PALADIN), 'a lawful good one with 17s does');
  TestKit.Check(ClassCal.CanTakeClass(c, C_LEVEL.RANGER), 'and may become a ranger: Curse offers both');
  c^.stats[C_ABIL.CHARISMA] := 16;
  TestKit.Check(not ClassCal.CanTakeClass(c, C_LEVEL.PALADIN), 'not with Charisma 16, below the paladin''s minimum');

  { the change }
  Fighter(5);
  c^.hpMax := 40;
  c^.memorizedSpells[1] := 3;
  ClassCal.ChangeClass(c, C_LEVEL.MAGE);
  TestKit.Check(CharHlp.IsDualClass(c), 'a fighter turned magic-user is dual-classed');
  TestKit.CheckEqualsL(C_LEVEL.FIGHTER_BIT, c^.portExt.formerClasses, 'the fighter is the class left');
  TestKit.CheckEqualsL(C_CLASS.MAGE, c^.charClass, 'charClass is the magic-user');
  TestKit.CheckEqualsL(1, c^.classLevels[C_LEVEL.MAGE], 'at level 1');
  TestKit.CheckEqualsL(5, c^.classLevels[C_LEVEL.FIGHTER], 'the fighter keeps level 5');
  TestKit.CheckEqualsL(0, c^.experience, 'experience starts again at 0');
  TestKit.CheckEqualsL(40, c^.hpMax, 'hit points stay');
  TestKit.CheckEqualsL(0, c^.memorizedSpells[1], 'memorized spells are gone');
  TestKit.CheckEqualsL(1, c^.mageSpells[1], 'a first-level magic-user slot');
  TestKit.Check(c^.spellsKnown[11] <> 0, 'and Detect Magic known, as at creation');
  TestKit.CheckEqualsL(5, c^.levelHighest, 'levelHighest keeps the levels as they are');
  TestKit.CheckEqualsL(1, CharHlp.CurrentClassLevel(c), 'CHAR_LEVEL reads the class followed now');

  { the fighter rests }
  TestKit.Check(CharHlp.ClassResting(c, C_LEVEL.FIGHTER), 'the fighter rests');
  TestKit.CheckEqualsL(0, CharHlp.GetClassLevel(c, C_LEVEL.FIGHTER_BIT), 'and lends no level');
  TestKit.CheckEqualsL(0, CharHlp.WarriorLevel(c), 'nor a warrior''s');
  TestKit.CheckEqualsL(1, CharHlp.GetClassLevel(c, C_LEVEL.MAGE_BIT), 'the magic-user''s level is its own');
  TestKit.CheckEqualsL(1, CharHlp.GetClassLevel(c, C_LEVEL.ALL_BITS), 'the highest usable level is 1');
  Plain(C_LEVEL.MAGE, 1);
  TestKit.CheckEqualsL(d^.thac0Base, c^.thac0Base, 'THAC0 is a level 1 magic-user''s');
  TestKit.Check(SameSaves, 'and so are the saving throws');
  TestKit.CheckEqualsL(ClassCal.usabilityBit[C_LEVEL.MAGE], c^.itemLimits, 'and the weapons and armor');
  TestKit.Check(not ClassCal.CanChangeClass(c), 'no second change while a class rests');
  TestKit.CheckEqualsL(5, ClassCal.HitDice(c, C_LEVEL.FIGHTER), 'the fighter''s five hit dice');
  TestKit.CheckEqualsL(0, ClassCal.HitDice(c, C_LEVEL.MAGE), 'the magic-user has none yet');
  TestKit.CheckEqualsL(1, ClassCal.HpClassCount(c), 'hit points are not divided between the classes');
  TestKit.CheckEqualsL(50, ClassCal.HpMaximum(c), 'at most 10 a fighter level, Con 14 adding none');
  TestKit.CheckEqualsL(5, ClassCal.HpMinimum(c), 'at least 1 a fighter level');

  c^.classLevels[C_LEVEL.MAGE] := 5;
  ClassCal.RecalcBaseSkills(c);
  TestKit.Check(CharHlp.ClassResting(c, C_LEVEL.FIGHTER), 'level 5 as a magic-user does not pass the fighter''s 5');
  TestKit.CheckEqualsL(0, ClassCal.HitDice(c, C_LEVEL.MAGE), 'nor gives a hit die');

  { the fighter wakes }
  c^.classLevels[C_LEVEL.MAGE] := 6;
  ClassCal.RecalcBaseSkills(c);
  TestKit.Check(not CharHlp.ClassResting(c, C_LEVEL.FIGHTER), 'level 6 passes it: the fighter wakes');
  TestKit.CheckEqualsL(5, CharHlp.GetClassLevel(c, C_LEVEL.FIGHTER_BIT), 'and lends level 5');
  TestKit.CheckEqualsL(5, CharHlp.WarriorLevel(c), 'a warrior''s level 5');
  TestKit.CheckEqualsL(6, CharHlp.GetClassLevel(c, C_LEVEL.ALL_BITS), 'the highest usable level is 6');
  Plain(C_LEVEL.FIGHTER, 5);
  TestKit.CheckEqualsL(d^.thac0Base, c^.thac0Base, 'THAC0 is the fighter''s, the better');
  TestKit.CheckEqualsL(ClassCal.usabilityBit[C_LEVEL.MAGE] or ClassCal.usabilityBit[C_LEVEL.FIGHTER], c^.itemLimits,
                       'a fighter''s weapons and armor again');
  TestKit.CheckEqualsL(1, ClassCal.HitDice(c, C_LEVEL.MAGE), 'level 6 is the magic-user''s first hit die');
  TestKit.CheckEqualsL(54, ClassCal.HpMaximum(c), 'at most 50 for the fighter and 4 for the magic-user');
  TestKit.CheckEqualsL(6, CharHlp.CurrentClassLevel(c), 'CHAR_LEVEL is 6');

  { training }
  c^.classLevels[C_LEVEL.MAGE] := C_LEVEL.LEVEL_LAST;
  c^.experience := 2000000;
  TestKit.Check(not CharHlp.CanTrain(c), 'the fighter never trains again, whatever the experience');

  { a second change, once every class left is awake }
  c^.classLevels[C_LEVEL.MAGE] := 6;
  c^.stats[C_ABIL.WISDOM] := 17;
  ClassCal.RecalcBaseSkills(c);
  TestKit.Check(ClassCal.CanChangeClass(c), 'a magic-user with Intelligence 17 may leave its class');
  TestKit.Check(ClassCal.CanTakeClass(c, C_LEVEL.CLERIC), 'and become a cleric');
  TestKit.Check(not ClassCal.CanTakeClass(c, C_LEVEL.FIGHTER), 'but never the fighter it left');
  ClassCal.ChangeClass(c, C_LEVEL.CLERIC);
  TestKit.CheckEqualsL(C_LEVEL.FIGHTER_BIT + C_LEVEL.MAGE_BIT, c^.portExt.formerClasses, 'two classes left');
  TestKit.CheckEqualsL(0, CharHlp.GetClassLevel(c, C_LEVEL.FIGHTER_BIT + C_LEVEL.MAGE_BIT), 'both rest');
  TestKit.CheckEqualsL(0, c^.mageSpells[1], 'the resting magic-user has no slots');
  TestKit.CheckEqualsL(5, ClassCal.HitDice(c, C_LEVEL.FIGHTER), 'the fighter''s dice');
  TestKit.CheckEqualsL(1, ClassCal.HitDice(c, C_LEVEL.MAGE), 'the magic-user''s one past the fighter');
  c^.classLevels[C_LEVEL.CLERIC] := 6;
  TestKit.Check(not CharHlp.ClassResting(c, C_LEVEL.FIGHTER), 'cleric 6 wakes the fighter');
  TestKit.Check(CharHlp.ClassResting(c, C_LEVEL.MAGE), 'but not the magic-user of level 6');
  TestKit.CheckEqualsL(0, ClassCal.HitDice(c, C_LEVEL.CLERIC), 'nor gives the cleric a die');
  c^.classLevels[C_LEVEL.CLERIC] := 7;
  TestKit.Check(not CharHlp.ClassResting(c, C_LEVEL.MAGE), 'cleric 7 wakes the magic-user');
  TestKit.CheckEqualsL(1, ClassCal.HitDice(c, C_LEVEL.CLERIC), 'and is the cleric''s first die');

  { a character never changed is as it was }
  Plain(C_LEVEL.RANGER, 2);
  TestKit.CheckEqualsL(3, ClassCal.HitDice(d, C_LEVEL.RANGER), 'a level 2 ranger''s three dice');
  TestKit.CheckEqualsL(2, CharHlp.GetClassLevel(d, C_LEVEL.WARRIOR_BITS), 'its warrior level');
  d^.levelHighest := 2;
  TestKit.CheckEqualsL(2, CharHlp.CurrentClassLevel(d), 'CHAR_LEVEL is levelHighest');

  { the .chx file }
  Fighter(5);
  ClassCal.ChangeClass(c, C_LEVEL.MAGE);
  FileUtil.NewSet(s, '');
  TestKit.Check(CharExt.WriteExt(s, c, FN) and FileUtil.CommitSet(s), 'a dual-classed character''s .chx is written');
  d^ := c^;
  FillChar(d^.portExt, SizeOf(d^.portExt), $FF);
  CharExt.ReadExt(d, FN);
  TestKit.CheckEqualsL(C_LEVEL.FIGHTER_BIT, d^.portExt.formerClasses, 'and read back');
  d^.randByte := 78;
  CharExt.ReadExt(d, FN);
  TestKit.CheckEqualsL(0, d^.portExt.formerClasses, 'not for another character of the name');
  d^ := c^;
  d^.name := 'OTHER';
  CharExt.ReadExt(d, FN);
  TestKit.CheckEqualsL(0, d^.portExt.formerClasses, 'nor of another name');
  Fighter(5);
  FileUtil.NewSet(s, '');
  TestKit.Check(CharExt.WriteExt(s, c, FN) and FileUtil.CommitSet(s), 'an ordinary character''s save');
  TestKit.Check(not FileUtil.Exists(FN + '.chx'), 'erases the .chx');
  c^.portExt.formerClasses := C_LEVEL.FIGHTER_BIT;
  CharExt.ReadExt(c, FN);
  TestKit.CheckEqualsL(0, c^.portExt.formerClasses, 'and with none a character is ordinary');

  FreeMem(c, SizeOf(Types.TCharRecord));
  FreeMem(d, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.
