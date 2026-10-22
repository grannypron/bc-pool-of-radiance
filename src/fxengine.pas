{ Effect dispatch and active-effect lists, attack rolls, saving throws, damage, healing and revival. }
{$O+,F+}
{$I COMPILER.INC}
unit FxEngine;

interface

{ C_Effect supplies the EFF_ effect ids }
uses Types;

{ Call the effect handler for effId (1..141) through GDVars.effectFns; an id outside the table calls nothing. p is the
  item or effect node the handler concerns; removed is True when the item is being unreadied or the effect removed. }
procedure CallEffectHandler(effId: Byte; creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Remove an effect node from the creature's list: eff when it is not nil, else the first node whose id is effId (nothing
  happens if there is none, or if eff is not in the list). If the node's onRemove flag is set, effId's handler is first
  called with removed = True; the node is then unlinked and freed, unless the handler has removed it already. }
procedure RemoveEffect(creature: Types.PCharRecord; effId: Byte; eff: Pointer);

{ True when eff is a node of the creature's effect list. A caller holding a node across a removal checks it with this,
  since the removal's handler may have removed and freed it. }
function HasEffectNode(creature: Types.PCharRecord; eff: Pointer): Boolean;

{ True when the creature has any of the effects a cure of disease removes (GDConsts.cureDiseaseEffects). }
function HasDisease(creature: Types.PCharRecord): Boolean;

{ Remove every effect a cure of disease removes, quietly, with the effect lock held: the temple's cure and the
  paladin's. }
procedure RemoveDiseases(creature: Types.PCharRecord);

{ Fire, on one creature, every effect id registered under condition cond (0..19, the C_Cond constants). Each id goes
  through the private TriggerEffect, which also honours the aura effects 21, 45, 46 and 49 carried by other creatures. }
procedure TriggerEffectsWithCondition(cond: Byte; creature: Types.PCharRecord);

{ Stinking-cloud check for an enabled creature: CbtMap.ProbeDirection (dir 8, its own cells) must report terrain 30
  (C_Terr.STINK_CLOUD), and any of effects 30, 31, 32, 111 and 125 prevents it. A successful save vs.
  paralyzation/poison (type 0) gives effect 30 "starts to cough" for 1 minute, a failure effect 31 "chokes and gags from
  nausea" for 1d4+1 minutes; that effect's handler is then called at once with a nil node, whether or not the effect was
  applied. }
procedure ConsiderStinkingCloud(creature: Types.PCharRecord);

{ The lowest cloud number, at most 15, that none of the caster's clouds on the GDVars.stinkHead list has, so the number
  in the caster's Cast Stinking Cloud effect (strength div 16) names one cloud alone. }
function FreeCloudNumber(caster: Types.PCharRecord): Byte;

{ The Cast Stinking Cloud effect's strength: the cloud number (FreeCloudNumber) in the high nibble and the caster level
  in the low one, which Dispel Magic reads. A level above 15 is stored as 15 rather than carrying into the number. }
function CloudStrength(level, num: Byte): Byte;

{ Attack roll with no attacking creature (used by ECL script attacks): d20 into gAttackRoll, where 1 misses and 20
  becomes 100, then the defender's C_Cond.ATTACK_ROLL_DEF (16) effects run. Hit when no effect forced a miss
  (GDVars.gAttackAvoided) and roll + sixtyMinusThac0 >= defender^.acCur, AttackRoll's test; SSI's needed more than
  acCur, so a script's attack hit 5% less often than a creature's with the same THAC0 (#719). }
function AttackRollNoAttacker(defender: Types.PCharRecord; sixtyMinusThac0: Byte): Boolean;

{ Full attack roll: strip the attacker's invisibility (effect 25), roll d20 into gAttackRoll (1 misses, 20 becomes 100),
  run the attacker's C_Cond.ATTACK_ROLL_ATT (10) and the defender's C_Cond.ATTACK_ROLL_DEF (16) effects, and take the
  GBVM modifier zmod (low byte of $6E71 when the attacker is allied, of $6E70 when hostile). Hit when no effect forced a
  miss (GDVars.gAttackAvoided) and roll + attacker^.thac0Cur + zmod >= sixtyMinusAc. Penalties that take the roll below
  0 only lower it; SSI's took any roll below 0 for a forced miss (#718). }
function AttackRoll(attacker, defender: Types.PCharRecord; sixtyMinusAc: Byte): Boolean;

{ d20 saving throw into GDVars.gSaveRoll: 1 always fails and 20 always succeeds. Otherwise the roll becomes roll +
  creature^.saveBonus + modifier, gSaveType is set to saveType, the creature's C_Cond.SAVING_THROW (12) effects run, and
  the save succeeds when creature^.saves[saveType] <= the modified roll. A saveType outside C_Save.PARALYZE..SPELL (an
  ECL script supplies it) is rolled as C_Save.SPELL. }
function RollSavingThrow(creature: Types.PCharRecord; saveType, modifier: ShortInt): Boolean;

{ Allocate an effect node, append it to the creature's effect list (as the head if the list is empty) and fill in id,
  duration (minutes; 0 = permanent), onRemove and strength. Does not check for an existing node or call the handler. }
procedure AddEffect(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);

{ Take an enabled creature out of play: center the map view on it, print msg after its name, disable it and set its
  status. Its hit points drop to 0 unless the status is C_Status.RUNNING (fled). Its sprite is erased from the combat
  map, its arena location cleared and the arena arrays rebuilt; then its per-round combat state is reset
  (CharHlp.EndActions) and the hpZeroEffects removed. }
procedure PutOutOfPlayWithStatus(creature: Types.PCharRecord; status: Byte; msg: Types.TStr40);

{ Remove every invisibility (effect 25) node from the creature. }
procedure RemoveInvisibility(creature: Types.PCharRecord);

{ Remove the effects listed in hpZeroEffects (the first node of each id). }
procedure RemoveEffectsHp0(creature: Types.PCharRecord);

{ Remove the effects listed in aiRoundRemoveEffects, 74 and 75 (the first node of each id). }
procedure RemoveAiEffects(creature: Types.PCharRecord);

{ If the creature has effect effId, print "<name> is Cured", remove that node and return True; otherwise return False. }
function RemoveEffectWithMessage(creature: Types.PCharRecord; effId: Byte): Boolean;

{ Apply a new Strength from a Strength effect. If it is weaker than the creature's current Strength, nothing changes:
  effStrength gets the new Strength encoded with bit 7 set and the result is False. Otherwise the first active Strength
  effect (id 12 or 38 with strength < $80), if any, is superseded: it is given the creature's current Strength, encoded
  with bit 7 set. The new Strength is stored, CharHlp.RecalcStats runs, effStrength gets the Strength to restore when
  the new effect ends (the superseded effect's previously stored Strength, else the current one) and the result is
  True. The current Strength is taken with a disease's loss given back, and the new one is stored less it
  (CharHlp.DiseaseStrLoss). }
function AdjustForNewStrength(creature: Types.PCharRecord; baseStr, excStr: Byte; var effStrength: Byte): Boolean;

{ Non-weapon damage: post damage to GDVars.pendingDamage and run the C_Cond.NONWEAPON_DAMAGE (6) effects; when saved,
  saveReduction 1 cancels the damage and 2 halves it. If any damage remains, print it with its element from
  GDVars.elementMask (Fire, Cold, Electricity, Acid, or "from Magic" when no bit but magic is set), apply it with
  CharHlp.InflictDamage and, in combat, clear castAllowed and lose any spell being cast. A creature it disables "Goes
  Down" (", and is Dying") or "is killed" (status 6..8); in combat the hpZeroEffects are removed, the C_Cond.HP_ZERO
  (13) effects run and CbtMap.CreatureDowned is called if the creature is still disabled. A dead, stoned or gone
  creature (a corpse a single-target spell was aimed at) is left alone. }
procedure InflictNonWeaponDamage(creature: Types.PCharRecord; damage, saveReduction: Byte; saved: Boolean);

{ InflictNonWeaponDamage, with no save, for an aligned item (eff 132) that shocks the creature readying it: in place
  of "takes n points of damage" the message window shows "<item> shocks <name> for <n> damage, and has been
  unequipped." with the item's displayed name, and waits for a key (CharDisp.MessageWait). }
procedure InflictItemShock(creature: Types.PCharRecord; item: Types.PItemRec; damage: Byte);

{ True when effId is a disease (Diseased, its Strength and hit point drains, or mummy rot) and the creature has paladin
  levels: paladins catch no disease. }
function DiseaseImmune(creature: Types.PCharRecord; effId: Byte): Boolean;

{ The immunity check: True when the creature is immune to effId, that is when one of its C_Cond.EFFECT_IMMUNITY (9)
  effects (a ward, an immunity or magic resistance) clears GDVars.pendingEffectId, or when FxEngine.DiseaseImmune
  holds. }
function EffectImmune(creature: Types.PCharRecord; effId: Byte): Boolean;

{ AddEffect with an immunity check and a message. The effect is refused with "is Unaffected" when
  FxEngine.EffectImmune holds, or when saved and saveNegates are both True.
  Otherwise an existing node with the same id is removed first if it is timed and the new duration is longer, or if the
  new effect is permanent (0); in any other case the new node is added alongside it. A non-empty msg is printed after
  the creature's name. }
procedure AddEffectWithMessage(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove,
                               saveNegates, saved: Boolean; msg: Types.TStr40);

{ Heal hp hit points, capped at hpMax, and return True. Returns False without healing unless the status is Okay,
  Animated, Unconscious or Dying (0, 1, 4, 5); mummy rot (effect 50) blocks healing unless bypassRot is True and the
  creature is wounded, and bypassRot at full hit points also returns False. A disabled Dying creature becomes
  Unconscious, and out of combat a disabled Unconscious creature gets the effect 78 handler with removed = True. }
function RestoreHitPoints(creature: Types.PCharRecord; hp: Byte; bypassRot: Boolean): Boolean;

{ Revive a creature with hp hit points if CbtMap.IsValidCreatureLoc (moving = True) accepts its current cell, which in
  combat also places it there; otherwise return False. It becomes Okay and enabled, the map view centers on it in
  combat, it "stands up and grins" (hostile = 1) or "gets back up", and CharHlp.CountTeams runs. }
function ReviveDeadCreature(creature: Types.PCharRecord; hp: Byte): Boolean;

procedure ToggleReadyItem(item: Types.PItemRec);

procedure AdvanceTime(amount: Byte; tUnit: ShortInt);

{ The start of a hold effect's handler (bite and hold, blood drain): p is the effect, its strength the victim's
  creature index. Returns the victim (also set in GDVars.dsOtherCreatureCurrentPtr) while the hold lasts, else nil:
  with no victim in the arena the effect just goes (released False); when the effect is being removed, either side is
  down or the victim is no longer C_Effect.IMMOBILE (it broke free, #709), the victim loses C_Effect.IMMOBILE and the
  effect goes (released True). The effect is removed here with
  onRemove cleared first, unless removed says it is already being removed. }
function HoldTarget(creature: Types.PCharRecord; p: Pointer; removed: Boolean; effId: Byte;
                    var released: Boolean): Types.PCharRecord;

implementation

uses Stats, StrUtil, AbilAdj, C_Gbvm, CharDisp, C_Time, Dice, Clock, C_Terr, C_Save, C_Cond, GDConsts, GDVars, Blit,
  TextRend, CharHlp, Pathing, CbtMap, C_Effect, C_Status, C_Ifc, C_Dir, C_Level, Crt, C_Item, C_Equip;


procedure CallEffectHandler(effId: Byte; creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (effId >= C_Effect.BLESS) and (effId <= C_Effect.RECENT_CURE) then
    GDVars.effectFns[effId](creature, p, removed);
end;

procedure RemoveEffect(creature: Types.PCharRecord; effId: Byte; eff: Pointer);
var
  prev: Types.PEffectRec;
  p: Types.PEffectRec;
begin
  p := eff;
  if p = nil then begin
    p := creature^.effectsAddr;
    while (p <> nil) and (p^.id <> effId) do
      p := p^.next;
  end else if not FxEngine.HasEffectNode(creature, p) then
    { a node not in the list would walk the unlink below off its end }
    p := nil;
  if p = nil then Exit;
  if Types.PEffectRec(p)^.onRemove then begin
    FxEngine.CallEffectHandler(effId, creature, p, True);
    { The handler may have removed the node itself: Fight On's (eff 95) kills the creature, and a creature that falls
      dead loses its 0-HP effects (RemoveEffectsHp0), Fight On among them. The node is then gone and freed, and the
      unlink below would run off the list's end and write through nil, into the interrupt vectors. }
    if not FxEngine.HasEffectNode(creature, p) then Exit;
  end;
  if creature^.effectsAddr = p then
    creature^.effectsAddr := p^.next
  else begin
    prev := creature^.effectsAddr;
    while (prev <> nil) and (prev^.next <> p) do
      prev := prev^.next;
    if prev = nil then Exit;
    prev^.next := p^.next;
  end;
  FreeMem(p, SizeOf(Types.TEffectRec));
end;

function HasEffectNode(creature: Types.PCharRecord; eff: Pointer): Boolean;
var
  p: Types.PEffectRec;
begin
  p := Types.PEffectRec(creature^.effectsAddr);
  while (p <> nil) and (p <> eff) do
    p := p^.next;
  HasEffectNode := p <> nil;
end;

{ Trigger one effect id on the creature: call its handler if the creature itself has the effect, or, for the aura
  effects 21 (Silence 15'), 45 (Prot Evil 10'), 46 (Prot Good 10') and 49 (Prayer), if any creature carrying it has this
  one in range (6 for Prayer, else 1; out of combat any carrier counts). The handler gets the node found: the creature's
  own, or the carrier's for an aura. The range test uses Pathing.BuildTargetList, saving and restoring the caller's
  target list around it. }
procedure TriggerEffect(creature: Types.PCharRecord; effId: Byte);
var
  save: Types.TTargetList;
  p: Types.PCharRecord;
  effect: Types.PEffectRec;
  found: Boolean;
  i: Byte;
  range: Byte;
begin
  found := False;
  p := GDVars.creatureList;
  if CharHlp.HasEffect(creature, effId, effect) then
    found := True
  else if effId in [C_Effect.SILENCE, C_Effect.PROT_EVIL_10FT, C_Effect.PROT_GOOD_10FT,
                    C_Effect.PRAYER] then begin
    Move(GDVars.targetList, save, SizeOf(GDVars.targetList));
    while (p <> nil) and not found do begin
      if CharHlp.HasEffect(p, effId, effect) then begin
        if GDVars.ifcState = C_Ifc.COMBAT then begin
          if effId = C_Effect.PRAYER then
            range := 6
          else
            range := 1;
          Pathing.BuildTargetList(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), range, 255, CbtMap.GetIconSize(p),
                                  GDVars.arenaPtr);
          for i := 1 to GDVars.targetCount do
            if GDVars.targetList[i].idx = CbtMap.CombatSlot(creature) then
              found := True;
        end else
          found := True;
      end;
      p := p^.nextCharAddr;
    end;
    Move(save, GDVars.targetList, SizeOf(GDVars.targetList));
  end;
  if found then
    FxEngine.CallEffectHandler(effId, creature, effect, False);
end;

procedure TriggerEffectsWithCondition(cond: Byte; creature: Types.PCharRecord);
begin
  case cond of
    C_Cond.ATTACKER_VETO: FxEngine.TriggerEffect(creature, C_Effect.GAZE_BLOCK);
    C_Cond.TARGET_VETO: begin
      FxEngine.TriggerEffect(creature, 63); FxEngine.TriggerEffect(creature, C_Effect.BLINKING);
      FxEngine.TriggerEffect(creature, C_Effect.INVISIBLE); FxEngine.TriggerEffect(creature,
          C_Effect.DUST_DISAPPEAR);
    end;
    C_Cond.HIT_PHASE_1: begin
      FxEngine.TriggerEffect(creature, C_Effect.DRAIN_ONE); FxEngine.TriggerEffect(creature,
                                                                                       C_Effect.DRAIN_TWO);
      FxEngine.TriggerEffect(creature, C_Effect.ROT_TOUCH); FxEngine.TriggerEffect(creature,
          C_Effect.GHOUL_PARA);
      FxEngine.TriggerEffect(creature, C_Effect.FIRE_TOUCH); FxEngine.TriggerEffect(creature,
          C_Effect.ACID_SQUIRT);
      FxEngine.TriggerEffect(creature, C_Effect.BLOOD_ATTACH); FxEngine.TriggerEffect(creature,
          C_Effect.REAR_CLAW_RAKE);
      FxEngine.TriggerEffect(creature, C_Effect.BITE_ATTACH);
    end;
    C_Cond.HIT_PHASE_2: begin
      FxEngine.TriggerEffect(creature, C_Effect.POISON_HIT0); FxEngine.TriggerEffect(creature,
          C_Effect.POISON_HIT4);
      FxEngine.TriggerEffect(creature, C_Effect.POISON_HIT2); FxEngine.TriggerEffect(creature,
          C_Effect.KREEN_PARA);
      FxEngine.TriggerEffect(creature, C_Effect.GHOUL_PARA); FxEngine.TriggerEffect(creature,
          C_Effect.DRIDER_PARA);
      FxEngine.TriggerEffect(creature, C_Effect.POISON_HIT_M2); FxEngine.TriggerEffect(creature,
          C_Effect.FIRE_TOUCH);
      FxEngine.TriggerEffect(creature, C_Effect.DRAIN_ONE); FxEngine.TriggerEffect(creature,
                                                                                       C_Effect.DRAIN_TWO);
      FxEngine.TriggerEffect(creature, C_Effect.ROT_TOUCH);
    end;
    C_Cond.WEAPON_DAMAGE_ATT: begin
      FxEngine.TriggerEffect(creature, C_Effect.ENFEEBLE); FxEngine.TriggerEffect(creature,
          C_Effect.UNDEAD_SLAYER);
      FxEngine.TriggerEffect(creature, C_Effect.FLAME_TONGUE);
    end;
    C_Cond.WEAPON_DAMAGE_DEF: begin
      { Mirror Image against weapons is CbtActs.DoAttack's }
      FxEngine.TriggerEffect(creature, C_Effect.PROT_MISSILES);
      FxEngine.TriggerEffect(creature, C_Effect.KREEN_DODGE); FxEngine.TriggerEffect(creature,
          C_Effect.BOULDER_DODGE);
      FxEngine.TriggerEffect(creature, C_Effect.TROLL_HEAL); FxEngine.TriggerEffect(creature,
          C_Effect.HALF_PIERCE);
      FxEngine.TriggerEffect(creature, C_Effect.HALF_MAGICAL); FxEngine.TriggerEffect(creature,
          C_Effect.NEED_MAGIC);
      FxEngine.TriggerEffect(creature, C_Effect.SILVER_MAGIC); FxEngine.TriggerEffect(creature,
          C_Effect.NEED_SILVER);
      FxEngine.TriggerEffect(creature, C_Effect.HALF_BASH); FxEngine.TriggerEffect(creature, 60);
      FxEngine.TriggerEffect(creature, C_Effect.MUMMY_FIRE); FxEngine.TriggerEffect(creature,
          C_Effect.HOLY_WATER);
    end;
    C_Cond.NONWEAPON_DAMAGE: begin
      FxEngine.TriggerEffect(creature, C_Effect.EFREETI_FIRE); FxEngine.TriggerEffect(creature,
          C_Effect.RING_FIRE_RES);
      FxEngine.TriggerEffect(creature, C_Effect.MUMMY_FIRE); FxEngine.TriggerEffect(creature, 60);
      FxEngine.TriggerEffect(creature, C_Effect.IMMUNE_MM); FxEngine.TriggerEffect(creature,
          C_Effect.RESIST_COLD);
      FxEngine.TriggerEffect(creature, C_Effect.RESIST_FIRE); FxEngine.TriggerEffect(creature,
          C_Effect.MAGIC_RES50);
      FxEngine.TriggerEffect(creature, C_Effect.MAGIC_RES85); FxEngine.TriggerEffect(creature,
                                                                                         C_Effect.NO_FIRE);
      FxEngine.TriggerEffect(creature, C_Effect.HALF_ELEC); FxEngine.TriggerEffect(creature,
                                                                                       C_Effect.HALF_COLD);
      FxEngine.TriggerEffect(creature, C_Effect.SHIELD); FxEngine.TriggerEffect(creature, C_Effect.HALF_FIRE);
      FxEngine.TriggerEffect(creature, C_Effect.TROLL_HEAL); FxEngine.TriggerEffect(creature,
          C_Effect.MIRROR_IMAGE);
    end;
    C_Cond.TURN_START: begin
      FxEngine.TriggerEffect(creature, C_Effect.SNAKE_CHARM); FxEngine.TriggerEffect(creature,
                                                                                         C_Effect.PARALYSIS);
      FxEngine.TriggerEffect(creature, C_Effect.SLEEP); FxEngine.TriggerEffect(creature, C_Effect.HELPLESS);
    end;
    C_Cond.COMBAT_START: begin
      FxEngine.TriggerEffect(creature, C_Effect.CAN_FIGHT_ON); FxEngine.TriggerEffect(creature,
          C_Effect.DRAGON_FEAR);
      FxEngine.TriggerEffect(creature, C_Effect.MUMMY_FEAR); FxEngine.TriggerEffect(creature,
                                                                                        C_Effect.DISPLACED);
      FxEngine.TriggerEffect(creature, C_Effect.CAMOUFLAGE); FxEngine.TriggerEffect(creature,
          C_Effect.RING_INVIS);
    end;
    C_Cond.EFFECT_IMMUNITY: begin
      FxEngine.TriggerEffect(creature, C_Effect.MAGIC_RES50); FxEngine.TriggerEffect(creature,
          C_Effect.MAGIC_RES85);
      FxEngine.TriggerEffect(creature, C_Effect.ELF_RESIST); FxEngine.TriggerEffect(creature,
          C_Effect.NO_SLEEP_CHARM);
      FxEngine.TriggerEffect(creature, C_Effect.NO_PARALYSIS); FxEngine.TriggerEffect(creature,
                                                                                          C_Effect.NO_COLD);
      FxEngine.TriggerEffect(creature, C_Effect.NO_PARA_POISON); FxEngine.TriggerEffect(creature,
                                                                                            C_Effect.NO_FIRE);
      FxEngine.TriggerEffect(creature, C_Effect.HALF_ELF_RESIST); FxEngine.TriggerEffect(creature,
          C_Effect.NO_CHARM_POISON);
    end;
    C_Cond.ATTACK_ROLL_ATT: begin
      FxEngine.TriggerEffect(creature, C_Effect.BLESS); FxEngine.TriggerEffect(creature, C_Effect.CURSE);
      FxEngine.TriggerEffect(creature, C_Effect.BLIND); FxEngine.TriggerEffect(creature,
          C_Effect.BESTOW_CURSE);
      FxEngine.TriggerEffect(creature, C_Effect.PRAYER); FxEngine.TriggerEffect(creature,
          C_Effect.UNDEAD_SLAYER);
      FxEngine.TriggerEffect(creature, C_Effect.FLAME_TONGUE); FxEngine.TriggerEffect(creature,
          C_Effect.GNOME_THAC0);
      FxEngine.TriggerEffect(creature, C_Effect.DWARF_THAC0);
    end;
    C_Cond.DEFENDER_AC: begin
      { the cough first: its handler recalculates the creature's stats, which SSI's ran last and so threw away the
        Blindness and Shield changes (#717) }
      FxEngine.TriggerEffect(creature, C_Effect.STINK_COUGH);
      FxEngine.TriggerEffect(creature, C_Effect.BLIND); FxEngine.TriggerEffect(creature, C_Effect.SHIELD);
      FxEngine.TriggerEffect(creature, C_Effect.PROT_EVIL); FxEngine.TriggerEffect(creature,
                                                                                       C_Effect.PROT_GOOD);
      FxEngine.TriggerEffect(creature, C_Effect.PROT_EVIL_10FT); FxEngine.TriggerEffect(creature,
          C_Effect.PROT_GOOD_10FT);
    end;
    C_Cond.SAVING_THROW: begin
      FxEngine.TriggerEffect(creature, C_Effect.PROT_EVIL); FxEngine.TriggerEffect(creature,
                                                                                       C_Effect.PROT_GOOD);
      FxEngine.TriggerEffect(creature, C_Effect.RESIST_COLD); FxEngine.TriggerEffect(creature, C_Effect.SHIELD);
      FxEngine.TriggerEffect(creature, C_Effect.RESIST_FIRE); FxEngine.TriggerEffect(creature, C_Effect.BLIND);
      FxEngine.TriggerEffect(creature, C_Effect.BESTOW_CURSE); FxEngine.TriggerEffect(creature,
          C_Effect.PROT_EVIL_10FT);
      FxEngine.TriggerEffect(creature, C_Effect.PROT_GOOD_10FT); FxEngine.TriggerEffect(creature,
                                                                                            C_Effect.PRAYER);
      FxEngine.TriggerEffect(creature, C_Effect.RING_FIRE_RES); FxEngine.TriggerEffect(creature,
          C_Effect.NO_PARA_POISON);
      FxEngine.TriggerEffect(creature, C_Effect.NO_CHARM_POISON); FxEngine.TriggerEffect(creature,
          C_Effect.CON_PSN_SAVE);
      FxEngine.TriggerEffect(creature, C_Effect.CON_SPELL_SAVE);
    end;
    C_Cond.HP_ZERO: begin
      FxEngine.TriggerEffect(creature, C_Effect.CAN_FIGHT_ON); FxEngine.TriggerEffect(creature,
          C_Effect.TROLL_BURN);
      FxEngine.TriggerEffect(creature, C_Effect.GASEOUS); FxEngine.TriggerEffect(creature,
          C_Effect.BLOOD_DRAIN);
      FxEngine.TriggerEffect(creature, C_Effect.BITE_HOLD);
    end;
    C_Cond.MONSTER_SPECIAL: begin
      FxEngine.TriggerEffect(creature, C_Effect.PETRIFY_GAZE); FxEngine.TriggerEffect(creature,
          C_Effect.CHARM_GAZE);
      FxEngine.TriggerEffect(creature, C_Effect.DRAGON_BREATH); FxEngine.TriggerEffect(creature,
          C_Effect.ANHKHEG_ACID);
    end;
    C_Cond.ACTION_START: begin
      FxEngine.TriggerEffect(creature, C_Effect.SILENCE); FxEngine.TriggerEffect(creature,
          C_Effect.STINK_COUGH);
      FxEngine.TriggerEffect(creature, C_Effect.BITE_HOLD); FxEngine.TriggerEffect(creature,
          C_Effect.BLOOD_DRAIN);
      FxEngine.TriggerEffect(creature, C_Effect.CHARM);
    end;
    C_Cond.ATTACK_ROLL_DEF: begin
      FxEngine.TriggerEffect(creature, C_Effect.INVISIBLE); FxEngine.TriggerEffect(creature,
          C_Effect.DUST_DISAPPEAR);
      FxEngine.TriggerEffect(creature, C_Effect.BLINKING); FxEngine.TriggerEffect(creature,
          C_Effect.DWARF_AC_GIANT);
      FxEngine.TriggerEffect(creature, C_Effect.GNOME_AC_BUG); FxEngine.TriggerEffect(creature,
                                                                                          C_Effect.DISPLACED);
    end;
    C_Cond.MORALE_CHECK: begin
      FxEngine.TriggerEffect(creature, C_Effect.BLESS); FxEngine.TriggerEffect(creature, C_Effect.CURSE);
      FxEngine.TriggerEffect(creature, C_Effect.CHARM);
    end;
    C_Cond.MOVE_ATTACK_RATE: begin
      FxEngine.TriggerEffect(creature, C_Effect.HASTED); FxEngine.TriggerEffect(creature, C_Effect.SLOWED);
      FxEngine.TriggerEffect(creature, C_Effect.IMMOBILE);
    end;
    C_Cond.ROUND_END: begin
      FxEngine.TriggerEffect(creature, C_Effect.REGEN3); FxEngine.TriggerEffect(creature,
          C_Effect.SPIRIT_HAMMER);
      FxEngine.TriggerEffect(creature, C_Effect.CAMOUFLAGE); FxEngine.TriggerEffect(creature,
          C_Effect.RING_INVIS);
      FxEngine.TriggerEffect(creature, C_Effect.CHARM);
    end;
  end;
end;

procedure ConsiderStinkingCloud(creature: Types.PCharRecord);
var
  terrIdx: Byte;
  crIdx: Byte;
  effect: Types.PEffectRec;
  saved: Boolean;
begin
  if creature^.enabled = 0 then Exit;
  CbtMap.ProbeDirection(creature, C_Dir.CENTER, crIdx, terrIdx);
  if terrIdx <> C_Terr.STINK_CLOUD then Exit;
  if CharHlp.HasEffect(creature, C_Effect.STINK_COUGH, effect) then Exit;
  if CharHlp.HasEffect(creature, C_Effect.HELPLESS, effect) then Exit;
  if CharHlp.HasEffect(creature, C_Effect.ANIMATE_DEAD, effect) then Exit;
  if CharHlp.HasEffect(creature, C_Effect.NO_PARA_POISON, effect) then Exit;
  if CharHlp.HasEffect(creature, C_Effect.NO_CHARM_POISON, effect) then Exit;
  { save vs. paralyzation, poison and death magic, with the Constitution's poison bonus }
  saved := FxEngine.RollSavingThrow(creature, C_Save.PARALYZE, AbilAdj.ConPoisonSave(creature^.conCur));
  if saved then begin
    FxEngine.AddEffectWithMessage(creature, C_Effect.STINK_COUGH, 1, 255, False, False, saved, 'starts to cough');
    FxEngine.CallEffectHandler(C_Effect.STINK_COUGH, creature, effect, False);
  end else begin
    FxEngine.AddEffectWithMessage(creature, C_Effect.HELPLESS, Dice.RollDice(1, 4) + 1, 255, False, False,
                                  saved, 'chokes and gags from nausea');
    FxEngine.CallEffectHandler(C_Effect.HELPLESS, creature, effect, False);
  end;
end;

function FreeCloudNumber(caster: Types.PCharRecord): Byte;
var
  node: Types.PStinkRec;
  n: Byte;
  used: Boolean;
begin
  n := 0;
  repeat
    used := False;
    node := GDVars.stinkHead;
    while node <> nil do begin
      if (node^.caster = caster) and (node^.idx = n) then
        used := True;
      node := node^.next;
    end;
    if used then
      Inc(n);
  until (not used) or (n = 15);
  FreeCloudNumber := n;
end;

function CloudStrength(level, num: Byte): Byte;
begin
  if level > 15 then
    level := 15;
  CloudStrength := level + num * 16;
end;

{ The d20 both attack rolls share: into gAttackRoll (1 misses, 20 becomes 100), then the attacker's
  C_Cond.ATTACK_ROLL_ATT effects (none when attacker is nil) and the defender's C_Cond.ATTACK_ROLL_DEF. A hit when no
  effect forced a miss and roll + toHit >= sixtyMinusAc. }
function RollToHit(attacker, defender: Types.PCharRecord; toHit: Integer; sixtyMinusAc: Byte): Boolean;
begin
  RollToHit := False;
  GDVars.gAttackAvoided := False;
  GDVars.gAttackRoll := Dice.RollDice(1, 20);
  if GDVars.gAttackRoll > 1 then begin
    if GDVars.gAttackRoll = 20 then GDVars.gAttackRoll := 100;
    if attacker <> nil then
      FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACK_ROLL_ATT, attacker);
    FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACK_ROLL_DEF, defender);
    if not GDVars.gAttackAvoided and (GDVars.gAttackRoll + toHit >= sixtyMinusAc) then
      RollToHit := True;
  end;
end;

function AttackRollNoAttacker(defender: Types.PCharRecord; sixtyMinusThac0: Byte): Boolean;
begin
  AttackRollNoAttacker := RollToHit(nil, defender, sixtyMinusThac0, defender^.acCur);
end;

function AttackRoll(attacker, defender: Types.PCharRecord; sixtyMinusAc: Byte): Boolean;
var
  zmod: ShortInt;
begin
  FxEngine.RemoveInvisibility(attacker);
  if attacker^.hostile = 0 then
    zmod := ShortInt(Lo(GDVars.zone1^[C_Gbvm.PARTY_HIT_MOD]))
  else
    zmod := ShortInt(Lo(GDVars.zone1^[C_Gbvm.MONSTER_HIT_MOD]));
  AttackRoll := RollToHit(attacker, defender, attacker^.thac0Cur + zmod, sixtyMinusAc);
end;

function RollSavingThrow(creature: Types.PCharRecord; saveType, modifier: ShortInt): Boolean;
begin
  if (saveType < C_Save.PARALYZE) or (saveType > C_Save.SPELL) then
    saveType := C_Save.SPELL;
  GDVars.gSaveRoll := Dice.RollDice(1, 20);
  case GDVars.gSaveRoll of
    1: RollSavingThrow := False;
    20: RollSavingThrow := True;
  else begin
    GDVars.gSaveRoll := GDVars.gSaveRoll + creature^.saveBonus + modifier;
    GDVars.gSaveType := saveType;
    FxEngine.TriggerEffectsWithCondition(C_Cond.SAVING_THROW, creature);
    if creature^.saves[saveType] <= GDVars.gSaveRoll then
      RollSavingThrow := True
    else
      RollSavingThrow := False;
  end;
  end;
end;

procedure AddEffect(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);
var
  { p is the new node, q walks to the tail }
  p: Types.PEffectRec;
  q: Types.PEffectRec;
begin
  if effId = C_Effect.POISONED then
    Stats.Count(creature, Stats.POISONED, 1);
  GetMem(p, SizeOf(Types.TEffectRec));
  if creature^.effectsAddr = nil then
    creature^.effectsAddr := p
  else begin
    q := creature^.effectsAddr;
    while q^.next <> nil do
      q := q^.next;
    q^.next := p;
  end;
  p^.next := nil;
  p^.id := effId;
  Types.PEffectRec(p)^.duration := minutes;
  Types.PEffectRec(p)^.onRemove := onRemove;
  Types.PEffectRec(p)^.strength := strength;
end;

procedure PutOutOfPlayWithStatus(creature: Types.PCharRecord; status: Byte; msg: Types.TStr40);
var
  slot: Byte;
begin
  if creature^.enabled = 0 then Exit;
  slot := CbtMap.CombatSlot(creature);
  CbtMap.DisplayMapViewCentered(creature, 3, False);
  CharDisp.PrintNameString(creature, msg, 10, True);
  creature^.enabled := 0;
  creature^.status := status;
  { a creature that fled (C_Status.RUNNING) keeps its hit points }
  if creature^.status <> C_Status.RUNNING then
    creature^.hpCur := 0;
  { slot 0: not on the map, so there is no icon to erase }
  if slot > 0 then begin
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    Blit.FlushView;
    GDVars.arenaLoc[slot].size := 0;
  end;
  CbtMap.BuildArenaArrays;
  if CharHlp.EndActions(creature) then
    FxEngine.RemoveEffectsHp0(creature);
end;

procedure RemoveInvisibility(creature: Types.PCharRecord);
var
  effect: Types.PEffectRec;
begin
  while CharHlp.HasEffect(creature, C_Effect.INVISIBLE, effect) do
    FxEngine.RemoveEffect(creature, C_Effect.INVISIBLE, effect);
end;

procedure RemoveEffectsHp0(creature: Types.PCharRecord);
var
  i: Byte;
begin
  for i := 1 to 16 do
    FxEngine.RemoveEffect(creature, GDConsts.hpZeroEffects[i], nil);
end;

procedure RemoveAiEffects(creature: Types.PCharRecord);
var
  i: Byte;
begin
  for i := 1 to 2 do
    FxEngine.RemoveEffect(creature, GDConsts.aiRoundRemoveEffects[i], nil);
end;

function RemoveEffectWithMessage(creature: Types.PCharRecord; effId: Byte): Boolean;
var
  effect: Types.PEffectRec;
begin
  RemoveEffectWithMessage := False;
  if CharHlp.HasEffect(creature, effId, effect) then begin
    CharDisp.PrintNameString(creature, 'is Cured', 10, True);
    FxEngine.RemoveEffect(creature, effId, effect);
    RemoveEffectWithMessage := True;
  end;
end;

function AdjustForNewStrength(creature: Types.PCharRecord; baseStr, excStr: Byte; var effStrength: Byte): Boolean;
var
  p: Types.PEffectRec;
  found: Types.PEffectRec;
  oldBase: Byte;
  oldExc: Byte;
  enc: Byte;
  loss: Byte;
begin
  loss := CharHlp.DiseaseStrLoss(creature);
  oldBase := creature^.strCur + loss;
  oldExc := creature^.strExc;
  if (baseStr < oldBase) or ((baseStr = 18) and (excStr < oldExc)) then begin
    AdjustForNewStrength := False;
    effStrength := CharHlp.StrengthModifier(baseStr, excStr) + $80;
  end else begin
    found := nil;
    p := creature^.effectsAddr;
    while (p <> nil) and (found = nil) do begin
      if ((p^.id = C_Effect.ENLARGE) or (p^.id = C_Effect.STRENGTH)) and
          (Types.PEffectRec(p)^.strength < $80) then
        found := p;
      p := p^.next;
    end;
    if found <> nil then begin
      enc := CharHlp.StrengthModifier(oldBase, oldExc);
      CharHlp.StrengthEffectToStrength(found, oldBase, oldExc);
      Types.PEffectRec(found)^.strength := enc + $80;
    end;
    creature^.strCur := AbilAdj.ClampScore(Integer(baseStr) - loss);
    creature^.strExc := excStr;
    CharHlp.RecalcStats(creature);
    effStrength := CharHlp.StrengthModifier(oldBase, oldExc);
    AdjustForNewStrength := True;
  end;
end;

{ InflictNonWeaponDamage and InflictItemShock: shockItem nil prints the "takes n points of damage" line, else the
  item's shock message. }
procedure NonWeaponDamage(creature: Types.PCharRecord; damage, saveReduction: Byte; saved: Boolean;
                          shockItem: Types.PItemRec);
var
  { the longest is 'takes 255 points of damage from Electricity' }
  s: String[43];
begin
  if creature^.status in [C_Status.DEAD, C_Status.STONED, C_Status.GONE] then Exit;
  GDVars.pendingDamage := damage;
  FxEngine.TriggerEffectsWithCondition(C_Cond.NONWEAPON_DAMAGE, creature);
  if saved then
    case saveReduction of
      1: GDVars.pendingDamage := 0;
      2: GDVars.pendingDamage := GDVars.pendingDamage div 2;
    end;
  if GDVars.pendingDamage > 0 then begin
    if GDVars.pendingDamage <> 1 then
      s := 'takes ' + StrUtil.NumStr(GDVars.pendingDamage) + ' points of damage '
    else
      s := 'takes 1 point of damage ';
    case GDVars.elementMask and not C_Effect.ELEM_MAGIC of
      C_Effect.ELEM_FIRE: s := s + 'from Fire';
      C_Effect.ELEM_COLD: s := s + 'from Cold';
      C_Effect.ELEM_ELEC: s := s + 'from Electricity';
      C_Effect.ELEM_ACID: s := s + 'from Acid';
    end;
    { magic bit alone, or no element bit at all }
    if (GDVars.elementMask and C_Effect.ELEM_MAGIC) = GDVars.elementMask then
      s := s + 'from Magic';
    if shockItem = nil then
      CharDisp.PrintNameStringAnim(creature, False, s)
    else begin
      { the item and the creature in green, the rest in white (#637); the item label ends in a space }
      CharHlp.ItemLabel(shockItem, False);
      CharDisp.MessageText(shockItem^.name, LightGreen, True);
      CharDisp.MessageText('shocks ', White, False);
      CharDisp.MessageText(creature^.name, LightGreen, False);
      CharDisp.MessageText(' for ' + StrUtil.NumStr(GDVars.pendingDamage) + ' damage, and has been unequipped.', White,
                           False);
      CharDisp.MessageWait;
    end;
    CharHlp.InflictDamage(creature, GDVars.pendingDamage);
    if GDVars.ifcState = C_Ifc.COMBAT then begin
      creature^.combatAddr^.castAllowed := 0;
      if creature^.combatAddr^.spellCast > 0 then begin
        CharDisp.PrintNameString(creature, 'lost a spell', 12, True);
        CharHlp.RemoveSpell(creature, creature^.combatAddr^.spellCast);
        creature^.combatAddr^.spellCast := 0;
      end;
    end;
    if creature^.enabled = 0 then begin
      s := 'Goes Down';
      if creature^.status = C_Status.DYING then
        s := s + ', and is Dying';
      { 6..8 = dead, stoned, gone }
      if creature^.status in [C_Status.DEAD, C_Status.STONED, C_Status.GONE] then
        s := 'is killed';
      CharDisp.PrintNameString(creature, s, GDVars.curRow + 1, False);
      if GDVars.ifcState <> C_Ifc.COMBAT then
        TextRend.PauseOnly
      else begin
        FxEngine.RemoveEffectsHp0(creature);
        FxEngine.TriggerEffectsWithCondition(C_Cond.HP_ZERO, creature);
        if creature^.enabled = 0 then
          CbtMap.CreatureDowned(creature)
        else
          TextRend.PauseOnly;
      end;
    end;
    CharDisp.ClearMessageWindow;
  end;
end;

procedure InflictNonWeaponDamage(creature: Types.PCharRecord; damage, saveReduction: Byte; saved: Boolean);
begin
  FxEngine.NonWeaponDamage(creature, damage, saveReduction, saved, nil);
end;

procedure InflictItemShock(creature: Types.PCharRecord; item: Types.PItemRec; damage: Byte);
begin
  FxEngine.NonWeaponDamage(creature, damage, 0, False, item);
end;

function DiseaseImmune(creature: Types.PCharRecord; effId: Byte): Boolean;
begin
  DiseaseImmune := (creature <> nil) and (creature^.classLevels[C_Level.PALADIN] > 0) and
    (effId in C_Effect.DISEASES);
end;

function EffectImmune(creature: Types.PCharRecord; effId: Byte): Boolean;
begin
  GDVars.pendingEffectId := effId;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_IMMUNITY, creature);
  EffectImmune := (GDVars.pendingEffectId = 0) or FxEngine.DiseaseImmune(creature, effId);
end;

procedure AddEffectWithMessage(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove,
                               saveNegates, saved: Boolean; msg: Types.TStr40);
var
  effect: Types.PEffectRec;
begin
  if FxEngine.EffectImmune(creature, effId) or (saved and (saveNegates = True)) then
    CharDisp.PrintNameString(creature, 'is Unaffected', 10, True)
  else begin
    if CharHlp.HasEffect(creature, effId, effect) then
      if ((Types.PEffectRec(effect)^.duration > 0) and (minutes > Types.PEffectRec(effect)^.duration)) or
          (minutes = 0) then
        FxEngine.RemoveEffect(creature, effId, effect);
    FxEngine.AddEffect(creature, effId, minutes, strength, onRemove);
    if msg[0] <> #0 then begin
      CharDisp.PrintNameStringAnim(creature, True, msg);
      CharDisp.ClearMessageWindow;
    end;
  end;
end;

function RestoreHitPoints(creature: Types.PCharRecord; hp: Byte; bypassRot: Boolean): Boolean;
var
  effect: Types.PEffectRec;
  hpBefore: Byte;
begin
  RestoreHitPoints := False;
  if not (creature^.status in [C_Status.OKAY, C_Status.ANIMATED, C_Status.UNCONSCIOUS,
                               C_Status.DYING]) then Exit;
  if (creature^.hpCur >= creature^.hpMax) or not bypassRot then begin
    { 50 = mummy rot }
    if CharHlp.HasEffect(creature, C_Effect.ROT_NO_HEAL, effect) then Exit;
    { bypassRot at full hit points: False }
    if bypassRot then Exit;
  end;
  hpBefore := creature^.hpCur;
  { capped before the add, so the Byte hpCur cannot wrap past 255 }
  if Word(creature^.hpCur) + hp > creature^.hpMax then
    creature^.hpCur := creature^.hpMax
  else
    creature^.hpCur := creature^.hpCur + hp;
  { the statistics (#611): healing given only by a spell's or an item's caster }
  Stats.Healed(GDVars.curChar, creature, creature^.hpCur - hpBefore, False);
  if creature^.enabled = 0 then begin
    if creature^.status = C_Status.DYING then
      creature^.status := C_Status.UNCONSCIOUS;
    if (creature^.status = C_Status.UNCONSCIOUS) and (GDVars.ifcState <> C_Ifc.COMBAT) then
      FxEngine.CallEffectHandler(C_Effect.HEAL_WAKE, creature, nil, True);
  end;
  RestoreHitPoints := True;
end;

function ReviveDeadCreature(creature: Types.PCharRecord; hp: Byte): Boolean;
var
  s: Types.TStr40;
begin
  if CbtMap.IsValidCreatureLoc(creature, CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), True)
  then begin
    creature^.status := C_Status.OKAY;
    creature^.enabled := 1;
    creature^.hpCur := hp;
    if GDVars.ifcState = C_Ifc.COMBAT then
      CbtMap.DisplayMapViewCentered(creature, 3, False);
    if creature^.hostile = 1 then
      s := 'stands up and grins'
    else
      s := 'gets back up';
    CharDisp.PrintNameString(creature, s, 10, True);
    CharHlp.CountTeams;
    ReviveDeadCreature := True;
  end else
    ReviveDeadCreature := False;
end;

function HasDisease(creature: Types.PCharRecord): Boolean;
var
  i: Byte;
  effect: Types.PEffectRec;
  found: Boolean;
begin
  found := False;
  for i := 1 to SizeOf(GDConsts.cureDiseaseEffects) do
    if CharHlp.HasEffect(creature, GDConsts.cureDiseaseEffects[i], effect) then
      found := True;
  HasDisease := found;
end;

procedure RemoveDiseases(creature: Types.PCharRecord);
var
  i: Byte;
begin
  GDVars.effectLock := 1;
  for i := 1 to SizeOf(GDConsts.cureDiseaseEffects) do
    FxEngine.RemoveEffect(creature, GDConsts.cureDiseaseEffects[i], nil);
  GDVars.effectLock := 0;
end;

{ Toggle an item's readied state for curChar. Unreadying fails on a cursed item. Readying checks, with later checks
  overriding earlier ones, free hands (3), an occupied slot or ammunition slot (2) and the class mask (1); the
  hands-full message is skipped for a quick-fighting creature in combat. Special items (special > $7F) invoke their
  effect handler when readied and when unreadied. }
procedure ToggleReadyItem(item: Types.PItemRec);
var
  hasSpecial: Boolean;
  err: Byte;
  slot: ShortInt;
  creature: Types.PCharRecord;
begin
  hasSpecial := item^.special > $7F;
  creature := GDVars.curChar;
  if item^.equipped <> 0 then begin
    if item^.cursed <> 0 then
      CharDisp.PrintBottomLine('It''s Cursed')
    else begin
      item^.equipped := 0;
      if hasSpecial then
        FxEngine.CallEffectHandler(item^.special, creature, item, True);
    end;
  end else begin
    err := 0;
    if creature^.handsEquipped + CharHlp.BaseItem(item^.itemType)^.hands > 2 then
      err := 3;
    slot := CharHlp.BaseItem(item^.itemType)^.slot;
    { slots 0..8 each hold one item; a ring (slot 9) fails only when the second ring slot is taken }
    case Byte(slot) of
      C_Equip.WEAPON..C_Equip.BOOTS:
        if creature^.equipped[slot] <> nil then
          err := 2;
      C_Equip.RING1:
        if creature^.equipped[C_Equip.RING2] <> nil then
          { second ring slot already in use }
          err := 2;
    end;
    { arrows }
    if item^.itemType = C_Item.ARROW then
      if creature^.equipped[C_Equip.ARROW] <> nil then begin
        err := 2;
        slot := C_Equip.ARROW;
      end;
    { quarrels }
    if item^.itemType = C_Item.QUARREL then
      if creature^.equipped[C_Equip.BOLT] <> nil then begin
        err := 2;
        slot := C_Equip.BOLT;
      end;
    if CharHlp.BaseItem(item^.itemType)^.classMask and creature^.itemLimits = 0 then
      err := 1;
    case err of
      0: begin
           item^.equipped := 1;
           if hasSpecial then
             FxEngine.CallEffectHandler(item^.special, creature, item, False);
         end;
      1: CharDisp.PrintBottomLine('Wrong Class');
      2: begin
           CharHlp.ItemLabel(creature^.equipped[slot], False);
           CharDisp.PrintBottomLine('already using ' + creature^.equipped[slot]^.name);
         end;
      3: if (GDVars.ifcState <> C_Ifc.COMBAT) or (creature^.quickfight = 0) then
           CharDisp.PrintBottomLine('Your hands are full!');
    end;
  end;
end;

{ Age every timed effect (duration > 0 minutes) of each creature by count units of tUnit (ten segments to the minute),
  in steps of at most 10 minutes, removing those that run out. Outside camp every creature is visited; in camp only
  those GDVars.effFlags marks as still holding timed effects. Each step first ages the effects and notes the expiring
  ones, then removes those still in the list, since a removal's handler can remove (and free) another effect. }
procedure TimeOutEffects(count: Byte; tUnit: ShortInt);
const
  { expiring effects one creature can lose in one step; any more expire in the next step }
  MAX_EXPIRING = 32;
var
  u: ShortInt;
  i: Byte;
  k: Byte;
  step: Byte;
  total: LongInt;
  cur: Types.PCharRecord;
  found: Boolean;
  e: Types.PEffectRec;
  expiring: array[1..MAX_EXPIRING] of Types.PEffectRec;
  expiringId: array[1..MAX_EXPIRING] of Byte;
  expiringDuration: array[1..MAX_EXPIRING] of Word;
  nExpiring: Byte;
  again: Boolean;
begin
  if GDVars.ifcState <> C_Ifc.CAMPING then
    FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1)
  else begin
    found := False;
    i := 1;
    repeat
      if GDVars.effFlags[i] <> 0 then found := True;
      Inc(i);
    until found or (i > GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
    if not found then Exit;
  end;
  total := count;
  u := tUnit;
  if u = C_Time.SEGMENTS then
    total := total div GDConsts.unitScale[C_Time.SEGMENTS];
  while u > 1 do begin
    total := GDConsts.unitScale[Pred(u)] * total;
    u := Pred(u);
  end;
  while total > 0 do begin
    if total > 10 then step := 10 else step := total;
    i := 1;
    cur := GDVars.creatureList;
    while cur <> nil do begin
      if (i > SizeOf(GDVars.effFlags)) or (GDVars.effFlags[i] <> 0) then begin
        again := False;
        { age the timed effects, and note those that run out in this step; 0 is permanent }
        nExpiring := 0;
        e := Types.PEffectRec(cur^.effectsAddr);
        while e <> nil do begin
          if e^.duration > 0 then
            if step < e^.duration then begin
              Dec(e^.duration, step);
              again := True;
            end else if nExpiring < MAX_EXPIRING then begin
              Inc(nExpiring);
              expiring[nExpiring] := e;
              expiringId[nExpiring] := e^.id;
              expiringDuration[nExpiring] := e^.duration;
            end else
              again := True;
          e := e^.next;
        end;
        { then remove them, skipping any an earlier removal's handler has already removed and freed (Slow Poison's end
          removes the poison's damage effect); a node a handler allocated since can reuse a freed one's address, so the
          id and duration must still match }
        for k := 1 to nExpiring do
          if FxEngine.HasEffectNode(cur, expiring[k]) and (expiring[k]^.id = expiringId[k]) and
              (expiring[k]^.duration = expiringDuration[k]) then
            FxEngine.RemoveEffect(cur, expiring[k]^.id, expiring[k]);
        { a removal's handler can add effects too: the creature is visited again while any timed effect is left }
        e := Types.PEffectRec(cur^.effectsAddr);
        while (e <> nil) and not again do begin
          if e^.duration > 0 then again := True;
          e := e^.next;
        end;
        if i <= SizeOf(GDVars.effFlags) then
          if again then GDVars.effFlags[i] := 1 else GDVars.effFlags[i] := 0;
      end;
      Inc(i);
      cur := cur^.nextCharAddr;
    end;
    if total > 10 then Dec(total, 10) else total := 0;
  end;
end;

{ Read the game clock from the GBVM clock words, bump component tUnit amount times (validating after each bump), write
  it back, then time out effects by the same duration }
procedure AdvanceTime(amount: Byte; tUnit: ShortInt);
var
  time: Types.TClock;
  i: ShortInt;
  j: Byte;
begin
  for i := 0 to 6 do
    time[i] := GDVars.zone0^.words[C_Gbvm.CLOCK + i];
  for j := 1 to amount do begin
    Inc(time[tUnit]);
    Clock.ValidateClock(time, True);
  end;
  for i := 0 to 6 do
    GDVars.zone0^.words[C_Gbvm.CLOCK + i] := time[i];
  FxEngine.TimeOutEffects(amount, tUnit);
end;

function HoldTarget(creature: Types.PCharRecord; p: Pointer; removed: Boolean; effId: Byte;
                    var released: Boolean): Types.PCharRecord;
var
  held: Types.PEffectRec;
begin
  HoldTarget := nil;
  released := False;
  if (Types.PEffectRec(p)^.strength = 0) or (Types.PEffectRec(p)^.strength > GDVars.arenaCount) or
      (Types.PEffectRec(p)^.strength > Types.ARENA_SLOTS) then begin
    if not removed then begin
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, effId, p);
    end;
    Exit;
  end;
  GDVars.dsOtherCreatureCurrentPtr := GDVars.creatureArr[Types.PEffectRec(p)^.strength];
  if removed or (creature^.enabled = 0) or (GDVars.dsOtherCreatureCurrentPtr^.enabled = 0)
     or not CharHlp.HasEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.IMMOBILE, held) then begin
    FxEngine.RemoveEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.IMMOBILE, nil);
    if not removed then begin
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, effId, p);
    end;
    released := True;
  end else
    HoldTarget := GDVars.dsOtherCreatureCurrentPtr;
end;

end.
