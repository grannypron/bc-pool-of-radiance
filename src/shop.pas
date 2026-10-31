{ Shop menus, item selection and purchases. Shop inventory uses the shared treasure state. }
{$O+,F+}
{$I COMPILER.INC}
unit Shop;

interface

uses Types;

procedure ShopMainMenu;

{ Runs the counter menu shared by shops and temples. command supplies the Buy
  or Heal action, keeping this unit independent of Temple. Leaving money on the
  counter prompts the player before exiting. }
procedure CounterMenu(atTemple: Boolean; command: Types.TMenuAction);

procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);

implementation

uses Crt, C_MSG, C_SPELL, GameDefs, GameVars, EclMenu, ViewChar, Money, C_KEYS, C_IFC, Border, CharHlp, MenuCore,
  TextRend, CharDisp, MoneyCal, Party;

{ Temporarily formats each item name as a 30-column menu row with a right-aligned
  price, runs the Buy menu, then restores the normal labels. cursor and idx
  preserve the selection between calls. }
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
  p := GameVars.treasureItems;
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
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, 'Shop');
  head := GameVars.treasureItems;
  c := MenuCore.MenuVertical('Items: ', 'Buy', LightMagenta, LightGreen, White, 1, 4, 38, 22, head,
                             True, redraw, idx, cursor);
  itemToBuy := cursor;
  CharHlp.LabelItems(GameVars.treasureItems);
end;

{ Give the current character a copy of item (CharHlp.AddToInventory, which joins it to a stack it matches while Auto
  Join is on) and recalculate its stats. When the character cannot carry it, print that it is overloaded and set
  failed instead. }
procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);
begin
  if ViewChar.CannotCarryItem(GameVars.curChar, item) then begin
    CharDisp.PrintBottomLine('OverLoaded');
    failed := True;
  end else begin
    failed := False;
    CharHlp.AddToInventory(GameVars.curChar, item);
    CharHlp.RecalcStats(GameVars.curChar);
  end;
end;

{ True when the player buys item after seeing it. A scroll whose spells can be read (identified, as the magic shop's
  are, #1091) lists its spells in the message window, one a line, and asks; anything else is bought without asking. }
function WantsItem(item: Types.PItemRec): Boolean;
var
  i: Byte;
  id: Byte;
  first: Boolean;
begin
  WantsItem := True;
  if CharHlp.ItemReadable(item) and (item^.unidMask = 0) then begin
    first := True;
    for i := 1 to SizeOf(item^.spells) do begin
      id := CharHlp.ScrollSpellAt(item, i);
      if id <> C_SPELL.NONE then begin
        if first then
          CharDisp.MessageText('The scroll holds:', LightGreen, True);
        first := False;
        { each spell from the start of the next line, as CharDisp.PrintTwoLines starts its second }
        GameVars.curCol := C_MSG.TEXT_LEFT;
        Inc(GameVars.curRow);
        CharDisp.MessageText(GameDefs.spellNames[id], White, False);
      end;
    end;
    if not first then
      WantsItem := MenuCore.YesNoMenu('Buy it? ', LightMagenta, LightGreen, White) = 'Y';
  end;
end;

{ Buy loop: each chosen item, once the player still wants it (WantsItem), is paid for from the current character's
  coins when they cover the price, otherwise from the pooled treasure money. Runs until the menu is left with a key
  other than Buy or Enter. }
procedure ShopBuyMenu;
var
  itemToBuy: Types.PItemRec;
  c: Char;
  done: Boolean;
  price: Word;
  payer: Byte;
  failed: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
begin
  itemToBuy := nil;
  cursor := GameVars.treasureItems;
  { MenuVertical counts idx from 0: open on the first item, as the loot Take menu does }
  idx := 0;
  repeat
    Shop.ShopBuyItemSelection(c, itemToBuy, cursor, idx);
    done := False;
    if (c <> 'B') and (c <> C_KEYS.ENTER) then
      done := True
    else if Shop.WantsItem(itemToBuy) then begin
      price := itemToBuy^.value;
      payer := MoneyCal.WhoPays(GameVars.curChar, price);
      if payer = MoneyCal.PAY_NOBODY then
        CharDisp.PrintBottomLine('Not enough money.')
      else begin
        Shop.GiveItemCopyToCreature(itemToBuy, failed);
        if not failed then
          Money.PayBy(GameVars.curChar, payer, price);
      end;
    end;
  until done;
end;

{ The counter menu: Buy or Heal (command), View, Take, Pool, Share, Appraise and Exit, with Take and Share offered only
  while there is pooled money; an extended key steps through the party. Leaving with money still in the pool asks
  whether to go back for it. }
procedure CounterMenu(atTemple: Boolean; command: Types.TMenuAction);
var
  menu: String[40];
  first: String[4];
  ext: Boolean;
  done: Boolean;
  c: Char;
  hasMoney: Boolean;
  hasItems: Boolean;
  apprOk: Boolean;
begin
  GameVars.ifcState := C_IFC.SHOP_TEMPLE;
  CharDisp.DisplayNoncombatInterface;
  CharDisp.DisplayParty(GameVars.curChar);
  FillChar(GameVars.treasureMoney, SizeOf(Types.TMoney), 0);
  done := False;
  if atTemple then
    first := 'Heal'
  else begin
    first := 'Buy';
    CharHlp.LabelItems(GameVars.treasureItems);
  end;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      menu := first + ' View Take Pool Share Appraise Exit'
    else
      menu := first + ' View Pool Appraise Exit';
    c := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, ext);
    { an extended key only steps the character: its scan code is no command letter (H is the up arrow, P the down
      arrow, Delete S, which shared the pool, F7 A, #731) }
    if ext then
      Party.SelectPrevNextChar(c)
    else begin
      case c of
        'B': if not atTemple then command;
        'H': if atTemple then command;
        'V': ViewChar.ViewCharMenu(ext);
        'T': if hasMoney then
               Money.TakeMoneyMenu;
        'P': Money.PoolMoney;
        'S': if hasMoney then
               Money.ShareMoney;
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
      end;
      case c of
        'B', 'T': CharDisp.DisplayNoncombatInterface;
        'A': if apprOk then CharDisp.DisplayNoncombatInterface;
      end;
    end;
    CharDisp.DisplayParty(GameVars.curChar);
  until done;
end;

procedure ShopMainMenu;
begin
  Shop.CounterMenu(False, Shop.ShopBuyMenu);
end;

end.
