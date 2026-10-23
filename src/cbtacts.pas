{ Combat movement, attacks, aiming and spell targeting. }
{$O+,F+}
{$I COMPILER.INC}
unit CbtActs;

interface

uses Types;

var
  { suppress targeting }
  currentSuppressTargetingFlag: Byte;
  hitsMade: array[1..2] of Byte;
  { Hostile creatures' hit points, percent remaining }
  hostileHpPct: Byte;
  { Done flag for the acting creature's attacks; combat menus also return their extended-key flag here }
  doneRoundFlag: Boolean;

procedure CombatRoundStartSetup(creature: Types.PCharRecord);

function CalcCreatureMovement(creature: Types.PCharRecord): Byte;

procedure CombatMoveCreature(creature: Types.PCharRecord; dir: Byte);

procedure MoveOpportunityAttacks(creature: Types.PCharRecord; dir: Byte);

function CombatFleeAttempt(creature: Types.PCharRecord): Boolean;

procedure SetCurAttacksX2(creature: Types.PCharRecord);

function SweepAttempt(att, def: Types.PCharRecord): Boolean;

function CanAttackTarget(creature, other: Types.PCharRecord): Boolean;

procedure CombatTurnUndead(creature: Types.PCharRecord);

function FindTurnUndeadTarget(creature: Types.PCharRecord; var tgt: Pointer): Boolean;

{ The cleric level the creature turns undead at: its cleric level, or its paladin level less 2 when that is higher, so a
  paladin turns from level 3; 0 when it cannot turn. }
function TurnLevel(creature: Types.PCharRecord): ShortInt;

procedure NoteAttackDirection(att, def: Types.PCharRecord);

procedure CombatAttack(att, def: Types.PCharRecord; fromBehind: Boolean; weapon: Types.PItemRec; var done: Boolean);

function FindCureTarget(creature: Types.PCharRecord; var tgt: Pointer): Boolean;

procedure CombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);

procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);

function CheckAttackAlly(att, def: Types.PCharRecord): Boolean;

procedure CombatAimMenu(creature: Types.PCharRecord; range, weaponMode, groundOk: Byte; var done: Boolean; var tgt);

function DirTowardTarget(creature, other: Types.PCharRecord): Byte;

procedure CalcHostileHpPercent;

function HighestEnemyMovement(creature: Types.PCharRecord): Byte;

function AcquireTarget(creature: Types.PCharRecord; range, relaxed, forceNew: Byte): Boolean;

procedure RearClawRake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure BiteAndHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

function StingVictoryCheat: Boolean;

{ Would an area spell aimed at cell (x, y) with walk budget radius catch anyone not on GameVars.curChar's enemy team?
  Rebuilds the target list around the aim point. }
function AreaHitsNonEnemy(x, y: ShortInt; radius: Byte): Boolean;

implementation

uses C_ITEM, C_TERR, C_COND, GameDefs, GameVars, Crt, MenuCore, Magic, C_EFFECT, C_EQUIP, C_KEYS, C_LEVEL,
  C_STATUS, C_GBVM, C_DIR, C_SOUND, C_SPELL, Border, CbtMap, CharHlp, FxEngine, Pathing, SoundDrv, TextRend, StrUtil,
  CharDisp, AbilAdj, Dice, Blit, ClassCal;

var
  { Primary and secondary attack counts. }
  attacksMade: array[1..2] of Byte;

const
  { Combat sprite cells the spell-aim preview draws with: the spell missile, the lightning bolt, the effect sparkle and
    the damage burst }
  SPRITE_MISSILE = 18;
  SPRITE_LIGHTNING = 19;
  SPRITE_SPARKLE = 22;
  SPRITE_BURST = 23;

function AdjustedAttacks(n: Byte): Byte; forward;

procedure ModifyDefenseForDistance(att, def: Types.PCharRecord; var defense: Byte); forward;

function IsBackstab(att, def: Types.PCharRecord): Boolean; forward;

procedure RangedAttackAnim(att, def: Types.PCharRecord; weapon: Types.PItemRec); forward;

{ Per-creature round reset: combat record flags, current attacks (SetCurAttacksX2, then the secondary attacks through
  AdjustedAttacks), the sweep budget, initiative (1d6 + missile dex adjustment, at least 1, -6 when surprised, 0 if
  disabled or outside 0..20) and movement. }
procedure CombatRoundStartSetup(creature: Types.PCharRecord);
begin
  with creature^.combatAddr^ do begin
    spellCast := 0;
    castAllowed := 1;
    itemUseAllowed := 1;
    madeAttack := 0;
    attackPhase := 2;
    CbtActs.SetCurAttacksX2(creature);
    GameVars.currentAttackCurrent := creature^.attacks2;
    GameVars.currentCreatureCalculatingFlag := 0;
    FxEngine.TriggerEffectsWithCondition(C_COND.MOVE_ATTACK_RATE, creature);
    creature^.curAttacks2 := CbtActs.AdjustedAttacks(GameVars.currentAttackCurrent);
    sweepBudget := creature^.attackLevel;
    if creature^.enabled <> 0 then begin
      initiative := Dice.RollDice(1, 6) + AbilAdj.DexMissileAdjust(creature);
      if initiative < 1 then
        initiative := 1;
      { Surprise mask: bit 0 for the party, bit 1 for monsters }
      if Byte((creature^.hostile + 1) and Integer(GameVars.zone1^[C_GBVM.SURPRISE])) <> 0 then
        Dec(initiative, 6);
      if (initiative < 0) or (initiative > 20) then
        initiative := 0;
    end else
      initiative := 0;
  end;
  creature^.combatAddr^.movement := CbtActs.CalcCreatureMovement(creature);
end;

{ Calculate movement from the current speed plus, for the party, the GBVM movement modifier (values outside 1..96 become
  1), then let haste, slow and immobile effects adjust it. Return it in half-step units. }
function CalcCreatureMovement(creature: Types.PCharRecord): Byte;
var
  m: Byte;
begin
  m := creature^.movementCur;
  if creature^.hostile = 0 then
    m := m + GameVars.zone1^[C_GBVM.MOD_PARTY_MOVE];
  GameVars.currentCreatureCalculatingFlag := 1;
  if (m < 1) or (m > 96) then
    m := 1;
  GameVars.currentAttackCurrent := m * 2;
  FxEngine.TriggerEffectsWithCondition(C_COND.MOVE_ATTACK_RATE, creature);
  GameVars.currentCreatureCalculatingFlag := 0;
  CalcCreatureMovement := GameVars.currentAttackCurrent;
end;

{ Roll attack idx's (1 or 2) current dice plus modifier into pendingDamage, multiply it on a backstab by the AD&D band
  for the thief level (x2 at 1-4, x3 at 5-8, x4 at 9-12), add the attacker's ranger level against a giant-class foe
  (GameDefs.rangerFoes) in melee, up to 255, clear elementMask and fire the attacker's and defender's weapon-damage
  effect conditions. }
procedure CalcWeaponDamage(att, def: Types.PCharRecord; idx: Byte);
var
  i: Byte;
  dmg: Integer;
begin
  { summed as an Integer so that a negative modifier stops at 0 instead of wrapping in the Byte }
  dmg := att^.curModA[idx] + Dice.RollDamageDice(att^.curRollsA[idx], att^.curDiceA[idx]);
  if dmg < 0 then
    dmg := 0;
  if dmg > 255 then
    dmg := 255;
  GameVars.pendingDamage := dmg;
  if CbtActs.IsBackstab(att, def) then
    { (level + 3) div 4 + 1 is (level - 1) div 4 + 2 without the underflow at level 0 }
    GameVars.pendingDamage := GameVars.pendingDamage * ((Word(att^.classLevels[C_LEVEL.THIEF]) + 3) div 4 + 1);
  if (att^.classLevels[C_LEVEL.RANGER] > 0) and (CbtMap.CalcDistance(att, def) <= 1) then
    for i := 1 to SizeOf(GameDefs.rangerFoes) div SizeOf(GameDefs.rangerFoes[1]) do
      if def^.name = GameDefs.rangerFoes[i] then
        if GameVars.pendingDamage > 255 - att^.classLevels[C_LEVEL.RANGER] then
          GameVars.pendingDamage := 255
        else
          Inc(GameVars.pendingDamage, att^.classLevels[C_LEVEL.RANGER]);
  GameVars.elementMask := 0;
  FxEngine.TriggerEffectsWithCondition(C_COND.WEAPON_DAMAGE_ATT, att);
  FxEngine.TriggerEffectsWithCondition(C_COND.WEAPON_DAMAGE_DEF, def);
end;

{ Print the attack message and inflict the damage (dmg = inflicted, dmgDisp = displayed). atkType: 1 = from behind, 2 =
  backstab, 3 = slays a helpless target, else a plain attack. Any damage cancels the defender's casting for the round
  and loses a spell being cast; a defender that goes down gets its hp-0 effects and, if still disabled,
  CbtMap.CreatureDowned. }
procedure ProcessAttackResult(att, def: Types.PCharRecord; atkType, dmg, dmgDisp: Byte; isHit: Boolean);
var
  row: Byte;
  verb: String[80];
begin
  case atkType of
    2: verb := '-Backstabs-';
    3: verb := 'slays helpless';
  else
    verb := 'Attacks';
  end;
  CharDisp.PrintNameString(att, verb, 10, False);
  row := 12;
  CharDisp.DisplayCreatureName(def, 23, row, False);
  Inc(row);
  if atkType = 1 then
    verb := '(from behind) '
  else
    verb := '';
  if isHit then begin
    if atkType = 3 then
      verb := 'with one cruel blow'
    else begin
      verb := verb + 'Hitting for ' + StrUtil.NumStr(dmgDisp);
      if dmgDisp = 1 then
        verb := verb + ' point '
      else
        verb := verb + ' points ';
      verb := verb + 'of damage';
    end;
    CharHlp.InflictDamage(def, dmg);
  end else
    verb := verb + 'and Misses';
  TextRend.DisplayMessageWindow(23, row, 38, row + 3, LightGreen, True, verb);
  row := GameVars.curRow + 1;
  if dmg > 0 then begin
    def^.combatAddr^.castAllowed := 0;
    if def^.combatAddr^.spellCast > 0 then begin
      TextRend.PauseOnly;
      CharDisp.PrintNameString(def, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(def, def^.combatAddr^.spellCast);
      def^.combatAddr^.spellCast := 0;
    end else
      TextRend.PauseOnly;
  end else
    TextRend.PauseOnly;
  if def^.enabled = 0 then begin
    CharDisp.PrintNameString(def, 'goes down', row, False);
    Inc(row, 2);
    if def^.status = C_STATUS.DYING then
      TextRend.DisplayString(23, row, LightGreen, 'and is Dying');
    if def^.status in [C_STATUS.DEAD, C_STATUS.STONED, C_STATUS.GONE] then
      CharDisp.PrintNameString(def, 'is killed', row, False);
    FxEngine.RemoveEffectsHp0(def);
    FxEngine.TriggerEffectsWithCondition(C_COND.HP_ZERO, def);
    if def^.enabled = 0 then
      CbtMap.CreatureDowned(def)
    else
      TextRend.PauseOnly;
  end;
  CharDisp.ClearMessageWindow;
end;

{ Each adjacent enemy that is guarding and not helpless spends its guard on a free attack against the mover. }
procedure GuardingAttacks(creature: Types.PCharRecord);
var
  cnt: Byte;
  i: Byte;
  p: Types.PCharRecord;
  done: Boolean;
begin
  cnt := CbtMap.CountTargets(creature, 1);
  for i := 1 to cnt do
    if creature^.enabled <> 0 then begin
      p := GameVars.creatureArr[GameVars.potentialTargetCreature[i]];
      if (p^.combatAddr^.guarding <> 0) and (not CharHlp.IsHelpless(p)) then begin
        CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 2, C_DIR.CENTER);
        p^.combatAddr^.guarding := 0;
        CbtActs.NoteAttackDirection(p, creature);
        CbtActs.CombatAttack(p, creature, False, nil, done);
      end;
    end;
end;

{ One step in dir: pay 2 half-moves (3 on a diagonal; with too few left, movement drops to 0 and nothing moves), move
  the icon, reset the flanking accumulators and let guarding enemies attack. A mover left disabled or helpless loses the
  rest of its movement. }
procedure CombatMoveCreature(creature: Types.PCharRecord; dir: Byte);
var
  cost: Byte;
  slot: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
begin
  if Odd(dir) then
    cost := 3
  else
    cost := 2;
  if cost > creature^.combatAddr^.movement then begin
    creature^.combatAddr^.movement := 0;
    Exit;
  end;
  Dec(creature^.combatAddr^.movement, cost);
  slot := CbtMap.CombatSlot(creature);
  if slot = 0 then begin
    { not on the map: nothing to move }
    creature^.combatAddr^.movement := 0;
    Exit;
  end;
  x := GameVars.arenaLoc[slot].x;
  y := GameVars.arenaLoc[slot].y;
  nx := x + GameDefs.dirDX[dir];
  ny := y + GameDefs.dirDY[dir];
  { cost is reused as the ScrollView delta: 1 under manual control, 3 under quickfight }
  cost := 1;
  if creature^.quickfight <> 0 then begin
    cost := 3;
    if not CbtMap.ViewCoordsValid(nx - GameVars.arenaPtr^.ox, ny - GameVars.arenaPtr^.oy) then
      CbtMap.ScrollView(x, y, 2, C_DIR.CENTER);
  end;
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  GameVars.arenaLoc[slot].x := nx;
  GameVars.arenaLoc[slot].y := ny;
  CbtMap.BuildArenaArrays;
  CbtMap.ScrollView(nx, ny, cost, C_DIR.CENTER);
  { flanking accumulators reset }
  creature^.combatAddr^.flankCount := 0;
  creature^.combatAddr^.flankSpread := 0;
  SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.STEP], C_SOUND.GROUP_FOOTSTEPS);
  CbtActs.GuardingAttacks(creature);
  if (creature^.enabled = 0) or CharHlp.IsHelpless(creature) then
    creature^.combatAddr^.movement := 0;
end;

{ Enemies adjacent before a step in dir but not after it get one free attack on the mover, made as from behind.
  Helpless, effect-vetoed, blood-draining and bite-holding enemies are skipped. An enemy with no initiative left that
  has already been attacked this round (flankCount > 0) attacks only if the mover is in its 5-direction front cone. The
  free attack is one attack and costs the enemy nothing: CombatAttack would spend every attack it has left and end its
  turn, so its attacks, phase, turn state and sweep (madeAttack, sweepBudget) are put back afterwards while it is still
  up (#711, #770). Its special attacks (breath, gaze, acid) still come at the start of its own move
  (CombatAi.AiMoveAttack). }
procedure MoveOpportunityAttacks(creature: Types.PCharRecord; dir: Byte);
var
  adj: array[1..12] of Byte;
  effect: Types.PEffectRec;
  still: Boolean;
  attacked: Boolean;
  slot: Byte;
  cntBefore: Byte;
  cntAfter: Byte;
  j: Byte;
  i: Byte;
  k: Byte;
  phase: Byte;
  a: Byte;
  p: Types.PCharRecord;
  savedOther: Types.PCharRecord;
  savedAtt: array[1..2] of Byte;
  savedPhase: Byte;
  savedInit: ShortInt;
  savedSpell: Byte;
  savedGuard: Byte;
  savedMove: Byte;
  savedMade: Byte;
  savedSweep: Byte;
begin
  FillChar(adj, SizeOf(adj), 0);
  slot := CbtMap.CombatSlot(creature);
  { not on the map: no step to probe }
  if slot = 0 then
    Exit;
  cntBefore := CbtMap.CountTargets(creature, 1);
  if cntBefore = 0 then
    Exit;
  for i := 1 to cntBefore do
    adj[i] := GameVars.potentialTargetCreature[i];
  { probe: step the icon, recount, step back }
  Inc(GameVars.arenaLoc[slot].x, GameDefs.dirDX[dir]);
  Inc(GameVars.arenaLoc[slot].y, GameDefs.dirDY[dir]);
  cntAfter := CbtMap.CountTargets(creature, 1);
  Dec(GameVars.arenaLoc[slot].x, GameDefs.dirDX[dir]);
  Dec(GameVars.arenaLoc[slot].y, GameDefs.dirDY[dir]);
  { enemies still adjacent after the step get no free attack }
  for i := 1 to cntBefore do begin
    still := False;
    for j := 1 to cntAfter do
      if GameVars.potentialTargetCreature[j] = adj[i] then
        still := True;
    if still then
      adj[i] := 0;
  end;
  for i := 1 to cntBefore do
    if adj[i] > 0 then
      if creature^.enabled <> 0 then begin
        attacked := False;
        p := GameVars.creatureArr[adj[i]];
        if not CharHlp.IsHelpless(p) then
          if CbtActs.CanAttackTarget(p, creature) then
            if not CharHlp.HasEffect(p, C_EFFECT.BLOOD_DRAIN, effect) then
              if not CharHlp.HasEffect(p, C_EFFECT.BITE_HOLD, effect) then
                for a := p^.combatAddr^.direction + 6 to p^.combatAddr^.direction + 10 do
                  if not attacked then
                    if (p^.combatAddr^.initiative > 0) or (p^.combatAddr^.flankCount = 0) or
                        Pathing.IsDirToward(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), CbtMap.CombatCellX(creature),
                                            CbtMap.CombatCellY(creature), a mod 8) then begin
                      phase := 1;
                      if p^.attacks = 0 then
                        phase := 2;
                      { 2 = curAtt's upper bound }
                      for k := 1 to 2 do
                        if Types.PAttackPhaseView(p)^.curAtt[k] > 0 then
                          phase := k;
                      savedAtt[1] := Types.PAttackPhaseView(p)^.curAtt[1];
                      savedAtt[2] := Types.PAttackPhaseView(p)^.curAtt[2];
                      savedPhase := p^.combatAddr^.attackPhase;
                      savedInit := p^.combatAddr^.initiative;
                      savedSpell := p^.combatAddr^.spellCast;
                      savedGuard := p^.combatAddr^.guarding;
                      savedMove := p^.combatAddr^.movement;
                      savedMade := p^.combatAddr^.madeAttack;
                      savedSweep := p^.combatAddr^.sweepBudget;
                      { exactly one attack, in that phase }
                      Types.PAttackPhaseView(p)^.curAtt[1] := 0;
                      Types.PAttackPhaseView(p)^.curAtt[2] := 0;
                      Types.PAttackPhaseView(p)^.curAtt[phase] := 1;
                      p^.combatAddr^.attackPhase := phase;
                      savedOther := p^.combatAddr^.other;
                      CbtActs.CombatAttack(p, creature, True, nil, doneRoundFlag);
                      attacked := True;
                      p^.combatAddr^.other := savedOther;
                      if p^.enabled <> 0 then begin
                        Types.PAttackPhaseView(p)^.curAtt[1] := savedAtt[1];
                        Types.PAttackPhaseView(p)^.curAtt[2] := savedAtt[2];
                        p^.combatAddr^.attackPhase := savedPhase;
                        p^.combatAddr^.initiative := savedInit;
                        p^.combatAddr^.spellCast := savedSpell;
                        p^.combatAddr^.guarding := savedGuard;
                        p^.combatAddr^.movement := savedMove;
                        p^.combatAddr^.madeAttack := savedMade;
                        p^.combatAddr^.sweepBudget := savedSweep;
                      end;
                      if creature^.enabled <> 0 then
                        CharDisp.CombatPrintCreatureInfo(creature);
                    end;
      end;
end;

{ Flee: automatic when the target list (range 255) holds no enemy; otherwise it succeeds when the creature's movement in
  whole moves beats the fastest enemy's (HighestEnemyMovement), on 1 in 2 when they tie. Success takes it out of play as
  'Got Away' (C_STATUS.RUNNING). EndActions runs on both outcomes and supplies the result. }
function CombatFleeAttempt(creature: Types.PCharRecord): Boolean;
var
  ok: Boolean;
  enemyMove: Byte;
  halfMove: Byte;
begin
  ok := False;
  if CbtMap.CountTargets(creature, 255) = 0 then
    ok := True
  else begin
    halfMove := CbtActs.CalcCreatureMovement(creature) div 2;
    enemyMove := CbtActs.HighestEnemyMovement(creature);
    if enemyMove < halfMove then
      ok := True
    else if enemyMove = halfMove then
      if Dice.RollDice(1, 2) = 1 then
        ok := True;
  end;
  if ok then
    FxEngine.PutOutOfPlayWithStatus(creature, C_STATUS.RUNNING, 'Got Away')
  else
    CharDisp.PrintBottomLine('Escape is blocked');
  CombatFleeAttempt := CharHlp.EndActions(creature);
end;

{ Set curAttacks for the round. Start from the weapon's rate of fire (at least 2) for a damaging ranged weapon, else the
  base attacks, both in half-attacks; apply haste/slow effects, then AdjustedAttacks (odd rounds round up, then halve)
  and cap a ranged weapon by its ammunition. Once an attack has been made the result is used only when it is below the
  previous curAttacks (melee: below twice it); otherwise curAttacks keeps the previous value. }
procedure SetCurAttacksX2(creature: Types.PCharRecord);
var
  adj: Byte;
  saved: Byte;
  qty: Byte;
  rof: Byte;
  ranged: Boolean;
  weapon: Types.PItemRec;
begin
  ranged := False;
  saved := creature^.curAttacks;
  if CharHlp.HasRangedWeapon(creature) and CharHlp.FindDamagingRangedWeapon(creature, weapon) then begin
    ranged := True;
    rof := CharHlp.BaseItem(creature^.equipped[C_EQUIP.WEAPON]^.itemType)^.rateOfFire;
    if rof < 2 then
      rof := 2;
    GameVars.currentAttackCurrent := rof;
  end else
    GameVars.currentAttackCurrent := creature^.attacks;
  GameVars.currentCreatureCalculatingFlag := 0;
  FxEngine.TriggerEffectsWithCondition(C_COND.MOVE_ATTACK_RATE, creature);
  adj := CbtActs.AdjustedAttacks(GameVars.currentAttackCurrent);
  if ranged and (weapon <> nil) then begin
    qty := 1;
    if weapon^.quantity > qty then
      qty := weapon^.quantity;
    if qty < adj then
      { ammo-limited }
      adj := qty;
  end;
  if (creature^.combatAddr^.madeAttack = 0) or (adj < saved)
     or ((creature^.combatAddr^.madeAttack <> 0) and (adj < saved * 2) and (not ranged)) then
    creature^.curAttacks := adj;
end;

{ Half-attacks to attacks: add 1 on odd rounds, then halve. }
function AdjustedAttacks(n: Byte): Byte;
var
  v: Byte;
begin
  v := n;
  if Odd(GameVars.roundCounter) then
    Inc(v);
  AdjustedAttacks := v div 2;
end;

{ Sweep sub-1-HD foes: when def is an adjacent level-0 foe, the sweep budget (attack level) exceeds the current attacks
  and more adjacent level-0 enemies stand around than there are current attacks, make one attack on each of up to
  sweepBudget of them, def first. Returns True if it swept. }
function SweepAttempt(att, def: Types.PCharRecord): Boolean;
var
  cnt: Byte;
  weak: Byte;
  i: Byte;
  defIdx: Byte;
  p: Types.PCharRecord;
begin
  SweepAttempt := False;
  if att^.curAttacks >= att^.combatAddr^.sweepBudget then
    Exit;
  if def^.levelHighest <> 0 then
    Exit;
  if CbtMap.CalcDistance(att, def) <> 1 then
    Exit;
  cnt := CbtMap.CountTargets(att, 1);
  weak := 0;
  defIdx := 0;
  for i := 1 to cnt do begin
    p := GameVars.creatureArr[GameVars.potentialTargetCreature[i]];
    if p = def then
      defIdx := i;
    if p^.levelHighest = 0 then
      Inc(weak);
  end;
  { def is not in the enemy list (an ally, such as an animated corpse): no sweep }
  if defIdx = 0 then
    Exit;
  if weak <= att^.curAttacks then
    Exit;
  if weak > att^.combatAddr^.sweepBudget then
    weak := att^.combatAddr^.sweepBudget;
  CharDisp.PrintNameString(att, 'sweeps', 10, True);
  { def becomes the first sweep target }
  p := GameVars.creatureArr[GameVars.potentialTargetCreature[1]];
  if p <> def then begin
    GameVars.potentialTargetCreature[defIdx] := GameVars.potentialTargetCreature[1];
    GameVars.potentialTargetCreature[1] := CbtMap.CombatSlot(def);
  end;
  for i := 1 to cnt do
    if weak > 0 then
      if GameVars.creatureArr[GameVars.potentialTargetCreature[i]]^.levelHighest = 0 then begin
        p := GameVars.creatureArr[GameVars.potentialTargetCreature[i]];
        CbtActs.NoteAttackDirection(att, p);
        att^.curAttacks := 1;
        CbtActs.CombatAttack(att, p, False, nil, doneRoundFlag);
        Dec(weak);
      end;
  SweepAttempt := True;
end;

{ Check whether effects permit creature to attack other: False for nil, True for itself. Otherwise the target's veto
  effects run first, then the attacker's with other as its temporary target; any veto sets
  currentSuppressTargetingFlag. }
function CanAttackTarget(creature, other: Types.PCharRecord): Boolean;
var
  saved: Types.PCharRecord;
begin
  CanAttackTarget := False;
  if other = nil then
    Exit;
  if creature = other then begin
    CanAttackTarget := True;
    Exit;
  end;
  currentSuppressTargetingFlag := 0;
  FxEngine.TriggerEffectsWithCondition(C_COND.TARGET_VETO, other);
  if currentSuppressTargetingFlag = 0 then begin
    saved := creature^.combatAddr^.other;
    creature^.combatAddr^.other := other;
    FxEngine.TriggerEffectsWithCondition(C_COND.ATTACKER_VETO, creature);
    creature^.combatAddr^.other := saved;
  end;
  CanAttackTarget := currentSuppressTargetingFlag = 0;
end;

{ Turn undead at CbtActs.TurnLevel: one d20 roll against the turning table, applied to up to 1d12 targets (lowest-level
  undead first) until a target resists. }
procedure CombatTurnUndead(creature: Types.PCharRecord);
const
  { Turning table by undead level (row) and cleric level (column: levels 1..8 one each, then 9..13, then 14+). Roll
    d20 >= Abs(value): positive values turn, zero or negative values destroy. 1 turns automatically, 0 destroys
    automatically, and 99 is immune. A negative result extends exhausted attempts until six successes. An undead level
    above 10 (CbtActs.FindTurnUndeadTarget admits up to 12) is read from row 10. }
  turnTable: Types.TTurnUndeadTable = (
    { 1: Skeleton }
    (10, 7, 4, 1, 1, 0, 0, -1, -1, -1),
    { 2: Zombie }
    (13, 10, 7, 1, 1, 0, 0, 0, -1, -1),
    { 3: Ghoul }
    (16, 13, 10, 4, 1, 1, 0, 0, 0, -1),
    { 4: Shadow }
    (19, 16, 13, 7, 4, 1, 1, 0, 0, -1),
    { 5: Wight }
    (20, 19, 16, 10, 7, 4, 1, 1, 0, 0),
    { 6: Ghast }
    (99, 20, 19, 13, 10, 7, 4, 1, 1, 0),
    { 7: Wraith }
    (99, 99, 20, 16, 13, 10, 7, 4, 1, 0),
    { 8: Mummy }
    (99, 99, 99, 20, 16, 13, 10, 7, 4, 1),
    { 9: Spectre }
    (99, 99, 99, 99, 20, 16, 13, 10, 7, 1),
    { 10: Vampire }
    (99, 99, 99, 99, 99, 20, 16, 13, 10, 4));
var
  roll: Byte;
  attempts: Byte;
  destroys: Byte;
  turnVal: ShortInt;
  any: Boolean;
  stop: Boolean;
  tgt: Pointer;
  col: ShortInt;
  row: ShortInt;
begin
  CharDisp.PrintNameString(creature, 'turns undead...', 10, False);
  TextRend.ClearBottomLine;
  TextRend.PauseOnly;
  any := False;
  stop := False;
  creature^.combatAddr^.usedTurnUndead := 1;
  destroys := 6;
  attempts := Dice.RollDice(1, 12);
  roll := Dice.RollDice(1, 20);
  case CbtActs.TurnLevel(creature) of
    1..8: col := CbtActs.TurnLevel(creature);
    9..13: col := 9;
  else
    col := 10;
  end;
  while CbtActs.FindTurnUndeadTarget(creature, tgt) and (attempts > 0)
        and (stop = False) do begin
    { FindTurnUndeadTarget admits undead levels up to 12; the table's rows stop at 10 }
    row := Types.PCharRecord(tgt)^.levelUndead;
    if row > 10 then
      row := 10;
    turnVal := turnTable[row, col];
    if roll >= Abs(turnVal) then begin
      any := True;
      CbtMap.DisplayMapViewCentered(Types.PCharRecord(tgt), 3, False);
      CharDisp.CombatPrintCreatureInfo(Types.PCharRecord(tgt));
      if turnVal > 0 then begin
        Types.PCharRecord(tgt)^.combatAddr^.turned := 1;
        CharDisp.PrintNameStringAnim(Types.PCharRecord(tgt), True, 'is turned');
      end else begin
        CharDisp.PrintNameString(Types.PCharRecord(tgt), 'Is destroyed', 10, False);
        CbtMap.CreatureDowned(Types.PCharRecord(tgt));
        Types.PCharRecord(tgt)^.status := C_STATUS.GONE;
        Types.PCharRecord(tgt)^.enabled := 0;
      end;
      if destroys > 0 then
        Dec(destroys);
      Dec(attempts);
      if attempts = 0 then
        if destroys > 0 then
          if turnVal < 0 then
            { extend while below six successes }
            Inc(attempts);
      CharDisp.ClearMessageWindow;
    end else
      stop := True;
  end;
  if not any then
    CharDisp.PrintBottomLine('Nothing Happens...');
  CharHlp.CountTeams;
  doneRoundFlag := CharHlp.EndActions(creature);
  CharDisp.ClearMessageWindow;
end;

function TurnLevel(creature: Types.PCharRecord): ShortInt;
var
  lvl: ShortInt;
begin
  lvl := creature^.classLevels[C_LEVEL.CLERIC];
  if creature^.classLevels[C_LEVEL.PALADIN] - 2 > lvl then
    lvl := creature^.classLevels[C_LEVEL.PALADIN] - 2;
  if lvl < 0 then
    lvl := 0;
  TurnLevel := lvl;
end;

{ The lowest-level unturned undead in the target list (any range); equal levels keep the earlier, nearer one. }
function FindTurnUndeadTarget(creature: Types.PCharRecord; var tgt: Pointer): Boolean;
var
  cnt: Byte;
  i: Byte;
  best: ShortInt;
  p: Types.PCharRecord;
begin
  best := 13;
  tgt := nil;
  cnt := CbtMap.CountTargets(creature, 255);
  FindTurnUndeadTarget := False;
  for i := 1 to cnt do begin
    p := GameVars.creatureArr[GameVars.potentialTargetCreature[i]];
    if (p^.combatAddr^.turned = 0) and (p^.levelUndead > 0)
       and (p^.levelUndead < best) then begin
      best := p^.levelUndead;
      tgt := p;
      FindTurnUndeadTarget := True;
    end;
  end;
end;

{ Resolve att's remaining attacks on def. A helpless defender is slain with one blow (hp + 5 damage) and all attacks are
  spent. Otherwise use the large-target dice against a large defender and pick the defense: backstab, acBehind - 2; from
  behind (fromBehind, or flanked by more than one attacker with att at its back and a flank spread above 4), the rear
  AC. Add range penalties, roll the attacks from attackPhase down to 1 until def drops, and spend the sweep budget. A
  hit on a defender with Mirror Image (C_EFFECT.MIRROR_IMAGE) strikes an image unless 1d(images + 1) rolls 1: it shows
  as a miss, the defender loses the image and the blow does no damage and has no on-hit effects. With no attacks left,
  att's actions end. The blows' sounds are of the Settings screen's ranged kind for a ranged attack, else melee. }
procedure DoAttack(att, def: Types.PCharRecord; fromBehind, ranged: Boolean; var done: Boolean);
var
  base: Types.TBaseItemRec;
  anyHit: Boolean;
  defDowned: Boolean;
  behind: Boolean;
  defense: Byte;
  phase: Byte;
  startPhase: Byte;
  atkType: Byte;
  behindIdx: ShortInt;
  image: Types.PEffectRec;
  slay: Byte;
  { the Settings screen's kind for the blows' sounds }
  group: Byte;
begin
  if ranged then
    group := C_SOUND.GROUP_RANGED
  else
    group := C_SOUND.GROUP_MELEE;
  behind := fromBehind;
  done := False;
  hitsMade[1] := 0;
  hitsMade[2] := 0;
  attacksMade[1] := 0;
  attacksMade[2] := 0;
  anyHit := False;
  defDowned := False;
  GameVars.pendingDamage := 0;
  att^.combatAddr^.madeAttack := 1;
  if CharHlp.IsHelpless(def) then begin
    SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.IMPACT], group);
    { phase 1 is curAtt's lower bound }
    while (att^.combatAddr^.attackPhase > 1)
          and (Types.PAttackPhaseView(att)^.curAtt[att^.combatAddr^.attackPhase] = 0) do
      Dec(att^.combatAddr^.attackPhase);
    Inc(attacksMade[att^.combatAddr^.attackPhase]);
    { hp + 5, held to the Byte }
    if def^.hpCur > 250 then
      slay := 255
    else
      slay := def^.hpCur + 5;
    CbtActs.ProcessAttackResult(att, def, 3, slay, 1, True);
    FxEngine.RemoveInvisibility(att);
    { 2 = curAtt's upper bound }
    for phase := 1 to 2 do
      Types.PAttackPhaseView(att)^.curAtt[phase] := 0;
    anyHit := True;
    done := True;
  end else begin
    if (att^.equipped[C_EQUIP.WEAPON] <> nil) and (def^.iconDimensions and Types.ICON_LARGE <> 0) then begin
      { large target: swap in the large-damage dice. SSI's took any creature with a two-tile icon for Large, so wolves,
        wild boars and basilisks took them (#748). }
      base := CharHlp.BaseItem(att^.equipped[C_EQUIP.WEAPON]^.itemType)^;
      att^.curRollsA[1] := base.dmgLgRolls;
      att^.curDiceA[1] := base.dmgLgDice;
      att^.curModA[1] := att^.curModA[1] - base.dmgSmMod + base.dmgLgMod;
    end;
    CharHlp.RecalcStats(def);
    FxEngine.TriggerEffectsWithCondition(C_COND.DEFENDER_AC, def);
    behindIdx := 0;
    if CbtActs.IsBackstab(att, def) then
      defense := def^.acBehind - 2
    else begin
      if def^.combatAddr^.flankCount > 1 then
        if (CbtActs.DirTowardTarget(att, def) = def^.combatAddr^.direction)
           and (def^.combatAddr^.flankSpread > 4) then
          behind := True;
      if behind then
        behindIdx := 1;
      defense := Types.PAttackPhaseView(def)^.acCurArr[behindIdx];
    end;
    CbtActs.ModifyDefenseForDistance(att, def, defense);
    atkType := 0;
    if behind then
      atkType := 1;
    if CbtActs.IsBackstab(att, def) then
      atkType := 2;
    startPhase := att^.combatAddr^.attackPhase;
    { the downto's own entry guard covers startPhase < 1 }
    for phase := startPhase downto 1 do
      while (Types.PAttackPhaseView(att)^.curAtt[phase] > 0)
            and (defDowned = False) do begin
        Dec(Types.PAttackPhaseView(att)^.curAtt[phase]);
        att^.combatAddr^.attackPhase := phase;
        Inc(attacksMade[phase]);
        if FxEngine.AttackRoll(att, def, defense) or CharHlp.IsHelpless(def) then begin
          anyHit := True;
          if CharHlp.HasEffect(def, C_EFFECT.MIRROR_IMAGE, image)
             and (Dice.RollDice(1, image^.strength + 1) > 1) then begin
            { the blow strikes an image }
            SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.MISS], group);
            CbtActs.ProcessAttackResult(att, def, atkType, 0, 0, False);
            CharDisp.PrintNameString(def, 'lost an image', 10, True);
            Dec(image^.strength);
            if image^.strength = 0 then
              FxEngine.RemoveEffect(def, C_EFFECT.MIRROR_IMAGE, nil);
          end else begin
            Inc(hitsMade[phase]);
            SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.IMPACT], group);
            CbtActs.CalcWeaponDamage(att, def, phase);
            CbtActs.ProcessAttackResult(att, def, atkType, GameVars.pendingDamage, GameVars.pendingDamage, True);
            if def^.enabled <> 0 then
              { C_COND.HIT_PHASE_1/2 }
              FxEngine.TriggerEffectsWithCondition(phase + 1, att);
            if def^.enabled = 0 then
              defDowned := True;
          end;
        end;
      end;
    if not anyHit then begin
      SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.MISS], group);
      CbtActs.ProcessAttackResult(att, def, atkType, 0, 0, False);
    end;
    done := True;
    { 2 = curAtt's upper bound }
    for phase := 1 to 2 do
      if Types.PAttackPhaseView(att)^.curAtt[phase] > 0 then
        done := False;
    { sweep budget spent }
    att^.combatAddr^.sweepBudget := 0;
  end;
  if done then
    done := CharHlp.EndActions(att);
end;

{ The flanking accumulator: count attacks on def (flankCount) and add each attacker's angular offset from def's facing
  (0..4) into flankSpread (mod 8). DoAttack's from-behind test and IsBackstab read them; they reset when def moves and
  at the start of its turn. }
procedure NoteAttackDirection(att, def: Types.PCharRecord);
var
  rel: Byte;
  d: Byte;
begin
  Inc(def^.combatAddr^.flankCount);
  d := CbtActs.DirTowardTarget(def, att);
  rel := (d - def^.combatAddr^.direction + 8) mod 8;
  if rel > 4 then
    rel := 8 - rel;
  def^.combatAddr^.flankSpread := (def^.combatAddr^.flankSpread + rel) mod 8;
end;

{ The public attack wrapper. def turns to face att (unless fromBehind or already attacked three times) and att turns and
  animates, with a missile flight for weapon and for an equipped sling. If attacks remain, DoAttack runs; weapon (the
  missile or thrown item, nil for melee) then loses attacksMade[1] from its quantity, and once used up it is removed, an
  expended thrown weapon other than a spirit hammer dropping into the treasure pile. }
procedure CombatAttack(att, def: Types.PCharRecord; fromBehind: Boolean; weapon: Types.PItemRec; var done: Boolean);
var
  item: Types.PItemRec;
  savedCur: Types.PCharRecord;
  dir: Byte;
  { a missile or thrown weapon, or an equipped sling: the attack is ranged }
  ranged: Boolean;
begin
  ranged := weapon <> nil;
  if (def^.combatAddr^.flankCount < 3) and (not fromBehind) then begin
    dir := CbtActs.DirTowardTarget(def, att);
    if CbtMap.CombatIconVisible(def, 0) then
      CbtMap.SetCreatureFacing(def, dir, 0, 0)
    else
      def^.combatAddr^.direction := dir;
  end;
  dir := CbtActs.DirTowardTarget(att, def);
  CharDisp.CombatPrintCreatureInfo(att);
  CbtMap.SetCreatureFacing(att, dir, 1, 0);
  att^.combatAddr^.other := def;
  Delay(100);
  if weapon <> nil then
    CbtActs.RangedAttackAnim(att, def, weapon);
  { a sling's stone animates a second time }
  if (att^.equipped[C_EQUIP.WEAPON] <> nil) and (att^.equipped[C_EQUIP.WEAPON]^.itemType = C_ITEM.SLING) then begin
    CbtActs.RangedAttackAnim(att, def, att^.equipped[C_EQUIP.WEAPON]);
    ranged := True;
  end;
  done := True;
  if (att^.curAttacks > 0) or (att^.curAttacks2 > 0) then begin
    savedCur := GameVars.curChar;
    GameVars.curChar := att;
    CbtActs.DoAttack(att, def, fromBehind, ranged, done);
    if weapon <> nil then begin
      if weapon^.quantity > 0 then
        Dec(weapon^.quantity, attacksMade[1]);
      if weapon^.quantity = 0 then
        if CharHlp.HasThrowableWeapon(att) and (weapon^.special <> C_EFFECT.SPIRIT_HAMMER_GONE) then begin
          { the expended thrown weapon drops into the loot pile }
          CharHlp.PrependItemCopy(GameVars.treasureItems, weapon);
          item := GameVars.treasureItems;
          item^.equipped := 0;
          CharHlp.RemoveItem(att, weapon);
          GameVars.lastMissileItem := item;
        end else
          CharHlp.RemoveItem(att, weapon);
    end;
    CharHlp.RecalcStats(att);
    GameVars.curChar := savedCur;
  end;
  if done then
    done := CharHlp.EndActions(att);
  if CbtMap.CombatIconVisible(att, 0) then begin
    CbtMap.SetCreatureFacing(att, att^.combatAddr^.direction, 1, 1);
    CbtMap.SetCreatureFacing(att, att^.combatAddr^.direction, 0, 0);
  end;
end;

{ Range penalty: with a ranged weapon the subrange is (range - 1) div 3, and defense rises by 2 beyond one subrange and
  by 3 more beyond two. Melee adds nothing. }
procedure ModifyDefenseForDistance(att, def: Types.PCharRecord; var defense: Byte);
var
  subrange: ShortInt;
  dist: ShortInt;
begin
  dist := CbtMap.CalcDistance(att, def);
  if CharHlp.HasRangedWeapon(att) then
    subrange := (CharHlp.BaseItem(att^.equipped[C_EQUIP.WEAPON]^.itemType)^.range - 1) div 3
  else
    subrange := dist;
  if dist - subrange > 0 then begin
    dist := dist - subrange;
    defense := defense + 2;
  end;
  if dist - subrange > 0 then begin
    dist := dist - subrange;
    { cumulative with the first +2 }
    defense := defense + 3;
  end;
end;

{ Cure Light Wounds target in the creature's own cell or the 8 around it. Candidates: the wounded ally with the fewest
  hp (the creature itself, checked last, also wins whenever below half its max) and the last downed, not dead body of
  its own side found on a corpse cell. The body wins unless there is none or the ally has 7 hp or fewer. }
function FindCureTarget(creature: Types.PCharRecord; var tgt: Pointer): Boolean;
var
  best: Pointer;
  nx: ShortInt;
  ny: ShortInt;
  downIdx: Byte;
  bestHp: Byte;
  d: Byte;
  j: Byte;
  crIdx: Byte;
  terrIdx: Byte;
begin
  best := nil;
  downIdx := 0;
  bestHp := 255;
  for d := 0 to C_DIR.CENTER do begin
    nx := CbtMap.CombatCellX(creature) + GameDefs.dirDX[d];
    ny := CbtMap.CombatCellY(creature) + GameDefs.dirDY[d];
    CbtMap.GetArenaContents(nx, ny, crIdx, terrIdx);
    if crIdx > 0 then begin
      { the var param is the scratch }
      tgt := GameVars.creatureArr[crIdx];
      if Types.PCharRecord(tgt)^.hostile = creature^.hostile then
        if Types.PCharRecord(tgt)^.hpCur < Types.PCharRecord(tgt)^.hpMax then
          if (Types.PCharRecord(tgt)^.hpCur < bestHp)
             or ((tgt = creature) and (Types.PCharRecord(tgt)^.hpCur < Types.PCharRecord(tgt)^.hpMax div 2)) then begin
            best := tgt;
            bestHp := Types.PCharRecord(tgt)^.hpCur;
          end;
    end else if terrIdx = C_TERR.CORPSE then
      for j := 1 to GameVars.downedCount do
        if GameVars.downed[j].cr <> nil then
          if not (GameVars.downed[j].cr^.status in
                  [C_STATUS.DEAD, C_STATUS.STONED, C_STATUS.GONE]) then
            if GameVars.downed[j].x = nx then
              if GameVars.downed[j].y = ny then
                { a body of its own side only: downed holds the party's, which a hostile cleric healed (#714) }
                if GameVars.downed[j].cr^.hostile = creature^.hostile then
                  downIdx := j;
  end;
  if (bestHp < 8) or (downIdx = 0) then
    tgt := best
  else
    tgt := GameVars.downed[downIdx].cr;
  if tgt <> nil then
    FindCureTarget := True
  else
    FindCureTarget := False;
end;

{ Pick one spell target. Manual: the spell-mode aim menu, which also locks the target. AI: a non-offensive spell targets
  the caster (Cure Light Wounds: FindCureTarget's pick); an offensive one makes up to 20 AcquireTarget picks, vetoing
  any with a non-enemy within aiRadius of it, or that is helpless when the spell's effect is one of helplessFx. On
  success set gTargetX/gTargetY; on failure clear tgt. }
function PickSpellTarget(spell: Byte; ai: Boolean; ground: Byte; var tgt: Types.TAimTarget): Boolean;
var
  found: Boolean;
  ok: Boolean;
  p: Types.PCharRecord;
  i: Byte;
  tries: Byte;
begin
  found := False;
  if not ai then begin
    CbtActs.CombatAimMenu(GameVars.curChar, CharHlp.CalcSpellRange(spell), 0, ground, found, tgt);
    GameVars.curChar^.combatAddr^.other := tgt.cr;
  end else begin
    if GameDefs.spellTable[spell].offensive = 0 then begin
      tgt.cr := GameVars.curChar;
      if (spell <> C_SPELL.CURE_LIGHT_WOUNDS) or CbtActs.FindCureTarget(GameVars.curChar, tgt.cr) then begin
        tgt.x := CbtMap.CombatCellX(tgt.cr);
        tgt.y := CbtMap.CombatCellY(tgt.cr);
        found := True;
      end;
    end else begin
      tries := 20;
      while (tries > 0) and (found = False) do begin
        ok := True;
        if CbtActs.AcquireTarget(GameVars.curChar, CharHlp.CalcSpellRange(spell), 0, 1) then begin
          p := GameVars.curChar^.combatAddr^.other;
          if GameDefs.spellTable[spell].aiRadius > 0 then begin
            if CbtActs.AreaHitsNonEnemy(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p),
                                        GameDefs.spellTable[spell].aiRadius) then
              ok := False;
          end;
          if CharHlp.IsHelpless(p) then
            for i := 1 to SizeOf(GameDefs.helplessFx) div SizeOf(GameDefs.helplessFx[1]) do
              if GameDefs.spellTable[spell].effect = GameDefs.helplessFx[i] then
                ok := False;
          if ok then begin
            tgt.cr := GameVars.curChar^.combatAddr^.other;
            tgt.x := CbtMap.CombatCellX(tgt.cr);
            tgt.y := CbtMap.CombatCellY(tgt.cr);
            found := True;
          end;
        end;
        Dec(tries);
      end;
    end;
  end;
  if found then begin
    PickSpellTarget := True;
    Magic.gTargetX := tgt.x;
    Magic.gTargetY := tgt.y;
  end else begin
    PickSpellTarget := False;
    FillChar(tgt, SizeOf(tgt), 0);
  end;
end;

{ The sprite cell the spell-aim preview marks a spell's cells with: the spell missile for a hostile spell (spellTable
  offensive 1 and target 0), otherwise the sparkle. A spell outside the table sparkles. }
function AimMarker(spell: Byte): Byte;
begin
  AimMarker := SPRITE_SPARKLE;
  if (spell >= 1) and (spell <= SizeOf(GameDefs.spellTable) div SizeOf(GameDefs.spellTable[1])) then
    if (GameDefs.spellTable[spell].offensive = 1) and (GameDefs.spellTable[spell].target = 0) then
      AimMarker := SPRITE_MISSILE;
end;

{ The cast-target menu in combat (GameVars.castTargetMenu): build the spell-target list from the low nibble of the
  spell's area. 0: the caster; 15: the picked creature (a bare cell gets a zero-radius area); 8..14: everything within
  area and 7 of the picked cell; 1..7: (area and 3) + 1 individual picks. b is the AI flag, passed to PickSpellTarget.
  While the player aims, the CbtMap spell-aim preview shows the cells the spell will reach. }
procedure CombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);
var
  remaining: Byte;
  k: Byte;
  j: Byte;
  sel: Types.TAimTarget;
  dup: Boolean;
  radius: Byte;
  picked: Boolean;
begin
  cast := True;
  GameVars.spellTargetCount := 0;
  GameVars.gMultiTarget := 0;
  Magic.gTargetX := CbtMap.CombatCellX(GameVars.curChar);
  Magic.gTargetY := CbtMap.CombatCellY(GameVars.curChar);
  case GameDefs.spellTable[spell].area and $F of
    0:
      { self only }
      begin
        GameVars.targetCreaturePtr[1] := GameVars.curChar;
        GameVars.spellTargetCount := 1;
      end;
    15:
      { the picked creature, or an area at the picked cell }
      begin
        if not b then
          CbtMap.StartSpellPreview(Types.AimBlast, 0, CbtActs.AimMarker(spell));
        picked := CbtActs.PickSpellTarget(spell, b, 0, sel);
        CbtMap.StopSpellPreview;
        if picked then begin
          if GameVars.curChar^.combatAddr^.other <> nil then begin
            GameVars.targetCreaturePtr[1] := GameVars.curChar^.combatAddr^.other;
            GameVars.spellTargetCount := 1;
          end else begin
            { radius 0: the picked cell alone }
            Pathing.TargetArea(Magic.gTargetX, Magic.gTargetY, 0);
            GameVars.gMultiTarget := 1;
          end;
        end else
          cast := False;
      end;
    8..14:
      { fixed radius, ground OK }
      begin
        { Preview the spell while the player aims: Lightning Bolt's path, Stinking Cloud's 2x2 block (its handler
          ignores the table radius), or the blast at the table radius (a fireball bursts in flame, and FireballHandler
          uses radius 2 when view3dFlag is clear). }
        if not b then begin
          radius := GameDefs.spellTable[spell].area and 7;
          if spell = C_SPELL.LIGHTNING_BOLT then
            CbtMap.StartSpellPreview(Types.AimBolt, 0, SPRITE_LIGHTNING)
          else if spell = C_SPELL.STINKING_CLOUD then
            CbtMap.StartSpellPreview(Types.AimCloud, 0, SPRITE_SPARKLE)
          else if (spell = C_SPELL.FIREBALL) or (spell = C_SPELL.ITEM_FIREBALL) then begin
            if GameVars.zone0^.view3dFlag = 0 then
              radius := 2;
            CbtMap.StartSpellPreview(Types.AimBlast, radius, SPRITE_BURST);
          end else
            CbtMap.StartSpellPreview(Types.AimBlast, radius, CbtActs.AimMarker(spell));
        end;
        picked := CbtActs.PickSpellTarget(spell, b, 1, sel);
        CbtMap.StopSpellPreview;
        if picked then begin
          Pathing.TargetArea(Magic.gTargetX, Magic.gTargetY, GameDefs.spellTable[spell].area and 7);
          GameVars.gMultiTarget := 1;
        end else
          cast := False;
      end;
  else
    { 1..7: (area and 3) + 1 individual targets }
    begin
      remaining := (GameDefs.spellTable[spell].area and 3) + 1;
      k := 0;
      while remaining > 0 do begin
        if not b then
          CbtMap.StartSpellPreview(Types.AimBlast, 0, CbtActs.AimMarker(spell));
        picked := CbtActs.PickSpellTarget(spell, b, 0, sel);
        CbtMap.StopSpellPreview;
        if picked then begin
          dup := False;
          for j := 1 to k do
            if GameVars.targetCreaturePtr[j] = sel.cr then
              dup := True;
          if not dup then begin
            Inc(k);
            GameVars.targetCreaturePtr[k] := sel.cr;
            Dec(remaining);
          end else if not b then
            CharDisp.PrintBottomLine('Already been targeted')
          else
            Dec(remaining);
          CbtMap.RedrawArenaCell(CbtMap.CombatCellX(GameVars.targetCreaturePtr[k]),
                                 CbtMap.CombatCellY(GameVars.targetCreaturePtr[k]));
        end else
          Dec(remaining);
      end;
      GameVars.spellTargetCount := k;
      if k = 0 then
        cast := False;
    end;
  end;
end;

{ Pick (C_SPELL.NONE: from the Cast list) and validate a spell, rejecting camp-only ones. A casting time (castTime div
  3) of 0 casts it now and ends the caster's actions; otherwise the caster "Begins Casting": spellCast holds the spell
  and initiative drops by the casting time (to at least 1), so it resolves on a later action. A scroll spell picked from
  the list gets the same camp-only check, then is cast from its scroll as Use does (Magic.UseItemSpell), but named as a
  memorized spell is, followed by Use's stat and attack updates. }
procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);
var
  spellId: Byte;
  castTime: Byte;
  idx: Integer;
  notEmpty: Boolean;
  caster: Types.PCharRecord;
  scroll: Types.PItemRec;
begin
  caster := GameVars.curChar;
  notEmpty := True;
  idx := -1;
  cast := False;
  spellId := spell;
  scroll := nil;
  if spellId = C_SPELL.NONE then begin
    spellId := Magic.CastSpellMenu(idx, notEmpty, scroll);
    if spellId = C_SPELL.NONE then
      scroll := nil;
  end;
  if spellId > C_SPELL.NONE then
    if GameDefs.spellTable[spellId].whenCast = 0 then begin
      CharDisp.PrintBottomLine('Camp Only Spell');
      spellId := C_SPELL.NONE;
      scroll := nil;
    end;
  if scroll <> nil then begin
    Magic.UseItemSpell(scroll, spellId, True, cast);
    CharHlp.RecalcStats(caster);
    CbtActs.SetCurAttacksX2(caster);
    if not cast then
      CharDisp.DisplayCombatInterface;
    Exit;
  end;
  if ai = 0 then begin
    CharDisp.DisplayCombatInterface;
    CbtMap.DisplayMapViewCentered(caster, 3, True);
    CharDisp.CombatPrintCreatureInfo(caster);
  end;
  if spellId > C_SPELL.NONE then begin
    castTime := GameDefs.spellTable[spellId].castTime div 3;
    if castTime = 0 then begin
      Magic.CastSpellNC(spellId, Boolean(ai), True, cast);
      cast := CharHlp.EndActions(caster);
    end else begin
      cast := True;
      CharDisp.PrintNameString(caster, 'Begins Casting', 10, True);
      caster^.combatAddr^.spellCast := spellId;
      if caster^.combatAddr^.initiative > castTime then
        Dec(caster^.combatAddr^.initiative, castTime)
      else
        caster^.combatAddr^.initiative := 1;
    end;
  end;
end;

{ Backstabbing requires a thief in leather or no armor and with no shield (ClassCal.ArmorBarsThiefSkills), using a club,
  dagger, broad, long or short sword, or no weapon. The target must have been attacked more than once this round and
  face away from the attacker. }
function IsBackstab(att, def: Types.PCharRecord): Boolean;
var
  weapon: Types.PItemRec;
  wItem: Byte;
  can: Boolean;
begin
  can := False;
  weapon := att^.equipped[C_EQUIP.WEAPON];
  if weapon <> nil then
    wItem := weapon^.itemType;
  if att^.classLevels[C_LEVEL.THIEF] > 0 then
    if not ClassCal.ArmorBarsThiefSkills(att) then
      if (weapon = nil) or (wItem = C_ITEM.CLUB) or (wItem = C_ITEM.DAGGER)
         or ((wItem >= C_ITEM.BROAD_SWORD) and (wItem <= C_ITEM.SHORT_SWORD)) then
        can := True;
  if can and (def^.combatAddr^.flankCount > 1)
     and (CbtActs.DirTowardTarget(att, def) = def^.combatAddr^.direction) then
    IsBackstab := True
  else
    IsBackstab := False;
end;

{ The first direction 0..7 whose cone (Pathing.IsDirToward) holds the other creature's cell; the same cell gives 0. }
function DirTowardTarget(creature, other: Types.PCharRecord): Byte;
var
  d: Byte;
  x1: ShortInt;
  y1: ShortInt;
  x2: ShortInt;
  y2: ShortInt;
begin
  x1 := CbtMap.CombatCellX(creature);
  y1 := CbtMap.CombatCellY(creature);
  x2 := CbtMap.CombatCellX(other);
  y2 := CbtMap.CombatCellY(other);
  d := 0;
  while not Pathing.IsDirToward(x1, y1, x2, y2, d) do
    Inc(d);
  DirTowardTarget := d;
end;

{ Build the missile icon for weapon's type and fly it from att to def between the ranged-attack sounds. }
procedure RangedAttackAnim(att, def: Types.PCharRecord; weapon: Types.PItemRec);
var
  sym: Byte;
  frames: Byte;
  dir: Byte;
  pace: Byte;
  size: Word;
begin
  dir := CbtActs.DirTowardTarget(att, def);
  frames := 1;
  pace := 10;
  sym := 13;
  size := Blit.MaskBytes(GameVars.moveIconSheet^.imgSize);
  case weapon^.itemType of
    { straight-flying missiles }
    C_ITEM.DART, C_ITEM.JAVELIN, C_ITEM.QUARREL, C_ITEM.SPEAR, C_ITEM.ARROW:
      if Odd(dir) then begin
        if (dir = C_DIR.SOUTHEAST) or (dir = C_DIR.SOUTHWEST) then
          CharDisp.CopyIconFacing(sym + 1, 1, 0, dir = C_DIR.SOUTHWEST)
        else
          CharDisp.CopyIconFacing(sym + 1, 0, 0, dir = C_DIR.NORTHWEST);
      end else
        CharDisp.CopyIconFacing(sym + dir mod 4, dir div 4, 0, False);
    { spinning thrown weapons }
    C_ITEM.HAND_AXE, C_ITEM.CLUB, C_ITEM.HAMMER:
      begin
        CharDisp.BuildIconFacings(sym + 3);
        frames := 4;
        pace := 50;
      end;
    { holy water / oil flask }
    C_ITEM.HOLY_WATER_VIAL, C_ITEM.FLASK_OF_OIL:
      begin
        CharDisp.BuildIconFacings(sym + 4);
        frames := 4;
        pace := 50;
      end;
  else begin
      if weapon^.itemType = C_ITEM.SLING then
        Inc(sym);
      CharDisp.CopyIconFacing(sym + 7, 0, 0, False);
      CharDisp.CopyIconFacing(sym + 7, 1, 1, False);
      frames := 2;
      pace := 20;
    end;
  end;
  SoundDrv.SoundSetAutoStop(0);
  SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.RANGED_START], C_SOUND.GROUP_RANGED);
  CharDisp.CombatAnimateMovingIcon(CbtMap.CombatCellX(att), CbtMap.CombatCellY(att), CbtMap.CombatCellX(def),
                                  CbtMap.CombatCellY(def), frames, pace);
  SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.RANGED_END], C_SOUND.GROUP_RANGED);
  SoundDrv.SoundSetAutoStop(10);
end;

{ Set hostileHpPct to the enabled hostiles' current HP as a percentage of all hostiles' maximum HP, rounded down to a
  multiple of five; it is left unchanged when there are no hostiles. }
procedure CalcHostileHpPercent;
var
  maxSum: Word;
  curSum: Word;
  p: Types.PCharRecord;
begin
  maxSum := 0;
  curSum := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    if p^.hostile = 1 then begin
      if p^.enabled <> 0 then
        curSum := curSum + p^.hpCur;
      maxSum := maxSum + p^.hpMax;
    end;
    p := p^.nextCharAddr;
  end;
  if maxSum > 0 then
    { LongInt: curSum * 20 passes a Word above 3276 }
    hostileHpPct := LongInt(curSum) * 20 div maxSum * 5;
end;

{ The fastest enabled enemy's movement in whole moves (CalcCreatureMovement div 2); no range or line-of-sight check. }
function HighestEnemyMovement(creature: Types.PCharRecord): Byte;
var
  best: Byte;
  m: Byte;
  p: Types.PCharRecord;
begin
  best := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    if (CharHlp.EnemyTeam(creature) = p^.hostile) and (p^.enabled <> 0) then begin
      m := CbtActs.CalcCreatureMovement(p) div 2;
      if m > best then
        best := m;
    end;
    p := p^.nextCharAddr;
  end;
  HighestEnemyMovement := best;
end;

{ Confirm a physical attack on an ally (enemies and quick-fighting attackers pass unasked). Yes sets the GBVM
  attacked-allies flag, and every NPC-flagged creature in okay status turns hostile and drops its target. }
function CheckAttackAlly(att, def: Types.PCharRecord): Boolean;
var
  p: Types.PCharRecord;
begin
  if (CharHlp.EnemyTeam(def) = att^.hostile) or (att^.quickfight <> 0) then
    CheckAttackAlly := True
  else if MenuCore.YesNoMenu('Attack Ally: ', LightMagenta, LightGreen, White) <> 'Y' then
    CheckAttackAlly := False
  else begin
    CheckAttackAlly := True;
    GameVars.zone1^[C_GBVM.ATTACKED_ALLIES] := 1;
    p := GameVars.creatureList;
    while p <> nil do begin
      { NPC flag (high bit) set }
      if (p^.status = C_STATUS.OKAY) and CharHlp.IsNpc(p) then begin
        p^.hostile := 1;
        p^.combatAddr^.other := nil;
      end;
      p := p^.nextCharAddr;
    end;
    CharHlp.CountTeams;
  end;
end;

{ The direction a cursor key (an arrow, Home, End, Page Up or Page Down scan code) points, or C_DIR.CENTER for any other
  key. }
function DirOfKey(ch: Char): Byte;
begin
  case ch of
    C_KEYS.UP: DirOfKey := C_DIR.NORTH;
    C_KEYS.PGUP: DirOfKey := C_DIR.NORTHEAST;
    C_KEYS.RIGHT: DirOfKey := C_DIR.EAST;
    C_KEYS.PGDN: DirOfKey := C_DIR.SOUTHEAST;
    C_KEYS.DOWN: DirOfKey := C_DIR.SOUTH;
    C_KEYS.END_KEY: DirOfKey := C_DIR.SOUTHWEST;
    C_KEYS.LEFT: DirOfKey := C_DIR.WEST;
    C_KEYS.HOME: DirOfKey := C_DIR.NORTHWEST;
  else
    DirOfKey := C_DIR.CENTER;
  end;
end;

{ One aim-menu round on the target: center the view on it, show the range (weapon mode) and offer Target when it is in
  range (a weapon attack needs another creature, and a ranged weapon needs damaging ammunition plus either no adjacent
  enemy or a throwable weapon), then Next/Prev/Manual/Center/Exit. A cursor key (keypad digits included) returns through
  dir the direction it points, so the caller can switch to manual aim and move the cursor that way; any other choice
  sets dir to C_DIR.CENTER. ground is unused. }
function AimTargetMenu(cur, tgt: Types.PCharRecord; range, weaponMode, ground: Byte; var dir: Byte): Char;
var
  menu: String[40];
  ext: Boolean;
  weapon: Types.PItemRec;
  dist: Byte;
  ch: Char;
begin
  menu := '';
  dist := CbtMap.CalcDistance(cur, tgt);
  if weaponMode <> 0 then
    TextRend.DisplayString(0, 23, LightGreen, 'Range = ' + StrUtil.NumStr(dist) + '  ');
  if dist <= range then begin
    if weaponMode = 0 then
      menu := 'Target '
    else if cur <> tgt then begin
      if not CharHlp.HasRangedWeapon(cur) then
        menu := 'Target '
      else if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
        if (CbtMap.CountTargets(cur, 1) = 0) or CharHlp.HasThrowableWeapon(cur) then
          menu := 'Target ';
    end;
  end;
  menu := 'Next Prev Manual ' + menu + 'Center Exit';
  CbtMap.DisplayMapViewCentered(tgt, 3, True);
  CharDisp.CombatPrintCreatureInfo(tgt);
  repeat
    MenuCore.arrowsToCaller := True;
    ch := MenuCore.MenuHorizontal('Aim: ', menu, LightMagenta, LightGreen, White, True, False, ext);
    dir := C_DIR.CENTER;
    if ext then
      dir := CbtActs.DirOfKey(ch);
  until (not ext) or (dir <> C_DIR.CENTER);
  AimTargetMenu := ch;
end;

{ Confirm an aim selection. weaponMode=1 performs a weapon attack; 0 selects a spell target. An attack on an ally needs
  CheckAttackAlly's consent, else sel is cleared and done is False. The attack tries a sweep first; a throwable ranged
  weapon used at distance 1 strikes as melee (weapon nil). }
procedure ConfirmAttackTarget(cur, tgt: Types.PCharRecord; weaponMode: Byte; var done: Boolean;
                              var sel: Types.TAimTarget);
var
  weapon: Types.PItemRec;
begin
  weapon := nil;
  done := True;
  if weaponMode = 1 then
    if not CbtActs.CheckAttackAlly(cur, tgt) then
      done := False;
  if done then begin
    sel.cr := tgt;
    sel.x := CbtMap.CombatCellX(tgt);
    sel.y := CbtMap.CombatCellY(tgt);
    GameVars.arenaPtr^.cursorOn := False;
    CbtMap.ScrollView(GameVars.arenaPtr^.ox + 3, GameVars.arenaPtr^.oy + 3, 3, C_DIR.CENTER);
    if weaponMode = 1 then begin
      if CbtActs.SweepAttempt(cur, tgt) then
        done := CharHlp.EndActions(cur)
      else begin
        CbtActs.NoteAttackDirection(cur, tgt);
        if CharHlp.HasRangedWeapon(cur) then
          if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
            if CharHlp.HasThrowableWeapon(cur) then
              if CbtMap.CalcDistance(cur, tgt) = 1 then
                weapon := nil;
        CbtActs.CombatAttack(cur, tgt, False, weapon, done);
      end;
    end;
  end else
    FillChar(sel, SizeOf(sel), 0);
end;

{ The free cursor aim: the arrow-key scans move a cell cursor (clamped to the arena) from underCursor's cell, after a
  first step toward startDir (C_DIR.CENTER stays put), Pathing.WalkLine checks the line and range, Target takes a valid
  cell (a weapon attack goes through ConfirmAttackTarget), Center recenters and Exit/Escape cancels. A bare cell is
  valid only when ground is set. }
procedure ManualAimCursor(cur, underCursor: Types.PCharRecord; range, weaponMode, ground, startDir: Byte;
                          var done: Boolean; var sel: Types.TAimTarget);
var
  menu: String[40];
  ch: Char;
  weapon: Types.PItemRec;
  dir: Byte;
  j: Byte;
  wx: ShortInt;
  wy: ShortInt;
  cx: ShortInt;
  cy: ShortInt;
  crIdx: Byte;
  terrIdx: Byte;
  dist: Word;
  valid: Boolean;
begin
  FillChar(sel, SizeOf(sel), 0);
  cx := CbtMap.CombatCellX(underCursor);
  cy := CbtMap.CombatCellY(underCursor);
  ch := ' ';
  dir := startDir;
  done := False;
  GameVars.arenaPtr^.cursorOn := True;
  GameVars.arenaPtr^.cursorSize := 1;
  while not (ch in [C_KEYS.NONE, 'E', 'T']) do
  begin
    CbtMap.ScrollView(cx, cy, 3, dir);
    Inc(cx, GameDefs.dirDX[dir]);
    Inc(cy, GameDefs.dirDY[dir]);
    if cx < 0 then
      cx := 0;
    if cy < 0 then
      cy := 0;
    if cx > 49 then
      cx := 49;
    if cy > 24 then
      cy := 24;
    CbtMap.GetArenaContents(cx, cy, crIdx, terrIdx);
    valid := False;
    dist := 255;
    wx := cx;
    wy := cy;
    if Pathing.WalkLine(CbtMap.CombatCellX(cur), CbtMap.CombatCellY(cur), wx, wy, dist, GameVars.arenaPtr) then begin
      valid := True;
      if weaponMode <> 0 then
        TextRend.DisplayString(0, 23, LightGreen, 'Range = ' + StrUtil.NumStr(dist div 2) + '  ');
    end else if weaponMode <> 0 then
      Border.ClearBox(0, 23, 39, 23);
    dist := dist div 2;
    underCursor := nil;
    if valid then begin
      if crIdx > 0 then
        underCursor := GameVars.creatureArr[crIdx]
      else if terrIdx = C_TERR.CORPSE then
        for j := 1 to GameVars.downedCount do
          if GameVars.downed[j].x = cx then
            if GameVars.downed[j].y = cy then
              underCursor := GameVars.downed[j].cr;
    end;
    if underCursor <> nil then
      CharDisp.CombatPrintCreatureInfo(underCursor)
    else
      Border.ClearBox(23, 1, 38, 21);
    if (range < dist) or (GameDefs.terrainInfo[terrIdx].cost = 255) then
      valid := False;
    if underCursor <> nil then begin
      if not CbtActs.CanAttackTarget(cur, underCursor) then
        valid := False;
      if weaponMode = 1 then
        if (cur = underCursor)
           or ((crIdx = 0) and (terrIdx = C_TERR.CORPSE)) then
          valid := False
        else if CharHlp.HasRangedWeapon(cur) then
          if (not CharHlp.FindDamagingRangedWeapon(cur, weapon)) or
              ((CbtMap.CountTargets(cur, 1) > 0) and (not CharHlp.HasThrowableWeapon(cur))) then
            valid := False;
    end else if ground = 0 then
      valid := False;
    menu := 'Center Exit';
    if valid then
      menu := 'Target ' + menu;
    MenuCore.arrowsToCaller := True;
    ch := MenuCore.MenuHorizontal('(Use Cursor keys) ', menu, LightMagenta, LightGreen, White, True, False,
                                  doneRoundFlag);
    case ch of
      'T':
        begin
          GameVars.arenaPtr^.cursorOn := False;
          if valid then begin
            sel.x := cx;
            sel.y := cy;
            if underCursor <> nil then
              sel.cr := underCursor
            else
              sel.cr := nil;
            if weaponMode = 1 then
              CbtActs.ConfirmAttackTarget(cur, sel.cr, weaponMode, done, sel)
            else
              done := True;
          end;
          if (valid = False) or (done = False) then begin
            CbtMap.RedrawArenaCell(cx, cy);
            done := False;
            FillChar(sel, SizeOf(sel), 0);
          end;
        end;
      C_KEYS.NONE, 'E':
        begin
          CbtMap.RedrawArenaCell(cx, cy);
          FillChar(sel, SizeOf(sel), 0);
          done := False;
        end;
      'C':
        begin
          CbtMap.ScrollView(cx, cy, 0, C_DIR.CENTER);
          dir := C_DIR.CENTER;
        end;
    else
      dir := CbtActs.DirOfKey(ch);
    end;
  end;
end;

{ Run target selection, allowing cycling, manual aim and confirmation. tgt is a TAimTarget passed as an untyped var
  parameter. weaponMode is 1 for weapon attacks or 0 for spell casting. range 255 means the equipped weapon's range
  minus 1 (1 unarmed); targets the creature may not attack are skipped. }
procedure CombatAimMenu(creature: Types.PCharRecord; range, weaponMode, groundOk: Byte; var done: Boolean; var tgt);
var
  targets: array[1..72] of Types.TCombatTarget;
  effRange: Byte;
  tgtCount: Byte;
  curIdx: Byte;
  skipStep: ShortInt;
  menuStep: ShortInt;
  curX: ShortInt;
  curY: ShortInt;
  nextX: ShortInt;
  nextY: ShortInt;
  p: Types.PCharRecord;
  ch: Char;
  keyDir: Byte;

  { Build the parent routine's aiming list from targets within range 127. }
  procedure BuildAimTargets(c: Types.PCharRecord);
  var
    i: Byte;
  begin
    Pathing.BuildTargetList(CbtMap.CombatCellX(c), CbtMap.CombatCellY(c), 127, 255, CbtMap.GetIconSize(c),
                            GameVars.arenaPtr);
    tgtCount := GameVars.targetCount;
    for i := 1 to tgtCount do
      targets[i] := GameVars.targetList[i];
  end;

  { Move the aim highlight step entries through the list (wrapping) and return that creature; animate flies the cursor
    from the current target, otherwise the old cursor cell is redrawn. }
  function AdvanceAimTarget(step: ShortInt; animate: Boolean): Types.PCharRecord;
  begin
    if animate then begin
      curX := GameVars.arenaLoc[targets[curIdx].idx].x;
      curY := GameVars.arenaLoc[targets[curIdx].idx].y;
    end else
      CbtMap.RedrawArenaCell(curX, curY);
    Inc(curIdx, step);
    if curIdx = 0 then
      curIdx := tgtCount;
    if curIdx > tgtCount then
      curIdx := 1;
    AdvanceAimTarget := GameVars.creatureArr[targets[curIdx].idx];
    nextX := GameVars.arenaLoc[targets[curIdx].idx].x;
    nextY := GameVars.arenaLoc[targets[curIdx].idx].y;
    if animate then begin
      CharDisp.CombatAnimateMovingIcon(curX, curY, nextX, nextY, 1, 0);
      curX := nextX;
      curY := nextY;
    end;
  end;

begin
  { the aim cursor icon }
  CharDisp.CopyIconFacing(25, 0, 0, False);
  FillChar(tgt, SizeOf(Types.TAimTarget), 0);
  done := False;
  effRange := range;
  if effRange = 255 then
    if creature^.equipped[C_EQUIP.WEAPON] <> nil then
      effRange := CharHlp.BaseItem(creature^.equipped[C_EQUIP.WEAPON]^.itemType)^.range - 1
    else
      effRange := 1;
  if (effRange = 0) or (effRange = 255) then
    effRange := 1;
  BuildAimTargets(creature);
  curIdx := 1;
  skipStep := 0;
  p := AdvanceAimTarget(skipStep, True);
  skipStep := 1;
  ch := ' ';
  while (done = False) and (not (ch in [C_KEYS.NONE, 'E'])) do
  begin
    if not CbtActs.CanAttackTarget(creature, p) then
      p := AdvanceAimTarget(skipStep, False)
    else begin
      ch := CbtActs.AimTargetMenu(creature, p, effRange, weaponMode, groundOk, keyDir);
      { a cursor key goes straight to manual aim }
      if keyDir <> C_DIR.CENTER then
        ch := 'M';
      case ch of
        'N':
          begin
            skipStep := 1;
            menuStep := 1;
          end;
        'P':
          begin
            skipStep := -1;
            menuStep := -1;
          end;
        'M':
          begin
            CbtActs.ManualAimCursor(creature, p, effRange, weaponMode, groundOk, keyDir, done,
                                    Types.TAimTarget(tgt));
            CharDisp.CopyIconFacing(25, 0, 0, False);
            BuildAimTargets(creature);
            menuStep := 0;
          end;
        'T':
          begin
            CbtActs.ConfirmAttackTarget(creature, p, weaponMode, done, Types.TAimTarget(tgt));
            CharDisp.CopyIconFacing(25, 0, 0, False);
            BuildAimTargets(creature);
            menuStep := 0;
          end;
        'C':
          begin
            CbtMap.ScrollView(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), 0, C_DIR.CENTER);
            menuStep := 0;
          end;
      end;
      CbtMap.RedrawArenaCell(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p));
      p := AdvanceAimTarget(menuStep, (done = False) and (not (ch in [C_KEYS.NONE, 'E'])));
    end;
  end;
  if weaponMode <> 0 then
    Border.ClearBox(0, 23, 39, 23);
end;

{ Make sure combatAddr^.other holds a target. An existing lock is kept (without a range check) unless forceNew is set or
  it is now an ally, disabled or vetoed by CanAttackTarget. Otherwise make up to 20 random picks among the enemies
  within range, dropping vetoed ones. If that fails a second pass repeats it, with the arena's distMode set (terrain no
  longer blocks) unless forceNew; there relaxed <> 0 accepts a pick without CanAttackTarget. }
function AcquireTarget(creature: Types.PCharRecord; range, relaxed, forceNew: Byte): Boolean;
var
  cnt: Byte;
  tries: Byte;
  pick: Byte;
  second: Boolean;
  found: Boolean;
  pass: Boolean;
  p: Types.PCharRecord;
begin
  pass := False;
  found := False;
  second := False;
  p := creature^.combatAddr^.other;
  { Drop the lock when forceNew is set or the locked target is no longer valid; a nil lock skips the checks }
  if (forceNew <> 0) or
      ((p <> nil) and
       ((p^.hostile = creature^.hostile) or (p^.enabled = 0) or (not CbtActs.CanAttackTarget(creature, p)))) then
    creature^.combatAddr^.other := nil;
  if creature^.combatAddr^.other <> nil then
    found := True;
  while (not found) and (not second) do begin
    second := pass;
    if pass and (forceNew = 0) then
      GameVars.arenaPtr^.distMode := 1;
    tries := 20;
    cnt := CbtMap.CountTargets(creature, range);
    while (tries > 0) and (not found) and (cnt > 0) do begin
      Dec(tries);
      pick := Dice.RollDice(1, cnt);
      if GameVars.potentialTargetCreature[pick] > 0 then begin
        p := GameVars.creatureArr[GameVars.potentialTargetCreature[pick]];
        if ((relaxed <> 0) and (GameVars.arenaPtr^.distMode <> 0))
           or CbtActs.CanAttackTarget(creature, p) then begin
          found := True;
          creature^.combatAddr^.other := p;
        end else begin
          GameVars.potentialTargetCreature[pick] := 0;
          { pick is reused as the index: do any targets remain? }
          for pick := 1 to cnt do
            if GameVars.potentialTargetCreature[pick] > 0 then
              found := True;
          if found then
            found := False
          else
            cnt := 0;
        end;
      end;
    end;
    if not pass then
      pass := True;
  end;
  GameVars.arenaPtr^.distMode := 0;
  AcquireTarget := found;
end;

{ C_EFFECT.REAR_CLAW_RAKE (73) handler (TEffectHandler shape; p and removed unused): when both primary attacks hit
  (hitsMade[1] = 2) and the locked target is still up, rake it with two 2d4 secondary attacks, then end the creature's
  actions. }
procedure RearClawRake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  done: Boolean;
begin
  if hitsMade[1] = 2 then
    if creature^.combatAddr^.other^.enabled <> 0 then begin
      creature^.combatAddr^.attackPhase := 2;
      creature^.curAttacks2 := 2;
      creature^.curRollsA[2] := 2;
      creature^.curDiceA[2] := 4;
      creature^.curAttacks := 0;
      CharDisp.PrintNameString(creature, 'Rakes...', 10, True);
      CbtActs.CombatAttack(creature, creature^.combatAddr^.other, False, nil, done);
      done := CharHlp.EndActions(creature);
    end;
end;

{ C_EFFECT.BITE_HOLD (74) handler; p is the effect, whose strength holds the victim's creature index. While the hold
  lasts, each trigger is one 3d4 bite on the victim as from behind, ending the creature's actions; a victim that drops
  ends the hold. On removal, when either side is down or when the victim is no longer immobile (#709), the victim loses
  C_EFFECT.IMMOBILE (58), and the hold itself is removed (onRemove cleared first) unless it is already being removed. An
  index outside creatureArr[1..arenaCount] (CombatSlot's 0 for a creature not in the arena) has no victim: the hold just
  goes, as in EffHndlr.EffBloodDrain. }
procedure BiteAndHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  done: Boolean;
  released: Boolean;
begin
  if FxEngine.HoldTarget(creature, p, removed, C_EFFECT.BITE_HOLD, released) <> nil then begin
    creature^.curAttacks := 1;
    creature^.curAttacks2 := 0;
    creature^.curRollsA[1] := 3;
    creature^.curDiceA[1] := 4;
    CbtActs.CombatAttack(creature, GameVars.otherCreatureCurrentPtr, True, nil, done);
    done := CharHlp.EndActions(creature);
    if GameVars.otherCreatureCurrentPtr^.enabled = 0 then
      FxEngine.RemoveEffect(creature, C_EFFECT.BITE_HOLD, p);
  end;
end;

{ Alt-X cheat, active only when the first command-line parameter is STING: every hostile drops dead, every creature's
  actions end and the view is rebuilt. Returns False without STING. }
function StingVictoryCheat: Boolean;
var
  done: Boolean;
  p: Types.PCharRecord;
  slot: Byte;
begin
  StingVictoryCheat := False;
  if not GameVars.stingArg then
    Exit;
  StingVictoryCheat := True;
  CharDisp.PrintBottomLine('The Gods intervene!');
  p := GameVars.creatureList;
  while p <> nil do begin
    if p^.hostile = 1 then begin
      p^.enabled := 0;
      p^.status := C_STATUS.DEAD;
      slot := CbtMap.CombatSlot(p);
      { slot 0: not on the map }
      if slot > 0 then
        GameVars.arenaLoc[slot].size := 0;
    end;
    done := CharHlp.EndActions(p);
    p := p^.nextCharAddr;
  end;
  CbtMap.ScrollView(GameVars.arenaPtr^.ox + 3, GameVars.arenaPtr^.oy + 3, 255, C_DIR.CENTER);
end;

function AreaHitsNonEnemy(x, y: ShortInt; radius: Byte): Boolean;
var
  i: Byte;
begin
  AreaHitsNonEnemy := False;
  Pathing.BuildTargetList(x, y, radius, 255, 1, GameVars.arenaPtr);
  for i := 1 to GameVars.targetCount do
    if GameVars.creatureArr[GameVars.targetList[i].idx]^.hostile <> CharHlp.EnemyTeam(GameVars.curChar) then
      AreaHitsNonEnemy := True;
end;

begin
  { Turbo Pascal clears no variable }
  currentSuppressTargetingFlag := 0;
  FillChar(hitsMade, SizeOf(hitsMade), 0);
  hostileHpPct := 0;
  doneRoundFlag := False;
end.
