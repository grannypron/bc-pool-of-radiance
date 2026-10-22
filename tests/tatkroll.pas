{ Tests for FxEngine's attack rolls: a penalty that takes a low roll below 0 only lowers it (#718), only an effect that
  forces a miss (Blink, Displacement) does, and a script's attack with no attacker hits on the same roll as a creature's
  (#719). And for Dice.ReduceDamagePerDie, which takes damage off per die and leaves no die below 1 (#745). }
{$I COMPILER.INC}
program TAtkRoll;

uses Types, C_Effect, GDVars, Dice, FxEngine, TestKit;

const
  TRIES = 200;

var
  att: Types.PCharRecord;
  def: Types.PCharRecord;
  natural: ShortInt;
  penalty: ShortInt;
  forceMiss: Boolean;
  calls: Integer;
  hits: Integer;
  bad: Integer;
  i: Integer;

{$F+}
{ An attacker's effect: note the natural roll, count the rolls above 1 and take penalty off it. }
procedure Penalize(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  natural := GDVars.gAttackRoll;
  Inc(calls);
  Dec(GDVars.gAttackRoll, penalty);
end;

{ A defender's effect: note the roll, and force a miss when asked, as Blink and Displacement do. }
procedure Defend(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  natural := GDVars.gAttackRoll;
  if forceMiss then
    GDVars.gAttackAvoided := True;
end;
{$F-}

{ ReduceDamagePerDie's result for damage from count dice, perDie off each }
function Reduced(damage, count, perDie: Byte): Byte;
begin
  GDVars.pendingDamage := damage;
  GDVars.gDamageDice := count;
  Dice.ReduceDamagePerDie(perDie);
  Reduced := GDVars.pendingDamage;
end;

function NewCreature(effId: Byte): Types.PCharRecord;
var
  c: Types.PCharRecord;
begin
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  GetMem(c^.effectsAddr, SizeOf(Types.TEffectRec));
  FillChar(c^.effectsAddr^, SizeOf(Types.TEffectRec), 0);
  c^.effectsAddr^.id := effId;
  NewCreature := c;
end;

begin
  TestKit.Start('TATKROLL');
  GetMem(GDVars.zone1, SizeOf(GDVars.zone1^));
  FillChar(GDVars.zone1^, SizeOf(GDVars.zone1^), 0);
  GDVars.effectFns[C_Effect.BLESS] := Penalize;
  GDVars.effectFns[C_Effect.DISPLACED] := Defend;
  att := NewCreature(C_Effect.BLESS);
  def := NewCreature(C_Effect.DISPLACED);

  { THAC0 1 against AC 10 with a -10 penalty: every roll but a natural 1 hits, though most go below 0 }
  att^.thac0Cur := 59;
  penalty := 10;
  forceMiss := False;
  calls := 0;
  hits := 0;
  for i := 1 to TRIES do
    if FxEngine.AttackRoll(att, def, 50) then
      Inc(hits);
  TestKit.Check(calls > TRIES div 2, 'most rolls are above 1');
  TestKit.CheckEqualsL(calls, hits, 'a penalty below 0 does not turn a hit into a miss');

  { and an effect that forces a miss still does, on any roll }
  forceMiss := True;
  hits := 0;
  for i := 1 to TRIES do
    if FxEngine.AttackRoll(att, def, 50) then
      Inc(hits);
  TestKit.CheckEqualsL(0, hits, 'a forced miss misses');
  hits := 0;
  for i := 1 to TRIES do
    if FxEngine.AttackRollNoAttacker(def, 59) then
      Inc(hits);
  TestKit.CheckEqualsL(0, hits, 'and misses a script attack too');

  { a script attack at THAC0 20 (60 - 20) against AC 10 hits on 10 or more, as a creature's does }
  forceMiss := False;
  def^.acCur := 50;
  att^.thac0Cur := 40;
  penalty := 0;
  bad := 0;
  for i := 1 to TRIES do begin
    natural := 1;
    if FxEngine.AttackRollNoAttacker(def, 40) <> (natural >= 10) then
      Inc(bad);
  end;
  TestKit.CheckEqualsL(0, bad, 'a script attack hits on THAC0 - AC');
  bad := 0;
  for i := 1 to TRIES do begin
    natural := 1;
    if FxEngine.AttackRoll(att, def, 50) <> (natural >= 10) then
      Inc(bad);
  end;
  TestKit.CheckEqualsL(0, bad, 'as a creature''s attack does');

  TestKit.CheckEqualsL(7, Reduced(9, 2, 1), '2d6 for 9 does 7 at 1 less per die');
  TestKit.CheckEqualsL(2, Reduced(3, 2, 1), 'but no die below 1');
  TestKit.CheckEqualsL(2, Reduced(9, 2, 4), 'however much comes off');
  TestKit.CheckEqualsL(1, Reduced(1, 2, 1), 'and damage below the dice count is left alone');
  TestKit.CheckEqualsL(5, Reduced(9, 2, 2), '2 less per die');
  TestKit.CheckEqualsL(200, Reduced(250, 25, 2), 'on many dice');
  TestKit.Done;
end.
