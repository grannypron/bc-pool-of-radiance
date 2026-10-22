{ Treasure collection, money menus and paying; the arithmetic under them is in MoneyCal. }
{$O+,F+}
{$I COMPILER.INC}
unit Money;

interface

uses Types;

function CheckOverload(p: Types.PCharRecord; w: LongInt; var takable: Word): Boolean;

procedure PoolMoney;

procedure ShareMoney;

procedure TakeMoneyMenu;

function InputNumberMax(max: Word; query: Types.TStr40; color: Byte): Word;

procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: Word; mType: ShortInt);

procedure DropMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);

procedure DetermineTreasure(var treasure, items: Boolean);

{ Leaving with treasure still on the table: show said in green, then ask (in white) whether to go back for it. True when
  the party goes back (the message window is cleared for the menu again), False when it leaves. }
function GoBackForIt(said, ask: String): Boolean;

procedure PayFromCreature(creature: Types.PCharRecord; gp: LongInt);

procedure PayFromPool(gp: LongInt);

{ Give creature pp platinum and then gp gold, as many as it can carry and hold (Takable); whatever does not fit goes to
  the treasure pool, which the bottom line reports. SSI capped only by weight, so a count could pass 65535 and wrap
  (#781). The coins' weight changes, so the creature's stats are recalculated. }
procedure GiveCoins(creature: Types.PCharRecord; pp, gp: Word);

{ Pay gp gold pieces from payer (WhoPays): buyer's coins or the pool's. }
procedure PayBy(buyer: Types.PCharRecord; payer: Byte; gp: LongInt);

{ Pay gp gold pieces from buyer, else the pool: True when paid; 'Not enough money.' when neither can. }
function PayGold(buyer: Types.PCharRecord; gp: LongInt): Boolean;

procedure AppraiseMenu(var ok: Boolean);

implementation

uses Crt, C_Npc, GDConsts, GDVars, TextRend, Border, CharHlp, C_Keys, C_IFC, C_Money, GameIo, MenuCore, C_MSG,
  EclMenu, CharDisp, AbilAdj, MoneyCal, Dice{$IFDEF FPC}, TpRand{$ENDIF};

{ Carrying capacity is the weight allowance plus 1500 coins, and 5000 more with a Bag of Holding readied. It is measured
  against CharHlp.RawWeight, the weight before the bag takes its share. }
function CarryingCapacity(p: Types.PCharRecord): LongInt;
begin
  if CharHlp.HasBagOfHolding(p) then
    CarryingCapacity := LongInt(AbilAdj.WeightAllowance(p)) + 1500 + 5000
  else
    CarryingCapacity := LongInt(AbilAdj.WeightAllowance(p)) + 1500;
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

{ How many coins of mType the creature can take: as many as it can carry (SpareCapacity), but no more than bring its
  count to C_Money.MAX_COINS (MoneyCal.CoinRoom). }
function Takable(p: Types.PCharRecord; mType: ShortInt): Word;
var
  n: Word;
begin
  n := Money.SpareCapacity(p);
  if MoneyCal.CoinRoom(p, mType) < n then
    n := MoneyCal.CoinRoom(p, mType);
  Takable := n;
end;

{ Pay gp gold pieces from the creature's coins, worked out in copper, with the change given back in the largest coins.
  The caller has checked the creature can pay (CreatureGold); if not, every coin goes. The coins' weight changes, so the
  creature's stats are recalculated. }
procedure PayFromCreature(creature: Types.PCharRecord; gp: LongInt);
var
  m: Types.TMoney;
  i: ShortInt;
begin
  MoneyCal.CoinsOf(creature, m);
  MoneyCal.MakeChange(MoneyCal.CopperValue(m) - gp * GDConsts.coinValuationCopper[C_Money.GOLD], C_Money.MAX_COINS,
                      m);
  for i := C_Money.COPPER to C_Money.PLATINUM do
    creature^.coins[i] := m[i];
  CharHlp.RecalcStats(creature);
end;

{ Pay gp gold pieces from the treasure pool, as PayFromCreature does; the pool's coins have no 65535 limit. }
procedure PayFromPool(gp: LongInt);
begin
  MoneyCal.MakeChange(MoneyCal.CopperValue(GDVars.treasureMoney) - gp * GDConsts.coinValuationCopper[C_Money.GOLD],
                      MaxLongInt, GDVars.treasureMoney);
end;

procedure GiveCoins(creature: Types.PCharRecord; pp, gp: Word);
var
  ppTaken: Word;
  gpTaken: Word;
begin
  ppTaken := pp;
  if ppTaken > Money.Takable(creature, C_Money.PLATINUM) then
    ppTaken := Money.Takable(creature, C_Money.PLATINUM);
  Inc(creature^.coins[C_Money.PLATINUM], ppTaken);
  { the platinum taken already weighs in the gold's Takable }
  gpTaken := gp;
  if gpTaken > Money.Takable(creature, C_Money.GOLD) then
    gpTaken := Money.Takable(creature, C_Money.GOLD);
  Inc(creature^.coins[C_Money.GOLD], gpTaken);
  if (ppTaken < pp) or (gpTaken < gp) then begin
    CharDisp.PrintBottomLine('Overloaded.  Money will be put in Pool.');
    Inc(GDVars.treasureMoney[C_Money.PLATINUM], pp - ppTaken);
    Inc(GDVars.treasureMoney[C_Money.GOLD], gp - gpTaken);
  end;
  CharHlp.RecalcStats(creature);
end;

{ Read an amount from the bottom line. Accept digits, Backspace, Return and Escape; clamp to max as digits are entered.
  Escape returns zero. The number is drawn afresh after each change: SSI kept a column that Backspace blanked one cell
  past the last digit, so the digit deleted stayed on screen (#734). }
function InputNumberMax;
var
  qLen: Byte;
  maxStr: String[5];
  s: String[6];
  ch: Char;
  v: LongInt;
  code: Integer;
  n: Word;
begin
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, color, query);
  qLen := Length(query);
  Str(max, maxStr);
  s := '';
  repeat
    { an extended key (an arrow, Delete) types nothing }
    ch := GameIo.ReadAnyKey;
    case ch of
      '0'..'9': begin
          s := Concat(s, ch);
          Val(s, v, code);
          if v > max then
            s := maxStr;
        end;
      C_Keys.BACKSPACE: if Length(s) > 0 then
          s := Copy(s, 1, Length(s) - 1);
    end;
    if (ch in ['0'..'9']) or (ch = C_Keys.BACKSPACE) then begin
      { s holds at most 6 digits }
      TextRend.PrintSpaces(qLen, 24, Black, 6);
      TextRend.DisplayString(qLen, 24, White, s);
    end;
  until (ch = C_Keys.ENTER) or (ch = C_Keys.ESC);
  TextRend.ClearBottomLine;
  if ch = C_Keys.ESC then
    n := 0
  else
    Val(s, n, code);
  InputNumberMax := n;
end;

{ Move qty coins of mType, and their weight, from giver to rcv if rcv can carry and hold them (Takable), else print
  'Overloaded'. }
procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: Word; mType: ShortInt);
begin
  if qty <= Money.Takable(rcv, mType) then begin
    giver^.coins[mType] := giver^.coins[mType] - qty;
    CharHlp.RecalcStats(giver);
    rcv^.coins[mType] := rcv^.coins[mType] + qty;
    CharHlp.RecalcStats(rcv);
  end else
    CharDisp.PrintBottomLine('Overloaded');
end;

{ Creatures with npc = 0 or C_Npc.ANIMATED_PC pour all seven money types into the treasure pool. }
procedure PoolMoney;
var
  p: Types.PCharRecord;
  i: ShortInt;
  mt: ShortInt;
begin
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = C_Npc.ANIMATED_PC) then begin
      for i := C_Money.COPPER to C_Money.JEWELRY do begin
        mt := i;
        GDVars.treasureMoney[mt] := p^.coins[mt] + GDVars.treasureMoney[mt];
      end;
      FillChar(p^.coins, SizeOf(p^.coins), 0);
      CharHlp.RecalcStats(p);
    end;
    p := p^.nextCharAddr;
  end;
end;

{ Count the creatures ShareMoney's first pass pays: those without C_Npc.FLAG, hired NPCs among them. }
function CountSharers: Byte;
var
  p: Types.PCharRecord;
  n: Byte;
begin
  p := GDVars.creatureList;
  n := 0;
  while p <> nil do begin
    if not CharHlp.IsNpc(p) then
      Inc(n);
    p := p^.nextCharAddr;
  end;
  CountSharers := n;
end;

{ Split the treasure pool. Each type's share is the pool amount div CountSharers, with the remainder held back. Pass 1
  walks the creatures with C_Npc.FLAG clear and, from jewelry (6) down to copper (0), gives each its share (or as much
  as it can take, Takable, the rest joining the remainder) plus one remainder coin when the whole outstanding remainder
  would fit. Pass 2 hands out the leftovers to every creature in list order up to what each can take, and any excess
  returns to the treasure pool. Shares and remainders are LongInt, as the pool is; with no creature to count, the pool
  is left as it is. SSI divided by the creatures PoolMoney empties (npc 0 or C_Npc.ANIMATED_PC), so with a hired NPC
  along more shares were paid than the pool held. }
procedure ShareMoney;
var
  p: Types.PCharRecord;
  cnt: Byte;
  done: Boolean;
  takable: Word;
  share: array[C_Money.COPPER..C_Money.JEWELRY] of LongInt;
  rem: array[C_Money.COPPER..C_Money.JEWELRY] of LongInt;
  i: ShortInt;
begin
  p := GDVars.creatureList;
  done := False;
  cnt := Money.CountSharers;
  if cnt = 0 then Exit;
  FillChar(share, SizeOf(share), 0);
  FillChar(rem, SizeOf(rem), 0);
  for i := C_Money.COPPER to C_Money.JEWELRY do
    if GDVars.treasureMoney[i] > 0 then begin
      share[i] := GDVars.treasureMoney[i] div cnt;
      rem[i] := GDVars.treasureMoney[i] mod cnt;
    end else begin
      share[i] := 0;
      rem[i] := 0;
    end;
  { pass 1: shares }
  while p <> nil do begin
    { C_Npc.FLAG clear }
    if not CharHlp.IsNpc(p) then
      for i := C_Money.JEWELRY downto C_Money.COPPER do
        if share[i] <= Money.Takable(p, i) then begin
          p^.coins[i] := share[i] + p^.coins[i];
          CharHlp.RecalcStats(p);
          if rem[i] > 0 then
            if rem[i] <= Money.Takable(p, i) then begin
              p^.coins[i] := p^.coins[i] + 1;
              CharHlp.RecalcStats(p);
              Dec(rem[i]);
            end;
        end else begin
          takable := Money.Takable(p, i);
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
        takable := Money.Takable(p, i);
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
  for i := C_Money.COPPER to C_Money.JEWELRY do
    GDVars.treasureMoney[i] := rem[i];
end;

{ Dropped money enters the treasure pool in a shop, temple, vault or loot menu (C_IFC.SHOP_TEMPLE, C_IFC.VAULT,
  C_IFC.LOOT). Elsewhere it is discarded. }
procedure DropMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);
begin
  p^.coins[mType] := p^.coins[mType] - qty;
  CharHlp.RecalcStats(p);
  if (GDVars.ifcState = C_IFC.LOOT) or (GDVars.ifcState = C_IFC.SHOP_TEMPLE) or (GDVars.ifcState = C_IFC.VAULT) then
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] + qty;
end;

{ Take qty of mType from the pool; a qty above the pool amount is cut to the pool's low word. The whole take is refused
  ('Overloaded') if the uncapped qty is more than p can carry or hold (Takable); there is no partial take. }
procedure TakeMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);
begin
  if qty > Money.Takable(p, mType) then
    CharDisp.PrintBottomLine('Overloaded')
  else begin
    if qty > GDVars.treasureMoney[mType] then
      qty := Word(GDVars.treasureMoney[mType]);
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] - qty;
    p^.coins[mType] := p^.coins[mType] + qty;
    CharHlp.RecalcStats(p);
  end;
end;

{ Build the money menu (copper first), prompt for an amount and take it from the treasure pool; repeat while money
  remains. The prompt limit is the available amount, at most 65535. }
procedure TakeMoneyMenu;
var
  i: ShortInt;
  mType: ShortInt;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  save: Types.PItemRec;
  idx: Integer;
  numStr: String;
  n: Word;
  exitF: Boolean;
  redraw: Boolean;
  ch: Char;
begin
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, LightGreen, '');
  idx := 0;
  repeat
    redraw := True;
    p := nil;
    sel := nil;
    for i := C_Money.JEWELRY downto C_Money.COPPER do
      if GDVars.treasureMoney[i] > 0 then begin
        if p = nil then begin
          GetMem(p, SizeOf(Types.TMenuNode));
          p^.next := nil;
        end else begin
          sel := p;
          GetMem(p, SizeOf(Types.TMenuNode));
          p^.next := sel;
        end;
        Str(GDVars.treasureMoney[i], numStr);
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
      mType := MoneyCal.ParseMoneyType(sel^.name, numStr);
      numStr := 'How much ' + numStr + 'will you take? ';
      if GDVars.treasureMoney[mType] > 65535 then
        n := 65535
      else
        n := GDVars.treasureMoney[mType];
      n := Money.InputNumberMax(n, numStr, LightGreen);
      Money.TakeMoney(GDVars.curChar, n, mType);
      MenuCore.FreeStringList(save);
      exitF := True;
      for i := C_Money.COPPER to C_Money.JEWELRY do
        if GDVars.treasureMoney[i] > 0 then
          exitF := False;
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
    if GDVars.treasureMoney[i] <> 0 then
      treasure := True;
  if GDVars.treasureItems <> nil then
    items := True;
end;

{ Appraise the current character's gems and jewelry one at a time. Sell pays the value div 5 in platinum through
  GiveCoins (the remainder is lost). Keep builds an itemType 70 item worth the appraisal and gives it to the appraiser
  or, when the appraiser has no room (16 items, or one more coin would overload them), to the first other party member
  (not a hired NPC) who has; the screen says which, and with no one to take it only Sell is offered. CharHlp.RecalcStats
  runs every pass. ok is False only when there is nothing to appraise. }
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
  gem: Types.TItemRec;
  exitF: Boolean;
  ext: Boolean;

  { True when the creature holds under 16 items and one more coin's weight would not overload it. Recalculates its stats
    first. }
  function HasRoom(creature: Types.PCharRecord): Boolean;
  begin
    CharHlp.RecalcStats(creature);
    HasRoom := (creature^.numberOfItems < 16) and not Money.CheckOverload(creature, 1, takable);
  end;

  { Offer Sell, and Keep when someone has room, for the stone just appraised: name component nameId, worth gp, until one
    is chosen. Keep appends the stone to the holder's items; Sell pays gp div 5 in platinum. }
  procedure SellOrKeep(nameId: Byte; worth: Word);
  var
    holder: Types.PCharRecord;
    c: Types.PCharRecord;
  begin
    holder := nil;
    if HasRoom(GDVars.curChar) then
      holder := GDVars.curChar
    else begin
      TextRend.DisplayString(1, 14, White, GDVars.curChar^.name + ' doesn''t have space');
      c := GDVars.creatureList;
      while (c <> nil) and (holder = nil) do begin
        { C_Npc.FLAG clear: a party member, not a hired NPC }
        if (c <> GDVars.curChar) and not CharHlp.IsNpc(c) and HasRoom(c) then
          holder := c;
        c := c^.nextCharAddr;
      end;
      if holder <> nil then
        TextRend.DisplayString(1, 15, White, 'Keep will give to ' + holder^.name)
      else
        TextRend.DisplayString(1, 15, White, 'No one else has space either');
    end;
    if holder <> nil then
      actionStr := 'Sell Keep'
    else
      actionStr := 'Sell';
    { the stone is already out of the pool, so only Sell or Keep ends the prompt: Escape or any other key sold it
      (#732) }
    repeat
      ch := MenuCore.MenuHorizontal('You can: ', actionStr, LightMagenta, LightGreen, White, True, False, ext);
    until not ext and ((ch = 'S') or ((ch = 'K') and (holder <> nil)));
    if ch = 'K' then begin
      { a whole item record }
      FillChar(gem, SizeOf(gem), 0);
      gem.next := nil;
      gem.equipped := 0;
      gem.nameIds[3] := nameId;
      gem.nameIds[2] := 0;
      gem.nameIds[1] := 0;
      gem.itemType := 70;
      gem.value := worth;
      gem.weight := 1;
      gem.unidMask := 0;
      CharHlp.AppendItemCopy(holder^.itemsAddr, @gem);
      { the holder's item count and weight }
      CharHlp.RecalcStats(holder);
    end else
      Money.GiveCoins(GDVars.curChar, worth div 5, 0);
  end;

begin
  ok := True;
  if (GDVars.curChar^.coins[C_Money.GEMS] = 0) and
      (GDVars.curChar^.coins[C_Money.JEWELRY] = 0) then begin
    CharDisp.PrintBottomLine('No Gems or Jewelry');
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
        TextRend.ClearRect(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
        CharDisp.DisplayCreatureName(GDVars.curChar, 1, 1, False);
        TextRend.DisplayString(1, 7, White, 'You have a fine collection of:');
        TextRend.DisplayString(1, 9, White, gemStr);
        TextRend.DisplayString(1, 10, White, jwlStr);
        menu := '';
        if GDVars.curChar^.coins[C_Money.GEMS] <> 0 then
          menu := 'Gems ';
        if GDVars.curChar^.coins[C_Money.JEWELRY] <> 0 then
          menu := menu + 'Jewelry ';
        menu := menu + 'Exit';
        ch := MenuCore.MenuHorizontal('Appraise: ', menu, LightMagenta, LightGreen, White, True,
                                      False, ext);
        case ch of
          'G': if GDVars.curChar^.coins[C_Money.GEMS] <> 0 then begin
              Dec(GDVars.curChar^.coins[C_Money.GEMS]);
              r := Dice.RollDice(1, 100);
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
              SellOrKeep(101, value);
            end;
          'J': if GDVars.curChar^.coins[C_Money.JEWELRY] <> 0 then begin
              Dec(GDVars.curChar^.coins[C_Money.JEWELRY]);
              r := Dice.RollDice(1, 100);
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
              SellOrKeep(214, value);
            end;
          'E', C_Keys.NONE:
            exitF := True;
        end;
        CharHlp.RecalcStats(GDVars.curChar);
      end;
    until exitF;
end;

function GoBackForIt(said, ask: String): Boolean;
begin
  TextRend.ShowMessage(LightGreen, True, said);
  TextRend.ShowMessage(White, False, ask);
  { 0-based: 1 is No }
  if EclMenu.MenuHorizontalCS('', '~Yes ~No', LightMagenta, LightGreen, White, False, False) = 1 then
    GoBackForIt := False
  else begin
    TextRend.ClearRect(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
    GoBackForIt := True;
  end;
end;

procedure PayBy(buyer: Types.PCharRecord; payer: Byte; gp: LongInt);
begin
  case payer of
    MoneyCal.PAY_CHARACTER: Money.PayFromCreature(buyer, gp);
    MoneyCal.PAY_POOL: Money.PayFromPool(gp);
  end;
end;

function PayGold(buyer: Types.PCharRecord; gp: LongInt): Boolean;
var
  payer: Byte;
begin
  payer := MoneyCal.WhoPays(buyer, gp);
  if payer = MoneyCal.PAY_NOBODY then
    CharDisp.PrintBottomLine('Not enough money.')
  else
    Money.PayBy(buyer, payer, gp);
  PayGold := payer <> MoneyCal.PAY_NOBODY;
end;

end.
