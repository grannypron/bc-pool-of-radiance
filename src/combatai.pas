{ Combat AI: movement, equipment, spell selection, morale and automatic actions. }

{$O+,F+}
unit CombatAi;

interface

uses Types, C_Item, C_Npc, C_Terr, C_Cond, GDConsts, GDVars, Crt, MenuCore, CbtActs,
  ViewChar, FxEngine, C_Effect, C_Equip, C_Class, C_Status, C_Gbvm, C_Dir, C_Spell, C_Keys;

{ Run one AI-controlled turn for creature: check the keyboard (Space returns the party to manual control), reroll the
  approach pattern, check morale, then try in order an item's spell effect, a spell readied earlier
  (combatAddr^.spellCast), turning undead and a new spell, and otherwise re-equip and run the move/attack loop. }
procedure CombatAiControl(creature: Types.PCharRecord);

implementation

function TurnUndeadAI(creature: Types.PCharRecord): Boolean; forward;

function DecideCastSpell(creature: Types.PCharRecord; spell, minPri: Byte): Boolean; forward;

function SelectItemToUse(creature: Types.PCharRecord): Boolean; forward;

function SelectSpellToCast(creature: Types.PCharRecord): Boolean; forward;

function AiCanStep(creature: Types.PCharRecord; attempt, baseDir: Byte; var edge: Boolean): Boolean; forward;

procedure AiMoveStep(creature: Types.PCharRecord); forward;

function AiMoveAttack(creature: Types.PCharRecord): Boolean; forward;

function FinishRound(creature: Types.PCharRecord): Boolean; forward;

function CheckKeystroke(creature: Types.PCharRecord): Boolean; forward;

function CheckMorale(creature: Types.PCharRecord): Boolean; forward;

function CalcWeaponPriority(creature: Types.PCharRecord; item: Types.PItemRec): Byte; forward;

procedure EquipWeaponAndShield(creature: Types.PCharRecord); forward;

procedure CombatAiControl(creature: Types.PCharRecord);
var
  stance: Byte;
  done: Boolean;
begin
  done := CombatAi.CheckKeystroke(creature);
  MenuCore.ClearBottomLine;
  CharHlp.ClearMessageWindow;
  if creature^.enabled = 0 then
    done := CharHlp.EndActions(creature);
  stance := creature^.combatAddr^.aiStance;
  { Reroll when unset, after a sweep pattern or on 1 turn in 4; a 1d8 roll of 8 picks sweep pattern 5..6, else 1..4 }
  if (stance = 0) or (stance > 4) or (FxEngine.RollDice(1, 4) = 1) then begin
    stance := FxEngine.RollDice(1, 8);
    if stance = 8 then
      stance := FxEngine.RollDice(1, 2) + 4
    else
      stance := FxEngine.RollDice(1, 4);
  end;
  creature^.combatAddr^.aiStance := stance;
  if not done then
    done := CombatAi.CheckMorale(creature);
  if (creature^.combatAddr^.fleeing <> 0) and (creature^.combatAddr^.turned = 0) then
    CharHlp.PrintNameString(creature, 'flees in panic', 10, True);
  if done then
    Exit;
  if CombatAi.SelectItemToUse(creature) then
    done := CharHlp.EndActions(creature)
  else if creature^.combatAddr^.spellCast > 0 then begin
    { A spell readied earlier resolves this segment. Combat's manual path zeroes spellCast before casting; here
      CharHlp.EndActions below does it }
    Magic.CastSpellNC(creature^.combatAddr^.spellCast, True, True, done);
    done := CharHlp.EndActions(creature);
  end else if CombatAi.TurnUndeadAI(creature) then
    done := CharHlp.EndActions(creature)
  else if CombatAi.SelectSpellToCast(creature) then
    done := True
  else begin
    CombatAi.EquipWeaponAndShield(creature);
    done := CombatAi.CheckKeystroke(creature);
    while not done do
      if CbtActs.AcquireTarget(creature, 255, 1, 0)
         and (creature^.combatAddr^.initiative > 0) then
        done := CombatAi.AiMoveAttack(creature)
      else
        done := CombatAi.FinishRound(creature);
  end;
end;

{ Turn undead whenever creature is a cleric that has not tried this combat and a turnable undead target exists. }
function TurnUndeadAI(creature: Types.PCharRecord): Boolean;
var
  tgt: Pointer;
begin
  if (creature^.combatAddr^.usedTurnUndead = 0)
     and (creature^.classLevels[C_Class.LEVEL_CLERIC] > 0)
     and CbtActs.FindTurnUndeadTarget(creature, tgt) then begin
    TurnUndeadAI := True;
    CbtActs.CombatTurnUndead(creature);
  end else
    TurnUndeadAI := False;
end;

{ Should the AI use spell (memorized, or an item's spell effect)? Its aiPriority must be at least minPri. Non-offensive
  spells other than Cure Light Wounds always qualify, as does Cure Light Wounds with a cure target. Everything else,
  including Cure Light Wounds with no cure target, needs an enemy within Magic.CalcSpellRange and, for an area spell
  (aiRadius > 0), no candidate target whose surroundings include a non-enemy. }
function DecideCastSpell(creature: Types.PCharRecord; spell, minPri: Byte): Boolean;
var
  tgt: Pointer;
  cnt: Byte;
  j: Byte;

  { Would an area spell aimed at cell (x, y) catch anyone not on GDVars.curChar's enemy team? Rebuilds the target list
    around the aim point with the spell's aiRadius as the walk budget }
  function AreaHitsNonEnemy(x, y: ShortInt; spell: Byte): Boolean;
  var
    i: Byte;
  begin
    AreaHitsNonEnemy := False;
    Pathing.BuildTargetList(x, y, GDConsts.spellTable[spell].aiRadius, 255, 1, GDVars.arenaPtr);
    for i := 1 to GDVars.targetCount do
      if GDVars.creatureArr[GDVars.targetList[i].idx]^.hostile
         <> CharHlp.EnemyTeam(GDVars.curChar) then
        AreaHitsNonEnemy := True;
  end;

begin
  DecideCastSpell := False;
  if GDConsts.spellTable[spell].aiPriority < minPri then
    Exit;
  if ((spell <> C_Spell.CURE_LIGHT_WOUNDS) and (GDConsts.spellTable[spell].offensive = 0))
     or ((spell = C_Spell.CURE_LIGHT_WOUNDS) and CbtActs.FindCureTarget(creature, tgt)) then
    { buff or heal: no aiming }
    DecideCastSpell := True
  else begin
    cnt := CharHlp.CountTargets(creature, Magic.CalcSpellRange(spell));
    if cnt > 0 then
      if GDConsts.spellTable[spell].aiRadius = 0 then
        DecideCastSpell := True
      else begin
        { Reject the spell if any candidate aim point would also catch a non-enemy }
        for j := 1 to cnt do
          if AreaHitsNonEnemy(GDVars.arenaLoc[GDVars.dsPotentialTargetCreature[j]].x,
                              GDVars.arenaLoc[GDVars.dsPotentialTargetCreature[j]].y, spell) then
            Exit;
        DecideCastSpell := True;
      end;
  end;
end;

{ Pick an equipped item whose spell effect the AI should use; needs itemUseAllowed, a remaining enemy team and no
  anti-magic. Over 1d7 passes the minimum aiPriority drops from 7, and the first equipped item that is not readable, has
  special < $80 and has an effect DecideCastSpell accepts is used through ViewChar.UseItem. }
function SelectItemToUse(creature: Types.PCharRecord): Boolean;
var
  lowPri: Byte;
  roll: Byte;
  i: Byte;
  pad1: Integer;
  slot: Byte;
  effect: Byte;
  pad2: Pointer;
  item: Types.PItemRec;
  chosen: Types.PItemRec;
  used: Boolean;
begin
  SelectItemToUse := False;
  chosen := nil;
  lowPri := 7;
  roll := FxEngine.RollDice(1, 7);
  if (creature^.combatAddr^.itemUseAllowed <> 0)
     and (GDVars.teamCount[CharHlp.EnemyTeam(creature)] > 0)
     and (GDVars.zone0^.antimagic = 0) then
    for i := 1 to roll do begin
      item := creature^.itemsAddr;
      while (item <> nil) and (chosen = nil) do begin
        effect := item^.effect;
        slot := GDVars.baseItems[item^.itemType].slot;
        if (not Magic.ItemReadable(item))
           and (item^.special < $80)
           and (item^.equipped <> 0)
           and (effect > 0) then begin
          { Item effects 80..90 map to spell entries 57..67; 56 is the last real spell id }
          if effect > 56 then
            effect := effect - 23;
          if CombatAi.DecideCastSpell(creature, effect, lowPri) then
            chosen := item;
        end;
        item := item^.next;
      end;
      Dec(lowPri);
    end;
  if chosen <> nil then begin
    ViewChar.UseItem(chosen, used);
    SelectItemToUse := True;
  end;
end;

{ Choose a spell for an NPC, or for a PC while quick magic (Alt-M) is on, when an enemy team remains. The list holds
  every nonzero memorizedSpells entry if castAllowed is set, including ones with bit 7 set (still being memorized). Over
  1d7 passes the minimum aiPriority drops from 7, with three random picks per pass; the first spell DecideCastSpell
  accepts goes to CbtActs.CastSpellCombat, whose result is returned. }
function SelectSpellToCast(creature: Types.PCharRecord): Boolean;
var
  list: array[0..20] of Byte;
  pad: Pointer;
  lowPri: Byte;
  roll: Byte;
  ext: Boolean;
  tries: Byte;
  inner: Byte;
  count: Byte;
  k: Byte;
  spell: Byte;
  chosen: Byte;
begin
  count := 0;
  if creature^.combatAddr^.castAllowed <> 0 then
    for k := 0 to SizeOf(creature^.memorizedSpells) div SizeOf(creature^.memorizedSpells[0]) - 1 do
      if creature^.memorizedSpells[k] > 0 then begin
        list[count] := creature^.memorizedSpells[k];
        Inc(count);
      end;
  chosen := 0;
  lowPri := 7;
  roll := FxEngine.RollDice(1, 7);
  tries := 1;
  if count > 0 then
    { C_Npc.FLAG set }
    if (creature^.npc > $7F) or GDVars.quickMagic then
      if GDVars.teamCount[CharHlp.EnemyTeam(creature)] > 0 then
        while (tries <= roll) and (chosen = 0) do begin
          inner := 1;
          { three picks per pass }
          while (inner < 4) and (chosen = 0) do begin
            k := FxEngine.RollDice(1, count) - 1;
            spell := list[k];
            if CombatAi.DecideCastSpell(creature, spell, lowPri) then
              chosen := spell;
            Inc(inner);
          end;
          Dec(lowPri);
          Inc(tries);
        end;
  if chosen > 0 then
    CbtActs.CastSpellCombat(chosen, 1, ext)
  else
    ext := False;
  SelectSpellToCast := ext;
end;

{ Can creature step in direction baseDir + aiDirOffsets[aiStance, attempt]? Off the map sets edge and fails, and an
  occupied cell fails. The step costs 2 (orthogonal) or 3 (diagonal) times the terrain cost and must fit in the
  remaining movement. Stinking Cloud is avoided unless the creature has C_Effect.ANIMATE_DEAD, C_Effect.STINK_COUGH,
  C_Effect.NO_PARA_POISON or C_Effect.NO_CHARM_POISON. }
function AiCanStep(creature: Types.PCharRecord; attempt, baseDir: Byte; var edge: Boolean): Boolean;
var
  effect: Types.PEffectRec;
  dirAdj: Byte;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  stepCost: Byte;
begin
  edge := False;
  AiCanStep := False;
  dirAdj := GDConsts.aiDirOffsets[creature^.combatAddr^.aiStance, attempt];
  dir := (baseDir + dirAdj) mod 8;
  CbtMap.ProbeDirection(creature, dir, crIdx, terrIdx);
  if terrIdx = 0 then begin
    { off the map: flee chance }
    edge := True;
    Exit;
  end;
  if crIdx <> 0 then
    { a creature blocks the cell }
    Exit;
  if GDConsts.terrainInfo[terrIdx].cost >= creature^.combatAddr^.movement then
    Exit;
  stepCost := 2;
  { diagonal: doubled metric 3 }
  if Odd(dir) then
    stepCost := 3;
  stepCost := stepCost * GDConsts.terrainInfo[terrIdx].cost;
  if terrIdx = C_Terr.STINK_CLOUD then
    if (not CharHlp.HasEffect(creature, C_Effect.ANIMATE_DEAD, effect)) and
        (not CharHlp.HasEffect(creature, C_Effect.STINK_COUGH, effect))
       and (not CharHlp.HasEffect(creature, C_Effect.NO_PARA_POISON, effect))
       and (not CharHlp.HasEffect(creature, C_Effect.NO_CHARM_POISON, effect)) then
      stepCost := creature^.combatAddr^.movement + 1;
  if creature^.combatAddr^.movement >= stepCost then
    AiCanStep := True;
end;

{ One AI movement step: toward the locked target (or in the flee direction), with aiDirOffsets supplying up to five
  fallback directions, and oscillation detection through lastMoveDir and stuckCount }
procedure AiMoveStep(creature: Types.PCharRecord);
var
  dir: Byte;
  adjDir: Byte;
  attempt: Byte;
  edge: Boolean;
  done: Boolean;
begin
  TextRend.DisplayString(0, 24, LightGreen,
                         'Move/Attack, Move Left = ' + CharHlp.ByteToString(creature^.combatAddr^.movement div 2) +
                           ' ');
  if CombatAi.CheckKeystroke(creature) then
    Exit;
  { A mage that is not fleeing does not walk }
  if (creature^.combatAddr^.movement div 2 > 0)
     and (creature^.combatAddr^.initiative > 0)
     and ((creature^.combatAddr^.fleeing <> 0) or (creature^.charClass <> C_Class.MAGE)) then begin
    if creature^.combatAddr^.fleeing = 0 then
      dir := CbtActs.DirTowardTarget(creature, creature^.combatAddr^.other)
    else begin
      creature^.combatAddr^.aiStance := FxEngine.RollDice(1, 2);
      { Hostiles flee along the party's facing (DIR_* 0, 2, 4, 6). Note: north gives 7 (NW) and south gives 3 (SE), so
        the result is not always a cardinal direction. }
      dir := GDVars.gFacing - Word((GDVars.gFacing + 2) mod 4) div 2;
      if creature^.hostile = 0 then
        { allies flee the other way }
        dir := dir + 4;
      dir := dir mod 8;
    end;
    edge := False;
    done := False;
    attempt := 1;
    while (attempt < 6) and (not done)
          and (not CombatAi.AiCanStep(creature, attempt, dir, edge)) do
      if (creature^.combatAddr^.fleeing <> 0) and edge then
        done := CbtActs.CombatFleeAttempt(creature)
      else
        Inc(attempt);
    if done then
    { fled off the map }
    begin
      creature^.combatAddr^.movement := 0;
      creature^.combatAddr^.fleeing := 0;
      done := CharHlp.EndActions(creature);
    end else begin
      adjDir := (dir + GDConsts.aiDirOffsets[creature^.combatAddr^.aiStance, attempt])
                mod 8;
      { nothing walkable }
      if (attempt = 6)
         { reversing }
         or (GDVars.lastMoveDir = (adjDir + 4) mod 8) then begin
        Inc(GDVars.stuckCount);
        creature^.combatAddr^.aiStance := creature^.combatAddr^.aiStance mod 6 + 1;
        if GDVars.stuckCount > 1 then begin
          creature^.combatAddr^.other := nil;
          if GDVars.stuckCount > 2 then begin
            creature^.combatAddr^.movement := 0;
            done := True;
          end else if not CbtActs.AcquireTarget(creature, 255, 1, 0) then
            done := CombatAi.FinishRound(creature);
        end;
      end;
      if attempt < 6 then
        GDVars.lastMoveDir := adjDir
      else
        done := True;
    end;
    { flee and step paths rejoin }
    if not done then begin
      CbtMap.SetCreatureFacing(creature, adjDir, 0, 0);
      CbtActs.MoveOpportunityAttacks(creature, creature^.combatAddr^.direction);
      if creature^.enabled = 0 then
        done := CharHlp.EndActions(creature)
      else begin
        CbtActs.CombatMoveCreature(creature, creature^.combatAddr^.direction);
        if creature^.enabled = 0 then
          done := CharHlp.EndActions(creature);
        FxEngine.ConsiderStinkingCloud(creature);
      end;
    end;
  end else
    done := CombatAi.FinishRound(creature);
end;

{ The AI's move/attack loop. Returns True when the creature can no longer act. }
function AiMoveAttack(creature: Types.PCharRecord): Boolean;
var
  done: Boolean;
  inRange: Boolean;
  canAct: Boolean;
  weaponRange: Byte;
  range: Word;
  cnt: Byte;
  pick: Byte;
  weapon: Types.PItemRec;
  target: Types.PCharRecord;
  tx: ShortInt;
  ty: ShortInt;
  loopCount: Byte;
begin
  GDVars.lastMoveDir := C_Dir.CENTER;
  GDVars.stuckCount := 0;
  GDVars.unidentified01 := 0;
  loopCount := 0;
  canAct := True;
  done := False;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MONSTER_SPECIAL, creature);
  if creature^.combatAddr^.initiative = 0 then
    canAct := False;
  while (not done) and canAct do begin
    { A fleeing creature spends all its remaining movement. fleeing is tested only before the inner loop starts. }
    if creature^.combatAddr^.fleeing <> 0 then
      while (creature^.combatAddr^.movement > 0)
            and (creature^.combatAddr^.initiative > 0)
            and (creature^.combatAddr^.initiative < 20) do
        CombatAi.AiMoveStep(creature);
    if (creature^.combatAddr^.initiative = 0)
       or (creature^.combatAddr^.initiative = 20) then
      canAct := False
    else
      done := False;
    if (not done) and canAct then begin
      Inc(loopCount);
      { runaway-turn guard }
      if loopCount > 20 then begin
        done := True;
        canAct := CombatAi.FinishRound(creature) = False;
      end;
      inRange := False;
      weaponRange := 1;
      if creature^.equipped[C_Equip.WEAPON] <> nil then
        weaponRange := GDVars.baseItems[creature^.equipped[C_Equip.WEAPON]^.itemType].range - 1;
      if (weaponRange = 0) or (weaponRange = 255) then
        weaponRange := 1;
      { Note: other may be nil, and is dereferenced before the nil check below. }
      target := creature^.combatAddr^.other;
      if (target^.enabled = 0) or (target^.hostile = 0) then
        target := nil;
      if target <> nil then
        if CbtActs.CanAttackTarget(creature, target) then begin
          tx := CbtMap.CombatCellX(target);
          ty := CbtMap.CombatCellY(target);
          range := weaponRange;
          if Pathing.WalkLine(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), tx, ty, range,
                              GDVars.arenaPtr) then
            if range div 2 <= weaponRange then
              inRange := True;
        end;
      if not inRange then begin
        cnt := CharHlp.CountTargets(creature, weaponRange);
        if cnt = 0 then begin
          if CbtActs.AcquireTarget(creature, 255, 0, 0) then
            { approach }
            CombatAi.AiMoveStep(creature)
          else
            done := CombatAi.FinishRound(creature);
        end else begin
          pick := FxEngine.RollDice(1, cnt);
          target := GDVars.creatureArr[GDVars.dsPotentialTargetCreature[pick]];
          if CharHlp.HasRangedWeapon(creature)
             and (not CharHlp.HasThrowableWeapon(creature))
             and (CharHlp.CountTargets(creature, 1) > 0) then begin
            { pure missile weapon with an enemy adjacent: re-equip }
            CombatAi.EquipWeaponAndShield(creature);
            done := True;
          end else if (CharHlp.CalcDistance(creature, target) = 1)
                  or CbtActs.CanAttackTarget(creature, target) then
            inRange := True;
        end;
      end;
      if inRange then
        CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 2,
                          CbtActs.DirTowardTarget(creature, target));
      if inRange then begin
        if CbtActs.SweepAttempt(creature, target) then
          done := CharHlp.EndActions(creature)
        else begin
          CbtActs.NoteAttackDirection(creature, target);
          weapon := nil;
          if CharHlp.HasRangedWeapon(creature) then begin
            inRange := CharHlp.FindDamagingRangedWeapon(creature, weapon);
            if CharHlp.HasThrowableWeapon(creature) then
              if CharHlp.CalcDistance(creature, target) = 1 then
                { adjacent: melee the throwable }
                weapon := nil;
          end;
          CbtActs.CombatAttack(creature, target, False, weapon, done);
          if done then
            canAct := False
          else if target^.enabled = 0 then
            done := True;
        end;
      end;
    end;
  end;
  AiMoveAttack := canAct = False;
end;

{ End creature's round: helpless, ranged-armed or out-of-initiative creatures just end their actions, others Guard.
  Always returns True. }
function FinishRound(creature: Types.PCharRecord): Boolean;
begin
  CharHlp.ClearMessageWindow;
  if CharHlp.IsHelpless(creature)
     or CharHlp.HasRangedWeapon(creature)
     or (creature^.combatAddr^.initiative = 0) then
    FinishRound := CharHlp.EndActions(creature)
  else
    FinishRound := CharHlp.Guard(creature);
end;

{ Handle a key pressed during AI turns: Alt-M toggles quick magic, Space returns every non-NPC, non-animated creature to
  manual control (True when creature itself is now manual), Alt-X runs the STING victory cheat. Note: the case tests
  the key whether or not the extended-key prefix came first, so an unprefixed '2' also toggles quick magic and an
  unprefixed '-' also runs the STING cheat. }
function CheckKeystroke(creature: Types.PCharRecord): Boolean;
var
  p: Types.PCharRecord;
  ch: Char;
begin
  CheckKeystroke := False;
  if KeyPressed then begin
    ch := GameIo.ReadGameKey;
    if ch = #0 then
      { this second call can consume later pending bytes too }
      ch := GameIo.ReadGameKey;
    case ch of
      C_Keys.ALT_M:
        begin
          GDVars.quickMagic := GDVars.quickMagic = False;
          if GDVars.quickMagic then
            CharHlp.PrintBottomLine('Magic On')
          else
            CharHlp.PrintBottomLine('Magic Off');
        end;
      { Space: everyone manual }
      ' ':
        begin
          p := GDVars.creatureList;
          while p <> nil do begin
            { C_Npc.FLAG clear }
            if (p^.npc < C_Npc.FLAG) and (p^.status <> C_Status.ANIMATED) then
              p^.quickfight := 0;
            p := p^.nextCharAddr;
          end;
          if creature^.quickfight = 0 then begin
            creature^.combatAddr^.initiative := 20;
            CheckKeystroke := True;
          end;
        end;
      { result ignored }
      C_Keys.ALT_X:
        if CbtActs.StingVictoryCheat then
          begin end;
    end;
  end;
end;

{ Check morale against the creature's own HP loss, then, for hostiles only, the group's remaining HP. A failed check
  causes flight if the creature is twice as fast as every enemy; otherwise a creature with Int 6+ surrenders. A turned
  creature is simply forced to flee, and PCs never check. Returns True on surrender. }
function CheckMorale(creature: Types.PCharRecord): Boolean;
var
  enemyMove: Byte;
  moraleSave: Byte;
begin
  CheckMorale := False;
  creature^.combatAddr^.fleeing := 0;
  { Removes C_Effect.BITE_HOLD and C_Effect.BLOOD_DRAIN }
  FxEngine.RemoveAiEffects(creature);
  if creature^.combatAddr^.turned <> 0 then begin
    creature^.combatAddr^.fleeing := 1;
    CharHlp.PrintNameString(creature, 'is forced to flee', 10, True);
    Exit;
  end;
  { C_Npc.FLAG clear }
  if creature^.npc <= $7F then
    { PCs never check morale }
    Exit;
  { packed morale rating }
  GDVars.dsCurrentMorale := (creature^.npc and C_Npc.MORALE_MASK) * 2;
  if GDVars.dsCurrentMorale > 102 then
    { 0 is the fail sentinel: both checks below require morale <> 0 }
    GDVars.dsCurrentMorale := 0;
  { Effects adjust morale here: Bless +5, Curse -5 floored at 0 (so a curse below 5 fails both checks), Charm sets 100
    and flips the creature's side on its first call. Bless and Curse also adjust the attack roll. }
  FxEngine.TriggerEffectsWithCondition(C_Cond.MORALE_CHECK, creature);
  if (GDVars.dsCurrentMorale >= 100 - creature^.hpCur * 100 div creature^.hpMax)
     and (GDVars.dsCurrentMorale <> 0) then
    { own-HP check holds }
    Exit;
  moraleSave := GDVars.dsCurrentMorale;
  GDVars.dsCurrentMorale := GDVars.hostileHpPct;
  { the same effect adjustments, now to the group figure }
  FxEngine.TriggerEffectsWithCondition(C_Cond.MORALE_CHECK, creature);
  if (GDVars.dsCurrentMorale >= 100 - GDVars.zone1^[C_Gbvm.MORALE_THRESHOLD])
     and (GDVars.dsCurrentMorale <> 0)
     and (creature^.hostile <> 0) then
    { group check holds (hostiles) }
    Exit;
  enemyMove := CbtActs.HighestEnemyMovement(creature);
  if enemyMove <= CbtActs.CalcCreatureMovement(creature) div 2 then begin
    { fast enough to get away: flee in panic }
    creature^.combatAddr^.fleeing := 1;
    FxEngine.RemoveEffect(creature, C_Effect.BITE_HOLD, nil);
    FxEngine.RemoveEffect(creature, C_Effect.BLOOD_DRAIN, nil);
  end else if creature^.intCur > 5 then begin
    { Int 6+ creatures give up instead }
    FxEngine.PutOutOfPlayWithStatus(creature, C_Status.UNCONSCIOUS, 'Surrenders');
    CheckMorale := CharHlp.EndActions(creature);
  end;
end;

{ Weapon score for EquipWeaponAndShield: damage dice product, +8 per plus, +2 per damage bonus (holy water against an
  undead target scores 8), launchers +2 per extra shot, one-handed +3. Zero when it would exceed 3 hands, for an aligned
  weapon of another alignment, for the Javelin of Lightning and when cursed. }
function CalcWeaponPriority(creature: Types.PCharRecord; item: Types.PItemRec): Byte;
var
  pri: Byte;
  base: Types.TBaseItemRec;
begin
  base := GDVars.baseItems[item^.itemType];
  pri := base.dmgSmDice * base.dmgSmRolls;
  if item^.plus > 0 then
    pri := pri + item^.plus * 8;
  if base.dmgSmMod > 0 then
    pri := pri + base.dmgSmMod * 2;
  if (item^.itemType = C_Item.HOLY_WATER_VIAL)
     and (creature^.combatAddr^.other <> nil)
     and (creature^.combatAddr^.other^.levelUndead > 0) then
    pri := 8;
  { launcher: +2 per rateOfFire point above 1 }
  if (base.props and C_Item.PROP_FIRES_AMMO) > 0 then
    pri := pri + (base.rateOfFire - 1) * 2;
  if base.hands <= 1 then
    pri := pri + 3;
  if base.hands + creature^.handsEquipped > 3 then
    { not enough hands }
    pri := 0;
  { aligned weapon }
  if item^.special = C_Effect.ALIGNED_WEAPON then
    if (item^.effect and $F) <> creature^.alignment then
      pri := 0;
  { Javelin of Lightning }
  if item^.effect = 83 then
    pri := 0;
  if item^.cursed <> 0 then
    pri := 0;
  CalcWeaponPriority := pri;
end;

{ Re-equip creature: pick the best usable weapon by CalcWeaponPriority (unarmed damage sets the melee bar) and the best
  shield (plus + 1). The ranged pick wins when it beats half the melee score, has ammo, and either is trueRanged or no
  enemy is adjacent. Cursed items are never swapped out. Prints the creature info if anything changed. }
procedure EquipWeaponAndShield(creature: Types.PCharRecord);
var
  bestRanged: Types.PItemRec;
  bestMelee: Types.PItemRec;
  bestShield: Types.PItemRec;
  item: Types.PItemRec;
  ammo: Types.PItemRec;
  bestRangedPri: Byte;
  bestMeleePri: Byte;
  bestShieldPri: Byte;
  pri: Byte;
  itType: Byte;
  props: Byte;
  pad: Byte;
  needSwap: Boolean;
  changed: Boolean;
  trueRanged: Boolean;
  hasAmmo: Boolean;
begin
  { stop counting the current weapon/shield hands }
  if creature^.equipped[C_Equip.WEAPON] <> nil then
    creature^.handsEquipped := creature^.handsEquipped
        - GDVars.baseItems[creature^.equipped[C_Equip.WEAPON]^.itemType].hands;
  if creature^.equipped[C_Equip.SHIELD] <> nil then
    creature^.handsEquipped := creature^.handsEquipped
        - GDVars.baseItems[creature^.equipped[C_Equip.SHIELD]^.itemType].hands;
  bestRanged := nil;
  bestMelee := nil;
  bestShield := nil;
  bestRangedPri := 1;
  bestMeleePri := creature^.unarmedDiceA[1] * creature^.unarmedRollsA[1];
  if creature^.unarmedModA[1] > 0 then
    bestMeleePri := bestMeleePri + creature^.unarmedModA[1] * 2;
  bestShieldPri := 0;
  item := creature^.itemsAddr;
  while item <> nil do begin
    itType := item^.itemType;
    { weapon slot }
    if GDVars.baseItems[itType].slot = C_Equip.WEAPON then
      if (GDVars.baseItems[itType].classMask and creature^.itemLimits) <> 0 then begin
        pri := CombatAi.CalcWeaponPriority(creature, item);
        if ((GDVars.baseItems[itType].props and C_Item.PROP_FIRES_AMMO) <> 0)
           or ((GDVars.baseItems[itType].props and C_Item.PROP_THROWN) <> 0) then
          if pri > bestRangedPri then begin
            bestRanged := item;
            bestRangedPri := pri;
          end;
        if (GDVars.baseItems[itType].props and C_Item.PROP_FIRES_AMMO) = 0 then
          if pri > bestMeleePri then begin
            bestMelee := item;
            bestMeleePri := pri;
          end;
      end;
    { shield slot }
    if GDVars.baseItems[itType].slot = C_Equip.SHIELD then
      if (GDVars.baseItems[itType].classMask and creature^.itemLimits) > 0 then begin
        if item^.plus >= 0 then
          pri := item^.plus + 1
        else
          pri := 0;
        if pri > bestShieldPri then begin
          bestShield := item;
          bestShieldPri := pri;
        end;
      end;
    item := item^.next;
  end;
  { trueRanged: range > 1 and both C_Item.PROPS_THROWABLE bits (thrown, Strength bonus); such a weapon is picked even
    with an enemy adjacent }
  if (bestRanged <> nil)
     and (GDVars.baseItems[bestRanged^.itemType].range > 1)
     and
       ((GDVars.baseItems[bestRanged^.itemType].props and
         C_Item.PROPS_THROWABLE) = C_Item.PROPS_THROWABLE) then
    trueRanged := True
  else
    trueRanged := False;
  hasAmmo := False;
  ammo := nil;
  props := 0;
  if bestRanged <> nil then begin
    props := GDVars.baseItems[bestRanged^.itemType].props;
    if (props and C_Item.PROP_THROWN) <> 0 then
      { thrown: is its own ammo }
      ammo := bestRanged;
    if (props and C_Item.PROP_FIRES_AMMO) <> 0 then begin
      if (props and C_Item.PROP_ARROWS) <> 0 then
        ammo := creature^.equipped[C_Equip.ARROW];
      if (props and C_Item.PROP_QUARRELS) <> 0 then
        ammo := creature^.equipped[C_Equip.BOLT];
    end;
  end;
  { props = $A exactly (C_Item.PROP_FIRES_AMMO + C_Item.PROP_DEX_MISSILE, no arrow, quarrel or thrown bit): a launcher
    with no ammo to look up counts as supplied }
  if (ammo <> nil) or (props = $A) then
    hasAmmo := True;
  { pick the weapon }
  if (bestRanged <> nil)
     and (bestRangedPri > bestMeleePri div 2)
     and hasAmmo
     and (trueRanged or (CharHlp.CountTargets(creature, 1) = 0)) then
    item := bestRanged
  else
    item := bestMelee;
  changed := False;
  needSwap := True;
  if creature^.equipped[C_Equip.WEAPON] <> nil then
    if (creature^.equipped[C_Equip.WEAPON] = item) or (creature^.equipped[C_Equip.WEAPON]^.cursed <> 0) then
      needSwap := False;
  if needSwap then begin
    if creature^.equipped[C_Equip.WEAPON] <> nil then
      ViewChar.ToggleReadyItem(creature^.equipped[C_Equip.WEAPON]);
    CharHlp.RecalcStats(creature);
    if creature^.equipped[C_Equip.SHIELD] <> nil then
      if creature^.equipped[C_Equip.SHIELD]^.cursed = 0 then
        creature^.handsEquipped := creature^.handsEquipped
            - GDVars.baseItems[creature^.equipped[C_Equip.SHIELD]^.itemType].hands;
    if item <> nil then
      ViewChar.ToggleReadyItem(item);
    changed := True;
  end;
  CharHlp.RecalcStats(creature);
  CbtActs.SetCurAttacksX2(creature);
  needSwap := True;
  if creature^.equipped[C_Equip.SHIELD] <> nil then
    if (creature^.equipped[C_Equip.SHIELD] = bestShield)
       or (creature^.equipped[C_Equip.SHIELD]^.cursed <> 0) then
      needSwap := False;
  if creature^.handsEquipped > 2 then begin
    { Over-handed: drop the shield, or the chosen weapon when there is no shield or the shield is cursed }
    if (creature^.equipped[C_Equip.SHIELD] = nil) or
        (creature^.equipped[C_Equip.SHIELD]^.cursed <> 0) then begin
      ViewChar.ToggleReadyItem(item);
      changed := True;
    end else begin
      ViewChar.ToggleReadyItem(creature^.equipped[C_Equip.SHIELD]);
      changed := True;
    end;
  end else if (creature^.handsEquipped < 2) and needSwap then begin
    if creature^.equipped[C_Equip.SHIELD] <> nil then
      ViewChar.ToggleReadyItem(creature^.equipped[C_Equip.SHIELD]);
    CharHlp.RecalcStats(creature);
    if bestShield <> nil then
      ViewChar.ToggleReadyItem(bestShield);
    changed := True;
  end;
  CharHlp.RecalcStats(creature);
  if changed then
    CharHlp.CombatPrintCreatureInfo(creature);
end;

end.
