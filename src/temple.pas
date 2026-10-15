{ Temple services: healing, revival, curse removal and payment. }
{$O+,F+}
unit Temple;

interface


procedure TempleMainMenu;

{ The Heal menu: the cures and spells the temple sells, for the current character. }
procedure HealMenu;

implementation

uses Types, Crt, C_Msg, GDConsts, GDVars, TextRend, EclMenu, Money, Magic, FxEngine, C_Effect, C_Keys, C_Class,
  C_Status, C_Ifc, Stats, Border, CharHlp, MenuCore, ViewChar, StrUtil, Shop;

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
begin
  spell := spell + ' will only cost ' + StrUtil.NumStr(cost) + ' gold pieces.';
  TextRend.ShowMessage(LightGreen, True, spell);
  c := MenuCore.YesNoMenu('pay for cure ', LightMagenta, White, LightGreen);
  if c = 'Y' then begin
    if not Money.PayGold(cost) then
      c := 'N';
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

{ CureDisease: for 1000 gp, remove the current character's disease effects (FxEngine.RemoveDiseases), asking first when
  there are none }
procedure CureDisease;
var
  c: Char;
begin
  c := 'Y';
  if not FxEngine.HasDisease(GDVars.curChar) then
    c := Temple.ConfirmCureAnyway('is not Diseased.');
  if c = 'Y' then
    if Temple.ConfirmCureCost('Cure Disease', 1000) = 'Y' then
      FxEngine.RemoveDiseases(GDVars.curChar);
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
  one unless it is 0. hpMax loses the hit points that point was worth, the Con table's bonus at the old Constitution
  less the bonus at the new over every hit die (CharHlp.ConHpTotal), keeping at least 1. }
procedure RaiseDead;
var
  effect: Types.PEffectRec;
  s: String;
  c: Char;
  wasDead: Boolean;
  hpLoss: Integer;
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
        Stats.Count(creature, Stats.RAISED, 1);
        if creature^.conCur > 0 then begin
          Dec(creature^.conCur);
          hpLoss := CharHlp.ConHpTotal(creature, creature^.conCur + 1) - CharHlp.ConHpTotal(creature, creature^.conCur);
          if hpLoss >= creature^.hpMax then
            hpLoss := creature^.hpMax - 1;
          if hpLoss > 0 then
            Dec(creature^.hpMax, hpLoss);
        end;
      end;
    end;
  end;
end;

{ NeutralizePoison: Checks for C_Effect.POISONED (55); for 1000 gp removes C_Effect.POISONED, C_Effect.SLOW_POISON_END
  (22) and C_Effect.SLOW_POISON_HIT (15), in that order, with the effect lock set. Poison kills on the spot, so a
  character the poison left dead is brought back with 1 hp, as RaiseDead does but without its cost in Constitution and
  hit points. A dead character still under Slow Poison was kept up through the poison and died of something else (a
  wound, bleeding out), so it stays dead: that needs RaiseDead. }
procedure NeutralizePoison;
var
  effect: Types.PEffectRec;
  s: String;
  c: Char;
  found: Boolean;
  slowed: Boolean;
begin
  found := False;
  s := '';
  c := 'Y';
  if CharHlp.HasEffect(GDVars.curChar, C_Effect.POISONED, effect) then
    found := True;
  slowed := CharHlp.HasEffect(GDVars.curChar, C_Effect.SLOW_POISON_END, effect) or
            CharHlp.HasEffect(GDVars.curChar, C_Effect.SLOW_POISON_HIT, effect);
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
      if found and not slowed and (GDVars.curChar^.status = C_Status.DEAD) then begin
        GDVars.curChar^.hpCur := 1;
        GDVars.curChar^.status := C_Status.OKAY;
        GDVars.curChar^.enabled := 1;
      end;
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
  { open on the first cure; MenuVertical also brings a vertTop left by an earlier menu back to it }
  idx := 0;
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
begin
  Shop.CounterMenu(True);
end;

end.
