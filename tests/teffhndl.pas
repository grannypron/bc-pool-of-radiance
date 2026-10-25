{ Tests for the effect handlers the 2026-10-25 review consolidated (EffHndlr): Resist Fire and Resist Cold
  (ResistElement), the immunities to fire, cold and electricity (ElementImmunity), the elves' and half-elves' resistance
  to sleep and charm (SleepCharmResist), the racial to-hit and armor bonuses by the foe's name (NamedIn,
  RacialFoeBonus), Mirror Image's roll (FxEngine.ImageStruck), and Healed from Unconscious (eff 78) called with no node,
  as FxEngine.RestoreHitPoints calls it, whose retry SSI read through nil. And the immunity check leaves no effect
  pending, so magic resistance passes over later damage of no magic (POR-0219, #940). }
{$I COMPILER.INC}
program TEffHndl;

uses Types, C_EFFECT, C_IFC, C_SPELL, GameVars, FxEngine, EffHndlr, CharHlp, TestKit;

const
  TRIES = 400;

var
  c: Types.PCharRecord;
  foe: Types.PCharRecord;
  effect: Types.PEffectRec;
  i: Integer;
  n: Integer;
  image: Types.TEffectRec;

function NewCreature: Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  GetMem(p, SizeOf(Types.TCharRecord));
  FillChar(p^, SizeOf(Types.TCharRecord), 0);
  GetMem(p^.combatAddr, SizeOf(Types.TCombatRec));
  FillChar(p^.combatAddr^, SizeOf(Types.TCombatRec), 0);
  NewCreature := p;
end;

{ Post damage 9 of element elem and save roll 10; return the damage left after handler, the save roll in save. }
function After(elem: Byte; var save: Integer; fire: Boolean): Integer;
begin
  GameVars.elementMask := elem;
  GameVars.pendingDamage := 9;
  GameVars.pendingEffectId := 0;
  FxEngine.gSaveRoll := 10;
  if fire then
    EffHndlr.EffResistFire(c, nil, False)
  else
    EffHndlr.EffResistCold(c, nil, False);
  save := FxEngine.gSaveRoll;
  After := GameVars.pendingDamage;
end;

{ The damage of 9, element elem, that the immunity effId's handler leaves. }
function ImmuneLeft(effId, elem: Byte): Integer;
begin
  GameVars.elementMask := elem;
  GameVars.pendingDamage := 9;
  GameVars.pendingEffectId := 0;
  case effId of
    C_EFFECT.NO_FIRE: EffHndlr.EffNoFire(c, nil, False);
    C_EFFECT.NO_COLD: EffHndlr.EffNoCold(c, nil, False);
    C_EFFECT.IMMUNE_MM: EffHndlr.EffImmuneMM(c, nil, False);
  end;
  ImmuneLeft := GameVars.pendingDamage;
end;

{ How many of TRIES pending effId the elves' (elf True) or half-elves' handler clears. }
function Resisted(elf: Boolean; effId: Byte): Integer;
var
  k: Integer;
begin
  k := 0;
  for i := 1 to TRIES do begin
    GameVars.pendingEffectId := effId;
    if elf then
      EffHndlr.EffElfResist(c, nil, False)
    else
      EffHndlr.EffHalfElfResist(c, nil, False);
    if GameVars.pendingEffectId = 0 then
      Inc(k);
  end;
  Resisted := k;
end;

{ What the creature's to-hit or armor handler (effId) does to an attack roll of 10 against or by foe. }
function RollChange(effId: Byte): Integer;
begin
  GameVars.gAttackRoll := 10;
  case effId of
    C_EFFECT.DWARF_THAC0: EffHndlr.EffDwarfThac0(c, nil, False);
    C_EFFECT.GNOME_THAC0: EffHndlr.EffGnomeThac0(c, nil, False);
    C_EFFECT.DWARF_AC_GIANT: EffHndlr.EffDwarfAcGiant(c, nil, False);
  end;
  RollChange := Integer(GameVars.gAttackRoll) - 10;
end;

procedure SetFoe(name: Types.TName15; charType, size: Byte);
begin
  foe^.name := name;
  foe^.charType := charType;
  foe^.iconDimensions := size;
end;

begin
  TestKit.Start('TEFFHNDL');
  GameVars.creatureList := nil;
  GameVars.ifcState := 0;
  GameVars.effectLock := 0;
  GameVars.currentSpellBeing := C_SPELL.NONE;
  c := NewCreature;
  foe := NewCreature;
  GameVars.curChar := c;

  { Resist Fire and Resist Cold }
  TestKit.CheckEqualsL(4, After(C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC, n, True), 'Resist Fire halves fire');
  TestKit.CheckEqualsL(13, n, 'and gives +3 to the save');
  TestKit.CheckEqualsL(9, After(C_EFFECT.ELEM_COLD, n, True), 'but not cold');
  TestKit.CheckEqualsL(10, n, 'nor a save against it');
  TestKit.CheckEqualsL(4, After(C_EFFECT.ELEM_COLD, n, False), 'Resist Cold halves cold');
  TestKit.CheckEqualsL(13, n, 'and gives +3 to the save');
  TestKit.CheckEqualsL(9, After(C_EFFECT.ELEM_FIRE, n, False), 'but not fire');

  { the immunities }
  TestKit.CheckEqualsL(0, ImmuneLeft(C_EFFECT.NO_FIRE, C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC), 'immune to fire');
  TestKit.CheckEqualsL(9, ImmuneLeft(C_EFFECT.NO_FIRE, C_EFFECT.ELEM_COLD), 'not to cold');
  TestKit.CheckEqualsL(0, ImmuneLeft(C_EFFECT.NO_COLD, C_EFFECT.ELEM_COLD), 'immune to cold');
  TestKit.CheckEqualsL(9, ImmuneLeft(C_EFFECT.NO_COLD, C_EFFECT.ELEM_ACID), 'not to acid');
  TestKit.CheckEqualsL(0, ImmuneLeft(C_EFFECT.IMMUNE_MM, C_EFFECT.ELEM_ELEC), 'immune to electricity');
  TestKit.CheckEqualsL(9, ImmuneLeft(C_EFFECT.IMMUNE_MM, C_EFFECT.ELEM_MAGIC), 'not to other magic');

  { sleep and charm resistance: 90% and 30% }
  n := Resisted(True, C_EFFECT.SLEEP);
  TestKit.Check((n > TRIES * 8 div 10) and (n < TRIES), 'an elf resists sleep about 90% of the time');
  n := Resisted(True, C_EFFECT.CHARM);
  TestKit.Check((n > TRIES * 8 div 10) and (n < TRIES), 'and charm');
  TestKit.CheckEqualsL(0, Resisted(True, C_EFFECT.PARALYSIS), 'and not paralysis');
  n := Resisted(False, C_EFFECT.SLEEP);
  TestKit.Check((n > TRIES div 5) and (n < TRIES * 2 div 5), 'a half-elf resists sleep about 30% of the time');
  TestKit.CheckEqualsL(0, Resisted(False, C_EFFECT.POISONED), 'and not poison');

  { the racial bonuses by name }
  c^.combatAddr^.other := foe;
  SetFoe('GRISHNAK', 0, 1);
  TestKit.CheckEqualsL(1, RollChange(C_EFFECT.DWARF_THAC0), 'a dwarf hits Grishnak (type 0) at +1');
  TestKit.CheckEqualsL(0, RollChange(C_EFFECT.GNOME_THAC0), 'a gnome does not');
  SetFoe('KOBOLD', 1, 1);
  TestKit.CheckEqualsL(1, RollChange(C_EFFECT.GNOME_THAC0), 'a gnome hits a kobold at +1');
  TestKit.CheckEqualsL(0, RollChange(C_EFFECT.DWARF_THAC0), 'a dwarf does not');
  SetFoe('ORC', 1, 2);
  TestKit.CheckEqualsL(0, RollChange(C_EFFECT.DWARF_THAC0), 'nor a two-tile orc');
  SetFoe('ORC', 1, 1);
  TestKit.CheckEqualsL(1, RollChange(C_EFFECT.DWARF_THAC0), 'but a one-tile one');
  GameVars.curChar := foe;
  SetFoe('TROLL', 10, 1);
  TestKit.CheckEqualsL(-4, RollChange(C_EFFECT.DWARF_AC_GIANT), 'a troll attacks a dwarf at -4');
  SetFoe('ETTIN', 1, 2);
  TestKit.CheckEqualsL(-4, RollChange(C_EFFECT.DWARF_AC_GIANT), 'and so does an ettin');
  SetFoe('ORC', 1, 1);
  TestKit.CheckEqualsL(0, RollChange(C_EFFECT.DWARF_AC_GIANT), 'an orc does not');
  GameVars.curChar := c;

  { Mirror Image: 1d(images + 1) rolls 1 with no image left }
  image.strength := 0;
  n := 0;
  for i := 1 to 50 do
    if FxEngine.ImageStruck(@image) then
      Inc(n);
  TestKit.CheckEqualsL(0, n, 'no image is struck when none is left');

  { the immunity check leaves no effect pending, and magic resistance then lets acid through (POR-0219, #940) }
  TestKit.Check(not FxEngine.EffectImmune(c, C_EFFECT.SLEEP), 'a creature with no wards is not immune to sleep');
  TestKit.CheckEqualsL(0, GameVars.pendingEffectId, 'and no effect is left pending');
  n := 0;
  for i := 1 to 100 do begin
    GameVars.elementMask := C_EFFECT.ELEM_ACID;
    GameVars.pendingDamage := 9;
    EffHndlr.EffMagicRes50(c, nil, False);
    if GameVars.pendingDamage = 9 then
      Inc(n);
  end;
  TestKit.CheckEqualsL(100, n, 'magic resistance never stops acid after an immunity check');
  n := 0;
  for i := 1 to 100 do begin
    GameVars.elementMask := C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC;
    GameVars.pendingDamage := 9;
    EffHndlr.EffMagicRes50(c, nil, False);
    if GameVars.pendingDamage = 9 then
      Inc(n);
  end;
  TestKit.Check((n > 20) and (n < 80), 'but resists magical fire about half the time');

  { Healed from Unconscious with no node: a revival that fails retries in a minute, at strength 0 }
  GameVars.ifcState := C_IFC.COMBAT;
  GameVars.arenaCount := 0;
  EffHndlr.EffHealWake(c, nil, True);
  TestKit.Check(CharHlp.HasEffect(c, C_EFFECT.HEAL_WAKE, effect), 'a failed revival with no node retries');
  if CharHlp.HasEffect(c, C_EFFECT.HEAL_WAKE, effect) then begin
    TestKit.CheckEqualsL(0, effect^.strength, 'at strength 0');
    TestKit.CheckEqualsL(1, effect^.duration, 'in a minute');
  end;
  GameVars.ifcState := 0;
  TestKit.Done;
end.
