{ Tests for FxEngine.FreeCloudNumber (#761): each of a caster's stinking clouds gets its own number, the list's last
  node counted too, so ending one cloud clears that cloud and not an older one. And for FxEngine.CloudStrength (#762): a
  caster level above 15 does not carry into the cloud's number. And who a cloud cannot touch (CloudProof) or does
  nothing to now (CloudSpares), which ConsiderStinkingCloud and CombatAi share. }
{$I COMPILER.INC}
program TClouds;

uses Types, C_EFFECT, GameVars, FxEngine, TestKit;

var
  a: Types.PCharRecord;
  b: Types.PCharRecord;

{ Append a cloud of caster cr numbered idx to the stinkHead list. }
procedure AddCloud(cr: Types.PCharRecord; idx: Byte);
var
  node: Types.PStinkRec;
  tail: Types.PStinkRec;
begin
  GetMem(node, SizeOf(Types.TStinkRec));
  FillChar(node^, SizeOf(Types.TStinkRec), 0);
  node^.caster := cr;
  node^.idx := idx;
  if GameVars.stinkHead = nil then
    GameVars.stinkHead := node
  else begin
    tail := GameVars.stinkHead;
    while tail^.next <> nil do
      tail := tail^.next;
    tail^.next := node;
  end;
end;

procedure FreeClouds;
var
  node: Types.PStinkRec;
begin
  while GameVars.stinkHead <> nil do begin
    node := GameVars.stinkHead^.next;
    FreeMem(GameVars.stinkHead, SizeOf(Types.TStinkRec));
    GameVars.stinkHead := node;
  end;
end;

{ CloudProof and CloudSpares for b with effect id alone (0: none). }
procedure CheckSpared(id: Byte; proof, spares: Boolean; what: String);
var
  e: Types.TEffectRec;
begin
  FillChar(e, SizeOf(e), 0);
  e.id := id;
  if id = 0 then
    b^.effectsAddr := nil
  else
    b^.effectsAddr := @e;
  TestKit.Check(FxEngine.CloudProof(b) = proof, what + ': proof');
  TestKit.Check(FxEngine.CloudSpares(b) = spares, what + ': spared');
  b^.effectsAddr := nil;
end;

var
  i: Byte;

begin
  TestKit.Start('TCLOUDS');
  GetMem(a, SizeOf(Types.TCharRecord));
  GetMem(b, SizeOf(Types.TCharRecord));
  GameVars.stinkHead := nil;
  TestKit.CheckEqualsL(0, FxEngine.FreeCloudNumber(a), 'no clouds: number 0');
  AddCloud(a, 0);
  TestKit.CheckEqualsL(1, FxEngine.FreeCloudNumber(a), 'the caster''s one cloud, the list''s last node, is counted');
  TestKit.CheckEqualsL(0, FxEngine.FreeCloudNumber(b), 'another caster''s cloud is not');
  AddCloud(b, 0);
  AddCloud(a, 1);
  TestKit.CheckEqualsL(2, FxEngine.FreeCloudNumber(a), 'two clouds of the caster: number 2');
  FreeClouds;
  AddCloud(a, 1);
  TestKit.CheckEqualsL(0, FxEngine.FreeCloudNumber(a), 'cloud 0 has ended: its number is free again');
  AddCloud(a, 0);
  TestKit.CheckEqualsL(2, FxEngine.FreeCloudNumber(a), 'numbers 1 and 0 taken, in either order: number 2');
  FreeClouds;
  for i := 0 to 15 do
    AddCloud(a, i);
  TestKit.CheckEqualsL(15, FxEngine.FreeCloudNumber(a), 'never above 15, the most the strength''s high nibble holds');
  FreeClouds;
  TestKit.CheckEqualsL(9 + 2 * 16, FxEngine.CloudStrength(9, 2), 'level 9, cloud 2');
  TestKit.CheckEqualsL(15 + 2 * 16, FxEngine.CloudStrength(15, 2), 'level 15 still fits the low nibble');
  TestKit.CheckEqualsL(2, FxEngine.CloudStrength(16, 2) div 16, 'level 16 leaves the number 2');
  TestKit.CheckEqualsL(15, FxEngine.CloudStrength(20, 0) and $F, 'level 20 is stored as 15');
  TestKit.CheckEqualsL(15 + 15 * 16, FxEngine.CloudStrength(255, 15), 'level 255, cloud 15: no wrap');
  FillChar(b^, SizeOf(Types.TCharRecord), 0);
  b^.enabled := 1;
  CheckSpared(0, False, False, 'a plain creature');
  CheckSpared(C_EFFECT.ANIMATE_DEAD, True, True, 'animated dead');
  CheckSpared(C_EFFECT.STINKING_CLOUD_COUGH, True, True, 'one coughing already');
  CheckSpared(C_EFFECT.NO_PARA_POISON, True, True, 'one immune to paralysis and poison');
  CheckSpared(C_EFFECT.NO_CHARM_POISON, True, True, 'one immune to charm and poison');
  CheckSpared(C_EFFECT.HELPLESS, False, True, 'one nauseated already, who may still walk in');
  b^.enabled := 0;
  CheckSpared(0, False, True, 'a disabled creature');
  FreeMem(a, SizeOf(Types.TCharRecord));
  FreeMem(b, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.
