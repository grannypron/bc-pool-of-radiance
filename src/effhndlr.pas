{ Effect handlers for spells, items and creature abilities. Each handler receives the creature, the effect node or item
  concerned, and whether the effect is being removed or the item unreadied; it works through shared combat state such as
  GDVars.pendingDamage, the attack roll and GDVars.gSaveRoll. }
{$O+,F+}
{$I COMPILER.INC}
unit EffHndlr;

interface

uses Types;

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

{ Make the creature's displacement (eff 89) due again: CombatSt.CombatStart calls it for every creature. Only the first
  node counts, as only it is triggered. }
procedure ResetDisplacement(creature: Types.PCharRecord);

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

function TouchImmune(target: Types.PCharRecord; effId: Byte): Boolean;

implementation

uses C_Item, C_Npc, C_Terr, C_Save, C_COND, GDConsts, GDVars, CbtActs, ClassCal, FxEngine, Debug, C_EFFECT, C_Equip,
  C_Race, C_STATUS, C_Ifc, C_ALIGN, C_SPELL, CbtMap, CharHlp, Pathing, TextRend, StrUtil, CharDisp, AbilAdj,
  C_Level, Dice, Stats;

const
  { set by TouchImmune for its immunity check: a monster's poisonous or paralyzing touch is no magic, so magic
    resistance does not meet it (MagicResistance; #800) }
  mundaneCheck: Boolean = False;

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

{ Print "<name> <msg>", then set the status (dead, stoned or gone), disable the creature with 0 HP, count a party
  member's death (dead or gone) in its statistics (#796), remove the effects that end at 0 HP, run the C_COND.HP_ZERO
  effects and, if it is still disabled, hand it to CbtMap.CreatureDowned. Then pause, clear the message window and, out
  of combat, redisplay the party. The message prints first: for a creature already dead, stoned or gone it is all that
  happens. }
procedure InflictStatusMsg(creature: Types.PCharRecord; status: Byte; msg: Types.TStr40);
begin
  CharDisp.PrintNameString(creature, msg, 10, False);
  case creature^.status of
    C_STATUS.STONED, C_STATUS.DEAD, C_STATUS.GONE: Exit;
  end;
  creature^.status := status;
  creature^.enabled := 0;
  creature^.hpCur := 0;
  if status in [C_STATUS.DEAD, C_STATUS.GONE] then
    Stats.Death(creature);
  FxEngine.RemoveEffectsHp0(creature);
  FxEngine.TriggerEffectsWithCondition(C_COND.HP_ZERO, creature);
  if creature^.enabled = 0 then
    CbtMap.CreatureDowned(creature);
  TextRend.PauseOnly;
  CharDisp.ClearMessageWindow;
  if GDVars.ifcState <> C_Ifc.COMBAT then
    CharDisp.DisplayParty(GDVars.curChar);
end;

{ Bless (eff 1) }
procedure EffBless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Inc(GDVars.currentMorale, 5);
  Inc(GDVars.gAttackRoll);
end;

{ Curse (eff 2) }
procedure EffCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.currentMorale < 5 then
    GDVars.currentMorale := 0
  else
    Dec(GDVars.currentMorale, 5);
  Dec(GDVars.gAttackRoll);
end;

{ Undead slaying weapon (eff 3) }
procedure EffUndeadSlayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  { undead }
  if GDVars.otherCreatureCurrentPtr^.charType = 4 then begin
    Inc(GDVars.gAttackRoll, 2);
    Inc(GDVars.pendingDamage, 2);
  end;
end;

{ Start training with a Manual of Bodily Health (eff 4): add eff 7 for 43200 minutes }
procedure EffTrainStart(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  CharDisp.PrintNameString(creature, 'starts to train', 10, True);
  FxEngine.AddEffect(creature, C_EFFECT.TRAIN_MANUAL, 43200, 255, True);
end;

{ Flame Tongue weapon (eff 6) }
procedure EffFlameTongue(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  bonus: Byte;
begin
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  case GDVars.otherCreatureCurrentPtr^.charType of
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
  GDVars.elementMask := C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC;
end;

{ Manual of Bodily Health training done (eff 7): +1 Constitution and the matching hit-point change, the Con table's
  bonus at the new Constitution less the bonus at the old over every hit die (ClassCal.ConHpTotal), with hpMax capped at
  255. At Constitution 20 or more a creature without it gets eff 62 (regeneration) at its Constitution's interval
  (AbilAdj.ConRegenMinutes); before, each Manual at 20 or more added another, and the hit points stopped at 19. }
procedure EffTrainManual(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  hpGain: Integer;
  effect: Types.PEffectRec;
begin
  CharDisp.PrintNameString(creature, 'is hardier', 10, True);
  creature^.conCur := AbilAdj.ClampScore(creature^.conCur + 1);
  if (creature^.conCur >= 20) and not CharHlp.HasEffect(creature, C_EFFECT.CON_REGEN, effect) then
    FxEngine.AddEffect(creature, C_EFFECT.CON_REGEN, AbilAdj.ConRegenMinutes(creature^.conCur), 255, True);
  hpGain := ClassCal.ConHpTotal(creature, creature^.conCur) - ClassCal.ConHpTotal(creature, creature^.conCur - 1);
  if hpGain > 255 - creature^.hpMax then
    hpGain := 255 - creature^.hpMax;
  if hpGain > 0 then begin
    Inc(creature^.hpMax, hpGain);
    Inc(creature^.hpCur, hpGain);
  end;
end;

{ Protection from Evil and from Good: +2 to saving throws and -2 to be hit when foe holds, that is when the attacker or
  caster (GDVars.curChar) has the alignment warded against, and it is on the other side. A script's attack or damage has
  no attacker, and curChar is then a party member. The penalty is taken under C_COND.ATTACK_ROLL_DEF, after the d20 is
  rolled; SSI's took it under C_COND.DEFENDER_AC, before the roll replaced it, so it never applied (#789). }
procedure Protection(creature: Types.PCharRecord; foe: Boolean);
begin
  if foe and (GDVars.curChar^.hostile <> creature^.hostile) then begin
    Inc(GDVars.gSaveRoll, 2);
    Dec(GDVars.gAttackRoll, 2);
  end;
end;

{ Protection from Evil (eff 8, 45) }
procedure EffProtEvil(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.Protection(creature, GDVars.curChar^.alignment in [C_ALIGN.LAWFUL_EVIL, C_ALIGN.NEUTRAL_EVIL,
                                                               C_ALIGN.CHAOTIC_EVIL]);
end;

{ Protection from Good (eff 9, 46) }
procedure EffProtGood(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.Protection(creature, GDVars.curChar^.alignment in [C_ALIGN.LAWFUL_GOOD, C_ALIGN.NEUTRAL_GOOD,
                                                               C_ALIGN.CHAOTIC_GOOD]);
end;

{ Resist Cold (eff 10) }
procedure EffResistCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and C_EFFECT.ELEM_COLD <> 0 then begin
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
      Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength + $20 + CharHlp.Team(creature) * 64;
      creature^.hostile := Types.PEffectRec(p)^.strength div 128;
      creature^.quickfight := 1;
      { C_Npc.FLAG clear }
      if not CharHlp.IsNpc(creature) then
        creature^.npc := C_Npc.ANIMATED_PC;
      creature^.combatAddr^.other := nil;
      CharHlp.CountTeams;
    end;
    GDVars.currentMorale := 100;
  end;
end;

{ Enlarge and Strength (eff 12, 38). Sets Strength to the value stored in this node, then applies the strongest other
  Enlarge or Strength node, which takes over the Strength to restore. A node whose strength byte is above $7F is
  ignored. The Strength set is less a disease's loss, and the Strength handed over has it given back
  (CharHlp.DiseaseStrLoss). }
procedure EffExtraStr(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  base: Byte;
  exc: Byte;
  bestBase: Byte;
  bestExc: Byte;
  q: Types.PEffectRec;
  best: Types.PEffectRec;
  restored: Byte;
  loss: Byte;
begin
  if Types.PEffectRec(p)^.strength > $7F then Exit;
  loss := CharHlp.DiseaseStrLoss(creature);
  AbilAdj.StrengthEffectToStrength(p, base, exc);
  { the creature's own Strength, kept whole for the node that takes over }
  restored := AbilAdj.StrengthModifier(AbilAdj.ClampScore(base), exc);
  creature^.strCur := AbilAdj.ClampScore(Integer(base) - loss);
  creature^.strExc := exc;
  best := nil;
  bestBase := 0;
  bestExc := 0;
  q := creature^.effectsAddr;
  while q <> nil do begin
    if (q^.id = C_EFFECT.ENLARGE) or (q^.id = C_EFFECT.STRENGTH) then
      if q <> Types.PEffectRec(p) then begin
        AbilAdj.StrengthEffectToStrength(q, base, exc);
        if (base > bestBase) or ((bestBase = 18) and (exc > bestExc)) then begin
          bestBase := base;
          bestExc := exc;
          best := q;
        end;
      end;
    q := q^.next;
  end;
  if best <> nil then begin
    Types.PEffectRec(best)^.strength := restored;
    creature^.strCur := AbilAdj.ClampScore(Integer(bestBase) - loss);
    creature^.strExc := bestExc;
  end;
end;

{ Friends (eff 14) }
procedure EffFriends(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  creature^.chaCur := AbilAdj.ClampScore(Types.PEffectRec(p)^.strength);
end;

{ Slow Poison periodic damage (eff 15): re-arm for 10 minutes and deal 1 damage while HP > 1 }
procedure EffSlowPoisonHit(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.SLOW_POISON_HIT, Types.PEffectRec(p)^.strength, 10) then
    if creature^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(creature, 1, 0, False);
      if GDVars.ifcState <> C_Ifc.COMBAT then
        CharDisp.DisplayParty(GDVars.curChar);
    end;
end;

{ Shield (eff 17) }
procedure EffShield(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  { 60-biased AC 3 }
  if creature^.acCur < 57 then
    creature^.acCur := 57;
  Inc(GDVars.gSaveRoll);
  if GDVars.currentSpellBeing = C_SPELL.MAGIC_MISSILE then
    GDVars.pendingDamage := 0;
end;

{ Gnome THAC0 bonus (eff 18) }
procedure EffGnomeThac0(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  { charType 0 or 1: the monster data gives some listed foes type 0 (HOBGOBLIN LDR, GRISHNAK) }
  if GDVars.otherCreatureCurrentPtr^.charType <= 1 then
    if GDVars.otherCreatureCurrentPtr^.iconDimensions = 1 then
      { 5 = High(gnomeFoes) }
      for i := 1 to 5 do
        if GDVars.otherCreatureCurrentPtr^.name = GDConsts.gnomeFoes[i] then
          Inc(GDVars.gAttackRoll);
end;

{ Resist Fire (eff 20) }
procedure EffResistFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and C_EFFECT.ELEM_FIRE <> 0 then begin
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
    Inc(GDVars.gSaveRoll, 3);
  end;
end;

{ Silence 15' (eff 21) }
procedure EffSilence(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.itemUseAllowed <> 0 then
    CharDisp.PrintNameString(creature, 'is silenced', 10, True);
  creature^.combatAddr^.itemUseAllowed := 0;
  creature^.combatAddr^.castAllowed := 0;
end;

{ Slow Poison expiration (eff 22): a creature still poisoned (eff 55) dies; eff 15 is removed under the effect lock }
procedure EffSlowPoisonEnd(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if CharHlp.HasEffect(creature, C_EFFECT.POISONED, effect) then
    EffHndlr.InflictStatusMsg(creature, C_STATUS.DEAD, 'dies from poison');
  GDVars.effectLock := 1;
  FxEngine.RemoveEffect(creature, C_EFFECT.SLOW_POISON_HIT, nil);
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
    if (item^.itemType = C_Item.HAMMER) and (item^.nameIds[3] = C_Item.NAME_SPIRITUAL) then
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
        item^.nameIds[2] := C_Item.NAME_HAMMER;
        item^.nameIds[3] := C_Item.NAME_SPIRITUAL;
        item^.plus := 1;
        item^.effect := C_EFFECT.SPIRIT_HAMMER;
        item^.special := C_EFFECT.SPIRIT_HAMMER_GONE;
        CharHlp.AppendItemCopy(creature^.itemsAddr, item);
        FreeMem(item, SizeOf(Types.TItemRec));
        CharDisp.PrintNameString(creature, 'Gains an item', 10, True);
      end;
  CharHlp.RecalcStats(creature);
end;

{ Invisibility (eff 25) }
procedure EffInvisible(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if not CharHlp.HasEffect(GDVars.curChar, C_EFFECT.SEE_INVISIBLE, effect) then
    GDVars.currentSuppressTargetingFlag := 1;
  Dec(GDVars.gAttackRoll, 4);
end;

{ Dwarf THAC0 bonus (eff 26) }
procedure EffDwarfThac0(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  { charType 0 or 1: the monster data gives some listed foes type 0 (HOBGOBLIN LDR, GRISHNAK) }
  if GDVars.otherCreatureCurrentPtr^.charType <= 1 then
    if GDVars.otherCreatureCurrentPtr^.iconDimensions = 1 then
      { 11 = High(dwarfFoes) }
      for i := 1 to 11 do
        if GDVars.otherCreatureCurrentPtr^.name = GDConsts.dwarfFoes[i] then
          Inc(GDVars.gAttackRoll);
end;

{ Mirror Image (eff 28). strength = images left; against a single-target spell (currentSpellBeing > 0, gMultiTarget =
  0) an image absorbs it unless 1d(images + 1) rolls 1. Weapon hits are tested in CbtActs.DoAttack. }
procedure EffMirrorImage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if Dice.RollDice(1, Types.PEffectRec(p)^.strength + 1) > 1 then
    if GDVars.currentSpellBeing > 0 then
      if GDVars.gMultiTarget = 0 then begin
        EffHndlr.NullifyAttack(0);
        CharDisp.PrintNameString(creature, 'lost an image', 10, True);
        Dec(Types.PEffectRec(p)^.strength);
        if Types.PEffectRec(p)^.strength = 0 then
          FxEngine.RemoveEffect(creature, C_EFFECT.MIRROR_IMAGE, nil);
      end;
end;

{ Ray of Enfeeblement (eff 29): pendingDamage loses a quarter (rounded down) }
procedure EffEnfeeble(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.pendingDamage := GDVars.pendingDamage - GDVars.pendingDamage div 4;
end;

{ Coughing from Stinking Cloud (eff 30): no items or spells, and its AC from the front and behind is its rear AC less 2.
  It recalculates the creature's stats, so C_COND.DEFENDER_AC runs it before Blindness and Shield change the AC. }
procedure EffStinkCough(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.itemUseAllowed <> 0 then
    CharDisp.PrintNameString(creature, 'is coughing', 10, True);
  creature^.combatAddr^.itemUseAllowed := 0;
  creature^.combatAddr^.castAllowed := 0;
  CharHlp.RecalcStats(creature);
  if creature^.acBehind > 52 then
    Dec(creature^.acBehind, 2)
  else
    creature^.acBehind := 50;
  creature^.acCur := creature^.acBehind;
  if creature = GDVars.curChar then
    CharDisp.CombatPrintCreatureInfo(creature);
end;

{ Animate Dead (eff 32). Fires on REMOVAL of the animation. The old side is read first: for a corpse that fled
  (C_STATUS.RUNNING), InflictStatusMsg removes the hp-zero effects again, which frees this node (#716). }
procedure EffAnimateDead(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  side: Byte;
begin
  Types.PEffectRec(p)^.onRemove := False;
  side := Types.PEffectRec(p)^.strength div 16 and 1;
  if GDVars.effectLock = 0 then
    EffHndlr.InflictStatusMsg(creature, C_STATUS.DEAD, 'collapses');
  creature^.hostile := side;
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
  FxEngine.CallEffectHandler(C_EFFECT.DISEASE_STR, creature, p, removed);
  FxEngine.CallEffectHandler(C_EFFECT.DISEASE_HP, creature, p, removed);
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
    GDVars.currentSuppressTargetingFlag := 1;
    GDVars.gAttackAvoided := True;
  end;
end;

{ Hasted (eff 39). Ages the creature one year the first time it fires (strength bit 4 marks that it has), and doubles
  currentAttackCurrent by CharHlp.HasteSlowRate: with Slowed too, the two cancel, and each handler leaves the rate as
  it is. }
procedure EffHasted(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if Types.PEffectRec(p)^.strength and $10 = 0 then begin
    Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength + $10;
    CharDisp.PrintNameString(creature, 'ages', 10, True);
    Inc(creature^.age);
  end;
  GDVars.currentAttackCurrent := CharHlp.HasteSlowRate(creature, GDVars.currentAttackCurrent);
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
  CharDisp.PrintBottomLine('The air clears a little...');
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
    if CbtMap.CalcDistance(GDVars.curChar, creature) > 1 then
      if Dice.RollDice(1, 100) <= pct then begin
        CharDisp.PrintNameString(creature, 'Avoids it', 10, True);
        GDVars.pendingDamage := 0;
        GDVars.gAttackAvoided := True;
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

{ Protection from Normal Missiles (eff 41): a normal missile (the damaging item has no plus) is stopped; a magical one
  does 1 less per die, no die below 1 (#745) }
procedure EffProtMissiles(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  missile: Types.PItemRec;
begin
  missile := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if missile <> nil then
    if missile^.plus = 0 then
      EffHndlr.AvoidRanged(creature, 100)
    else if CbtMap.CalcDistance(GDVars.curChar, creature) > 1 then
      Dice.ReduceDamagePerDie(1);
end;

{ Slowed (eff 42): halves currentAttackCurrent by CharHlp.HasteSlowRate, as EffHasted doubles it. }
procedure EffSlowed(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.currentAttackCurrent := CharHlp.HasteSlowRate(creature, GDVars.currentAttackCurrent);
end;

{ Disease Strength drain (eff 43; p is this node, or Diseased's, eff 34, as the disease starts): re-arm for 60 minutes
  and lose 1 Strength; at Strength 3 become helpless. The node counts the Strength lost in its strength byte's upper
  nibble (CharHlp.DiseaseStrLoss), up to 15, the most a natural 18 can lose; the lower keeps the caster level, at most
  15. A cure removes the node under the effect lock, and the count is given back: SSI kept no count, and the Strength
  stayed lost (#705). }
procedure EffDiseaseStr(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
  loss: Byte;
  level: Byte;
  weaken: Boolean;
begin
  if Types.PEffectRec(p)^.id = C_EFFECT.DISEASE_STR then begin
    loss := Types.PEffectRec(p)^.strength shr 4;
    level := Types.PEffectRec(p)^.strength and $F;
  end else begin
    loss := 0;
    level := Types.PEffectRec(p)^.strength;
    if level > 15 then
      level := 15;
  end;
  weaken := (creature^.strCur > 3) and (loss < 15);
  if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.DISEASE_STR, (loss + Ord(weaken)) * 16 + level, 60) then begin
    if weaken then begin
      CharDisp.PrintNameString(creature, 'is weakened', 10, True);
      Dec(creature^.strCur);
      CharHlp.RecalcStats(creature);
    end else if creature^.strCur <= 3 then
      if not CharHlp.HasEffect(creature, C_EFFECT.HELPLESS, effect) then
        FxEngine.AddEffect(creature, C_EFFECT.HELPLESS, 0, 255, False);
  end else if removed and (Types.PEffectRec(p)^.id = C_EFFECT.DISEASE_STR) and (loss > 0) then begin
    creature^.strCur := AbilAdj.ClampScore(creature^.strCur + loss);
    CharHlp.RecalcStats(creature);
  end;
end;

{ Disease hit point drain (eff 44): re-arm for 10 minutes and deal 1 damage; at 1 HP become helpless }
procedure EffDiseaseHp(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.DISEASE_HP, Types.PEffectRec(p)^.strength, 10) then
    if creature^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(creature, 1, 0, False);
      if GDVars.ifcState <> C_Ifc.COMBAT then
        CharDisp.DisplayParty(GDVars.curChar);
    end else
      if not CharHlp.HasEffect(creature, C_EFFECT.HELPLESS, effect) then
        FxEngine.AddEffect(creature, C_EFFECT.HELPLESS, 0, 255, False);
end;

{ Dwarf/gnome AC bonus vs giants (eff 47) }
procedure EffDwarfAcGiant(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  { The attacker is curChar: its name is tested, as are its type and size, not that of the defender's own target.
    charType 0, 1, 2 or 10 and size 1 or 2: the monster data gives the listed giants these (OGRE LEADER type 0 and size
    1, HILL GIANT and FIRE GIANT type 2, TROLL type 10, OGRE and ETTIN type 1). }
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

{ Prayer (eff 49). FxEngine.PrayerSide = the caster's side: creatures on that team (CharHlp.Team) get the
  EffAlliedPrayer bonus, all others -1 to attack rolls and saving throws. FxEngine.TriggerPrayer runs one from each side
  in reach. }
procedure EffPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if CharHlp.Team(creature) = FxEngine.PrayerSide(p) then
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
  if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.ROT_NO_HEAL, Types.PEffectRec(p)^.strength, 14400) then
    if FxEngine.RestoreHitPoints(creature, 1, True) then
      CharDisp.PrintHpRestoreMsg(creature);
end;

{ Helpless (eff 31, 51, 52, 53) }
procedure EffHelpless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if CharHlp.EndActions(creature) then ;
end;

{ Wearing Ring of Invisibility (eff 56) }
procedure EffRingInvis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(creature, C_EFFECT.INVISIBLE, 1, 12, False);
end;

{ Mummy rot degeneration (eff 57). strength upper nibble = the 1d6 countdown seeded by eff 87. Each firing costs 2
  Charisma (not below 3); the creature re-arms for 43200 minutes while the count exceeds 1, then dies }
procedure EffMummyRot(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.effectLock <> 0 then Exit;
  CharDisp.PrintNameString(creature, 'Rots...', 10, True);
  creature^.chaCur := AbilAdj.ClampScore(creature^.chaCur - 2);
  if Types.PEffectRec(p)^.strength div 16 > 1 then begin
    Dec(Types.PEffectRec(p)^.strength, $10);
    if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.MUMMY_ROT, Types.PEffectRec(p)^.strength, 43200) then ;
  end else
    EffHndlr.InflictStatusMsg(creature, C_STATUS.GONE, 'Dies rots away');
end;

{ Immobile (eff 58) }
procedure EffImmobile(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  creature^.combatAddr^.movement := 0;
  if GDVars.currentCreatureCalculatingFlag <> 0 then
    GDVars.currentAttackCurrent := 0;
end;

{ Troll: add regeneration (eff 59): add eff 98 permanently }
procedure EffTrollRegen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(creature, C_EFFECT.REGEN3, 0, 255, False);
end;

{ Ring of Fire Resistance (eff 61): against fire, -2 damage per die (minimum 1 per die, but never more than the damage
  was) and +4 to save; non-magical fire is nullified }
procedure EffRingFireRes(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and C_EFFECT.ELEM_FIRE <> 0 then begin
    Dice.ReduceDamagePerDie(2);
    Inc(GDVars.gSaveRoll, 4);
    if GDVars.elementMask and C_EFFECT.ELEM_MAGIC = 0 then
      EffHndlr.NullifyAttack(0);
  end;
end;

{ Regenerating from high Con (eff 62): re-arm for the creature's Constitution's interval (AbilAdj.ConRegenMinutes; 60,
  Constitution 20's, once it has fallen below 20) and restore 1 HP }
procedure EffConRegen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  minutes: Word;
begin
  minutes := AbilAdj.ConRegenMinutes(creature^.conCur);
  if minutes = 0 then
    minutes := 60;
  if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.CON_REGEN, Types.PEffectRec(p)^.strength, minutes) then
    if FxEngine.RestoreHitPoints(creature, 1, True) then
      CharDisp.PrintHpRestoreMsg(creature);
end;

{ A touch's failed save: True, with "is Unaffected", when the target is immune to effId all the same
  (FxEngine.EffectImmune, the check FxEngine.AddEffectWithMessage makes), magic resistance aside: the touch is no magic
  (#800). SSI added the touch's effect with no immunity check: a paralysis ward (eff 109) never stopped a paralyzing
  touch (#767), and a poison-immune creature (eff 111, 125), whose saves vs. poison otherwise always succeed, died of
  poison on a natural 1 (#720). }
function TouchImmune(target: Types.PCharRecord; effId: Byte): Boolean;
var
  immune: Boolean;
begin
  mundaneCheck := True;
  immune := FxEngine.EffectImmune(target, effId);
  mundaneCheck := False;
  if immune then
    CharDisp.PrintNameString(target, 'is Unaffected', 10, True);
  TouchImmune := immune;
end;

{ Poison the attacker's combat target: unless it saves vs. paralyzation/poison with saveMod and its Constitution's
  poison bonus (AbilAdj.ConPoisonSave), or is immune to poison, it gets eff 55 and is killed. }
procedure PoisonTouch(creature: Types.PCharRecord; saveMod: ShortInt);
begin
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  if not FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, C_Save.PARALYZE,
                                  saveMod + AbilAdj.ConPoisonSave(GDVars.otherCreatureCurrentPtr^.conCur)) then
    if not EffHndlr.TouchImmune(GDVars.otherCreatureCurrentPtr, C_EFFECT.POISONED) then begin
      CharDisp.PrintNameString(GDVars.otherCreatureCurrentPtr, 'is Poisoned', 10, False);
      TextRend.PauseOnly;
      FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_EFFECT.POISONED, 0, 255, False);
      EffHndlr.InflictStatusMsg(GDVars.otherCreatureCurrentPtr, C_STATUS.DEAD, 'is killed');
    end;
end;

{ Paralyze the attacker's combat target for minutes unless it saves vs. paralyzation with saveMod or is immune to
  paralysis. SSI's ignored saveMod, so the drider's -2 was lost (#785). }
procedure ParalysisTouch(creature: Types.PCharRecord; minutes: Word; saveMod: ShortInt);
begin
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  if not FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, C_Save.PARALYZE, saveMod) then
    if not EffHndlr.TouchImmune(GDVars.otherCreatureCurrentPtr, C_EFFECT.PARALYSIS) then begin
      CharDisp.PrintNameStringAnim(GDVars.otherCreatureCurrentPtr, True, 'is Paralyzed');
      FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_EFFECT.PARALYSIS, minutes, 12, False);
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
  EffHndlr.ParalysisTouch(creature, Dice.RollDice(2, 8), 0);
end;

{ Ghoul paralysis (eff 68): 63 minutes, not vs. elves }
procedure EffGhoulPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.other^.race <> C_Race.ELF then
    EffHndlr.ParalysisTouch(creature, 63, 0);
end;

{ Drider paralysis (eff 69): 1d9+10 minutes, saved against at -2 }
procedure EffDriderPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.ParalysisTouch(creature, Dice.RollDice(1, 9) + 10, -2);
end;

{ Melee poison, -2 save (eff 70) }
procedure EffPoisonHitM2(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTouch(creature, -2);
end;

{ Dust of Disappearance (eff 71): a stronger form of invisibility. Sets currentSuppressTargetingFlag and lowers
  gAttackRoll by 4. }
procedure EffDustDisappear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.currentSuppressTargetingFlag := 1;
  Dec(GDVars.gAttackRoll, 4);
end;

{ Camouflaged / Cloak of Elvenkind (eff 72): 95% chance of invisibility (eff 25) for 1 minute }
procedure EffCamouflage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if Dice.RollDice(1, 100) <= 95 then
    FxEngine.AddEffect(creature, C_EFFECT.INVISIBLE, 1, 12, False);
end;

{ Blood drain (eff 75). strength = victim's creature index; duration's upper bits = the x16 damage budget. An index
  outside creatureArr[1..arenaCount] (CombatSlot's 0 for a creature not in the arena) has no victim: the effect just
  goes. }
procedure EffBloodDrain(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  done: Boolean;
  dmg: Byte;
  released: Boolean;
begin
  if FxEngine.HoldTarget(creature, p, removed, C_EFFECT.BLOOD_DRAIN, released) = nil then begin
    if released and (creature^.enabled <> 0) then
      if GDVars.otherCreatureCurrentPtr^.enabled <> 0 then
        creature^.combatAddr^.turned := 1;
  end else begin
    CharDisp.PrintNameString(creature, 'Sucks some Blood', 10, True);
    dmg := Dice.RollDamageDice(1, 4);
    GDVars.elementMask := 0;
    FxEngine.InflictNonWeaponDamage(GDVars.otherCreatureCurrentPtr, dmg, 0, False);
    done := CharHlp.EndActions(creature);
    if (GDVars.otherCreatureCurrentPtr^.enabled <> 0) and (Types.PEffectRec(p)^.duration div 16 > dmg) then
      Dec(Types.PEffectRec(p)^.duration, dmg * 16)
    else
      FxEngine.RemoveEffect(creature, C_EFFECT.BLOOD_DRAIN, p);
  end;
end;

{ Blood drain attachment (eff 76): add eff 75 on the attacker with a 12 hp budget and immobilize the target. A target
  with no combat slot (none, or not on the map) is not drained. }
procedure EffBloodAttach(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  slot: Byte;
begin
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
    Exit;
  slot := CbtMap.CombatSlot(GDVars.otherCreatureCurrentPtr);
  if slot = 0 then
    Exit;
  { a 12 hp budget in the upper bits of the duration }
  FxEngine.AddEffect(creature, C_EFFECT.BLOOD_DRAIN, 12 * 16 + 15, slot, True);
  FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_EFFECT.IMMOBILE, 0, 255, False);
  FxEngine.CallEffectHandler(C_EFFECT.IMMOBILE, GDVars.otherCreatureCurrentPtr, nil, False);
end;

{ Bite attach (eff 77): add eff 74 (bite and hold, handled by CbtActs.BiteAndHold) on the biter and immobilize the
  target. No effect on a target with Strength 19+, or with no combat slot (none, or not on the map) }
procedure EffBiteHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  slot: Byte;
begin
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  if GDVars.otherCreatureCurrentPtr = nil then
    Exit;
  slot := CbtMap.CombatSlot(GDVars.otherCreatureCurrentPtr);
  if slot = 0 then
    Exit;
  if GDVars.otherCreatureCurrentPtr^.strCur < 19 then begin
    FxEngine.AddEffect(creature, C_EFFECT.BITE_HOLD, 0, slot, True);
    FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_EFFECT.IMMOBILE, 0, 255, False);
    FxEngine.CallEffectHandler(C_EFFECT.IMMOBILE, GDVars.otherCreatureCurrentPtr, nil, False);
    CharDisp.PrintNameString(GDVars.otherCreatureCurrentPtr, 'is held fast', 10, True);
  end;
end;

{ Healed from unconscious (eff 78): revive at the current HP, or retry in 1 minute if that fails }
procedure EffHealWake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  dummy: Boolean;
begin
  if not FxEngine.ReviveDeadCreature(creature, creature^.hpCur) then
    dummy := EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.HEAL_WAKE, Types.PEffectRec(p)^.strength, 1);
end;

{ Melee fire touch (eff 79): +2d10 fire }
procedure EffFireTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.elementMask := C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC;
  FxEngine.InflictNonWeaponDamage(creature^.combatAddr^.other, Dice.RollDamageDice(2, 10), 0, False);
end;

{ Melee acid squirt (eff 80): +1d4 acid }
procedure EffAcidSquirt(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GDVars.elementMask := C_EFFECT.ELEM_ACID;
  FxEngine.InflictNonWeaponDamage(creature^.combatAddr^.other, Dice.RollDamageDice(1, 4), 0, False);
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
          0..3: FxEngine.AddEffectWithMessage(q, C_EFFECT.PARALYSIS, 0, 12, False, True, saved,
                                              'is paralyzed with fear');
          4, 5: FxEngine.AddEffectWithMessage(q, C_EFFECT.CURSE, 0, 12, False, True, saved, 'is weakened by fear');
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
    FxEngine.RemoveEffect(q, C_EFFECT.MUMMY_FEAR, nil);
    if q^.enabled <> 0 then
      if CharHlp.EnemyTeam(creature) = q^.hostile then begin
        bonus := 0;
        if GDVars.teamCount[q^.hostile] >= 6 then
          Inc(bonus);
        if q^.race = C_Race.HUMAN then
          Inc(bonus, 2);
        saved := FxEngine.RollSavingThrow(q, C_Save.PARALYZE, bonus);
        FxEngine.AddEffectWithMessage(q, C_EFFECT.PARALYSIS, Dice.RollDice(1, 4), 12, False, True, saved,
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
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  CharDisp.PrintNameString(creature, 'gazes...', 10, False);
  CharDisp.BuildIconFacings(18);
  CharDisp.CombatAnimateMovingIcon(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                  CbtMap.CombatCellX(GDVars.otherCreatureCurrentPtr),
                                  CbtMap.CombatCellY(GDVars.otherCreatureCurrentPtr), 4, 45);
  if CharHlp.HasEffect(creature, C_EFFECT.GAZE_REFLECTABLE, effect) then begin
    reflected := False;
    item := GDVars.otherCreatureCurrentPtr^.itemsAddr;
    while (item <> nil) and (reflected = False) do begin
      if item^.equipped <> 0 then
        { "Mirror" }
        if (item^.nameIds[1] = C_Item.NAME_MIRROR) or (item^.nameIds[2] = C_Item.NAME_MIRROR) or
           (item^.nameIds[3] = C_Item.NAME_MIRROR) then begin
          CharDisp.PrintNameString(GDVars.otherCreatureCurrentPtr, 'reflects it!', 12, False);
          CharDisp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.otherCreatureCurrentPtr),
                                          CbtMap.CombatCellY(GDVars.otherCreatureCurrentPtr),
                                          CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 4, 45);
          reflected := True;
          GDVars.otherCreatureCurrentPtr := creature;
        end;
      item := item^.next;
    end;
  end;
  if not FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, C_Save.PETRIFY, 0) then
    EffHndlr.InflictStatusMsg(GDVars.otherCreatureCurrentPtr, C_STATUS.STONED, 'is Stoned');
end;

{ Charming gaze (eff 84): with a clear line to an attackable target within Charm Person's range, apply Charm Person's
  charm (save vs. spell at -2) without using a spell slot or action. The gaze is no spell: magic resistance meets it at
  its listed figure, as it does the other gazes (EffHndlr.MagicResistance). SSI's marked the spell being cast as Charm
  Person while it applied the charm, so the resistance was adjusted by the gazer's mage level (#799). }
procedure EffCharmGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  dist: Word;
  effect: Types.PEffectRec;
  x: ShortInt;
  y: ShortInt;
begin
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  x := CbtMap.CombatCellX(GDVars.otherCreatureCurrentPtr);
  y := CbtMap.CombatCellY(GDVars.otherCreatureCurrentPtr);
  if not CbtActs.CanAttackTarget(creature, GDVars.otherCreatureCurrentPtr) then Exit;
  { the range budget in cells, read by WalkLine on entry: that of the Charm Person the gaze applies }
  dist := GDConsts.spellTable[C_SPELL.CHARM_PERSON].rangeFixed;
  if not Pathing.WalkLine(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), x, y, dist,
                          GDVars.arenaPtr) then Exit;
  CharDisp.PrintNameString(creature, 'Gazes...', 10, False);
  CharDisp.BuildIconFacings(18);
  CharDisp.CombatAnimateMovingIcon(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                  CbtMap.CombatCellX(GDVars.otherCreatureCurrentPtr),
                                  CbtMap.CombatCellY(GDVars.otherCreatureCurrentPtr), 4, 45);
  FxEngine.AddEffectWithMessage(GDVars.otherCreatureCurrentPtr, C_EFFECT.CHARM, 0, CharHlp.Team(creature) * 128 + 12,
                                True, True,
                                FxEngine.RollSavingThrow(creature^.combatAddr^.other, C_Save.SPELL, -2),
                                'is charmed');
  if CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, C_EFFECT.CHARM, effect) then
    FxEngine.CallEffectHandler(C_EFFECT.CHARM, GDVars.otherCreatureCurrentPtr, effect, False);
end;

{ Drain levels from a creature; an animated creature, or one with no class levels, is destroyed instead. For each level
  the creature loses hpMax div (total class levels) from hpMax, hpRolled and hpCur, then either dies forever (highest
  level below 2) or loses a level in the class picked by ClassToDrain, dying if its HP reached 0. Its highest level and
  experience are then reset from the class ClassToDrain picks after the loss. }
procedure DrainLevels(creature: Types.PCharRecord; levels: Byte);
var
  numStr: Types.TStr40;
  xpMin: LongInt;
  cls: ShortInt;
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
    xpTry: LongInt;
    jj: ShortInt;
    bestLvl: ShortInt;
    lvl: ShortInt;
  begin
    xpMin := 0;
    bestLvl := 0;
    for jj := C_Level.CLERIC to C_Level.MONK do begin
      lvl := creature^.classLevels[jj];
      { xp[] runs to level 9; a level above it reads level 9's entry }
      if lvl > 9 then
        xpTry := GDConsts.experienceSpellsClass[jj].xp[9]
      else if lvl > 1 then
        xpTry := GDConsts.experienceSpellsClass[jj].xp[lvl]
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
  CharDisp.PrintNameString(creature, 'is drained ' + numStr, 10, True);
  if creature^.status = C_STATUS.ANIMATED then begin
    EffHndlr.InflictStatusMsg(creature, C_STATUS.GONE, 'is dead forever');
    creature^.hpMax := 0;
    Exit;
  end;
  for i := 1 to levels do begin
    if creature^.status <> C_STATUS.GONE then begin
      Inc(creature^.drainedLevels);
      totalLevels := 0;
      for j := C_Level.CLERIC to C_Level.MONK do
        Inc(totalLevels, creature^.classLevels[j]);
      { a creature with no class levels (kobolds, bandits and other monsters) has no level to lose, and no divisor }
      if totalLevels = 0 then begin
        EffHndlr.InflictStatusMsg(creature, C_STATUS.GONE, 'is dead forever');
        creature^.hpMax := 0;
        Exit;
      end;
      hpPerLevel := creature^.hpMax div totalLevels;
      { tested here, so a drain loads Debug only with the STING display on }
      if GDVars.stingHpFlag <> 0 then
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
      cls := ClassToDrain;
      if creature^.levelHighest < 2 then begin
        EffHndlr.InflictStatusMsg(creature, C_STATUS.GONE, 'is dead forever');
        creature^.hpMax := 0;
        { SSI's: only a two-level drain clears the class's level }
        if levels = 2 then
          creature^.classLevels[cls] := 0;
      end else begin
        Dec(creature^.classLevels[cls]);
        if creature^.hpCur = 0 then
          if creature^.status <> C_STATUS.DEAD then
            EffHndlr.InflictStatusMsg(creature, C_STATUS.DEAD, 'is killed');
        ClassCal.RecalcBaseSkills(creature);
      end;
      { picked again, after the loss, with xpMin for it }
      cls := ClassToDrain;
      creature^.levelHighest := creature^.classLevels[cls];
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
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  if FxEngine.DiseaseImmune(GDVars.otherCreatureCurrentPtr, C_EFFECT.ROT_NO_HEAL) then
    Exit;
  if not CharHlp.HasEffect(GDVars.otherCreatureCurrentPtr, C_EFFECT.ROT_NO_HEAL, effect) then begin
    FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_EFFECT.ROT_NO_HEAL, 14400, 255, True);
    FxEngine.AddEffect(GDVars.otherCreatureCurrentPtr, C_EFFECT.MUMMY_ROT, 43200,
                       Dice.RollDice(1, 6) * 16 + 15, True);
    CharDisp.PrintNameString(GDVars.otherCreatureCurrentPtr, 'is Diseased', 10, True);
  end;
end;

{ Displaced (eff 89): the first attack on the creature each combat misses. strength bit 4 = "has displaced an attack
  this combat", cleared by ResetDisplacement as combat starts. SSI's cleared it from here, in the first round whenever
  the attack roll stood at 0, so a first-round attack modified to exactly 0 cleared it instead of missing (#791). }
procedure EffDisplaced(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if Types.PEffectRec(p)^.strength and $10 = 0 then begin
    GDVars.gAttackAvoided := True;
    Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength or $10;
  end;
end;

procedure ResetDisplacement(creature: Types.PCharRecord);
var
  effect: Types.PEffectRec;
begin
  if CharHlp.HasEffect(creature, C_EFFECT.DISPLACED, effect) then
    effect^.strength := effect^.strength and not $10;
end;

{ Con poison saving throw bonus (eff 90) }
procedure EffConPsnSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.gSaveType = C_Save.PARALYZE then begin
    GDVars.gSaveRoll := GDVars.gSaveRoll + AbilAdj.ConSaveBonus(creature^.conCur);
  end;
end;

{ Immunity to electricity + Magic Missile (eff 91) }
procedure EffImmuneMM(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.currentSpellBeing = C_SPELL.MAGIC_MISSILE then begin
    EffHndlr.NullifyAttack(0);
    CharDisp.PrintNameString(creature, 'is unaffected', 10, True);
  end else
    if GDVars.elementMask and C_EFFECT.ELEM_ELEC <> 0 then
      EffHndlr.NullifyAttack(0);
end;

{ Half damage from fire (eff 93) }
procedure EffHalfFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and C_EFFECT.ELEM_FIRE <> 0 then
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

{ Half damage from blunt/piercing (eff 94) }
procedure EffHalfBash(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then
    if CharHlp.BaseItem(w^.itemType)^.wpnClass and (C_Item.WPN_PIERCE or C_Item.WPN_BASH) <> 0 then
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

{ Fight on at 0 HP (eff 95): when it expires, a creature still fighting falls dead }
procedure EffFightOn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  if creature^.enabled <> 0 then
    EffHndlr.InflictStatusMsg(creature, C_STATUS.DEAD, 'Falls dead');
end;

{ Immune to weapons neither magical nor silver, and to attacks without a weapon (eff 96). Silver = name component 177 }
procedure EffNeedSilver(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if (w = nil) or ((w^.plus = 0) and (w^.nameIds[3] <> C_Item.NAME_SILVER)) then
    GDVars.pendingDamage := 0;
end;

{ Con spell/wand save bonus (eff 97), on EffConPsnSave's scale }
procedure EffConSpellSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.gSaveType = C_Save.SPELL) or (GDVars.gSaveType = C_Save.WAND) then begin
    GDVars.gSaveRoll := GDVars.gSaveRoll + AbilAdj.ConSaveBonus(creature^.conCur);
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
  if creature^.status = C_STATUS.DYING then
    if creature^.combatAddr^.overkill < 6 then
      hp := 6 - creature^.combatAddr^.overkill;
  if creature^.status = C_STATUS.UNCONSCIOUS then
    hp := 6;
  if hp > 0 then
    if FxEngine.ReviveDeadCreature(creature, hp) then begin
      FxEngine.AddEffect(creature, C_EFFECT.FIGHT_ON, Dice.RollDice(1, 4) + 1, 255, True);
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, C_EFFECT.CAN_FIGHT_ON, p);
    end;
end;

{ Troll vulnerability to fire/acid (eff 100): when the damage is neither fire nor acid, add eff 102 to bring the troll
  back in 3d6 minutes }
procedure EffTrollBurn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and C_EFFECT.ELEM_FIRE = 0) and (GDVars.elementMask and C_EFFECT.ELEM_ACID = 0) then
    FxEngine.AddEffect(creature, C_EFFECT.TROLL_RETURN, Dice.RollDice(3, 6), 255, True);
end;

{ Troll: add regeneration (eff 101): unless it has eff 98 or eff 59 already, add eff 59 for 3 minutes }
procedure EffTrollHeal(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if not CharHlp.HasEffect(creature, C_EFFECT.REGEN3, effect) then
    if not CharHlp.HasEffect(creature, C_EFFECT.TROLL_REGEN, effect) then
      FxEngine.AddEffect(creature, C_EFFECT.TROLL_REGEN, 3, 255, True);
end;

{ Troll returning from going down (eff 102): revive at full HP, or retry in 1 minute if that fails }
procedure EffTrollReturn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  dummy: Boolean;
begin
  if not FxEngine.ReviveDeadCreature(creature, creature^.hpMax) then
    dummy := EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.TROLL_RETURN, Types.PEffectRec(p)^.strength, 1);
end;

{ Gaseous form (eff 103): the creature escapes and is put out of play as fled }
procedure EffGaseous(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  CbtMap.DisplayMapViewCentered(creature, 3, False);
  FxEngine.PutOutOfPlayWithStatus(creature, C_STATUS.RUNNING, 'Turns gaseous and escapes');
end;

{ Thri-kreen missile evasion (eff 104) }
procedure EffKreenDodge(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.AvoidRanged(creature, 60);
end;

{ pct is the creature's magic resistance against an 11th-level caster. As in the DMG, it rises 5% for each caster level
  below 11 and falls 5% for each level above: chance := pct + (11 - lvl) * 5, kept within 0..100, and a 1d100 roll <=
  chance nullifies. Only an effect under the immunity check or magic damage is resisted, and not a monster's poisonous
  or paralyzing touch, which is no magic (TouchImmune; #800). An item counts as a 6th-level caster here, as a scroll
  does, not the 12 GetCasterLevel gives the class-2 item spells (the wands, the necklace and the javelin). Against an
  effect that is no spell (GDVars.currentSpellBeing NONE: a gaze, a monster's fear) there is no caster level, and pct
  stands as listed, as against an 11th-level caster; SSI's read the level of spell 0, from outside the spell table
  (#786). Shipped v1.3 had the sign the other way (pct - (11 - lvl) * 5, with eff 106 passing 15), so resistance grew
  with the caster level; Tyranthraxus (eff 106) still resists every caster the game produces, as he did. }
procedure MagicResistance(pct: Byte);
const
  { the caster level pct is listed against }
  BASE_LEVEL = 11;
var
  lvl: Byte;
  chance: Integer;
begin
  if GDVars.currentSpellBeing = C_SPELL.NONE then
    lvl := BASE_LEVEL
  else begin
    lvl := CharHlp.GetCasterLevel(GDVars.currentSpellBeing);
    if GDVars.usingItem and (lvl > C_SPELL.ITEM_CASTER_LEVEL) then
      lvl := C_SPELL.ITEM_CASTER_LEVEL;
  end;
  chance := Integer(pct) + (BASE_LEVEL - Integer(lvl)) * 5;
  if chance < 0 then
    chance := 0
  else if chance > 100 then
    chance := 100;
  if (GDVars.pendingEffectId = 0) and (GDVars.elementMask and C_EFFECT.ELEM_MAGIC = 0) then
    Exit;
  if mundaneCheck then
    Exit;
  if Dice.RollDice(1, 100) <= chance then
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
  if Dice.RollDice(1, 100) <= 90 then begin
    EffHndlr.NullifyAttack(C_EFFECT.SLEEP);
    EffHndlr.NullifyAttack(C_EFFECT.CHARM);
  end;
end;

{ Immunity to sleep/charm (eff 108) }
procedure EffNoSleepCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_EFFECT.CHARM);
  EffHndlr.NullifyAttack(C_EFFECT.SLEEP);
end;

{ Immunity to paralysis (eff 109) }
procedure EffNoParalysis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_EFFECT.PARALYSIS);
end;

{ Immunity to cold (eff 110) }
procedure EffNoCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and C_EFFECT.ELEM_COLD <> 0 then
    EffHndlr.NullifyAttack(0);
end;

{ Immunity to paralysis + poison (eff 111). Saves of type 0 (paralyzation/poison, e.g. Stinking Cloud) succeed
  automatically }
procedure EffNoParaPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_EFFECT.POISONED);
  EffHndlr.NullifyAttack(C_EFFECT.PARALYSIS);
  if GDVars.gSaveType = C_Save.PARALYZE then
    GDVars.gSaveRoll := 100;
end;

{ Immunity to fire (eff 112) }
procedure EffNoFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and C_EFFECT.ELEM_FIRE <> 0 then
    EffHndlr.NullifyAttack(0);
end;

{ Efreeti fire resistance (eff 113): -1 per die, minimum = dice count (damage already below it is left alone) }
procedure EffEfreetiFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and C_EFFECT.ELEM_FIRE <> 0 then
    Dice.ReduceDamagePerDie(1);
end;

{ Half damage from electricity (eff 114) }
procedure EffHalfElec(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and C_EFFECT.ELEM_ELEC <> 0 then
    GDVars.pendingDamage := GDVars.pendingDamage div 2;
end;

{ Half damage from piercing/slashing (eff 115) }
procedure EffHalfPierce(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then
    if (CharHlp.BaseItem(w^.itemType)^.wpnClass = C_Item.WPN_SLASH) or
        (CharHlp.BaseItem(w^.itemType)^.wpnClass and C_Item.WPN_PIERCE <> 0) then
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
      GDVars.pendingDamage := Dice.RollDamageDice(1, 6) + 1;
end;

{ Half damage from cold (eff 118) }
procedure EffHalfCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.elementMask and C_EFFECT.ELEM_COLD <> 0 then
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

{ Anhkheg acid squirt (eff 121): 25% chance, range < 4, 8d4 acid, save vs. breath for half; the effect removes itself
  (and eff 80) after firing }
procedure EffAnhkhegAcid(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  dummy: Boolean;
begin
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  { other is nil before the anhkheg's first target, and may be a creature since taken out of play }
  if (GDVars.otherCreatureCurrentPtr = nil) or (GDVars.otherCreatureCurrentPtr^.enabled = 0) then Exit;
  if Dice.RollDice(1, 100) > 25 then Exit;
  if CbtMap.CalcDistance(creature, GDVars.otherCreatureCurrentPtr) >= 4 then Exit;
  dummy := CharHlp.EndActions(creature);
  CharDisp.PrintNameString(creature, 'Spits Acid', 10, True);
  CharDisp.BuildIconFacings(23);
  CharDisp.CombatAnimateMovingIcon(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                  CbtMap.CombatCellX(GDVars.otherCreatureCurrentPtr),
                                  CbtMap.CombatCellY(GDVars.otherCreatureCurrentPtr), 1, 30);
  { acid, set before the save, whose effects read it too: SSI left the type of the last damage dealt (#721) }
  GDVars.elementMask := C_EFFECT.ELEM_ACID;
  FxEngine.InflictNonWeaponDamage(GDVars.otherCreatureCurrentPtr, Dice.RollDamageDice(8, 4), 2,
                                  FxEngine.RollSavingThrow(GDVars.otherCreatureCurrentPtr, C_Save.BREATH, 0));
  FxEngine.RemoveEffect(creature, C_EFFECT.ANHKHEG_ACID, p);
  FxEngine.RemoveEffect(creature, C_EFFECT.ACID_SQUIRT, nil);
end;

{ Mummy vulnerability to fire (eff 122): a flask of oil does 3d8; magic or fire damage +1 per die }
procedure EffMummyFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := GDVars.curChar^.equipped[C_Equip.WEAPON];
  if item <> nil then
    if item^.itemType = C_Item.FLASK_OF_OIL then
      GDVars.pendingDamage := Dice.RollDamageDice(3, 8);
  if GDVars.elementMask and (C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC) <> 0 then
    Inc(GDVars.pendingDamage, GDVars.gDamageDice);
end;

{ Immune unless silver (half) or magical (full); no damage without a weapon (eff 123) }
procedure EffSilverMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if w <> nil then begin
    if (w^.plus = 0) and (w^.nameIds[3] = C_Item.NAME_SILVER) then
      GDVars.pendingDamage := GDVars.pendingDamage div 2
    else if w^.plus = 0 then
      GDVars.pendingDamage := 0;
  end else
    GDVars.pendingDamage := 0;
end;

{ Half-elf 30% resistance (eff 124) }
procedure EffHalfElfResist(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if Dice.RollDice(1, 100) <= 30 then begin
    EffHndlr.NullifyAttack(C_EFFECT.CHARM);
    EffHndlr.NullifyAttack(C_EFFECT.SLEEP);
  end;
end;

{ Immunity to sleep/charm/para/poison (eff 125). Saves of type 0 succeed automatically }
procedure EffNoCharmPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_EFFECT.CHARM);
  EffHndlr.NullifyAttack(C_EFFECT.SLEEP);
  EffHndlr.NullifyAttack(C_EFFECT.PARALYSIS);
  EffHndlr.NullifyAttack(C_EFFECT.POISONED);
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
  GDVars.otherCreatureCurrentPtr := creature^.combatAddr^.other;
  item := GDVars.otherCreatureCurrentPtr^.itemsAddr;
  while (item <> nil) and (GDVars.currentSuppressTargetingFlag = 0) do begin
    if item^.equipped <> 0 then
      { 3 = High(TItemRec.nameIds) }
      for j := 1 to 3 do
        if ((item^.nameIds[j] = C_Item.NAME_HOLY_SYMBOL) and (item^.nameIds[3] = C_Item.NAME_WOODEN)) or
           (item^.nameIds[j] = C_Item.NAME_MIRROR) then
          GDVars.currentSuppressTargetingFlag := 1;
    item := item^.next;
  end;
end;

{ Ready item (eff 128, 129, 130, 133, 134, 136, 138, 139): p is the ITEM. Readying adds its effect byte as a permanent
  effect (strength 12) and calls that handler with the new node, except the Cloak of Displacement's: a cloak readied in
  combat had its first miss marked spent at once (#784). Unreadying removes the effect. SSI passed the handler nil, and
  the Cloak of Displacement's (eff 89) wrote its strength through it, into the interrupt vectors (#737). }
procedure EffReadyItem(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  effect: Types.PEffectRec;
begin
  item := p;
  if removed then
    FxEngine.RemoveEffect(creature, item^.effect, nil)
  else begin
    FxEngine.AddEffect(creature, item^.effect, 0, 12, False);
    { AddEffect appends: the new node is the last }
    effect := creature^.effectsAddr;
    while effect^.next <> nil do
      effect := effect^.next;
    { displacement acts only on an attack: its handler would spend the first miss on the readying (#784) }
    if item^.effect <> C_EFFECT.DISPLACED then
      FxEngine.CallEffectHandler(item^.effect, creature, effect, False);
  end;
end;

{ Gauntlets of Ogre Power (eff 131). Ready: Str 18/00 via FxEngine.AdjustForNewStrength plus a permanent eff 38 node
  holding the Strength to restore; "is stronger" shows only for the character readying them (GDVars.curChar), not for a
  monster loaded wearing them (EclMenu.LoadCreatureData). Unready: while the creature is still at 18/00 (with a
  disease's loss given back, CharHlp.DiseaseStrLoss), remove the first eff 38 node that is not superseded, which
  restores its Strength }
procedure EffGauntlets(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  enc: Byte;
  isOgre: Boolean;
  found: Boolean;
  q: Types.PEffectRec;
  next: Types.PEffectRec;
begin
  if removed then begin
    found := False;
    q := creature^.effectsAddr;
    if (creature^.strCur + CharHlp.DiseaseStrLoss(creature) = 18) and (creature^.strExc = 100) then
      isOgre := True
    else
      isOgre := False;
    while (q <> nil) and (found = False) do begin
      { taken before RemoveEffect frees q }
      next := q^.next;
      { the first Strength effect not superseded ($80 in its strength byte, as EffExtraStr reads it) while the
        Gauntlets' 18/00 holds: the one they added. SSI tested q^.id < $80, always true for C_EFFECT.STRENGTH, which
        came to "an 18/00 wearer, or a restore value of 18/00" and could remove a superseded effect (POR-0164). }
      if (q^.id = C_EFFECT.STRENGTH) and isOgre and (q^.strength < $80) then begin
        FxEngine.RemoveEffect(creature, C_EFFECT.STRENGTH, q);
        found := True;
      end;
      q := next;
    end;
  end else begin
    if FxEngine.AdjustForNewStrength(creature, 18, 100, enc) and (creature = GDVars.curChar) then
      if GDVars.ifcState = C_Ifc.COMBAT then begin
        GDVars.ifcState := C_Ifc.CAMPING;
        CharDisp.PrintNameString(creature, 'is stronger', 10, True);
        GDVars.ifcState := C_Ifc.COMBAT;
      end else
        CharDisp.PrintNameString(creature, 'is stronger', 10, True);
    GDVars.redrawInventoryMenuFlag := 1;
    FxEngine.AddEffect(creature, C_EFFECT.STRENGTH, 0, enc, True);
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
    GDVars.elementMask := C_EFFECT.ELEM_MAGIC;
    if GDVars.ifcState = C_Ifc.COMBAT then
      CharDisp.DisplayCombatInterface;
    FxEngine.InflictItemShock(creature, item, dmg);
    GDVars.redrawInventoryMenuFlag := 1;
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
    CharDisp.PrintBottomLine('Must have Giant Strength');
  end;
end;

{ Spiritual Hammer unreadied (eff 137) }
procedure EffHammerGone(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then
    FxEngine.RemoveEffect(creature, C_EFFECT.SPIRIT_HAMMER, nil);
end;

{ the do-nothing handler (eff 5, 13, 16, 19, 24, 27, 54, 55, 60, 63, 92, 127) }
procedure EffNull(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

end.
