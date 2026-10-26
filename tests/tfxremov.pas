{ Tests for FxEngine.RemoveEffect when the removed effect's own handler removes the node first, as Fight On's does
  (eff 95: the creature falls dead, and RemoveEffectsHp0 takes its 0-HP effects, Fight On among them). The outer
  removal must leave the freed node alone: it once walked off the list and wrote through nil, into the interrupt
  vectors, and freed the node twice. And for FxEngine.HoldTarget, which lets a hold go once its victim is free,
  FxEngine.HasEffectNode, FxEngine.EffectImmune, and the Strength a disease takes (CharHlp.DiseaseStrLoss,
  AdjustForNewStrength). And the one cure of disease (FxEngine.RemoveDiseases, HasDisease, #922) and what Friends
  gives back as it ends (FxEngine.FriendsEndCha, #920). }
{$I COMPILER.INC}
program TFxRemov;

uses Types, C_EFFECT, GameVars, CharHlp, AbilAdj, FxEngine, TestKit;

{ The heap's free bytes. Natively MemAvail is a fixed figure (TpCompat), so the heap's used bytes count instead. }
function HeapFree: LongInt;
begin
{$IFDEF FPC}
  HeapFree := -LongInt(GetFPCHeapStatus.CurrHeapUsed);
{$ELSE}
  HeapFree := MemAvail;
{$ENDIF}
end;

var
  c: Types.PCharRecord;
  first: Types.PEffectRec;
  second: Types.PEffectRec;
  vectors: array[0..3] of LongInt;
  before: LongInt;
  victim: Types.PCharRecord;
  hold: Types.PEffectRec;
  released: Boolean;
  enc: Byte;

{$F+}
{ A handler that removes its own effect, as EffFightOn does through InflictStatusMsg and RemoveEffectsHp0. }
procedure RemovesItself(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  FxEngine.RemoveEffect(creature, C_EFFECT.FIGHT_ON, nil);
end;

{ A paralysis ward, as EffNoParalysis is (eff 109): it refuses paralysis under the immunity check. }
procedure WardsParalysis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GameVars.pendingEffectId = C_EFFECT.PARALYZED then
    GameVars.pendingEffectId := 0;
end;
{$F-}

{ Give c a list of quiet nodes (no handler on removal) of the ids in ids, in order. }
procedure SetEffects(ids: String);
var
  i: Byte;
  e: Types.PEffectRec;
begin
  c^.effectsAddr := nil;
  for i := Length(ids) downto 1 do begin
    GetMem(e, SizeOf(Types.TEffectRec));
    FillChar(e^, SizeOf(Types.TEffectRec), 0);
    e^.id := Ord(ids[i]);
    e^.next := c^.effectsAddr;
    c^.effectsAddr := e;
  end;
end;

{ The ids left on c, in order. }
function EffectIds: String;
var
  s: String;
  e: Types.PEffectRec;
begin
  s := '';
  e := c^.effectsAddr;
  while e <> nil do begin
    s := s + Chr(e^.id);
    e := e^.next;
  end;
  EffectIds := s;
end;

{ The ids as numbers, for a failed check's message. }
function IdList(ids: String): String;
var
  s: String;
  n: String[3];
  i: Byte;
begin
  s := '';
  for i := 1 to Length(ids) do begin
    Str(Ord(ids[i]), n);
    s := s + ' ' + n;
  end;
  IdList := s;
end;

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
  GameVars.effectFns[C_EFFECT.FIGHT_ON] := RemovesItself;
  { Fight On second in the list, so the unlink would walk for it; the heap is measured before its node is made, so
    one free brings it back }
  first := NewEffect(C_EFFECT.BLESS, nil);
  first^.onRemove := False;
  before := HeapFree;
  second := NewEffect(C_EFFECT.FIGHT_ON, nil);
  first^.next := second;
  c^.effectsAddr := first;
{$IFNDEF FPC}
  Move(Mem[0:0], vectors, SizeOf(vectors));
{$ENDIF}
  FxEngine.RemoveEffect(c, C_EFFECT.FIGHT_ON, second);
  TestKit.Check((c^.effectsAddr = first) and (first^.next = nil), 'Fight On is gone and Bless is left');
{$IFNDEF FPC}
  { a native program has no interrupt vectors at address 0 }
  TestKit.Check((MemL[0:0] = vectors[0]) and (MemL[0:4] = vectors[1]) and (MemL[0:8] = vectors[2]) and
                (MemL[0:12] = vectors[3]), 'nothing is written into the interrupt vectors');
{$ENDIF}
  TestKit.CheckEqualsL(before, HeapFree, 'the node is freed once');
  { and first in the list }
  second := NewEffect(C_EFFECT.FIGHT_ON, nil);
  c^.effectsAddr := second;
  FxEngine.RemoveEffect(c, C_EFFECT.FIGHT_ON, second);
  TestKit.Check(c^.effectsAddr = nil, 'alone in the list, it is gone too');

  { a bite-and-hold on creature 1 of the arena: it lasts while the victim is immobile, and goes once the victim is
    not, rather than biting a victim that broke free (#709) }
  GetMem(victim, SizeOf(Types.TCharRecord));
  FillChar(victim^, SizeOf(Types.TCharRecord), 0);
  victim^.enabled := 1;
  c^.enabled := 1;
  GameVars.arenaCount := 1;
  GameVars.creatureArr[1] := victim;
  victim^.effectsAddr := NewEffect(C_EFFECT.IMMOBILE, nil);
  victim^.effectsAddr^.onRemove := False;
  hold := NewEffect(C_EFFECT.BITE_HOLD, nil);
  hold^.strength := 1;
  hold^.onRemove := False;
  c^.effectsAddr := hold;
  TestKit.Check(FxEngine.HoldTarget(c, hold, False, C_EFFECT.BITE_HOLD, released) = victim,
                'a hold on an immobile victim lasts');
  TestKit.Check(not released and (c^.effectsAddr = hold), 'and is kept');
  FreeMem(victim^.effectsAddr, SizeOf(Types.TEffectRec));
  victim^.effectsAddr := nil;
  TestKit.Check(FxEngine.HoldTarget(c, hold, False, C_EFFECT.BITE_HOLD, released) = nil,
                'a victim no longer immobile is not held');
  TestKit.Check(released and (c^.effectsAddr = nil), 'and the hold is released and removed');
  { HasEffectNode, which Dispel Magic's walk asks after each removal (#763) }
  first := NewEffect(C_EFFECT.BLESS, nil);
  second := NewEffect(C_EFFECT.FIGHT_ON, nil);
  first^.next := second;
  c^.effectsAddr := first;
  TestKit.Check(FxEngine.HasEffectNode(c, first) and FxEngine.HasEffectNode(c, second),
                'both nodes of the list are found');
  first^.next := nil;
  TestKit.Check(not FxEngine.HasEffectNode(c, second), 'a node taken out of the list is not');
  TestKit.Check(not FxEngine.HasEffectNode(c, nil), 'nor is nil');
  FreeMem(first, SizeOf(Types.TEffectRec));
  FreeMem(second, SizeOf(Types.TEffectRec));
  c^.effectsAddr := nil;

  { EffectImmune, the immunity check a paralyzing or poisonous touch now makes too (#767, #720): a ward refuses its
    effect and lets others through }
  GameVars.effectFns[C_EFFECT.NO_PARALYSIS] := WardsParalysis;
  c^.effectsAddr := NewEffect(C_EFFECT.NO_PARALYSIS, nil);
  TestKit.Check(FxEngine.EffectImmune(c, C_EFFECT.PARALYZED), 'a paralysis ward refuses paralysis');
  TestKit.Check(not FxEngine.EffectImmune(c, C_EFFECT.POISONED), 'but not poison');
  FreeMem(c^.effectsAddr, SizeOf(Types.TEffectRec));
  c^.effectsAddr := nil;
  TestKit.Check(not FxEngine.EffectImmune(c, C_EFFECT.PARALYZED), 'with no ward, paralysis is not refused');

  { a disease that has taken 3 Strength from 18/76 (#705): its node counts the loss, a Strength effect stores the
    creature's own Strength with the loss given back, and sets the new one less the loss }
  c^.strCur := 15;
  c^.strExc := 76;
  c^.effectsAddr := NewEffect(C_EFFECT.DISEASE_STRENGTH, nil);
  c^.effectsAddr^.strength := 3 * 16 + 5;
  TestKit.CheckEqualsL(3, CharHlp.DiseaseStrLoss(c), 'the disease has taken 3 Strength');
  TestKit.Check(not FxEngine.AdjustForNewStrength(c, 17, 0, enc), '17 is weaker than the 18/76 under the disease');
  TestKit.CheckEqualsL(15, c^.strCur, 'and changes nothing');
  TestKit.Check(FxEngine.AdjustForNewStrength(c, 18, 100, enc), '18/00 is stronger');
  TestKit.CheckEqualsL(AbilAdj.StrengthModifier(18, 76), enc, 'the Strength to restore is 18/76, the loss given back');
  TestKit.CheckEqualsL(15, c^.strCur, '18/00 less the 3 lost is 15');
  TestKit.CheckEqualsL(100, c^.strExc, 'kept as 18/00 for the cure');
  c^.effectsAddr^.strength := 5;
  TestKit.CheckEqualsL(0, CharHlp.DiseaseStrLoss(c), 'a disease that has taken nothing yet');
  FreeMem(c^.effectsAddr, SizeOf(Types.TEffectRec));
  c^.effectsAddr := nil;
  TestKit.CheckEqualsL(0, CharHlp.DiseaseStrLoss(c), 'no disease, no loss');

  { the one cure of disease (#922): the Strength drain takes its hit-point drain and helplessness with it, rot takes
    mummy rot, a stray hit-point drain or mummy rot goes, and helplessness alone (a Stinking Cloud's nausea) stays }
  SetEffects(Chr(C_EFFECT.BLESS) + Chr(C_EFFECT.DISEASE_STRENGTH) + Chr(C_EFFECT.DISEASE_HIT_POINTS) +
             Chr(C_EFFECT.HELPLESS) + Chr(C_EFFECT.DISEASED));
  TestKit.Check(FxEngine.HasDisease(c), 'the Strength drain is a disease');
  TestKit.Check(FxEngine.RemoveDiseases(c), 'and is cured');
  TestKit.CheckEqualsS(IdList(Chr(C_EFFECT.BLESS)), IdList(EffectIds), 'with its drains and helplessness');
  SetEffects(Chr(C_EFFECT.HELPLESS) + Chr(C_EFFECT.ROT_NO_HEAL) + Chr(C_EFFECT.MUMMY_ROT));
  TestKit.Check(FxEngine.RemoveDiseases(c), 'rot is cured');
  TestKit.CheckEqualsS(IdList(Chr(C_EFFECT.HELPLESS)), IdList(EffectIds),
                       'with mummy rot, and a cloud''s helplessness stays');
  TestKit.Check(not FxEngine.HasDisease(c), 'helplessness alone is no disease');
  TestKit.Check(not FxEngine.RemoveDiseases(c), 'and nothing is cured');
  TestKit.CheckEqualsS(IdList(Chr(C_EFFECT.HELPLESS)), IdList(EffectIds), 'it is left');
  SetEffects(Chr(C_EFFECT.DISEASE_HIT_POINTS) + Chr(C_EFFECT.MUMMY_ROT));
  TestKit.Check(FxEngine.HasDisease(c), 'a stray drain is a disease');
  TestKit.Check(FxEngine.RemoveDiseases(c) and (c^.effectsAddr = nil), 'a stray drain and mummy rot are cured');
  TestKit.CheckEqualsL(0, GameVars.effectLock, 'the effect lock is let go');

  { Friends gives back what it gave (#920): 10 + 5 = 15, + 3 = 18; the first ends, 13; the second, 10 }
  TestKit.CheckEqualsL(13, FxEngine.FriendsEndCha(18, C_EFFECT.FRIENDS_BONUS or 5), 'the first Friends takes its 5');
  TestKit.CheckEqualsL(10, FxEngine.FriendsEndCha(13, C_EFFECT.FRIENDS_BONUS or 3), 'the second its 3: no gain');
  TestKit.CheckEqualsL(11, FxEngine.FriendsEndCha(13, C_EFFECT.FRIENDS_BONUS or 2),
                       'Charisma lost while it lasted stays lost');
  TestKit.CheckEqualsL(3, FxEngine.FriendsEndCha(4, C_EFFECT.FRIENDS_BONUS or 8), 'never below 3');
  TestKit.CheckEqualsL(12, FxEngine.FriendsEndCha(20, 12), 'one saved before #920 restores its stored Charisma');
  TestKit.Done;
end.
