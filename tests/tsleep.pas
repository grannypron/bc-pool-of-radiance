{ Tests for Sleep's rules in CharHlp, which Magic.SleepHandler and the spell-aim count (#840) share: what a creature
  costs the pool (SleepCost), who the pool takes and how it is spent (SleepTakes), and who cannot sleep at all
  (SleepProof). }
{$I COMPILER.INC}
program TSleep;

uses Types, C_EFFECT, C_RACE, C_STATUS, CharHlp, TestKit;

var
  c: Types.PCharRecord;
  e: Types.TEffectRec;
  pool: Byte;

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
  TestKit.Check(not CharHlp.SleepProof(c), 'which is not proof against it');
  ClearCreature(6);
  pool := 16;
  TestKit.Check(not CharHlp.SleepTakes(c, pool), 'the best pool, 16, never takes a creature costing 20');

  { proof against sleep }
  ClearCreature(1);
  TestKit.Check(not CharHlp.SleepProof(c), 'a plain creature can sleep');
  e.id := C_EFFECT.NO_SLEEP_CHARM;
  c^.effectsAddr := @e;
  TestKit.Check(CharHlp.SleepProof(c), 'immunity to sleep and charm is proof');
  pool := 4;
  TestKit.Check(CharHlp.SleepTakes(c, pool) and (pool = 3), 'yet the pool is still spent on it');
  e.id := C_EFFECT.NO_CHARM_POISON;
  TestKit.Check(CharHlp.SleepProof(c), 'and so is immunity to sleep, charm, paralysis and poison');
  e.id := C_EFFECT.ELF_RESIST;
  TestKit.Check(not CharHlp.SleepProof(c), 'an elf''s resistance is a roll, not proof');
  c^.effectsAddr := nil;

  FreeMem(c, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.
