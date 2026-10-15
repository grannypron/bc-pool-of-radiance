{ Tests for Stats (#611): party membership, saturation, kills by kind, damage, healing and net coin. }
program TStats;

uses Types, GDVars, C_Gbvm, C_Status, C_Ifc, C_Money, Stats, TestKit;

var
  a: Types.PCharRecord;
  b: Types.PCharRecord;
  monster: Types.PCharRecord;
  blk: Stats.PStatBlock;
  i: Byte;
  s: String;

function NewCreature(name: String; next: Types.PCharRecord): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  GetMem(p, SizeOf(Types.TCharRecord));
  FillChar(p^, SizeOf(Types.TCharRecord), 0);
  p^.name := name;
  p^.status := C_Status.OKAY;
  p^.nextCharAddr := next;
  NewCreature := p;
end;

begin
  TestKit.Start('TSTATS');
  GetMem(GDVars.zone1, SizeOf(Types.TGbvmZone1));
  FillChar(GDVars.zone1^, SizeOf(Types.TGbvmZone1), 0);
  { a party of two, then a monster after them, as combat appends monsters }
  monster := NewCreature('KOBOLD', nil);
  b := NewCreature('ANNA', monster);
  a := NewCreature('TALONIA', b);
  GDVars.creatureList := a;
  GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 2;

  TestKit.Check(Stats.IsPartyMember(a), 'first member is in the party');
  TestKit.Check(Stats.IsPartyMember(b), 'second member is in the party');
  TestKit.Check(not Stats.IsPartyMember(monster), 'a monster after PARTY_SIZE is not');
  TestKit.Check(not Stats.IsPartyMember(nil), 'nil is not');
  TestKit.Check(Stats.BlockOf(monster) = nil, 'a monster has no block');

  { saturation }
  Stats.Count(a, Stats.SPELLS_CAST, MaxLongInt - 1);
  Stats.Count(a, Stats.SPELLS_CAST, 5);
  TestKit.CheckEqualsL(MaxLongInt, Stats.BlockOf(a)^.counts[Stats.SPELLS_CAST], 'a counter stops at MaxLongInt');
  Stats.Count(a, Stats.RAISED, -3);
  TestKit.CheckEqualsL(0, Stats.BlockOf(a)^.counts[Stats.RAISED], 'Count ignores a negative amount');
  Stats.Count(monster, Stats.RAISED, 1);
  TestKit.CheckEqualsL(0, Stats.game.counts[Stats.RAISED], 'a monster''s count reaches neither block nor game');

  { a party member fells a monster in combat }
  GDVars.ifcState := C_Ifc.COMBAT;
  monster^.status := C_Status.DYING;
  Stats.Damaged(a, monster, 7, True);
  blk := Stats.BlockOf(a);
  TestKit.CheckEqualsL(7, blk^.counts[Stats.DAMAGE_DONE], 'damage done');
  TestKit.CheckEqualsL(1, blk^.counts[Stats.KILLS], 'a fall counts as a kill');
  TestKit.CheckEqualsL(1, blk^.kindCount, 'one kind killed');
  TestKit.CheckEqualsS('KOBOLD', blk^.kills[1].name, 'the kind is the victim''s name');
  TestKit.CheckEqualsL(1, Stats.game.counts[Stats.KILLS], 'the game counts the kill');
  { a second blow on the fallen monster is damage, not another kill }
  Stats.Damaged(a, monster, 2, False);
  TestKit.CheckEqualsL(1, blk^.counts[Stats.KILLS], 'no kill for a creature already down');
  TestKit.CheckEqualsL(9, blk^.counts[Stats.DAMAGE_DONE], 'damage on a fallen creature still counts');
  { outside combat a party member's blow is not credited }
  GDVars.ifcState := C_Ifc.INDOORS;
  Stats.Damaged(a, monster, 4, False);
  TestKit.CheckEqualsL(9, blk^.counts[Stats.DAMAGE_DONE], 'no damage done outside combat');

  { a party member is hurt, knocked down, killed }
  b^.status := C_Status.DEAD;
  Stats.Damaged(monster, b, 12, True);
  blk := Stats.BlockOf(b);
  TestKit.CheckEqualsL(12, blk^.counts[Stats.DAMAGE_TAKEN], 'damage taken');
  TestKit.CheckEqualsL(1, blk^.counts[Stats.KNOCKED_DOWN], 'knocked down');
  TestKit.CheckEqualsL(1, blk^.counts[Stats.DIED], 'died');

  { kinds past the table go under OTHER }
  GDVars.ifcState := C_Ifc.COMBAT;
  for i := 1 to Stats.KINDS + 2 do begin
    Str(i, s);
    monster^.name := 'BEAST' + s;
    monster^.status := C_Status.DEAD;
    Stats.Damaged(a, monster, 1, True);
  end;
  blk := Stats.BlockOf(a);
  TestKit.CheckEqualsL(Stats.KINDS, blk^.kindCount, 'the kinds fill the table');
  TestKit.CheckEqualsS('OTHER', blk^.kills[Stats.KINDS].name, 'the last slot is OTHER');
  { KOBOLD took slot 1, so BEAST1..BEAST46 fill slots 2..47 and BEAST47..BEAST50 go under OTHER }
  TestKit.CheckEqualsL(4, blk^.kills[Stats.KINDS].count, 'OTHER counts every kind past the table');

  { healing given counts only while a spell is resolved }
  GDVars.dsCurrentSpellBeing := 0;
  Stats.Healed(a, b, 5, False);
  TestKit.CheckEqualsL(5, Stats.BlockOf(b)^.counts[Stats.HEALED_TAKEN], 'healing taken');
  TestKit.CheckEqualsL(0, Stats.BlockOf(a)^.counts[Stats.HEALED_GIVEN], 'no healing given without a spell');
  GDVars.dsCurrentSpellBeing := 3;
  Stats.Healed(a, b, 4, False);
  TestKit.CheckEqualsL(4, Stats.BlockOf(a)^.counts[Stats.HEALED_GIVEN], 'healing given by a spell');
  GDVars.dsCurrentSpellBeing := 0;
  Stats.Healed(a, b, 2, True);
  TestKit.CheckEqualsL(6, Stats.BlockOf(a)^.counts[Stats.HEALED_GIVEN], 'healing given by a power');

  { net coin: what each member comes away with, up or down }
  a^.coins[C_Money.GOLD] := 10;
  b^.coins[C_Money.SILVER] := 50;
  Stats.MarkCoins;
  a^.coins[C_Money.GOLD] := 15;
  b^.coins[C_Money.SILVER] := 0;
  Stats.SettleCoins;
  TestKit.CheckEqualsL(1000, Stats.BlockOf(a)^.counts[Stats.COIN_LOOTED], 'coin taken, in copper');
  TestKit.CheckEqualsL(-500, Stats.BlockOf(b)^.counts[Stats.COIN_LOOTED], 'coin pooled, below zero');
  TestKit.CheckEqualsL(500, Stats.game.counts[Stats.COIN_LOOTED], 'the game''s net coin');

  { a freed creature's block is forgotten; one with the same record starts empty }
  Stats.Forget(a);
  TestKit.CheckEqualsL(0, Stats.BlockOf(a)^.counts[Stats.KILLS], 'a forgotten member starts again from none');

  Stats.ResetGame;
  TestKit.CheckEqualsL(0, Stats.game.counts[Stats.KILLS], 'ResetGame clears the game');
  TestKit.Done;
end.
