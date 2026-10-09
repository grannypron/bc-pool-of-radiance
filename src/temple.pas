{ Temple services: healing, revival, curse removal and payment. }
{$O+,F+}
unit Temple;

interface

uses Types, Crt, C_Msg, GDConsts, GDVars, TextRend, EclMenu, Money, Magic, FxEngine, C_Effect, C_Keys, C_Class,
  C_Status, C_Ifc;

procedure TempleMainMenu;

implementation

var
  treasureMoney: Types.TMoney absolute GDVars.treasureMoney;

{ ConfirmCureAnyway: Print "<name> <msg>", ask "cast cure anyway: " Y/N, clear the message window and return the key }
function ConfirmCureAnyway(msg: String): Char;
begin
  CharHlp.PrintNameString(GDVars.curChar, msg, 0, False);
  ConfirmCureAnyway := MenuCore.YesNoMenu('cast cure anyway: ', LightMagenta, LightGreen, White);
  CharHlp.ClearMessageWindow;
end;

{ ConfirmCureCost: Show "<spell> will only cost <cost> gold pieces." and ask to pay. On Y, pay from the current
  character's coins if they cover it, else from the pooled treasure, else print "Not enough money." and return N; a paid
  cure prints "<name> is cured." Returns Y or N. }
function ConfirmCureCost(spell: String; cost: Word): Char;
var
  c: Char;
  charGold: Word;
  pooled: LongInt;
begin
  spell := spell + ' will only cost ' + CharHlp.WordToString(cost) + ' gold pieces.';
  TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen,
                                True, spell);
  c := MenuCore.YesNoMenu('pay for cure ', LightMagenta, White, LightGreen);
  if c = 'Y' then begin
    charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
    if cost <= charGold then begin
      Dec(charGold, cost);
      Money.SetCreatureCoinsInGold(charGold);
    end else begin
      pooled := Money.CoinValueInGold(treasureMoney);
      if cost <= pooled then begin
        Dec(pooled, cost);
        Money.SetTreasureCoinsInGold(pooled);
      end else begin
        CharHlp.PrintBottomLine('Not enough money.');
        c := 'N';
      end;
    end;
  end;
  if c = 'Y' then begin
    CharHlp.ClearMessageWindow;
    CharHlp.PrintNameString(GDVars.curChar, 'is cured.', 0, True);
  end;
  ConfirmCureCost := c;
end;

{ CureBlindness: Removes C_Effect.BLIND (33) for 1000 gp; asks first if the character is not blind }
procedure CureBlindness;
var
  effect: Types.PEffectRec;
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BLIND, effect) then
    c := Temple.ConfirmCureAnyway('is not blind.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Cure Blindness', 1000);
    if c = 'Y' then
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
  end;
end;

{ CureDisease: Checks for effects 31, 34, 43, 44, 50 and 57 (C_Effect.HELPLESS, C_Effect.DISEASED, C_Effect.DISEASE_STR,
  C_Effect.DISEASE_HP, C_Effect.ROT_NO_HEAL, C_Effect.MUMMY_ROT); for 1000 gp removes all six with the effect lock set }
procedure CureDisease;
var
  effect: Types.PEffectRec;
  s: String;
  c: Char;
  i: Byte;
  found: Boolean;
begin
  found := False;
  s := '';
  c := 'Y';
  { 6 = High(cureDiseaseEffects) }
  for i := 1 to 6 do
    if CharHlp.HasEffect(GDVars.curChar, GDConsts.cureDiseaseEffects[i], effect) then
      found := True;
  if not found then
    c := Temple.ConfirmCureAnyway('is not Diseased.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Cure Disease', 1000);
    if c = 'Y' then begin
      GDVars.effectLock := 1;
      { 6 = High(cureDiseaseEffects) }
      for i := 1 to 6 do
        FxEngine.RemoveEffect(GDVars.curChar, GDConsts.cureDiseaseEffects[i], nil);
      GDVars.effectLock := 0;
    end;
  end;
end;

{ CureWounds: spell 1/2/3 = CLW 1d8 100 gp / CSW 2d8+1 350 gp / CCW 3d8+3 600 gp; the RestoreHitPoints result is
  ignored }
procedure CureWounds(spell: Byte);
var
  hp: Byte;
  c: Char;
  restored: Boolean;
begin
  case spell of
    1: begin
         c := Temple.ConfirmCureCost('Cure Light Wounds', 100);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(1, 8);
           restored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
    2: begin
         c := Temple.ConfirmCureCost('Cure Serious Wounds', 350);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(2, 8) + 1;
           restored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
    3: begin
         c := Temple.ConfirmCureCost('Cure Critical Wounds', 600);
         if c = 'Y' then begin
           hp := FxEngine.RollDice(3, 8) + 3;
           restored := FxEngine.RestoreHitPoints(GDVars.curChar, hp, False);
         end;
       end;
  end;
end;

{ RaiseDead: For 5500 gold, raise a dead or animated character (paying for anyone else changes nothing). Remove
  animation and poison under the effect lock, set one hit point, C_Status.OKAY and enabled, and lower constitution by
  one unless it is 0. hpLoss is hpMax - hpRolled (0 if negative); if the reduced constitution is still 14 or more, it is
  divided by the summed per-level constitution bonus (skipped when that sum is 0) and taken off hpMax when constitution
  is below 17 or the character has fighter levels. }
procedure RaiseDead;
var
  effect: Types.PEffectRec;
  s: String;
  c: Char;
  wasDead: Boolean;
  hpLoss: Byte;
  hpBonus: Byte;
  i: ShortInt;
  creature: Types.PCharRecord;
begin
  creature := GDVars.curChar;
  wasDead := False;
  s := '';
  c := 'Y';
  if (creature^.status = C_Status.DEAD) or (creature^.status = C_Status.ANIMATED) then
    wasDead := True;
  if not wasDead then
    c := Temple.ConfirmCureAnyway('is not dead.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Raise Dead', 5500);
    if c = 'Y' then begin
      if wasDead then begin
        GDVars.effectLock := 1;
        FxEngine.RemoveEffect(creature, C_Effect.ANIMATE_DEAD, nil);
        FxEngine.RemoveEffect(creature, C_Effect.POISONED, nil);
        GDVars.effectLock := 0;
        creature^.hpCur := 1;
        creature^.status := C_Status.OKAY;
        creature^.enabled := 1;
        if creature^.conCur > 0 then
          Dec(creature^.conCur);
        if creature^.hpMax > creature^.hpRolled then
          hpLoss := creature^.hpMax - creature^.hpRolled
        else
          hpLoss := 0;
        hpBonus := 0;
        if creature^.conCur >= 14 then begin
          { 7 = High(classLevels) }
          for i := 0 to 7 do
            if creature^.classLevels[i] > 0 then begin
              if i = C_Class.LEVEL_FIGHTER then
                Inc(hpBonus, (creature^.conCur - 14) * creature^.classLevels[i])
              else if creature^.conCur > 15 then
                Inc(hpBonus, creature^.classLevels[i] * 2)
              else
                Inc(hpBonus, creature^.classLevels[i]);
            end;
          if hpBonus > 0 then
            hpLoss := hpLoss div hpBonus;
          if (creature^.conCur < 17) or (creature^.classLevels[C_Class.LEVEL_FIGHTER] > 0) then
            Dec(creature^.hpMax, hpLoss);
        end;
      end;
    end;
  end;
end;

{ NeutralizePoison: Checks for C_Effect.POISONED (55); for 1000 gp removes C_Effect.POISONED, C_Effect.SLOW_POISON_END
  (22) and C_Effect.SLOW_POISON_HIT (15), in that order, with the effect lock set }
procedure NeutralizePoison;
var
  effect: Types.PEffectRec;
  s: String;
  c: Char;
  found: Boolean;
begin
  found := False;
  s := '';
  c := 'Y';
  if CharHlp.HasEffect(GDVars.curChar, C_Effect.POISONED, effect) then
    found := True;
  if not found then
    c := Temple.ConfirmCureAnyway('is not poisoned.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Neutralize Poison', 1000);
    if c = 'Y' then begin
      GDVars.effectLock := 1;
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.POISONED, nil);
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_END, nil);
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_HIT, nil);
      GDVars.effectLock := 0;
    end;
  end;
end;

{ RemoveCurse: Looks for a cursed item in the inventory, else for C_Effect.BESTOW_CURSE (36); for 3500 gp sets
  dsTargetCreaturePtr[1] to the current character and calls the Remove Curse spell handler, Magic.RemoveCurseSpell
  (spell 43) }
procedure RemoveCurse;
var
  cursed: Boolean;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  cursed := False;
  item := GDVars.curChar^.itemsAddr;
  while (item <> nil) and (not cursed) do begin
    if item^.cursed <> 0 then
      cursed := True;
    item := item^.next;
  end;
  if not cursed then
    if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BESTOW_CURSE, effect) then
      c := Temple.ConfirmCureAnyway('is not cursed.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Remove Curse', 3500);
    if c = 'Y' then begin
      GDVars.dsTargetCreaturePtr[1] := GDVars.curChar;
      Magic.RemoveCurseSpell;
    end;
  end;
end;

{ StoneToFlesh: C_Status.STONED (7), 2000 gp; if still stoned after paying, status := C_Status.OKAY, enabled := 1, hpCur
  := 1 }
procedure StoneToFlesh;
var
  effect: Types.PEffectRec;
  s: String;
  c: Char;
begin
  s := '';
  c := 'Y';
  if GDVars.curChar^.status <> C_Status.STONED then
    c := Temple.ConfirmCureAnyway('is not stoned.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Stone to Flesh', 2000);
    if c = 'Y' then
      if GDVars.curChar^.status = C_Status.STONED then begin
        GDVars.curChar^.status := C_Status.OKAY;
        GDVars.curChar^.enabled := 1;
        GDVars.curChar^.hpCur := 1;
      end;
  end;
end;

{ HealMenu: Allocates a 10-node string list with MenuCore.AllocStringList, fills it from templeSpells, runs
  MenuCore.MenuVertical over it and dispatches idx 0..8 to the cures (idx 9 'Exit', or a #0 key, leaves) }
procedure HealMenu;
var
  list: Types.PItemRec;
  sel: Types.PItemRec;
  { Seeded True; MenuVertical draws the page and clears it. }
  redraw: Boolean;
  i: Byte;
  idx: Integer;
  done: Boolean;
  s: String[40];
  c: Char;
begin
  done := False;
  list := nil;
  sel := nil;
  MenuCore.AllocStringList(10, list);
  sel := list;
  i := 1;
  while list <> nil do begin
    list^.name := GDConsts.templeSpells[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  list := sel;
  TextRend.ClearRect(0, 24, 39, 24);
  redraw := True;
  Border.DrawWindow(1, 1, 38, 22, 0, White, '');
  { the top divider row }
  Border.DrawWindow(1, 1, 38, 1, 0, White, '');
  repeat
    s := GDVars.curChar^.name + ', how can we help you?';
    TextRend.DisplayString(1, 1, White, s);
    Border.DrawWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0, White, '');
    c := MenuCore.MenuVertical('', 'Heal Exit', LightMagenta, LightGreen, White, 2, 4, 38, 15, list, False, redraw, idx,
                               sel);
    case c of
      'H', C_Keys.ENTER:
        case idx of
          0: Temple.CureBlindness;
          1: Temple.CureDisease;
          2: Temple.CureWounds(1);
          3: Temple.CureWounds(2);
          4: Temple.CureWounds(3);
          5: Temple.NeutralizePoison;
          6: Temple.RaiseDead;
          7: Temple.RemoveCurse;
          8: Temple.StoneToFlesh;
          9: done := True;
        end;
      C_Keys.NONE: done := True;
    end;
  until done;
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(0, 0, 39, 24);
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ TempleMainMenu: Run the temple menu using the shared treasure state. H and P are told apart from the extended Up and
  Down scan codes by ext; the G and O codes (Home and End) cycle characters. }
procedure TempleMainMenu;
var
  c: Char;
  done: Boolean;
  ext: Boolean;
  menu: String[40];
  hasMoney: Boolean;
  hasItems: Boolean;
  ynIdx: Byte;
  apprOk: Boolean;
begin
  GDVars.ifcState := C_Ifc.SHOP_TEMPLE;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayParty(GDVars.curChar);
  FillChar(treasureMoney, SizeOf(Types.TMoney), 0);
  GDVars.treasureMoneyFlag := False;
  done := False;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      menu := 'Heal View Take Pool Share Appraise Exit'
    else
      menu := 'Heal View Pool Appraise Exit';
    c := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, ext);
    case c of
      'H': if not ext then Temple.HealMenu;
      'V': ViewChar.ViewCharMenu(ext);
      'T': Money.TakeMoneyMenu;
      'P': if not ext then Money.PoolMoney;
      'S': Money.ShareMoney;
      'A': Money.AppraiseMenu(apprOk);
      'E': begin
             Money.DetermineTreasure(hasMoney, hasItems);
             if hasMoney then begin
               menu := '~Yes ~No';
               TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT,
                 C_Msg.TEXT_BOTTOM, LightGreen, True,
'As you leave a priest says, "Excuse me but you have left some money here" ');
               TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                             LightGreen, True,
                                             'Do you want to go back and retrieve your money?');
               ynIdx := EclMenu.MenuHorizontalCS('', menu, LightMagenta, LightGreen, White, False, False);
               if ynIdx = 1 then
                 done := True
               else
                 TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
             end else
               done := True;
           end;
      C_Keys.HOME: ViewChar.SelectPrevNextChar(c);
      C_Keys.END_KEY: ViewChar.SelectPrevNextChar(c);
    end;
    case c of
      'B', 'T': CharHlp.DisplayNoncombatInterface;
      'A': if apprOk then CharHlp.DisplayNoncombatInterface;
    end;
    CharHlp.DisplayParty(GDVars.curChar);
  until done;
end;

begin
end.
