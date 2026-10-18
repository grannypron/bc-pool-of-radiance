{ Tests for FxEngine.RemoveEffect when the removed effect's own handler removes the node first, as Fight On's does
  (eff 95: the creature falls dead, and RemoveEffectsHp0 takes its 0-HP effects, Fight On among them). The outer
  removal must leave the freed node alone: it once walked off the list and wrote through nil, into the interrupt
  vectors, and freed the node twice. }
{$I COMPILER.INC}
program TFxRemov;

uses Types, C_Effect, GDVars, FxEngine, TestKit;

var
  c: Types.PCharRecord;
  first: Types.PEffectRec;
  second: Types.PEffectRec;
  vectors: array[0..3] of LongInt;
  before: LongInt;

{$F+}
{ A handler that removes its own effect, as EffFightOn does through InflictStatusMsg and RemoveEffectsHp0. }
procedure RemovesItself(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  FxEngine.RemoveEffect(creature, C_Effect.FIGHT_ON, nil);
end;
{$F-}

function NewEffect(id: Byte; next: Types.PEffectRec): Types.PEffectRec;
var
  e: Types.PEffectRec;
begin
  GetMem(e, SizeOf(Types.TEffectRec));
  FillChar(e^, SizeOf(Types.TEffectRec), 0);
  e^.id := id;
  e^.onRemove := True;
  e^.next := next;
  NewEffect := e;
end;

begin
  TestKit.Start('TFXREMOV');
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  GDVars.effectFns[C_Effect.FIGHT_ON] := RemovesItself;
  { Fight On second in the list, so the unlink would walk for it; the heap is measured before its node is made, so
    one free brings it back }
  first := NewEffect(C_Effect.BLESS, nil);
  first^.onRemove := False;
  before := MemAvail;
  second := NewEffect(C_Effect.FIGHT_ON, nil);
  first^.next := second;
  c^.effectsAddr := first;
  Move(Mem[0:0], vectors, SizeOf(vectors));
  FxEngine.RemoveEffect(c, C_Effect.FIGHT_ON, second);
  TestKit.Check((c^.effectsAddr = first) and (first^.next = nil), 'Fight On is gone and Bless is left');
  TestKit.Check((MemL[0:0] = vectors[0]) and (MemL[0:4] = vectors[1]) and (MemL[0:8] = vectors[2]) and
                (MemL[0:12] = vectors[3]), 'nothing is written into the interrupt vectors');
  TestKit.CheckEqualsL(before, MemAvail, 'the node is freed once');
  { and first in the list }
  second := NewEffect(C_Effect.FIGHT_ON, nil);
  c^.effectsAddr := second;
  FxEngine.RemoveEffect(c, C_Effect.FIGHT_ON, second);
  TestKit.Check(c^.effectsAddr = nil, 'alone in the list, it is gone too');
  TestKit.Done;
end.
