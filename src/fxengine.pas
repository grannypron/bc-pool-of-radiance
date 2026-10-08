{ Effect dispatch and active-effect lists, attack rolls, saving throws, damage, healing and revival. }
{$O+,F+}
unit FxEngine;

interface

{ C_Effect supplies the EFF_ effect ids }
uses Types, C_Terr, C_Save, C_Cond, GDConsts, GDVars, Blit, TextRend, CharHlp, Pathing, CbtMap,
  C_Effect, C_Status, C_Ifc, C_Dir;

{ Call the effect handler for effId (1..139) through GDVars.effectFns. p is the item or effect node the handler
  concerns; removed is True when the item is being unreadied or the effect removed. }
procedure CallEffectHandler(effId: Byte; creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Remove an effect node from the creature's list: eff when it is not nil, else the first node whose id is effId (nothing
  happens if there is none). If the node's onRemove flag is set, effId's handler is first called with removed = True;
  the node is then unlinked and freed. }
procedure RemoveEffect(creature: Types.PCharRecord; effId: Byte; eff: Pointer);

{ Fire, on one creature, every effect id registered under condition cond (0..19, the COND_ constants of C_Cond and of
  this unit). Each id goes through the private TriggerEffect, which also honours the aura effects 21, 45, 46 and 49
  carried by other creatures. }
procedure TriggerEffectsWithCondition(cond: Byte; creature: Types.PCharRecord);

{ Stinking-cloud check for an enabled creature: CbtMap.ProbeDirection (dir 8, its own cells) must report terrain 30
  (C_Terr.STINK_CLOUD), and any of effects 30, 31, 32, 111 and 125 prevents it. A successful save vs.
  paralyzation/poison (type 0) gives effect 30 "starts to cough" for 1 minute, a failure effect 31 "chokes and gags from
  nausea" for 1d4+1 minutes; that effect's handler is then called at once with a nil node, whether or not the effect was
  applied. }
procedure ConsiderStinkingCloud(creature: Types.PCharRecord);

{ Attack roll with no attacking creature (used by ECL script attacks): d20 into gAttackRoll, where 1 misses and 20
  becomes 100, then the defender's C_Cond.ATTACK_ROLL_DEF (16) effects run. Hit when the roll is still >= 0 and roll +
  sixtyMinusThac0 > defender^.acCur. }
function AttackRollNoAttacker(defender: Types.PCharRecord; sixtyMinusThac0: Byte): Boolean;

{ Full attack roll: strip the attacker's invisibility (effect 25), roll d20 into gAttackRoll (1 misses, 20 becomes 100),
  run the attacker's C_Cond.ATTACK_ROLL_ATT (10) and the defender's C_Cond.ATTACK_ROLL_DEF (16) effects, and take the
  GBVM modifier zmod (low byte of $6E71 when the attacker is allied, of $6E70 when hostile). Hit when the roll is still
  >= 0 and roll + attacker^.thac0Cur + zmod >= sixtyMinusAc. }
function AttackRoll(attacker, defender: Types.PCharRecord; sixtyMinusAc: Byte): Boolean;

{ d20 saving throw into GDVars.gSaveRoll: 1 always fails and 20 always succeeds. Otherwise the roll becomes roll +
  creature^.saveBonus + modifier, gSaveType is set to saveType, the creature's C_Cond.SAVING_THROW (12) effects run, and
  the save succeeds when creature^.saves[saveType] <= the modified roll. }
function RollSavingThrow(creature: Types.PCharRecord; saveType, modifier: ShortInt): Boolean;

{ Roll n dice with the given number of sides and return the total (0 when n = 0; the Byte sum wraps past 255). }
function RollDice(n, sides: Byte): Byte;

{ RollDice that also posts the dice count n to gDamageDice. Does not set GDVars.pendingDamage. }
function RollDamageDice(n, sides: Byte): Byte;

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

{ Encode Strength as an effect strength byte: base 18 gives excStr + 1, any other base gives baseStr + 100. Bit 7 is
  left for the caller's "superseded" mark. }
function StrengthModifier(baseStr, excStr: Byte): Byte;

{ Decode an effect's strength byte (bit 7 masked off) into base and exceptional Strength: values <= 101 give base 18
  with exceptional value - 1, larger values give base value - 100 with exceptional 0. }
procedure StrengthEffectToStrength(effect: Types.PEffectRec; var baseStr, excStr: Byte);

{ Apply a new Strength from a Strength effect. If it is weaker than the creature's current Strength, nothing changes:
  effStrength gets the new Strength encoded with bit 7 set and the result is False. Otherwise the first active Strength
  effect (id 12 or 38 with strength < $80), if any, is superseded: it is given the creature's current Strength, encoded
  with bit 7 set. The new Strength is stored, CharHlp.RecalcStats runs, effStrength gets the Strength to restore when
  the new effect ends (the superseded effect's previously stored Strength, else the current one) and the result is
  True. }
function AdjustForNewStrength(creature: Types.PCharRecord; baseStr, excStr: Byte; var effStrength: Byte): Boolean;

{ Non-weapon damage: post damage to GDVars.pendingDamage and run the C_Cond.NONWEAPON_DAMAGE (6) effects; when saved,
  saveReduction 1 cancels the damage and 2 halves it. If any damage remains, print it with its element from
  GDVars.elementMask (Fire, Cold, Electricity, Acid, or "from Magic" when no bit but magic is set), apply it with
  CharHlp.InflictDamage and, in combat, clear castAllowed and lose any spell being cast. A creature it disables "Goes
  Down" (", and is Dying") or "is killed" (status 6..8); in combat the hpZeroEffects are removed, the C_Cond.HP_ZERO
  (13) effects run and CbtMap.CreatureDowned is called if the creature is still disabled. }
procedure InflictNonWeaponDamage(creature: Types.PCharRecord; damage, saveReduction: Byte; saved: Boolean);

{ AddEffect with an immunity check and a message. The effect is refused with "is Unaffected" when a
  C_Cond.EFFECT_IMMUNITY (9) effect clears GDVars.pendingEffectId, or when saved and saveNegates are both True.
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

implementation

var

  { GBVM zone 1 as bytes: byte 2 * (addr - $6B00) is the low byte of GBVM word addr }
  zone1B: Types.PFxengineZoneBytes absolute GDVars.zone1;
  { save type of the current saving throw, 0..4 (the SAVE_ constants of C_Save and EffHndlr) }
  gSaveType: Byte absolute GDVars.gSaveType;
  { effect handler table, indexed by effect id }
  effectHandlers: array[C_Effect.BLESS..C_Effect.READY_RING_INVIS] of Types.TEffectHandler
                             absolute GDVars.effectFns;

procedure CallEffectHandler(effId: Byte; creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  effectHandlers[effId](creature, p, removed);
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
  end;
  if p = nil then Exit;
  if Types.PEffectRec(p)^.onRemove then
    FxEngine.CallEffectHandler(effId, creature, p, True);
  if creature^.effectsAddr = p then
    creature^.effectsAddr := p^.next
  else begin
    prev := creature^.effectsAddr;
    while (prev <> nil) and (prev^.next <> p) do
      prev := prev^.next;
    prev^.next := p^.next;
  end;
  FreeMem(p, SizeOf(Types.TEffectRec));
end;

{ Trigger one effect id on the creature: call its handler if the creature itself has the effect, or, for the aura
  effects 21 (Silence 15'), 45 (Prot Evil 10'), 46 (Prot Good 10') and 49 (Prayer), if any creature carrying it has this
  one in range (6 for Prayer, else 1; out of combat any carrier counts). The handler gets the node found: the creature's
  own, or the carrier's for an aura. The range test uses Pathing.BuildTargetList, saving and restoring the caller's
  target list around it. }
procedure TriggerEffect(creature: Types.PCharRecord; effId: Byte);
var
  save: array[1..72] of Types.TCombatTarget;
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
var
  effect: Types.PEffectRec;
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
      FxEngine.TriggerEffect(creature, C_Effect.MIRROR_IMAGE); FxEngine.TriggerEffect(creature,
          C_Effect.PROT_MISSILES);
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
      FxEngine.TriggerEffect(creature, C_Effect.BLIND); FxEngine.TriggerEffect(creature, C_Effect.SHIELD);
      FxEngine.TriggerEffect(creature, C_Effect.PROT_EVIL); FxEngine.TriggerEffect(creature,
                                                                                       C_Effect.PROT_GOOD);
      FxEngine.TriggerEffect(creature, C_Effect.PROT_EVIL_10FT); FxEngine.TriggerEffect(creature,
          C_Effect.PROT_GOOD_10FT);
      FxEngine.TriggerEffect(creature, C_Effect.STINK_COUGH);
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
  { save vs. paralyzation, poison and death magic }
  saved := FxEngine.RollSavingThrow(creature, C_Save.PARALYZE, 0);
  if saved then begin
    FxEngine.AddEffectWithMessage(creature, C_Effect.STINK_COUGH, 1, 255, False, False, saved, 'starts to cough');
    FxEngine.CallEffectHandler(C_Effect.STINK_COUGH, creature, effect, False);
  end else begin
    FxEngine.AddEffectWithMessage(creature, C_Effect.HELPLESS, FxEngine.RollDice(1, 4) + 1, 255, False, False,
                                  saved, 'chokes and gags from nausea');
    FxEngine.CallEffectHandler(C_Effect.HELPLESS, creature, effect, False);
  end;
end;

function AttackRollNoAttacker(defender: Types.PCharRecord; sixtyMinusThac0: Byte): Boolean;
begin
  AttackRollNoAttacker := False;
  GDVars.gAttackRoll := FxEngine.RollDice(1, 20);
  if GDVars.gAttackRoll > 1 then begin
    if GDVars.gAttackRoll = 20 then GDVars.gAttackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACK_ROLL_DEF, defender);
    if (GDVars.gAttackRoll >= 0) and (GDVars.gAttackRoll + sixtyMinusThac0 > defender^.acCur) then
      AttackRollNoAttacker := True;
  end;
end;

function AttackRoll(attacker, defender: Types.PCharRecord; sixtyMinusAc: Byte): Boolean;
var
  zmod: ShortInt;
begin
  AttackRoll := False;
  FxEngine.RemoveInvisibility(attacker);
  GDVars.gAttackRoll := FxEngine.RollDice(1, 20);
  if GDVars.gAttackRoll > 1 then begin
    if GDVars.gAttackRoll = 20 then GDVars.gAttackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACK_ROLL_ATT, attacker);
    FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACK_ROLL_DEF, defender);
    if attacker^.hostile = 0 then
      { GBVM $6E71 (party) }
      zmod := zone1B^[$6E2]
    else
      { GBVM $6E70 (monster) }
      zmod := zone1B^[$6E0];
    if (GDVars.gAttackRoll >= 0) and (GDVars.gAttackRoll + attacker^.thac0Cur + zmod >= sixtyMinusAc) then
      AttackRoll := True;
  end;
end;

function RollSavingThrow(creature: Types.PCharRecord; saveType, modifier: ShortInt): Boolean;
begin
  GDVars.gSaveRoll := FxEngine.RollDice(1, 20);
  case GDVars.gSaveRoll of
    1: RollSavingThrow := False;
    20: RollSavingThrow := True;
  else begin
    GDVars.gSaveRoll := GDVars.gSaveRoll + creature^.saveBonus + modifier;
    gSaveType := saveType;
    FxEngine.TriggerEffectsWithCondition(C_Cond.SAVING_THROW, creature);
    if creature^.saves[saveType] <= GDVars.gSaveRoll then
      RollSavingThrow := True
    else
      RollSavingThrow := False;
  end;
  end;
end;

function RollDice(n, sides: Byte): Byte;
var
  i: Byte;
  total: Byte;
begin
  total := 0;
  if n > 0 then
    for i := 1 to n do
      Inc(total, Random(sides) + 1);
  RollDice := total;
end;

function RollDamageDice(n, sides: Byte): Byte;
begin
  GDVars.gDamageDice := n;
  RollDamageDice := FxEngine.RollDice(n, sides);
end;

procedure AddEffect(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);
var
  { p is the new node, q walks to the tail }
  p: Types.PEffectRec;
  q: Types.PEffectRec;
begin
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
  CharHlp.PrintNameString(creature, msg, 10, True);
  creature^.enabled := 0;
  creature^.status := status;
  { a creature that fled (C_Status.RUNNING) keeps its hit points }
  if creature^.status <> C_Status.RUNNING then
    creature^.hpCur := 0;
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  Blit.FlushView;
  GDVars.arenaLoc[slot].size := 0;
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
    CharHlp.PrintNameString(creature, 'is Cured', 10, True);
    FxEngine.RemoveEffect(creature, effId, effect);
    RemoveEffectWithMessage := True;
  end;
end;

function StrengthModifier(baseStr, excStr: Byte): Byte;
begin
  StrengthModifier := baseStr + 100;
  if baseStr = 18 then
    StrengthModifier := excStr + 1;
end;

procedure StrengthEffectToStrength(effect: Types.PEffectRec; var baseStr, excStr: Byte);
begin
  excStr := 0;
  baseStr := Types.PEffectRec(effect)^.strength and $7F;
  if baseStr <= 101 then begin
    excStr := baseStr - 1;
    baseStr := 18;
  end else
    baseStr := baseStr - 100;
end;

function AdjustForNewStrength(creature: Types.PCharRecord; baseStr, excStr: Byte; var effStrength: Byte): Boolean;
var
  p: Types.PEffectRec;
  found: Types.PEffectRec;
  oldBase: Byte;
  oldExc: Byte;
  enc: Byte;
begin
  oldBase := creature^.strCur;
  oldExc := creature^.strExc;
  if (baseStr < oldBase) or ((baseStr = 18) and (excStr < oldExc)) then begin
    AdjustForNewStrength := False;
    effStrength := FxEngine.StrengthModifier(baseStr, excStr) + $80;
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
      enc := FxEngine.StrengthModifier(oldBase, oldExc);
      FxEngine.StrengthEffectToStrength(found, oldBase, oldExc);
      Types.PEffectRec(found)^.strength := enc + $80;
    end;
    creature^.strCur := baseStr;
    creature^.strExc := excStr;
    CharHlp.RecalcStats(creature);
    effStrength := FxEngine.StrengthModifier(oldBase, oldExc);
    AdjustForNewStrength := True;
  end;
end;

procedure InflictNonWeaponDamage(creature: Types.PCharRecord; damage, saveReduction: Byte; saved: Boolean);
var
  s: String;
begin
  GDVars.pendingDamage := damage;
  FxEngine.TriggerEffectsWithCondition(C_Cond.NONWEAPON_DAMAGE, creature);
  if saved then
    case Char(saveReduction) of
      #1: GDVars.pendingDamage := 0;
      #2: GDVars.pendingDamage := Integer(GDVars.pendingDamage) div 2;
    end;
  if GDVars.pendingDamage > 0 then begin
    if GDVars.pendingDamage <> 1 then
      s := 'takes ' + CharHlp.ByteToString(GDVars.pendingDamage) + ' points of damage '
    else
      s := 'takes 1 point of damage ';
    case GDVars.elementMask and $F7 of
      1: s := s + 'from Fire';
      2: s := s + 'from Cold';
      4: s := s + 'from Electricity';
      16: s := s + 'from Acid';
    end;
    { magic bit alone, or no element bit at all }
    if (GDVars.elementMask and 8) = GDVars.elementMask then
      s := s + 'from Magic';
    CharHlp.PrintNameStringAnim(creature, False, s);
    CharHlp.InflictDamage(creature, GDVars.pendingDamage);
    if GDVars.ifcState = C_Ifc.COMBAT then begin
      creature^.combatAddr^.castAllowed := 0;
      if creature^.combatAddr^.spellCast > 0 then begin
        CharHlp.PrintNameString(creature, 'lost a spell', 12, True);
        CharHlp.RemoveSpell(creature^.combatAddr^.spellCast);
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
      CharHlp.PrintNameString(creature, s, GDVars.curRow + 1, False);
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
    CharHlp.ClearMessageWindow;
  end;
end;

procedure AddEffectWithMessage(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove,
                               saveNegates, saved: Boolean; msg: Types.TStr40);
var
  effect: Types.PEffectRec;
  frameSizer: Byte;
begin
  GDVars.pendingEffectId := effId;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_IMMUNITY, creature);
  if (GDVars.pendingEffectId = 0) or (saved and (saveNegates = True)) then
    CharHlp.PrintNameString(creature, 'is Unaffected', 10, True)
  else begin
    if CharHlp.HasEffect(creature, effId, effect) then
      if ((Types.PEffectRec(effect)^.duration > 0) and (minutes > Types.PEffectRec(effect)^.duration)) or
          (minutes = 0) then
        FxEngine.RemoveEffect(creature, effId, effect);
    FxEngine.AddEffect(creature, effId, minutes, strength, onRemove);
    if msg[0] <> #0 then begin
      CharHlp.PrintNameStringAnim(creature, True, msg);
      CharHlp.ClearMessageWindow;
    end;
  end;
end;

function RestoreHitPoints(creature: Types.PCharRecord; hp: Byte; bypassRot: Boolean): Boolean;
var
  effect: Types.PEffectRec;
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
  creature^.hpCur := creature^.hpCur + hp;
  if creature^.hpCur > creature^.hpMax then
    creature^.hpCur := creature^.hpMax;
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
    CharHlp.PrintNameString(creature, s, 10, True);
    CharHlp.CountTeams;
    ReviveDeadCreature := True;
  end else
    ReviveDeadCreature := False;
end;

begin
end.
