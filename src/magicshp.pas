{ The magic shop in New Phlan at (11,12), which was one of the town's arms and armor shops (#1091, #1158). The patched
  New Phlan script runs PROGRAM 11 (EclVm.PROG_MAGIC_SHOP) and then enters the shop as every shop does; the program
  fills the shop's stock here. The stock is built afresh on every visit, so nothing ever sells out.

  The stock adapts the magic shop in Curse of the Azure Bonds' Zhentil Keep: its prices where it sells the same item,
  otherwise twice the item's value in this game, and its magic-user scrolls of three spells at four times its price
  (Curse asks 300 gold pieces a spell level for each spell on them). }
{$O+,F+}
{$I COMPILER.INC}
unit MagicShp;

interface

uses Types, C_ITEM;

type
  { One of the shop's wares other than the scrolls. A ware with a template is RandItem's template item of that kind;
    one without is ammunition +1, named nameId and weighing weight coins a piece. }
  TWare = record
    kind: Byte;
    template: Byte;
    nameId: Byte;
    weight: Byte;
    quantity: Byte;
    price: Word;
  end;

const
  { what a spell on a scroll costs for each of its spell levels: Curse's 300 gold pieces, four times over }
  SCROLL_PRICE_PER_LEVEL = 1200;
  { the spells on a scroll }
  SCROLL_SPELLS = 3;
  { The magic-user scrolls, three spells of one level each. Together they hold every magic-user spell of levels 1 to 3,
    13, 7 and 11 of them; a level's last scroll, which its spells do not fill, repeats its most useful ones. Levels 4
    and 5 are rows to add here once their spells exist (#1121). }
  SCROLL_COUNT = 12;
  scrolls: array[1..SCROLL_COUNT, 1..SCROLL_SPELLS] of Byte = (
    { Burning Hands, Magic Missile, Shocking Grasp }
    (9, 15, 20),
    { Charm Person, Friends, Sleep }
    (10, 14, 21),
    { Enlarge, Reduce, Shield }
    (12, 13, 19),
    { Detect Magic, Read Magic, Protection From Evil }
    (11, 18, 16),
    { Protection From Good, and Magic Missile and Sleep again }
    (17, 15, 21),
    { Detect Invisibility, Invisibility, Knock }
    (29, 30, 31),
    { Mirror Image, Ray of Enfeeblement, Stinking Cloud }
    (32, 33, 34),
    { Strength, and Stinking Cloud and Mirror Image again }
    (35, 34, 32),
    { Fireball, Lightning Bolt, Slow }
    (47, 51, 55),
    { Haste, Blink, Hold Person }
    (48, 45, 49),
    { Dispel Magic, Invisibility 10' Radius, Protection From Normal Missiles }
    (46, 50, 54),
    { Protection From Evil 10' Radius, Protection From Good 10' Radius, and Fireball again }
    (52, 53, 47));
  { the wares, listed before the scrolls }
  WARE_COUNT = 7;
  wares: array[1..WARE_COUNT] of TWare = (
    { a Javelin of Lightning: Curse sells none, and its value here is 3,000 }
    (kind: C_ITEM.JAVELIN; template: 14; nameId: 0; weight: 0; quantity: 0; price: 6000),
    { a Potion of Extra Healing and a Potion of Speed, at Curse's prices }
    (kind: 71; template: 1; nameId: 0; weight: 0; quantity: 0; price: 1600),
    (kind: 71; template: 4; nameId: 0; weight: 0; quantity: 0; price: 900),
    { a Wand of Magic Missiles, at Curse's price }
    (kind: 79; template: 8; nameId: 0; weight: 0; quantity: 0; price: 40000),
    { 10 Darts +1: ammunition +1 is worth 150 a bundle of 20 here, and Curse sells no darts +1 }
    (kind: C_ITEM.DART; template: 0; nameId: 9; weight: 5; quantity: 10; price: 150),
    { 10 Arrows +1, at Curse's price }
    (kind: C_ITEM.ARROW; template: 0; nameId: 61; weight: 4; quantity: 10; price: 240),
    { a Bag of Holding: Curse sells none, and its value here is 25,000 }
    (kind: 70; template: 18; nameId: 0; weight: 0; quantity: 0; price: 50000));
  { the whole stock: the wares, then the scrolls }
  STOCK_COUNT = WARE_COUNT + SCROLL_COUNT;

{ The price of scroll n: SCROLL_PRICE_PER_LEVEL for each level of each spell on it. }
function ScrollPrice(n: Byte): Word;

{ Make stock item n, 1..STOCK_COUNT, in item: ware n, or for n past WARE_COUNT scroll n - WARE_COUNT, a magic-user
  scroll with its three spells. Every item is identified, as a shop's are, so a scroll's spells can be read at once. }
procedure MakeStockItem(n: Byte; item: Types.PItemRec);

{ Fill the shop's stock, GameVars.treasureItems, with the STOCK_COUNT items in order, after freeing any items it held. }
procedure StockShop;

implementation

uses GameDefs, GameVars, CharHlp, RandItem;

function ScrollPrice(n: Byte): Word;
var
  i: Byte;
  price: Word;
begin
  price := 0;
  for i := 1 to SCROLL_SPELLS do
    Inc(price, GameDefs.spellTable[MagicShp.scrolls[n, i]].level * SCROLL_PRICE_PER_LEVEL);
  ScrollPrice := price;
end;

procedure MakeStockItem(n: Byte; item: Types.PItemRec);
var
  i: Byte;
begin
  FillChar(item^, SizeOf(Types.TItemRec), 0);
  if n <= WARE_COUNT then
    with MagicShp.wares[n] do begin
      item^.itemType := kind;
      if template <> 0 then
        RandItem.ApplyTemplate(item, template)
      else begin
        { ammunition +1, named as RandItem names it: "+1" before the ammunition's name }
        item^.nameIds[3] := nameId;
        item^.nameIds[2] := C_ITEM.NAME_PLUS_BASE + 1;
        item^.plus := 1;
        item^.weight := weight;
      end;
      item^.quantity := quantity;
      item^.value := price;
    end
  else begin
    { a magic-user scroll, named and weighing as RandItem's do }
    item^.itemType := C_ITEM.MAGE_SCROLL;
    item^.nameIds[3] := C_ITEM.NAME_MAGE_SCROLL;
    item^.nameIds[2] := C_ITEM.NAME_WITH_1_SPELL + SCROLL_SPELLS - 1;
    item^.plus := 1;
    item^.weight := 25;
    for i := 1 to SCROLL_SPELLS do
      item^.spells[i] := MagicShp.scrolls[n - WARE_COUNT, i];
    item^.value := MagicShp.ScrollPrice(n - WARE_COUNT);
  end;
  item^.unidMask := 0;
end;

procedure StockShop;
var
  it: Types.TItemRec;
  n: Byte;
begin
  CharHlp.FreeItemList(GameVars.treasureItems);
  for n := 1 to STOCK_COUNT do begin
    MagicShp.MakeStockItem(n, @it);
    CharHlp.AppendItemCopy(GameVars.treasureItems, @it);
  end;
end;

end.
