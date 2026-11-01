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
  TextRend, CharDisp, MoneyCal, Party, Magic;

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
  { Alt-n opens member n's items (ViewChar.AltItems), for ShopBuyMenu to run }
  MenuCore.memberKeysToCaller := True;
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
  are, #1091) lists its spells under "The scroll holds:" in the message window and asks; anything else is bought
  without asking. The spells are listed as the scribe list shows them (#1196): each a line indented under a light
  magenta heading for its level (Magic.LevelHeading), the heading given again only when the level changes, and with
  '+' before a spell the current character could learn but doesn't know (Magic.SpellLine, MARK_NOT_KNOWN). When the
  headings would not fit in the window below the title, the spells are listed without them. Each line is drawn at its
  row, so the message window's word wrap can't take away the indent. }
function WantsItem(item: Types.PItemRec): Boolean;
var
  i: Byte;
  id: Byte;
  { how many spells the scroll holds, and how many lines they take with their level headings }
  spells: Byte;
  lines: Byte;
  lastLevel: ShortInt;
  headings: Boolean;
  row: Byte;
begin
  WantsItem := True;
  if CharHlp.ItemReadable(item) and (item^.unidMask = 0) then begin
    spells := 0;
    lines := 0;
    lastLevel := 0;
    for i := 1 to SizeOf(item^.spells) do begin
      id := CharHlp.ScrollSpellAt(item, i);
      if id <> C_SPELL.NONE then begin
        Inc(spells);
        Inc(lines);
        if GameDefs.spellTable[id].levelSp <> lastLevel then begin
          lastLevel := GameDefs.spellTable[id].levelSp;
          Inc(lines);
        end;
      end;
    end;
    if spells > 0 then begin
      CharDisp.MessageText('The scroll holds:', LightGreen, True);
      { MessageText leaves the cursor on the title's row: the window holds the rows below it to TEXT_BOTTOM }
      row := GameVars.curRow;
      headings := row + lines <= C_MSG.TEXT_BOTTOM;
      lastLevel := 0;
      for i := 1 to SizeOf(item^.spells) do begin
        id := CharHlp.ScrollSpellAt(item, i);
        if id <> C_SPELL.NONE then begin
          if headings and (GameDefs.spellTable[id].levelSp <> lastLevel) then begin
            lastLevel := GameDefs.spellTable[id].levelSp;
            Inc(row);
            TextRend.DisplayString(C_MSG.TEXT_LEFT, row, LightMagenta, Magic.LevelHeading(lastLevel));
          end;
          Inc(row);
          if row <= C_MSG.TEXT_BOTTOM then
            TextRend.DisplayString(C_MSG.TEXT_LEFT, row, White,
                                   Magic.SpellLine(GameVars.curChar, id, Magic.MARK_NOT_KNOWN));
        end;
      end;
      WantsItem := MenuCore.YesNoMenu('Buy it? ', LightMagenta, LightGreen, White) = 'Y';
    end;
  end;
end;

{ Buy loop: each chosen item, once the player still wants it (WantsItem), is paid for from the current character's
  coins when they cover the price, otherwise from the pooled treasure money. Alt-n opens member n's items, who then
  buys (ViewChar.AltItems, #1195), and the list comes back. Runs until the menu is left with a key other than Buy or
  Enter. }
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
  { AltItems's result: the list is drawn again either way }
  opened: Boolean;
begin
  itemToBuy := nil;
  cursor := GameVars.treasureItems;
  { MenuVertical counts idx from 0: open on the first item, as the loot Take menu does }
  idx := 0;
  repeat
    Shop.ShopBuyItemSelection(c, itemToBuy, cursor, idx);
    done := False;
    if Party.AltMember(c) > 0 then
      opened := ViewChar.AltItems(c)
    else if (c <> 'B') and (c <> C_KEYS.ENTER) then
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
  while there is pooled money; an extended key steps through the party, and Alt-n opens member n's items
  (ViewChar.AltItems, #1195). Leaving with money still in the pool asks
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
    if ext then begin
      if ViewChar.AltItems(c) then
        CharDisp.DisplayNoncombatInterface
      else
        Party.SelectPrevNextChar(c);
    end else begin
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
