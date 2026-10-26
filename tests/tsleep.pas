{ Tests for Sleep's rules in CharHlp, which Magic.SpellSleep and the spell-aim count (#840) share: what a creature
  costs the pool (SleepCost), who the pool takes and how it is spent (SleepTakes), the most the spell-aim count says
  may fall asleep on each side (SleepMost), and how the aim line puts a side's count (CatchText). }
{$I COMPILER.INC}
program TSleep;

uses Types, C_EFFECT, C_RACE, C_STATUS, GameVars, CharHlp, TestKit;

var
  c: Types.PCharRecord;
  e: Types.TEffectRec;
  pool: Byte;
  { the spell-aim count's creatures: arena slots 1..6, nearest first in caught }
  arena: array[1..6] of Types.TCharRecord;
  caught: Types.TSlotList;
  foes: Byte;
  friends: Byte;
  i: Byte;

{ Put arena slot n in the caught list: a human of level, on team hostile. }
procedure Catch(n, level: Byte; hostile: ShortInt);
begin
  FillChar(arena[n], SizeOf(arena[n]), 0);
  arena[n].race := C_RACE.HUMAN;
  arena[n].levelHighest := level;
  arena[n].hostile := hostile;
  GameVars.creatureArr[n] := @arena[n];
  Inc(caught.count);
  caught.slot[caught.count] := n;
end;

procedure ClearCreature(level: Byte);
begin
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.race := C_RACE.HUMAN;
  c^.levelHighest := level;
end;

begin
  TestKit.Start('TSLEEP');
  GetMem(c, SizeOf(Types.TCharRecord));

  { the cost by level }
  ClearCreature(0);
  TestKit.CheckEqualsL(1, CharHlp.SleepCost(c), 'level 0 costs 1');
  ClearCreature(1);
  TestKit.CheckEqualsL(1, CharHlp.SleepCost(c), 'level 1 costs 1');
  ClearCreature(2);
  TestKit.CheckEqualsL(2, CharHlp.SleepCost(c), 'level 2 costs 2');
  ClearCreature(3);
  TestKit.CheckEqualsL(4, CharHlp.SleepCost(c), 'level 3 costs 4');
  ClearCreature(4);
  TestKit.CheckEqualsL(6, CharHlp.SleepCost(c), 'level 4 costs 6');
  ClearCreature(5);
  TestKit.CheckEqualsL(20, CharHlp.SleepCost(c), 'a level 5 character costs 20');
  c^.race := C_RACE.MONSTER;
  TestKit.CheckEqualsL(10, CharHlp.SleepCost(c), 'a level 5 monster costs 10');
  ClearCreature(6);
  TestKit.CheckEqualsL(20, CharHlp.SleepCost(c), 'level 6 costs 20');

  { the pool }
  ClearCreature(3);
  pool := 5;
  TestKit.Check(CharHlp.SleepTakes(c, pool), 'a pool of 5 takes a level 3 creature');
  TestKit.CheckEqualsL(1, pool, 'and 4 is spent');
  pool := 3;
  TestKit.Check(not CharHlp.SleepTakes(c, pool), 'a pool of 3 does not');
  TestKit.CheckEqualsL(3, pool, 'and nothing is spent');
  ClearCreature(1);
  c^.status := C_STATUS.ANIMATED;
  pool := 16;
  TestKit.Check(not CharHlp.SleepTakes(c, pool), 'animated dead are passed over');
  TestKit.CheckEqualsL(16, pool, 'at no cost');
  ClearCreature(1);
  FillChar(e, SizeOf(e), 0);
  e.id := C_EFFECT.SLEEP;
  c^.effectsAddr := @e;
  TestKit.Check(not CharHlp.SleepTakes(c, pool), 'so is a creature asleep already');
  ClearCreature(6);
  pool := 16;
  TestKit.Check(not CharHlp.SleepTakes(c, pool), 'the best pool, 16, never takes a creature costing 20');

  { the most that may fall asleep, side by side (#840): the Zhentil Keep aides (fighters of level 3, costing 4) and
    a corporal (level 2, 2), with a level 6 ally (20) nearest; three aides and the corporal take 14, and so all sleep
    at the best pool, 16 }
  caught.count := 0;
  Catch(1, 6, 0);
  Catch(2, 3, 1);
  Catch(3, 3, 1);
  Catch(4, 3, 1);
  Catch(5, 2, 1);
  CharHlp.SleepMost(caught, 1, foes, friends);
  TestKit.CheckEqualsL(4, foes, 'three aides and a corporal may all fall asleep');
  TestKit.CheckEqualsL(0, friends, 'the level 6 ally never does');
  { an ally of level 4 (6) nearest takes its share first: 16 - 6 leaves room for two aides, and a pool under 6 passes
    over it and takes an aide; the sides keep their best, which need not come on one roll }
  arena[1].levelHighest := 4;
  CharHlp.SleepMost(caught, 1, foes, friends);
  TestKit.CheckEqualsL(3, foes, 'past a level 4 ally, at most three enemies');
  TestKit.CheckEqualsL(1, friends, 'and the ally may fall asleep');
  { a creature immune to sleep takes its share as any other and counts as one that may fall asleep: the count gives
    no immunity away }
  FillChar(e, SizeOf(e), 0);
  e.id := C_EFFECT.NO_SLEEP_CHARM;
  arena[2].effectsAddr := @e;
  arena[1].levelHighest := 6;
  CharHlp.SleepMost(caught, 1, foes, friends);
  TestKit.CheckEqualsL(4, foes, 'an aide immune to sleep still counts');
  { those asleep already are passed over: a group all asleep counts 0, as SpellSleep would put none to sleep }
  e.id := C_EFFECT.SLEEP;
  for i := 2 to 5 do
    arena[i].effectsAddr := @e;
  CharHlp.SleepMost(caught, 1, foes, friends);
  TestKit.CheckEqualsL(0, foes, 'a group asleep already counts 0');
  for i := 2 to 5 do
    arena[i].effectsAddr := nil;
  { animated dead are passed over too }
  arena[2].status := C_STATUS.ANIMATED;
  CharHlp.SleepMost(caught, 1, foes, friends);
  TestKit.CheckEqualsL(3, foes, 'animated dead do not count');
  caught.count := 0;
  CharHlp.SleepMost(caught, 1, foes, friends);
  TestKit.Check((foes = 0) and (friends = 0), 'an empty area counts 0 on both sides');

  { a side's count on the aim line }
  TestKit.CheckEqualsS('3 OF 2 ENEMIES', CharHlp.CatchText(3, 2, True), 'the most when fewer may be taken');
  TestKit.CheckEqualsS('3 ENEMIES', CharHlp.CatchText(3, 3, True), 'no most when all may be');
  TestKit.CheckEqualsS('3 ENEMIES', CharHlp.CatchText(3, 0, True), 'no most of 0');
  TestKit.CheckEqualsS('1 ENEMY', CharHlp.CatchText(1, 0, True), 'one enemy');
  TestKit.CheckEqualsS('2 OF 1 ALLIES', CharHlp.CatchText(2, 1, False), 'the allies, with their most');
  TestKit.CheckEqualsS('1 ALLY', CharHlp.CatchText(1, 1, False), 'one ally');
  TestKit.CheckEqualsS('12 ALLIES', CharHlp.CatchText(12, 0, False), 'and none for a spell without one');

  FreeMem(c, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.
