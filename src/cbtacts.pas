{ Combat movement, attacks, aiming and spell targeting. }
{$O+,F+}
unit CbtActs;

interface

uses Types, C_Item, C_Terr, C_Cond, GDConsts, GDVars, Crt, MenuCore, ViewChar, Magic, C_Effect,
  C_Equip, C_Keys, C_Class, C_Status, C_Gbvm, C_Dir, C_Sound, C_Spell;

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

implementation


procedure CalcWeaponDamage(att, def: Types.PCharRecord; idx: Byte); forward;

procedure ProcessAttackResult(att, def: Types.PCharRecord; atkType, dmg, dmgDisp: Byte; isHit: Boolean); forward;

procedure GuardingAttacks(creature: Types.PCharRecord); forward;

function AdjustedAttacks(n: Byte): Byte; forward;

procedure DoAttack(att, def: Types.PCharRecord; fromBehind: Boolean; var done: Boolean); forward;

procedure ModifyDefenseForDistance(att, def: Types.PCharRecord; var defense: Byte); forward;

function PickSpellTarget(spell: Byte; ai: Boolean; ground: Byte; var tgt: Types.TAimTarget): Boolean; forward;

function IsBackstab(att, def: Types.PCharRecord): Boolean; forward;

procedure RangedAttackAnim(att, def: Types.PCharRecord; weapon: Types.PItemRec); forward;

function AimTargetMenu(cur, tgt: Types.PCharRecord; range, weaponMode, ground: Byte): Char; forward;

procedure ConfirmAttackTarget(cur, tgt: Types.PCharRecord; weaponMode: Byte; var done: Boolean;
                              var sel: Types.TAimTarget); forward;

procedure ManualAimCursor(cur, underCursor: Types.PCharRecord; range, weaponMode, ground: Byte; var done: Boolean;
                          var sel: Types.TAimTarget); forward;

{ Per-creature round reset: combat record flags, current attacks (SetCurAttacksX2, then the secondary attacks through
  AdjustedAttacks), the sweep budget, initiative (1d6 + missile dex adjustment, at least 1, -6 when surprised, 0 if
  disabled or outside 0..20) and movement. }
procedure CombatRoundStartSetup(creature: Types.PCharRecord);
var
  pad: Byte;
begin
  with creature^.combatAddr^ do begin
    spellCast := 0;
    castAllowed := 1;
    itemUseAllowed := 1;
    madeAttack := 0;
    attackPhase := 2;
    CbtActs.SetCurAttacksX2(creature);
    GDVars.dsCurrentAttackCurrent := creature^.attacks2;
    GDVars.dsCurrentCreatureCalculatingFlag := 0;
    FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
    creature^.curAttacks2 := CbtActs.AdjustedAttacks(GDVars.dsCurrentAttackCurrent);
    sweepBudget := creature^.attackLevel;
    if creature^.enabled <> 0 then begin
      initiative := FxEngine.RollDice(1, 6) + CharHlp.DexMissileAdjust(creature);
      if initiative < 1 then
        initiative := 1;
      { Surprise mask: bit 0 for the party, bit 1 for monsters }
      if Byte((creature^.hostile + 1) and Integer(GDVars.zone1^[C_Gbvm.SURPRISE])) <> 0 then
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
    m := m + GDVars.zone1^[C_Gbvm.MOD_PARTY_MOVE];
  GDVars.dsCurrentCreatureCalculatingFlag := 1;
  if (m < 1) or (m > 96) then
    m := 1;
  GDVars.dsCurrentAttackCurrent := m * 2;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
  GDVars.dsCurrentCreatureCalculatingFlag := 0;
  CalcCreatureMovement := GDVars.dsCurrentAttackCurrent;
end;

{ Roll attack idx's (1 or 2) current dice plus modifier into pendingDamage, multiply it by thief level div 4 + 2 on a
  backstab, clear elementMask and fire the attacker's and defender's weapon-damage effect conditions. }
procedure CalcWeaponDamage(att, def: Types.PCharRecord; idx: Byte);
begin
  GDVars.pendingDamage := att^.curModA[idx]
      + FxEngine.RollDamageDice(att^.curRollsA[idx], att^.curDiceA[idx]);
  { dead guard: pendingDamage is a Byte }
  if GDVars.pendingDamage < 0 then
    GDVars.pendingDamage := 0;
  if CbtActs.IsBackstab(att, def) then
    GDVars.pendingDamage := GDVars.pendingDamage * (Word(att^.classLevels[C_Class.LEVEL_THIEF]) div 4 + 2);
  GDVars.elementMask := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.WEAPON_DAMAGE_ATT, att);
  FxEngine.TriggerEffectsWithCondition(C_Cond.WEAPON_DAMAGE_DEF, def);
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
  CharHlp.PrintNameString(att, verb, 10, False);
  row := 12;
  CharHlp.DisplayCreatureName(def, 23, row, False);
  Inc(row);
  if atkType = 1 then
    verb := '(from behind) '
  else
    verb := '';
  if isHit then begin
    if atkType = 3 then
      verb := 'with one cruel blow'
    else begin
      verb := verb + 'Hitting for ' + CharHlp.ByteToString(dmgDisp);
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
  row := GDVars.curRow + 1;
  if dmg > 0 then begin
    def^.combatAddr^.castAllowed := 0;
    if def^.combatAddr^.spellCast > 0 then begin
      TextRend.PauseOnly;
      CharHlp.PrintNameString(def, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(def^.combatAddr^.spellCast);
      def^.combatAddr^.spellCast := 0;
    end else
      TextRend.PauseOnly;
  end else
    TextRend.PauseOnly;
  if def^.enabled = 0 then begin
    CharHlp.PrintNameString(def, 'goes down', row, False);
    Inc(row, 2);
    if def^.status = C_Status.DYING then
      TextRend.DisplayString(23, row, LightGreen, 'and is Dying');
    if def^.status in [C_Status.DEAD, C_Status.STONED, C_Status.GONE] then
      CharHlp.PrintNameString(def, 'is killed', row, False);
    { dead store: row is never read again }
    Inc(row, 2);
    FxEngine.RemoveEffectsHp0(def);
    FxEngine.TriggerEffectsWithCondition(C_Cond.HP_ZERO, def);
    if def^.enabled = 0 then
      CbtMap.CreatureDowned(def)
    else
      TextRend.PauseOnly;
  end;
  CharHlp.ClearMessageWindow;
end;

{ Each adjacent enemy that is guarding and not helpless spends its guard on a free attack against the mover. }
procedure GuardingAttacks(creature: Types.PCharRecord);
var
  cnt: Byte;
  i: Byte;
  p: Types.PCharRecord;
  done: Boolean;
begin
  cnt := CharHlp.CountTargets(creature, 1);
  for i := 1 to cnt do
    if creature^.enabled <> 0 then begin
      p := GDVars.creatureArr[GDVars.dsPotentialTargetCreature[i]];
      if (p^.combatAddr^.guarding <> 0) and (not CharHlp.IsHelpless(p)) then begin
        CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 2, C_Dir.CENTER);
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
  x := GDVars.arenaLoc[slot].x;
  y := GDVars.arenaLoc[slot].y;
  nx := x + GDConsts.dirDX[dir];
  ny := y + GDConsts.dirDY[dir];
  { cost is reused as the ScrollView delta: 1 under manual control, 3 under quickfight }
  cost := 1;
  if creature^.quickfight <> 0 then begin
    cost := 3;
    if not CbtMap.ViewCoordsValid(nx - GDVars.arenaPtr^.ox, ny - GDVars.arenaPtr^.oy) then
      CbtMap.ScrollView(x, y, 2, C_Dir.CENTER);
  end;
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  GDVars.arenaLoc[slot].x := nx;
  GDVars.arenaLoc[slot].y := ny;
  CbtMap.BuildArenaArrays;
  CbtMap.ScrollView(nx, ny, cost, C_Dir.CENTER);
  { flanking accumulators reset }
  creature^.combatAddr^.flankCount := 0;
  creature^.combatAddr^.flankSpread := 0;
  SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
  CbtActs.GuardingAttacks(creature);
  if (creature^.enabled = 0) or CharHlp.IsHelpless(creature) then
    creature^.combatAddr^.movement := 0;
end;

{ Enemies adjacent before a step in dir but not after it get one free attack on the mover, made as from behind.
  Helpless, effect-vetoed, blood-draining and bite-holding enemies are skipped. An enemy with no initiative left that
  has already been attacked this round (flankCount > 0) attacks only if the mover is in its 5-direction front cone. }
procedure MoveOpportunityAttacks(creature: Types.PCharRecord; dir: Byte);
var
  adj: array[1..12] of Byte;
  effect: Types.PEffectRec;
  still: Boolean;
  attacked: Boolean;
  slot: Byte;
  pad: Byte;
  cntBefore: Byte;
  cntAfter: Byte;
  j: Byte;
  i: Byte;
  k: Byte;
  phase: Byte;
  a: Byte;
  p: Types.PCharRecord;
  savedOther: Types.PCharRecord;
begin
  FillChar(adj, SizeOf(adj), 0);
  slot := CbtMap.CombatSlot(creature);
  cntBefore := CharHlp.CountTargets(creature, 1);
  if cntBefore = 0 then
    Exit;
  for i := 1 to cntBefore do
    adj[i] := GDVars.dsPotentialTargetCreature[i];
  { probe: step the icon, recount, step back }
  Inc(GDVars.arenaLoc[slot].x, GDConsts.dirDX[dir]);
  Inc(GDVars.arenaLoc[slot].y, GDConsts.dirDY[dir]);
  cntAfter := CharHlp.CountTargets(creature, 1);
  Dec(GDVars.arenaLoc[slot].x, GDConsts.dirDX[dir]);
  Dec(GDVars.arenaLoc[slot].y, GDConsts.dirDY[dir]);
  { enemies still adjacent after the step get no free attack }
  for i := 1 to cntBefore do begin
    still := False;
    for j := 1 to cntAfter do
      if GDVars.dsPotentialTargetCreature[j] = adj[i] then
        still := True;
    if still then
      adj[i] := 0;
  end;
  for i := 1 to cntBefore do
    if adj[i] > 0 then
      if creature^.enabled <> 0 then begin
        attacked := False;
        p := GDVars.creatureArr[adj[i]];
        if not CharHlp.IsHelpless(p) then
          if CbtActs.CanAttackTarget(p, creature) then
            if not CharHlp.HasEffect(p, C_Effect.BLOOD_DRAIN, effect) then
              if not CharHlp.HasEffect(p, C_Effect.BITE_HOLD, effect) then
                for a := p^.combatAddr^.direction + 6
                    to p^.combatAddr^.direction + 10 do
                  if not attacked then
                    if (p^.combatAddr^.initiative > 0)
                       or (p^.combatAddr^.flankCount = 0)
                       or
                         Pathing.IsDirToward(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), CbtMap.CombatCellX(creature),
                                             CbtMap.CombatCellY(creature), a mod 8) then begin
                      phase := 1;
                      if p^.attacks = 0 then
                        phase := 2;
                      { 2 = curAtt's upper bound }
                      for k := 1 to 2 do
                        if Types.PAttackPhaseView(p)^.curAtt[k] > 0 then
                          phase := k;
                      if Types.PAttackPhaseView(p)^.curAtt[phase] = 0 then
                        Types.PAttackPhaseView(p)^.curAtt[phase] := 1;
                      p^.combatAddr^.attackPhase := phase;
                      savedOther := p^.combatAddr^.other;
                      CbtActs.CombatAttack(p, creature, True, nil, GDVars.doneRoundFlag);
                      attacked := True;
                      p^.combatAddr^.other := savedOther;
                      if creature^.enabled <> 0 then
                        CharHlp.CombatPrintCreatureInfo(creature);
                    end;
      end;
end;

{ Flee: automatic when the target list (range 255) holds no enemy; otherwise it succeeds when the creature's movement in
  whole moves beats the fastest enemy's (HighestEnemyMovement), on 1 in 2 when they tie. Success takes it out of play as
  'Got Away' (C_Status.RUNNING). EndActions runs on both outcomes and supplies the result. }
function CombatFleeAttempt(creature: Types.PCharRecord): Boolean;
var
  ok: Boolean;
  enemyMove: Byte;
  halfMove: Byte;
begin
  ok := False;
  if CharHlp.CountTargets(creature, 255) = 0 then
    ok := True
  else begin
    halfMove := CbtActs.CalcCreatureMovement(creature) div 2;
    enemyMove := CbtActs.HighestEnemyMovement(creature);
    if enemyMove < halfMove then
      ok := True
    else if enemyMove = halfMove then
      if FxEngine.RollDice(1, 2) = 1 then
        ok := True;
  end;
  if ok then
    FxEngine.PutOutOfPlayWithStatus(creature, C_Status.RUNNING, 'Got Away')
  else
    CharHlp.PrintBottomLine('Escape is blocked');
  CombatFleeAttempt := CharHlp.EndActions(creature);
end;

{ Set curAttacks for the round. Start from the weapon's rate of fire (at least 2) for a damaging ranged weapon, else the
  base attacks, both in half-attacks; apply haste/slow effects, then AdjustedAttacks (odd rounds round up, then halve)
  and cap a ranged weapon by its ammunition. Once an attack has been made the result is used only when it is below the
  previous curAttacks (melee: below twice it); otherwise curAttacks keeps the base attacks value instead of the previous
  one. }
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
  creature^.curAttacks := creature^.attacks;
  if CharHlp.HasRangedWeapon(creature) and CharHlp.FindDamagingRangedWeapon(creature, weapon) then begin
    ranged := True;
    rof := GDVars.baseItems[creature^.equipped[C_Equip.WEAPON]^.itemType].rateOfFire;
    if rof < 2 then
      rof := 2;
    GDVars.dsCurrentAttackCurrent := rof;
  end else
    GDVars.dsCurrentAttackCurrent := creature^.curAttacks;
  GDVars.dsCurrentCreatureCalculatingFlag := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
  adj := CbtActs.AdjustedAttacks(GDVars.dsCurrentAttackCurrent);
  if ranged then
    if weapon <> nil then begin
      qty := 1;
      if weapon <> nil then
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
  if Odd(GDVars.roundCounter) then
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
  if CharHlp.CalcDistance(att, def) <> 1 then
    Exit;
  cnt := CharHlp.CountTargets(att, 1);
  weak := 0;
  for i := 1 to cnt do begin
    p := GDVars.creatureArr[GDVars.dsPotentialTargetCreature[i]];
    if p = def then
      defIdx := i;
    if p^.levelHighest = 0 then
      Inc(weak);
  end;
  if weak <= att^.curAttacks then
    Exit;
  if weak > att^.combatAddr^.sweepBudget then
    weak := att^.combatAddr^.sweepBudget;
  CharHlp.PrintNameString(att, 'sweeps', 10, True);
  { def becomes the first sweep target }
  p := GDVars.creatureArr[GDVars.dsPotentialTargetCreature[1]];
  if p <> def then begin
    GDVars.dsPotentialTargetCreature[defIdx] := GDVars.dsPotentialTargetCreature[1];
    GDVars.dsPotentialTargetCreature[1] := CbtMap.CombatSlot(def);
  end;
  for i := 1 to cnt do
    if weak > 0 then
      if GDVars.creatureArr[GDVars.dsPotentialTargetCreature[i]]^.levelHighest = 0 then begin
        p := GDVars.creatureArr[GDVars.dsPotentialTargetCreature[i]];
        CbtActs.NoteAttackDirection(att, p);
        att^.curAttacks := 1;
        CbtActs.CombatAttack(att, p, False, nil, GDVars.doneRoundFlag);
        Dec(weak);
      end;
  SweepAttempt := True;
end;

{ Check whether effects permit creature to attack other: False for nil, True for itself. Otherwise the target's veto
  effects run first, then the attacker's with other as its temporary target; any veto sets
  dsCurrentSuppressTargetingFlag. }
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
  GDVars.dsCurrentSuppressTargetingFlag := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.TARGET_VETO, other);
  if GDVars.dsCurrentSuppressTargetingFlag = 0 then begin
    saved := creature^.combatAddr^.other;
    creature^.combatAddr^.other := other;
    FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACKER_VETO, creature);
    creature^.combatAddr^.other := saved;
  end;
  CanAttackTarget := GDVars.dsCurrentSuppressTargetingFlag = 0;
end;

{ Turn undead: one d20 roll against the turning table, applied to up to 1d12 targets (lowest-level undead first) until a
  target resists. }
procedure CombatTurnUndead(creature: Types.PCharRecord);
var
  roll: Byte;
  attempts: Byte;
  destroys: Byte;
  turnVal: ShortInt;
  any: Boolean;
  stop: Boolean;
  tgt: Pointer;
  col: ShortInt;
begin
  CharHlp.PrintNameString(creature, 'turns undead...', 10, False);
  MenuCore.ClearBottomLine;
  TextRend.PauseOnly;
  any := False;
  stop := False;
  creature^.combatAddr^.usedTurnUndead := 1;
  destroys := 6;
  attempts := FxEngine.RollDice(1, 12);
  roll := FxEngine.RollDice(1, 20);
  case creature^.classLevels[C_Class.LEVEL_CLERIC] of
    1..8: col := creature^.classLevels[C_Class.LEVEL_CLERIC];
    9..13: col := 9;
  else
    col := 10;
  end;
  while CbtActs.FindTurnUndeadTarget(creature, tgt) and (attempts > 0)
        and (stop = False) do begin
    turnVal := GDConsts.turnTable[Types.PCharRecord(tgt)^.levelUndead, col];
    if roll >= Abs(turnVal) then begin
      any := True;
      CbtMap.DisplayMapViewCentered(Types.PCharRecord(tgt), 3, False);
      CharHlp.CombatPrintCreatureInfo(Types.PCharRecord(tgt));
      if turnVal > 0 then begin
        Types.PCharRecord(tgt)^.combatAddr^.turned := 1;
        CharHlp.PrintNameStringAnim(Types.PCharRecord(tgt), True, 'is turned');
      end else begin
        CharHlp.PrintNameString(Types.PCharRecord(tgt), 'Is destroyed', 10, False);
        CbtMap.CreatureDowned(Types.PCharRecord(tgt));
        Types.PCharRecord(tgt)^.status := C_Status.GONE;
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
      CharHlp.ClearMessageWindow;
    end else
      stop := True;
  end;
  if not any then
    CharHlp.PrintBottomLine('Nothing Happens...');
  CharHlp.CountTeams;
  GDVars.doneRoundFlag := CharHlp.EndActions(creature);
  CharHlp.ClearMessageWindow;
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
  cnt := CharHlp.CountTargets(creature, 255);
  FindTurnUndeadTarget := False;
  for i := 1 to cnt do begin
    p := GDVars.creatureArr[GDVars.dsPotentialTargetCreature[i]];
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
  AC. Add range penalties, roll the attacks from attackPhase down to 1 until def drops, and spend the sweep budget. With
  no attacks left, att's actions end. }
procedure DoAttack(att, def: Types.PCharRecord; fromBehind: Boolean; var done: Boolean);
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
begin
  behind := fromBehind;
  done := False;
  GDVars.hitsMade[1] := 0;
  GDVars.hitsMade[2] := 0;
  GDVars.attacksMade[1] := 0;
  GDVars.attacksMade[2] := 0;
  anyHit := False;
  defDowned := False;
  GDVars.pendingDamage := 0;
  att^.combatAddr^.madeAttack := 1;
  if CharHlp.IsHelpless(def) then begin
    SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.IMPACT]);
    while Types.PAttackPhaseView(att)^.curAtt[att^.combatAddr^.attackPhase] = 0 do
      { may run below the array bound }
      Dec(att^.combatAddr^.attackPhase);
    Inc(GDVars.attacksMade[att^.combatAddr^.attackPhase]);
    CbtActs.ProcessAttackResult(att, def, 3, def^.hpCur + 5, 1, True);
    FxEngine.RemoveInvisibility(att);
    { 2 = curAtt's upper bound }
    for phase := 1 to 2 do
      Types.PAttackPhaseView(att)^.curAtt[phase] := 0;
    anyHit := True;
    done := True;
  end else begin
    if (att^.equipped[C_Equip.WEAPON] <> nil)
       and ((def^.iconDimensions > $80) or (def^.iconDimensions and 7 > 1)) then begin
      { large target: swap in the large-damage dice }
      base := GDVars.baseItems[att^.equipped[C_Equip.WEAPON]^.itemType];
      att^.curRollsA[1] := base.dmgLgRolls;
      att^.curDiceA[1] := base.dmgLgDice;
      att^.curModA[1] := att^.curModA[1] - base.dmgSmMod
          + base.dmgLgMod;
    end;
    CharHlp.RecalcStats(def);
    FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_AC, def);
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
        Inc(GDVars.attacksMade[phase]);
        if FxEngine.AttackRoll(att, def, defense) or CharHlp.IsHelpless(def) then begin
          Inc(GDVars.hitsMade[phase]);
          SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.IMPACT]);
          anyHit := True;
          CbtActs.CalcWeaponDamage(att, def, phase);
          CbtActs.ProcessAttackResult(att, def, atkType, GDVars.pendingDamage, GDVars.pendingDamage, True);
          if def^.enabled <> 0 then
            { C_Cond.HIT_PHASE_1/2 }
            FxEngine.TriggerEffectsWithCondition(phase + 1, att);
          if def^.enabled = 0 then
            defDowned := True;
        end;
      end;
    if not anyHit then begin
      SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.MISS]);
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
begin
  if (def^.combatAddr^.flankCount < 3) and (not fromBehind) then begin
    dir := CbtActs.DirTowardTarget(def, att);
    if CbtMap.CombatIconVisible(def, 0) then
      CbtMap.SetCreatureFacing(def, dir, 0, 0)
    else
      def^.combatAddr^.direction := dir;
  end;
  dir := CbtActs.DirTowardTarget(att, def);
  CharHlp.CombatPrintCreatureInfo(att);
  CbtMap.SetCreatureFacing(att, dir, 1, 0);
  att^.combatAddr^.other := def;
  Delay(100);
  if weapon <> nil then
    CbtActs.RangedAttackAnim(att, def, weapon);
  { Note: no nil check on the equipped weapon. Base item 47 is the sling. }
  if att^.equipped[C_Equip.WEAPON]^.itemType = 47 then
    CbtActs.RangedAttackAnim(att, def, att^.equipped[C_Equip.WEAPON]);
  done := True;
  if (att^.curAttacks > 0) or (att^.curAttacks2 > 0) then begin
    savedCur := GDVars.curChar;
    GDVars.curChar := att;
    CbtActs.DoAttack(att, def, fromBehind, done);
    if weapon <> nil then begin
      if weapon^.quantity > 0 then
        Dec(weapon^.quantity, GDVars.attacksMade[1]);
      if weapon^.quantity = 0 then
        if CharHlp.HasThrowableWeapon(att) and (weapon^.special <> C_Effect.SPIRIT_HAMMER_GONE) then begin
          { the expended thrown weapon drops into the loot pile }
          GetMem(item, SizeOf(Types.TItemRec));
          Move(weapon^, item^, SizeOf(Types.TItemRec));
          item^.next := GDVars.treasureItems;
          GDVars.treasureItems := item;
          item^.equipped := 0;
          CharHlp.RemoveItem(att, weapon);
          GDVars.lastMissileItem := item;
        end else
          CharHlp.RemoveItem(att, weapon);
    end;
    CharHlp.RecalcStats(att);
    GDVars.curChar := savedCur;
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
  dist := CharHlp.CalcDistance(att, def);
  if CharHlp.HasRangedWeapon(att) then
    subrange := (GDVars.baseItems[att^.equipped[C_Equip.WEAPON]^.itemType].range - 1)
        div 3
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
  hp (the creature itself, checked last, also wins whenever below half its max) and the last downed, not dead body found
  on a corpse cell. The body wins unless there is none or the ally has 7 hp or fewer. }
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
  for d := 0 to C_Dir.CENTER do begin
    nx := CbtMap.CombatCellX(creature) + GDConsts.dirDX[d];
    ny := CbtMap.CombatCellY(creature) + GDConsts.dirDY[d];
    CbtMap.GetArenaContents(nx, ny, crIdx, terrIdx);
    if crIdx > 0 then begin
      { the var param is the scratch }
      tgt := GDVars.creatureArr[crIdx];
      if Types.PCharRecord(tgt)^.hostile = creature^.hostile then
        if Types.PCharRecord(tgt)^.hpCur < Types.PCharRecord(tgt)^.hpMax then
          if (Types.PCharRecord(tgt)^.hpCur < bestHp)
             or ((tgt = creature) and (Types.PCharRecord(tgt)^.hpCur < Types.PCharRecord(tgt)^.hpMax div 2)) then begin
            best := tgt;
            bestHp := Types.PCharRecord(tgt)^.hpCur;
          end;
    end else if terrIdx = C_Terr.CORPSE then
      for j := 1 to GDVars.downedCount do
        if GDVars.downed[j].cr <> nil then
          if not (GDVars.downed[j].cr^.status in
                  [C_Status.DEAD, C_Status.STONED, C_Status.GONE]) then
            if GDVars.downed[j].x = nx then
              if GDVars.downed[j].y = ny then
                downIdx := j;
  end;
  if (bestHp < 8) or (downIdx = 0) then
    tgt := best
  else
    tgt := GDVars.downed[downIdx].cr;
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
    CbtActs.CombatAimMenu(GDVars.curChar, Magic.CalcSpellRange(spell), 0, ground, found, tgt);
    GDVars.curChar^.combatAddr^.other := tgt.cr;
  end else begin
    if GDConsts.spellTable[spell].offensive = 0 then begin
      tgt.cr := GDVars.curChar;
      if (spell <> C_Spell.CURE_LIGHT_WOUNDS) or CbtActs.FindCureTarget(GDVars.curChar, tgt.cr) then begin
        tgt.x := CbtMap.CombatCellX(tgt.cr);
        tgt.y := CbtMap.CombatCellY(tgt.cr);
        found := True;
      end;
    end else begin
      tries := 20;
      while (tries > 0) and (found = False) do begin
        ok := True;
        if CbtActs.AcquireTarget(GDVars.curChar, Magic.CalcSpellRange(spell), 0, 1) then begin
          p := GDVars.curChar^.combatAddr^.other;
          if GDConsts.spellTable[spell].aiRadius > 0 then begin
            Pathing.BuildTargetList(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), GDConsts.spellTable[spell].aiRadius,
                                    255, 1, GDVars.arenaPtr);
            for i := 1 to GDVars.targetCount do
              if GDVars.creatureArr[GDVars.targetList[i].idx]^.hostile
                 <> CharHlp.EnemyTeam(GDVars.curChar) then
                ok := False;
          end;
          if CharHlp.IsHelpless(p) then
            for i := 1 to SizeOf(GDConsts.helplessFx) div SizeOf(GDConsts.helplessFx[1]) do
              if GDConsts.spellTable[spell].effect = GDConsts.helplessFx[i] then
                ok := False;
          if ok then begin
            tgt.cr := GDVars.curChar^.combatAddr^.other;
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
    GDVars.gTargetX := tgt.x;
    GDVars.gTargetY := tgt.y;
  end else begin
    PickSpellTarget := False;
    FillChar(tgt, SizeOf(tgt), 0);
  end;
end;

{ Combat's spellFps[0] callback: build the spell-target list from the low nibble of the spell's area. 0: the caster; 15:
  the picked creature (a bare cell gets a zero-radius area); 8..14: everything within area and 7 of the picked cell;
  1..7: (area and 3) + 1 individual picks. b is the AI flag, passed to PickSpellTarget. }
procedure CombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);
var
  remaining: Byte;
  k: Byte;
  j: Byte;
  sel: Types.TAimTarget;
  dup: Boolean;
begin
  cast := True;
  GDVars.spellTargetCount := 0;
  GDVars.gMultiTarget := 0;
  GDVars.gTargetX := CbtMap.CombatCellX(GDVars.curChar);
  GDVars.gTargetY := CbtMap.CombatCellY(GDVars.curChar);
  case GDConsts.spellTable[spell].area and $F of
    0:
      { self only }
      begin
        GDVars.dsTargetCreaturePtr[1] := GDVars.curChar;
        GDVars.spellTargetCount := 1;
      end;
    15:
      { the picked creature, or an area at the picked cell }
      begin
        if CbtActs.PickSpellTarget(spell, b, 0, sel) then begin
          if GDVars.curChar^.combatAddr^.other <> nil then begin
            GDVars.dsTargetCreaturePtr[1] := GDVars.curChar^.combatAddr^.other;
            GDVars.spellTargetCount := 1;
          end else begin
            { (area and $F) shr 4 is always 0: a zero radius }
            Pathing.BuildTargetList(GDVars.gTargetX, GDVars.gTargetY,
                                    (GDConsts.spellTable[spell].area and $F) shr 4, 255, 1, GDVars.arenaPtr);
            for k := 1 to GDVars.targetCount do
              GDVars.dsTargetCreaturePtr[k] := GDVars.creatureArr[GDVars.targetList[k].idx];
            GDVars.spellTargetCount := GDVars.targetCount;
            GDVars.gMultiTarget := 1;
          end;
        end else
          cast := False;
      end;
    8..14:
      { fixed radius, ground OK }
      begin
        if CbtActs.PickSpellTarget(spell, b, 1, sel) then begin
          Pathing.BuildTargetList(GDVars.gTargetX, GDVars.gTargetY, GDConsts.spellTable[spell].area and 7, 255, 1,
                                  GDVars.arenaPtr);
          for k := 1 to GDVars.targetCount do
            GDVars.dsTargetCreaturePtr[k] := GDVars.creatureArr[GDVars.targetList[k].idx];
          GDVars.spellTargetCount := GDVars.targetCount;
          GDVars.gMultiTarget := 1;
        end else
          cast := False;
      end;
  else
    { 1..7: (area and 3) + 1 individual targets }
    begin
      remaining := (GDConsts.spellTable[spell].area and 3) + 1;
      k := 0;
      while remaining > 0 do begin
        if CbtActs.PickSpellTarget(spell, b, 0, sel) then begin
          dup := False;
          for j := 1 to k do
            if GDVars.dsTargetCreaturePtr[j] = sel.cr then
              dup := True;
          if not dup then begin
            Inc(k);
            GDVars.dsTargetCreaturePtr[k] := sel.cr;
            Dec(remaining);
          end else if not b then
            CharHlp.PrintBottomLine('Already been targeted')
          else
            Dec(remaining);
          CbtMap.RedrawArenaCell(CbtMap.CombatCellX(GDVars.dsTargetCreaturePtr[k]),
                                 CbtMap.CombatCellY(GDVars.dsTargetCreaturePtr[k]));
        end else
          Dec(remaining);
      end;
      GDVars.spellTargetCount := k;
      if k = 0 then
        cast := False;
    end;
  end;
end;

{ Pick (C_Spell.NONE: from the spell menu) and validate a spell, rejecting camp-only ones. A casting time (castTime div
  3) of 0 casts it now and ends the caster's actions; otherwise the caster "Begins Casting": spellCast holds the spell
  and initiative drops by the casting time (to at least 1), so it resolves on a later action. }
procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);
var
  spellId: Byte;
  pad: Byte;
  castTime: Byte;
  idx: Integer;
  notEmpty: Boolean;
  caster: Types.PCharRecord;
begin
  caster := GDVars.curChar;
  notEmpty := True;
  idx := -1;
  cast := False;
  spellId := spell;
  if spellId = C_Spell.NONE then
    spellId := ViewChar.SpellMenu(0, 1, idx, notEmpty);
  if spellId > C_Spell.NONE then
    if GDConsts.spellTable[spellId].whenCast = 0 then begin
      CharHlp.PrintBottomLine('Camp Only Spell');
      spellId := C_Spell.NONE;
    end;
  if ai = 0 then begin
    CharHlp.DisplayCombatInterface;
    CbtMap.DisplayMapViewCentered(caster, 3, True);
    CharHlp.CombatPrintCreatureInfo(caster);
  end;
  if spellId > C_Spell.NONE then begin
    castTime := GDConsts.spellTable[spellId].castTime div 3;
    if castTime = 0 then begin
      Magic.CastSpellNC(spellId, Boolean(ai), True, cast);
      cast := CharHlp.EndActions(caster);
    end else begin
      cast := True;
      CharHlp.PrintNameString(caster, 'Begins Casting', 10, True);
      caster^.combatAddr^.spellCast := spellId;
      if caster^.combatAddr^.initiative > castTime then
        Dec(caster^.combatAddr^.initiative, castTime)
      else
        caster^.combatAddr^.initiative := 1;
    end;
  end;
end;

{ Backstabbing requires a thief in leather or no armor, using a club, dagger, broad, long or short sword, or no weapon.
  The target must have been attacked more than once this round and face away from the attacker. }
function IsBackstab(att, def: Types.PCharRecord): Boolean;
var
  weapon: Types.PItemRec;
  armor: Types.PItemRec;
  wItem: Byte;
  can: Boolean;
begin
  can := False;
  weapon := att^.equipped[C_Equip.WEAPON];
  if weapon <> nil then
    wItem := weapon^.itemType;
  armor := att^.equipped[C_Equip.ARMOR];
  if att^.classLevels[C_Class.LEVEL_THIEF] > 0 then
    { base item 50, Leather Armor }
    if (armor = nil) or (armor^.itemType = 50) then
      { Club, Dagger }
      if (weapon = nil) or (wItem = 7) or (wItem = 8)
         { 35..37 = Broad/Long/Short Sword }
         or ((wItem > 34) and (wItem < 38)) then
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
  size := GDVars.dsMoveIconSheet^.imgSize;
  if GDVars.videoMode = 1 then
    size := size div 4;
  case weapon^.itemType of
    { straight-flying missiles: Dart, Javelin, Quarrel, Spear and Arrow }
    9, 21, 28, 31, 73:
      if Odd(dir) then begin
        if (dir = C_Dir.SOUTHEAST) or (dir = C_Dir.SOUTHWEST) then
          CharHlp.CopyIconFacing(sym + 1, 1, 0, dir = C_Dir.SOUTHWEST)
        else
          CharHlp.CopyIconFacing(sym + 1, 0, 0, dir = C_Dir.NORTHWEST);
      end else
        CharHlp.CopyIconFacing(sym + dir mod 4, dir div 4, 0, False);
    { spinning thrown weapons: Hand Axe, Club, Hammer }
    2, 7, C_Item.HAMMER:
      begin
        CharHlp.BuildIconFacings(sym + 3);
        frames := 4;
        pace := 50;
      end;
    { holy water / oil flask }
    C_Item.HOLY_WATER_VIAL, C_Item.FLASK_OF_OIL:
      begin
        CharHlp.BuildIconFacings(sym + 4);
        frames := 4;
        pace := 50;
      end;
  else begin
      { base item 47, Sling }
      if weapon^.itemType = 47 then
        Inc(sym);
      CharHlp.CopyIconFacing(sym + 7, 0, 0, False);
      CharHlp.CopyIconFacing(sym + 7, 1, 1, False);
      frames := 2;
      pace := 20;
    end;
  end;
  SoundDrv.SoundSetAutoStop(0);
  SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.RANGED_START]);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(att), CbtMap.CombatCellY(att), CbtMap.CombatCellX(def),
                                  CbtMap.CombatCellY(def), frames, pace);
  SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.RANGED_END]);
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
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.hostile = 1 then begin
      if p^.enabled <> 0 then
        curSum := curSum + p^.hpCur;
      maxSum := maxSum + p^.hpMax;
    end;
    p := p^.nextCharAddr;
  end;
  if maxSum > 0 then
    GDVars.hostileHpPct := curSum * 20 div maxSum * 5;
end;

{ The fastest enabled enemy's movement in whole moves (CalcCreatureMovement div 2); no range or line-of-sight check. }
function HighestEnemyMovement(creature: Types.PCharRecord): Byte;
var
  best: Byte;
  m: Byte;
  p: Types.PCharRecord;
begin
  best := 0;
  p := GDVars.creatureList;
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

{ Confirm a physical attack on an ally (enemies and quick-fighting attackers pass unasked). Yes sets attackedAllies and
  the GBVM attacked-allies flag, and every NPC-flagged creature in okay status turns hostile and drops its target. }
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
    GDVars.attackedAllies := 1;
    GDVars.zone1^[C_Gbvm.ATTACKED_ALLIES] := 1;
    p := GDVars.creatureList;
    while p <> nil do begin
      { NPC flag (high bit) set }
      if (p^.status = C_Status.OKAY) and (p^.npc > $7F) then begin
        p^.hostile := 1;
        p^.combatAddr^.other := nil;
      end;
      p := p^.nextCharAddr;
    end;
    CharHlp.CountTeams;
  end;
end;

{ One aim-menu round on the target: center the view on it, show the range (weapon mode) and offer Target when it is in
  range (a weapon attack needs another creature, and a ranged weapon needs damaging ammunition plus either no adjacent
  enemy or a throwable weapon), then Next/Prev/Manual/Center/Exit. ground is unused. }
function AimTargetMenu(cur, tgt: Types.PCharRecord; range, weaponMode, ground: Byte): Char;
var
  menu: String[40];
  ext: Boolean;
  weapon: Types.PItemRec;
  dist: Byte;
  dir: Byte;
begin
  menu := '';
  dist := CharHlp.CalcDistance(cur, tgt);
  dir := CbtActs.DirTowardTarget(cur, tgt);
  if weaponMode <> 0 then
    TextRend.DisplayString(0, 23, LightGreen, 'Range = ' + CharHlp.ByteToString(dist) + '  ');
  if dist <= range then begin
    if weaponMode = 0 then
      menu := 'Target '
    else if cur <> tgt then begin
      if not CharHlp.HasRangedWeapon(cur) then
        menu := 'Target '
      else if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
        if (CharHlp.CountTargets(cur, 1) = 0) or CharHlp.HasThrowableWeapon(cur) then
          menu := 'Target ';
    end;
  end;
  menu := 'Next Prev Manual ' + menu + 'Center Exit';
  CbtMap.DisplayMapViewCentered(tgt, 3, True);
  CharHlp.CombatPrintCreatureInfo(tgt);
  AimTargetMenu := MenuCore.MenuHorizontal('Aim:', menu, LightMagenta, LightGreen, White, False, False,
                                           ext);
end;

{ Confirm an aim selection. weaponMode=1 performs a weapon attack; 0 selects a spell target. An attack on an ally needs
  CheckAttackAlly's consent, else sel is cleared and done is False. The attack tries a sweep first; a throwable ranged
  weapon used at distance 1 strikes as melee (weapon nil). }
procedure ConfirmAttackTarget(cur, tgt: Types.PCharRecord; weaponMode: Byte; var done: Boolean;
                              var sel: Types.TAimTarget);
var
  pad: Byte;
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
    GDVars.arenaPtr^.cursorOn := False;
    CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 3, C_Dir.CENTER);
    if weaponMode = 1 then begin
      if CbtActs.SweepAttempt(cur, tgt) then
        done := CharHlp.EndActions(cur)
      else begin
        CbtActs.NoteAttackDirection(cur, tgt);
        if CharHlp.HasRangedWeapon(cur) then
          if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
            if CharHlp.HasThrowableWeapon(cur) then
              if CharHlp.CalcDistance(cur, tgt) = 1 then
                weapon := nil;
        CbtActs.CombatAttack(cur, tgt, False, weapon, done);
      end;
    end;
  end else
    FillChar(sel, SizeOf(sel), 0);
end;

{ The free cursor aim: the arrow-key scans move a cell cursor (clamped to the arena) from underCursor's cell,
  Pathing.WalkLine checks the line and range, Target/Enter takes a valid cell (a weapon attack goes through
  ConfirmAttackTarget), Center recenters and Exit/Escape cancels. A bare cell is valid only when ground is set. }
procedure ManualAimCursor(cur, underCursor: Types.PCharRecord; range, weaponMode, ground: Byte; var done: Boolean;
                          var sel: Types.TAimTarget);
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
  dir := C_Dir.CENTER;
  done := False;
  GDVars.arenaPtr^.cursorOn := True;
  GDVars.arenaPtr^.cursorSize := 1;
  while not (ch in [C_Keys.NONE, C_Keys.ENTER, 'E', 'T']) do
  begin
    CbtMap.ScrollView(cx, cy, 3, dir);
    Inc(cx, GDConsts.dirDX[dir]);
    Inc(cy, GDConsts.dirDY[dir]);
    if cx < 0 then
      cx := 0;
    if cy < 0 then
      cy := 0;
    if cx > 49 then
      cx := 49;
    if cy > 24 then
      cy := 24;
    CbtMap.GetArenaContents(cx, cy, crIdx, terrIdx);
    GameIo.PollGameKeys;
    valid := False;
    dist := 255;
    wx := cx;
    wy := cy;
    if Pathing.WalkLine(CbtMap.CombatCellX(cur), CbtMap.CombatCellY(cur), wx, wy, dist, GDVars.arenaPtr) then begin
      valid := True;
      if weaponMode <> 0 then
        TextRend.DisplayString(0, 23, LightGreen, 'Range = ' + CharHlp.WordToString(dist div 2) + '  ');
    end else if weaponMode <> 0 then
      Border.ClearBox(0, 23, 39, 23);
    dist := dist div 2;
    underCursor := nil;
    if valid then begin
      if crIdx > 0 then
        underCursor := GDVars.creatureArr[crIdx]
      else if terrIdx = C_Terr.CORPSE then
        for j := 1 to GDVars.downedCount do
          if GDVars.downed[j].x = cx then
            if GDVars.downed[j].y = cy then
              underCursor := GDVars.downed[j].cr;
    end;
    if underCursor <> nil then
      CharHlp.CombatPrintCreatureInfo(underCursor)
    else
      Border.ClearBox(23, 1, 38, 21);
    if (range < dist) or (GDConsts.terrainInfo[terrIdx].cost = 255) then
      valid := False;
    if underCursor <> nil then begin
      if not CbtActs.CanAttackTarget(cur, underCursor) then
        valid := False;
      if weaponMode = 1 then
        if (cur = underCursor)
           or ((crIdx = 0) and (terrIdx = C_Terr.CORPSE)) then
          valid := False
        else if CharHlp.HasRangedWeapon(cur) then
          if (not CharHlp.FindDamagingRangedWeapon(cur, weapon)) or
              ((CharHlp.CountTargets(cur, 1) > 0) and (not CharHlp.HasThrowableWeapon(cur))) then
            valid := False;
    end else if ground = 0 then
      valid := False;
    menu := 'Center Exit';
    if valid then
      menu := 'Target ' + menu;
    ch := MenuCore.MenuHorizontal('(Use Cursor keys) ', menu, LightMagenta, LightGreen, White, True, False,
                                  GDVars.doneRoundFlag);
    case ch of
      C_Keys.ENTER, 'T':
        begin
          GDVars.arenaPtr^.cursorOn := False;
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
      C_Keys.UP: dir := C_Dir.NORTH;
      C_Keys.PGUP: dir := C_Dir.NORTHEAST;
      C_Keys.RIGHT: dir := C_Dir.EAST;
      C_Keys.PGDN: dir := C_Dir.SOUTHEAST;
      C_Keys.DOWN: dir := C_Dir.SOUTH;
      C_Keys.END_KEY: dir := C_Dir.SOUTHWEST;
      C_Keys.LEFT: dir := C_Dir.WEST;
      C_Keys.HOME: dir := C_Dir.NORTHWEST;
      C_Keys.NONE, 'E':
        begin
          CbtMap.RedrawArenaCell(cx, cy);
          FillChar(sel, SizeOf(sel), 0);
          done := False;
        end;
      'C':
        begin
          CbtMap.ScrollView(cx, cy, 0, C_Dir.CENTER);
          dir := C_Dir.CENTER;
        end;
    else
      dir := C_Dir.CENTER;
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

  { Build the parent routine's aiming list from targets within range 127. }
  procedure BuildAimTargets(c: Types.PCharRecord);
  var
    i: Byte;
  begin
    Pathing.BuildTargetList(CbtMap.CombatCellX(c), CbtMap.CombatCellY(c), 127, 255, CbtMap.GetIconSize(c),
                            GDVars.arenaPtr);
    tgtCount := GDVars.targetCount;
    for i := 1 to tgtCount do
      targets[i] := GDVars.targetList[i];
  end;

  { Move the aim highlight step entries through the list (wrapping) and return that creature; animate flies the cursor
    from the current target, otherwise the old cursor cell is redrawn. }
  function AdvanceAimTarget(step: ShortInt; animate: Boolean): Types.PCharRecord;
  var
    pad: Pointer;
  begin
    if animate then begin
      curX := GDVars.arenaLoc[targets[curIdx].idx].x;
      curY := GDVars.arenaLoc[targets[curIdx].idx].y;
    end else
      CbtMap.RedrawArenaCell(curX, curY);
    Inc(curIdx, step);
    if curIdx = 0 then
      curIdx := tgtCount;
    if curIdx > tgtCount then
      curIdx := 1;
    AdvanceAimTarget := GDVars.creatureArr[targets[curIdx].idx];
    nextX := GDVars.arenaLoc[targets[curIdx].idx].x;
    nextY := GDVars.arenaLoc[targets[curIdx].idx].y;
    if animate then begin
      CharHlp.CombatAnimateMovingIcon(curX, curY, nextX, nextY, 1, 0);
      curX := nextX;
      curY := nextY;
    end;
  end;

begin
  { the aim cursor icon }
  CharHlp.CopyIconFacing(25, 0, 0, False);
  FillChar(tgt, SizeOf(Types.TAimTarget), 0);
  done := False;
  effRange := range;
  if effRange = 255 then
    if creature^.equipped[C_Equip.WEAPON] <> nil then
      effRange := GDVars.baseItems[creature^.equipped[C_Equip.WEAPON]^.itemType].range - 1
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
  while (done = False) and (not (ch in [C_Keys.NONE, 'E'])) do
  begin
    if not CbtActs.CanAttackTarget(creature, p) then
      p := AdvanceAimTarget(skipStep, False)
    else begin
      ch := CbtActs.AimTargetMenu(creature, p, effRange, weaponMode, groundOk);
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
            CbtActs.ManualAimCursor(creature, p, effRange, weaponMode, groundOk, done, Types.TAimTarget(tgt));
            CharHlp.CopyIconFacing(25, 0, 0, False);
            BuildAimTargets(creature);
            menuStep := 0;
          end;
        'T':
          begin
            CbtActs.ConfirmAttackTarget(creature, p, weaponMode, done, Types.TAimTarget(tgt));
            CharHlp.CopyIconFacing(25, 0, 0, False);
            BuildAimTargets(creature);
            menuStep := 0;
          end;
        'C':
          begin
            CbtMap.ScrollView(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), 0, C_Dir.CENTER);
            menuStep := 0;
          end;
      end;
      CbtMap.RedrawArenaCell(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p));
      p := AdvanceAimTarget(menuStep, (done = False) and (not (ch in [C_Keys.NONE, 'E'])));
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
      GDVars.arenaPtr^.distMode := 1;
    tries := 20;
    cnt := CharHlp.CountTargets(creature, range);
    while (tries > 0) and (not found) and (cnt > 0) do begin
      Dec(tries);
      pick := FxEngine.RollDice(1, cnt);
      if GDVars.dsPotentialTargetCreature[pick] > 0 then begin
        p := GDVars.creatureArr[GDVars.dsPotentialTargetCreature[pick]];
        if ((relaxed <> 0) and (GDVars.arenaPtr^.distMode <> 0))
           or CbtActs.CanAttackTarget(creature, p) then begin
          found := True;
          creature^.combatAddr^.other := p;
        end else begin
          GDVars.dsPotentialTargetCreature[pick] := 0;
          { pick is reused as the index: do any targets remain? }
          for pick := 1 to cnt do
            if GDVars.dsPotentialTargetCreature[pick] > 0 then
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
  GDVars.arenaPtr^.distMode := 0;
  AcquireTarget := found;
end;

{ C_Effect.REAR_CLAW_RAKE (73) handler (TEffectHandler shape; p and removed unused): when both primary attacks hit
  (hitsMade[1] = 2) and the locked target is still up, rake it with two 2d4 secondary attacks, then end the creature's
  actions. }
procedure RearClawRake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  done: Boolean;
begin
  if GDVars.hitsMade[1] = 2 then
    if creature^.combatAddr^.other^.enabled <> 0 then begin
      creature^.combatAddr^.attackPhase := 2;
      creature^.curAttacks2 := 2;
      creature^.curRollsA[2] := 2;
      creature^.curDiceA[2] := 4;
      creature^.curAttacks := 0;
      CharHlp.PrintNameString(creature, 'Rakes...', 10, True);
      CbtActs.CombatAttack(creature, creature^.combatAddr^.other, False, nil, done);
      done := CharHlp.EndActions(creature);
    end;
end;

{ C_Effect.BITE_HOLD (74) handler; p is the effect, whose strength holds the victim's creature index. While the hold
  lasts, each trigger is one 3d4 bite on the victim as from behind, ending the creature's actions; a victim that drops
  ends the hold. On removal, or when either side is down, the victim loses C_Effect.IMMOBILE (58), and the hold itself
  is removed (onRemove cleared first) unless it is already being removed. }
procedure BiteAndHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  done: Boolean;
begin
  GDVars.dsOtherCreatureCurrentPtr := GDVars.creatureArr[Types.PEffectRec(p)^.strength];
  if removed or (creature^.enabled = 0) or (GDVars.dsOtherCreatureCurrentPtr^.enabled = 0) then begin
    FxEngine.RemoveEffect(GDVars.dsOtherCreatureCurrentPtr, C_Effect.IMMOBILE, nil);
    if not removed then begin
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, C_Effect.BITE_HOLD, p);
    end;
  end else begin
    creature^.curAttacks := 1;
    creature^.curAttacks2 := 0;
    creature^.curRollsA[1] := 3;
    creature^.curDiceA[1] := 4;
    CbtActs.CombatAttack(creature, GDVars.dsOtherCreatureCurrentPtr, True, nil, done);
    done := CharHlp.EndActions(creature);
    if GDVars.dsOtherCreatureCurrentPtr^.enabled = 0 then
      FxEngine.RemoveEffect(creature, C_Effect.BITE_HOLD, p);
  end;
end;

{ Alt-X cheat, active only when the first command-line parameter is STING: every hostile drops dead, every creature's
  actions end and the view is rebuilt. Returns False without STING. }
function StingVictoryCheat: Boolean;
var
  done: Boolean;
  p: Types.PCharRecord;
begin
  StingVictoryCheat := False;
  if ParamStr(1) <> 'STING' then
    Exit;
  StingVictoryCheat := True;
  CharHlp.PrintBottomLine('The Gods intervene!');
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.hostile = 1 then begin
      p^.enabled := 0;
      p^.status := C_Status.DEAD;
      GDVars.arenaLoc[CbtMap.CombatSlot(p)].size := 0;
    end;
    done := CharHlp.EndActions(p);
    p := p^.nextCharAddr;
  end;
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 255, C_Dir.CENTER);
end;

begin
end.
