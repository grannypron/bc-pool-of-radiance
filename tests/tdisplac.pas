{ Tests for displacement (EffHndlr.EffDisplaced, eff 89): the first attack on the creature each combat misses,
  whatever the attack roll comes to, even a first-round roll modified to 0, which once cleared the displacement
  instead (#791); EffHndlr.ResetDisplacement makes it due again for the next combat. A Cloak of Displacement readied
  in combat (EffHndlr.EffReadyItem) displaces the next attack, rather than having its miss spent on the readying
  (#784). }
{$I COMPILER.INC}
program TDisplac;

uses Types, C_Effect, C_Ifc, GDVars, FxEngine, EffHndlr, TestKit;

var
  att: Types.PCharRecord;
  def: Types.PCharRecord;
  rollTo: Integer;
  cloak: Types.TItemRec;
  hit: Boolean;

{$F+}
{ The attacker's C_Cond.ATTACK_ROLL_ATT effect: a roll above 1 becomes rollTo, as penalties or bonuses would make it. }
procedure SetRoll(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.gAttackRoll := rollTo;
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

{ True when an attack on def is displaced. A natural 1 misses before any effect runs, so it is rolled again. }
function Displaced: Boolean;
begin
  repeat
    GDVars.gAttackRoll := 0;
    hit := FxEngine.AttackRoll(att, def, 0);
  until GDVars.gAttackRoll = rollTo;
  Displaced := GDVars.gAttackAvoided;
end;

begin
  TestKit.Start('TDISPLAC');
  GetMem(GDVars.zone1, SizeOf(GDVars.zone1^));
  FillChar(GDVars.zone1^, SizeOf(GDVars.zone1^), 0);
  GDVars.effectFns[C_Effect.BLESS] := SetRoll;
  GDVars.effectFns[C_Effect.DISPLACED] := EffHndlr.EffDisplaced;
  att := NewCreature;
  def := NewCreature;
  FxEngine.AddEffect(att, C_Effect.BLESS, 0, 0, False);
  FxEngine.AddEffect(def, C_Effect.DISPLACED, 0, 12, False);
  GDVars.roundCounter := 0;

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

  { a cloak readied in combat (#784) }
  FxEngine.RemoveEffect(def, C_Effect.DISPLACED, nil);
  GDVars.ifcState := C_Ifc.COMBAT;
  GDVars.roundCounter := 3;
  FillChar(cloak, SizeOf(cloak), 0);
  cloak.effect := C_Effect.DISPLACED;
  EffHndlr.EffReadyItem(def, @cloak, False);
  rollTo := 10;
  TestKit.Check(Displaced, 'a cloak readied in combat displaces the next attack');
  TestKit.Check(not Displaced, 'and that one only');
  TestKit.Done;
end.
