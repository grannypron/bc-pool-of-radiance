{ Tests for MoneyCal: coin values, making change, who pays, item values and sale prices, money type names and temple
  prices. }
{$I COMPILER.INC}
program TMoneyCa;

uses Types, GDVars, C_Money, MoneyCal, TestKit;

var
  c: Types.PCharRecord;
  item: Types.PItemRec;
  m: Types.TMoney;
  name: String;
  mType: ShortInt;

procedure SetMoney(var m: Types.TMoney; cp, sp, ep, gp, pp, gems, jewelry: LongInt);
begin
  m[C_Money.COPPER] := cp;
  m[C_Money.SILVER] := sp;
  m[C_Money.ELECTRUM] := ep;
  m[C_Money.GOLD] := gp;
  m[C_Money.PLATINUM] := pp;
  m[C_Money.GEMS] := gems;
  m[C_Money.JEWELRY] := jewelry;
end;

procedure CheckMoney(var m: Types.TMoney; cp, sp, ep, gp, pp, gems, jewelry: LongInt; what: String);
begin
  TestKit.CheckEqualsL(cp, m[C_Money.COPPER], what + ': copper');
  TestKit.CheckEqualsL(sp, m[C_Money.SILVER], what + ': silver');
  TestKit.CheckEqualsL(ep, m[C_Money.ELECTRUM], what + ': electrum');
  TestKit.CheckEqualsL(gp, m[C_Money.GOLD], what + ': gold');
  TestKit.CheckEqualsL(pp, m[C_Money.PLATINUM], what + ': platinum');
  TestKit.CheckEqualsL(gems, m[C_Money.GEMS], what + ': gems');
  TestKit.CheckEqualsL(jewelry, m[C_Money.JEWELRY], what + ': jewelry');
end;

procedure SetItem(itemType: Byte; value: Word; quantity: Byte);
begin
  item^.itemType := itemType;
  item^.value := value;
  item^.quantity := quantity;
end;

procedure CheckParse(s: String; mType: ShortInt; typeName: String);
begin
  name := '';
  TestKit.CheckEqualsL(mType, MoneyCal.ParseMoneyType(s, name), '''' + s + ''': the money type');
  TestKit.CheckEqualsS(typeName, name, '''' + s + ''': its name');
end;

begin
  TestKit.Start('TMONEYCA');
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  GetMem(item, SizeOf(Types.TItemRec));
  FillChar(item^, SizeOf(Types.TItemRec), 0);

  { coin values: copper 1, silver 10, electrum 100, gold 200, platinum 1000 }
  SetMoney(m, 5, 3, 2, 4, 1, 9, 9);
  TestKit.CheckEqualsL(2035, MoneyCal.CopperValue(m), 'CopperValue counts the five coin types, not gems or jewelry');
  TestKit.CheckEqualsL(10, MoneyCal.CoinValueInGold(m), 'CoinValueInGold drops a part of a gold piece');
  c^.coins[C_Money.COPPER] := 5;
  c^.coins[C_Money.SILVER] := 3;
  c^.coins[C_Money.ELECTRUM] := 2;
  c^.coins[C_Money.GOLD] := 4;
  c^.coins[C_Money.PLATINUM] := 1;
  c^.coins[C_Money.GEMS] := 7;
  c^.coins[C_Money.JEWELRY] := 8;
  MoneyCal.CoinsOf(c, m);
  CheckMoney(m, 5, 3, 2, 4, 1, 0, 0, 'CoinsOf');
  TestKit.CheckEqualsL(2035, MoneyCal.CreatureCopper(c), 'CreatureCopper');
  TestKit.CheckEqualsL(10, MoneyCal.CreatureGold(c), 'CreatureGold');
  FillChar(c^.coins, SizeOf(c^.coins), 0);
  c^.coins[C_Money.GOLD] := 999;
  c^.coins[C_Money.ELECTRUM] := 1;
  TestKit.CheckEqualsL(999, MoneyCal.CreatureGold(c), '999 gp and an electrum piece are 999 gold');
  c^.coins[C_Money.PLATINUM] := 65535;
  c^.coins[C_Money.GOLD] := 65535;
  TestKit.CheckEqualsL(65535 * 5 + 65535, MoneyCal.CreatureGold(c), 'a full purse does not overflow');

  { making change: the largest coins first, each type capped, gems and jewelry kept }
  SetMoney(m, 0, 0, 0, 0, 0, 9, 4);
  MoneyCal.MakeChange(2035, 65535, m);
  CheckMoney(m, 5, 3, 0, 0, 2, 9, 4, '2035 copper');
  MoneyCal.MakeChange(-1, 65535, m);
  CheckMoney(m, 0, 0, 0, 0, 0, 9, 4, 'a negative amount');
  MoneyCal.MakeChange(5000, 2, m);
  CheckMoney(m, 2, 2, 2, 2, 2, 9, 4, 'a cap of 2 loses what it cannot hold');

  { who pays: the buyer with 10 gp, else a pool with 50 gp }
  FillChar(c^.coins, SizeOf(c^.coins), 0);
  c^.coins[C_Money.GOLD] := 10;
  SetMoney(GDVars.treasureMoney, 0, 0, 0, 50, 0, 1000, 1000);
  TestKit.CheckEqualsL(MoneyCal.PAY_CHARACTER, MoneyCal.WhoPays(c, 10), 'the buyer pays what it can');
  TestKit.CheckEqualsL(MoneyCal.PAY_POOL, MoneyCal.WhoPays(c, 11), 'else the pool pays');
  TestKit.CheckEqualsL(MoneyCal.PAY_POOL, MoneyCal.WhoPays(c, 50), 'the pool pays all it holds');
  TestKit.CheckEqualsL(MoneyCal.PAY_NOBODY, MoneyCal.WhoPays(c, 51), 'nobody pays more (gems and jewelry do not count)');
  TestKit.CheckEqualsL(MoneyCal.PAY_CHARACTER, MoneyCal.WhoPays(c, 0), 'a free item is the buyer''s');

  { item values: darts (9), quarrels (28) and arrows (73) by the bundle of 20 }
  SetItem(73, 100, 20);
  TestKit.CheckEqualsL(20, MoneyCal.ItemBundle(item), 'arrows come in bundles of 20');
  TestKit.CheckEqualsL(100, MoneyCal.ItemValue(item), '20 arrows at 100 a bundle');
  SetItem(73, 100, 0);
  TestKit.CheckEqualsL(5, MoneyCal.ItemValue(item), 'one unstacked arrow');
  TestKit.CheckEqualsL(2, MoneyCal.ItemSalePrice(item), 'sells for half, rounded down');
  SetItem(9, 20, 20);
  TestKit.CheckEqualsL(20, MoneyCal.ItemBundle(item), 'darts too');
  SetItem(28, 20, 20);
  TestKit.CheckEqualsL(20, MoneyCal.ItemBundle(item), 'and quarrels');
  SetItem(1, 400, 3);
  TestKit.CheckEqualsL(1, MoneyCal.ItemBundle(item), 'anything else by the piece');
  TestKit.CheckEqualsL(1200, MoneyCal.ItemValue(item), '3 at 400 each');
  TestKit.CheckEqualsL(600, MoneyCal.ItemSalePrice(item), 'sells for half');
  SetItem(1, 400, 0);
  TestKit.CheckEqualsL(400, MoneyCal.ItemValue(item), 'quantity 0 is a single item');
  SetItem(1, 65535, 3);
  TestKit.CheckEqualsL(65535, MoneyCal.ItemSalePrice(item), 'a sale price stops at 65535');

  { money type names }
  CheckParse('Gold', C_Money.GOLD, 'Gold ');
  CheckParse('Gems', C_Money.GEMS, 'Gems ');
  CheckParse('GEMS', C_Money.GEMS, 'Gems ');
  CheckParse('   Platinum', C_Money.PLATINUM, 'Platinum ');
  CheckParse('Electrum', C_Money.ELECTRUM, 'electrum ');
  CheckParse('Silver', C_Money.SILVER, 'silver ');
  CheckParse('Copper', C_Money.COPPER, 'Copper ');
  CheckParse('Jewelry', C_Money.JEWELRY, 'Jewelry ');
  name := 'unchanged';
  mType := MoneyCal.ParseMoneyType('Xyz', name);
  TestKit.CheckEqualsS('unchanged', name, 'an unknown letter leaves the name');

  { temple prices: SSI's in full, or a tenth off in the Temple of Bane that Dirten rebuilds (#682) }
  TestKit.CheckEqualsL(100, MoneyCal.TemplePrice(100, MoneyCal.TEMPLE_FULL_PRICE), 'a temple''s full price');
  TestKit.CheckEqualsL(5500, MoneyCal.TemplePrice(5500, MoneyCal.TEMPLE_FULL_PRICE), 'Raise Dead in full');
  TestKit.CheckEqualsL(90, MoneyCal.TemplePrice(100, MoneyCal.TEMPLE_TENTH_OFF), 'Cure Light Wounds a tenth off');
  TestKit.CheckEqualsL(315, MoneyCal.TemplePrice(350, MoneyCal.TEMPLE_TENTH_OFF), 'Cure Serious Wounds a tenth off');
  TestKit.CheckEqualsL(4950, MoneyCal.TemplePrice(5500, MoneyCal.TEMPLE_TENTH_OFF), 'Raise Dead a tenth off');
  TestKit.CheckEqualsL(59, MoneyCal.TemplePrice(65, MoneyCal.TEMPLE_TENTH_OFF), 'the tenth taken off is rounded down');
  TestKit.CheckEqualsL(58982, MoneyCal.TemplePrice(65535, MoneyCal.TEMPLE_TENTH_OFF), 'the largest price');

  FreeMem(item, SizeOf(Types.TItemRec));
  FreeMem(c, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.
