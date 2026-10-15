{ Effect handlers for spells, items and creature abilities. Each handler receives the creature, the effect node or item
  concerned, and whether the effect is being removed or the item unreadied; it works through shared combat state such as
  GDVars.pendingDamage, the attack roll and GDVars.gSaveRoll. }
{$O+,F+}
unit EffHndlr;

interface

uses Types;

{ Install the effect handlers in GDVars.effectFns. Magic installs slot 88 (dragon breath) itself. }
procedure InitEffectHandlers;

procedure EffBless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffUndeadSlayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffTrainStart(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffFlameTongue(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffTrainManual(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ eff 8, 45 }
procedure EffProtEvil(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ eff 9, 46 }
procedure EffProtGood(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffResistCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ eff 12, 38 }
procedure EffExtraStr(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffFriends(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSlowPoisonHit(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffShield(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffGnomeThac0(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffResistFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSilence(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSlowPoisonEnd(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSpiritHammer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffInvisible(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDwarfThac0(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffMirrorImage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffEnfeeble(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffStinkCough(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffAnimateDead(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBlind(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDiseased(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffAlliedPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBestowCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBlinking(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHasted(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffCastStink(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffProtMissiles(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSlowed(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDiseaseStr(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDiseaseHp(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDwarfAcGiant(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffGnomeAcBug(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffRotNoHeal(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ eff 31, 51, 52, 53 }
procedure EffHelpless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffRingInvis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffMummyRot(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffImmobile(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffTrollRegen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffRingFireRes(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffConRegen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPoisonHit0(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPoisonHit4(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPoisonHit2(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffKreenPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffGhoulPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDriderPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPoisonHitM2(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDustDisappear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffCamouflage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBloodDrain(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBloodAttach(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ eff 77 (bite attach) }
procedure EffBiteHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHealWake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffFireTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffAcidSquirt(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDragonFear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffMummyFear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPetrifyGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffCharmGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDrainOne(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDrainTwo(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffRotTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDisplaced(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffConPsnSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffImmuneMM(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfBash(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffFightOn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNeedSilver(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffConSpellSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffRegen3(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffCanFightOn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffTrollBurn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffTrollHeal(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffTrollReturn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffGaseous(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffKreenDodge(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffMagicRes50(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffMagicRes85(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffElfResist(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNoSleepCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNoParalysis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNoCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNoParaPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNoFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffEfreetiFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfElec(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfPierce(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfMagical(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHolyWater(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNeedMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBoulderDodge(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffAnhkhegAcid(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffMummyFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSilverMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfElfResist(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNoCharmPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffGazeBlock(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ eff 128, 129, 130, 133, 134, 136, 138, 139 }
procedure EffReadyItem(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffGauntlets(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffAlignedWeapon(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBoulder(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHammerGone(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ The handler for effects whose presence is all that matters: eff 5, 13, 16, 19, 24, 27, 54, 55, 60, 63, 92, 127 }
procedure EffNull(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

implementation

uses C_Item, C_Npc, C_Terr, C_Save, C_Cond, GDConsts, GDVars, CbtActs, ClassCal, FxEngine, Debug, C_Effect, C_Equip,
  C_Race, C_Class, C_Status, C_Ifc, C_Align, C_Spell, CbtMap, CharHlp, Pathing, TextRend, StrUtil;

const


  { TBaseItemRec.wpnClass melee damage type. Pierce and bash are distinct bits, so wpnClass and (WPN_PIERCE or WPN_BASH)
    tests pierce-or-bash; slash is zero. }
  WPN_SLASH = 0;
  WPN_PIERCE = $01;
  WPN_BASH = $80;




{ Nullify the attack or effect: zero GDVars.pendingDamage and GDVars.pendingEffectId. effId 0 always matches; otherwise
  only when effId is the id under the immunity check (pendingEffectId). }
procedure NullifyAttack(effId: Byte);
begin
  if (effId = 0) or (GDVars.pendingEffectId = effId) then begin
    GDVars.pendingDamage := 0;
    GDVars.pendingEffectId := 0;
  end;
end;

{ FxEngine.AddEffect unless the effect lock is on; returns True when the effect was added. The parameter order differs
  from FxEngine.AddEffect (strength before minutes), and onRemove is always True. }
function AddEffectIfNoLock(creature: Types.PCharRecord; effId, strength: Byte; minutes: Word): Boolean;
begin
  if GDVars.effectLock <> 0 then
    AddEffectIfNoLock := False
  else begin
    AddEffectIfNoLock := True;
    FxEngine.AddEffect(creature, effId, minutes, strength, True);
  end;
end;

{ Print "<name> <msg>", then set the status (dead, stoned or gone), disable the creature with 0 HP, remove the effects
  that end at 0 HP, run the C_Cond.HP_ZERO effects and, if it is still disabled, hand it to CbtMap.CreatureDowned. Then
  pause, clear the message window and, out of combat, redisplay the party. The message prints first: for a creature
  already dead, stoned or gone it is all that happens. }
procedure InflictStatusMsg(creature: Types.PCharRecord; status: Byte; msg: Types.TStr40);
begin
  CharHlp.PrintNameString(creature, msg, 10, False);
  case creature^.status of
    C_Status.STONED, C_Status.DEAD, C_Status.GONE: Exit;
  end;
  creature^.status := status;
  creature^.enabled := 0;
  creature^.hpCur := 0;
  FxEngine.RemoveEffectsHp0(creature);
  FxEngine.TriggerEffectsWithCondition(C_Cond.HP_ZERO, creature);
  if creature^.enabled = 0 then
    CbtMap.CreatureDowned(creature);
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
  if GDVars.ifcState <> C_Ifc.COMBAT then
    CharHlp.DisplayParty(GDVars.curChar);
end;

{ Bless (eff 1) }

procedure EffBless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Inc(GDVars.dsCurrentMorale, 5);
  Inc(GDVars.gAttackRoll);
end;

{ Curse (eff 2) }

procedure EffCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.dsCurrentMorale < 5 then
    GDVars.dsCurrentMorale := 0
  else
    Dec(GDVars.dsCurrentMorale, 5);
  Dec(GDVars.gAttackRoll);
end;

{ Undead slaying weapon (eff 3) }

procedure EffUndeadSlayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  { undead }
  if GDVars.dsOtherCreatureCurrentPtr^.charType = 4 then begin
    Inc(GDVars.gAttackRoll, 2);
    Inc(GDVars.pendingDamage, 2);
  end;
end;

{ Start training with a Manual of Bodily Health (eff 4): add eff 7 for 43200 minutes }

procedure EffTrainStart(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  CharHlp.PrintNameString(creature, 'starts to train', 10, True);
  FxEngine.AddEffect(creature, C_Effect.TRAIN_MANUAL, 43200, 255, True);
end;

{ Flame Tongue weapon (eff 6) }

procedure EffFlameTongue(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  bonus: Byte;
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  case GDVars.dsOtherCreatureCurrentPtr^.charType of
    { regenerating }
    10: bonus := 1;
    { cold-based / avian }
    9, 12: bonus := 2;
    { undead }
    4: bonus := 3;
  else
    bonus := 0;
  end;
  Inc(GDVars.gAttackRoll, bonus);
  Inc(GDVars.pendingDamage, bonus);
  { magical fire }
  GDVars.elementMask := 9;
end;

{ Manual of Bodily Health training done (eff 7): +1 Constitution and the matching hit-point change, the Con table's
  bonus at the new Constitution less the bonus at the old over every hit die (CharHlp.ConHpTotal), with hpMax capped at
  255; at Constitution 20 or more, add eff 62 (regeneration) for 60 minutes instead. }

procedure EffTrainManual(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  hpGain: Integer;
begin
  CharHlp.PrintNameString(creature, 'is hardier', 10, True);
  Inc(creature^.conCur);
  if creature^.conCur >= 20 then begin
    FxEngine.AddEffect(creature, C_Effect.CON_REGEN, 60, 255, True);
    Exit;
  end;
  hpGain := CharHlp.ConHpTotal(creature, creature^.conCur) - CharHlp.ConHpTotal(creature, creature^.conCur - 1);
  if hpGain > 255 - creature^.hpMax then
    hpGain := 255 - creature^.hpMax;
  if hpGain > 0 then begin
    Inc(creature^.hpMax, hpGain);
    Inc(creature^.hpCur, hpGain);
  end;
end;

{ Protection from Evil (eff 8, 45) }

procedure EffProtEvil(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.curChar^.alignment = C_Align.LAWFUL_EVIL) or
      (GDVars.curChar^.alignment = C_Align.NEUTRAL_EVIL) or
      (GDVars.curChar^.alignment = C_Align.CHAOTIC_EVIL) then begin
    Inc(GDVars.gSaveRoll, 2);
    Dec(GDVars.gAttackRoll, 2);
  end;
end;

{ Protection from Good (eff 9, 46) }

procedure EffProtGood(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.curChar^.alignment = C_Align.LAWFUL_GOOD) or
      (GDVars.curChar^.alignment = C_Align.NEUTRAL_GOOD) or
      (GDVars.curChar^.alignment = C_Align.CHAOTIC_GOOD) then begin
    Inc(GDVars.gSaveRoll, 2);
    Dec(GDVars.gAttackRoll, 2);
  end;
end;

{ Resist Cold (eff 10) }

procedure EffResistCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 2 <> 0 then begin
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
    Inc(GDVars.gSaveRoll, 3);
  end;
end;

{ Charm (eff 11). strength packs: bit 5 = applied mark, bit 6 = saved hostility, bit 7 = charmer side }

procedure EffCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then begin
    creature^.hostile := (Types.PEffectRec(p)^.strength and $40) div 64;
    if creature^.npc = C_Npc.ANIMATED_PC then
      creature^.npc := 0;
  end else begin
    if Types.PEffectRec(p)^.strength and $20 = 0 then begin
      Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength + $20 + creature^.hostile * 64;
      creature^.hostile := Types.PEffectRec(p)^.strength div 128;
      creature^.quickfight := 1;
      { C_Npc.FLAG clear }
      if not CharHlp.IsNpc(creature) then
        creature^.npc := C_Npc.ANIMATED_PC;
      creature^.combatAddr^.other := nil;
      CharHlp.CountTeams;
    end;
    GDVars.dsCurrentMorale := 100;
  end;
end;

{ Enlarge and Strength (eff 12, 38). Sets Strength to the value stored in this node, then applies the strongest other
  Enlarge or Strength node, which takes over the Strength to restore. A node whose strength byte is above $7F is
  ignored. }

procedure EffExtraStr(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  base: Byte;
  exc: Byte;
  bestBase: Byte;
  bestExc: Byte;
  q: Types.PEffectRec;
  best: Types.PEffectRec;
begin
  if Types.PEffectRec(p)^.strength > $7F then Exit;
  FxEngine.StrengthEffectToStrength(p, base, exc);
  creature^.strCur := base;
  creature^.strExc := exc;
  best := nil;
  bestBase := 0;
  bestExc := 0;
  q := creature^.effectsAddr;
  while q <> nil do begin
    if (q^.id = C_Effect.ENLARGE) or (q^.id = C_Effect.STRENGTH) then
      if q <> Types.PEffectRec(p) then begin
        FxEngine.StrengthEffectToStrength(q, base, exc);
        if (base > bestBase) or ((bestBase = 18) and (exc > bestExc)) then begin
          bestBase := base;
          bestExc := exc;
          best := q;
        end;
      end;
    q := q^.next;
  end;
  if best <> nil then begin
    Types.PEffectRec(best)^.strength := FxEngine.StrengthModifier(creature^.strCur, creature^.strExc);
    creature^.strCur := bestBase;
    creature^.strExc := bestExc;
  end;
end;

{ Friends (eff 14) }

procedure EffFriends(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  creature^.chaCur := Types.PEffectRec(p)^.strength;
end;

{ Slow Poison periodic damage (eff 15): re-arm for 10 minutes and deal 1 damage while HP > 1 }

procedure EffSlowPoisonHit(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_Effect.SLOW_POISON_HIT, Types.PEffectRec(p)^.strength, 10) then
    if creature^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(creature, 1, 0, False);
      if GDVars.ifcState <> C_Ifc.COMBAT then
        CharHlp.DisplayParty(GDVars.curChar);
    end;
end;

{ Shield (eff 17) }

procedure EffShield(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  { 60-biased AC 3 }
  if creature^.acCur < 57 then
    creature^.acCur := 57;
  Inc(GDVars.gSaveRoll);
  { Magic Missile }
  if GDVars.dsCurrentSpellBeing = 15 then
    GDVars.pendingDamage := 0;
end;

{ Gnome THAC0 bonus (eff 18) }

procedure EffGnomeThac0(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  { charType 0 or 1: the monster data gives some listed foes type 0 (HOBGOBLIN LDR, GRISHNAK) }
  if GDVars.dsOtherCreatureCurrentPtr^.charType <= 1 then
    if GDVars.dsOtherCreatureCurrentPtr^.iconDimensions = 1 then
      { 5 = High(gnomeFoes) }
      for i := 1 to 5 do
        if GDVars.dsOtherCreatureCurrentPtr^.name = GDConsts.gnomeFoes[i] then
          Inc(GDVars.gAttackRoll);
end;

{ Resist Fire (eff 20) }

procedure EffResistFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 1 <> 0 then begin
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
    Inc(GDVars.gSaveRoll, 3);
  end;
end;

{ Silence 15' (eff 21) }

procedure EffSilence(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintNameString(creature, 'is silenced', 10, True);
  creature^.combatAddr^.itemUseAllowed := 0;
  creature^.combatAddr^.castAllowed := 0;
end;

{ Slow Poison expiration (eff 22): a creature still poisoned (eff 55) dies; eff 15 is removed under the effect lock }

procedure EffSlowPoisonEnd(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if CharHlp.HasEffect(creature, C_Effect.POISONED, effect) then
    EffHndlr.InflictStatusMsg(creature, C_Status.DEAD, 'dies from poison');
  GDVars.effectLock := 1;
  FxEngine.RemoveEffect(creature, C_Effect.SLOW_POISON_HIT, nil);
  GDVars.effectLock := 0;
end;

{ Spiritual Hammer (eff 23). The hammer is an C_Item.HAMMER whose nameIds[3] is 243. Removal deletes the hammer;
  otherwise one is created (+1, special = eff 137) when missing and the creature has fewer than 16 items. }

procedure EffSpiritHammer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  found: Byte;
begin
  item := creature^.itemsAddr;
  found := 0;
  while (item <> nil) and (found = 0) do
    if (item^.itemType = C_Item.HAMMER) and (item^.nameIds[3] = 243) then
      found := 1
    else
      item := item^.next;
  if removed and (item <> nil) then
    CharHlp.RemoveItem(creature, item);
  if not removed then
    if found = 0 then
      if creature^.numberOfItems < 16 then begin
        GetMem(item, SizeOf(Types.TItemRec));
        FillChar(item^, SizeOf(Types.TItemRec), 0);
        item^.itemType := C_Item.HAMMER;
        item^.nameIds[2] := 20;
        item^.nameIds[3] := 243;
        item^.plus := 1;
        item^.effect := C_Effect.SPIRIT_HAMMER;
        item^.special := C_Effect.SPIRIT_HAMMER_GONE;
        CharHlp.AddItemCopy(creature, item);
        FreeMem(item, SizeOf(Types.TItemRec));
        CharHlp.PrintNameString(creature, 'Gains an item', 10, True);
      end;
  CharHlp.RecalcStats(creature);
end;

{ Invisibility (eff 25) }

procedure EffInvisible(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if not CharHlp.HasEffect(GDVars.curChar, C_Effect.SEE_INVISIBLE, effect) then
    GDVars.dsCurrentSuppressTargetingFlag := 1;
  Dec(GDVars.gAttackRoll, 4);
end;

{ Dwarf THAC0 bonus (eff 26) }

procedure EffDwarfThac0(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  { charType 0 or 1: the monster data gives some listed foes type 0 (HOBGOBLIN LDR, GRISHNAK) }
  if GDVars.dsOtherCreatureCurrentPtr^.charType <= 1 then
    if GDVars.dsOtherCreatureCurrentPtr^.iconDimensions = 1 then
      { 11 = High(dwarfFoes) }
      for i := 1 to 11 do
        if GDVars.dsOtherCreatureCurrentPtr^.name = GDConsts.dwarfFoes[i] then
          Inc(GDVars.gAttackRoll);
end;

{ Mirror Image (eff 28). strength = images left; against a single-target spell (dsCurrentSpellBeing > 0, gMultiTarget =
  0) an image absorbs it unless 1d(images + 1) rolls 1. Weapon hits are tested in CbtActs.DoAttack. }

procedure EffMirrorImage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, Types.PEffectRec(p)^.strength + 1) > 1 then
    if GDVars.dsCurrentSpellBeing > 0 then
      if GDVars.gMultiTarget = 0 then begin
        EffHndlr.NullifyAttack(0);
        CharHlp.PrintNameString(creature, 'lost an image', 10, True);
        Dec(Types.PEffectRec(p)^.strength);
        if Types.PEffectRec(p)^.strength = 0 then
          FxEngine.RemoveEffect(creature, C_Effect.MIRROR_IMAGE, nil);
      end;
end;

{ Ray of Enfeeblement (eff 29): pendingDamage loses a quarter (rounded down) }

procedure EffEnfeeble(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.pendingDamage := GDVars.pendingDamage - GDVars.pendingDamage div 4;
end;

{ Coughing from Stinking Cloud (eff 30) }

procedure EffStinkCough(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintNameString(creature, 'is coughing', 10, True);
  creature^.combatAddr^.itemUseAllowed := 0;
  creature^.combatAddr^.castAllowed := 0;
  CharHlp.RecalcStats(creature);
  if creature^.acBehind > 52 then
    Dec(creature^.acBehind, 2)
  else
    creature^.acBehind := 50;
  creature^.acCur := creature^.acBehind;
  if creature = GDVars.curChar then
    CharHlp.CombatPrintCreatureInfo(creature);
end;

{ Animate Dead (eff 32). Fires on REMOVAL of the animation }

procedure EffAnimateDead(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  if GDVars.effectLock = 0 then
    EffHndlr.InflictStatusMsg(creature, C_Status.DEAD, 'collapses');
  creature^.hostile := Types.PEffectRec(p)^.strength div 16;
  creature^.quickfight := 1;
  creature^.levelUndead := 0;
  creature^.attackLevel := CharHlp.WarriorLevel(creature);
  creature^.movementBase := 12;
  if creature^.npc = C_Npc.ANIMATED_PC then
    creature^.npc := 0;
  creature^.charType := 0;
end;

{ Blind (eff 33) }

procedure EffBlind(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Dec(GDVars.gAttackRoll, 4);
  Dec(creature^.acCur, 4);
  Dec(creature^.acBehind, 4);
  Dec(GDVars.gSaveRoll, 4);
end;

{ Diseased (eff 34): chains 43 + 44 }

procedure EffDiseased(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  FxEngine.CallEffectHandler(C_Effect.DISEASE_STR, creature, p, removed);
  FxEngine.CallEffectHandler(C_Effect.DISEASE_HP, creature, p, removed);
end;

{ Allied Prayer (eff 35): Prayer's bonus to the caster's side, +1 to saving throws and +1 to attack rolls. EffPrayer
  also applies it to creatures on the caster's side. }

procedure EffAlliedPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Inc(GDVars.gSaveRoll);
  Inc(GDVars.gAttackRoll);
end;

{ Bestow Curse (eff 36) }

procedure EffBestowCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Dec(GDVars.gAttackRoll, 4);
  Dec(GDVars.gSaveRoll, 4);
end;

{ Blinking (eff 37) }

procedure EffBlinking(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.initiative > 0 then begin
    GDVars.dsCurrentSuppressTargetingFlag := 1;
    GDVars.gAttackRoll := -1;
  end;
end;

{ Hasted (eff 39). Ages the creature one year the first time it fires (strength bit 4 marks that it has), and doubles
  dsCurrentAttackCurrent }

procedure EffHasted(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if Types.PEffectRec(p)^.strength and $10 = 0 then begin
    Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength + $10;
    CharHlp.PrintNameString(creature, 'ages', 10, True);
    Inc(creature^.age);
  end;
  GDVars.dsCurrentAttackCurrent := GDVars.dsCurrentAttackCurrent * 2;
end;

{ Cast Stinking Cloud (eff 40). Removes the cloud this caster is responsible for (strength upper nibble = its idx),
  restores or corpse-marks its cells, unlinks and frees the node, then repaints every remaining cloud }

procedure EffCastStink(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  q: Types.PStinkRec;
  node: Types.PStinkRec;
  found: Byte;
  slotId: Byte;
  i: Byte;
  xx: Byte;
  yy: Byte;
begin
  slotId := Types.PEffectRec(p)^.strength div 16;
  found := 0;
  node := GDVars.stinkHead;
  while (node <> nil) and (found = 0) do
    if (node^.caster = creature) and (node^.idx = slotId) then
      found := 1
    else
      node := node^.next;
  if found = 0 then Exit;
  CharHlp.PrintBottomLine('The air clears a little...');
  { 4 = High(TStinkRec.exists) }
  for i := 1 to 4 do
    if node^.exists[i] <> 0 then begin
      xx := node^.ulX + GDConsts.dirDX[GDConsts.cloudDir[i]];
      yy := node^.ulY + GDConsts.dirDY[GDConsts.cloudDir[i]];
      found := 0;
      for slotId := 1 to GDVars.downedCount do
        if GDVars.downed[slotId].cr <> nil then
          if GDVars.downed[slotId].x = xx then
            if GDVars.downed[slotId].y = yy then
              found := 1;
      if found <> 0 then
        GDVars.arenaPtr^.cells[yy, xx] := C_Terr.CORPSE
      else
        GDVars.arenaPtr^.cells[yy, xx] := node^.under[i];
    end;
  q := GDVars.stinkHead;
  if q = node then
    GDVars.stinkHead := q^.next
  else
    while q^.next <> node do
      q := q^.next;
  q^.next := node^.next;
  FreeMem(node, SizeOf(Types.TStinkRec));
  q := GDVars.stinkHead;
  while q <> nil do begin
    { 4 = High(TStinkRec.exists) }
    for i := 1 to 4 do
      if q^.exists[i] <> 0 then
        GDVars.arenaPtr^.cells[q^.ulY + GDConsts.dirDY[GDConsts.cloudDir[i]],
                                 q^.ulX + GDConsts.dirDX[GDConsts.cloudDir[i]]] := C_Terr.STINK_CLOUD;
    q := q^.next;
  end;
end;

{ Avoid the attack with pct% chance, only when the attacker (GDVars.curChar) has a weapon equipped and is more than one
  cell away: print "Avoids it", zero the damage, force a miss and take the hit back off hitsMade for the attacker's
  current attack phase. }

procedure AvoidRanged(creature: Types.PCharRecord; pct: Byte);
var
  phase: Byte;
begin
  if GDVars.curChar^.equipped[C_Equip.WEAPON] <> nil then
    if CharHlp.CalcDistance(GDVars.curChar, creature) > 1 then
      if FxEngine.RollDice(1, 100) <= pct then begin
        CharHlp.PrintNameString(creature, 'Avoids it', 10, True);
        GDVars.pendingDamage := 0;
        GDVars.gAttackRoll := -1;
        phase := GDVars.curChar^.combatAddr^.attackPhase;
        { 1..2 = the bounds of hitsMade }
        if (phase >= 1) and (phase <= 2) then
          if GDVars.hitsMade[phase] > 0 then
            Dec(GDVars.hitsMade[phase]);
      end;
end;

{ Choose the item that deals damage: the item CharHlp.FindDamagingRangedWeapon picks (such as the arrows or quarrels for
  a bow or crossbow), otherwise the equipped weapon; nil when no weapon is equipped }

function FindDamagingWeapon(creature: Types.PCharRecord): Types.PItemRec;
var
  sel: Types.PItemRec;
  ok: Boolean;
begin
  sel := nil;
  if creature^.equipped[C_Equip.WEAPON] <> nil then begin
    ok := CharHlp.FindDamagingRangedWeapon(creature, sel);
    if (ok = False) or (sel = nil) then
      sel := creature^.equipped[C_Equip.WEAPON];
  end;
  FindDamagingWeapon := sel;
end;

{ Protection from Normal Missiles (eff 41) }

procedure EffProtMissiles(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if EffHndlr.FindDamagingWeapon(GDVars.curChar) <> nil then
    if Types.PItemRec(EffHndlr.FindDamagingWeapon(GDVars.curChar))^.plus = 0 then
      EffHndlr.AvoidRanged(creature, 100);
end;

{ Slowed (eff 42) }

procedure EffSlowed(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.dsCurrentAttackCurrent := GDVars.dsCurrentAttackCurrent div 2;
end;

{ Disease Strength drain (eff 43): re-arm for 60 minutes and lose 1 Strength; at Strength 3 become helpless }

procedure EffDiseaseStr(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_Effect.DISEASE_STR, Types.PEffectRec(p)^.strength, 60) then
    if creature^.strCur > 3 then begin
      CharHlp.PrintNameString(creature, 'is weakened', 10, True);
      Dec(creature^.strCur);
    end else
      if not CharHlp.HasEffect(creature, C_Effect.HELPLESS, effect) then
        FxEngine.AddEffect(creature, C_Effect.HELPLESS, 0, 255, False);
end;

{ Disease hit point drain (eff 44): re-arm for 10 minutes and deal 1 damage; at 1 HP become helpless }

procedure EffDiseaseHp(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_Effect.DISEASE_HP, Types.PEffectRec(p)^.strength, 10) then
    if creature^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(creature, 1, 0, False);
      if GDVars.ifcState <> C_Ifc.COMBAT then
        CharHlp.DisplayParty(GDVars.curChar);
    end else
      if not CharHlp.HasEffect(creature, C_Effect.HELPLESS, effect) then
        FxEngine.AddEffect(creature, C_Effect.HELPLESS, 0, 255, False);
end;

{ Dwarf/gnome AC bonus vs giants (eff 47) }

procedure EffDwarfAcGiant(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  { The attacker is curChar: its name is tested, as are its type and size, not that of the defender's own target.
    charType 0, 1, 2 or 10 and size 1 or 2: the monster data gives the listed giants these (OGRE LEADER type 0 and size
    1, HILL GIANT and FIRE GIANT type 2, TROLL type 10). }
  if GDVars.curChar^.charType in [0, 1, 2, 10] then
    if GDVars.curChar^.iconDimensions and $7F in [1, 2] then
      for i := 1 to SizeOf(GDConsts.giantFoes) div SizeOf(GDConsts.giantFoes[1]) do
        if GDVars.curChar^.name = GDConsts.giantFoes[i] then
          Dec(GDVars.gAttackRoll, 4);
end;

{ Gnome AC bonus vs bugbears/gnolls (eff 48) }

procedure EffGnomeAcBug(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.curChar^.charType = 1 then
    if (GDVars.curChar^.name = 'BUGBEAR') or (GDVars.curChar^.name = 'GNOLL') then
      Dec(GDVars.gAttackRoll, 4);
end;

{ Prayer (eff 49). strength bit 4 = the caster's side: creatures on that side get the EffAlliedPrayer bonus, all others
  -1 to attack rolls and saving throws }

procedure EffPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  side: Byte;
begin
  side := (Types.PEffectRec(p)^.strength and $10) div 16;
  if Byte(creature^.hostile) = side then
    EffHndlr.EffAlliedPrayer(creature, p, removed)
  else begin
    Dec(GDVars.gAttackRoll);
    Dec(GDVars.gSaveRoll);
  end;
end;

{ Mummy rot healing prevention (eff 50): re-arms itself for 14400 minutes, then restores 1 HP (bypassing the rot
  block) }

procedure EffRotNoHeal(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_Effect.ROT_NO_HEAL, Types.PEffectRec(p)^.strength, 14400) then
    if FxEngine.RestoreHitPoints(creature, 1, True) then
      CharHlp.PrintHpRestoreMsg(creature);
end;

{ Helpless (eff 31, 51, 52, 53) }

procedure EffHelpless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if CharHlp.EndActions(creature) then ;
end;

{ Wearing Ring of Invisibility (eff 56) }

procedure EffRingInvis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(creature, C_Effect.INVISIBLE, 1, 12, False);
end;

{ Mummy rot degeneration (eff 57). strength upper nibble = the 1d6 countdown seeded by eff 87. Each firing costs 2
  Charisma (not below 3); the creature re-arms for 43200 minutes while the count exceeds 1, then dies }

procedure EffMummyRot(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.effectLock <> 0 then Exit;
  CharHlp.PrintNameString(creature, 'Rots...', 10, True);
  if creature^.chaCur > 2 then
    Dec(creature^.chaCur, 2)
  else
    creature^.chaCur := 0;
  if creature^.chaCur < 3 then
    creature^.chaCur := 3;
  if Types.PEffectRec(p)^.strength div 16 > 1 then begin
    Dec(Types.PEffectRec(p)^.strength, $10);
    if EffHndlr.AddEffectIfNoLock(creature, C_Effect.MUMMY_ROT, Types.PEffectRec(p)^.strength, 43200) then ;
  end else
    EffHndlr.InflictStatusMsg(creature, C_Status.GONE, 'Dies rots away');
end;

{ Immobile (eff 58) }

procedure EffImmobile(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  creature^.combatAddr^.movement := 0;
  if GDVars.dsCurrentCreatureCalculatingFlag <> 0 then
    GDVars.dsCurrentAttackCurrent := 0;
end;

{ Troll: add regeneration (eff 59): add eff 98 permanently }

procedure EffTrollRegen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(creature, C_Effect.REGEN3, 0, 255, False);
end;

{ Ring of Fire Resistance (eff 61): against fire, -2 damage per die (minimum 1 per die, but never more than the damage
  was) and +4 to save; non-magical fire is nullified }

procedure EffRingFireRes(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  if GDVars.elementMask and 1 <> 0 then begin
    for i := 1 to GDVars.gDamageDice do
      { floor before taking 2 off, so damage of 0 or 1 cannot wrap the Byte to 254 or 255 }
      if GDVars.pendingDamage >= Word(GDVars.gDamageDice) + 2 then
        Dec(GDVars.pendingDamage, 2)
      else if GDVars.pendingDamage > GDVars.gDamageDice then
        GDVars.pendingDamage := GDVars.gDamageDice;
    Inc(GDVars.gSaveRoll, 4);
    if GDVars.elementMask and 8 = 0 then
      EffHndlr.NullifyAttack(0);
  end;
end;

{ Regenerating from high Con (eff 62): re-arm for 60 minutes and restore 1 HP }

procedure EffConRegen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_Effect.CON_REGEN, Types.PEffectRec(p)^.strength, 60) then
    if FxEngine.RestoreHitPoints(creature, 1, True) then
      CharHlp.PrintHpRestoreMsg(creature);
end;

{ Poison the attacker's combat target: unless it saves vs. paralyzation/poison with saveMod, it gets eff 55 and is
  killed. }

procedure PoisonTouch(creature: Types.PCharRecord; saveMod: ShortInt);
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  if not FxEngine.RollSavingThrow(GDVars.dsOtherCreatureCurrentPtr, C_Save.PARALYZE, saveMod) then begin
    CharHlp.PrintNameString(GDVars.dsOtherCreatureCurrentPtr, 'is Poisoned', 10, False);
    TextRend.PauseOnly;
    FxEngine.AddEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.POISONED, 0, 255, False);
    EffHndlr.InflictStatusMsg(GDVars.dsOtherCreatureCurrentPtr, C_Status.DEAD, 'is killed');
  end;
end;

{ Paralyze the attacker's combat target for minutes unless it saves vs. paralyzation; saveMod is unused. }

procedure ParalysisTouch(creature: Types.PCharRecord; minutes: Word; saveMod: ShortInt);
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  if not FxEngine.RollSavingThrow(GDVars.dsOtherCreatureCurrentPtr, C_Save.PARALYZE, 0) then begin
    CharHlp.PrintNameStringAnim(GDVars.dsOtherCreatureCurrentPtr, True, 'is Paralyzed');
    FxEngine.AddEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.PARALYSIS, minutes, 12, False);
  end;
end;

{ Melee poison (eff 64): the target saves at +0 }

procedure EffPoisonHit0(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTouch(creature, 0);
end;

{ Melee poison, +4 save (eff 65) }

procedure EffPoisonHit4(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTouch(creature, 4);
end;

{ Melee poison, +2 save (eff 66) }

procedure EffPoisonHit2(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTouch(creature, 2);
end;

{ Thri-kreen paralysis (eff 67): 2d8 minutes }

procedure EffKreenPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.ParalysisTouch(creature, FxEngine.RollDice(2, 8), 0);
end;

{ Ghoul paralysis (eff 68): 63 minutes, not vs. elves }

procedure EffGhoulPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.other^.race <> C_Race.ELF then
    EffHndlr.ParalysisTouch(creature, 63, 0);
end;

{ Drider paralysis (eff 69): 1d9+10 minutes. The -2 save modifier is passed but ParalysisTouch ignores it }

procedure EffDriderPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.ParalysisTouch(creature, FxEngine.RollDice(1, 9) + 10, -2);
end;

{ Melee poison, -2 save (eff 70) }

procedure EffPoisonHitM2(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTouch(creature, -2);
end;

{ Dust of Disappearance (eff 71): a stronger form of invisibility. Sets dsCurrentSuppressTargetingFlag and lowers
  gAttackRoll by 4. }

procedure EffDustDisappear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.dsCurrentSuppressTargetingFlag := 1;
  Dec(GDVars.gAttackRoll, 4);
end;

{ Camouflaged / Cloak of Elvenkind (eff 72): 95% chance of invisibility (eff 25) for 1 minute }

procedure EffCamouflage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 95 then
    FxEngine.AddEffect(creature, C_Effect.INVISIBLE, 1, 12, False);
end;

{ Blood drain (eff 75). strength = victim's creature index; duration's upper bits = the x16 damage budget. An index
  outside creatureArr[1..arenaCount] (CombatSlot's 0 for a creature not in the arena) has no victim: the effect just
  goes. }

procedure EffBloodDrain(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  done: Boolean;
  dmg: Byte;
begin
  { 72 = High(creatureArr) }
  if (Types.PEffectRec(p)^.strength = 0) or (Types.PEffectRec(p)^.strength > GDVars.arenaCount) or
      (Types.PEffectRec(p)^.strength > 72) then begin
    if not removed then begin
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, C_Effect.BLOOD_DRAIN, p);
    end;
    Exit;
  end;
  GDVars.dsOtherCreatureCurrentPtr := GDVars.creatureArr[Types.PEffectRec(p)^.strength];
  if removed or (creature^.enabled = 0) or (GDVars.dsOtherCreatureCurrentPtr^.enabled = 0) then begin
    FxEngine.RemoveEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.IMMOBILE, nil);
    if not removed then begin
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, C_Effect.BLOOD_DRAIN, p);
    end;
    if creature^.enabled <> 0 then
      if GDVars.dsOtherCreatureCurrentPtr^.enabled <> 0 then
        creature^.combatAddr^.turned := 1;
  end else begin
    CharHlp.PrintNameString(creature, 'Sucks some Blood', 10, True);
    dmg := FxEngine.RollDamageDice(1, 4);
    GDVars.elementMask := 0;
    FxEngine.InflictNonWeaponDamage(GDVars.dsOtherCreatureCurrentPtr, dmg, 0, False);
    done := CharHlp.EndActions(creature);
    if (GDVars.dsOtherCreatureCurrentPtr^.enabled <> 0) and (Types.PEffectRec(p)^.duration div 16 > dmg) then
      Dec(Types.PEffectRec(p)^.duration, dmg * 16)
    else
      FxEngine.RemoveEffect(creature, C_Effect.BLOOD_DRAIN, p);
  end;
end;

{ Blood drain attachment (eff 76): add eff 75 on the attacker with a 12 hp budget and immobilize the target. A target
  with no combat slot (none, or not on the map) is not drained. }

procedure EffBloodAttach(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  slot: Byte;
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  if GDVars.dsOtherCreatureCurrentPtr = nil then
    Exit;
  slot := CbtMap.CombatSlot(GDVars.dsOtherCreatureCurrentPtr);
  if slot = 0 then
    Exit;
  { a 12 hp budget in the upper bits of the duration }
  FxEngine.AddEffect(creature, C_Effect.BLOOD_DRAIN, 12 * 16 + 15, slot, True);
  FxEngine.AddEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.IMMOBILE, 0, 255, False);
  FxEngine.CallEffectHandler(C_Effect.IMMOBILE, GDVars.dsOtherCreatureCurrentPtr, nil, False);
end;

{ Bite attach (eff 77): add eff 74 (bite and hold, handled by CbtActs.BiteAndHold) on the biter and immobilize the
  target. No effect on a target with Strength 19+, or with no combat slot (none, or not on the map) }

procedure EffBiteHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  slot: Byte;
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  if GDVars.dsOtherCreatureCurrentPtr = nil then
    Exit;
  slot := CbtMap.CombatSlot(GDVars.dsOtherCreatureCurrentPtr);
  if slot = 0 then
    Exit;
  if GDVars.dsOtherCreatureCurrentPtr^.strCur < 19 then begin
    FxEngine.AddEffect(creature, C_Effect.BITE_HOLD, 0, slot, True);
    FxEngine.AddEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.IMMOBILE, 0, 255, False);
    FxEngine.CallEffectHandler(C_Effect.IMMOBILE, GDVars.dsOtherCreatureCurrentPtr, nil, False);
    CharHlp.PrintNameString(GDVars.dsOtherCreatureCurrentPtr, 'is held fast', 10, True);
  end;
end;

{ Healed from unconscious (eff 78): revive at the current HP, or retry in 1 minute if that fails }

procedure EffHealWake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  dummy: Boolean;
begin
  if not FxEngine.ReviveDeadCreature(creature, creature^.hpCur) then
    dummy := EffHndlr.AddEffectIfNoLock(creature, C_Effect.HEAL_WAKE, Types.PEffectRec(p)^.strength, 1);
end;

{ Melee fire touch (eff 79): +2d10 fire }

procedure EffFireTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.elementMask := 9;
  FxEngine.InflictNonWeaponDamage(creature^.combatAddr^.other, FxEngine.RollDamageDice(2, 10), 0, False);
end;

{ Melee acid squirt (eff 80): +1d4 acid }

procedure EffAcidSquirt(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.elementMask := $10;
  FxEngine.InflictNonWeaponDamage(creature^.combatAddr^.other, FxEngine.RollDamageDice(1, 4), 0, False);
end;

{ Dragon fear aura (eff 81). Walks the whole creature list: each enabled enemy saves vs. spell or, by highest level, is
  permanently paralyzed (0..3) or cursed (4, 5); level 6+ is unaffected }

procedure EffDragonFear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  q: Types.PCharRecord;
  saved: Boolean;
begin
  q := GDVars.creatureList;
  while q <> nil do begin
    if q^.enabled <> 0 then
      if CharHlp.EnemyTeam(creature) = q^.hostile then begin
        saved := FxEngine.RollSavingThrow(q, C_Save.SPELL, 0);
        case q^.levelHighest of
          0..3: FxEngine.AddEffectWithMessage(q, C_Effect.PARALYSIS, 0, 12, False, True, saved,
                                              'is paralyzed with fear');
          4, 5: FxEngine.AddEffectWithMessage(q, C_Effect.CURSE, 0, 12, False, True, saved, 'is weakened by fear');
        end;
      end;
    q := q^.nextCharAddr;
  end;
end;

{ Mummy fear aura (eff 82). Removes an eff-82 node from EVERY creature (the mummy's own included); each enabled enemy
  then saves vs. paralyzation (+1 if its team has 6+ members, +2 if human) or is paralyzed with fear for 1d4 minutes }

procedure EffMummyFear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  q: Types.PCharRecord;
  bonus: Byte;
  saved: Boolean;
begin
  q := GDVars.creatureList;
  while q <> nil do begin
    FxEngine.RemoveEffect(q, C_Effect.MUMMY_FEAR, nil);
    if q^.enabled <> 0 then
      if CharHlp.EnemyTeam(creature) = q^.hostile then begin
        bonus := 0;
        if GDVars.teamCount[q^.hostile] >= 6 then
          Inc(bonus);
        if q^.race = C_Race.HUMAN then
          Inc(bonus, 2);
        saved := FxEngine.RollSavingThrow(q, C_Save.PARALYZE, bonus);
        FxEngine.AddEffectWithMessage(q, C_Effect.PARALYSIS, FxEngine.RollDice(1, 4), 12, False, True, saved,
                                      'is paralyzed with fear');
      end;
    q := q^.nextCharAddr;
  end;
end;

{ Petrifying gaze (eff 83): the target saves vs. petrification or is stoned. Effect 127 on the gazer marks the gaze
  reflectable: an equipped "Mirror" item turns it back on the gazer }

procedure EffPetrifyGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  reflected: Boolean;
  effect: Types.PEffectRec;
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  CharHlp.PrintNameString(creature, 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                  CbtMap.CombatCellX(GDVars.dsOtherCreatureCurrentPtr),
                                  CbtMap.CombatCellY(GDVars.dsOtherCreatureCurrentPtr), 4, 45);
  if CharHlp.HasEffect(creature, C_Effect.GAZE_REFLECTABLE, effect) then begin
    reflected := False;
    item := GDVars.dsOtherCreatureCurrentPtr^.itemsAddr;
    while (item <> nil) and (reflected = False) do begin
      if item^.equipped <> 0 then
        { "Mirror" }
        if (item^.nameIds[1] = 118) or (item^.nameIds[2] = 118) or (item^.nameIds[3] = 118) then begin
          CharHlp.PrintNameString(GDVars.dsOtherCreatureCurrentPtr, 'reflects it!', 12, False);
          CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.dsOtherCreatureCurrentPtr),
                                          CbtMap.CombatCellY(GDVars.dsOtherCreatureCurrentPtr),
                                          CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 4, 45);
          reflected := True;
          GDVars.dsOtherCreatureCurrentPtr := creature;
        end;
      item := item^.next;
    end;
  end;
  if not FxEngine.RollSavingThrow(GDVars.dsOtherCreatureCurrentPtr, C_Save.PETRIFY, 0) then
    EffHndlr.InflictStatusMsg(GDVars.dsOtherCreatureCurrentPtr, C_Status.STONED, 'is Stoned');
end;

{ Charming gaze (eff 84): with a clear line to an attackable target within Charm Person's range, apply Charm Person
  (save vs. spell at -2) without using a spell slot or action. The spell being cast is marked as Charm Person only while
  the charm is applied, then restored: left at 10, it made later damage look like a spell's (Mirror Image absorbed it). }

procedure EffCharmGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  dist: Word;
  effect: Types.PEffectRec;
  x: ShortInt;
  y: ShortInt;
  savedSpell: Byte;
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  x := CbtMap.CombatCellX(GDVars.dsOtherCreatureCurrentPtr);
  y := CbtMap.CombatCellY(GDVars.dsOtherCreatureCurrentPtr);
  if not CbtActs.CanAttackTarget(creature, GDVars.dsOtherCreatureCurrentPtr) then Exit;
  { the range budget in cells, read by WalkLine on entry: that of the Charm Person the gaze applies }
  dist := GDConsts.spellTable[C_Spell.CHARM_PERSON].rangeFixed;
  if not Pathing.WalkLine(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), x, y, dist,
                          GDVars.arenaPtr) then Exit;
  CharHlp.PrintNameString(creature, 'Gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                  CbtMap.CombatCellX(GDVars.dsOtherCreatureCurrentPtr),
                                  CbtMap.CombatCellY(GDVars.dsOtherCreatureCurrentPtr), 4, 45);
  { Charm Person }
  savedSpell := GDVars.dsCurrentSpellBeing;
  GDVars.dsCurrentSpellBeing := 10;
  FxEngine.AddEffectWithMessage(GDVars.dsOtherCreatureCurrentPtr, C_Effect.CHARM, 0, creature^.hostile * 128 + 12,
                                True, True,
                                FxEngine.RollSavingThrow(creature^.combatAddr^.other, C_Save.SPELL, -2),
                                'is charmed');
  if CharHlp.HasEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.CHARM, effect) then
    FxEngine.CallEffectHandler(C_Effect.CHARM, GDVars.dsOtherCreatureCurrentPtr, effect, False);
  GDVars.dsCurrentSpellBeing := savedSpell;
end;

{ Drain levels from a creature; an animated creature, or one with no class levels, is destroyed instead. For each level
  the creature loses hpMax div (total class levels) from hpMax, hpRolled and hpCur, then either dies forever (highest
  level below 2) or loses a level in the class picked by ClassToDrain, dying if its HP reached 0. Its highest level and
  experience are then reset from that class. }

procedure DrainLevels(creature: Types.PCharRecord; levels: Byte);
var
  numStr: Types.TStr40;
  xpTry: LongInt;
  xpMin: LongInt;
  j: ShortInt;
  i: Byte;
  totalLevels: Byte;
  hpPerLevel: Byte;
  k: Byte;

  { Which class to drain: scanning classes 0..7, take each one whose level is >= the best so far and whose XP table
    entry for that level is >= the best so far (or is the -1 "at cap" sentinel); later classes win ties. xpMin is left
    at the chosen entry (0 for level 0 or 1, level 9's above level 9). }
  function ClassToDrain: ShortInt;
  var
    jj: ShortInt;
    bestLvl: ShortInt;
    lvl: ShortInt;
  begin
    xpMin := 0;
    bestLvl := 0;
    { 7 = High(classLevels) }
    for jj := 0 to 7 do begin
      lvl := creature^.classLevels[jj];
      { xp[] runs to level 9; a level above it reads level 9's entry }
      if lvl > 9 then
        xpTry := GDConsts.dsExperienceSpellsClass[jj].xp[9]
      else if lvl > 1 then
        xpTry := GDConsts.dsExperienceSpellsClass[jj].xp[lvl]
      else
        xpTry := 0;
      if lvl >= bestLvl then
        if (xpTry >= xpMin) or (xpTry = -1) then begin
          xpMin := xpTry;
          ClassToDrain := jj;
          bestLvl := lvl;
        end;
    end;
  end;

begin
  if levels > 1 then
    numStr := StrUtil.NumStr(levels) + ' levels'
  else
    numStr := 'a level';
  CharHlp.PrintNameString(creature, 'is drained ' + numStr, 10, True);
  if creature^.status = C_Status.ANIMATED then begin
    EffHndlr.InflictStatusMsg(creature, C_Status.GONE, 'is dead forever');
    creature^.hpMax := 0;
    Exit;
  end;
  for i := 1 to levels do begin
    if creature^.status <> C_Status.GONE then begin
      Inc(creature^.drainedLevels);
      totalLevels := 0;
      { 7 = High(classLevels) }
      for j := 0 to 7 do
        Inc(totalLevels, creature^.classLevels[j]);
      { a creature with no class levels (kobolds, bandits and other monsters) has no level to lose, and no divisor }
      if totalLevels = 0 then begin
        EffHndlr.InflictStatusMsg(creature, C_Status.GONE, 'is dead forever');
        creature^.hpMax := 0;
        Exit;
      end;
      hpPerLevel := creature^.hpMax div totalLevels;
      Debug.PrintHpDebug('max,cur,lost', creature^.hpMax, creature^.hpCur, creature^.drainedHps);
      for k := 1 to hpPerLevel do begin
        if creature^.hpMax > 0 then
          Dec(creature^.hpMax);
        if creature^.hpRolled > 0 then
          Dec(creature^.hpRolled);
        if creature^.hpCur > 0 then
          Dec(creature^.hpCur);
        Inc(creature^.drainedHps);
      end;
      if creature^.levelHighest < 2 then begin
        EffHndlr.InflictStatusMsg(creature, C_Status.GONE, 'is dead forever');
        creature^.hpMax := 0;
        if creature^.classLevels[ClassToDrain] > 0 then
          if levels = 2 then
            creature^.classLevels[ClassToDrain] := 0;
      end else begin
        Dec(creature^.classLevels[ClassToDrain]);
        if creature^.hpCur = 0 then
          if creature^.status <> C_Status.DEAD then
            EffHndlr.InflictStatusMsg(creature, C_Status.DEAD, 'is killed');
        ClassCal.RecalcBaseSkills(creature);
      end;
      creature^.levelHighest := creature^.classLevels[ClassToDrain];
      creature^.experience := xpMin;
      CharHlp.RecalcStats(creature);
    end;
  end;
end;

{ Melee level drain (eff 85): the target loses one level }

procedure EffDrainOne(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.DrainLevels(creature^.combatAddr^.other, 1);
end;

{ Melee level drain (eff 86): the target loses two levels }

procedure EffDrainTwo(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.DrainLevels(creature^.combatAddr^.other, 2);
end;

{ Melee mummy rot (eff 87): unless the target has eff 50 or is immune to disease (FxEngine.DiseaseImmune), add eff 50
  and eff 57. Seeds eff 57's 1d6 countdown in the upper nibble }

procedure EffRotTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  if FxEngine.DiseaseImmune(GDVars.dsOtherCreatureCurrentPtr, C_Effect.ROT_NO_HEAL) then
    Exit;
  if not CharHlp.HasEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.ROT_NO_HEAL, effect) then begin
    FxEngine.AddEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.ROT_NO_HEAL, 14400, 255, True);
    FxEngine.AddEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.MUMMY_ROT, 43200,
                       FxEngine.RollDice(1, 6) * 16 + 15, True);
    CharHlp.PrintNameString(GDVars.dsOtherCreatureCurrentPtr, 'is Diseased', 10, True);
  end;
end;

{ Displaced (eff 89). strength bit 4 = "already displaced an attack this round" }

procedure EffDisplaced(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.roundCounter = 0) and (GDVars.gAttackRoll = 0) then
    Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength and $F
  else
    if Types.PEffectRec(p)^.strength and $10 = 0 then begin
      GDVars.gAttackRoll := -1;
      Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength or $10;
    end;
end;

{ Con poison saving throw bonus (eff 90) }

procedure EffConPsnSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  bonus: Byte;
begin
  if GDVars.gSaveType = C_Save.PARALYZE then begin
    case creature^.conCur of
      4..6: bonus := 1;
      7..10: bonus := 2;
      11..13: bonus := 3;
      14..17: bonus := 4;
      18..20: bonus := 5;
    else
      { +1 per 3 1/2 points of Constitution, the rule the table follows: 0 below 4, 6 at 21..24 }
      bonus := Word(creature^.conCur) * 2 div 7;
    end;
    GDVars.gSaveRoll := GDVars.gSaveRoll + bonus;
  end;
end;

{ Immunity to electricity + Magic Missile (eff 91) }

procedure EffImmuneMM(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.dsCurrentSpellBeing = 15 then begin
    EffHndlr.NullifyAttack(0);
    CharHlp.PrintNameString(creature, 'is unaffected', 10, True);
  end else
    if GDVars.elementMask and 4 <> 0 then
      EffHndlr.NullifyAttack(0);
end;

{ Half damage from fire (eff 93) }

procedure EffHalfFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 1 <> 0 then
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

{ Half damage from blunt/piercing (eff 94) }

procedure EffHalfBash(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then
    if CharHlp.BaseItem(w^.itemType)^.wpnClass and (WPN_PIERCE or WPN_BASH) <> 0 then
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

{ Fight on at 0 HP (eff 95): when it expires, a creature still fighting falls dead }

procedure EffFightOn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  if creature^.enabled <> 0 then
    EffHndlr.InflictStatusMsg(creature, C_Status.DEAD, 'Falls dead');
end;

{ Immune to weapons neither magical nor silver, and to attacks without a weapon (eff 96). Silver = name component 177 }

procedure EffNeedSilver(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if (w = nil) or ((w^.plus = 0) and (w^.nameIds[3] <> 177)) then
    GDVars.pendingDamage := 0;
end;

{ Con spell/wand save bonus (eff 97), on EffConPsnSave's scale }

procedure EffConSpellSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  bonus: Byte;
begin
  if (GDVars.gSaveType = C_Save.SPELL) or (GDVars.gSaveType = C_Save.WAND) then begin
    case creature^.conCur of
      4..6: bonus := 1;
      7..10: bonus := 2;
      11..13: bonus := 3;
      14..17: bonus := 4;
      18..20: bonus := 5;
    else
      { +1 per 3 1/2 points of Constitution, the rule the table follows: 0 below 4, 6 at 21..24 }
      bonus := Word(creature^.conCur) * 2 div 7;
    end;
    GDVars.gSaveRoll := GDVars.gSaveRoll + bonus;
  end;
end;

{ Regenerate 3 hp per round (eff 98) }

procedure EffRegen3(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  { capped before the add, so hpCur 253..255 cannot wrap the Byte }
  if Word(creature^.hpCur) + 3 > creature^.hpMax then
    creature^.hpCur := creature^.hpMax
  else
    Inc(creature^.hpCur, 3);
end;

{ Can fight on (eff 99). Revives a dying (with overkill < 6) or unconscious creature and grants eff 95 for 1d4+1
  minutes, then removes itself }

procedure EffCanFightOn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  hp: Byte;
begin
  hp := 0;
  if creature^.status = C_Status.DYING then
    if creature^.combatAddr^.overkill < 6 then
      hp := 6 - creature^.combatAddr^.overkill;
  if creature^.status = C_Status.UNCONSCIOUS then
    hp := 6;
  if hp > 0 then
    if FxEngine.ReviveDeadCreature(creature, hp) then begin
      FxEngine.AddEffect(creature, C_Effect.FIGHT_ON, FxEngine.RollDice(1, 4) + 1, 255, True);
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, C_Effect.CAN_FIGHT_ON, p);
    end;
end;

{ Troll vulnerability to fire/acid (eff 100): when the damage is neither fire nor acid, add eff 102 to bring the troll
  back in 3d6 minutes }

procedure EffTrollBurn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and 1 = 0) and (GDVars.elementMask and $10 = 0) then
    FxEngine.AddEffect(creature, C_Effect.TROLL_RETURN, FxEngine.RollDice(3, 6), 255, True);
end;

{ Troll: add regeneration (eff 101): unless it has eff 98 or eff 59 already, add eff 59 for 3 minutes }

procedure EffTrollHeal(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if not CharHlp.HasEffect(creature, C_Effect.REGEN3, effect) then
    if not CharHlp.HasEffect(creature, C_Effect.TROLL_REGEN, effect) then
      FxEngine.AddEffect(creature, C_Effect.TROLL_REGEN, 3, 255, True);
end;

{ Troll returning from going down (eff 102): revive at full HP, or retry in 1 minute if that fails }

procedure EffTrollReturn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  dummy: Boolean;
begin
  if not FxEngine.ReviveDeadCreature(creature, creature^.hpMax) then
    dummy := EffHndlr.AddEffectIfNoLock(creature, C_Effect.TROLL_RETURN, Types.PEffectRec(p)^.strength, 1);
end;

{ Gaseous form (eff 103): the creature escapes and is put out of play as fled }

procedure EffGaseous(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  CbtMap.DisplayMapViewCentered(creature, 3, False);
  FxEngine.PutOutOfPlayWithStatus(creature, C_Status.RUNNING, 'Turns gaseous and escapes');
end;

{ Thri-kreen missile evasion (eff 104) }

procedure EffKreenDodge(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.AvoidRanged(creature, 60);
end;

{ pct is the creature's magic resistance against an 11th-level caster. As in the DMG, it rises 5% for each caster level
  below 11 and falls 5% for each level above: chance := pct + (11 - lvl) * 5, kept within 0..100, and a 1d100 roll <=
  chance nullifies. Only an effect under the immunity check or magic damage is resisted. An item counts as a 6th-level
  caster here, as a scroll does, not the 12 GetCasterLevel gives the class-2 item spells (the wands, the necklace and
  the javelin). Shipped v1.3 had the sign the other way (pct - (11 - lvl) * 5, with eff 106 passing 15), so resistance
  grew with the caster level; Tyranthraxus (eff 106) still resists every caster the game produces, as he did. }

procedure MagicResistance(pct: Byte);
var
  lvl: Byte;
  chance: Integer;
begin
  lvl := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  if GDVars.usingItem and (lvl > 6) then
    lvl := 6;
  chance := Integer(pct) + (11 - Integer(lvl)) * 5;
  if chance < 0 then
    chance := 0
  else if chance > 100 then
    chance := 100;
  if (GDVars.pendingEffectId = 0) and (GDVars.elementMask and 8 = 0) then
    Exit;
  if FxEngine.RollDice(1, 100) <= chance then
    EffHndlr.NullifyAttack(0);
end;

{ Magic resistance 50% (eff 105) }

procedure EffMagicRes50(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.MagicResistance(50);
end;

{ Magic resistance 85% (eff 106) }

procedure EffMagicRes85(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.MagicResistance(85);
end;

{ Elf 90% resistance to sleep/charm (eff 107) }

procedure EffElfResist(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 90 then begin
    EffHndlr.NullifyAttack(C_Effect.SLEEP);
    EffHndlr.NullifyAttack(C_Effect.CHARM);
  end;
end;

{ Immunity to sleep/charm (eff 108) }

procedure EffNoSleepCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.CHARM);
  EffHndlr.NullifyAttack(C_Effect.SLEEP);
end;

{ Immunity to paralysis (eff 109) }

procedure EffNoParalysis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.PARALYSIS);
end;

{ Immunity to cold (eff 110) }

procedure EffNoCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 2 <> 0 then
    EffHndlr.NullifyAttack(0);
end;

{ Immunity to paralysis + poison (eff 111). Saves of type 0 (paralyzation/poison, e.g. Stinking Cloud) succeed
  automatically }

procedure EffNoParaPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.POISONED);
  EffHndlr.NullifyAttack(C_Effect.PARALYSIS);
  if GDVars.gSaveType = C_Save.PARALYZE then
    GDVars.gSaveRoll := 100;
end;

{ Immunity to fire (eff 112) }

procedure EffNoFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 1 <> 0 then
    EffHndlr.NullifyAttack(0);
end;

{ Efreeti fire resistance (eff 113): -1 per die, minimum = dice count (damage already below it is left alone) }

procedure EffEfreetiFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  if GDVars.elementMask and 1 <> 0 then
    for i := 1 to GDVars.gDamageDice do
      { only above the floor, so damage of 0 cannot wrap the Byte to 255 }
      if GDVars.pendingDamage > GDVars.gDamageDice then
        Dec(GDVars.pendingDamage);
end;

{ Half damage from electricity (eff 114) }

procedure EffHalfElec(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 4 <> 0 then
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

{ Half damage from piercing/slashing (eff 115) }

procedure EffHalfPierce(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then
    if (CharHlp.BaseItem(w^.itemType)^.wpnClass = WPN_SLASH) or
        (CharHlp.BaseItem(w^.itemType)^.wpnClass and WPN_PIERCE <> 0) then
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

{ Half damage from magical weapons (eff 116) }

procedure EffHalfMagical(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then
    if w^.plus > 0 then
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

{ Vulnerability to holy water (eff 117): a holy water vial does 1d6+1 }

procedure EffHolyWater(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := GDVars.curChar^.equipped[C_Equip.WEAPON];
  if item <> nil then
    if item^.itemType = C_Item.HOLY_WATER_VIAL then
      GDVars.pendingDamage := FxEngine.RollDamageDice(1, 6) + 1;
end;

{ Half damage from cold (eff 118) }

procedure EffHalfCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and 2 <> 0 then
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

{ Immunity to non-magical weapons and unarmed attacks (eff 119): only vs PC races or attackers with levelHighest < 4 }

procedure EffNeedMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if (w = nil) or (w^.plus = 0) then
    if (GDVars.curChar^.race > C_Race.MONSTER) or (GDVars.curChar^.levelHighest < 4) then
      GDVars.pendingDamage := 0;
end;

{ Boulder evasion (eff 120): 50% chance to avoid a thrown C_Item.BOULDER or C_Item.LARGE_BOULDER }

procedure EffBoulderDodge(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := GDVars.curChar^.equipped[C_Equip.WEAPON];
  if item <> nil then
    if (item^.itemType = C_Item.BOULDER) or (item^.itemType = C_Item.LARGE_BOULDER) then
      EffHndlr.AvoidRanged(creature, 50);
end;

{ Anhkheg acid squirt (eff 121): 25% chance, range < 4, 8d4, save vs. breath for half; the effect removes itself (and
  eff 80) after firing }

procedure EffAnhkhegAcid(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  dummy: Boolean;
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  { other is nil before the anhkheg's first target, and may be a creature since taken out of play }
  if (GDVars.dsOtherCreatureCurrentPtr = nil) or (GDVars.dsOtherCreatureCurrentPtr^.enabled = 0) then Exit;
  if FxEngine.RollDice(1, 100) > 25 then Exit;
  if CharHlp.CalcDistance(creature, GDVars.dsOtherCreatureCurrentPtr) >= 4 then Exit;
  dummy := CharHlp.EndActions(creature);
  CharHlp.PrintNameString(creature, 'Spits Acid', 10, True);
  CharHlp.BuildIconFacings(23);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                  CbtMap.CombatCellX(GDVars.dsOtherCreatureCurrentPtr),
                                  CbtMap.CombatCellY(GDVars.dsOtherCreatureCurrentPtr), 1, 30);
  FxEngine.InflictNonWeaponDamage(GDVars.dsOtherCreatureCurrentPtr, FxEngine.RollDamageDice(8, 4), 2,
                                  FxEngine.RollSavingThrow(GDVars.dsOtherCreatureCurrentPtr, C_Save.BREATH, 0));
  FxEngine.RemoveEffect(creature, C_Effect.ANHKHEG_ACID, p);
  FxEngine.RemoveEffect(creature, C_Effect.ACID_SQUIRT, nil);
end;

{ Mummy vulnerability to fire (eff 122): a flask of oil does 3d8; magic or fire damage +1 per die }

procedure EffMummyFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := GDVars.curChar^.equipped[C_Equip.WEAPON];
  if item <> nil then
    if item^.itemType = C_Item.FLASK_OF_OIL then
      GDVars.pendingDamage := FxEngine.RollDamageDice(3, 8);
  if GDVars.elementMask and 9 <> 0 then
    Inc(GDVars.pendingDamage, GDVars.gDamageDice);
end;

{ Immune unless silver (half) or magical (full); no damage without a weapon (eff 123) }

procedure EffSilverMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then begin
    if (w^.plus = 0) and (w^.nameIds[3] = 177) then
      GDVars.pendingDamage := GDVars.pendingDamage div 2
    else if w^.plus = 0 then
      GDVars.pendingDamage := 0;
  end else
    GDVars.pendingDamage := 0;
end;

{ Half-elf 30% resistance (eff 124) }

procedure EffHalfElfResist(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 30 then begin
    EffHndlr.NullifyAttack(C_Effect.CHARM);
    EffHndlr.NullifyAttack(C_Effect.SLEEP);
  end;
end;

{ Immunity to sleep/charm/para/poison (eff 125). Saves of type 0 succeed automatically }

procedure EffNoCharmPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.CHARM);
  EffHndlr.NullifyAttack(C_Effect.SLEEP);
  EffHndlr.NullifyAttack(C_Effect.PARALYSIS);
  EffHndlr.NullifyAttack(C_Effect.POISONED);
  if GDVars.gSaveType = C_Save.PARALYZE then
    GDVars.gSaveRoll := 100;
end;

{ Suppressible gaze (eff 126): blocked by an equipped "Mirror" component (118) or Wooden Holy Symbol of Tyr (component
  pair 152/252) on the target }

procedure EffGazeBlock(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  j: Byte;
begin
  GDVars.dsOtherCreatureCurrentPtr := creature^.combatAddr^.other;
  item := GDVars.dsOtherCreatureCurrentPtr^.itemsAddr;
  while (item <> nil) and (GDVars.dsCurrentSuppressTargetingFlag = 0) do begin
    if item^.equipped <> 0 then
      { 3 = High(TItemRec.nameIds) }
      for j := 1 to 3 do
        if ((item^.nameIds[j] = 152) and (item^.nameIds[3] = 252)) or (item^.nameIds[j] = 118) then
          GDVars.dsCurrentSuppressTargetingFlag := 1;
    item := item^.next;
  end;
end;

{ Ready item (eff 128, 129, 130, 133, 134, 136, 138, 139): p is the ITEM. Readying adds its effect byte as a permanent
  effect (strength 12) and calls that handler; unreadying removes it. }

procedure EffReadyItem(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := p;
  if removed then
    FxEngine.RemoveEffect(creature, item^.effect, nil)
  else begin
    FxEngine.AddEffect(creature, item^.effect, 0, 12, False);
    FxEngine.CallEffectHandler(item^.effect, creature, nil, False);
  end;
end;

{ Gauntlets of Ogre Power (eff 131). Ready: Str 18/00 via FxEngine.AdjustForNewStrength plus a permanent eff 38 node
  holding the Strength to restore. Unready: remove the first eff 38 node if the creature is at 18/00, else the first one
  whose stored Strength is 18/00 }

procedure EffGauntlets(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  enc: Byte;
  base: Byte;
  exc: Byte;
  isOgre: Boolean;
  found: Boolean;
  q: Types.PEffectRec;
  next: Types.PEffectRec;
begin
  if removed then begin
    found := False;
    q := creature^.effectsAddr;
    if (creature^.strCur = 18) and (creature^.strExc = 100) then
      isOgre := True
    else
      isOgre := False;
    while (q <> nil) and (found = False) do begin
      { taken before RemoveEffect frees q }
      next := q^.next;
      if q^.id = C_Effect.STRENGTH then begin
        FxEngine.StrengthEffectToStrength(q, base, exc);
        { SSI tested q^.id < $80 here, always true for C_Effect.STRENGTH: the $80 flag is in the strength byte, which
          EffExtraStr tests. What the test came to is kept. }
        if isOgre or ((base = 18) and (exc = 100)) then begin
          FxEngine.RemoveEffect(creature, C_Effect.STRENGTH, q);
          found := True;
        end;
      end;
      q := next;
    end;
  end else begin
    if FxEngine.AdjustForNewStrength(creature, 18, 100, enc) then
      if GDVars.ifcState = C_Ifc.COMBAT then begin
        GDVars.ifcState := C_Ifc.CAMPING;
        CharHlp.PrintNameString(creature, 'is stronger', 10, True);
        GDVars.ifcState := C_Ifc.COMBAT;
      end else
        CharHlp.PrintNameString(creature, 'is stronger', 10, True);
    GDVars.dsRedrawInventoryMenuFlag := 1;
    FxEngine.AddEffect(creature, C_Effect.STRENGTH, 0, enc, True);
  end;
end;

{ Aligned weapon (eff 132). The item's effect byte holds the required alignment in its low nibble; a wielder of another
  alignment has it unreadied and takes magic damage equal to the upper nibble, with a message naming the item }

procedure EffAlignedWeapon(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  dmg: Byte;
begin
  item := p;
  if removed then Exit;
  if item^.effect and $F <> creature^.alignment then begin
    item^.equipped := 0;
    dmg := item^.effect div 16;
    GDVars.elementMask := 8;
    if GDVars.ifcState = C_Ifc.COMBAT then
      CharHlp.DisplayCombatInterface;
    FxEngine.InflictItemShock(creature, item, dmg);
    GDVars.dsRedrawInventoryMenuFlag := 1;
  end;
end;

{ Boulder (eff 135): readying it without Strength 19+ unreadies it ("Must have Giant Strength") }

procedure EffBoulder(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := p;
  if removed then Exit;
  if creature^.strCur < 19 then begin
    item^.equipped := 0;
    CharHlp.PrintBottomLine('Must have Giant Strength');
  end;
end;

{ Spiritual Hammer unreadied (eff 137) }

procedure EffHammerGone(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then
    FxEngine.RemoveEffect(creature, C_Effect.SPIRIT_HAMMER, nil);
end;

{ the do-nothing handler (eff 5, 13, 16, 19, 24, 27, 54, 55, 60, 63, 92, 127) }

procedure EffNull(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

{ Install the effect handlers. Magic assigns slot 88; slots 73 and 74 use the CbtActs combat action handlers. }

procedure InitEffectHandlers;
begin
  GDVars.effectFns[C_Effect.BLESS] := EffHndlr.EffBless;
  GDVars.effectFns[C_Effect.CURSE] := EffHndlr.EffCurse;
  GDVars.effectFns[C_Effect.UNDEAD_SLAYER] := EffHndlr.EffUndeadSlayer;
  GDVars.effectFns[C_Effect.TRAIN_START] := EffHndlr.EffTrainStart;
  GDVars.effectFns[C_Effect.DETECT_MAGIC] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.FLAME_TONGUE] := EffHndlr.EffFlameTongue;
  GDVars.effectFns[C_Effect.TRAIN_MANUAL] := EffHndlr.EffTrainManual;
  GDVars.effectFns[C_Effect.PROT_EVIL] := EffHndlr.EffProtEvil;
  GDVars.effectFns[C_Effect.PROT_GOOD] := EffHndlr.EffProtGood;
  GDVars.effectFns[C_Effect.RESIST_COLD] := EffHndlr.EffResistCold;
  GDVars.effectFns[C_Effect.CHARM] := EffHndlr.EffCharm;
  GDVars.effectFns[C_Effect.ENLARGE] := EffHndlr.EffExtraStr;
  GDVars.effectFns[C_Effect.REDUCE] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.FRIENDS] := EffHndlr.EffFriends;
  GDVars.effectFns[C_Effect.SLOW_POISON_HIT] := EffHndlr.EffSlowPoisonHit;
  GDVars.effectFns[C_Effect.READ_MAGIC] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.SHIELD] := EffHndlr.EffShield;
  GDVars.effectFns[C_Effect.GNOME_THAC0] := EffHndlr.EffGnomeThac0;
  GDVars.effectFns[C_Effect.FIND_TRAPS] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.RESIST_FIRE] := EffHndlr.EffResistFire;
  GDVars.effectFns[C_Effect.SILENCE] := EffHndlr.EffSilence;
  GDVars.effectFns[C_Effect.SLOW_POISON_END] := EffHndlr.EffSlowPoisonEnd;
  GDVars.effectFns[C_Effect.SPIRIT_HAMMER] := EffHndlr.EffSpiritHammer;
  GDVars.effectFns[C_Effect.SEE_INVISIBLE] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.INVISIBLE] := EffHndlr.EffInvisible;
  GDVars.effectFns[C_Effect.DWARF_THAC0] := EffHndlr.EffDwarfThac0;
  GDVars.effectFns[C_Effect.FEATHER_FALL] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.MIRROR_IMAGE] := EffHndlr.EffMirrorImage;
  GDVars.effectFns[C_Effect.ENFEEBLE] := EffHndlr.EffEnfeeble;
  GDVars.effectFns[C_Effect.STINK_COUGH] := EffHndlr.EffStinkCough;
  GDVars.effectFns[C_Effect.HELPLESS] := EffHndlr.EffHelpless;
  GDVars.effectFns[C_Effect.ANIMATE_DEAD] := EffHndlr.EffAnimateDead;
  GDVars.effectFns[C_Effect.BLIND] := EffHndlr.EffBlind;
  GDVars.effectFns[C_Effect.DISEASED] := EffHndlr.EffDiseased;
  GDVars.effectFns[C_Effect.ALLIED_PRAYER] := EffHndlr.EffAlliedPrayer;
  GDVars.effectFns[C_Effect.BESTOW_CURSE] := EffHndlr.EffBestowCurse;
  GDVars.effectFns[C_Effect.BLINKING] := EffHndlr.EffBlinking;
  GDVars.effectFns[C_Effect.STRENGTH] := EffHndlr.EffExtraStr;
  GDVars.effectFns[C_Effect.HASTED] := EffHndlr.EffHasted;
  GDVars.effectFns[C_Effect.CAST_STINK] := EffHndlr.EffCastStink;
  GDVars.effectFns[C_Effect.PROT_MISSILES] := EffHndlr.EffProtMissiles;
  GDVars.effectFns[C_Effect.SLOWED] := EffHndlr.EffSlowed;
  GDVars.effectFns[C_Effect.DISEASE_STR] := EffHndlr.EffDiseaseStr;
  GDVars.effectFns[C_Effect.DISEASE_HP] := EffHndlr.EffDiseaseHp;
  GDVars.effectFns[C_Effect.PROT_EVIL_10FT] := EffHndlr.EffProtEvil;
  GDVars.effectFns[C_Effect.PROT_GOOD_10FT] := EffHndlr.EffProtGood;
  GDVars.effectFns[C_Effect.DWARF_AC_GIANT] := EffHndlr.EffDwarfAcGiant;
  GDVars.effectFns[C_Effect.GNOME_AC_BUG] := EffHndlr.EffGnomeAcBug;
  GDVars.effectFns[C_Effect.PRAYER] := EffHndlr.EffPrayer;
  GDVars.effectFns[C_Effect.ROT_NO_HEAL] := EffHndlr.EffRotNoHeal;
  GDVars.effectFns[C_Effect.SNAKE_CHARM] := EffHndlr.EffHelpless;
  GDVars.effectFns[C_Effect.PARALYSIS] := EffHndlr.EffHelpless;
  GDVars.effectFns[C_Effect.SLEEP] := EffHndlr.EffHelpless;
  { A milder dragon fear that only marks the creature (camp lists it as Repulsed); the full fear is DRAGON_FEAR. }
  GDVars.effectFns[C_Effect.DRAGON_AURA] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.POISONED] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.RING_INVIS] := EffHndlr.EffRingInvis;
  GDVars.effectFns[C_Effect.MUMMY_ROT] := EffHndlr.EffMummyRot;
  GDVars.effectFns[C_Effect.IMMOBILE] := EffHndlr.EffImmobile;
  GDVars.effectFns[C_Effect.TROLL_REGEN] := EffHndlr.EffTrollRegen;
  GDVars.effectFns[60] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.RING_FIRE_RES] := EffHndlr.EffRingFireRes;
  GDVars.effectFns[C_Effect.CON_REGEN] := EffHndlr.EffConRegen;
  GDVars.effectFns[63] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.POISON_HIT0] := EffHndlr.EffPoisonHit0;
  GDVars.effectFns[C_Effect.POISON_HIT4] := EffHndlr.EffPoisonHit4;
  GDVars.effectFns[C_Effect.POISON_HIT2] := EffHndlr.EffPoisonHit2;
  GDVars.effectFns[C_Effect.KREEN_PARA] := EffHndlr.EffKreenPara;
  GDVars.effectFns[C_Effect.GHOUL_PARA] := EffHndlr.EffGhoulPara;
  GDVars.effectFns[C_Effect.DRIDER_PARA] := EffHndlr.EffDriderPara;
  GDVars.effectFns[C_Effect.POISON_HIT_M2] := EffHndlr.EffPoisonHitM2;
  GDVars.effectFns[C_Effect.DUST_DISAPPEAR] := EffHndlr.EffDustDisappear;
  GDVars.effectFns[C_Effect.CAMOUFLAGE] := EffHndlr.EffCamouflage;
  GDVars.effectFns[C_Effect.REAR_CLAW_RAKE] := CbtActs.RearClawRake;
  GDVars.effectFns[C_Effect.BITE_HOLD] := CbtActs.BiteAndHold;
  GDVars.effectFns[C_Effect.BLOOD_DRAIN] := EffHndlr.EffBloodDrain;
  GDVars.effectFns[C_Effect.BLOOD_ATTACH] := EffHndlr.EffBloodAttach;
  GDVars.effectFns[C_Effect.BITE_ATTACH] := EffHndlr.EffBiteHold;
  GDVars.effectFns[C_Effect.HEAL_WAKE] := EffHndlr.EffHealWake;
  GDVars.effectFns[C_Effect.FIRE_TOUCH] := EffHndlr.EffFireTouch;
  GDVars.effectFns[C_Effect.ACID_SQUIRT] := EffHndlr.EffAcidSquirt;
  GDVars.effectFns[C_Effect.DRAGON_FEAR] := EffHndlr.EffDragonFear;
  GDVars.effectFns[C_Effect.MUMMY_FEAR] := EffHndlr.EffMummyFear;
  GDVars.effectFns[C_Effect.PETRIFY_GAZE] := EffHndlr.EffPetrifyGaze;
  GDVars.effectFns[C_Effect.CHARM_GAZE] := EffHndlr.EffCharmGaze;
  GDVars.effectFns[C_Effect.DRAIN_ONE] := EffHndlr.EffDrainOne;
  GDVars.effectFns[C_Effect.DRAIN_TWO] := EffHndlr.EffDrainTwo;
  GDVars.effectFns[C_Effect.ROT_TOUCH] := EffHndlr.EffRotTouch;
  GDVars.effectFns[C_Effect.DISPLACED] := EffHndlr.EffDisplaced;
  GDVars.effectFns[C_Effect.CON_PSN_SAVE] := EffHndlr.EffConPsnSave;
  GDVars.effectFns[C_Effect.IMMUNE_MM] := EffHndlr.EffImmuneMM;
  GDVars.effectFns[92] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.HALF_FIRE] := EffHndlr.EffHalfFire;
  GDVars.effectFns[C_Effect.HALF_BASH] := EffHndlr.EffHalfBash;
  GDVars.effectFns[C_Effect.FIGHT_ON] := EffHndlr.EffFightOn;
  GDVars.effectFns[C_Effect.NEED_SILVER] := EffHndlr.EffNeedSilver;
  GDVars.effectFns[C_Effect.CON_SPELL_SAVE] := EffHndlr.EffConSpellSave;
  GDVars.effectFns[C_Effect.REGEN3] := EffHndlr.EffRegen3;
  GDVars.effectFns[C_Effect.CAN_FIGHT_ON] := EffHndlr.EffCanFightOn;
  GDVars.effectFns[C_Effect.TROLL_BURN] := EffHndlr.EffTrollBurn;
  GDVars.effectFns[C_Effect.TROLL_HEAL] := EffHndlr.EffTrollHeal;
  GDVars.effectFns[C_Effect.TROLL_RETURN] := EffHndlr.EffTrollReturn;
  GDVars.effectFns[C_Effect.GASEOUS] := EffHndlr.EffGaseous;
  GDVars.effectFns[C_Effect.KREEN_DODGE] := EffHndlr.EffKreenDodge;
  GDVars.effectFns[C_Effect.MAGIC_RES50] := EffHndlr.EffMagicRes50;
  GDVars.effectFns[C_Effect.MAGIC_RES85] := EffHndlr.EffMagicRes85;
  GDVars.effectFns[C_Effect.ELF_RESIST] := EffHndlr.EffElfResist;
  GDVars.effectFns[C_Effect.NO_SLEEP_CHARM] := EffHndlr.EffNoSleepCharm;
  GDVars.effectFns[C_Effect.NO_PARALYSIS] := EffHndlr.EffNoParalysis;
  GDVars.effectFns[C_Effect.NO_COLD] := EffHndlr.EffNoCold;
  GDVars.effectFns[C_Effect.NO_PARA_POISON] := EffHndlr.EffNoParaPoison;
  GDVars.effectFns[C_Effect.NO_FIRE] := EffHndlr.EffNoFire;
  GDVars.effectFns[C_Effect.EFREETI_FIRE] := EffHndlr.EffEfreetiFire;
  GDVars.effectFns[C_Effect.HALF_ELEC] := EffHndlr.EffHalfElec;
  GDVars.effectFns[C_Effect.HALF_PIERCE] := EffHndlr.EffHalfPierce;
  GDVars.effectFns[C_Effect.HALF_MAGICAL] := EffHndlr.EffHalfMagical;
  GDVars.effectFns[C_Effect.HOLY_WATER] := EffHndlr.EffHolyWater;
  GDVars.effectFns[C_Effect.HALF_COLD] := EffHndlr.EffHalfCold;
  GDVars.effectFns[C_Effect.NEED_MAGIC] := EffHndlr.EffNeedMagic;
  GDVars.effectFns[C_Effect.BOULDER_DODGE] := EffHndlr.EffBoulderDodge;
  GDVars.effectFns[C_Effect.ANHKHEG_ACID] := EffHndlr.EffAnhkhegAcid;
  GDVars.effectFns[C_Effect.MUMMY_FIRE] := EffHndlr.EffMummyFire;
  GDVars.effectFns[C_Effect.SILVER_MAGIC] := EffHndlr.EffSilverMagic;
  GDVars.effectFns[C_Effect.HALF_ELF_RESIST] := EffHndlr.EffHalfElfResist;
  GDVars.effectFns[C_Effect.NO_CHARM_POISON] := EffHndlr.EffNoCharmPoison;
  GDVars.effectFns[C_Effect.GAZE_BLOCK] := EffHndlr.EffGazeBlock;
  GDVars.effectFns[C_Effect.GAZE_REFLECTABLE] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.READY_FEATHER_FALL] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.READY_FIRE_RES] := EffHndlr.EffReadyItem;
  GDVars.effectFns[130] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.GAUNTLETS] := EffHndlr.EffGauntlets;
  GDVars.effectFns[C_Effect.ALIGNED_WEAPON] := EffHndlr.EffAlignedWeapon;
  GDVars.effectFns[C_Effect.READY_DISPLACEMENT] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.READY_ELVENKIND] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.BOULDER] := EffHndlr.EffBoulder;
  GDVars.effectFns[136] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.SPIRIT_HAMMER_GONE] := EffHndlr.EffHammerGone;
  GDVars.effectFns[138] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.READY_RING_INVIS] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.RECENT_HEAL] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.RECENT_CURE] := EffHndlr.EffNull;
end;

end.
