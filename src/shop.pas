{ Shop menus, item selection and purchases. Shop inventory uses the shared treasure state. }
{$O+,F+}
unit Shop;

interface

uses Types;

procedure ShopMainMenu;

{ The counter menu a shop and a temple share: Buy (a shop) or Heal (a temple), then View, Take, Pool, Share,
  Appraise and Exit. Leaving with money on the counter asks first whether to go back for it. }
procedure CounterMenu(atTemple: Boolean);

procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);

implementation

uses Crt, C_Msg, GDConsts, GDVars, EclMenu, ViewChar, Money, C_Keys, C_Ifc, Border, CharHlp, MenuCore, TextRend,
  Temple;

var
  treasureMoney: Types.TMoney absolute GDVars.treasureMoney;

{ Rewrite every shop item name as a 30-column line, name at the left and price right-justified (a zero price is bumped
  to 1), run the vertical Buy menu over the item list, then rebuild the real names with CharHlp.PrintItemString. Returns
  the menu key in c and the highlighted item in itemToBuy; cursor and idx carry the menu position from one call to the
  next. }
procedure ShopBuyItemSelection(var c: Char; var itemToBuy: Types.PItemRec; var cursor: Types.PItemRec;
                               var idx: Integer);
var
  head: Types.PItemRec;
  p: Types.PItemRec;
  tmp: String[16];
  s: String[30];
  lenv: Byte;
  i: Byte;
  { Seeded True; MenuVertical draws the page and clears it. }
  redraw: Boolean;
begin
  redraw := True;
  p := GDVars.treasureItems;
  while p <> nil do begin
    { 30 blanks, the full width of s }
    s := '                              ';
    if p^.value = 0 then p^.value := 1;
    Str(LongInt(p^.value), tmp);
    lenv := Length(tmp);
    for i := 1 to lenv do
      s[SizeOf(s) - 1 - lenv + i] := tmp[i];
    { the name is cut short of the price, with a blank between, so it neither runs past s nor over the price }
    lenv := Length(p^.name);
    if lenv > SizeOf(s) - 2 - Length(tmp) then
      lenv := SizeOf(s) - 2 - Length(tmp);
    for i := 1 to lenv do
      s[i] := p^.name[i];
    p^.name := s;
    p^.name[0] := Chr(SizeOf(s) - 1);
    p := p^.next;
  end;
  Border.DrawWindow(1, 1, 38, 22, 0, White, 'Shop');
  head := GDVars.treasureItems;
  c := MenuCore.MenuVertical('Items: ', 'Buy', LightMagenta, LightGreen, White, 1, 4, 38, 22, head,
                             True, redraw, idx, cursor);
  itemToBuy := cursor;
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
end;

{ Append a copy of item to the current character's item list and recalculate its stats. When the character cannot carry
  it, print that it is overloaded and set failed instead. }
procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  if ViewChar.CannotCarryItem(GDVars.curChar, item) then begin
    CharHlp.PrintBottomLine('OverLoaded');
    failed := True;
  end else begin
    failed := False;
    p := GDVars.curChar^.itemsAddr;
    if p = nil then begin
      GetMem(p, SizeOf(Types.TItemRec));
      p^ := item^;
      p^.next := nil;
      GDVars.curChar^.itemsAddr := p;
    end else begin
      while p^.next <> nil do
        p := p^.next;
      GetMem(q, SizeOf(Types.TItemRec));
      q^ := item^;
      q^.next := nil;
      p^.next := q;
    end;
    CharHlp.RecalcStats(GDVars.curChar);
  end;
end;

{ Buy loop: each chosen item is paid for from the current character's coins when they cover the price, otherwise from
  the pooled treasure money. Runs until the menu is left with a key other than Buy or Enter. }
procedure ShopBuyMenu;
var
  itemToBuy: Types.PItemRec;
  c: Char;
  done: Boolean;
  price: Word;
  charGold: LongInt;
  pooled: LongInt;
  failed: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
begin
  itemToBuy := nil;
  cursor := GDVars.treasureItems;
  { MenuVertical counts idx from 0: open on the first item, as the loot Take menu does }
  idx := 0;
  repeat
    Shop.ShopBuyItemSelection(c, itemToBuy, cursor, idx);
    if (c <> 'B') and (c <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      price := itemToBuy^.value;
      charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
      if price <= charGold then begin
        Shop.GiveItemCopyToCreature(itemToBuy, failed);
        if not failed then begin
          Money.PayFromCreature(GDVars.curChar, price);
        end;
      end else begin
        pooled := Money.CoinValueInGold(treasureMoney);
        if price <= pooled then begin
          Shop.GiveItemCopyToCreature(itemToBuy, failed);
          if not failed then begin
            Money.PayFromPool(price);
          end;
        end else
          CharHlp.PrintBottomLine('Not enough Money.');
      end;
    end;
  until done;
end;

{ Main shop menu: buy, view, take, pool, share and appraise, with Take and Share offered only while there is pooled
  money. Leaving with money still in the pool asks whether to go back for it. }
procedure CounterMenu(atTemple: Boolean);
var
  menu: String[40];
  first: String[4];
  ext: Boolean;
  done: Boolean;
  c: Char;
  hasMoney: Boolean;
  hasItems: Boolean;
  apprOk: Boolean;
  p: Types.PItemRec;
begin
  GDVars.ifcState := C_Ifc.SHOP_TEMPLE;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayParty(GDVars.curChar);
  FillChar(treasureMoney, SizeOf(Types.TMoney), 0);
  GDVars.treasureMoneyFlag := False;
  done := False;
  if atTemple then
    first := 'Heal'
  else begin
    first := 'Buy';
    p := GDVars.treasureItems;
    while p <> nil do begin
      CharHlp.PrintItemString(nil, p, 0, 0, False, False);
      p := p^.next;
    end;
  end;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      menu := first + ' View Take Pool Share Appraise Exit'
    else
      menu := first + ' View Pool Appraise Exit';
    c := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, ext);
    { extended keys come back as letters too: H is the up arrow, B is F8, P the down arrow }
    case c of
      'B': if not atTemple and not ext then Shop.ShopBuyMenu;
      'H': if atTemple and not ext then Temple.HealMenu;
      'V': ViewChar.ViewCharMenu(ext);
      'T': Money.TakeMoneyMenu;
      'P': if not ext then Money.PoolMoney;
      'S': Money.ShareMoney;
      'A': Money.AppraiseMenu(apprOk);
      'E': begin
             Money.DetermineTreasure(hasMoney, hasItems);
             if atTemple then
               done := not hasMoney or
                       not Money.GoBackForIt(
                         'As you leave a priest says, "Excuse me but you have left some money here" ',
                         'Do you want to go back and retrieve your money?')
             else
               done := not hasMoney or
                       not Money.GoBackForIt(
                         'As you Leave the Shopkeeper says, "Excuse me but you have Left Some Money here."  ',
                         'Do you want to go back and get your Money?');
           end;
      C_Keys.HOME, C_Keys.END_KEY: ViewChar.SelectPrevNextChar(c);
    end;
    case c of
      'B', 'T': CharHlp.DisplayNoncombatInterface;
      'A': if apprOk then CharHlp.DisplayNoncombatInterface;
    end;
    CharHlp.DisplayParty(GDVars.curChar);
  until done;
end;

procedure ShopMainMenu;
begin
  Shop.CounterMenu(False);
end;

end.
