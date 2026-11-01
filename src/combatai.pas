{ Combat AI: movement, equipment, spell selection, morale and automatic actions. }
{$O+,F+}
{$I COMPILER.INC}
unit CombatAi;

interface

uses Types;

{ Run one AI-controlled turn for creature: check the keyboard (Space returns the party to manual control), reroll the
  approach pattern, check morale, then resolve a spell readied earlier (combatAddr^.spellCast) as the whole action, or
  else try in order an item's spell effect, turning undead and a new spell, and otherwise re-equip and run the
  move/attack loop. }
procedure CombatAiControl(creature: Types.PCharRecord);

{ Alt-M in combat: turn quick magic over and show it on the bottom line: the Quick line (QuickLine) while the player's
  characters fight under Quick, else Magic On or Off. }
procedure ToggleQuickMagic;

{ Space in combat: every creature that comes under the player (CharHlp.ComesUnderPlayer: not an NPC, not animated)
  leaves quick-fight. The combat menu and the AI's key check both call it (#640). }
procedure AllToManual;

{ True when creature's side knows what item is, so the AI may choose by it: the item is identified (unidMask 0), or
  creature is not on the party's side (CharHlp.Team 1), whose monsters know their own gear. The party's AI weighs only
  what the player could see (#1143). }
function KnowsItem(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

{ Weapon score for EquipWeaponAndShield: damage dice product, +8 per plus, +2 per damage bonus (holy water against an
  undead target scores 8), launchers +2 per extra shot, one-handed +3. Zero when it would exceed 3 hands, for an aligned
  weapon of another alignment, for the Javelin of Lightning and when cursed. A weapon creature does not know
  (KnowsItem) is scored as the mundane weapon: no plus, and none of the last three, which only identifying shows
  (#1143). }
function CalcWeaponPriority(creature: Types.PCharRecord; item: Types.PItemRec): Byte;

{ How many creatures spell, cast by creature (the creature acting, GameVars.curChar), would usefully affect now; 0
  when it is not worth casting (#1086, #1087). Cure Light Wounds: 1 with a wounded ally to cure. Any other spell that
  is not offensive, which the AI casts on the caster: 1 while the caster is not under its effect; Resist Fire and
  Resist Cold only once an enemy has been seen doing that element's damage this fight (FxEngine.seenElements), and
  Protection From Normal Missiles only while an enemy has a missile weapon readied. An offensive spell: how many
  CbtActs.BestAim finds it would affect; an area spell needs 2 of them, as a player keeping the spell for the next
  fight would not spend it on one, except Silence, since one silenced caster is what it is for. }
function SpellImpact(creature: Types.PCharRecord; spell: Byte): Byte;

{ True when creature keeps the weapon and shield it holds, which EquipWeaponAndShield then leaves alone: with Allow Gear
  Changes off (GameVars.gearChangesOn), a creature that comes under the player (CharHlp.ComesUnderPlayer). NPCs,
  animated dead and monsters re-equip whatever the setting (#1127). }
function KeepsGear(creature: Types.PCharRecord): Boolean;

procedure EquipWeaponAndShield(creature: Types.PCharRecord);

implementation

uses C_ITEM, C_NPC, C_TERR, C_COND, GameDefs, GameVars, Crt, CbtActs, FxEngine, C_EFFECT, C_EQUIP, C_CLASS, C_STATUS,
  C_GBVM, C_DIR, C_SPELL, C_KEYS, CbtMap, CharHlp, GameIo, Magic, Pathing, TextRend, StrUtil, CharDisp, Dice, Combat,
  ClassCal{$IFDEF FPC}, TpRand{$ENDIF};

const
  { AiMoveAttack's runaway-turn guard allows a pass for each step the creature's movement pays for and this many more,
    for its attacks and changes of target }
  TURN_SLACK = 20;
  { AI step patterns (aiStance 1..6): five direction offsets tried in order, each added to the base direction mod 8 (8 =
    straight ahead, 1/7 = one step clockwise/counterclockwise, 2/6 = two, 3/5 = three, 4 = reverse). Patterns 1..4 are
    kept on three turns out of four; sweep patterns 5..6 are rerolled every turn. }
  aiDirOffsets: array[1..6, 1..5] of Byte = (
    ( 8, 7, 6, 1, 2),
    ( 8, 1, 2, 7, 6),
    ( 7, 1, 8, 6, 2),
    ( 1, 7, 8, 2, 6),
    ( 8, 7, 6, 5, 4),
    ( 8, 1, 2, 3, 4));

var
  { the AI's last step direction (8 = none) }
  lastMoveDir: Byte;
  { direction reversals or exhausted movement searches }
  stuckCount: Byte;
  { QuickLine drew the Quick line on this AI turn: the moves left are not written over it }
  quickShown: Boolean;

{ The bottom line while the player's characters fight under Quick (#665): Quick: On (Space) Magic: On or Off (Alt-M),
  the labels in light magenta and the rest in white, so the keys that leave Quick and toggle its magic are shown. With
  no character of the player's under Quick the line is cleared, and the result is False. }
function QuickLine: Boolean;
var
  p: Types.PCharRecord;
  quick: Boolean;
begin
  quick := False;
  p := GameVars.creatureList;
  while p <> nil do begin
    if (p^.quickfight <> 0) and CharHlp.ComesUnderPlayer(p) then
      quick := True;
    p := p^.nextCharAddr;
  end;
  TextRend.ClearBottomLine;
  QuickLine := quick;
  quickShown := quick;
  if not quick then Exit;
  TextRend.DisplayString(0, 24, LightMagenta, 'Quick: ');
  TextRend.DisplayString(7, 24, White, 'On (Space) ');
  TextRend.DisplayString(18, 24, LightMagenta, 'Magic: ');
  if GameVars.quickMagic then
    TextRend.DisplayString(25, 24, White, 'On (Alt-M)')
  else
    TextRend.DisplayString(25, 24, White, 'Off (Alt-M)');
end;

function TurnUndeadAi(creature: Types.PCharRecord): Boolean; forward;

function SelectItemToUse(creature: Types.PCharRecord): Boolean; forward;

function SelectSpellToCast(creature: Types.PCharRecord): Boolean; forward;

function AiMoveAttack(creature: Types.PCharRecord): Boolean; forward;

function FinishRound(creature: Types.PCharRecord): Boolean; forward;

function CheckKeystroke(creature: Types.PCharRecord): Boolean; forward;

function CheckMorale(creature: Types.PCharRecord): Boolean; forward;

procedure CombatAiControl(creature: Types.PCharRecord);
var
  stance: Byte;
  done: Boolean;
  spell: Byte;
begin
  done := CombatAi.CheckKeystroke(creature);
  if CombatAi.QuickLine then begin end;
  CharDisp.ClearMessageWindow;
  if creature^.enabled = 0 then
    done := CharHlp.EndActions(creature);
  stance := creature^.combatAddr^.aiStance;
  { Reroll when unset, after a sweep pattern or on 1 turn in 4; a 1d8 roll of 8 picks sweep pattern 5..6, else 1..4 }
  if (stance = 0) or (stance > 4) or (Dice.RollDice(1, 4) = 1) then begin
    stance := Dice.RollDice(1, 8);
    if stance = 8 then
      stance := Dice.RollDice(1, 2) + 4
    else
      stance := Dice.RollDice(1, 4);
  end;
  creature^.combatAddr^.aiStance := stance;
  if not done then
    done := CombatAi.CheckMorale(creature);
  if (creature^.combatAddr^.fleeing <> 0) and (creature^.combatAddr^.turned = 0) then
    CharDisp.PrintNameString(creature, 'flees in panic', 10, True);
  if done then
    Exit;
  if creature^.combatAddr^.spellCast > 0 then begin
    { A spell readied earlier resolves this segment and is the whole action, as on Combat's manual path. spellCast is
      cleared first, as there, so that the caster hurt by its own spell does not lose a second copy of it }
    spell := creature^.combatAddr^.spellCast;
    creature^.combatAddr^.spellCast := 0;
    Magic.CastSpell(spell, True, True, done);
    done := CharHlp.EndActions(creature);
  end else if CombatAi.SelectItemToUse(creature) then
    done := CharHlp.EndActions(creature)
  else if CombatAi.TurnUndeadAi(creature) then
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

{ Turn undead whenever creature can turn (a cleric, or a paladin of level 3 or more) and has not tried this combat, and
  a turnable undead target exists. }
function TurnUndeadAi(creature: Types.PCharRecord): Boolean;
var
  tgt: Pointer;
begin
  if (creature^.combatAddr^.usedTurnUndead = 0)
     and (ClassCal.TurnLevel(creature) > 0)
     and CbtActs.FindTurnUndeadTarget(creature, tgt) then begin
    TurnUndeadAi := True;
    CbtActs.CombatTurnUndead(creature);
  end else
    TurnUndeadAi := False;
end;

{ True when an enabled enemy of creature has been seen doing elem damage this fight (FxEngine.seenElements). }
function EnemySeenDoing(creature: Types.PCharRecord; elem: Byte): Boolean;
var
  i: Byte;
  p: Types.PCharRecord;
begin
  EnemySeenDoing := False;
  for i := 1 to Pathing.LastSlot do begin
    p := GameVars.creatureArr[i];
    if p <> nil then
      if (p^.enabled <> 0) and (CharHlp.Team(p) = CharHlp.EnemyTeam(creature))
         and ((FxEngine.seenElements[i] and elem) <> 0) then
        EnemySeenDoing := True;
  end;
end;

{ True when an enabled enemy of creature has a missile weapon readied (CharHlp.HasRangedWeapon), which anyone can see. }
function EnemyHasMissiles(creature: Types.PCharRecord): Boolean;
var
  i: Byte;
  p: Types.PCharRecord;
begin
  EnemyHasMissiles := False;
  for i := 1 to Pathing.LastSlot do begin
    p := GameVars.creatureArr[i];
    if p <> nil then
      if (p^.enabled <> 0) and (CharHlp.Team(p) = CharHlp.EnemyTeam(creature)) and CharHlp.HasRangedWeapon(p) then
        EnemyHasMissiles := True;
  end;
end;

function SpellImpact(creature: Types.PCharRecord; spell: Byte): Byte;
const
  SPELL_FLOOR = 2;
var
  tgt: Pointer;
  effect: Types.PEffectRec;
  eff: Byte;
  count: Byte;
  threat: Boolean;
begin
  SpellImpact := 0;
  if spell in C_SPELL.CURE_WOUNDS then begin
    if CbtActs.FindCureTarget(creature, tgt) then
      SpellImpact := 1;
  end else if GameDefs.spellTable[spell].offensive = 0 then begin
    case spell of
      C_SPELL.RESIST_FIRE: threat := CombatAi.EnemySeenDoing(creature, C_EFFECT.ELEM_FIRE);
      C_SPELL.RESIST_COLD: threat := CombatAi.EnemySeenDoing(creature, C_EFFECT.ELEM_COLD);
      C_SPELL.PROT_NORMAL_MISSILES: threat := CombatAi.EnemyHasMissiles(creature);
    else
      threat := True;
    end;
    eff := GameDefs.spellTable[spell].effect;
    { Fire Shield names no effect in the table: its flames are a shielded creature's mark }
    if spell = C_SPELL.FIRE_SHIELD then
      eff := C_EFFECT.FIRE_SHIELD_ZAP;
    if threat and ((eff = 0) or not CharHlp.HasEffect(creature, eff, effect)) then
      SpellImpact := 1;
  end else begin
    { no targets picked yet }
    FillChar(GameVars.spellTargets, SizeOf(GameVars.spellTargets), 0);
    if CbtActs.BestAim(spell, count) <> nil then
      if (GameDefs.spellTable[spell].aiRadius = 0) or (spell = C_SPELL.SILENCE) or (count >= SPELL_FLOOR) then
        SpellImpact := count;
  end;
end;

{ Should the AI use spell (an item's spell effect)? Its aiPriority must be at least minPri, and it must be worth casting
  (SpellImpact). }
function DecideCastSpell(creature: Types.PCharRecord; spell, minPri: Byte): Boolean;
begin
  DecideCastSpell := (GameDefs.spellTable[spell].aiPriority >= minPri) and (CombatAi.SpellImpact(creature, spell) > 0);
end;

{ Pick an equipped item whose spell effect the AI should use; needs itemUseAllowed, a remaining enemy team and no
  anti-magic. Over 1d7 passes the minimum aiPriority drops from 7, and the first equipped item that is not readable, has
  special < $80 and has an effect DecideCastSpell accepts is used through Magic.UseItem. The party's AI passes over an
  item it has not identified (KnowsItem), whose spell the player could not know to choose it by (#1143). }
function SelectItemToUse(creature: Types.PCharRecord): Boolean;
var
  lowPri: Byte;
  roll: Byte;
  i: Byte;
  effect: Byte;
  item: Types.PItemRec;
  chosen: Types.PItemRec;
  used: Boolean;
begin
  SelectItemToUse := False;
  chosen := nil;
  lowPri := 7;
  roll := Dice.RollDice(1, 7);
  if (creature^.combatAddr^.itemUseAllowed <> 0)
     and (GameVars.teamCount[CharHlp.EnemyTeam(creature)] > 0)
     and not CharHlp.AntiMagicArea then
    for i := 1 to roll do begin
      item := creature^.itemsAddr;
      while (item <> nil) and (chosen = nil) do begin
        { the spell Use would cast: none past spellTable, which is not rated, as SelectSpellToCast leaves such entries
          out (#708) }
        effect := CharHlp.ItemSpell(item);
        if (item^.equipped <> 0) and (effect <> C_SPELL.NONE) and CombatAi.KnowsItem(creature, item) then
          if CombatAi.DecideCastSpell(creature, effect, lowPri) then
            chosen := item;
        item := item^.next;
      end;
      Dec(lowPri);
    end;
  if chosen <> nil then begin
    Magic.UseItem(chosen, used);
    SelectItemToUse := True;
  end;
end;

{ Choose a spell for an NPC, or for a PC while quick magic (Alt-M) is on, when an enemy team remains. The list holds
  every memorized spell (CharHlp.MemorizedAt) that names a spell (CharHlp.IsSpell) if castAllowed is set; one with bit 7
  set (still being memorized) or past the spells is left out. Each is weighed by how many it would affect (SpellImpact)
  times its aiPriority, and one is drawn at random by weight, so the big plays come up most and the AI still fumbles now
  and then; one that would do nothing, or has priority 0, is never drawn (#1086). It goes to CbtActs.CastSpellCombat,
  whose result is returned. SSI drew at random over passes of falling priority, whatever the spell would do. Nothing is
  cast in an anti-magic area (CharHlp.AntiMagicArea), where the Cast menu is not offered either (#1120). }
function SelectSpellToCast(creature: Types.PCharRecord): Boolean;
var
  list: Types.TMemorized;
  weight: array[0..Types.MEMORIZED_LAST] of Word;
  total: Word;
  roll: Word;
  ext: Boolean;
  count: Byte;
  k: Byte;
  chosen: Byte;
begin
  count := 0;
  if (creature^.combatAddr^.castAllowed <> 0) and not CharHlp.AntiMagicArea then
    for k := 0 to Types.MEMORIZED_LAST do
      { a pending entry (bit 7) is no spell }
      if CharHlp.IsSpell(CharHlp.MemorizedAt(creature, k)) then begin
        list[count] := CharHlp.MemorizedAt(creature, k);
        Inc(count);
      end;
  chosen := 0;
  total := 0;
  if count > 0 then
    { C_NPC.FLAG set }
    if CharHlp.IsNpc(creature) or GameVars.quickMagic then
      if GameVars.teamCount[CharHlp.EnemyTeam(creature)] > 0 then begin
        for k := 0 to count - 1 do begin
          weight[k] := 0;
          if GameDefs.spellTable[list[k]].aiPriority > 0 then
            weight[k] := Word(CombatAi.SpellImpact(creature, list[k])) * GameDefs.spellTable[list[k]].aiPriority;
          Inc(total, weight[k]);
        end;
        if total > 0 then begin
          roll := Random(total);
          k := 0;
          while roll >= weight[k] do begin
            Dec(roll, weight[k]);
            Inc(k);
          end;
          chosen := list[k];
        end;
      end;
  if chosen > 0 then
    CbtActs.CastSpellCombat(chosen, 1, ext)
  else
    ext := False;
  SelectSpellToCast := ext;
end;

{ True when creature keeps out of a Stinking Cloud: any creature the cloud can touch (not FxEngine.CloudProof). }
function AvoidsCloud(creature: Types.PCharRecord): Boolean;
begin
  AvoidsCloud := not FxEngine.CloudProof(creature);
end;

{ Can creature step in direction dir? Off the map sets edge and fails, and an occupied cell fails. The step costs 2
  (orthogonal) or 3 (diagonal) times the terrain cost and must fit in the remaining movement. Stinking Cloud is avoided
  (AvoidsCloud). }
function CanStepDir(creature: Types.PCharRecord; dir: Byte; var edge: Boolean): Boolean;
var
  crIdx: Byte;
  terrIdx: Byte;
  stepCost: Byte;
begin
  edge := False;
  CanStepDir := False;
  CbtMap.ProbeDirection(creature, dir, crIdx, terrIdx);
  if terrIdx = 0 then begin
    { off the map: flee chance }
    edge := True;
    Exit;
  end;
  if crIdx <> 0 then
    { a creature blocks the cell }
    Exit;
  if GameDefs.terrainInfo[terrIdx].cost >= creature^.combatAddr^.movement then
    Exit;
  stepCost := 2;
  { diagonal: doubled metric 3 }
  if Odd(dir) then
    stepCost := 3;
  stepCost := stepCost * GameDefs.terrainInfo[terrIdx].cost;
  if (terrIdx = C_TERR.STINKING_CLOUD) and CombatAi.AvoidsCloud(creature) then
    stepCost := creature^.combatAddr^.movement + 1;
  if creature^.combatAddr^.movement >= stepCost then
    CanStepDir := True;
end;

{ Can creature step in direction baseDir + aiDirOffsets[aiStance, attempt]? As CanStepDir. }
function AiCanStep(creature: Types.PCharRecord; attempt, baseDir: Byte; var edge: Boolean): Boolean;
begin
  AiCanStep := CombatAi.CanStepDir(creature,
                                   (baseDir + aiDirOffsets[creature^.combatAddr^.aiStance, attempt]) mod 8,
                                   edge);
end;

{ The first step, in dir, of creature's walk to an enemy (Pathing.RouteStep): round walls and bodies to its locked
  target (#668); else to the nearest enemy it may attack, which becomes its target, so that a target hemmed in by its
  own side or walled off does not leave it stranded (#769); a creature that keeps out of a Stinking Cloud walks round
  it. When bodies close every walk, a walk through its own side's bodies stands in: it closes up behind them, and when
  its first step is onto one of them it waits there (wait). False when there is no step, or none it can pay for. }
function RouteToEnemy(creature: Types.PCharRecord; var dir: Byte; var wait: Boolean): Boolean;
var
  slot: Byte;
  targetSlot: Byte;
  goal: Byte;
  avoid: Byte;
  i: Byte;
  last: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  found: Boolean;
  edge: Boolean;
  p: Types.PCharRecord;
  enemies: Pathing.TSlotSet;
  friends: Pathing.TSlotSet;
begin
  RouteToEnemy := False;
  wait := False;
  slot := CbtMap.CombatSlot(creature);
  targetSlot := CbtMap.CombatSlot(creature^.combatAddr^.other);
  if (slot = 0) or (targetSlot = 0) then
    Exit;
  avoid := 0;
  if CombatAi.AvoidsCloud(creature) then
    avoid := C_TERR.STINKING_CLOUD;
  found := Pathing.RouteStep(slot, [targetSlot], [], avoid, CbtMap.OccupantAt, dir, goal);
  if not found then begin
    enemies := [];
    friends := [];
    last := Pathing.LastSlot;
    for i := 1 to last do begin
      p := GameVars.creatureArr[i];
      if (i <> slot) and (p <> nil) and (GameVars.arenaLoc[i].size <> 0) then
        if CharHlp.Team(p) <> CharHlp.EnemyTeam(creature) then
          friends := friends + [i]
        else if (p^.enabled <> 0) and CbtActs.CanTarget(creature, p, True) then
          enemies := enemies + [i];
    end;
    found := Pathing.RouteStep(slot, enemies, [], avoid, CbtMap.OccupantAt, dir, goal);
    if not found then begin
      found := Pathing.RouteStep(slot, enemies, friends, avoid, CbtMap.OccupantAt, dir, goal);
      if found then begin
        CbtMap.ProbeDirection(creature, dir, crIdx, terrIdx);
        wait := crIdx <> 0;
      end;
    end;
    if found then
      creature^.combatAddr^.other := GameVars.creatureArr[goal];
  end;
  RouteToEnemy := found and not wait and CombatAi.CanStepDir(creature, dir, edge);
end;

{ One AI movement step. Toward the locked target it takes the first step of a walk to an enemy (RouteToEnemy) when it
  can pay for it, and guards when that walk waits on its own side; otherwise, and when fleeing, it heads at the target
  (or in the flee direction) with aiDirOffsets supplying up to five fallback directions, and oscillation detection
  through lastMoveDir and stuckCount. }
procedure AiMoveStep(creature: Types.PCharRecord);
var
  dir: Byte;
  adjDir: Byte;
  attempt: Byte;
  edge: Boolean;
  done: Boolean;
  routed: Boolean;
  wait: Boolean;
begin
  if not quickShown then
    TextRend.DisplayString(0, 24, LightGreen,
                           'Move/Attack, Move Left = ' + StrUtil.NumStr(creature^.combatAddr^.movement div 2) +
                             ' ');
  if CombatAi.CheckKeystroke(creature) then
    Exit;
  { A mage that is not fleeing does not walk }
  if (creature^.combatAddr^.movement div 2 > 0)
     and (creature^.combatAddr^.initiative > 0)
     and ((creature^.combatAddr^.fleeing <> 0) or (creature^.charClass <> C_CLASS.MAGE)) then begin
    routed := False;
    wait := False;
    if creature^.combatAddr^.fleeing = 0 then begin
      if creature^.combatAddr^.other <> nil then
        routed := CombatAi.RouteToEnemy(creature, adjDir, wait);
      { after RouteToEnemy, which may change the target }
      dir := CbtActs.DirTowardTarget(creature, creature^.combatAddr^.other);
    end else begin
      creature^.combatAddr^.aiStance := Dice.RollDice(1, 2);
      { Hostiles flee along the party's facing (C_DIR 0, 2, 4, 6). SSI's arithmetic turned north into NW and south into
        SE (POR-0160). }
      dir := GameVars.gFacing;
      if creature^.hostile = 0 then
        { allies flee the other way }
        dir := dir + 4;
      dir := dir mod 8;
    end;
    edge := False;
    done := False;
    attempt := 1;
    if wait then
      { its own side is in the way: it holds its ground until they move }
      done := CombatAi.FinishRound(creature)
    else if routed then begin
      lastMoveDir := adjDir;
      stuckCount := 0;
    end else begin
      while (attempt < 6) and (not done)
            and (not CombatAi.AiCanStep(creature, attempt, dir, edge)) do
        if (creature^.combatAddr^.fleeing <> 0) and edge then
          done := CbtActs.AttemptFlee(creature)
        else
          Inc(attempt);
      if done then
      { fled off the map }
      begin
        creature^.combatAddr^.movement := 0;
        creature^.combatAddr^.fleeing := 0;
        done := CharHlp.EndActions(creature);
      end else begin
        { attempt 6 is past aiDirOffsets' row: there is no step to take }
        if attempt < 6 then
          adjDir := (dir + aiDirOffsets[creature^.combatAddr^.aiStance, attempt]) mod 8
        else
          adjDir := dir;
        { nothing walkable }
        if (attempt = 6)
           { reversing }
           or (lastMoveDir = (adjDir + 4) mod 8) then begin
          Inc(stuckCount);
          creature^.combatAddr^.aiStance := creature^.combatAddr^.aiStance mod 6 + 1;
          if stuckCount > 1 then begin
            creature^.combatAddr^.other := nil;
            if stuckCount > 2 then begin
              creature^.combatAddr^.movement := 0;
              done := True;
            end else if not CbtActs.AcquireTarget(creature, 255, 1, 0) then
              done := CombatAi.FinishRound(creature);
          end;
        end;
        if attempt < 6 then
          lastMoveDir := adjDir
        else
          done := True;
      end;
    end;
    { flee and step paths rejoin }
    if not done then begin
      CbtMap.SetCreatureFacing(creature, adjDir, 0, 0);
      done := CbtActs.StepCreature(creature, creature^.combatAddr^.direction);
    end;
  end else
    done := CombatAi.FinishRound(creature);
end;

{ The AI's move/attack loop. A party member (not hostile) first bandages a dying teammate, which ends its turn, as in
  Curse (#654). A guard ends a runaway turn: after a pass for each step the movement left at the start pays for (two
  half-moves a step at the least) and TURN_SLACK more; a fixed 20 passes cut short a hasted fast monster's move
  (#803). Returns True when the creature can no longer act. }
function AiMoveAttack(creature: Types.PCharRecord): Boolean;
var
  done: Boolean;
  inRange: Boolean;
  canAct: Boolean;
  weaponRange: Byte;
  range: Word;
  cnt: Byte;
  pick: Byte;
  target: Types.PCharRecord;
  tx: ShortInt;
  ty: ShortInt;
  loopCount: Byte;
  loopLimit: Byte;
begin
  lastMoveDir := C_DIR.CENTER;
  stuckCount := 0;
  loopCount := 0;
  loopLimit := creature^.combatAddr^.movement div 2 + TURN_SLACK;
  canAct := True;
  done := False;
  FxEngine.TriggerEffectsWithCondition(C_COND.MONSTER_SPECIAL, creature);
  { as the combat menu's Bandage does }
  if (creature^.hostile = 0) and Combat.BandageDying(True) then
    done := CharHlp.EndActions(creature);
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
      canAct := False;
    Inc(loopCount);
    if canAct and (loopCount > loopLimit) then begin
      { runaway-turn guard: the round ends here. SSI went on with the pass, so a creature it had just set Guarding
        could still step or strike }
      done := True;
      canAct := not CombatAi.FinishRound(creature);
    end;
    if (not done) and canAct then begin
      inRange := False;
      weaponRange := 1;
      if creature^.equipped[C_EQUIP.WEAPON] <> nil then
        weaponRange := CharHlp.BaseItem(creature^.equipped[C_EQUIP.WEAPON]^.itemType)^.range - 1;
      if (weaponRange = 0) or (weaponRange = 255) then
        weaponRange := 1;
      { other is nil once AiMoveStep has dropped it. A lock on a creature of its own side, or one out of action, is
        dropped. SSI tested hostile = 0, which dropped every monster's lock on the party, so monsters struck a random
        enemy in reach rather than the one they had closed on (#715) }
      target := creature^.combatAddr^.other;
      if (target <> nil) and ((target^.enabled = 0) or (target^.hostile = creature^.hostile)) then
        target := nil;
      if target <> nil then
        if CbtActs.CanTarget(creature, target, True) then begin
          tx := CbtMap.CombatCellX(target);
          ty := CbtMap.CombatCellY(target);
          range := weaponRange;
          if Pathing.WalkLine(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), tx, ty, range,
                              GameVars.arenaPtr) then
            if range div 2 <= weaponRange then
              inRange := True;
        end;
      if not inRange then begin
        cnt := CbtMap.CountTargets(creature, weaponRange);
        if cnt = 0 then begin
          if CbtActs.AcquireTarget(creature, 255, 0, 0) then
            { approach }
            CombatAi.AiMoveStep(creature)
          else
            done := CombatAi.FinishRound(creature);
        end else begin
          pick := Dice.RollDice(1, cnt);
          target := GameVars.creatureArr[GameVars.combatTargetSlots[pick]];
          if CharHlp.HasRangedWeapon(creature)
             and (not CharHlp.HasThrowableWeapon(creature))
             and (CbtMap.CountTargets(creature, 1) > 0) then begin
            { pure missile weapon with an enemy adjacent: re-equip. A cursed bow, or any bow with Allow Gear Changes
              off (#1127), cannot be swapped: the turn ends, or CombatAiControl would call back here for ever (#713) }
            CombatAi.EquipWeaponAndShield(creature);
            done := True;
            if CharHlp.HasRangedWeapon(creature) and (not CharHlp.HasThrowableWeapon(creature)) then
              canAct := not CombatAi.FinishRound(creature);
          end else if (CbtMap.CalcDistance(creature, target) = 1)
                  or CbtActs.CanTarget(creature, target, True) then
            inRange := True;
        end;
      end;
      if inRange then
        CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 2,
                          CbtActs.DirTowardTarget(creature, target));
      if inRange then begin
        if CbtActs.SweepAttack(creature, target) then
          done := CharHlp.EndActions(creature)
        else begin
          CbtActs.AttackWithReadied(creature, target, done);
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
  CharDisp.ClearMessageWindow;
  if CharHlp.IsHelpless(creature)
     or CharHlp.HasRangedWeapon(creature)
     or (creature^.combatAddr^.initiative = 0) then
    FinishRound := CharHlp.EndActions(creature)
  else begin
    FinishRound := CharHlp.Guard(creature);
    CharDisp.PrintActionLine(creature, 'Guarding', 'is Guarding');
  end;
end;

{ Handle a key pressed during AI turns: Alt-M toggles quick magic, Space returns every non-NPC, non-animated creature to
  manual control (True when creature itself is now manual), Alt-X runs the STING victory cheat. Alt-M and Alt-X count
  only after the extended-key prefix: SSI also took a plain '2' for Alt-M and a plain '-' for Alt-X. }
function CheckKeystroke(creature: Types.PCharRecord): Boolean;
var
  ch: Char;
  ext: Boolean;
begin
  CheckKeystroke := False;
  if KeyPressed then begin
    ch := GameIo.ReadGameKey;
    ext := ch = #0;
    if ext then
      { this second call can consume later pending bytes too }
      ch := GameIo.ReadGameKey;
    case ch of
      C_KEYS.ALT_M:
        if ext then
          CombatAi.ToggleQuickMagic;
      { Space: everyone manual }
      ' ':
        begin
          CombatAi.AllToManual;
          if creature^.quickfight = 0 then begin
            creature^.combatAddr^.initiative := 20;
            CheckKeystroke := True;
          end;
        end;
      { result ignored }
      C_KEYS.ALT_X:
        if ext then
          if CbtActs.VictoryCheat then
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
  hpPct: Integer;
begin
  CheckMorale := False;
  creature^.combatAddr^.fleeing := 0;
  { Removes C_EFFECT.BITE_HOLD and C_EFFECT.BLOOD_DRAIN }
  FxEngine.RemoveAiEffects(creature);
  if creature^.combatAddr^.turned <> 0 then begin
    creature^.combatAddr^.fleeing := 1;
    CharDisp.PrintNameString(creature, 'is forced to flee', 10, True);
    Exit;
  end;
  { C_NPC.FLAG clear }
  if not CharHlp.IsNpc(creature) then
    { PCs never check morale }
    Exit;
  { packed morale rating }
  GameVars.combatMorale := (creature^.npc and C_NPC.MORALE_MASK) * 2;
  if GameVars.combatMorale > 102 then
    { 0 is the fail sentinel: both checks below require morale <> 0 }
    GameVars.combatMorale := 0;
  { Effects adjust morale here: Bless +5, Curse -5 floored at 0 (so a curse below 5 fails both checks), Charm sets 100
    and flips the creature's side on its first call. Bless and Curse also adjust the attack roll. }
  FxEngine.TriggerEffectsWithCondition(C_COND.MORALE_CHECK, creature);
  { hpMax 0 counts as no hit points left }
  if creature^.hpMax = 0 then
    hpPct := 0
  else
    hpPct := creature^.hpCur * 100 div creature^.hpMax;
  if (GameVars.combatMorale >= 100 - hpPct)
     and (GameVars.combatMorale <> 0) then
    { own-HP check holds }
    Exit;
  moraleSave := GameVars.combatMorale;
  GameVars.combatMorale := CbtActs.hostileHpPct;
  { the same effect adjustments, now to the group figure }
  FxEngine.TriggerEffectsWithCondition(C_COND.MORALE_CHECK, creature);
  if (GameVars.combatMorale >= 100 - GameVars.zone1^[C_GBVM.MORALE_THRESHOLD])
     and (GameVars.combatMorale <> 0)
     and (creature^.hostile <> 0) then
    { group check holds (hostiles) }
    Exit;
  enemyMove := CbtActs.HighestEnemyMovement(creature);
  if enemyMove <= CbtActs.CalcCreatureMovement(creature) div 2 then begin
    { fast enough to get away: flee in panic }
    { RemoveAiEffects has already let go of any bite-hold or blood drain }
    creature^.combatAddr^.fleeing := 1;
  end else if creature^.intCur > 5 then begin
    { Int 6+ creatures give up instead }
    FxEngine.PutOutOfPlayWithStatus(creature, C_STATUS.UNCONSCIOUS, 'Surrenders');
    CheckMorale := CharHlp.EndActions(creature);
  end;
end;

function KnowsItem(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;
begin
  KnowsItem := (item^.unidMask = 0) or (CharHlp.Team(creature) <> 0);
end;

function CalcWeaponPriority(creature: Types.PCharRecord; item: Types.PItemRec): Byte;
var
  pri: Byte;
  base: Types.TBaseItemRec;
  known: Boolean;
begin
  known := CombatAi.KnowsItem(creature, item);
  base := CharHlp.BaseItem(item^.itemType)^;
  pri := base.dmgSmDice * base.dmgSmRolls;
  if known and (item^.plus > 0) then
    pri := pri + item^.plus * 8;
  if base.dmgSmMod > 0 then
    pri := pri + base.dmgSmMod * 2;
  if (item^.itemType = C_ITEM.HOLY_WATER_VIAL)
     and (creature^.combatAddr^.other <> nil)
     and (creature^.combatAddr^.other^.levelUndead > 0) then
    pri := 8;
  { launcher: +2 per rateOfFire point above 1 }
  if (base.props and C_ITEM.PROP_FIRES_AMMO) > 0 then
    pri := pri + (base.rateOfFire - 1) * 2;
  if base.hands <= 1 then
    pri := pri + 3;
  if base.hands + creature^.handsEquipped > 3 then
    { not enough hands }
    pri := 0;
  { what only identifying the weapon tells: an unidentified one is scored as the mundane weapon (#1143) }
  if known then begin
    { aligned weapon }
    if item^.special = C_EFFECT.ALIGNED_WEAPON then
      if (item^.effect and $F) <> creature^.alignment then
        pri := 0;
    if item^.effect = C_SPELL.ITEM_JAVELIN_LIGHTNING + C_SPELL.ITEM_EFFECT_SHIFT then
      pri := 0;
    if item^.cursed <> 0 then
      pri := 0;
  end;
  CalcWeaponPriority := pri;
end;

{ Re-equip creature: pick the best usable weapon by CalcWeaponPriority (unarmed damage sets the melee bar) and the best
  shield (plus + 1). The ranged pick wins when it beats half the melee score, has ammo, and either is trueRanged or no
  enemy is adjacent. Cursed items are never swapped out. Prints the creature info if anything changed. Nothing changes
  for a creature that KeepsGear (Allow Gear Changes off, #1127). }
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
  needSwap: Boolean;
  changed: Boolean;
  trueRanged: Boolean;
  hasAmmo: Boolean;
begin
  if CombatAi.KeepsGear(creature) then Exit;
  { stop counting the current weapon/shield hands }
  if creature^.equipped[C_EQUIP.WEAPON] <> nil then
    creature^.handsEquipped := creature^.handsEquipped
        - CharHlp.BaseItem(creature^.equipped[C_EQUIP.WEAPON]^.itemType)^.hands;
  if creature^.equipped[C_EQUIP.SHIELD] <> nil then
    creature^.handsEquipped := creature^.handsEquipped
        - CharHlp.BaseItem(creature^.equipped[C_EQUIP.SHIELD]^.itemType)^.hands;
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
    if CharHlp.BaseItem(itType)^.slot = C_EQUIP.WEAPON then
      if (CharHlp.BaseItem(itType)^.classMask and creature^.itemLimits) <> 0 then begin
        pri := CombatAi.CalcWeaponPriority(creature, item);
        if ((CharHlp.BaseItem(itType)^.props and C_ITEM.PROP_FIRES_AMMO) <> 0)
           or ((CharHlp.BaseItem(itType)^.props and C_ITEM.PROP_THROWN) <> 0) then
          if pri > bestRangedPri then begin
            bestRanged := item;
            bestRangedPri := pri;
          end;
        if (CharHlp.BaseItem(itType)^.props and C_ITEM.PROP_FIRES_AMMO) = 0 then
          if pri > bestMeleePri then begin
            bestMelee := item;
            bestMeleePri := pri;
          end;
      end;
    { shield slot }
    if CharHlp.BaseItem(itType)^.slot = C_EQUIP.SHIELD then
      if (CharHlp.BaseItem(itType)^.classMask and creature^.itemLimits) > 0 then begin
        { a cursed shield is never picked, as CalcWeaponPriority scores a cursed weapon 0; an unidentified one is
          scored as a mundane shield (#1143) }
        if not CombatAi.KnowsItem(creature, item) then
          pri := 1
        else if (item^.plus >= 0) and (item^.cursed = 0) then
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
  { trueRanged: range > 1 and both C_ITEM.PROPS_THROWABLE bits (thrown, Strength bonus); such a weapon is picked even
    with an enemy adjacent }
  if (bestRanged <> nil)
     and (CharHlp.BaseItem(bestRanged^.itemType)^.range > 1)
     and
       ((CharHlp.BaseItem(bestRanged^.itemType)^.props and
         C_ITEM.PROPS_THROWABLE) = C_ITEM.PROPS_THROWABLE) then
    trueRanged := True
  else
    trueRanged := False;
  hasAmmo := CharHlp.FindAmmo(creature, bestRanged, ammo);
  { pick the weapon }
  if (bestRanged <> nil)
     and (bestRangedPri > bestMeleePri div 2)
     and hasAmmo
     and (trueRanged or (CbtMap.CountTargets(creature, 1) = 0)) then
    item := bestRanged
  else
    item := bestMelee;
  changed := False;
  needSwap := True;
  if creature^.equipped[C_EQUIP.WEAPON] <> nil then
    if (creature^.equipped[C_EQUIP.WEAPON] = item) or (creature^.equipped[C_EQUIP.WEAPON]^.cursed <> 0) then
      needSwap := False;
  if needSwap then begin
    if creature^.equipped[C_EQUIP.WEAPON] <> nil then
      FxEngine.ToggleReadyItem(creature^.equipped[C_EQUIP.WEAPON]);
    CharHlp.RecalcStats(creature);
    if creature^.equipped[C_EQUIP.SHIELD] <> nil then
      if creature^.equipped[C_EQUIP.SHIELD]^.cursed = 0 then
        creature^.handsEquipped := creature^.handsEquipped
            - CharHlp.BaseItem(creature^.equipped[C_EQUIP.SHIELD]^.itemType)^.hands;
    if item <> nil then
      FxEngine.ToggleReadyItem(item);
    changed := True;
  end;
  CharHlp.RecalcStats(creature);
  CbtActs.RecalcAttacksLeft(creature);
  needSwap := True;
  if creature^.equipped[C_EQUIP.SHIELD] <> nil then
    if (creature^.equipped[C_EQUIP.SHIELD] = bestShield)
       or (creature^.equipped[C_EQUIP.SHIELD]^.cursed <> 0) then
      needSwap := False;
  if creature^.handsEquipped > 2 then begin
    { Over-handed: drop the shield, or the chosen weapon when there is no shield or the shield is cursed }
    if (creature^.equipped[C_EQUIP.SHIELD] = nil) or
        (creature^.equipped[C_EQUIP.SHIELD]^.cursed <> 0) then begin
      { item is nil when no weapon was chosen }
      if item <> nil then
        FxEngine.ToggleReadyItem(item);
      changed := True;
    end else begin
      FxEngine.ToggleReadyItem(creature^.equipped[C_EQUIP.SHIELD]);
      changed := True;
    end;
  end else if (creature^.handsEquipped < 2) and needSwap then begin
    if creature^.equipped[C_EQUIP.SHIELD] <> nil then
      FxEngine.ToggleReadyItem(creature^.equipped[C_EQUIP.SHIELD]);
    CharHlp.RecalcStats(creature);
    if bestShield <> nil then
      FxEngine.ToggleReadyItem(bestShield);
    changed := True;
  end;
  CharHlp.RecalcStats(creature);
  if changed then
    CharDisp.CombatPrintCreatureInfo(creature);
end;

function KeepsGear(creature: Types.PCharRecord): Boolean;
begin
  KeepsGear := (GameVars.gearChangesOn = 0) and CharHlp.ComesUnderPlayer(creature);
end;

procedure ToggleQuickMagic;
begin
  GameVars.quickMagic := not GameVars.quickMagic;
  { the Quick line shows it; with no one under Quick, say which way it went }
  if not CombatAi.QuickLine then
    if GameVars.quickMagic then
      CharDisp.PrintBottomLine('Magic On')
    else
      CharDisp.PrintBottomLine('Magic Off');
end;

procedure AllToManual;
var
  p: Types.PCharRecord;
begin
  p := GameVars.creatureList;
  while p <> nil do begin
    if CharHlp.ComesUnderPlayer(p) then
      p^.quickfight := 0;
    p := p^.nextCharAddr;
  end;
end;

begin
  quickShown := False;
end.
