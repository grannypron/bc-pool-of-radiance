{ Tests for the drain log (#1174): what an energy drain records (EffHndlr.DrainLevels, CharExt.PushDrain), how
  Restoration gives a level back with the experience and hit points the drain took (Magic.RestoreLevel), the rule for
  levels the log does not hold (an old save's), training's forfeit (CharExt.TrainDrain), a class change clearing the
  log, the .chx file at version 3 and the versions before it, and what the View page shows (#1161): the levels each
  class lost (Magic.DrainedByClass) and the secondary statuses (ViewChar.SecondaryStatus). }
{$I COMPILER.INC}
program TDrain;

uses Types, C_ALIGN, C_CLASS, C_EFFECT, C_LEVEL, C_RACE, C_STAT, C_STATUS, GameVars, FileUtil, ClassCal, CharExt,
  EffHndlr, Magic, ViewChar, VidVga, TestKit;

const
  FN = 'TDR';

type
  { a version 2 .chx file, from before the drain log }
  TExtFile2 = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    formerClasses: Byte;
    flags: Byte;
  end;

var
  c: Types.PCharRecord;
  d: Types.PCharRecord;
  s: FileUtil.TFileSet;
  e: Types.TDrainRec;
  counts: Types.TClassCounts;
  poison: Types.TEffectRec;
  old: TExtFile2;
  f: file;
  i: Byte;

{ c: a creature of race and class cls (a C_CLASS value) with Str 18, Int 17, Wis 16, Dex 16, Con 14, Cha 10, its
  skills worked out; the class levels are the caller's. }
procedure NewChar(race, cls: ShortInt);
begin
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.name := 'SHIP';
  c^.randByte := 5;
  c^.race := race;
  c^.charClass := cls;
  c^.alignment := C_ALIGN.LN;
  c^.stats[C_STAT.STRENGTH] := 18;
  c^.stats[C_STAT.INTELLIGENCE] := 17;
  c^.stats[C_STAT.WISDOM] := 16;
  c^.stats[C_STAT.DEXTERITY] := 16;
  c^.stats[C_STAT.CONSTITUTION] := 14;
  c^.stats[C_STAT.CHARISMA] := 10;
  c^.status := C_STATUS.OKAY;
end;

{ c: SHIP, a human cleric of level 4 with 6750 experience and 24 hit points (6 a level). }
procedure Ship;
begin
  NewChar(C_RACE.HUMAN, C_CLASS.CLERIC);
  c^.classLevels[C_LEVEL.CLERIC] := 4;
  c^.levelHighest := 4;
  c^.experience := 6750;
  c^.hpMax := 24;
  c^.hpCur := 24;
  c^.hpRolled := 24;
  ClassCal.RecalcBaseSkills(c);
end;

begin
  TestKit.Start('TDRAIN');
  GetMem(c, SizeOf(Types.TCharRecord));
  GetMem(d, SizeOf(Types.TCharRecord));
  { a drain says so on the screen: VGA's, with a blank font }
  VidVga.Install;
  GetMem(GameVars.gameFont, SizeOf(Types.TFontArr));
  FillChar(GameVars.gameFont^, SizeOf(Types.TFontArr), 0);

  { the issue's example: drained twice, experience earned between, restored twice }
  Ship;
  EffHndlr.DrainLevels(c, 1);
  TestKit.CheckEqualsL(3, c^.classLevels[C_LEVEL.CLERIC], 'SHIP is drained to level 3');
  TestKit.CheckEqualsL(3001, c^.experience, 'at level 3''s start');
  TestKit.CheckEqualsL(18, c^.hpMax, 'losing 6 hit points');
  TestKit.CheckEqualsL(1, c^.portExt.drainCount, 'the drain is logged');
  TestKit.CheckEqualsL(3749, c^.portExt.drains[1].xp, 'with the experience it took');
  TestKit.CheckEqualsL(6, c^.portExt.drains[1].hp, 'its hit points');
  TestKit.CheckEqualsL(C_LEVEL.CLERIC, c^.portExt.drains[1].cls, 'and the class lowered');
  Inc(c^.experience, 500);
  EffHndlr.DrainLevels(c, 1);
  TestKit.CheckEqualsL(2, c^.classLevels[C_LEVEL.CLERIC], 'drained again to level 2');
  TestKit.CheckEqualsL(1501, c^.experience, 'at level 2''s start');
  TestKit.CheckEqualsL(2, c^.portExt.drainCount, 'two entries');
  TestKit.CheckEqualsL(2000, c^.portExt.drains[2].xp, 'the second took 2000');
  TestKit.CheckEqualsL(2, c^.drainedLevels, 'two drained levels');
  TestKit.CheckEqualsS(', Drained', ViewChar.SecondaryStatus(c), 'the View page says Drained');
  Magic.DrainedByClass(c, counts);
  TestKit.CheckEqualsL(2, counts[C_LEVEL.CLERIC], 'and the cleric level -2');
  Inc(c^.experience, 15);
  TestKit.Check(Magic.RestoreLevel(c), 'Restoration gives a level back');
  TestKit.CheckEqualsL(3, c^.classLevels[C_LEVEL.CLERIC], 'level 3 again');
  TestKit.CheckEqualsL(3516, c^.experience, 'with the 2000 the second drain took added');
  TestKit.CheckEqualsL(18, c^.hpMax, 'and its 6 hit points');
  TestKit.CheckEqualsL(1, c^.portExt.drainCount, 'one entry left');
  TestKit.Check(Magic.RestoreLevel(c), 'a second Restoration');
  TestKit.CheckEqualsL(4, c^.classLevels[C_LEVEL.CLERIC], 'level 4 again');
  TestKit.CheckEqualsL(7265, c^.experience, 'the 6750 SHIP started with and the 515 he earned');
  TestKit.CheckEqualsL(24, c^.hpMax, 'all his hit points');
  TestKit.CheckEqualsL(0, c^.drainedLevels, 'no drained level left');
  TestKit.CheckEqualsL(0, c^.drainedHps, 'nor hit points');
  TestKit.CheckEqualsL(0, c^.portExt.drainCount, 'nor entries');
  TestKit.CheckEqualsS('', ViewChar.SecondaryStatus(c), 'no secondary status');
  TestKit.Check(not Magic.RestoreLevel(c), 'a third Restoration does nothing');

  { a two-level drain makes two entries }
  Ship;
  EffHndlr.DrainLevels(c, 2);
  TestKit.CheckEqualsL(2, c^.portExt.drainCount, 'a two-level drain logs two entries');
  TestKit.CheckEqualsL(3749, c^.portExt.drains[1].xp, 'the first level''s experience');
  TestKit.CheckEqualsL(1500, c^.portExt.drains[2].xp, 'and the second''s');

  { an old save: drained levels and no log, restored by SSI's rule }
  Ship;
  c^.classLevels[C_LEVEL.CLERIC] := 2;
  c^.experience := 1600;
  c^.hpMax := 12;
  c^.drainedLevels := 2;
  c^.drainedHps := 12;
  Magic.DrainedByClass(c, counts);
  TestKit.CheckEqualsL(2, counts[C_LEVEL.CLERIC], 'an old save''s two drained levels are the cleric''s');
  TestKit.Check(Magic.RestoreLevel(c), 'an old save''s drain is restored');
  TestKit.CheckEqualsL(3, c^.classLevels[C_LEVEL.CLERIC], 'a level back');
  TestKit.CheckEqualsL(3001, c^.experience, 'experience raised to its start');
  TestKit.CheckEqualsL(18, c^.hpMax, 'the average hit points back');
  TestKit.CheckEqualsL(6, c^.drainedHps, 'the rest still owed');

  { a logged drain on top of an unlogged one comes back first }
  Ship;
  c^.classLevels[C_LEVEL.CLERIC] := 3;
  c^.experience := 3001;
  c^.drainedLevels := 1;
  c^.drainedHps := 4;
  EffHndlr.DrainLevels(c, 1);
  TestKit.CheckEqualsL(1, c^.portExt.drainCount, 'one entry over one unlogged level');
  Magic.RestoreLevel(c);
  TestKit.CheckEqualsL(3001, c^.experience, 'the logged one comes back first, with its 1500');
  TestKit.CheckEqualsL(4, c^.drainedHps, 'and its own hit points');
  Magic.RestoreLevel(c);
  TestKit.CheckEqualsL(4, c^.classLevels[C_LEVEL.CLERIC], 'then the unlogged one');
  TestKit.CheckEqualsL(6001, c^.experience, 'at its level''s start');

  { the log keeps DRAIN_LOG_LEN entries, the oldest going }
  Ship;
  for i := 1 to Types.DRAIN_LOG_LEN + 1 do
    CharExt.PushDrain(c, i, 1, C_LEVEL.CLERIC);
  TestKit.CheckEqualsL(Types.DRAIN_LOG_LEN, c^.portExt.drainCount, 'a ninth drain fills the log');
  TestKit.CheckEqualsL(2, c^.portExt.drains[1].xp, 'the first entry gone');
  TestKit.Check(CharExt.PopDrain(c, e) and (e.xp = Types.DRAIN_LOG_LEN + 1), 'the most recent pops first');

  { training: the trained class's entry goes, its experience forfeit }
  NewChar(C_RACE.HALF_ELF, C_CLASS.FIGHTER_MAGE_THIEF);
  c^.classLevels[C_LEVEL.FIGHTER] := 3;
  c^.classLevels[C_LEVEL.MAGE] := 3;
  c^.classLevels[C_LEVEL.THIEF] := 4;
  c^.drainedLevels := 3;
  CharExt.PushDrain(c, 100, 2, C_LEVEL.FIGHTER);
  CharExt.PushDrain(c, 200, 2, C_LEVEL.THIEF);
  CharExt.PushDrain(c, 300, 2, C_LEVEL.FIGHTER);
  Magic.DrainedByClass(c, counts);
  TestKit.CheckEqualsL(2, counts[C_LEVEL.FIGHTER], 'a triple class: the fighter lost two levels');
  TestKit.CheckEqualsL(0, counts[C_LEVEL.MAGE], 'the magic-user none');
  TestKit.CheckEqualsL(1, counts[C_LEVEL.THIEF], 'the thief one');
  TestKit.Check(CharExt.TrainDrain(c, C_LEVEL.THIEF, e) and (e.xp = 200), 'training the thief drops its entry');
  TestKit.CheckEqualsL(2, c^.portExt.drainCount, 'two left');
  TestKit.CheckEqualsL(300, c^.portExt.drains[2].xp, 'the later fighter entry moved down');
  c^.drainedLevels := 2;
  TestKit.Check(CharExt.TrainDrain(c, C_LEVEL.MAGE, e) and (e.xp = 300),
                'a class with no entry drops the most recent');
  c^.drainedLevels := 2;
  TestKit.Check(not CharExt.TrainDrain(c, C_LEVEL.MAGE, e), 'unless an unlogged level is there to take');
  c^.portExt.drainCount := 0;
  c^.drainedLevels := 1;
  Magic.DrainedByClass(c, counts);
  TestKit.CheckEqualsL(1, counts[C_LEVEL.FIGHTER] + counts[C_LEVEL.MAGE], 'an unlogged level goes where Restoration '
                       + 'would put it: the fighter or magic-user, the lowest');
  TestKit.CheckEqualsL(0, counts[C_LEVEL.THIEF], 'not the thief, a level higher');
  TestKit.CheckEqualsL(3, c^.classLevels[C_LEVEL.FIGHTER], 'and the look ahead leaves the levels as they were');
  TestKit.CheckEqualsL(4, c^.classLevels[C_LEVEL.THIEF], 'every one');

  { a class change clears the log }
  NewChar(C_RACE.HUMAN, C_CLASS.FIGHTER);
  c^.classLevels[C_LEVEL.FIGHTER] := 5;
  c^.drainedLevels := 1;
  CharExt.PushDrain(c, 100, 2, C_LEVEL.FIGHTER);
  ClassCal.ChangeClass(c, C_LEVEL.MAGE);
  TestKit.CheckEqualsL(0, c^.portExt.drainCount, 'changing class forfeits the log');

  { the .chx file at version 3 }
  Ship;
  EffHndlr.DrainLevels(c, 1);
  TestKit.Check(CharExt.HasExt(c), 'a drained character needs a .chx');
  FileUtil.NewSet(s, '');
  TestKit.Check(CharExt.WriteExt(s, c, FN) and FileUtil.CommitSet(s), 'which is written');
  d^ := c^;
  FillChar(d^.portExt, SizeOf(d^.portExt), $FF);
  CharExt.ReadExt(d, FN);
  TestKit.CheckEqualsL(1, d^.portExt.drainCount, 'and its log read back');
  TestKit.CheckEqualsL(3749, d^.portExt.drains[1].xp, 'with its experience');
  d^.drainedLevels := 0;
  CharExt.ReadExt(d, FN);
  TestKit.CheckEqualsL(0, d^.portExt.drainCount, 'a log is never longer than the drained levels');
  { a version 2 file, written before the log }
  FillChar(old, SizeOf(old), 0);
  old.sig := 'CEXT';
  old.version := 2;
  old.name := c^.name;
  old.randByte := c^.randByte;
  old.formerClasses := C_LEVEL.FIGHTER_BIT;
  old.flags := CharExt.EXT_ANIMATE_JOINED;
  Assign(f, FN + '.chx');
  Rewrite(f, 1);
  BlockWrite(f, old, SizeOf(old));
  Close(f);
  FillChar(d^.portExt, SizeOf(d^.portExt), $FF);
  d^.drainedLevels := 1;
  CharExt.ReadExt(d, FN);
  TestKit.CheckEqualsL(C_LEVEL.FIGHTER_BIT, d^.portExt.formerClasses, 'a version 2 file still gives the class left');
  TestKit.CheckEqualsL(CharExt.EXT_ANIMATE_JOINED, d^.portExt.flags, 'and the flags');
  TestKit.CheckEqualsL(0, d^.portExt.drainCount, 'and no log');
  Ship;
  FileUtil.NewSet(s, '');
  TestKit.Check(CharExt.WriteExt(s, c, FN) and FileUtil.CommitSet(s), 'an ordinary character''s save erases it');

  { the secondary statuses }
  Ship;
  c^.status := C_STATUS.DEAD_STATUS;
  FillChar(poison, SizeOf(poison), 0);
  poison.id := C_EFFECT.POISONED;
  c^.effectsAddr := @poison;
  TestKit.CheckEqualsS(', Poisoned', ViewChar.SecondaryStatus(c), 'killed by poison: Dead, Poisoned');
  c^.drainedLevels := 2;
  TestKit.CheckEqualsS(', Poisoned, Drained', ViewChar.SecondaryStatus(c), 'and drained too');

  FreeMem(c, SizeOf(Types.TCharRecord));
  FreeMem(d, SizeOf(Types.TCharRecord));
  FreeMem(GameVars.gameFont, SizeOf(Types.TFontArr));
  TestKit.Done;
end.
