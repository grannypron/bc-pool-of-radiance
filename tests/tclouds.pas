{ Tests for FxEngine.FreeCloudNumber (#761): each of a caster's stinking clouds gets its own number, the list's last
  node counted too, so ending one cloud clears that cloud and not an older one. }
{$I COMPILER.INC}
program TClouds;

uses Types, GDVars, FxEngine, TestKit;

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
  if GDVars.stinkHead = nil then
    GDVars.stinkHead := node
  else begin
    tail := GDVars.stinkHead;
    while tail^.next <> nil do
      tail := tail^.next;
    tail^.next := node;
  end;
end;

procedure FreeClouds;
var
  node: Types.PStinkRec;
begin
  while GDVars.stinkHead <> nil do begin
    node := GDVars.stinkHead^.next;
    FreeMem(GDVars.stinkHead, SizeOf(Types.TStinkRec));
    GDVars.stinkHead := node;
  end;
end;

var
  i: Byte;

begin
  TestKit.Start('TCLOUDS');
  GetMem(a, SizeOf(Types.TCharRecord));
  GetMem(b, SizeOf(Types.TCharRecord));
  GDVars.stinkHead := nil;
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
  FreeMem(a, SizeOf(Types.TCharRecord));
  FreeMem(b, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.
