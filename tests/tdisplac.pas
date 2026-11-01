{ Tests for displacement (EffHndlr.EffDisplaced, eff 89): the first attack on the creature each combat misses,
  whatever the attack roll comes to, even a first-round roll modified to 0, which once cleared the displacement
  instead (#791); EffHndlr.ResetDisplacement makes it due again for the next combat. A Cloak of Displacement readied
  in combat (EffHndlr.EffReadyItem) displaces the next attack, rather than having its miss spent on the readying
  (#784). A natural 1, which misses on its own, is the first attack all the same and spends the displacement
  (FxEngine.SpendDisplacement, #1183). }
{$I COMPILER.INC}
program TDisplac;

uses Types, C_EFFECT, C_IFC, GameVars, CharHlp, FxEngine, EffHndlr, TestKit;

var
  att: Types.PCharRecord;
  def: Types.PCharRecord;
  rollTo: Integer;
  cloak: Types.TItemRec;
  hit: Boolean;
  effect: Types.PEffectRec;

{$F+}
{ The attacker's C_COND.ATTACK_ROLL_ATT effect: a roll above 1 becomes rollTo, as penalties or bonuses would make it. }
procedure SetRoll(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GameVars.gAttackRoll := rollTo;
end;
{$F-}

function NewCreature: Types.PCharRecord;
var
  c: Types.PCharRecord;
begin
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  NewCreature := c;
end;

{ True when an attack on def is displaced. A natural 1 misses before any effect runs, so it is rolled again, with the
  displacement it spent (#1183) put back. }
function Displaced: Boolean;
var
  before: Byte;
begin
  hit := CharHlp.HasEffect(def, C_EFFECT.DISPLACED, effect);
  before := effect^.strength;
  repeat
    effect^.strength := before;
    GameVars.gAttackRoll := 0;
    hit := FxEngine.AttackRoll(att, def, 0);
  until GameVars.gAttackRoll = rollTo;
  Displaced := GameVars.forcedMiss;
end;

begin
  TestKit.Start('TDISPLAC');
  GetMem(GameVars.zone1, SizeOf(GameVars.zone1^));
  FillChar(GameVars.zone1^, SizeOf(GameVars.zone1^), 0);
  GameVars.effectFns[C_EFFECT.BLESS] := SetRoll;
  GameVars.effectFns[C_EFFECT.DISPLACED] := EffHndlr.EffDisplaced;
  att := NewCreature;
  def := NewCreature;
  FxEngine.AddEffect(att, C_EFFECT.BLESS, 0, 0, False);
  FxEngine.AddEffect(def, C_EFFECT.DISPLACED, 0, 12, False);
  GameVars.roundCounter := 0;

  rollTo := 10;
  TestKit.Check(Displaced, 'the first attack is displaced');
  TestKit.Check(not Displaced, 'the second is not');
  TestKit.Check(not Displaced, 'nor the third');
  EffHndlr.ResetDisplacement(def);
  TestKit.Check(Displaced, 'in the next combat the first attack is displaced again');

  { a first-round attack modified to exactly 0 (#791) }
  EffHndlr.ResetDisplacement(def);
  rollTo := 0;
  TestKit.Check(Displaced, 'a first-round roll of 0 is displaced');
  TestKit.Check(not Displaced, 'and has not made the displacement due again');

  { a natural 1 as the first attack (#1183) }
  repeat
    EffHndlr.ResetDisplacement(def);
    hit := FxEngine.AttackRoll(att, def, 0);
  until GameVars.gAttackRoll = 1;
  TestKit.Check(not hit and not GameVars.forcedMiss, 'a natural 1 misses without the displacement');
  rollTo := 10;
  TestKit.Check(not Displaced, 'but spends it: the next attack is not displaced');
  EffHndlr.ResetDisplacement(def);
  TestKit.Check(Displaced, 'and the next combat makes it due again');

  { a cloak readied in combat (#784) }
  FxEngine.RemoveEffect(def, C_EFFECT.DISPLACED, nil);
  GameVars.ifcState := C_IFC.IN_COMBAT;
  GameVars.roundCounter := 3;
  FillChar(cloak, SizeOf(cloak), 0);
  cloak.effect := C_EFFECT.DISPLACED;
  EffHndlr.EffReadyItem(def, @cloak, False);
  rollTo := 10;
  TestKit.Check(Displaced, 'a cloak readied in combat displaces the next attack');
  TestKit.Check(not Displaced, 'and that one only');
  TestKit.Done;
end.
