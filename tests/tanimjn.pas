{ Tests the animated dead joining the party after a won fight (#1089): PostCbt.PostCombatCreatureCleanup keeps a
  monster Animate Dead raised on the party's side, out of the list, its combat record freed, its effect's stored side
  the party's and its mark set, while the party has room, and removes it with the other monsters after a fight not won
  or with a full party; the Dispel Magic that ends the spell then leaves it on the party's side
  (EffHndlr.EffAnimateDead). And who slips away at a rest once raised (CharExt.SlipsAway), and an NPC a paladin led
  given back to the computer (#1124). }
{$I COMPILER.INC}
program TAnimJn;

uses Types, GameVars, C_GBVM, C_STATUS, C_EFFECT, C_NPC, CharHlp, CharExt, EffHndlr, PostCbt, TestKit;

var
  pc1, pc2, zombie, orc: Types.PCharRecord;
  risen: PostCbt.TRisen;
  effect: Types.PEffectRec;

function NewCreature(name: String; monster: Boolean): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  GetMem(p, SizeOf(Types.TCharRecord));
  FillChar(p^, SizeOf(Types.TCharRecord), 0);
  p^.name := name;
  p^.enabled := 1;
  p^.hpMax := 10;
  p^.hpCur := 10;
  GetMem(p^.combatAddr, SizeOf(Types.TCombatRec));
  FillChar(p^.combatAddr^, SizeOf(Types.TCombatRec), 0);
  if monster then
    p^.combatAddr^.notPcNpc := 1;
  NewCreature := p;
end;

{ A fresh fight's list: two party members, a corpse the party's cleric animated (side 1 in the effect, the monster's
  old side, at caster level 5) and a live orc. }
procedure Fight(partySize: Byte);
var
  e: Types.PEffectRec;
begin
  pc1 := NewCreature('ALIAS', False);
  pc2 := NewCreature('BRAND', False);
  zombie := NewCreature('THUG', True);
  zombie^.status := C_STATUS.ANIMATED;
  zombie^.hostile := 0;
  zombie^.quickfight := 1;
  zombie^.npc := C_NPC.ANIMATED_NPC;
  GetMem(e, SizeOf(Types.TEffectRec));
  FillChar(e^, SizeOf(Types.TEffectRec), 0);
  e^.id := C_EFFECT.ANIMATE_DEAD;
  e^.strength := 1 * 16 + 5;
  zombie^.effectsAddr := e;
  orc := NewCreature('ORC', True);
  orc^.hostile := 1;
  GameVars.creatureList := pc1;
  pc1^.nextCharAddr := pc2;
  pc2^.nextCharAddr := zombie;
  zombie^.nextCharAddr := orc;
  GameVars.zone1^[C_GBVM.PARTY_SIZE] := partySize;
end;

function ListLength: Integer;
var
  p: Types.PCharRecord;
  n: Integer;
begin
  n := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    Inc(n);
    p := p^.nextCharAddr;
  end;
  ListLength := n;
end;

begin
  TestKit.Start('TANIMJN');
  GetMem(GameVars.zone1, SizeOf(GameVars.zone1^));
  FillChar(GameVars.zone1^, SizeOf(GameVars.zone1^), 0);

  { a won fight }
  Fight(2);
  PostCbt.PostCombatCreatureCleanup(True, risen);
  TestKit.CheckEqualsL(1, risen.keptCount, 'the party''s zombie is kept');
  TestKit.Check(risen.kept[1] = zombie, 'that one');
  TestKit.CheckEqualsL(0, risen.lostCount, 'none lost');
  TestKit.CheckEqualsL(2, ListLength, 'the list holds the party alone: the orc is gone and the zombie out, to join');
  TestKit.Check(pc2^.nextCharAddr = nil, 'the zombie is out of the list');
  TestKit.Check(zombie^.combatAddr = nil, 'its combat record freed');
  TestKit.Check(pc1^.combatAddr = nil, 'as the party''s are');
  TestKit.Check(CharHlp.HasEffect(zombie, C_EFFECT.ANIMATE_DEAD, effect), 'it is animated still');
  TestKit.CheckEqualsL(5, effect^.strength, 'its effect''s side the party''s, the caster level kept');
  TestKit.CheckEqualsL(CharExt.EXT_ANIMATE_JOINED, zombie^.portExt.flags, 'and it is marked');
  TestKit.CheckEqualsL(2, GameVars.zone1^[C_GBVM.PARTY_SIZE], 'the party size is JoinParty''s to raise');
  { Dispel Magic ends the spell on the new member }
  GameVars.effectLock := 1;
  EffHndlr.EffAnimateDead(zombie, effect, True);
  GameVars.effectLock := 0;
  TestKit.CheckEqualsL(0, zombie^.hostile, 'the spell ended, it stays on the party''s side');

  { raised by the temple, it slips away at the next rest }
  zombie^.status := C_STATUS.OKAY;
  TestKit.Check(CharExt.SlipsAway(zombie), 'raised, it slips away');
  zombie^.status := C_STATUS.ANIMATED;
  TestKit.Check(not CharExt.SlipsAway(zombie), 'animated, it stays');
  zombie^.status := C_STATUS.DEAD_STATUS;
  TestKit.Check(not CharExt.SlipsAway(zombie), 'and dead it stays, a corpse');
  pc1^.status := C_STATUS.OKAY;
  TestKit.Check(not CharExt.SlipsAway(pc1), 'a character the party made never slips away');

  { a full party, and a fight not won }
  Fight(8);
  PostCbt.PostCombatCreatureCleanup(True, risen);
  TestKit.CheckEqualsL(0, risen.keptCount, 'with eight in the party none is kept');
  TestKit.CheckEqualsL(1, risen.lostCount, 'and the zombie is lost');
  TestKit.CheckEqualsS('THUG', risen.lost[1], 'by name');
  TestKit.CheckEqualsL(2, ListLength, 'removed with the orc');
  Fight(2);
  PostCbt.PostCombatCreatureCleanup(False, risen);
  TestKit.Check((risen.keptCount = 0) and (risen.lostCount = 0), 'a fight not won (fled) keeps and names none');
  TestKit.CheckEqualsL(2, ListLength, 'and removes it with the orc');
  Fight(2);
  zombie^.hostile := 1;
  PostCbt.PostCombatCreatureCleanup(True, risen);
  TestKit.CheckEqualsL(0, risen.keptCount, 'a corpse the enemy animated is no member');

  { an NPC a paladin led goes back under the computer's control after the fight; one a script gave the player stays
    under the player's (#1124) }
  Fight(2);
  pc1^.npc := C_NPC.FLAG;
  pc2^.npc := C_NPC.FLAG;
  pc1^.combatAddr^.led := 1;
  PostCbt.PostCombatCreatureCleanup(True, risen);
  TestKit.CheckEqualsL(1, pc1^.quickfight, 'the led NPC is the computer''s again');
  TestKit.CheckEqualsL(0, pc2^.quickfight, 'the NPC the player had before the fight is still the player''s');
  TestKit.Done;
end.
