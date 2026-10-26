{ Temple services: healing, revival, curse removal and payment. }
{$O+,F+}
{$I COMPILER.INC}
unit Temple;

interface

{ The temple: its counter and Heal menu, at prices by mode, MoneyCal.TEMPLE_FULL_PRICE or TEMPLE_TENTH_OFF (the value
  the script stored in C_GBVM.ENTER_TEMPLE). }
procedure TempleMainMenu(mode: Byte);

{ The Heal menu: the cures and spells the temple sells, for the current character. }
procedure HealMenu;

implementation

uses Types, Crt, C_MSG, GameVars, TextRend, EclMenu, Money, Magic, FxEngine, C_EFFECT, C_KEYS, C_STATUS, C_RACE, Stats,
  Border, CharHlp, MenuCore, ViewChar, StrUtil, Shop, CharDisp, Dice, ClassCal, AbilAdj, MoneyCal;

var
  { the prices TempleMainMenu was entered with, for ConfirmCureCost }
  priceMode: Byte;

{ ConfirmCureAnyway: Print "<name> <msg>", ask "cast cure anyway: " Y/N, clear the message window and return the key }
function ConfirmCureAnyway(msg: String): Char;
begin
  CharDisp.PrintNameString(GameVars.curChar, msg, 0, False);
  ConfirmCureAnyway := MenuCore.YesNoMenu('cast cure anyway: ', LightMagenta, LightGreen, White);
  CharDisp.ClearMessageWindow;
end;

{ Quotes the adjusted temple price and asks for payment. Pay from the current
  character first, then the pooled treasure. Returns Y only when payment succeeds. }
function PayCureCost(spell: String; cost: Word): Char;
var
  c: Char;
begin
  cost := MoneyCal.TemplePrice(cost, priceMode);
  spell := spell + ' will only cost ' + StrUtil.NumStr(cost) + ' gold pieces.';
  TextRend.ShowMessage(LightGreen, True, spell);
  c := MenuCore.YesNoMenu('pay for cure ', LightMagenta, White, LightGreen);
  if c = 'Y' then begin
    if not Money.PayGold(GameVars.curChar, cost) then
      c := 'N';
  end;
  PayCureCost := c;
end;

{ ReportCure: "<name> <msg>" in a cleared message window until a key. }
procedure ReportCure(msg: String);
begin
  CharDisp.ClearMessageWindow;
  CharDisp.PrintNameString(GameVars.curChar, msg, 0, True);
end;

{ ConfirmCureCost: PayCureCost, and a paid cure prints "<name> is cured." (ReportCure). Returns Y or N. }
function ConfirmCureCost(spell: String; cost: Word): Char;
var
  c: Char;
begin
  c := Temple.PayCureCost(spell, cost);
  if c = 'Y' then
    Temple.ReportCure('is cured.');
  ConfirmCureCost := c;
end;

{ CureBlindness: Removes C_EFFECT.BLIND (33) for 1000 gp; asks first if the character is not blind }
procedure CureBlindness;
var
  effect: Types.PEffectRec;
  c: Char;
begin
  c := 'Y';
  if not CharHlp.HasEffect(GameVars.curChar, C_EFFECT.BLIND, effect) then
    c := Temple.ConfirmCureAnyway('is not blind.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Cure Blindness', 1000);
    if c = 'Y' then
      FxEngine.RemoveEffect(GameVars.curChar, C_EFFECT.BLIND, nil);
  end;
end;

{ CureDisease: for 1000 gp, remove the current character's disease effects (FxEngine.RemoveDiseases), asking first when
  there are none }
procedure CureDisease;
var
  c: Char;
begin
  c := 'Y';
  if not FxEngine.HasDisease(GameVars.curChar) then
    c := Temple.ConfirmCureAnyway('is not Diseased.');
  if c = 'Y' then
    if Temple.ConfirmCureCost('Cure Disease', 1000) = 'Y' then
      if FxEngine.RemoveDiseases(GameVars.curChar) then ;
end;

{ Explains why wound healing would fail for the current character. Returns an
  empty string when RestoreHitPoints can heal them. }
function NoWoundCure: String;
var
  effect: Types.PEffectRec;
begin
  NoWoundCure := '';
  case GameVars.curChar^.status of
    C_STATUS.OKAY, C_STATUS.ANIMATED, C_STATUS.UNCONSCIOUS, C_STATUS.DYING:
      if CharHlp.HasEffect(GameVars.curChar, C_EFFECT.ROT_NO_HEAL, effect) then
        NoWoundCure := 'has mummy rot, which stops healing.'
      else if GameVars.curChar^.hpCur >= GameVars.curChar^.hpMax then
        NoWoundCure := 'is not wounded.';
    C_STATUS.DEAD_STATUS: NoWoundCure := 'is dead.';
    C_STATUS.STONED: NoWoundCure := 'is stoned.';
  else
    NoWoundCure := 'cannot be healed.';
  end;
end;

{ Sells Cure Light, Serious, or Critical Wounds. Warn before charging for a cure
  that cannot help, and only report success when hit points were restored
  (POR-0226). }
procedure CureWounds(spell: Byte);
var
  hp: Byte;
  c: Char;
  name: Types.TStr40;
  cost: Word;
  bonus: Byte;
  why: Types.TStr40;
begin
  case spell of
    1: begin
         name := 'Cure Light Wounds';
         cost := 100;
         bonus := 0;
       end;
    2: begin
         name := 'Cure Serious Wounds';
         cost := 350;
         bonus := 1;
       end;
    3: begin
         name := 'Cure Critical Wounds';
         cost := 600;
         bonus := 3;
       end;
  else
    Exit;
  end;
  c := 'Y';
  why := Temple.NoWoundCure;
  if why <> '' then
    c := Temple.ConfirmCureAnyway(why);
  if c = 'Y' then
    if Temple.PayCureCost(name, cost) = 'Y' then begin
      { spell d8, plus the bonus }
      hp := Dice.RollDice(spell, 8) + bonus;
      if FxEngine.RestoreHitPoints(GameVars.curChar, hp, False) then
        Temple.ReportCure('is cured.')
      else
        Temple.ReportCure('is not helped.');
    end;
end;

{ Raises a dead or animated character for 5500 gold. Elves cannot be raised
  (#61), and poison must be neutralized first (#423, #751). After payment, roll
  resurrection survival. Failure leaves the character permanently gone. Success
  restores one hit point and costs one Constitution point, including the
  resulting maximum-hit-point adjustment. }
procedure RaiseDead;
var
  effect: Types.PEffectRec;
  c: Char;
  wasDead: Boolean;
  hpLoss: Integer;
  creature: Types.PCharRecord;
begin
  creature := GameVars.curChar;
  wasDead := False;
  c := 'Y';
  if (creature^.status = C_STATUS.DEAD_STATUS) or (creature^.status = C_STATUS.ANIMATED) then
    wasDead := True;
  if not wasDead then
    c := Temple.ConfirmCureAnyway('is not dead.')
  else if creature^.race = C_RACE.ELF then begin
    CharDisp.PrintTwoLines('RAISE DEAD cannot restore ' + creature^.name + '.', 'Elven souls lie beyond its reach.');
    c := 'N';
  end else if CharHlp.HasEffect(creature, C_EFFECT.POISONED, effect) then begin
    CharDisp.PrintNameString(creature, 'is poisoned, and RAISE DEAD cannot help.', 0, True);
    c := 'N';
  end;
  if c = 'Y' then begin
    c := Temple.PayCureCost('Raise Dead', 5500);
    if c = 'Y' then begin
      if not wasDead then
        Temple.ReportCure('is cured.')
      else begin
        GameVars.effectLock := 1;
        FxEngine.RemoveEffect(creature, C_EFFECT.ANIMATE_DEAD, nil);
        GameVars.effectLock := 0;
        { the resurrection survival roll, which SSI never made (#752): a failure is dead for good }
        if Dice.RollDice(1, 100) > AbilAdj.ConResurrectionSurvival(creature^.conCur) then begin
          creature^.status := C_STATUS.GONE;
          creature^.enabled := 0;
          creature^.hpCur := 0;
          Temple.ReportCure('does not survive.');
        end else begin
          creature^.hpCur := 1;
          creature^.status := C_STATUS.OKAY;
          creature^.enabled := 1;
          Stats.Count(creature, Stats.RAISED, 1);
          { Constitution goes no lower than AbilAdj.SCORE_MIN (#615) }
          if creature^.conCur > AbilAdj.SCORE_MIN then begin
            Dec(creature^.conCur);
            hpLoss := ClassCal.ConHpTotal(creature, creature^.conCur + 1) -
                      ClassCal.ConHpTotal(creature, creature^.conCur);
            if hpLoss >= creature^.hpMax then
              hpLoss := creature^.hpMax - 1;
            if hpLoss > 0 then
              Dec(creature^.hpMax, hpLoss);
          end;
          Temple.ReportCure('is cured.');
        end;
      end;
    end;
  end;
end;

{ Removes poison and both Slow Poison effects for 1000 gold. A character killed
  directly by poison returns with one hit point. Someone who died from another
  cause while Slow Poison was active remains dead and still needs Raise Dead. }
procedure NeutralizePoison;
var
  effect: Types.PEffectRec;
  c: Char;
  found: Boolean;
  slowed: Boolean;
begin
  found := False;
  c := 'Y';
  if CharHlp.HasEffect(GameVars.curChar, C_EFFECT.POISONED, effect) then
    found := True;
  slowed := CharHlp.HasEffect(GameVars.curChar, C_EFFECT.SLOW_POISON_END, effect) or
            CharHlp.HasEffect(GameVars.curChar, C_EFFECT.SLOW_POISON_HIT, effect);
  if not found then
    c := Temple.ConfirmCureAnyway('is not poisoned.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Neutralize Poison', 1000);
    if c = 'Y' then begin
      GameVars.effectLock := 1;
      FxEngine.RemoveEffect(GameVars.curChar, C_EFFECT.POISONED, nil);
      FxEngine.RemoveEffect(GameVars.curChar, C_EFFECT.SLOW_POISON_END, nil);
      FxEngine.RemoveEffect(GameVars.curChar, C_EFFECT.SLOW_POISON_HIT, nil);
      GameVars.effectLock := 0;
      if found and not slowed and (GameVars.curChar^.status = C_STATUS.DEAD_STATUS) then begin
        GameVars.curChar^.hpCur := 1;
        GameVars.curChar^.status := C_STATUS.OKAY;
        GameVars.curChar^.enabled := 1;
      end;
    end;
  end;
end;

{ RemoveCurse: Looks for a cursed item in the inventory, else for C_EFFECT.BESTOW_CURSE (36); for 3500 gp sets
  spellTargets[1] to the current character and calls the Remove Curse spell handler, Magic.SpellRemoveCurse
  (spell 43) }
procedure RemoveCurse;
var
  cursed: Boolean;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  c: Char;
begin
  c := 'Y';
  cursed := False;
  item := GameVars.curChar^.itemsAddr;
  while (item <> nil) and (not cursed) do begin
    if item^.cursed <> 0 then
      cursed := True;
    item := item^.next;
  end;
  if not cursed then
    if not CharHlp.HasEffect(GameVars.curChar, C_EFFECT.BESTOW_CURSE, effect) then
      c := Temple.ConfirmCureAnyway('is not cursed.');
  if c = 'Y' then begin
    c := Temple.ConfirmCureCost('Remove Curse', 3500);
    if c = 'Y' then begin
      GameVars.spellTargets[1] := GameVars.curChar;
      Magic.SpellRemoveCurse;
    end;
  end;
end;

{ Restores a stoned character for 2000 gold. After payment, roll system shock as
  required by the tabletop spell (#1004). Failure kills the character; success
  restores them with one hit point. }
procedure StoneToFlesh;
var
  c: Char;
  creature: Types.PCharRecord;
begin
  creature := GameVars.curChar;
  c := 'Y';
  if creature^.status <> C_STATUS.STONED then
    c := Temple.ConfirmCureAnyway('is not stoned.');
  if c = 'Y' then
    if Temple.PayCureCost('Stone to Flesh', 2000) = 'Y' then
      if creature^.status <> C_STATUS.STONED then
        Temple.ReportCure('is cured.')
      else if not AbilAdj.SurvivesSystemShock(creature^.conCur, Dice.RollDice(1, 100)) then begin
        { flesh again, and dead: as a death is marked out of combat }
        creature^.status := C_STATUS.DEAD_STATUS;
        creature^.enabled := 0;
        creature^.hpCur := 0;
        Stats.Death(creature);
        Temple.ReportCure('DOESN''T SURVIVE THE TRANSFORMATION.');
      end else begin
        creature^.status := C_STATUS.OKAY;
        creature^.enabled := 1;
        creature^.hpCur := 1;
        Temple.ReportCure('is cured.');
      end;
end;

{ HealMenu: Allocates a 10-node string list with MenuCore.AllocStringList, fills it from templeSpells, runs
  MenuCore.MenuVertical over it and dispatches idx 0..8 to the cures (idx 9 'Exit', or a #0 key, leaves) }
procedure HealMenu;
const
  templeSpells: array[1..10] of String[20] = (
    'Cure Blindness',
    'Cure Disease',
    'Cure Light Wounds',
    'Cure Serious Wounds',
    'Cure Critical Wounds',
    'Neutralize Poison',
    'Raise Dead',
    'Remove Curse',
    'Stone to Flesh',
    'Exit');
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
  MenuCore.AllocStringList(10, list);
  sel := list;
  i := 1;
  while list <> nil do begin
    list^.name := templeSpells[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  list := sel;
  TextRend.ClearRect(0, 24, 39, 24);
  redraw := True;
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
  { the top divider row }
  Border.DrawWindow(1, 1, 38, 1, 0, White, '');
  { open on the first cure; MenuVertical also brings a verticalMenuTop left by an earlier menu back to it }
  idx := 0;
  repeat
    s := GameVars.curChar^.name + ', how can we help you?';
    TextRend.DisplayString(1, 1, White, s);
    Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
    c := MenuCore.MenuVertical('', 'Heal Exit', LightMagenta, LightGreen, White, 2, 4, 38, 15, list, False, redraw, idx,
                               sel);
    case c of
      'H', C_KEYS.ENTER:
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
      C_KEYS.NONE: done := True;
    end;
  until done;
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(0, 0, 39, 24);
  CharDisp.DisplayNoncombatInterface;
  CharDisp.DisplayParty(GameVars.curChar);
end;

{ TempleMainMenu: Run the temple counter (Shop.CounterMenu, on the shared treasure state) with HealMenu as its Heal
  command, at the prices mode names (priceMode). }
procedure TempleMainMenu(mode: Byte);
begin
  priceMode := mode;
  Shop.CounterMenu(True, Temple.HealMenu);
end;

end.
