{ Coin conversion, treasure collection, money menus and random item generation. }
{$O+,F+}
unit Money;

interface

uses Types, Crt, C_Npc, GDConsts, GDVars, TextRend, Border, CharHlp, FxEngine, C_Keys, C_Ifc, C_Money;

function CheckOverload(p: Types.PCharRecord; w: LongInt; var takable: Word): Boolean;

procedure PoolMoney;

procedure ShareMoney;

procedure TakeMoneyMenu;

function ParseMoneyType(s: String; var typeName: String): ShortInt;

function InputNumberMax(max: Word; query: Types.TStr40; color: Byte): Word;

procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: Word; mType: ShortInt);

procedure DropMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);

procedure DetermineTreasure(var treasure, items: Boolean);

procedure PayFromCreature(creature: Types.PCharRecord; gp: LongInt);

procedure PayFromPool(gp: LongInt);

function CoinValueInGold(m: Types.TMoney): LongInt;

procedure GenerateRandomItem(kind: Byte; item: Types.PItemRec);

{ How many pieces an item's value is for: ammunition (darts, quarrels and arrows) is valued per bundle of 20, as the
  game's own 20 Arrows +1 for 100 gp are; anything else is valued per piece (3 Potions of Healing at 400 each). }
function ItemBundle(item: Types.PItemRec): Byte;

{ What an item or stack is worth in gold: value * quantity div ItemBundle (quantity 0 is a single unstacked item). }
function ItemValue(item: Types.PItemRec): LongInt;

{ What a shop pays for an item or stack: half its ItemValue, at most 65535. }
function ItemSalePrice(item: Types.PItemRec): Word;

procedure AppraiseMenu(var ok: Boolean);

implementation

var
  treasureMoney: Types.TMoney absolute GDVars.treasureMoney;
  { lo-word view }
  treasureMoneyLo: array[C_Money.COPPER..C_Money.JEWELRY] of Types.TLoW absolute GDVars.treasureMoney;
  { 19 * 8 Words, addressed by a one-based word index (template n starts at 8n - 7). Index 144 is not a template start:
    it spans the last word of template 18 and the first seven of template 19. }
  randItemW: array[1..152] of Word absolute GDConsts.randomItemTemplates;
  randItemB: array[1..152] of Types.TWB absolute GDConsts.randomItemTemplates;

{ Carrying capacity is the weight allowance plus 1500 coins, and 5000 more with a Bag of Holding readied. It is measured
  against CharHlp.RawWeight, the weight before the bag takes its share. }
function CarryingCapacity(p: Types.PCharRecord): LongInt;
begin
  if CharHlp.HasBagOfHolding(p) then
    CarryingCapacity := LongInt(CharHlp.WeightAllowance(p)) + 1500 + 5000
  else
    CarryingCapacity := LongInt(CharHlp.WeightAllowance(p)) + 1500;
end;

{ The coins the creature can still carry: its carrying capacity less its raw weight, or zero when it is full. }
function SpareCapacity(p: Types.PCharRecord): Word;
var
  room: LongInt;
begin
  room := Money.CarryingCapacity(p) - CharHlp.RawWeight(p);
  if room < 0 then
    room := 0;
  SpareCapacity := room;
end;

{ True, with the spare capacity in takable, when carrying w more coins would exceed capacity; else False with takable
  zero. }
function CheckOverload(p: Types.PCharRecord; w: LongInt; var takable: Word): Boolean;
begin
  takable := Money.SpareCapacity(p);
  if w > takable then
    CheckOverload := True
  else begin
    CheckOverload := False;
    takable := 0;
  end;
end;

{ The copper value of the five coin types in m. }
function CopperValue(var m: Types.TMoney): LongInt;
var
  total: LongInt;
  i: ShortInt;
begin
  total := 0;
  for i := C_Money.COPPER to C_Money.PLATINUM do
    Inc(total, GDConsts.dsCoinValuationCopper[i] * m[i]);
  CopperValue := total;
end;

{ The value of the five coin types in m in whole gold pieces; a part of a gold piece does not count, so 999 gp and an
  electrum piece cannot pay 1000. }
function CoinValueInGold(m: Types.TMoney): LongInt;
begin
  CoinValueInGold := CopperValue(m) div GDConsts.dsCoinValuationCopper[C_Money.GOLD];
end;

{ Replace the five coin types in m with rem copper given as the largest coins, platinum first, each type at most cap.
  Gems and jewelry are kept. A negative rem gives nothing; copper the caps cannot hold is lost (for a character, only
  above about 393,000 gp). }
procedure MakeChange(rem, cap: LongInt; var m: Types.TMoney);
var
  i: ShortInt;
  n: LongInt;
begin
  if rem < 0 then
    rem := 0;
  for i := C_Money.PLATINUM downto C_Money.COPPER do begin
    n := rem div GDConsts.dsCoinValuationCopper[i];
    if n > cap then
      n := cap;
    m[i] := n;
    Dec(rem, n * GDConsts.dsCoinValuationCopper[i]);
  end;
end;

{ Pay gp gold pieces from the creature's coins, worked out in copper, with the change given back in the largest coins.
  The caller has checked the creature can pay (ViewChar.CreatureCoinValueInGold); if not, every coin goes. The coins'
  weight changes, so the creature's stats are recalculated. }
procedure PayFromCreature(creature: Types.PCharRecord; gp: LongInt);
var
  m: Types.TMoney;
  i: ShortInt;
begin
  for i := C_Money.COPPER to C_Money.PLATINUM do
    m[i] := creature^.coins[i];
  MakeChange(CopperValue(m) - gp * GDConsts.dsCoinValuationCopper[C_Money.GOLD], 65535, m);
  for i := C_Money.COPPER to C_Money.PLATINUM do
    creature^.coins[i] := m[i];
  CharHlp.RecalcStats(creature);
end;

{ Pay gp gold pieces from the treasure pool, as PayFromCreature does; the pool's coins have no 65535 limit. }
procedure PayFromPool(gp: LongInt);
begin
  MakeChange(CopperValue(treasureMoney) - gp * GDConsts.dsCoinValuationCopper[C_Money.GOLD], MaxLongInt,
             treasureMoney);
end;

{ Give pp platinum to the current character; whatever does not fit goes to the treasure pool. }
procedure GivePlatinum(pp: Word);
var
  takable: Word;
begin
  if Money.CheckOverload(GDVars.curChar, pp, takable) then begin
    CharHlp.PrintBottomLine('Overloaded.  Money will be put in Pool.');
    Inc(GDVars.curChar^.coins[C_Money.PLATINUM], takable);
    CharHlp.RecalcStats(GDVars.curChar);
    treasureMoney[C_Money.PLATINUM] := pp + treasureMoney[C_Money.PLATINUM] - takable;
  end else begin
    Inc(GDVars.curChar^.coins[C_Money.PLATINUM], pp);
    CharHlp.RecalcStats(GDVars.curChar);
  end;
end;

{ Read an amount from the bottom line. Accept digits, Backspace, Return and Escape; clamp to max as digits are entered.
  Escape returns zero. }
function InputNumberMax;
var
  col: Byte;
  pad1: Byte;
  qLen: Byte;
  maxStr: String[5];
  s: String[6];
  ch: Char;
  v: LongInt;
  code: Integer;
  n: Word;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, query);
  qLen := Length(query);
  col := qLen;
  Str(max, maxStr);
  s := '';
  repeat
    ch := GameIo.ReadGameKey;
    case ch of
      '0'..'9': begin
          s := Concat(s, ch);
          Val(s, v, code);
          if max >= v then
            Inc(col)
          else begin
            s := maxStr;
            col := qLen + Length(maxStr);
          end;
          TextRend.DisplayString(qLen, 24, White, s);
        end;
      C_Keys.BACKSPACE: if Length(s) > 0 then begin
          s := Copy(s, 1, Length(s) - 1);
          TextRend.PrintSpaces(col, 24, Black, 1);
          Dec(col);
        end;
    end;
  until (ch = C_Keys.ENTER) or (ch = C_Keys.ESC);
  TextRend.PrintSpaces(0, 24, Black, 40);
  if ch = C_Keys.ESC then
    n := 0
  else
    Val(s, n, code);
  InputNumberMax := n;
end;

{ Move qty coins of mType, and their weight, from giver to rcv if rcv can carry them, else print 'Overloaded'. }
procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: Word; mType: ShortInt);
begin
  if qty <= Money.SpareCapacity(rcv) then begin
    giver^.coins[mType] := giver^.coins[mType] - qty;
    CharHlp.RecalcStats(giver);
    rcv^.coins[mType] := rcv^.coins[mType] + qty;
    CharHlp.RecalcStats(rcv);
  end else
    CharHlp.PrintBottomLine('Overloaded');
end;

{ Creatures with npc = 0 or C_Npc.ANIMATED_PC pour all seven money types into the treasure pool; sets
  treasureMoneyFlag. }
procedure PoolMoney;
var
  p: Types.PCharRecord;
  i: ShortInt;
  mt: ShortInt;
begin
  p := GDVars.creatureList;
  GDVars.treasureMoneyFlag := True;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = C_Npc.ANIMATED_PC) then begin
      for i := C_Money.COPPER to C_Money.JEWELRY do begin
        mt := i;
        treasureMoney[mt] := p^.coins[mt] + treasureMoney[mt];
      end;
      FillChar(p^.coins, SizeOf(p^.coins), 0);
      CharHlp.RecalcStats(p);
    end;
    p := p^.nextCharAddr;
  end;
end;

{ Count the creatures with npc = 0 or C_Npc.ANIMATED_PC, the ones PoolMoney empties. }
function CountPoolers: Byte;
var
  p: Types.PCharRecord;
  n: Byte;
begin
  p := GDVars.creatureList;
  n := 0;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = C_Npc.ANIMATED_PC) then
      Inc(n);
    p := p^.nextCharAddr;
  end;
  CountPoolers := n;
end;

{ Split the treasure pool. Each type's share is the pool amount div CountPoolers, with the remainder held back. Pass 1
  walks the creatures with C_Npc.FLAG clear and, from jewelry (6) down to copper (0), gives each its share (or as much
  as fits, the rest joining the remainder) plus one remainder coin when the whole outstanding remainder would fit. Pass
  2 hands out the leftovers to every creature in list order up to capacity, and any excess returns to the treasure pool.
  Note: the divisor counts C_Npc.ANIMATED_PC creatures, which pass 1 skips, and not npc 1..$7F, which pass 1 pays. }
procedure ShareMoney;
var
  p: Types.PCharRecord;
  deadP: Types.PCharRecord;
  cnt: Byte;
  done: Boolean;
  takable: Word;
  share: array[C_Money.COPPER..C_Money.JEWELRY] of Word;
  rem: array[C_Money.COPPER..C_Money.JEWELRY] of Word;
  i: ShortInt;
begin
  p := GDVars.creatureList;
  done := False;
  cnt := Money.CountPoolers;
  FillChar(share, SizeOf(share), 0);
  FillChar(rem, SizeOf(rem), 0);
  for i := C_Money.COPPER to C_Money.JEWELRY do
    if treasureMoney[i] > 0 then begin
      share[i] := treasureMoney[i] div cnt;
      rem[i] := treasureMoney[i] mod cnt;
    end else begin
      share[i] := 0;
      rem[i] := 0;
    end;
  { pass 1: shares }
  while p <> nil do begin
    { C_Npc.FLAG clear }
    if p^.npc < C_Npc.FLAG then
      for i := C_Money.JEWELRY downto C_Money.COPPER do
        if not Money.CheckOverload(p, share[i], takable) then begin
          p^.coins[i] := share[i] + p^.coins[i];
          CharHlp.RecalcStats(p);
          if rem[i] > 0 then
            if not Money.CheckOverload(p, rem[i], takable) then begin
              p^.coins[i] := p^.coins[i] + 1;
              CharHlp.RecalcStats(p);
              Dec(rem[i]);
            end;
        end else begin
          p^.coins[i] := p^.coins[i] + takable;
          rem[i] := rem[i] + share[i] - takable;
          CharHlp.RecalcStats(p);
        end;
    p := p^.nextCharAddr;
  end;
  { pass 2: leftovers }
  for i := C_Money.JEWELRY downto C_Money.COPPER do
    if rem[i] > 0 then begin
      p := GDVars.creatureList;
      while p <> nil do begin
        takable := Money.SpareCapacity(p);
        if takable > 0 then
          if rem[i] > takable then begin
            p^.coins[i] := p^.coins[i] + takable;
            CharHlp.RecalcStats(p);
            rem[i] := rem[i] - takable;
          end else begin
            p^.coins[i] := p^.coins[i] + rem[i];
            CharHlp.RecalcStats(p);
            rem[i] := 0;
          end;
        p := p^.nextCharAddr;
      end;
    end;
  { return the rest to the pool }
  GDVars.treasureMoneyFlag := False;
  for i := C_Money.COPPER to C_Money.JEWELRY do begin
    treasureMoney[i] := rem[i];
    if treasureMoney[i] <> 0 then
      GDVars.treasureMoneyFlag := True;
  end;
end;

{ Dropped money enters the treasure pool in a shop, temple or loot menu (C_Ifc.SHOP_TEMPLE, C_Ifc.LOOT). Elsewhere it is
  discarded. }
procedure DropMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);
begin
  p^.coins[mType] := p^.coins[mType] - qty;
  CharHlp.RecalcStats(p);
  if (GDVars.ifcState = C_Ifc.LOOT) or (GDVars.ifcState = C_Ifc.SHOP_TEMPLE) then
    treasureMoney[mType] := treasureMoney[mType] + qty;
end;

{ Take qty of mType from the pool; a qty above the pool amount is cut to the pool's low word. The whole take is refused
  ('Overloaded') if the uncapped qty would overload; there is no partial take. }
procedure TakeMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);
var
  takable: Word;
begin
  if Money.CheckOverload(p, qty, takable) then
    CharHlp.PrintBottomLine('Overloaded')
  else begin
    if qty > treasureMoney[mType] then
      qty := treasureMoneyLo[mType].lo;
    treasureMoney[mType] := treasureMoney[mType] - qty;
    p^.coins[mType] := p^.coins[mType] + qty;
    CharHlp.RecalcStats(p);
  end;
end;

{ Return the money type named by s and its display name in typeName. Leading spaces are skipped (no bounds check); the
  first letter selects the type, and for 'G' the second letter, upper-cased, tells Gems from Gold. An unmatched letter
  leaves the result and typeName unset. }
function ParseMoneyType(s: String; var typeName: String): ShortInt;
var
  i: Byte;
begin
  i := 1;
  while s[i] = ' ' do
    Inc(i);
  case s[i] of
    'G': if UpCase(s[i + 1]) = 'E' then begin
           ParseMoneyType := C_Money.GEMS;
           typeName := 'Gems ';
         end else begin
           typeName := 'Gold ';
           ParseMoneyType := C_Money.GOLD;
         end;
    'P': begin
           typeName := 'Platinum ';
           ParseMoneyType := C_Money.PLATINUM;
         end;
    'E': begin
           typeName := 'electrum ';
           ParseMoneyType := C_Money.ELECTRUM;
         end;
    'S': begin
           typeName := 'silver ';
           ParseMoneyType := C_Money.SILVER;
         end;
    'C': begin
           typeName := 'Copper ';
           ParseMoneyType := C_Money.COPPER;
         end;
    'J': begin
           typeName := 'Jewelry ';
           ParseMoneyType := C_Money.JEWELRY;
         end;
  end;
end;

{ Build the money menu (copper first), prompt for an amount and take it from the treasure pool; repeat while money
  remains. The prompt limit uses the low word of the available amount. Note: cnt is never initialised or read, and the
  list is freed only after a take, not when the menu is cancelled. }
procedure TakeMoneyMenu;
var
  i: ShortInt;
  mType: ShortInt;
  deadW: Word;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  save: Types.PItemRec;
  cnt: Word;
  idx: Integer;
  numStr: String;
  n: Word;
  exitF: Boolean;
  redraw: Boolean;
  ch: Char;
begin
  Border.DrawWindow(1, 1, 38, 22, 0, LightGreen, '');
  idx := 0;
  repeat
    redraw := True;
    p := nil;
    sel := nil;
    for i := C_Money.JEWELRY downto C_Money.COPPER do
      if treasureMoney[i] > 0 then begin
        Inc(cnt);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TMenuNode));
          p^.next := nil;
        end else begin
          sel := p;
          GetMem(p, SizeOf(Types.TMenuNode));
          p^.next := sel;
        end;
        Str(treasureMoney[i], numStr);
        p^.name := GDConsts.moneyNames[i] + ' ' + numStr;
        p^.inUse := 0;
      end;
    sel := p;
    save := p;
    ch := MenuCore.MenuVertical('Select type of coin', '', LightMagenta, LightGreen, White, 2, 2,
                                15, 8, p, True, redraw, idx, sel);
    if (sel = nil) or (ch = C_Keys.NONE) then begin
      MenuCore.FreeStringList(save);
      exitF := True;
    end else begin
      exitF := False;
      mType := Money.ParseMoneyType(sel^.name, numStr);
      numStr := 'How much ' + numStr + 'will you take? ';
      n := Money.InputNumberMax(treasureMoneyLo[mType].lo, numStr, LightGreen);
      Money.TakeMoney(GDVars.curChar, n, mType);
      MenuCore.FreeStringList(save);
      GDVars.treasureMoneyFlag := False;
      exitF := True;
      for i := C_Money.COPPER to C_Money.JEWELRY do
        if treasureMoney[i] > 0 then begin
          GDVars.treasureMoneyFlag := True;
          exitF := False;
        end;
    end;
  until exitF;
end;

{ Report whether the treasure pool contains money or items. }
procedure DetermineTreasure(var treasure, items: Boolean);
var
  i: ShortInt;
begin
  treasure := False;
  items := False;
  for i := C_Money.COPPER to C_Money.JEWELRY do
    if treasureMoney[i] <> 0 then
      treasure := True;
  if GDVars.treasureItems <> nil then
    items := True;
end;

function ItemBundle(item: Types.PItemRec): Byte;
begin
  case item^.itemType of
    9, 28, 73: ItemBundle := 20;
    else ItemBundle := 1;
  end;
end;

function ItemValue(item: Types.PItemRec): LongInt;
var
  q: LongInt;
begin
  q := item^.quantity;
  if q = 0 then
    q := 1;
  ItemValue := LongInt(item^.value) * q div Money.ItemBundle(item);
end;

function ItemSalePrice(item: Types.PItemRec): Word;
var
  v: LongInt;
begin
  v := Money.ItemValue(item) div 2;
  if v > 65535 then
    v := 65535;
  ItemSalePrice := v;
end;

{ Roll the magical plus for a random weapon or armor on a d20: 1 (70%), 2 (25%) or 3 (5%). }
function RandomBonus: ShortInt;
var
  r: Byte;
begin
  r := FxEngine.RollDice(1, 20);
  case r of
    1..14: RandomBonus := 1;
    15..19: RandomBonus := 2;
    else RandomBonus := 3;
  end;
end;

{ Build a random item of the given kind. Kinds 1..59, 73, 77 and 93 are weapons and armor, named from their type with a
  plus from RandomBonus and given a weight and value by type. 61 and 62 are magic-user and clerical scrolls holding 1d3
  rolled spells in the spells field. 63, 67, 69..71, 78, 79, 84 and 92 pick a randomItemTemplates entry by its one-based
  word index into randItemW/randItemB. Any other kind gets only itemType and the defaults. }
procedure GenerateRandomItem(kind: Byte; item: Types.PItemRec);
var
  r: Byte;
  n: Byte;
  j: Byte;
  templateWordIndex: Byte;
  spell: Byte;
begin
  { clear the whole item record }
  FillChar(item^, SizeOf(Types.TItemRec), 0);
  templateWordIndex := 0;
  with item^ do begin
    FillChar(spells, SizeOf(spells), 0);
    next := nil;
    equipped := 0;
    unidMask := 6;
    cursed := 0;
    itemType := kind;
    FillChar(nameIds, SizeOf(nameIds), 0);
    case itemType of
      1..59, 73, 77, 93: begin
          plus := Money.RandomBonus;
          case itemType of
            { One time in five, index 144: not a template start, so the item gets the last word of template 18 and the
              first seven of template 19. Template 14 (Javelin of Lightning, index 105) is never selected. }
            21: begin
                   r := FxEngine.RollDice(1, 5);
                   if r = 5 then
                     templateWordIndex := 144;
                   nameIds[3] := 21;
                   nameIds[2] := plus + 161;
                 end;
            28: begin
                   nameIds[3] := 28;
                   nameIds[2] := plus + 161;
                 end;
            50, 51: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 49;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            52: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 50;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            53..58: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 48;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            73: begin
                   nameIds[3] := 61;
                   nameIds[2] := plus + 161;
                 end;
            { bracers: plus 1..3 becomes 4/6/8, named AC 6/4/2 }
            77: begin
                   nameIds[3] := 79;
                   nameIds[2] := 167;
                   plus := plus * 2 + 2;
                   case plus of
                     4: nameIds[1] := 221;
                     6: nameIds[1] := 222;
                     8: nameIds[1] := 220;
                   end;
                 end;
            93: begin
                   nameIds[3] := 66;
                   nameIds[2] := 224;
                   nameIds[1] := plus + 161;
                 end;
            else begin
                   nameIds[3] := itemType;
                   nameIds[2] := plus + 161;
                 end;
          end;
          saveBonus := 0;
          quantity := 0;
          { weight in coins }
          case itemType of
            1, 13, 14, 35:
              weight := 75;
            2, 20, 29, 31, 32, 33, 39, 42, 44, 46, 59:
              weight := 50;
            3, 24, 40:
              weight := 125;
            4, 15, 23, 34, 43, 45, 51:
              weight := 100;
            5, 12, 17, 19, 50:
              weight := 150;
            6: weight := 15;
            7: weight := 30;
            8, 77:
              weight := 10;
            { ammunition: weight is per piece, as in every placed stack }
            9: begin
                 weight := 5;
                 quantity := 5;
               end;
            28: begin
                  weight := 3;
                  quantity := 10;
                end;
            73: begin
                  weight := 4;
                  quantity := 10;
                end;
            10, 26, 36:
              weight := 60;
            11, 16, 25, 27, 41, 47:
              weight := 80;
            18: weight := 175;
            21: weight := 20;
            22, 30:
              weight := 40;
            37: weight := 35;
            38, 53:
              weight := 250;
            52: weight := 200;
            54, 56:
              weight := 400;
            55: weight := 300;
            57: weight := 350;
            58: weight := 450;
            { Only 93 reaches this arm; 47 is matched above }
            47, 93:
              weight := 1;
            else begin
                   weight := 40;
                   quantity := 10;
                 end;
          end;
          { value in gp = plus * K }
          case itemType of
            59: value := Word(plus) * 2500;
            { per bundle of 20 (ItemBundle) }
            9, 28, 73: value := Word(plus) * 150;
            53, 54: value := Word(plus) * 3000;
            55, 56: value := Word(plus) * 3500;
            57: value := Word(plus) * 4000;
            58: value := Word(plus) * 5000;
            77: value := Word(plus) * 3000;
            else value := Word(plus) * 2000;
          end;
        end;
      { scrolls }
      61, 62: begin
          n := FxEngine.RollDice(1, 3);
          if itemType = 61 then
            nameIds[3] := 209
          else
            nameIds[3] := 208;
          nameIds[2] := n + 209;
          nameIds[1] := 0;
          plus := 1;
          weight := 25;
          quantity := 0;
          value := 0;
          for j := 1 to n do begin
            r := FxEngine.RollDice(1, 3);
            if itemType = 61 then
              { magic-user spell ids: 9..21, 29..35, 45..55 }
              case r of
                1: spell := FxEngine.RollDice(1, 13) + 8;
                2: spell := FxEngine.RollDice(1, 7) + 28;
                3: spell := FxEngine.RollDice(1, 11) + 44;
              end else
              { clerical spell ids: 1..8, 22..28, 36..44 }
              case r of
                1: spell := FxEngine.RollDice(1, 8);
                2: spell := FxEngine.RollDice(1, 7) + 21;
                3: spell := FxEngine.RollDice(1, 9) + 35;
              end;
            spells[j] := spell;
            value := Word(r) * 300 + value;
          end;
        end;
      63: templateWordIndex := 73;
      67: templateWordIndex := 145;
      69: begin
             r := FxEngine.RollDice(1, 10);
             case r of
               1: templateWordIndex := 41;
               2..6: templateWordIndex := 121;
               7..10: templateWordIndex := 129;
             end;
           end;
      78: begin
             { r is 2..4 vs labels 1..3: 49 is never chosen and r = 4 leaves no template }
             r := FxEngine.RollDice(1, 3) + 1;
             case r of
               1: templateWordIndex := 49;
               2: templateWordIndex := 65;
               3: templateWordIndex := 113;
             end;
           end;
      79: templateWordIndex := 57;
      84: templateWordIndex := 9;
      92: templateWordIndex := 97;
      71: begin
             { 11 makes nothing }
             r := FxEngine.RollDice(1, 11);
             case r of
               1..5: templateWordIndex := 17;
               6..8: templateWordIndex := 1;
               9: templateWordIndex := 25;
               10: templateWordIndex := 81;
             end;
           end;
      70: begin
             r := FxEngine.RollDice(1, 10);
             case r of
               1..7: templateWordIndex := 89;
               8..10: templateWordIndex := 137;
             end;
           end;
    end;
    if templateWordIndex <> 0 then begin
      for j := 0 to 2 do
        nameIds[j + 1] := randItemB[templateWordIndex + j].lo;
      plus := 1;
      saveBonus := 1;
      if templateWordIndex = 97 then begin
        plus := 2;
        saveBonus := 2;
      end;
      weight := randItemW[templateWordIndex + 3];
      quantity := 0;
      value := randItemW[templateWordIndex + 4];
      for j := 1 to 3 do
        spells[j] := randItemB[templateWordIndex + 4 + j].lo;
    end;
  end;
end;

{ Appraise the current character's gems and jewelry one at a time. Sell pays val div 5 in platinum through GivePlatinum
  (the remainder is lost). Keep, offered when one more coin fits and the character has under 16 items, builds an
  itemType 70 item worth the appraisal and appends it to the inventory. Note: with an empty inventory the new item is
  assigned only to the local p and lost. CharHlp.RecalcStats runs every pass. ok is False only when there is nothing to
  appraise. }
procedure AppraiseMenu(var ok: Boolean);
var
  gemStr: String[40];
  jwlStr: String[40];
  ch: Char;
  menu: String[40];
  actionStr: String[40];
  r: Byte;
  value: Word;
  takable: Word;
  p: Types.PItemRec;
  gem: Types.PItemRec;
  exitF: Boolean;
  ext: Boolean;
  mustSell: Boolean;
begin
  ok := True;
  if (GDVars.curChar^.coins[C_Money.GEMS] = 0) and
      (GDVars.curChar^.coins[C_Money.JEWELRY] = 0) then begin
    CharHlp.PrintBottomLine('No Gems or Jewelry');
    ok := False;
  end else
    repeat
      if (GDVars.curChar^.coins[C_Money.GEMS] = 0) and (GDVars.curChar^.coins[C_Money.JEWELRY] = 0) then
        exitF := True
      else begin
        exitF := False;
        Str(GDVars.curChar^.coins[C_Money.GEMS], gemStr);
        Str(GDVars.curChar^.coins[C_Money.JEWELRY], jwlStr);
        case GDVars.curChar^.coins[C_Money.GEMS] of
          0: gemStr := '';
          1: gemStr := gemStr + ' Gem';
          else gemStr := gemStr + ' Gems';
        end;
        case GDVars.curChar^.coins[C_Money.JEWELRY] of
          0: jwlStr := '';
          1: jwlStr := jwlStr + ' piece of Jewelry';
          else jwlStr := jwlStr + ' pieces of Jewelry';
        end;
        TextRend.ClearRect(1, 1, 38, 22);
        CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, False);
        TextRend.DisplayString(1, 7, White, 'You have a fine collection of:');
        TextRend.DisplayString(1, 9, White, gemStr);
        TextRend.DisplayString(1, 10, White, jwlStr);
        menu := '';
        if GDVars.curChar^.coins[C_Money.GEMS] <> 0 then
          menu := '  Gems';
        if GDVars.curChar^.coins[C_Money.JEWELRY] <> 0 then
          menu := menu + '  Jewelry';
        menu := menu + ' Exit';
        ch := MenuCore.MenuHorizontal('Appraise : ', menu, LightMagenta, LightGreen, White, True,
                                      False, ext);
        case ch of
          'G': if GDVars.curChar^.coins[C_Money.GEMS] <> 0 then begin
              Dec(GDVars.curChar^.coins[C_Money.GEMS]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..25: value := 10;
                26..50: value := 50;
                51..70: value := 100;
                71..90: value := 500;
                91..99: value := 1000;
                100: value := 5000;
              end;
              Str(value, gemStr);
              gemStr := 'The Gem is Valued at ' + gemStr + ' gp.';
              TextRend.DisplayString(1, 12, White, gemStr);
              if Money.CheckOverload(GDVars.curChar, 1, takable)
                 or (GDVars.curChar^.numberOfItems >= 16) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen,
                                            White, True, False, ext);
              if (ch = 'K') and (not mustSell) then begin
                { a whole item record }
                GetMem(gem, SizeOf(Types.TItemRec));
                FillChar(gem^, SizeOf(Types.TItemRec), 0);
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 101;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 70;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  GDVars.curChar^.itemsAddr := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
                { the item count and weight checked for the next stone }
                CharHlp.RecalcStats(GDVars.curChar);
              end else begin
                value := value div 5;
                Money.GivePlatinum(value);
              end;
            end;
          'J': if GDVars.curChar^.coins[C_Money.JEWELRY] <> 0 then begin
              Dec(GDVars.curChar^.coins[C_Money.JEWELRY]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..10: value := Trunc(Random(900)) + 100;
                11..20: value := Trunc(Random(1000)) + 200;
                21..40: value := Trunc(Random(1500)) + 300;
                41..50: value := Trunc(Random(2500)) + 500;
                51..70: value := Trunc(Random(5000)) + 1000;
                71..90: value := Trunc(Random(6000)) + 2000;
                91..100: value := Trunc(Random(10000)) + 2000;
              end;
              Str(value, jwlStr);
              gemStr := 'The Jewel is Valued at ' + jwlStr + ' gp.';
              TextRend.DisplayString(1, 12, White, gemStr);
              if Money.CheckOverload(GDVars.curChar, 1, takable)
                 or (GDVars.curChar^.numberOfItems >= 16) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen,
                                            White, True, False, ext);
              if (ch = 'K') and (not mustSell) then begin
                { a whole item record }
                GetMem(gem, SizeOf(Types.TItemRec));
                FillChar(gem^, SizeOf(Types.TItemRec), 0);
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 214;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 70;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  GDVars.curChar^.itemsAddr := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
                { the item count and weight checked for the next stone }
                CharHlp.RecalcStats(GDVars.curChar);
              end else begin
                value := value div 5;
                Money.GivePlatinum(value);
              end;
            end;
          'E', C_Keys.NONE:
            exitF := True;
        end;
        CharHlp.RecalcStats(GDVars.curChar);
      end;
    until exitF;
end;

end.
