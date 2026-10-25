{ Effect dispatch and active-effect lists, attack rolls, saving throws, damage, healing and revival. }
{$O+,F+}
{$I COMPILER.INC}
unit FxEngine;

interface

uses Types;

var
  { Creatures whose timed effects need processing, by list ordinal. }
  effFlags: array[1..Types.ARENA_SLOTS] of Byte;
  { modified saving-throw roll; signed, so a penalty can take it below 0 }
  gSaveRoll: Integer;
  { saving throw type, 0..4 }
  gSaveType: Byte;

{ Call the effect handler for effId (1..141) through GameVars.effectFns; an id outside the table calls nothing. p is the
  item or effect node the handler concerns; removed is True when the item is being unreadied or the effect removed. }
procedure CallEffectHandler(effId: Byte; creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Remove an effect node from the creature's list: eff when it is not nil, else the first node whose id is effId (nothing
  happens if there is none, or if eff is not in the list). If the node's onRemove flag is set, effId's handler is first
  called with removed = True; the node is then unlinked and freed, unless the handler has removed it already. }
procedure RemoveEffect(creature: Types.PCharRecord; effId: Byte; eff: Pointer);

{ True when eff is a node of the creature's effect list. A caller holding a node across a removal checks it with this,
  since the removal's handler may have removed and freed it. }
function HasEffectNode(creature: Types.PCharRecord; eff: Pointer): Boolean;

{ True when the creature has a disease, one of C_EFFECT.DISEASES: what RemoveDiseases cures. }
function HasDisease(creature: Types.PCharRecord): Boolean;

{ Cure the creature's diseases, quietly, with the effect lock held, and return whether there was one: every cure of
  disease (the Cure Disease spell, Keoghtom's Ointment, the temple's and the paladin's) runs this one rule, and each
  caller says what it did. Diseased goes; the Strength-draining disease goes with its hit-point drain and the
  helplessness it brings; rot goes with mummy rot; and a hit-point drain or mummy rot found alone goes too. HELPLESS
  is not taken on its own, since a Stinking Cloud's nausea is that effect too (#922). }
function RemoveDiseases(creature: Types.PCharRecord): Boolean;

{ The Charisma a creature with Charisma cha has once a Friends effect of strength strength ends (#920). A Friends
  effect holds C_EFFECT.FRIENDS_BONUS plus the Charisma it gave, which comes off again, so two at once, or a Charisma
  change while one lasts, leave nothing behind; one saved before the change holds the Charisma to restore. Kept to
  the score range. }
function FriendsEndCha(cha, strength: Byte): Byte;

{ Fire, on one creature, every effect id registered under condition cond (0..19, the C_COND constants). Each id goes
  through the private TriggerEffect, which also honours the aura effects 21, 45, 46 and 49 carried by other creatures;
  Protection from Evil (8, 45) and from Good (9, 46) each apply once however many sources there are, and Prayer (49)
  once for each side that has one in reach. }
procedure TriggerEffectsWithCondition(cond: Byte; creature: Types.PCharRecord);

{ True when a Stinking Cloud cannot touch creature, whatever the dice: it is animated dead (C_EFFECT.ANIMATE_DEAD), is
  coughing already (STINK_COUGH), or is immune to poison (NO_PARA_POISON, NO_CHARM_POISON). CombatAi keeps every other
  creature out of a cloud. }
function CloudProof(creature: Types.PCharRecord): Boolean;

{ True when a Stinking Cloud does nothing to creature now: it is disabled, nauseated already (C_EFFECT.HELPLESS) or
  CloudProof. ConsiderStinkingCloud passes over it. }
function CloudSpares(creature: Types.PCharRecord): Boolean;

{ Stinking-cloud check for a creature the cloud does not spare (CloudSpares): CbtMap.ProbeDirection (dir 8, its own
  cells) must report terrain 30 (C_TERR.STINK_CLOUD). It saves vs. paralyzation/poison (type 0); a failure, unless the
  creature is immune (magic resistance), gives effect 31 "chokes and gags from nausea" for 1d4+1 minutes, whose handler
  then runs at once with the new node. A save or an immunity leaves it "Unaffected", with no effect at all. SSI's gave a
  save effect 30, coughing, and ran the handler whether or not the effect was applied, so a creature whose resistance
  refused it still coughed or retched (POR-0218, #939). }
procedure ConsiderStinkingCloud(creature: Types.PCharRecord);

{ The lowest cloud number, at most 15, that none of the caster's clouds on the GameVars.stinkHead list has, so the
  number in the caster's Cast Stinking Cloud effect (strength div 16) names one cloud alone. }
function FreeCloudNumber(caster: Types.PCharRecord): Byte;

{ The Cast Stinking Cloud effect's strength: the cloud number (FreeCloudNumber) in the high nibble and the caster level
  in the low one, which Dispel Magic reads. A level above 15 is stored as 15 rather than carrying into the number. }
function CloudStrength(level, num: Byte): Byte;

{ The Prayer effect's strength: the caster's team (CharHlp.Team) in the C_EFFECT.PRAYER_SIDE bit and the caster level
  below it. A level above 15 is stored as 15, and a hostile byte above 1 is cut to its team, rather than either
  carrying into the side or past it (#827). }
function PrayerStrength(caster: Types.PCharRecord; level: Byte): Byte;

{ The side, 0 or 1, that cast a Prayer effect: its strength's C_EFFECT.PRAYER_SIDE bit. }
function PrayerSide(effect: Types.PEffectRec): Byte;

{ Attack roll with no attacking creature (used by ECL script attacks): d20 into gAttackRoll, where 1 misses and 20
  becomes 100, then the defender's C_COND.ATTACK_ROLL_DEF (16) effects run. Hit when no effect forced a miss
  (GameVars.gAttackAvoided) and roll + sixtyMinusThac0 >= defender^.acCur, AttackRoll's test; SSI's needed more than
  acCur, so a script's attack hit 5% less often than a creature's with the same THAC0 (#719). }
function AttackRollNoAttacker(defender: Types.PCharRecord; sixtyMinusThac0: Byte): Boolean;

{ Full attack roll: strip the attacker's invisibility (effect 25), roll d20 into gAttackRoll (1 misses, 20 becomes 100),
  run the attacker's C_COND.ATTACK_ROLL_ATT (10) and the defender's C_COND.ATTACK_ROLL_DEF (16) effects, and take the
  GBVM modifier zmod (the low byte of C_GBVM.PARTY_HIT_MOD when the attacker is allied, of C_GBVM.MONSTER_HIT_MOD when
  hostile). Hit when no effect forced a miss (GameVars.gAttackAvoided) and roll + attacker^.thac0Cur + zmod >=
  sixtyMinusAc. Penalties that take the roll below 0 only lower it; SSI's took any roll below 0 for a forced miss
  (#718). }
function AttackRoll(attacker, defender: Types.PCharRecord; sixtyMinusAc: Byte): Boolean;

{ What AttackRoll adds to attacker's roll: its thac0Cur (60 - THAC0) and the GBVM modifier zmod of its side. }
function HitBonus(attacker: Types.PCharRecord): Integer;

{ d20 saving throw into gSaveRoll: 1 always fails and 20 always succeeds. Otherwise the roll becomes roll +
  creature^.saveBonus + modifier, gSaveType is set to saveType, the creature's C_COND.SAVING_THROW (12) effects run, and
  the save succeeds when creature^.saves[saveType] <= the modified roll. A saveType outside C_SAVE.PARALYZE..SPELL (an
  ECL script supplies it) is rolled as C_SAVE.SPELL. }
function RollSavingThrow(creature: Types.PCharRecord; saveType, modifier: ShortInt): Boolean;

{ Allocate an effect node, append it to the creature's effect list (as the head if the list is empty) and fill in id,
  duration (minutes; 0 = permanent), onRemove and strength. Does not check for an existing node or call the handler. }
procedure AddEffect(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);

{ Take an enabled creature out of play: center the map view on it, print msg after its name, disable it and set its
  status. Its hit points drop to 0 unless the status is C_STATUS.RUNNING (fled). Its sprite is erased from the combat
  map, its arena location cleared and the arena arrays rebuilt; then its per-round combat state is reset
  (CharHlp.EndActions) and the hpZeroEffects removed. }
procedure PutOutOfPlayWithStatus(creature: Types.PCharRecord; status: Byte; msg: Types.TStr40);

{ Remove every invisibility (effect 25) node from the creature. }
procedure RemoveInvisibility(creature: Types.PCharRecord);

{ True when a blow or a single-target spell strikes one of the creature's mirror images (Mirror Image, image its node,
  strength the images left): unless 1d(images + 1) rolls 1. }
function ImageStruck(image: Types.PEffectRec): Boolean;

{ The struck image is lost: "lost an image", one fewer in image's strength, and the node removed with the last. }
procedure LoseImage(creature: Types.PCharRecord; image: Types.PEffectRec);

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
  the new effect ends (the superseded effect's previously stored Strength, else the current one) and the result is True.
  The current Strength is taken with a disease's loss given back, and the new one is stored less it
  (CharHlp.DiseaseStrLoss). }
function AdjustForNewStrength(creature: Types.PCharRecord; baseStr, excStr: Byte; var effStrength: Byte): Boolean;

{ Non-weapon damage: post damage to GameVars.pendingDamage and run the C_COND.NONWEAPON_DAMAGE (6) effects; when saved,
  saveReduction 1 cancels the damage and 2 halves it. If any damage remains, print it with its element from
  GameVars.elementMask (Fire, Cold, Electricity, Acid, poison, disease, blood drain, or "from Magic" when no bit but
  magic is set, or none is), apply it with
  CharHlp.InflictDamage and, in combat, clear castAllowed and lose any spell being cast. A creature it disables "Goes
  Down" (", and is Dying") or "is killed" (status 6..8); in combat the hpZeroEffects are removed, the C_COND.HP_ZERO
  (13) effects run and CbtMap.CreatureDowned is called if the creature is still disabled. A dead, stoned or gone
  creature (a corpse a single-target spell was aimed at) is left alone. }
procedure InflictNonWeaponDamage(creature: Types.PCharRecord; damage, saveReduction: Byte; saved: Boolean);

{ InflictNonWeaponDamage, with no save, for an aligned item (eff 132) that shocks the creature readying it: in place of
  "takes n points of damage" the message window shows "<item> shocks <name> for <n> damage, and has been unequipped."
  with the item's displayed name, and waits for a key (CharDisp.MessageWait). }
procedure InflictItemShock(creature: Types.PCharRecord; item: Types.PItemRec; damage: Byte);

{ True when effId is a disease (Diseased, its Strength and hit point drains, or mummy rot) and the creature has paladin
  levels: paladins catch no disease. }
function DiseaseImmune(creature: Types.PCharRecord; effId: Byte): Boolean;

{ The immunity check: True when the creature is immune to effId: one of its C_COND.EFFECT_IMMUNITY (9) effects (a ward,
  an immunity or magic resistance) clears GameVars.pendingEffectId, or FxEngine.DiseaseImmune holds. pendingEffectId is
  0 again afterwards: SSI's left effId in it, and magic resistance, which takes any damage while it is set, then
  resisted later damage of no magic, such as acid or blood drain (POR-0219, #940). }
function EffectImmune(creature: Types.PCharRecord; effId: Byte): Boolean;

{ AddEffect with an immunity check and a message. The effect is refused with "is Unaffected" when FxEngine.EffectImmune
  holds, or when saved and saveNegates are both True. Otherwise an existing node with the same id is removed first if it
  is timed and the new duration is longer, or if the new effect is permanent (0); in any other case the new node is
  added alongside it. A non-empty msg is printed after the creature's name. }
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

{ Toggle an item's readied state for curChar. Unreadying fails on a cursed item. Readying checks, with later checks
  overriding earlier ones, free hands (3), an occupied slot or ammunition slot (2) and the class mask (1); the
  hands-full message is skipped for a quick-fighting creature in combat. Special items (special > $7F) invoke their
  effect handler when readied and when unreadied. }
procedure ToggleReadyItem(item: Types.PItemRec);

{ Read the game clock from the GBVM clock words, bump component tUnit (C_TIME) amount times (validating after each
  bump), write it back, then time out effects by the same duration (whole minutes: segments short of one age none). }
procedure AdvanceTime(amount: Byte; tUnit: ShortInt);

{ The start of a hold effect's handler (bite and hold, blood drain): p is the effect, its strength the victim's creature
  index. Returns the victim (also set in GameVars.otherCreatureCurrentPtr) while the hold lasts, else nil: with no
  victim in the arena the effect just goes (released False); when the effect is being removed, either side is down or
  the victim is no longer C_EFFECT.IMMOBILE (it broke free, #709), the victim loses C_EFFECT.IMMOBILE and the effect
  goes (released True). The effect is removed here with onRemove cleared first, unless removed says it is already being
  removed. }
function HoldTarget(creature: Types.PCharRecord; p: Pointer; removed: Boolean; effId: Byte;
                    var released: Boolean): Types.PCharRecord;

{ The reach of an aura effect, which acts in combat on the creatures within that range of the one carrying it
  (EffectSource): 6 for Prayer and 1 for Silence 15' and Protection from Evil and from Good 10'. 0 for an effect that
  acts only on its carrier. }
function AuraRange(effId: Byte): Byte;

implementation

uses Stats, StrUtil, AbilAdj, C_GBVM, CharDisp, C_TIME, Dice, Clock, C_TERR, C_SAVE, C_COND, GameDefs, GameVars, Blit,
  TextRend, CharHlp, Pathing, CbtMap, C_EFFECT, C_STATUS, C_IFC, C_DIR, C_LEVEL, Crt, C_ITEM, C_EQUIP;

const
  { EffectSource's side for a node cast by either side }
  ANY_SIDE = 255;

procedure CallEffectHandler(effId: Byte; creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (effId >= C_EFFECT.BLESS) and (effId <= C_EFFECT.RECENT_CURE) then
    GameVars.effectFns[effId](creature, p, removed);
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

{ True when effect id effId acts on the creature, with effect the node that does: the creature's own, or, for the aura
  effects 21 (Silence 15'), 45 (Prot Evil 10'), 46 (Prot Good 10') and 49 (Prayer), that of a creature carrying it with
  this one in range (6 for Prayer, else 1; out of combat any carrier counts). A protection aura reaches only the
  carrier's side; SSI's lent it to enemies too, so the monsters a paladin fought were protected from evil (#782).
  Silence silences everyone, and Prayer's handler sorts the sides itself. A protection aura or a Prayer is the
  carrier's own and lapses while it is out of action (enabled 0: down, dead or fled); Silence is on its spot and stays.
  SSI's took any carrier's (POR-0220, #941). The sides are teams (CharHlp.Team), as a
  damaged save can hold a hostile byte above 1. side, for Prayer, takes only a node cast by that side
  (C_EFFECT.PRAYER_SIDE of its strength); ANY_SIDE takes any node. The range test uses Pathing.BuildTargetList, saving
  and restoring the caller's target list and its count around it (SSI's left the rebuilt list's count). }
function EffectSource(creature: Types.PCharRecord; effId, side: Byte; var effect: Types.PEffectRec): Boolean;
var
  save: Types.TTargetSnapshot;
  p: Types.PCharRecord;
  found: Boolean;
  i: Byte;
  range: Byte;
  slot: Byte;

  { the creature carries an effId node of the side wanted }
  function Carries(c: Types.PCharRecord): Boolean;
  begin
    Carries := CharHlp.HasEffect(c, effId, effect)
      and ((side = ANY_SIDE) or (FxEngine.PrayerSide(effect) = side));
  end;

begin
  found := False;
  p := GameVars.creatureList;
  range := FxEngine.AuraRange(effId);
  if Carries(creature) then
    found := True
  else if range > 0 then begin
    Pathing.SaveTargets(save);
    slot := CbtMap.CombatSlot(creature);
    while (p <> nil) and not found do begin
      if Carries(p) and ((effId = C_EFFECT.SILENCE) or (p^.enabled <> 0))
         and ((effId in [C_EFFECT.SILENCE, C_EFFECT.PRAYER]) or (CharHlp.Team(p) = CharHlp.Team(creature))) then begin
        if GameVars.ifcState = C_IFC.COMBAT then begin
          Pathing.BuildTargetList(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), range, 255, CbtMap.GetIconSize(p),
                                  GameVars.arenaPtr);
          for i := 1 to GameVars.targetCount do
            if GameVars.targetList[i].idx = slot then
              found := True;
        end else
          found := True;
      end;
      p := p^.nextCharAddr;
    end;
    Pathing.RestoreTargets(save);
  end;
  EffectSource := found;
end;

function AuraRange(effId: Byte): Byte;
begin
  case effId of
    C_EFFECT.PRAYER: AuraRange := 6;
    C_EFFECT.SILENCE, C_EFFECT.PROT_EVIL_10FT, C_EFFECT.PROT_GOOD_10FT: AuraRange := 1;
  else
    AuraRange := 0;
  end;
end;

{ Trigger one effect id on the creature: call its handler with the node FxEngine.EffectSource finds, if any. }
procedure TriggerEffect(creature: Types.PCharRecord; effId: Byte);
var
  effect: Types.PEffectRec;
begin
  if FxEngine.EffectSource(creature, effId, ANY_SIDE, effect) then
    FxEngine.CallEffectHandler(effId, creature, effect, False);
end;

{ Trigger Prayer (eff 49) once for each side with one in reach: a creature within reach of a Prayer from either side
  gets both, its own side's +1 and the other's -1, but two from one side apply once. SSI's took the first carrier in
  range, so of two Prayers from opposite sides only one applied (#801). }
procedure TriggerPrayer(creature: Types.PCharRecord);
var
  effect: Types.PEffectRec;
  side: Byte;
begin
  for side := 0 to 1 do
    if FxEngine.EffectSource(creature, C_EFFECT.PRAYER, side, effect) then
      FxEngine.CallEffectHandler(C_EFFECT.PRAYER, creature, effect, False);
end;

{ Trigger a protection once: the creature's own spell (own, eff 8 or 9) or else an aura it stands in or carries (aura,
  eff 45 or 46). SSI's triggered both, so a paladin's aura and a Protection from Evil spell gave +4 to saves (#783). It
  runs under C_COND.ATTACK_ROLL_DEF and SAVING_THROW. }
procedure TriggerProtection(creature: Types.PCharRecord; own, aura: Byte);
var
  effect: Types.PEffectRec;
begin
  if FxEngine.EffectSource(creature, own, ANY_SIDE, effect) or FxEngine.EffectSource(creature, aura, ANY_SIDE, effect)
  then
    FxEngine.CallEffectHandler(effect^.id, creature, effect, False);
end;

procedure TriggerEffectsWithCondition(cond: Byte; creature: Types.PCharRecord);
begin
  case cond of
    C_COND.ATTACKER_VETO: FxEngine.TriggerEffect(creature, C_EFFECT.GAZE_BLOCK);
    C_COND.TARGET_VETO: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.NULL_TARGET_VETO); FxEngine.TriggerEffect(creature, C_EFFECT.BLINKING);
      FxEngine.TriggerEffect(creature, C_EFFECT.INVISIBLE); FxEngine.TriggerEffect(creature, C_EFFECT.DUST_DISAPPEAR);
    end;
    C_COND.HIT_PHASE_1: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.DRAIN_ONE); FxEngine.TriggerEffect(creature, C_EFFECT.DRAIN_TWO);
      FxEngine.TriggerEffect(creature, C_EFFECT.ROT_TOUCH); FxEngine.TriggerEffect(creature, C_EFFECT.GHOUL_PARA);
      FxEngine.TriggerEffect(creature, C_EFFECT.FIRE_TOUCH); FxEngine.TriggerEffect(creature, C_EFFECT.ACID_SQUIRT);
      FxEngine.TriggerEffect(creature, C_EFFECT.BLOOD_ATTACH);
      FxEngine.TriggerEffect(creature, C_EFFECT.REAR_CLAW_RAKE); FxEngine.TriggerEffect(creature, C_EFFECT.BITE_ATTACH);
    end;
    C_COND.HIT_PHASE_2: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.POISON_HIT0); FxEngine.TriggerEffect(creature, C_EFFECT.POISON_HIT4);
      FxEngine.TriggerEffect(creature, C_EFFECT.POISON_HIT2); FxEngine.TriggerEffect(creature, C_EFFECT.KREEN_PARA);
      FxEngine.TriggerEffect(creature, C_EFFECT.GHOUL_PARA); FxEngine.TriggerEffect(creature, C_EFFECT.DRIDER_PARA);
      FxEngine.TriggerEffect(creature, C_EFFECT.POISON_HIT_M2); FxEngine.TriggerEffect(creature, C_EFFECT.FIRE_TOUCH);
      FxEngine.TriggerEffect(creature, C_EFFECT.DRAIN_ONE); FxEngine.TriggerEffect(creature, C_EFFECT.DRAIN_TWO);
      FxEngine.TriggerEffect(creature, C_EFFECT.ROT_TOUCH);
    end;
    C_COND.WEAPON_DAMAGE_ATT: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.ENFEEBLE); FxEngine.TriggerEffect(creature, C_EFFECT.UNDEAD_SLAYER);
      FxEngine.TriggerEffect(creature, C_EFFECT.FLAME_TONGUE);
    end;
    C_COND.WEAPON_DAMAGE_DEF: begin
      { Mirror Image against weapons is CbtActs.DoAttack's }
      FxEngine.TriggerEffect(creature, C_EFFECT.PROT_MISSILES);
      FxEngine.TriggerEffect(creature, C_EFFECT.KREEN_DODGE); FxEngine.TriggerEffect(creature, C_EFFECT.BOULDER_DODGE);
      FxEngine.TriggerEffect(creature, C_EFFECT.TROLL_HEAL); FxEngine.TriggerEffect(creature, C_EFFECT.HALF_PIERCE);
      FxEngine.TriggerEffect(creature, C_EFFECT.HALF_MAGICAL); FxEngine.TriggerEffect(creature, C_EFFECT.NEED_MAGIC);
      FxEngine.TriggerEffect(creature, C_EFFECT.SILVER_MAGIC); FxEngine.TriggerEffect(creature, C_EFFECT.NEED_SILVER);
      FxEngine.TriggerEffect(creature, C_EFFECT.HALF_BASH); FxEngine.TriggerEffect(creature, C_EFFECT.NULL_DAMAGE);
      FxEngine.TriggerEffect(creature, C_EFFECT.MUMMY_FIRE); FxEngine.TriggerEffect(creature, C_EFFECT.HOLY_WATER);
    end;
    C_COND.NONWEAPON_DAMAGE: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.EFREETI_FIRE); FxEngine.TriggerEffect(creature, C_EFFECT.RING_FIRE_RES);
      FxEngine.TriggerEffect(creature, C_EFFECT.MUMMY_FIRE); FxEngine.TriggerEffect(creature, C_EFFECT.NULL_DAMAGE);
      FxEngine.TriggerEffect(creature, C_EFFECT.IMMUNE_MM); FxEngine.TriggerEffect(creature, C_EFFECT.RESIST_COLD);
      FxEngine.TriggerEffect(creature, C_EFFECT.RESIST_FIRE); FxEngine.TriggerEffect(creature, C_EFFECT.MAGIC_RES50);
      FxEngine.TriggerEffect(creature, C_EFFECT.MAGIC_RES85); FxEngine.TriggerEffect(creature, C_EFFECT.NO_FIRE);
      FxEngine.TriggerEffect(creature, C_EFFECT.HALF_ELEC); FxEngine.TriggerEffect(creature, C_EFFECT.HALF_COLD);
      FxEngine.TriggerEffect(creature, C_EFFECT.SHIELD); FxEngine.TriggerEffect(creature, C_EFFECT.HALF_FIRE);
      FxEngine.TriggerEffect(creature, C_EFFECT.TROLL_HEAL); FxEngine.TriggerEffect(creature, C_EFFECT.MIRROR_IMAGE);
    end;
    C_COND.TURN_START: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.SNAKE_CHARM); FxEngine.TriggerEffect(creature, C_EFFECT.PARALYSIS);
      FxEngine.TriggerEffect(creature, C_EFFECT.SLEEP); FxEngine.TriggerEffect(creature, C_EFFECT.HELPLESS);
    end;
    C_COND.COMBAT_START: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.CAN_FIGHT_ON); FxEngine.TriggerEffect(creature, C_EFFECT.DRAGON_FEAR);
      { displacement is made due again by EffHndlr.ResetDisplacement }
      FxEngine.TriggerEffect(creature, C_EFFECT.MUMMY_FEAR); FxEngine.TriggerEffect(creature, C_EFFECT.CAMOUFLAGE);
      FxEngine.TriggerEffect(creature, C_EFFECT.RING_INVIS);
    end;
    C_COND.EFFECT_IMMUNITY: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.MAGIC_RES50); FxEngine.TriggerEffect(creature, C_EFFECT.MAGIC_RES85);
      FxEngine.TriggerEffect(creature, C_EFFECT.ELF_RESIST); FxEngine.TriggerEffect(creature, C_EFFECT.NO_SLEEP_CHARM);
      FxEngine.TriggerEffect(creature, C_EFFECT.NO_PARALYSIS); FxEngine.TriggerEffect(creature, C_EFFECT.NO_COLD);
      FxEngine.TriggerEffect(creature, C_EFFECT.NO_PARA_POISON); FxEngine.TriggerEffect(creature, C_EFFECT.NO_FIRE);
      FxEngine.TriggerEffect(creature, C_EFFECT.HALF_ELF_RESIST);
      FxEngine.TriggerEffect(creature, C_EFFECT.NO_CHARM_POISON);
    end;
    C_COND.ATTACK_ROLL_ATT: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.BLESS); FxEngine.TriggerEffect(creature, C_EFFECT.CURSE);
      FxEngine.TriggerEffect(creature, C_EFFECT.BLIND); FxEngine.TriggerEffect(creature, C_EFFECT.BESTOW_CURSE);
      FxEngine.TriggerPrayer(creature); FxEngine.TriggerEffect(creature, C_EFFECT.UNDEAD_SLAYER);
      FxEngine.TriggerEffect(creature, C_EFFECT.FLAME_TONGUE); FxEngine.TriggerEffect(creature, C_EFFECT.GNOME_THAC0);
      FxEngine.TriggerEffect(creature, C_EFFECT.DWARF_THAC0);
    end;
    C_COND.DEFENDER_AC: begin
      { the cough first: its handler recalculates the creature's stats, which SSI's ran last and so threw away the
        Blindness and Shield changes (#717) }
      FxEngine.TriggerEffect(creature, C_EFFECT.STINK_COUGH);
      FxEngine.TriggerEffect(creature, C_EFFECT.BLIND); FxEngine.TriggerEffect(creature, C_EFFECT.SHIELD);
    end;
    C_COND.SAVING_THROW: begin
      FxEngine.TriggerProtection(creature, C_EFFECT.PROT_EVIL, C_EFFECT.PROT_EVIL_10FT);
      FxEngine.TriggerProtection(creature, C_EFFECT.PROT_GOOD, C_EFFECT.PROT_GOOD_10FT);
      FxEngine.TriggerEffect(creature, C_EFFECT.RESIST_COLD); FxEngine.TriggerEffect(creature, C_EFFECT.SHIELD);
      FxEngine.TriggerEffect(creature, C_EFFECT.RESIST_FIRE); FxEngine.TriggerEffect(creature, C_EFFECT.BLIND);
      FxEngine.TriggerEffect(creature, C_EFFECT.BESTOW_CURSE); FxEngine.TriggerPrayer(creature);
      FxEngine.TriggerEffect(creature, C_EFFECT.RING_FIRE_RES);
      FxEngine.TriggerEffect(creature, C_EFFECT.NO_PARA_POISON);
      FxEngine.TriggerEffect(creature, C_EFFECT.NO_CHARM_POISON);
      FxEngine.TriggerEffect(creature, C_EFFECT.CON_PSN_SAVE);
      FxEngine.TriggerEffect(creature, C_EFFECT.CON_SPELL_SAVE);
    end;
    C_COND.HP_ZERO: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.CAN_FIGHT_ON); FxEngine.TriggerEffect(creature, C_EFFECT.TROLL_BURN);
      FxEngine.TriggerEffect(creature, C_EFFECT.GASEOUS); FxEngine.TriggerEffect(creature, C_EFFECT.BLOOD_DRAIN);
      FxEngine.TriggerEffect(creature, C_EFFECT.BITE_HOLD);
    end;
    C_COND.MONSTER_SPECIAL: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.PETRIFY_GAZE); FxEngine.TriggerEffect(creature, C_EFFECT.CHARM_GAZE);
      FxEngine.TriggerEffect(creature, C_EFFECT.DRAGON_BREATH); FxEngine.TriggerEffect(creature, C_EFFECT.ANHKHEG_ACID);
    end;
    C_COND.ACTION_START: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.SILENCE); FxEngine.TriggerEffect(creature, C_EFFECT.STINK_COUGH);
      FxEngine.TriggerEffect(creature, C_EFFECT.BITE_HOLD); FxEngine.TriggerEffect(creature, C_EFFECT.BLOOD_DRAIN);
      FxEngine.TriggerEffect(creature, C_EFFECT.CHARM);
    end;
    C_COND.ATTACK_ROLL_DEF: begin
      { after the d20, which AttackRoll rolls after C_COND.DEFENDER_AC (#789) }
      FxEngine.TriggerProtection(creature, C_EFFECT.PROT_EVIL, C_EFFECT.PROT_EVIL_10FT);
      FxEngine.TriggerProtection(creature, C_EFFECT.PROT_GOOD, C_EFFECT.PROT_GOOD_10FT);
      FxEngine.TriggerEffect(creature, C_EFFECT.INVISIBLE); FxEngine.TriggerEffect(creature, C_EFFECT.DUST_DISAPPEAR);
      FxEngine.TriggerEffect(creature, C_EFFECT.BLINKING); FxEngine.TriggerEffect(creature, C_EFFECT.DWARF_AC_GIANT);
      FxEngine.TriggerEffect(creature, C_EFFECT.GNOME_AC_BUG); FxEngine.TriggerEffect(creature, C_EFFECT.DISPLACED);
    end;
    C_COND.MORALE_CHECK: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.BLESS); FxEngine.TriggerEffect(creature, C_EFFECT.CURSE);
      FxEngine.TriggerEffect(creature, C_EFFECT.CHARM);
    end;
    C_COND.MOVE_ATTACK_RATE: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.HASTED); FxEngine.TriggerEffect(creature, C_EFFECT.SLOWED);
      FxEngine.TriggerEffect(creature, C_EFFECT.IMMOBILE);
    end;
    C_COND.ROUND_END: begin
      FxEngine.TriggerEffect(creature, C_EFFECT.REGEN3); FxEngine.TriggerEffect(creature, C_EFFECT.SPIRIT_HAMMER);
      FxEngine.TriggerEffect(creature, C_EFFECT.CAMOUFLAGE); FxEngine.TriggerEffect(creature, C_EFFECT.RING_INVIS);
      FxEngine.TriggerEffect(creature, C_EFFECT.CHARM);
    end;
  end;
end;

function CloudProof(creature: Types.PCharRecord): Boolean;
var
  effect: Types.PEffectRec;
begin
  CloudProof := CharHlp.HasEffect(creature, C_EFFECT.ANIMATE_DEAD, effect) or
                CharHlp.HasEffect(creature, C_EFFECT.STINK_COUGH, effect) or
                CharHlp.HasEffect(creature, C_EFFECT.NO_PARA_POISON, effect) or
                CharHlp.HasEffect(creature, C_EFFECT.NO_CHARM_POISON, effect);
end;

function CloudSpares(creature: Types.PCharRecord): Boolean;
var
  effect: Types.PEffectRec;
begin
  CloudSpares := (creature^.enabled = 0) or CharHlp.HasEffect(creature, C_EFFECT.HELPLESS, effect) or
                 FxEngine.CloudProof(creature);
end;

procedure ConsiderStinkingCloud(creature: Types.PCharRecord);
var
  effect: Types.PEffectRec;
  terrIdx: Byte;
  crIdx: Byte;
  saved: Boolean;
begin
  if FxEngine.CloudSpares(creature) then Exit;
  CbtMap.ProbeDirection(creature, C_DIR.CENTER, crIdx, terrIdx);
  if terrIdx <> C_TERR.STINK_CLOUD then Exit;
  { save vs. paralyzation, poison and death magic, with the Constitution's poison bonus }
  saved := FxEngine.RollSavingThrow(creature, C_SAVE.PARALYZE, AbilAdj.ConPoisonSave(creature^.conCur));
  if saved then
    CharDisp.PrintNameString(creature, 'is Unaffected', 10, True)
  else begin
    FxEngine.AddEffectWithMessage(creature, C_EFFECT.HELPLESS, Dice.RollDice(1, 4) + 1, 255, False, False,
                                  saved, 'chokes and gags from nausea');
    if CharHlp.HasEffect(creature, C_EFFECT.HELPLESS, effect) then
      FxEngine.CallEffectHandler(C_EFFECT.HELPLESS, creature, effect, False);
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
    node := GameVars.stinkHead;
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

function PrayerStrength(caster: Types.PCharRecord; level: Byte): Byte;
begin
  if level > 15 then
    level := 15;
  PrayerStrength := CharHlp.Team(caster) * C_EFFECT.PRAYER_SIDE + level;
end;

function PrayerSide(effect: Types.PEffectRec): Byte;
begin
  PrayerSide := (effect^.strength and C_EFFECT.PRAYER_SIDE) div C_EFFECT.PRAYER_SIDE;
end;

{ The d20 both attack rolls share: into gAttackRoll (1 misses, 20 becomes 100), then the attacker's
  C_COND.ATTACK_ROLL_ATT effects (none when attacker is nil) and the defender's C_COND.ATTACK_ROLL_DEF. A hit when no
  effect forced a miss and roll + toHit >= sixtyMinusAc. }
function RollToHit(attacker, defender: Types.PCharRecord; toHit: Integer; sixtyMinusAc: Byte): Boolean;
begin
  RollToHit := False;
  GameVars.gAttackAvoided := False;
  GameVars.gAttackRoll := Dice.RollDice(1, 20);
  if GameVars.gAttackRoll > 1 then begin
    if GameVars.gAttackRoll = 20 then GameVars.gAttackRoll := 100;
    if attacker <> nil then
      FxEngine.TriggerEffectsWithCondition(C_COND.ATTACK_ROLL_ATT, attacker);
    FxEngine.TriggerEffectsWithCondition(C_COND.ATTACK_ROLL_DEF, defender);
    if not GameVars.gAttackAvoided and (GameVars.gAttackRoll + toHit >= sixtyMinusAc) then
      RollToHit := True;
  end;
end;

function AttackRollNoAttacker(defender: Types.PCharRecord; sixtyMinusThac0: Byte): Boolean;
begin
  AttackRollNoAttacker := RollToHit(nil, defender, sixtyMinusThac0, defender^.acCur);
end;

function HitBonus(attacker: Types.PCharRecord): Integer;
var
  zmod: ShortInt;
begin
  if attacker^.hostile = 0 then
    zmod := ShortInt(Lo(GameVars.zone1^[C_GBVM.PARTY_HIT_MOD]))
  else
    zmod := ShortInt(Lo(GameVars.zone1^[C_GBVM.MONSTER_HIT_MOD]));
  HitBonus := attacker^.thac0Cur + zmod;
end;

function AttackRoll(attacker, defender: Types.PCharRecord; sixtyMinusAc: Byte): Boolean;
begin
  FxEngine.RemoveInvisibility(attacker);
  AttackRoll := RollToHit(attacker, defender, FxEngine.HitBonus(attacker), sixtyMinusAc);
end;

function RollSavingThrow(creature: Types.PCharRecord; saveType, modifier: ShortInt): Boolean;
begin
  if (saveType < C_SAVE.PARALYZE) or (saveType > C_SAVE.SPELL) then
    saveType := C_SAVE.SPELL;
  gSaveRoll := Dice.RollDice(1, 20);
  case gSaveRoll of
    1: RollSavingThrow := False;
    20: RollSavingThrow := True;
  else begin
    gSaveRoll := gSaveRoll + creature^.saveBonus + modifier;
    gSaveType := saveType;
    FxEngine.TriggerEffectsWithCondition(C_COND.SAVING_THROW, creature);
    if creature^.saves[saveType] <= gSaveRoll then
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
  if effId = C_EFFECT.POISONED then
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
  { a creature that fled (C_STATUS.RUNNING) keeps its hit points }
  if creature^.status <> C_STATUS.RUNNING then
    creature^.hpCur := 0;
  { slot 0: not on the map, so there is no icon to erase }
  if slot > 0 then begin
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    Blit.FlushView;
    GameVars.arenaLoc[slot].size := 0;
  end;
  CbtMap.BuildArenaArrays;
  if CharHlp.EndActions(creature) then
    FxEngine.RemoveEffectsHp0(creature);
end;

procedure RemoveInvisibility(creature: Types.PCharRecord);
var
  effect: Types.PEffectRec;
begin
  while CharHlp.HasEffect(creature, C_EFFECT.INVISIBLE, effect) do
    FxEngine.RemoveEffect(creature, C_EFFECT.INVISIBLE, effect);
end;

function ImageStruck(image: Types.PEffectRec): Boolean;
begin
  ImageStruck := Dice.RollDice(1, image^.strength + 1) > 1;
end;

procedure LoseImage(creature: Types.PCharRecord; image: Types.PEffectRec);
begin
  CharDisp.PrintNameString(creature, 'lost an image', 10, True);
  Dec(image^.strength);
  if image^.strength = 0 then
    FxEngine.RemoveEffect(creature, C_EFFECT.MIRROR_IMAGE, image);
end;

procedure RemoveEffectsHp0(creature: Types.PCharRecord);
const
  { Effects removed by RemoveEffectsHp0 when a creature reaches zero hit points or is put out of play }
  hpZeroEffects: array[1..16] of Byte = (
    { Training/Manual }
    C_EFFECT.TRAIN_MANUAL,
    { Charm }
    C_EFFECT.CHARM,
    { Stinking cloud coughing }
    C_EFFECT.STINK_COUGH,
    { Helpless (nausea) }
    C_EFFECT.HELPLESS,
    { Animate Dead }
    C_EFFECT.ANIMATE_DEAD,
    { Snake Charm }
    C_EFFECT.SNAKE_CHARM,
    { Paralysis (Hold Person) }
    C_EFFECT.PARALYSIS,
    { Sleep }
    C_EFFECT.SLEEP,
    { Dragon Aura }
    C_EFFECT.DRAGON_AURA,
    { Immobile }
    C_EFFECT.IMMOBILE,
    { Troll Regeneration }
    C_EFFECT.TROLL_REGEN,
    { Fight On at 0 HP }
    C_EFFECT.FIGHT_ON,
    { Regeneration }
    C_EFFECT.REGEN3,
    { Spiritual Hammer expiry }
    C_EFFECT.SPIRIT_HAMMER_GONE,
    { Bite-and-Hold }
    C_EFFECT.BITE_HOLD,
    { Blood Drain }
    C_EFFECT.BLOOD_DRAIN);
var
  i: Byte;
begin
  for i := 1 to SizeOf(hpZeroEffects) do
    FxEngine.RemoveEffect(creature, hpZeroEffects[i], nil);
end;

procedure RemoveAiEffects(creature: Types.PCharRecord);
const
  { Effects removed by RemoveAiEffects at the start of CombatAi.CheckMorale }
  aiRoundRemoveEffects: array[1..2] of Byte = (
    { Bite-and-Hold }
    C_EFFECT.BITE_HOLD,
    { Blood Drain }
    C_EFFECT.BLOOD_DRAIN);
var
  i: Byte;
begin
  for i := 1 to SizeOf(aiRoundRemoveEffects) do
    FxEngine.RemoveEffect(creature, aiRoundRemoveEffects[i], nil);
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
    effStrength := AbilAdj.StrengthModifier(baseStr, excStr) + $80;
  end else begin
    found := nil;
    p := creature^.effectsAddr;
    while (p <> nil) and (found = nil) do begin
      if ((p^.id = C_EFFECT.ENLARGE) or (p^.id = C_EFFECT.STRENGTH)) and
          (Types.PEffectRec(p)^.strength < $80) then
        found := p;
      p := p^.next;
    end;
    if found <> nil then begin
      enc := AbilAdj.StrengthModifier(oldBase, oldExc);
      AbilAdj.StrengthEffectToStrength(found, oldBase, oldExc);
      Types.PEffectRec(found)^.strength := enc + $80;
    end;
    creature^.strCur := AbilAdj.ClampScore(Integer(baseStr) - loss);
    creature^.strExc := excStr;
    CharHlp.RecalcStats(creature);
    effStrength := AbilAdj.StrengthModifier(oldBase, oldExc);
    AdjustForNewStrength := True;
  end;
end;

{ InflictNonWeaponDamage and InflictItemShock: shockItem nil prints the "takes n points of damage" line, else the item's
  shock message. }
procedure NonWeaponDamage(creature: Types.PCharRecord; damage, saveReduction: Byte; saved: Boolean;
                          shockItem: Types.PItemRec);
var
  { the longest is 'takes 255 points of damage from Electricity' }
  s: String[43];
begin
  if creature^.status in [C_STATUS.DEAD, C_STATUS.STONED, C_STATUS.GONE] then Exit;
  GameVars.pendingDamage := damage;
  FxEngine.TriggerEffectsWithCondition(C_COND.NONWEAPON_DAMAGE, creature);
  if saved then
    case saveReduction of
      1: GameVars.pendingDamage := 0;
      2: GameVars.pendingDamage := GameVars.pendingDamage div 2;
    end;
  if GameVars.pendingDamage > 0 then begin
    s := 'takes ' + StrUtil.Count(GameVars.pendingDamage, 'point', 'points') + ' of damage ';
    case GameVars.elementMask and not C_EFFECT.ELEM_MAGIC of
      C_EFFECT.ELEM_FIRE: s := s + 'from Fire';
      C_EFFECT.ELEM_COLD: s := s + 'from Cold';
      C_EFFECT.ELEM_ELEC: s := s + 'from Electricity';
      C_EFFECT.ELEM_ACID: s := s + 'from Acid';
      C_EFFECT.ELEM_POISON: s := s + 'from poison';
      C_EFFECT.ELEM_DISEASE: s := s + 'from disease';
      C_EFFECT.ELEM_BLOOD: s := s + 'from blood drain';
    end;
    { magic bit alone, or no element bit at all }
    if (GameVars.elementMask and C_EFFECT.ELEM_MAGIC) = GameVars.elementMask then
      s := s + 'from Magic';
    if shockItem = nil then
      CharDisp.PrintNameStringAnim(creature, False, s)
    else begin
      { the item and the creature in green, the rest in white (#637); the item label ends in a space }
      CharHlp.ItemLabel(shockItem, False);
      CharDisp.MessageText(shockItem^.name, LightGreen, True);
      CharDisp.MessageText('shocks ', White, False);
      CharDisp.MessageText(creature^.name, LightGreen, False);
      CharDisp.MessageText(' for ' + StrUtil.NumStr(GameVars.pendingDamage) + ' damage, and has been unequipped.',
                           White, False);
      CharDisp.MessageWait;
    end;
    CharHlp.InflictDamage(creature, GameVars.pendingDamage);
    if GameVars.ifcState = C_IFC.COMBAT then begin
      creature^.combatAddr^.castAllowed := 0;
      if creature^.combatAddr^.spellCast > 0 then begin
        CharDisp.PrintNameString(creature, 'lost a spell', 12, True);
        CharHlp.RemoveSpell(creature, creature^.combatAddr^.spellCast);
        creature^.combatAddr^.spellCast := 0;
      end;
    end;
    if creature^.enabled = 0 then begin
      s := 'Goes Down';
      if creature^.status = C_STATUS.DYING then
        s := s + ', and is Dying';
      { 6..8 = dead, stoned, gone }
      if creature^.status in [C_STATUS.DEAD, C_STATUS.STONED, C_STATUS.GONE] then
        s := 'is killed';
      CharDisp.PrintNameString(creature, s, GameVars.curRow + 1, False);
      if GameVars.ifcState <> C_IFC.COMBAT then
        TextRend.PauseOnly
      else begin
        FxEngine.RemoveEffectsHp0(creature);
        FxEngine.TriggerEffectsWithCondition(C_COND.HP_ZERO, creature);
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
  DiseaseImmune := (creature <> nil) and ((CharHlp.GetClassLevel(creature, C_LEVEL.PALADIN_BIT) > 0)) and
    (effId in C_EFFECT.DISEASES);
end;

function EffectImmune(creature: Types.PCharRecord; effId: Byte): Boolean;
begin
  GameVars.pendingEffectId := effId;
  FxEngine.TriggerEffectsWithCondition(C_COND.EFFECT_IMMUNITY, creature);
  EffectImmune := (GameVars.pendingEffectId = 0) or FxEngine.DiseaseImmune(creature, effId);
  GameVars.pendingEffectId := 0;
end;

procedure AddEffectWithMessage(creature: Types.PCharRecord; effId: Byte; minutes: Word; strength: Byte; onRemove,
                               saveNegates, saved: Boolean; msg: Types.TStr40);
var
  effect: Types.PEffectRec;
begin
  if FxEngine.EffectImmune(creature, effId) or (saved and saveNegates) then
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
  if not (creature^.status in [C_STATUS.OKAY, C_STATUS.ANIMATED, C_STATUS.UNCONSCIOUS,
                               C_STATUS.DYING]) then Exit;
  if (creature^.hpCur >= creature^.hpMax) or not bypassRot then begin
    { 50 = mummy rot }
    if CharHlp.HasEffect(creature, C_EFFECT.ROT_NO_HEAL, effect) then Exit;
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
  Stats.Healed(GameVars.curChar, creature, creature^.hpCur - hpBefore, False);
  if creature^.enabled = 0 then begin
    if creature^.status = C_STATUS.DYING then
      creature^.status := C_STATUS.UNCONSCIOUS;
    if (creature^.status = C_STATUS.UNCONSCIOUS) and (GameVars.ifcState <> C_IFC.COMBAT) then
      FxEngine.CallEffectHandler(C_EFFECT.HEAL_WAKE, creature, nil, True);
  end;
  RestoreHitPoints := True;
end;

function ReviveDeadCreature(creature: Types.PCharRecord; hp: Byte): Boolean;
var
  s: Types.TStr40;
begin
  if CbtMap.IsValidCreatureLoc(creature, CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), True)
  then begin
    creature^.status := C_STATUS.OKAY;
    creature^.enabled := 1;
    creature^.hpCur := hp;
    if GameVars.ifcState = C_IFC.COMBAT then
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
  p: Types.PEffectRec;
begin
  p := creature^.effectsAddr;
  while (p <> nil) and not (p^.id in C_EFFECT.DISEASES) do
    p := p^.next;
  HasDisease := p <> nil;
end;

{ Remove every node of effId from the creature; True when there was one. }
function RemoveAll(creature: Types.PCharRecord; effId: Byte): Boolean;
var
  effect: Types.PEffectRec;
  found: Boolean;
begin
  found := False;
  while CharHlp.HasEffect(creature, effId, effect) do begin
    FxEngine.RemoveEffect(creature, effId, effect);
    found := True;
  end;
  RemoveAll := found;
end;

function RemoveDiseases(creature: Types.PCharRecord): Boolean;
var
  cured: Boolean;
  effect: Types.PEffectRec;
begin
  GameVars.effectLock := 1;
  cured := FxEngine.RemoveAll(creature, C_EFFECT.DISEASED);
  if FxEngine.RemoveAll(creature, C_EFFECT.DISEASE_STR) then begin
    cured := True;
    if CharHlp.HasEffect(creature, C_EFFECT.HELPLESS, effect) then
      FxEngine.RemoveEffect(creature, C_EFFECT.HELPLESS, effect);
  end;
  if FxEngine.RemoveAll(creature, C_EFFECT.DISEASE_HP) then
    cured := True;
  if FxEngine.RemoveAll(creature, C_EFFECT.ROT_NO_HEAL) then
    cured := True;
  if FxEngine.RemoveAll(creature, C_EFFECT.MUMMY_ROT) then
    cured := True;
  GameVars.effectLock := 0;
  RemoveDiseases := cured;
end;

function FriendsEndCha(cha, strength: Byte): Byte;
begin
  if strength and C_EFFECT.FRIENDS_BONUS <> 0 then
    FriendsEndCha := AbilAdj.ClampScore(Integer(cha) - (strength and not C_EFFECT.FRIENDS_BONUS))
  else
    FriendsEndCha := AbilAdj.ClampScore(strength);
end;

procedure ToggleReadyItem(item: Types.PItemRec);
var
  hasSpecial: Boolean;
  err: Byte;
  slot: ShortInt;
  creature: Types.PCharRecord;
begin
  hasSpecial := item^.special > $7F;
  creature := GameVars.curChar;
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
      C_EQUIP.WEAPON..C_EQUIP.BOOTS:
        if creature^.equipped[slot] <> nil then
          err := 2;
      C_EQUIP.RING1:
        if creature^.equipped[C_EQUIP.RING2] <> nil then
          { second ring slot already in use }
          err := 2;
    end;
    { arrows }
    if item^.itemType = C_ITEM.ARROW then
      if creature^.equipped[C_EQUIP.ARROW] <> nil then begin
        err := 2;
        slot := C_EQUIP.ARROW;
      end;
    { quarrels }
    if item^.itemType = C_ITEM.QUARREL then
      if creature^.equipped[C_EQUIP.BOLT] <> nil then begin
        err := 2;
        slot := C_EQUIP.BOLT;
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
      3: if (GameVars.ifcState <> C_IFC.COMBAT) or (creature^.quickfight = 0) then
           CharDisp.PrintBottomLine('Your hands are full!');
    end;
  end;
end;

{ Age every timed effect (duration > 0 minutes) of each creature by count units of tUnit (ten segments to the minute),
  in steps of at most 10 minutes, removing those that run out. Outside camp every creature is visited; in camp only
  those effFlags marks as still holding timed effects. Each step first ages the effects and notes the expiring
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
  if GameVars.ifcState <> C_IFC.CAMPING then
    FillChar(effFlags, SizeOf(effFlags), 1)
  else begin
    found := False;
    i := 1;
    repeat
      if effFlags[i] <> 0 then found := True;
      Inc(i);
    until found or (i > GameVars.zone1^[C_GBVM.PARTY_SIZE]);
    if not found then Exit;
  end;
  total := count;
  u := tUnit;
  if u = C_TIME.SEGMENTS then
    total := total div GameDefs.unitScale[C_TIME.SEGMENTS];
  while u > 1 do begin
    total := GameDefs.unitScale[Pred(u)] * total;
    u := Pred(u);
  end;
  while total > 0 do begin
    if total > 10 then step := 10 else step := total;
    i := 1;
    cur := GameVars.creatureList;
    while cur <> nil do begin
      if (i > SizeOf(effFlags)) or (effFlags[i] <> 0) then begin
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
        if i <= SizeOf(effFlags) then
          if again then effFlags[i] := 1 else effFlags[i] := 0;
      end;
      Inc(i);
      cur := cur^.nextCharAddr;
    end;
    if total > 10 then Dec(total, 10) else total := 0;
  end;
end;

procedure AdvanceTime(amount: Byte; tUnit: ShortInt);
var
  time: Types.TClock;
  i: ShortInt;
  j: Byte;
begin
  for i := 0 to 6 do
    time[i] := GameVars.zone0^.words[C_GBVM.CLOCK + i];
  for j := 1 to amount do begin
    Inc(time[tUnit]);
    Clock.ValidateClock(time, True);
  end;
  for i := 0 to 6 do
    GameVars.zone0^.words[C_GBVM.CLOCK + i] := time[i];
  FxEngine.TimeOutEffects(amount, tUnit);
end;

function HoldTarget(creature: Types.PCharRecord; p: Pointer; removed: Boolean; effId: Byte;
                    var released: Boolean): Types.PCharRecord;
var
  held: Types.PEffectRec;
begin
  HoldTarget := nil;
  released := False;
  if (Types.PEffectRec(p)^.strength = 0) or (Types.PEffectRec(p)^.strength > GameVars.arenaCount) or
      (Types.PEffectRec(p)^.strength > Types.ARENA_SLOTS) then begin
    if not removed then begin
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, effId, p);
    end;
    Exit;
  end;
  GameVars.otherCreatureCurrentPtr := GameVars.creatureArr[Types.PEffectRec(p)^.strength];
  if removed or (creature^.enabled = 0) or (GameVars.otherCreatureCurrentPtr^.enabled = 0)
     or not CharHlp.HasEffect(GameVars.otherCreatureCurrentPtr, C_EFFECT.IMMOBILE, held) then begin
    FxEngine.RemoveEffect(GameVars.otherCreatureCurrentPtr, C_EFFECT.IMMOBILE, nil);
    if not removed then begin
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, effId, p);
    end;
    released := True;
  end else
    HoldTarget := GameVars.otherCreatureCurrentPtr;
end;

begin
  { Turbo Pascal clears no variable }
  FillChar(effFlags, SizeOf(effFlags), 0);
  gSaveRoll := 0;
  gSaveType := 0;
end.
