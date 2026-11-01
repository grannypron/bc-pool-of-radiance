{ Tests for MagicShp, the magic shop in New Phlan (#1091, #1158): each ware's kind, name, plus, weight, quantity,
  charges and price; the scrolls, which together hold every magic-user spell of the levels they cover, three of one
  level each at four times Curse's price; and the stock StockShop puts in the shop, in order and identified. }
{$I COMPILER.INC}
program TMagShop;

uses Types, GameDefs, GameVars, C_ITEM, C_SPELL, CharHlp, MagicShp, StrUtil, TestKit;

var
  it: Types.TItemRec;
  p: Types.PItemRec;
  n: Byte;
  i: Byte;
  j: Byte;
  id: Byte;
  lvl: Byte;
  top: Byte;
  ok: Boolean;
  found: Boolean;
  count: Integer;
  what: String;

{ Item's label as a shop lists it, without the trailing blank. }
function LabelOf(item: Types.PItemRec): String;
var
  s: String;
begin
  CharHlp.ItemLabel(item, False);
  s := item^.name;
  while (Length(s) > 0) and (s[Length(s)] = ' ') do
    Dec(s[0]);
  LabelOf := s;
end;

{ Make stock item n and check its label, type, plus, save bonus, weight, quantity, price and spells or charges. }
procedure CheckWare(n: Byte; name: String; kind: Byte; plus, save: ShortInt; weight: Word; quantity: Byte;
                    price: Word; s1, s2, s3: Byte);
begin
  MagicShp.MakeStockItem(n, @it);
  TestKit.CheckEqualsS(name, LabelOf(@it), name + ': its name');
  TestKit.CheckEqualsL(kind, it.itemType, name + ': its item type');
  TestKit.CheckEqualsL(plus, it.plus, name + ': its plus');
  TestKit.CheckEqualsL(save, it.saveBonus, name + ': its save bonus');
  TestKit.CheckEqualsL(weight, it.weight, name + ': its weight');
  TestKit.CheckEqualsL(quantity, it.quantity, name + ': its quantity');
  TestKit.CheckEqualsL(price, it.value, name + ': its price');
  TestKit.CheckEqualsL(s1, it.spells[1], name + ': its first property');
  TestKit.CheckEqualsL(s2, it.spells[2], name + ': its second property');
  TestKit.CheckEqualsL(s3, it.spells[3], name + ': its third property');
  TestKit.CheckEqualsL(0, it.unidMask, name + ': identified');
  TestKit.CheckEqualsL(0, it.cursed, name + ': not cursed');
end;

begin
  TestKit.Start('TMAGSHOP');
  { ItemReadable reads the scroll's base item: a magic-user scroll's slot is all it needs }
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  CharHlp.baseItems^[C_ITEM.MAGE_SCROLL].slot := C_ITEM.SLOT_MAGE_SCROLL;

  { the wares: Curse's prices for what Curse sells, twice this game's value for the rest }
  CheckWare(1, 'Javelin of Lightning', C_ITEM.JAVELIN, 1, 1, 20, 0, 6000, 1, 83, 0);
  CheckWare(2, 'Potion Extra Healing', 71, 1, 1, 1, 0, 1600, 3, 3, 0);
  CheckWare(3, 'Potion of Speed', 71, 1, 1, 1, 0, 900, 1, 80, 0);
  CheckWare(4, 'Wand of Magic Missiles', 79, 1, 1, 1, 0, 40000, 30, 88, 0);
  CheckWare(5, '10 Darts +1', C_ITEM.DART, 1, 0, 5, 10, 150, 0, 0, 0);
  CheckWare(6, '10 Arrows +1', C_ITEM.ARROW, 1, 0, 4, 10, 240, 0, 0, 0);
  CheckWare(7, 'Bag of Holding', 70, 1, 1, 150, 0, 50000, 0, 0, 0);

  { the scrolls: a magic-user scroll with three spells of one level, at 1,200 gold pieces a spell level for each }
  top := 0;
  for n := 1 to MagicShp.SCROLL_COUNT do begin
    what := 'scroll ' + StrUtil.NumStr(n);
    MagicShp.MakeStockItem(MagicShp.WARE_COUNT + n, @it);
    TestKit.CheckEqualsS('Magic User Scroll With 3 Spells', LabelOf(@it), what + ': its name');
    TestKit.CheckEqualsL(C_ITEM.MAGE_SCROLL, it.itemType, what + ': a magic-user scroll');
    TestKit.CheckEqualsL(25, it.weight, what + ': its weight');
    TestKit.CheckEqualsL(0, it.unidMask, what + ': identified, so its spells can be read');
    TestKit.Check(CharHlp.ItemReadable(@it), what + ': readable');
    lvl := GameDefs.spellTable[it.spells[1]].level;
    if lvl > top then
      top := lvl;
    ok := True;
    for i := 1 to MagicShp.SCROLL_SPELLS do begin
      id := CharHlp.ScrollSpellAt(@it, i);
      ok := ok and (id <> C_SPELL.NONE) and (GameDefs.spellTable[id].castClass = C_SPELL.CLASS_MAGE) and
            (GameDefs.spellTable[id].level = lvl);
      for j := 1 to i - 1 do
        ok := ok and (it.spells[j] <> it.spells[i]);
    end;
    TestKit.Check(ok, what + ': three different magic-user spells of level ' + StrUtil.NumStr(lvl));
    TestKit.CheckEqualsL(3 * 1200 * lvl, it.value, what + ': its price');
    TestKit.CheckEqualsL(it.value, MagicShp.ScrollPrice(n), what + ': ScrollPrice');
  end;
  TestKit.CheckEqualsL(3, top, 'the scrolls go up to the third level');
  { by level, Curse's 900, 1,800 and 2,700 four times over }
  MagicShp.MakeStockItem(MagicShp.WARE_COUNT + 1, @it);
  TestKit.CheckEqualsL(3600, it.value, 'a first-level scroll costs 3,600');
  MagicShp.MakeStockItem(MagicShp.WARE_COUNT + 6, @it);
  TestKit.CheckEqualsL(7200, it.value, 'a second-level scroll costs 7,200');
  MagicShp.MakeStockItem(MagicShp.STOCK_COUNT, @it);
  TestKit.CheckEqualsL(10800, it.value, 'a third-level scroll costs 10,800');

  { every magic-user spell of the levels the scrolls cover is on one of them }
  count := 0;
  for id := 1 to C_SPELL.LAST do
    if (GameDefs.spellTable[id].castClass = C_SPELL.CLASS_MAGE) and (GameDefs.spellTable[id].level <= top) then begin
      Inc(count);
      found := False;
      for n := 1 to MagicShp.SCROLL_COUNT do
        for i := 1 to MagicShp.SCROLL_SPELLS do
          if MagicShp.scrolls[n, i] = id then
            found := True;
      TestKit.Check(found, GameDefs.spellNames[id] + ' (spell ' + StrUtil.NumStr(id) + ') is on a scroll');
    end;
  TestKit.CheckEqualsL(31, count, 'the magic-user spells of levels 1 to 3: 13, 7 and 11');

  { StockShop: the whole stock in order, replacing what the shop held }
  GameVars.treasureItems := nil;
  MagicShp.StockShop;
  MagicShp.StockShop;
  p := GameVars.treasureItems;
  n := 0;
  ok := True;
  while p <> nil do begin
    Inc(n);
    MagicShp.MakeStockItem(n, @it);
    ok := ok and (p^.itemType = it.itemType) and (p^.value = it.value) and (p^.spells[1] = it.spells[1]) and
          (p^.spells[2] = it.spells[2]) and (p^.spells[3] = it.spells[3]);
    p := p^.next;
  end;
  TestKit.CheckEqualsL(MagicShp.STOCK_COUNT, n, 'StockShop stocks every item once, a second visit too');
  TestKit.Check(ok, 'StockShop stocks them in order');
  CharHlp.FreeItemList(GameVars.treasureItems);
  FreeMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));

  TestKit.Done;
end.
