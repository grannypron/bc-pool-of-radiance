{ Effect handlers for spells, items and creature abilities. Each handler receives the creature, the effect node or item
  concerned, and whether the effect is being removed or the item unreadied; it works through shared combat state such as
  GameVars.pendingDamage, the attack roll and FxEngine.saveRoll. }
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

procedure EffGnomeHitBonus(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffResistFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSilence(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSlowPoisonEnd(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSpiritualHammer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffInvisible(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDwarfHitBonus(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffMirrorImage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffEnfeeble(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffCoughing(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffAnimateDead(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBlind(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDiseased(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffAlliedPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBestowCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBlinking(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHasted(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffCastStink(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffProtNormalMissiles(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSlowed(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDiseaseStrength(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDiseaseHitPoints(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDwarfGiantDefense(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffGnomeBugDefense(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffRotNoHeal(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ eff 31, 51, 52, 53 }
procedure EffHelpless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffRingInvis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffMummyRot(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffImmobile(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffTrollRegen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffRingFireRes(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffConRegeneration(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPoisonHit0(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPoisonHit4(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPoisonHit2(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffKreenPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffGhoulPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDriderPara(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffPoisonHitM2(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDustOfDisappearance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

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

{ Drain levels from a creature; an animated creature, or one with no class levels, is destroyed instead. For each level
  the creature loses hpMax div (total class levels) from hpMax, hpRolled and hpCur, then either dies forever (highest
  level below 2) or loses a level in the class picked by ClassToDrain, dying if its HP reached 0, its skills and
  spell slots recalculated and the memorized spells past the new slots cleared (ClassCal.FitSpellsToLevel, POR-0223).
  Its highest level and experience are then reset from the class ClassToDrain picks after the loss. A dual-classed
  human (#838) is drained in the class it follows alone, as Pools of Darkness drains it (pools-disassembly v11
  effhndlr.pas:1829-1834): it loses hit points only for a level that gave them (ClassCal.HitDice), it is dead forever
  when that class is below level 2, a class it left rests again when the class it follows falls back to it
  (ChgClass.SyncClassPowers), and its highest level is that of its highest class. Each level lost and not dead
  forever goes on the drain log (CharExt.PushDrain, #1174): the experience it cost, its hit points and the class
  lowered, which Restoration gives back. }
procedure DrainLevels(creature: Types.PCharRecord; levels: Byte);

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

procedure EffElfResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffImmuneSleepCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffImmuneParalysis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNoCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffImmuneParalysisPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffImmuneFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffEfreetiFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfElectricity(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfPierce(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfMagical(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHolyWater(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNeedMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffDodgeBoulders(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffAnhkhegAcid(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffMummyFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffSilverMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHalfElfResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffNoCharmPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffGazeBlock(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ eff 128, 129, 130, 133, 134, 136, 138, 139 }
procedure EffReadyItem(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffGauntlets(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffAlignedWeapon(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffBoulder(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure EffHammerGone(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ The handler for effects whose presence is all that matters: eff 5, 13, 16, 19, 24, 27, 54, 55, 60, 63, 92, 127 }
procedure EffNone(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

function TouchImmune(target: Types.PCharRecord; effId: Byte): Boolean;

{ True when gazer has a clear line to target on the combat map within range squares (Pathing.WalkLine from cell to
  cell, as a ranged attack's: a diagonal step counts 1.5). False for no target, or one off the map. }
function InSight(gazer, target: Types.PCharRecord; range: Byte): Boolean;

{ True when a petrifying gaze can take target: it is in action (enabled: not down, dead or fled) and InSight within
  PETRIFY_GAZE_RANGE. }
function PetrifyGazeReaches(gazer, target: Types.PCharRecord): Boolean;

{ True when creature bears a silver shield: the item readied in its shield slot (C_EQUIP.SHIELD) has a "Silver" name
  component (C_ITEM.NAME_SILVER). It turns a petrifying gaze aside (#981). }
function SilverShielded(creature: Types.PCharRecord): Boolean;

implementation

uses C_ITEM, C_NPC, C_TERR, C_SAVE, C_COND, GameDefs, GameVars, CbtActs, ClassCal, FxEngine, Debug, C_EFFECT, C_EQUIP,
  C_RACE, C_STATUS, C_IFC, C_ALIGN, C_SPELL, CbtMap, CharHlp, Pathing, TextRend, StrUtil, CharDisp, AbilAdj,
  C_LEVEL, Dice, Stats, ChgClass, Bestiary, C_BEAST, C_SPRITE, CharExt;

const
  { The petrifying gaze's range in squares (1" a square). The Monster Manual gives the medusa's 3"; the basilisk's, the
    one other gazer in the monster data (MON*SPC eff 83, #938), has none listed, and takes the medusa's. }
  PETRIFY_GAZE_RANGE = 3;
  { set by TouchImmune for its immunity check: a monster's poisonous or paralyzing touch is no magic, so magic
    resistance does not meet it (MagicResistance; #800) }
  mundaneCheck: Boolean = False;

{ The creature's attack target (combatAddr^.other): nil when it has no combat record or no target yet. A handler run
  with no attack under way, as one an item's readying called before the creature's first attack was (POR-0231, #1094),
  does nothing with nil. }
function AttackTarget(creature: Types.PCharRecord): Types.PCharRecord;
begin
  AttackTarget := nil;
  if creature^.combatAddr <> nil then
    AttackTarget := creature^.combatAddr^.other;
end;

{ Nullify the attack or effect: zero GameVars.pendingDamage and GameVars.pendingEffectId. effId 0 always matches;
  otherwise only when effId is the id under the immunity check (pendingEffectId). }
procedure NullifyAttack(effId: Byte);
begin
  if (effId = 0) or (GameVars.pendingEffectId = effId) then begin
    GameVars.pendingDamage := 0;
    GameVars.pendingEffectId := 0;
  end;
end;

{ The Bestiary's fact for an immunity to effect effId: sleep and charm, paralysis or poison; 255, no fact, for any
  other. }
function ImmunityFact(effId: Byte): Byte;
begin
  case effId of
    C_EFFECT.SLEEP, C_EFFECT.CHARM: ImmunityFact := C_BEAST.IMMUNE_SLEEP_CHARM;
    C_EFFECT.PARALYZED: ImmunityFact := C_BEAST.IMMUNE_PARALYSIS;
    C_EFFECT.POISONED: ImmunityFact := C_BEAST.IMMUNE_POISON;
  else
    ImmunityFact := 255;
  end;
end;

{ After an immunity handler of creature's ran its NullifyAttack calls: when they cleared the effect effId or the damage
  dmg pending before them, the party member acting (GameVars.curChar) has seen creature shrug it off, fact in the
  Bestiary (#842). }
procedure NoteNullified(creature: Types.PCharRecord; effId, dmg, fact: Byte);
begin
  if ((effId <> 0) and (GameVars.pendingEffectId = 0)) or ((dmg <> 0) and (GameVars.pendingDamage = 0)) then
    Bestiary.Learn(creature, GameVars.curChar, fact);
end;

{ An immunity handler's NullifyAttack calls on creature have run with effect effId pending before them: when they
  cleared it, the fact ImmunityFact gives it goes in the Bestiary (NoteNullified). }
procedure NoteImmunity(creature: Types.PCharRecord; effId: Byte);
begin
  EffHndlr.NoteNullified(creature, effId, 0, EffHndlr.ImmunityFact(effId));
end;

{ A half-damage handler of creature's halves the pending damage: the party member whose blow or spell it was
  (GameVars.curChar) sees it, fact in the Bestiary (#842). }
procedure HalveDamage(creature: Types.PCharRecord; fact: Byte);
begin
  if GameVars.pendingDamage > 0 then
    Bestiary.Learn(creature, GameVars.curChar, fact);
  GameVars.pendingDamage := GameVars.pendingDamage div 2;
end;

{ Fire damage on creature is lessened (effs 61 and 113): the party member whose fire it was (GameVars.curChar) sees it,
  in the Bestiary (#1142). }
procedure NoteFireResisted(creature: Types.PCharRecord);
begin
  if GameVars.pendingDamage > 0 then
    Bestiary.Learn(creature, GameVars.curChar, C_BEAST.RESISTS_FIRE);
end;

{ A blow on creature with neither a silver nor a magical weapon does nothing (effs 96 and 123): one that would have hurt
  it shows the party member who struck it (GameVars.curChar) that it needs one, in the Bestiary (#1110). }
procedure NoHarmWithoutSilver(creature: Types.PCharRecord);
begin
  if GameVars.pendingDamage > 0 then
    Bestiary.Learn(creature, GameVars.curChar, C_BEAST.SILVER_OR_MAGIC);
  GameVars.pendingDamage := 0;
end;

{ FxEngine.AddEffect unless the effect lock is on; returns True when the effect was added. The parameter order differs
  from FxEngine.AddEffect (strength before minutes), and onRemove is always True. }
function AddEffectIfNoLock(creature: Types.PCharRecord; effId, strength: Byte; minutes: Word): Boolean;
begin
  if GameVars.effectLock <> 0 then
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
    C_STATUS.STONED, C_STATUS.DEAD_STATUS, C_STATUS.GONE: Exit;
  end;
  creature^.status := status;
  creature^.enabled := 0;
  creature^.hpCur := 0;
  if status in [C_STATUS.DEAD_STATUS, C_STATUS.GONE] then
    Stats.Death(creature);
  FxEngine.RemoveEffectsHp0(creature);
  FxEngine.TriggerEffectsWithCondition(C_COND.HP_ZERO, creature);
  if creature^.enabled = 0 then
    CbtMap.CreatureDowned(creature);
  TextRend.PauseOnly;
  CharDisp.ClearMessageWindow;
  CharDisp.RedrawPartyOutOfCombat;
end;

{ A disease's or Slow Poison's tick: 1 point of damage from source (C_EFFECT.ELEM_DISEASE or ELEM_POISON, which its
  message names) while the creature has more than 1 hit point, and the party redrawn out of combat. False, with no
  damage, at 1 hit point or less. }
function TickDamage(creature: Types.PCharRecord; source: Byte): Boolean;
begin
  TickDamage := creature^.hpCur > 1;
  if creature^.hpCur > 1 then begin
    GameVars.elementMask := source;
    FxEngine.InflictNonWeaponDamage(creature, 1, 0, False);
    CharDisp.RedrawPartyOutOfCombat;
  end;
end;

{ Halve the pending damage and add 3 to the saving throw when it is of element elem (C_EFFECT.ELEM_*): Resist Cold and
  Resist Fire. }
procedure ResistElement(elem: Byte);
begin
  if GameVars.elementMask and elem <> 0 then begin
    GameVars.pendingDamage := GameVars.pendingDamage div 2;
    Inc(FxEngine.saveRoll, 3);
  end;
end;

{ An immunity to element elem (C_EFFECT.ELEM_*): an attack of that element is nullified, and fact goes in the Bestiary
  when it cleared damage or an effect (NoteNullified). }
procedure ElementImmunity(creature: Types.PCharRecord; elem, fact: Byte);
var
  effId: Byte;
  dmg: Byte;
begin
  effId := GameVars.pendingEffectId;
  dmg := GameVars.pendingDamage;
  if GameVars.elementMask and elem <> 0 then begin
    EffHndlr.NullifyAttack(0);
    EffHndlr.NoteNullified(creature, effId, dmg, fact);
  end;
end;

{ A racial resistance to sleep and charm: pct% of the time it nullifies either (elves 90, half-elves 30). }
procedure SleepCharmResist(pct: Byte);
begin
  if Dice.RollDice(1, 100) <= pct then begin
    EffHndlr.NullifyAttack(C_EFFECT.SLEEP);
    EffHndlr.NullifyAttack(C_EFFECT.CHARM);
  end;
end;

type
  { the name lists NamedIn reads; each is declared with its own length }
  TNameList = array[1..255] of Types.TName15;

{ True when creature's name is one of the first count entries of names, an array of Types.TName15. }
function NamedIn(creature: Types.PCharRecord; var names; count: Byte): Boolean;
var
  i: Byte;
  found: Boolean;
begin
  found := False;
  for i := 1 to count do
    if creature^.name = TNameList(names)[i] then
      found := True;
  NamedIn := found;
end;

{ A racial to-hit bonus: +1 when creature's combat target is a one-tile creature of charType 0 or 1 named in names
  (count entries). The type may be 0 as well as 1: the monster data gives the dwarves' HOBGOBLIN LDR and GRISHNAK 0. }
procedure RacialFoeBonus(creature: Types.PCharRecord; var names; count: Byte);
begin
  GameVars.combatTarget := EffHndlr.AttackTarget(creature);
  if GameVars.combatTarget = nil then
    Exit;
  if GameVars.combatTarget^.charType <= 1 then
    if GameVars.combatTarget^.iconDimensions = 1 then
      if EffHndlr.NamedIn(GameVars.combatTarget, names, count) then
        Inc(GameVars.gAttackRoll);
end;

{ True when one of item's name components (TItemRec.nameIds) is name. }
function HasName(item: Types.PItemRec; name: Byte): Boolean;
begin
  HasName := (item^.nameIds[1] = name) or (item^.nameIds[2] = name) or (item^.nameIds[3] = name);
end;

{ True for a mirror: an item with a "Mirror" name component (C_ITEM.NAME_MIRROR), which turns back a gaze. }
function IsMirror(item: Types.PItemRec): Boolean;
begin
  IsMirror := EffHndlr.HasName(item, C_ITEM.NAME_MIRROR);
end;

function SilverShielded(creature: Types.PCharRecord): Boolean;
var
  shield: Types.PItemRec;
begin
  shield := creature^.equipped[C_EQUIP.SHIELD];
  SilverShielded := (shield <> nil) and EffHndlr.HasName(shield, C_ITEM.NAME_SILVER);
end;

{ The start of a hold (blood drain, bite and hold): True, with the creature's combat target in
  GameVars.combatTarget and its combat slot in slot, when it has a target on the map. }
function HoldSlot(creature: Types.PCharRecord; var slot: Byte): Boolean;
begin
  HoldSlot := False;
  GameVars.combatTarget := EffHndlr.AttackTarget(creature);
  if GameVars.combatTarget = nil then
    Exit;
  slot := CbtMap.CombatSlot(GameVars.combatTarget);
  HoldSlot := slot <> 0;
end;

{ Hold the victim fast: a permanent C_EFFECT.IMMOBILE, its handler run at once. }
procedure Immobilize(victim: Types.PCharRecord);
begin
  FxEngine.AddEffect(victim, C_EFFECT.IMMOBILE, 0, 255, False);
  FxEngine.CallEffectHandler(C_EFFECT.IMMOBILE, victim, nil, False);
end;

{ Bless (eff 1) }
procedure EffBless(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Inc(GameVars.combatMorale, 5);
  Inc(GameVars.gAttackRoll);
end;

{ Curse (eff 2) }
procedure EffCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GameVars.combatMorale < 5 then
    GameVars.combatMorale := 0
  else
    Dec(GameVars.combatMorale, 5);
  Dec(GameVars.gAttackRoll);
end;

{ Undead slaying weapon (eff 3) }
procedure EffUndeadSlayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GameVars.combatTarget := EffHndlr.AttackTarget(creature);
  if GameVars.combatTarget = nil then
    Exit;
  if GameVars.combatTarget^.charType = CharHlp.UNDEAD_TYPE then begin
    Inc(GameVars.gAttackRoll, 2);
    Inc(GameVars.pendingDamage, 2);
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
  GameVars.combatTarget := EffHndlr.AttackTarget(creature);
  if GameVars.combatTarget = nil then
    Exit;
  case GameVars.combatTarget^.charType of
    { regenerating }
    10: bonus := 1;
    { cold-based / avian }
    9, 12: bonus := 2;
    CharHlp.UNDEAD_TYPE: bonus := 3;
  else
    bonus := 0;
  end;
  Inc(GameVars.gAttackRoll, bonus);
  Inc(GameVars.pendingDamage, bonus);
  { magical fire }
  GameVars.elementMask := C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC;
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
  caster (GameVars.curChar) has the alignment warded against, and it is on the other side. A script's attack or damage
  has no attacker, and curChar is then a party member. The penalty is taken under C_COND.ATTACK_ROLL_DEF, after the d20
  is rolled; SSI's took it under C_COND.DEFENDER_AC, before the roll replaced it, so it never applied (#789). The sides
  are teams (CharHlp.Team), as a damaged save can hold a hostile byte above 1. }
procedure Protection(creature: Types.PCharRecord; foe: Boolean);
begin
  if foe and (CharHlp.Team(GameVars.curChar) <> CharHlp.Team(creature)) then begin
    Inc(FxEngine.saveRoll, 2);
    Dec(GameVars.gAttackRoll, 2);
  end;
end;

{ Protection from Evil (eff 8, 45) }
procedure EffProtEvil(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.Protection(creature, GameVars.curChar^.alignment in C_ALIGN.EVIL_ALIGNMENTS);
end;

{ Protection from Good (eff 9, 46) }
procedure EffProtGood(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.Protection(creature, GameVars.curChar^.alignment in [C_ALIGN.LAWFUL_GOOD, C_ALIGN.NEUTRAL_GOOD,
                                                                C_ALIGN.CHAOTIC_GOOD]);
end;

{ Resist Cold (eff 10) }
procedure EffResistCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.ResistElement(C_EFFECT.ELEM_COLD);
end;

{ Charm (eff 11). strength packs: bit 5 = applied mark, bit 6 = saved hostility, bit 7 = charmer side }
procedure EffCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then begin
    creature^.hostile := (Types.PEffectRec(p)^.strength and $40) div 64;
    if creature^.npc = C_NPC.ANIMATED_PC then
      creature^.npc := 0;
  end else begin
    if Types.PEffectRec(p)^.strength and $20 = 0 then begin
      Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength + $20 + CharHlp.Team(creature) * 64;
      creature^.hostile := Types.PEffectRec(p)^.strength div 128;
      creature^.quickfight := 1;
      { C_NPC.FLAG clear }
      if not CharHlp.IsNpc(creature) then
        creature^.npc := C_NPC.ANIMATED_PC;
      creature^.combatAddr^.other := nil;
      CharHlp.CountTeams;
    end;
    GameVars.combatMorale := 100;
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
        if (base > bestBase) or ((base = bestBase) and (exc > bestExc)) then begin
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

{ Friends (eff 14), as it ends: take back the Charisma it gave (FxEngine.FriendsEndCha). SSI's put back the Charisma
  stored at casting, so a second Friends, which stored the first one's raised score, left a lasting gain (POR-0212,
  #920). }
procedure EffFriends(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if p <> nil then
    creature^.chaCur := FxEngine.FriendsEndCha(creature^.chaCur, Types.PEffectRec(p)^.strength);
end;

{ Slow Poison periodic damage (eff 15): re-arm for 10 minutes and deal 1 damage while HP > 1 }
procedure EffSlowPoisonHit(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.SLOW_POISON_HIT, Types.PEffectRec(p)^.strength, 10) then
    if EffHndlr.TickDamage(creature, C_EFFECT.ELEM_POISON) then ;
end;

{ Shield (eff 17) }
procedure EffShield(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  { 60-biased AC 3 }
  if creature^.acCur < 57 then
    creature^.acCur := 57;
  Inc(FxEngine.saveRoll);
  { the wand's missiles too, not only the spell's (POR-0210, #890) }
  if GameVars.spellId in C_SPELL.MAGIC_MISSILES then
    GameVars.pendingDamage := 0;
end;

{ Gnome THAC0 bonus (eff 18) }
procedure EffGnomeHitBonus(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
const
  { the monsters a gnome gets its THAC0 bonus against }
  gnomeFoes: array[1..5] of Types.TName15 = (
    'KOBOLD', 'KOBOLD LEADER', 'GOBLIN', 'GOBLIN LEADER', 'GOBLIN GUARD');
begin
  EffHndlr.RacialFoeBonus(creature, gnomeFoes, SizeOf(gnomeFoes) div SizeOf(Types.TName15));
end;

{ Resist Fire (eff 20) }
procedure EffResistFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.ResistElement(C_EFFECT.ELEM_FIRE);
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
    EffHndlr.InflictStatusMsg(creature, C_STATUS.DEAD_STATUS, 'dies from poison');
  GameVars.effectLock := 1;
  FxEngine.RemoveEffect(creature, C_EFFECT.SLOW_POISON_HIT, nil);
  GameVars.effectLock := 0;
end;

{ Spiritual Hammer (eff 23). The hammer is a C_ITEM.HAMMER whose nameIds[3] is C_ITEM.NAME_SPIRITUAL. Removal deletes
  the hammer; otherwise one is created (+1, special = eff 137) when missing and the creature has fewer than
  C_ITEM.CARRY_MAX items. }
procedure EffSpiritualHammer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  found: Byte;
begin
  item := creature^.itemsAddr;
  found := 0;
  while (item <> nil) and (found = 0) do
    if (item^.itemType = C_ITEM.HAMMER) and (item^.nameIds[3] = C_ITEM.NAME_SPIRITUAL) then
      found := 1
    else
      item := item^.next;
  if removed and (item <> nil) then
    CharHlp.RemoveItem(creature, item);
  if not removed then
    if found = 0 then
      if creature^.numberOfItems < C_ITEM.CARRY_MAX then begin
        GetMem(item, SizeOf(Types.TItemRec));
        FillChar(item^, SizeOf(Types.TItemRec), 0);
        item^.itemType := C_ITEM.HAMMER;
        item^.nameIds[2] := C_ITEM.NAME_HAMMER;
        item^.nameIds[3] := C_ITEM.NAME_SPIRITUAL;
        item^.plus := 1;
        item^.effect := C_EFFECT.SPIRITUAL_HAMMER;
        item^.special := C_EFFECT.SPIRIT_HAMMER_GONE;
        CharHlp.AppendItemCopy(creature^.itemsAddr, item);
        FreeMem(item, SizeOf(Types.TItemRec));
        CharDisp.PrintNameString(creature, 'Gains an item', 10, True);
      end;
  CharHlp.RecalcStats(creature);
end;

{ Invisibility (eff 25). An attacker (GameVars.curChar) that sees invisible creatures shows it to the invisible party
  member it goes for, in the Bestiary (#1142). }
procedure EffInvisible(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if not CharHlp.HasEffect(GameVars.curChar, C_EFFECT.SEE_INVISIBLE, effect) then
    CbtActs.suppressTargeting := 1
  else
    Bestiary.Learn(GameVars.curChar, creature, C_BEAST.SEES_INVISIBLE);
  Dec(GameVars.gAttackRoll, 4);
end;

{ Dwarf THAC0 bonus (eff 26) }
procedure EffDwarfHitBonus(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
const
  dwarfFoes: array[1..11] of Types.TName15 = (
    'ORC', 'ORC LEADER', 'GOBLIN', 'GOBLIN LEADER',
    'HOBGOBLIN', 'HOBGOBLIN CHIEF', 'GAGOOL', 'MACE',
    'GOBLIN GUARD', 'HOBGOBLIN LDR', 'GRISHNAK');
begin
  EffHndlr.RacialFoeBonus(creature, dwarfFoes, SizeOf(dwarfFoes) div SizeOf(Types.TName15));
end;

{ Mirror Image (eff 28). strength = images left; against a single-target spell (spellId > 0, gMultiTarget = 0) an image
  absorbs it (FxEngine.ImageStruck) and is lost (LoseImage). Weapon hits are tested in CbtActs.RollAttacks. }
procedure EffMirrorImage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.ImageStruck(p) then
    if GameVars.spellId > 0 then
      if GameVars.gMultiTarget = 0 then begin
        EffHndlr.NullifyAttack(0);
        FxEngine.LoseImage(creature, p);
      end;
end;

{ Ray of Enfeeblement (eff 29): pendingDamage loses a quarter (rounded down) }
procedure EffEnfeeble(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GameVars.pendingDamage := GameVars.pendingDamage - GameVars.pendingDamage div 4;
end;

{ Coughing from Stinking Cloud (eff 30): no items or spells, and its AC from the front and behind is its rear AC less 2.
  It recalculates the creature's stats, so C_COND.DEFENDER_AC runs it before Blindness and Shield change the AC. }
procedure EffCoughing(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
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
  if creature = GameVars.curChar then
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
  if GameVars.effectLock = 0 then
    EffHndlr.InflictStatusMsg(creature, C_STATUS.DEAD_STATUS, 'collapses');
  creature^.hostile := side;
  creature^.quickfight := 1;
  creature^.levelUndead := 0;
  creature^.attackLevel := CharHlp.WarriorLevel(creature);
  creature^.movementBase := 12;
  if creature^.npc = C_NPC.ANIMATED_PC then
    creature^.npc := 0;
  creature^.charType := 0;
end;

{ Blind (eff 33) }
procedure EffBlind(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Dec(GameVars.gAttackRoll, 4);
  Dec(creature^.acCur, 4);
  Dec(creature^.acBehind, 4);
  Dec(FxEngine.saveRoll, 4);
end;

{ Diseased (eff 34): chains 43 + 44 }
procedure EffDiseased(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  FxEngine.CallEffectHandler(C_EFFECT.DISEASE_STRENGTH, creature, p, removed);
  FxEngine.CallEffectHandler(C_EFFECT.DISEASE_HIT_POINTS, creature, p, removed);
end;

{ Allied Prayer (eff 35): Prayer's bonus to the caster's side, +1 to saving throws and +1 to attack rolls. EffPrayer
  also applies it to creatures on the caster's side. }
procedure EffAlliedPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Inc(FxEngine.saveRoll);
  Inc(GameVars.gAttackRoll);
end;

{ Bestow Curse (eff 36) }
procedure EffBestowCurse(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Dec(GameVars.gAttackRoll, 4);
  Dec(FxEngine.saveRoll, 4);
end;

{ Blinking (eff 37): the party member acting (GameVars.curChar) sees it blink out of reach, in the Bestiary (#1122) }
procedure EffBlinking(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.combatAddr^.initiative > 0 then begin
    CbtActs.suppressTargeting := 1;
    GameVars.forcedMiss := True;
    Bestiary.Learn(creature, GameVars.curChar, C_BEAST.BLINKS);
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
  GameVars.currentAttackCurrent := CharHlp.HasteSlowRate(creature, GameVars.currentAttackCurrent);
end;

{ Cast Stinking Cloud (eff 40). Removes the cloud this caster is responsible for (strength upper nibble = its idx),
  restores or corpse-marks its cells, unlinks and frees the node, then repaints every remaining cloud }
procedure EffCastStink(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  q: Types.PStinkRec;
  node: Types.PStinkRec;
  cloudNum: Byte;
  corpse: Boolean;
  d: Byte;
  i: Byte;
  xx: Byte;
  yy: Byte;
begin
  cloudNum := Types.PEffectRec(p)^.strength div 16;
  node := GameVars.stinkHead;
  while (node <> nil) and not ((node^.caster = creature) and (node^.idx = cloudNum)) do
    node := node^.next;
  if node = nil then Exit;
  CharDisp.PrintBottomLine('The air clears a little...');
  { 4 = High(TStinkRec.exists) }
  for i := 1 to 4 do
    if node^.exists[i] <> 0 then begin
      xx := node^.ulX + GameDefs.dirDX[GameDefs.cloudDir[i]];
      yy := node^.ulY + GameDefs.dirDY[GameDefs.cloudDir[i]];
      corpse := False;
      for d := 1 to GameVars.downedCount do
        if (GameVars.downed[d].cr <> nil) and (GameVars.downed[d].x = xx) and (GameVars.downed[d].y = yy) then
          corpse := True;
      if corpse then
        GameVars.arenaPtr^.cells[yy, xx] := C_TERR.CORPSE
      else
        GameVars.arenaPtr^.cells[yy, xx] := node^.under[i];
    end;
  if GameVars.stinkHead = node then
    GameVars.stinkHead := node^.next
  else begin
    q := GameVars.stinkHead;
    while q^.next <> node do
      q := q^.next;
    q^.next := node^.next;
  end;
  FreeMem(node, SizeOf(Types.TStinkRec));
  q := GameVars.stinkHead;
  while q <> nil do begin
    { 4 = High(TStinkRec.exists) }
    for i := 1 to 4 do
      if q^.exists[i] <> 0 then
        GameVars.arenaPtr^.cells[q^.ulY + GameDefs.dirDY[GameDefs.cloudDir[i]],
                                 q^.ulX + GameDefs.dirDX[GameDefs.cloudDir[i]]] := C_TERR.STINKING_CLOUD;
    q := q^.next;
  end;
end;

{ Avoid the attack with pct% chance, only when the attacker (GameVars.curChar) has a weapon equipped and is more than
  one cell away: print "Avoids it", zero the damage, force a miss and take the hit back off hitsMade for the attacker's
  current attack phase. The attacker sees creature's fact, in the Bestiary (255 for none). }
procedure AvoidRanged(creature: Types.PCharRecord; pct, fact: Byte);
var
  phase: Byte;
begin
  if GameVars.curChar^.equipped[C_EQUIP.WEAPON] <> nil then
    if CbtMap.CalcDistance(GameVars.curChar, creature) > 1 then
      if Dice.RollDice(1, 100) <= pct then begin
        CharDisp.PrintNameString(creature, 'Avoids it', 10, True);
        Bestiary.Learn(creature, GameVars.curChar, fact);
        GameVars.pendingDamage := 0;
        GameVars.forcedMiss := True;
        phase := GameVars.curChar^.combatAddr^.attackPhase;
        { 1..2 = the bounds of hitsMade }
        if (phase >= 1) and (phase <= 2) then
          if CbtActs.hitsMade[phase] > 0 then
            Dec(CbtActs.hitsMade[phase]);
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
  if creature^.equipped[C_EQUIP.WEAPON] <> nil then begin
    ok := CharHlp.FindDamagingRangedWeapon(creature, sel);
    if (ok = False) or (sel = nil) then
      sel := creature^.equipped[C_EQUIP.WEAPON];
  end;
  FindDamagingWeapon := sel;
end;

{ Protection from Normal Missiles (eff 41): a normal missile (the damaging item has no plus) is stopped; a magical one
  does 1 less per die, no die below 1 (#745) }
procedure EffProtNormalMissiles(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  missile: Types.PItemRec;
begin
  missile := EffHndlr.FindDamagingWeapon(GameVars.curChar);
  if missile <> nil then
    if missile^.plus = 0 then
      EffHndlr.AvoidRanged(creature, 100, 255)
    else if CbtMap.CalcDistance(GameVars.curChar, creature) > 1 then
      Dice.ReduceDamagePerDie(1);
end;

{ Slowed (eff 42): halves currentAttackCurrent by CharHlp.HasteSlowRate, as EffHasted doubles it. }
procedure EffSlowed(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GameVars.currentAttackCurrent := CharHlp.HasteSlowRate(creature, GameVars.currentAttackCurrent);
end;

{ Disease Strength drain (eff 43; p is this node, or Diseased's, eff 34, as the disease starts): re-arm for 60 minutes
  and lose 1 Strength; at Strength 3 become helpless. The node counts the Strength lost in its strength byte's upper
  nibble (CharHlp.DiseaseStrLoss), up to 15, the most a natural 18 can lose; the lower keeps the caster level, at most
  15. A cure removes the node under the effect lock, and the count is given back: SSI kept no count, and the Strength
  stayed lost (#705). }
procedure EffDiseaseStrength(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
  loss: Byte;
  level: Byte;
  weaken: Boolean;
begin
  if Types.PEffectRec(p)^.id = C_EFFECT.DISEASE_STRENGTH then begin
    loss := Types.PEffectRec(p)^.strength shr 4;
    level := Types.PEffectRec(p)^.strength and $F;
  end else begin
    loss := 0;
    level := Types.PEffectRec(p)^.strength;
    if level > 15 then
      level := 15;
  end;
  weaken := (creature^.strCur > 3) and (loss < 15);
  if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.DISEASE_STRENGTH, (loss + Ord(weaken)) * 16 + level, 60) then begin
    if weaken then begin
      CharDisp.PrintNameString(creature, 'is weakened', 10, True);
      Dec(creature^.strCur);
      CharHlp.RecalcStats(creature);
    end else if creature^.strCur <= 3 then
      if not CharHlp.HasEffect(creature, C_EFFECT.HELPLESS, effect) then
        FxEngine.AddEffect(creature, C_EFFECT.HELPLESS, 0, 255, False);
  end else if removed and (Types.PEffectRec(p)^.id = C_EFFECT.DISEASE_STRENGTH) and (loss > 0) then begin
    creature^.strCur := AbilAdj.ClampScore(creature^.strCur + loss);
    CharHlp.RecalcStats(creature);
  end;
end;

{ Disease hit point drain (eff 44): re-arm for 10 minutes and deal 1 damage; at 1 HP become helpless }
procedure EffDiseaseHitPoints(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.DISEASE_HIT_POINTS, Types.PEffectRec(p)^.strength, 10) then
    if not EffHndlr.TickDamage(creature, C_EFFECT.ELEM_DISEASE) then
      if not CharHlp.HasEffect(creature, C_EFFECT.HELPLESS, effect) then
        FxEngine.AddEffect(creature, C_EFFECT.HELPLESS, 0, 255, False);
end;

{ Dwarf/gnome AC bonus vs giants (eff 47) }
procedure EffDwarfGiantDefense(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
const
  { The giant class whose attacks a dwarf or gnome makes at -4: ogres, trolls, giants and the ettin (#749) }
  giantFoes: array[1..6] of Types.TName15 = (
    'OGRE', 'OGRE LEADER', 'TROLL', 'FIRE GIANT', 'HILL GIANT', 'ETTIN');
begin
  { The attacker is curChar: its name is tested, as are its type and size, not that of the defender's own target.
    charType 0, 1, 2 or 10 and size 1 or 2: the monster data gives the listed giants these (OGRE LEADER type 0 and size
    1, HILL GIANT and FIRE GIANT type 2, TROLL type 10, OGRE and ETTIN type 1). }
  if GameVars.curChar^.charType in [0, 1, 2, 10] then
    if GameVars.curChar^.iconDimensions and $7F in [1, 2] then
      if EffHndlr.NamedIn(GameVars.curChar, giantFoes, SizeOf(giantFoes) div SizeOf(Types.TName15)) then
        Dec(GameVars.gAttackRoll, 4);
end;

{ Gnome AC bonus vs bugbears/gnolls (eff 48) }
procedure EffGnomeBugDefense(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GameVars.curChar^.charType = 1 then
    if (GameVars.curChar^.name = 'BUGBEAR') or (GameVars.curChar^.name = 'GNOLL') then
      Dec(GameVars.gAttackRoll, 4);
end;

{ Prayer (eff 49). FxEngine.PrayerSide = the caster's side: creatures on that team (CharHlp.Team) get the
  EffAlliedPrayer bonus, all others -1 to attack rolls and saving throws. FxEngine.TriggerPrayer runs one from each side
  in reach. }
procedure EffPrayer(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if CharHlp.Team(creature) = FxEngine.PrayerSide(p) then
    EffHndlr.EffAlliedPrayer(creature, p, removed)
  else begin
    Dec(GameVars.gAttackRoll);
    Dec(FxEngine.saveRoll);
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
  if GameVars.effectLock <> 0 then Exit;
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
  if GameVars.currentCreatureCalculatingFlag <> 0 then
    GameVars.currentAttackCurrent := 0;
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
  if GameVars.elementMask and C_EFFECT.ELEM_FIRE <> 0 then begin
    EffHndlr.NoteFireResisted(creature);
    Dice.ReduceDamagePerDie(2);
    Inc(FxEngine.saveRoll, 4);
    if GameVars.elementMask and C_EFFECT.ELEM_MAGIC = 0 then
      EffHndlr.NullifyAttack(0);
  end;
end;

{ Regenerating from high Con (eff 62): re-arm for the creature's Constitution's interval (AbilAdj.ConRegenMinutes; 60,
  Constitution 20's, once it has fallen below 20) and restore 1 HP }
procedure EffConRegeneration(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
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
  poison bonus (AbilAdj.ConPoisonSave), or is immune to poison, it gets eff 55 and is killed. A party member it is tried
  on has seen the poison, saved or not (the Bestiary, #842). }
procedure PoisonTouch(creature: Types.PCharRecord; saveMod: ShortInt);
begin
  GameVars.combatTarget := EffHndlr.AttackTarget(creature);
  if GameVars.combatTarget = nil then
    Exit;
  Bestiary.Learn(creature, GameVars.combatTarget, C_BEAST.ATK_POISON);
  if not FxEngine.RollSavingThrow(GameVars.combatTarget, C_SAVE.PARALYZE,
                                  saveMod + AbilAdj.ConPoisonSave(GameVars.combatTarget^.conCur)) then
    if not EffHndlr.TouchImmune(GameVars.combatTarget, C_EFFECT.POISONED) then begin
      CharDisp.PrintNameString(GameVars.combatTarget, 'is Poisoned', 10, False);
      TextRend.PauseOnly;
      FxEngine.AddEffect(GameVars.combatTarget, C_EFFECT.POISONED, 0, 255, False);
      EffHndlr.InflictStatusMsg(GameVars.combatTarget, C_STATUS.DEAD_STATUS, 'is killed');
    end;
end;

{ Paralyze the attacker's combat target for minutes unless it saves vs. paralyzation with saveMod or is immune to
  paralysis. SSI's ignored saveMod, so the drider's -2 was lost (#785). As with poison, a party member it is tried on
  has seen it (#842). }
procedure ParalysisTouch(creature: Types.PCharRecord; minutes: Word; saveMod: ShortInt);
begin
  GameVars.combatTarget := EffHndlr.AttackTarget(creature);
  if GameVars.combatTarget = nil then
    Exit;
  Bestiary.Learn(creature, GameVars.combatTarget, C_BEAST.ATK_PARALYZE);
  if not FxEngine.RollSavingThrow(GameVars.combatTarget, C_SAVE.PARALYZE, saveMod) then
    if not EffHndlr.TouchImmune(GameVars.combatTarget, C_EFFECT.PARALYZED) then begin
      CharDisp.PrintNameStringAnim(GameVars.combatTarget, True, 'is Paralyzed');
      FxEngine.AddEffect(GameVars.combatTarget, C_EFFECT.PARALYZED, minutes, 12, False);
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
  if EffHndlr.AttackTarget(creature) = nil then
    Exit;
  if EffHndlr.AttackTarget(creature)^.race <> C_RACE.ELF then
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

{ Dust of Disappearance (eff 71): a stronger form of invisibility. Sets suppressTargeting and lowers
  gAttackRoll by 4. }
procedure EffDustOfDisappearance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  CbtActs.suppressTargeting := 1;
  Dec(GameVars.gAttackRoll, 4);
end;

{ Camouflaged / Cloak of Elvenkind (eff 72): 95% chance of invisibility (eff 25) for 1 minute }
procedure EffCamouflage(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if Dice.RollDice(1, 100) <= 95 then begin
    FxEngine.AddEffect(creature, C_EFFECT.INVISIBLE, 1, 12, False);
    { a monster that fades from sight shows it in the Bestiary (#1142) }
    Bestiary.Learn(creature, nil, C_BEAST.TURNS_INVISIBLE);
  end;
end;

{ Blood drain (eff 75). strength = victim's creature index; duration's upper bits = the x16 damage budget. An index
  outside creatureArr[1..arenaCount] (CombatSlot's 0 for a creature not in the arena) has no victim: the effect just
  goes. }
procedure EffBloodDrain(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  dmg: Byte;
  released: Boolean;
begin
  if FxEngine.HoldTarget(creature, p, removed, C_EFFECT.BLOOD_DRAIN, released) = nil then begin
    if released and (creature^.enabled <> 0) then
      if GameVars.combatTarget^.enabled <> 0 then
        creature^.combatAddr^.turned := 1;
  end else begin
    CharDisp.PrintNameString(creature, 'Sucks some Blood', 10, True);
    dmg := Dice.RollDamageDice(1, 4);
    GameVars.elementMask := C_EFFECT.ELEM_BLOOD;
    FxEngine.InflictNonWeaponDamage(GameVars.combatTarget, dmg, 0, False);
    if CharHlp.EndActions(creature) then ;
    if (GameVars.combatTarget^.enabled <> 0) and (Types.PEffectRec(p)^.duration div 16 > dmg) then
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
  if not EffHndlr.HoldSlot(creature, slot) then
    Exit;
  { a 12 hp budget in the upper bits of the duration }
  FxEngine.AddEffect(creature, C_EFFECT.BLOOD_DRAIN, 12 * 16 + 15, slot, True);
  EffHndlr.Immobilize(GameVars.combatTarget);
  Bestiary.Learn(creature, GameVars.combatTarget, C_BEAST.ATK_BLOOD);
end;

{ Bite attach (eff 77): add eff 74 (bite and hold, handled by CbtActs.BiteAndHold) on the biter and immobilize the
  target. No effect on a target with Strength 19+, or with no combat slot (none, or not on the map) }
procedure EffBiteHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  slot: Byte;
begin
  if not EffHndlr.HoldSlot(creature, slot) then
    Exit;
  if GameVars.combatTarget^.strCur < 19 then begin
    FxEngine.AddEffect(creature, C_EFFECT.BITE_HOLD, 0, slot, True);
    EffHndlr.Immobilize(GameVars.combatTarget);
    CharDisp.PrintNameString(GameVars.combatTarget, 'is held fast', 10, True);
    Bestiary.Learn(creature, GameVars.combatTarget, C_BEAST.ATK_HOLD);
  end;
end;

{ Healed from unconscious (eff 78): revive at the current HP, or retry in 1 minute if that fails. p is nil when
  FxEngine.RestoreHitPoints calls it at once, out of combat; the retry then has strength 0. SSI's read the strength
  through nil (a revival out of combat never fails, so it was not reached). }
procedure EffHealWake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  strength: Byte;
begin
  if p = nil then
    strength := 0
  else
    strength := Types.PEffectRec(p)^.strength;
  if not FxEngine.ReviveDeadCreature(creature, creature^.hpCur) then
    if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.HEAL_WAKE, strength, 1) then ;
end;

{ Melee fire touch (eff 79): +2d10 fire }
procedure EffFireTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GameVars.elementMask := C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC;
  if EffHndlr.AttackTarget(creature) <> nil then begin
    Bestiary.Learn(creature, EffHndlr.AttackTarget(creature), C_BEAST.ATK_FIRE);
    FxEngine.InflictNonWeaponDamage(EffHndlr.AttackTarget(creature), Dice.RollDamageDice(2, 10), 0, False);
  end;
end;

{ Melee acid squirt (eff 80): +1d4 acid }
procedure EffAcidSquirt(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GameVars.elementMask := C_EFFECT.ELEM_ACID;
  if EffHndlr.AttackTarget(creature) <> nil then begin
    Bestiary.Learn(creature, EffHndlr.AttackTarget(creature), C_BEAST.ATK_ACID);
    FxEngine.InflictNonWeaponDamage(EffHndlr.AttackTarget(creature), Dice.RollDamageDice(1, 4), 0, False);
  end;
end;

{ Dragon fear aura (eff 81). Walks the whole creature list: each enabled enemy saves vs. spell or, by highest level, is
  permanently paralyzed (0..3) or cursed (4, 5); level 6+ is unaffected. The party feels it, in the Bestiary (#1142). }
procedure EffDragonFear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  q: Types.PCharRecord;
  saved: Boolean;
begin
  Bestiary.Learn(creature, nil, C_BEAST.ATK_FEAR);
  q := GameVars.creatureList;
  while q <> nil do begin
    if q^.enabled <> 0 then
      if CharHlp.Team(q) <> CharHlp.Team(creature) then begin
        saved := FxEngine.RollSavingThrow(q, C_SAVE.SPELL, 0);
        case q^.levelHighest of
          0..3: FxEngine.AddEffectWithMessage(q, C_EFFECT.PARALYZED, 0, 12, False, True, saved,
                                              'is paralyzed with fear');
          4, 5: FxEngine.AddEffectWithMessage(q, C_EFFECT.CURSE, 0, 12, False, True, saved, 'is weakened by fear');
        end;
      end;
    q := q^.nextCharAddr;
  end;
end;

{ Mummy fear aura (eff 82). Removes an eff-82 node from EVERY creature (the mummy's own included); each enabled enemy
  then saves vs. paralyzation (+1 if its team has 6+ members, +2 if human) or is paralyzed with fear for 1d4 minutes.
  The party feels it, in the Bestiary (#1122). }
procedure EffMummyFear(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  q: Types.PCharRecord;
  bonus: Byte;
  saved: Boolean;
begin
  Bestiary.Learn(creature, nil, C_BEAST.ATK_FEAR);
  q := GameVars.creatureList;
  while q <> nil do begin
    FxEngine.RemoveEffect(q, C_EFFECT.MUMMY_FEAR, nil);
    if q^.enabled <> 0 then
      if CharHlp.Team(q) <> CharHlp.Team(creature) then begin
        bonus := 0;
        if GameVars.teamCount[CharHlp.Team(q)] >= 6 then
          Inc(bonus);
        if q^.race = C_RACE.HUMAN then
          Inc(bonus, 2);
        saved := FxEngine.RollSavingThrow(q, C_SAVE.PARALYZE, bonus);
        FxEngine.AddEffectWithMessage(q, C_EFFECT.PARALYZED, Dice.RollDice(1, 4), 12, False, True, saved,
                                      'is paralyzed with fear');
      end;
    q := q^.nextCharAddr;
  end;
end;

function InSight(gazer, target: Types.PCharRecord; range: Byte): Boolean;
var
  dist: Word;
  x: ShortInt;
  y: ShortInt;
begin
  InSight := False;
  if target = nil then Exit;
  if CbtMap.CombatSlot(target) = 0 then Exit;
  { the budget in squares, read by WalkLine on entry }
  dist := range;
  x := CbtMap.CombatCellX(target);
  y := CbtMap.CombatCellY(target);
  InSight := Pathing.WalkLine(CbtMap.CombatCellX(gazer), CbtMap.CombatCellY(gazer), x, y, dist, GameVars.arenaPtr);
end;

function PetrifyGazeReaches(gazer, target: Types.PCharRecord): Boolean;
begin
  PetrifyGazeReaches := (target <> nil) and (target^.enabled <> 0) and
                        EffHndlr.InSight(gazer, target, PETRIFY_GAZE_RANGE);
end;

{ Petrifying gaze (eff 83): the target saves vs. petrification or is stoned. Effect 127 on the gazer marks the gaze
  reflectable: an equipped mirror (EffHndlr.IsMirror) turns it back on the gazer. A silver shield on whoever the gaze
  then meets turns it aside, the gaze lost (EffHndlr.SilverShielded, #981). The gaze runs as the gazer's AI turn
  starts (C_COND.MONSTER_SPECIAL), at the target it last chose: there is a gaze only when PetrifyGazeReaches it (in
  action, within PETRIFY_GAZE_RANGE squares and in sight). SSI's gazed at that target wherever it was and whatever its
  state, so a basilisk stoned a dying character across the map, and on the gazer's first turn, with no target yet
  (combatAddr is zeroed as combat starts), it gazed at nil, saving and stoning through it (POR-0217, #938). }
procedure EffPetrifyGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  reflected: Boolean;
  effect: Types.PEffectRec;
begin
  GameVars.combatTarget := EffHndlr.AttackTarget(creature);
  if GameVars.combatTarget = nil then
    Exit;
  if not EffHndlr.PetrifyGazeReaches(creature, GameVars.combatTarget) then Exit;
  Bestiary.Learn(creature, GameVars.combatTarget, C_BEAST.ATK_PETRIFY);
  CharDisp.PrintNameString(creature, 'gazes...', 10, False);
  CharDisp.AnimateBetween(creature, GameVars.combatTarget, C_SPRITE.MISSILE, 4, 45);
  if CharHlp.HasEffect(creature, C_EFFECT.GAZE_REFLECTABLE, effect) then begin
    reflected := False;
    item := GameVars.combatTarget^.itemsAddr;
    while (item <> nil) and not reflected do begin
      if (item^.equipped <> 0) and EffHndlr.IsMirror(item) then begin
        CharDisp.PrintNameString(GameVars.combatTarget, 'reflects it!', 12, False);
        CharDisp.AnimateBetween(GameVars.combatTarget, creature, C_SPRITE.MISSILE, 4, 45);
        reflected := True;
        GameVars.combatTarget := creature;
      end;
      item := item^.next;
    end;
  end;
  if EffHndlr.SilverShielded(GameVars.combatTarget) then begin
    CharDisp.PrintNameString(GameVars.combatTarget, 'is shielded from it!', 12, False);
    Exit;
  end;
  if not FxEngine.RollSavingThrow(GameVars.combatTarget, C_SAVE.PETRIFY, 0) then
    EffHndlr.InflictStatusMsg(GameVars.combatTarget, C_STATUS.STONED, 'is Stoned');
end;

{ Charming gaze (eff 84): with a clear line to an attackable target within Charm Person's range, apply Charm Person's
  charm (save vs. spell at -2) without using a spell slot or action. The gaze is no spell: magic resistance meets it at
  its listed figure, as it does the other gazes (EffHndlr.MagicResistance). SSI's marked the spell being cast as Charm
  Person while it applied the charm, so the resistance was adjusted by the gazer's mage level (#799). }
procedure EffCharmGaze(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
  target: Types.PCharRecord;
begin
  target := EffHndlr.AttackTarget(creature);
  GameVars.combatTarget := target;
  if target = nil then
    Exit;
  if not CbtActs.CanTarget(creature, target, True) then Exit;
  { the range of the Charm Person the gaze applies }
  if not EffHndlr.InSight(creature, target, GameDefs.spellTable[C_SPELL.CHARM_PERSON].rangeFixed) then Exit;
  CharDisp.PrintNameString(creature, 'Gazes...', 10, False);
  Bestiary.Learn(creature, target, C_BEAST.ATK_CHARM);
  CharDisp.AnimateBetween(creature, target, C_SPRITE.MISSILE, 4, 45);
  FxEngine.AddEffectWithMessage(target, C_EFFECT.CHARM, 0, CharHlp.Team(creature) * 128 + 12, True, True,
                                FxEngine.RollSavingThrow(target, C_SAVE.SPELL, -2), 'is charmed');
  if CharHlp.HasEffect(target, C_EFFECT.CHARM, effect) then
    FxEngine.CallEffectHandler(C_EFFECT.CHARM, target, effect, False);
end;

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
  dual: Boolean;
  top: ShortInt;
  xpBefore: LongInt;
  lowered: ShortInt;
  lost: LongInt;

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
    for jj := C_LEVEL.CLERIC to C_LEVEL.MONK do begin
      lvl := creature^.classLevels[jj];
      { a dual-classed human's classes left are never drained }
      if creature^.portExt.formerClasses and (1 shl jj) <> 0 then
        lvl := -1;
      { xp[] runs to level 9; a level above it reads level 9's entry }
      if lvl > C_LEVEL.LEVEL_LAST then
        xpTry := ClassCal.LevelXp(jj, C_LEVEL.LEVEL_LAST)
      else
        xpTry := ClassCal.LevelXp(jj, lvl);
      if (lvl >= bestLvl) and (lvl >= 0) then
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
      dual := CharHlp.IsDualClass(creature);
      for j := C_LEVEL.CLERIC to C_LEVEL.MONK do
        if dual then
          Inc(totalLevels, ClassCal.HitDice(creature, j))
        else
          Inc(totalLevels, creature^.classLevels[j]);
      { a creature with no class levels (kobolds, bandits and other monsters) has no level to lose, and no divisor }
      if totalLevels = 0 then begin
        EffHndlr.InflictStatusMsg(creature, C_STATUS.GONE, 'is dead forever');
        creature^.hpMax := 0;
        Exit;
      end;
      hpPerLevel := creature^.hpMax div totalLevels;
      { a level of the class a dual-classed human follows gave hit points only past the classes it left }
      if dual and (ClassCal.HitDice(creature, creature^.charClass) = 0) then
        hpPerLevel := 0;
      { tested here, so a drain loads Debug only with the STING display on }
      if GameVars.stingHpFlag <> 0 then
        Debug.PrintHpDebug('max,cur,lost', creature^.hpMax, creature^.hpCur, creature^.drainedHps);
      xpBefore := creature^.experience;
      { no class lowered yet: a creature dead forever logs nothing }
      lowered := -1;
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
      if dual then
        top := creature^.classLevels[cls]
      else
        top := creature^.levelHighest;
      if top < 2 then begin
        EffHndlr.InflictStatusMsg(creature, C_STATUS.GONE, 'is dead forever');
        creature^.hpMax := 0;
        { SSI's: only a two-level drain clears the class's level }
        if levels = 2 then
          creature^.classLevels[cls] := 0;
      end else begin
        Dec(creature^.classLevels[cls]);
        lowered := cls;
        if creature^.hpCur = 0 then
          if creature^.status <> C_STATUS.DEAD_STATUS then
            EffHndlr.InflictStatusMsg(creature, C_STATUS.DEAD_STATUS, 'is killed');
        ClassCal.RecalcBaseSkills(creature);
        ClassCal.FitSpellsToLevel(creature);
      end;
      { picked again, after the loss, with xpMin for it }
      cls := ClassToDrain;
      creature^.levelHighest := creature^.classLevels[cls];
      if dual then
        for j := C_LEVEL.CLERIC to C_LEVEL.MONK do
          if creature^.classLevels[j] > creature^.levelHighest then
            creature^.levelHighest := creature^.classLevels[j];
      creature^.experience := xpMin;
      if lowered >= 0 then begin
        lost := xpBefore - creature^.experience;
        if lost < 0 then
          lost := 0;
        CharExt.PushDrain(creature, lost, hpPerLevel, lowered);
      end;
      CharHlp.RecalcStats(creature);
      if dual then
        ChgClass.SyncClassPowers(creature);
    end;
  end;
end;

{ A level-draining touch: the attacker's combat target loses levels (DrainLevels); a party member drained knows the
  drainer for it (#842). }
procedure DrainTouch(creature: Types.PCharRecord; levels: Byte);
begin
  if EffHndlr.AttackTarget(creature) = nil then
    Exit;
  Bestiary.Learn(creature, EffHndlr.AttackTarget(creature), C_BEAST.ATK_DRAIN);
  EffHndlr.DrainLevels(EffHndlr.AttackTarget(creature), levels);
end;

{ Melee level drain (eff 85): the target loses one level }
procedure EffDrainOne(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.DrainTouch(creature, 1);
end;

{ Melee level drain (eff 86): the target loses two levels }
procedure EffDrainTwo(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.DrainTouch(creature, 2);
end;

{ Melee mummy rot (eff 87): unless the target has eff 50 or is immune to disease (FxEngine.DiseaseImmune), add eff 50
  and eff 57. Seeds eff 57's 1d6 countdown in the upper nibble }
procedure EffRotTouch(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effect: Types.PEffectRec;
begin
  GameVars.combatTarget := EffHndlr.AttackTarget(creature);
  if GameVars.combatTarget = nil then
    Exit;
  Bestiary.Learn(creature, GameVars.combatTarget, C_BEAST.ATK_ROT);
  if FxEngine.DiseaseImmune(GameVars.combatTarget, C_EFFECT.ROT_NO_HEAL) then
    Exit;
  if not CharHlp.HasEffect(GameVars.combatTarget, C_EFFECT.ROT_NO_HEAL, effect) then begin
    FxEngine.AddEffect(GameVars.combatTarget, C_EFFECT.ROT_NO_HEAL, 14400, 255, True);
    FxEngine.AddEffect(GameVars.combatTarget, C_EFFECT.MUMMY_ROT, 43200,
                       Dice.RollDice(1, 6) * 16 + 15, True);
    CharDisp.PrintNameString(GameVars.combatTarget, 'is Diseased', 10, True);
  end;
end;

{ Displaced (eff 89): the first attack on the creature each combat misses. strength bit 4 = "has displaced an attack
  this combat", cleared by ResetDisplacement as combat starts. SSI's cleared it from here, in the first round whenever
  the attack roll stood at 0, so a first-round attack modified to exactly 0 cleared it instead of missing (#791). }
procedure EffDisplaced(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if Types.PEffectRec(p)^.strength and $10 = 0 then begin
    GameVars.forcedMiss := True;
    Types.PEffectRec(p)^.strength := Types.PEffectRec(p)^.strength or $10;
    { the party member whose attack it was (GameVars.curChar) sees it strike where the creature is not (#1122) }
    Bestiary.Learn(creature, GameVars.curChar, C_BEAST.DISPLACED);
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
  if FxEngine.saveType = C_SAVE.PARALYZE then begin
    FxEngine.saveRoll := FxEngine.saveRoll + AbilAdj.ConSaveBonus(creature^.conCur);
  end;
end;

{ Immunity to electricity + Magic Missile (eff 91) }
procedure EffImmuneMM(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  { the wand's missiles too, not only the spell's (POR-0210, #890) }
  if GameVars.spellId in C_SPELL.MAGIC_MISSILES then begin
    EffHndlr.NullifyAttack(0);
    CharDisp.PrintNameString(creature, 'is unaffected', 10, True);
    Bestiary.Learn(creature, GameVars.curChar, C_BEAST.IMMUNE_MM);
  end else
    EffHndlr.ElementImmunity(creature, C_EFFECT.ELEM_ELEC, C_BEAST.IMMUNE_ELEC);
end;

{ Half damage from fire (eff 93) }
procedure EffHalfFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GameVars.elementMask and C_EFFECT.ELEM_FIRE <> 0 then
    EffHndlr.HalveDamage(creature, C_BEAST.HALF_FIRE);
end;

{ Half damage from blunt/piercing (eff 94) }
procedure EffHalfBash(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GameVars.curChar);
  if w <> nil then
    if CharHlp.BaseItem(w^.itemType)^.wpnClass and C_ITEM.WPN_BASH <> 0 then
      EffHndlr.HalveDamage(creature, C_BEAST.HALF_BLUNT)
    else if CharHlp.BaseItem(w^.itemType)^.wpnClass and C_ITEM.WPN_PIERCE <> 0 then
      EffHndlr.HalveDamage(creature, C_BEAST.HALF_PIERCE);
end;

{ Fight on at 0 HP (eff 95): when it expires, a creature still fighting falls dead }
procedure EffFightOn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  if creature^.enabled <> 0 then
    EffHndlr.InflictStatusMsg(creature, C_STATUS.DEAD_STATUS, 'Falls dead');
end;

{ Immune to weapons neither magical nor silver (C_ITEM.NAME_SILVER), and to attacks without a weapon (eff 96) }
procedure EffNeedSilver(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GameVars.curChar);
  if (w = nil) or ((w^.plus = 0) and (w^.nameIds[3] <> C_ITEM.NAME_SILVER)) then
    EffHndlr.NoHarmWithoutSilver(creature);
end;

{ Con spell/wand save bonus (eff 97), on EffConPsnSave's scale }
procedure EffConSpellSave(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (FxEngine.saveType = C_SAVE.SPELL) or (FxEngine.saveType = C_SAVE.WAND) then begin
    FxEngine.saveRoll := FxEngine.saveRoll + AbilAdj.ConSaveBonus(creature^.conCur);
  end;
end;

{ Regenerate 3 hp per round (eff 98); a monster seen to heal so regenerates in the Bestiary (#842) }
procedure EffRegen3(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if creature^.hpCur < creature^.hpMax then
    Bestiary.Learn(creature, nil, C_BEAST.REGENERATES);
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
      { it gets up and fights on, before the party's eyes (#1122) }
      Bestiary.Learn(creature, nil, C_BEAST.FIGHTS_ON);
      FxEngine.AddEffect(creature, C_EFFECT.FIGHT_ON, Dice.RollDice(1, 4) + 1, 255, True);
      Types.PEffectRec(p)^.onRemove := False;
      FxEngine.RemoveEffect(creature, C_EFFECT.CAN_FIGHT_ON, p);
    end;
end;

{ Troll vulnerability to fire/acid (eff 100): when the damage is neither fire nor acid, add eff 102 to bring the troll
  back in 3d6 minutes }
procedure EffTrollBurn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if (GameVars.elementMask and C_EFFECT.ELEM_FIRE = 0) and (GameVars.elementMask and C_EFFECT.ELEM_ACID = 0) then
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

{ Troll returning from going down (eff 102): revive at full HP, or retry in 1 minute if that fails. One that gets back
  up regenerates, in the Bestiary (#842). }
procedure EffTrollReturn(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if FxEngine.ReviveDeadCreature(creature, creature^.hpMax) then
    Bestiary.Learn(creature, nil, C_BEAST.REGENERATES)
  else if EffHndlr.AddEffectIfNoLock(creature, C_EFFECT.TROLL_RETURN, Types.PEffectRec(p)^.strength, 1) then ;
end;

{ Gaseous form (eff 103): the creature escapes and is put out of play as fled }
procedure EffGaseous(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  Types.PEffectRec(p)^.onRemove := False;
  { before it is out of play: the party sees it go, in the Bestiary (#1122) }
  Bestiary.Learn(creature, nil, C_BEAST.GAS_ESCAPE);
  CbtMap.DisplayMapViewCentered(creature, 3, False);
  FxEngine.PutOutOfPlayWithStatus(creature, C_STATUS.RUNNING, 'Turns gaseous and escapes');
end;

{ Thri-kreen missile evasion (eff 104) }
procedure EffKreenDodge(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.AvoidRanged(creature, 60, C_BEAST.DODGES_MISSILES);
end;

{ pct is the creature's magic resistance against an 11th-level caster. As in the DMG, it rises 5% for each caster level
  below 11 and falls 5% for each level above: chance := pct + (11 - lvl) * 5, kept within 0..100, and a 1d100 roll <=
  chance nullifies. Only an effect under the immunity check or magic damage is resisted, and not a monster's poisonous
  or paralyzing touch, which is no magic (TouchImmune; #800). An item counts as a 6th-level caster here, as a scroll
  does, not the 12 GetCasterLevel gives the class-2 item spells (the wands, the necklace and the javelin). Against an
  effect that is no spell (GameVars.spellId NONE: a gaze, a monster's fear) there is no caster level, and pct
  stands as listed, as against an 11th-level caster; SSI's read the level of spell 0, from outside the spell table
  (#786). Shipped v1.3 had the sign the other way (pct - (11 - lvl) * 5, with eff 106 passing 15), so resistance grew
  with the caster level; Tyranthraxus (eff 106) still resists every caster the game produces, as he did. Creature,
  resisting, resists magic in the Bestiary when it was a party member's doing (curChar, #842). }
procedure MagicResistance(creature: Types.PCharRecord; pct: Byte);
const
  { the caster level pct is listed against }
  BASE_LEVEL = 11;
var
  lvl: Byte;
  chance: Integer;
begin
  if GameVars.spellId = C_SPELL.NONE then
    lvl := BASE_LEVEL
  else begin
    lvl := CharHlp.GetCasterLevel(GameVars.spellId);
    if GameVars.usingItem and (lvl > C_SPELL.ITEM_CASTER_LEVEL) then
      lvl := C_SPELL.ITEM_CASTER_LEVEL;
  end;
  chance := Integer(pct) + (BASE_LEVEL - Integer(lvl)) * 5;
  if chance < 0 then
    chance := 0
  else if chance > 100 then
    chance := 100;
  if (GameVars.pendingEffectId = 0) and (GameVars.elementMask and C_EFFECT.ELEM_MAGIC = 0) then
    Exit;
  if mundaneCheck then
    Exit;
  if Dice.RollDice(1, 100) <= chance then begin
    EffHndlr.NullifyAttack(0);
    Bestiary.Learn(creature, GameVars.curChar, C_BEAST.MAGIC_RES);
  end;
end;

{ Magic resistance 50% (eff 105) }
procedure EffMagicRes50(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.MagicResistance(creature, 50);
end;

{ Magic resistance 85% (eff 106) }
procedure EffMagicRes85(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.MagicResistance(creature, 85);
end;

{ Elf 90% resistance to sleep/charm (eff 107) }
procedure EffElfResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.SleepCharmResist(90);
end;

{ Immunity to sleep/charm (eff 108) }
procedure EffImmuneSleepCharm(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effId: Byte;
begin
  effId := GameVars.pendingEffectId;
  EffHndlr.NullifyAttack(C_EFFECT.CHARM);
  EffHndlr.NullifyAttack(C_EFFECT.SLEEP);
  EffHndlr.NoteImmunity(creature, effId);
end;

{ Immunity to paralysis (eff 109) }
procedure EffImmuneParalysis(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effId: Byte;
begin
  effId := GameVars.pendingEffectId;
  EffHndlr.NullifyAttack(C_EFFECT.PARALYZED);
  EffHndlr.NoteImmunity(creature, effId);
end;

{ Immunity to cold (eff 110) }
procedure EffNoCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.ElementImmunity(creature, C_EFFECT.ELEM_COLD, C_BEAST.IMMUNE_COLD);
end;

{ Immunity to paralysis + poison (eff 111). Saves of type 0 (paralyzation/poison, e.g. Stinking Cloud) succeed
  automatically }
procedure EffImmuneParalysisPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effId: Byte;
begin
  effId := GameVars.pendingEffectId;
  EffHndlr.NullifyAttack(C_EFFECT.POISONED);
  EffHndlr.NullifyAttack(C_EFFECT.PARALYZED);
  EffHndlr.NoteImmunity(creature, effId);
  if FxEngine.saveType = C_SAVE.PARALYZE then
    FxEngine.saveRoll := 100;
end;

{ Immunity to fire (eff 112) }
procedure EffImmuneFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.ElementImmunity(creature, C_EFFECT.ELEM_FIRE, C_BEAST.IMMUNE_FIRE);
end;

{ Efreeti fire resistance (eff 113): -1 per die, minimum = dice count (damage already below it is left alone) }
procedure EffEfreetiFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GameVars.elementMask and C_EFFECT.ELEM_FIRE <> 0 then begin
    EffHndlr.NoteFireResisted(creature);
    Dice.ReduceDamagePerDie(1);
  end;
end;

{ Half damage from electricity (eff 114) }
procedure EffHalfElectricity(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GameVars.elementMask and C_EFFECT.ELEM_ELEC <> 0 then
    EffHndlr.HalveDamage(creature, C_BEAST.HALF_ELEC);
end;

{ Half damage from piercing/slashing (eff 115) }
procedure EffHalfPierce(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GameVars.curChar);
  if w <> nil then
    if CharHlp.BaseItem(w^.itemType)^.wpnClass = C_ITEM.WPN_SLASH then
      EffHndlr.HalveDamage(creature, C_BEAST.HALF_SLASH)
    else if CharHlp.BaseItem(w^.itemType)^.wpnClass and C_ITEM.WPN_PIERCE <> 0 then
      EffHndlr.HalveDamage(creature, C_BEAST.HALF_PIERCE);
end;

{ Half damage from magical weapons (eff 116) }
procedure EffHalfMagical(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GameVars.curChar);
  if w <> nil then
    if w^.plus > 0 then
      EffHndlr.HalveDamage(creature, C_BEAST.HALF_MAGICAL);
end;

{ Vulnerability to holy water (eff 117): a holy water vial does 1d6+1 }
procedure EffHolyWater(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := GameVars.curChar^.equipped[C_EQUIP.WEAPON];
  if item <> nil then
    if item^.itemType = C_ITEM.HOLY_WATER_VIAL then
      GameVars.pendingDamage := Dice.RollDamageDice(1, 6) + 1;
end;

{ Half damage from cold (eff 118) }
procedure EffHalfCold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GameVars.elementMask and C_EFFECT.ELEM_COLD <> 0 then
    EffHndlr.HalveDamage(creature, C_BEAST.HALF_COLD);
end;

{ Immunity to non-magical weapons and unarmed attacks (eff 119): only vs PC races or attackers with levelHighest < 4 }
procedure EffNeedMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GameVars.curChar);
  if (w = nil) or (w^.plus = 0) then
    if (GameVars.curChar^.race > C_RACE.MONSTER) or (GameVars.curChar^.levelHighest < 4) then begin
      { a blow that would have hurt it shows the party it needs a magical weapon (#842) }
      if GameVars.pendingDamage > 0 then
        Bestiary.Learn(creature, GameVars.curChar, C_BEAST.NEEDS_MAGIC);
      GameVars.pendingDamage := 0;
    end;
end;

{ Boulder evasion (eff 120): 50% chance to avoid a thrown C_ITEM.BOULDER or C_ITEM.LARGE_BOULDER }
procedure EffDodgeBoulders(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := GameVars.curChar^.equipped[C_EQUIP.WEAPON];
  if item <> nil then
    if (item^.itemType = C_ITEM.BOULDER) or (item^.itemType = C_ITEM.LARGE_BOULDER) then
      EffHndlr.AvoidRanged(creature, 50, C_BEAST.DODGES_BOULDERS);
end;

{ Anhkheg acid squirt (eff 121): 25% chance, range < 4, 8d4 acid, save vs. breath for half; the effect removes itself
  (and eff 80) after firing }
procedure EffAnhkhegAcid(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  GameVars.combatTarget := EffHndlr.AttackTarget(creature);
  { other is nil before the anhkheg's first target, and may be a creature since taken out of play }
  if (GameVars.combatTarget = nil) or (GameVars.combatTarget^.enabled = 0) then Exit;
  if Dice.RollDice(1, 100) > 25 then Exit;
  if CbtMap.CalcDistance(creature, GameVars.combatTarget) >= 4 then Exit;
  if CharHlp.EndActions(creature) then ;
  CharDisp.PrintNameString(creature, 'Spits Acid', 10, True);
  Bestiary.Learn(creature, GameVars.combatTarget, C_BEAST.ATK_ACID);
  CharDisp.AnimateBetween(creature, GameVars.combatTarget, C_SPRITE.BURST, 1, 30);
  { acid, set before the save, whose effects read it too: SSI left the type of the last damage dealt (#721) }
  GameVars.elementMask := C_EFFECT.ELEM_ACID;
  FxEngine.InflictNonWeaponDamage(GameVars.combatTarget, Dice.RollDamageDice(8, 4), 2,
                                  FxEngine.RollSavingThrow(GameVars.combatTarget, C_SAVE.BREATH, 0));
  FxEngine.RemoveEffect(creature, C_EFFECT.ANHKHEG_ACID, p);
  FxEngine.RemoveEffect(creature, C_EFFECT.ACID_SQUIRT, nil);
end;

{ Mummy vulnerability to fire (eff 122): a flask of oil does 3d8; magic or fire damage +1 per die }
procedure EffMummyFire(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
begin
  item := GameVars.curChar^.equipped[C_EQUIP.WEAPON];
  if item <> nil then
    if item^.itemType = C_ITEM.FLASK_OF_OIL then
      GameVars.pendingDamage := Dice.RollDamageDice(3, 8);
  if GameVars.elementMask and (C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC) <> 0 then
    Inc(GameVars.pendingDamage, GameVars.gDamageDice);
end;

{ Immune unless silver (half) or magical (full); no damage without a weapon (eff 123) }
procedure EffSilverMagic(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  w: Types.PItemRec;
begin
  w := EffHndlr.FindDamagingWeapon(GameVars.curChar);
  if w <> nil then begin
    if (w^.plus = 0) and (w^.nameIds[3] = C_ITEM.NAME_SILVER) then
      EffHndlr.HalveDamage(creature, C_BEAST.HALF_SILVER)
    else if w^.plus = 0 then
      EffHndlr.NoHarmWithoutSilver(creature);
  end else
    EffHndlr.NoHarmWithoutSilver(creature);
end;

{ Half-elf 30% resistance (eff 124) }
procedure EffHalfElfResistance(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  EffHndlr.SleepCharmResist(30);
end;

{ Immunity to sleep/charm/para/poison (eff 125). Saves of type 0 succeed automatically }
procedure EffNoCharmPoison(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  effId: Byte;
begin
  effId := GameVars.pendingEffectId;
  EffHndlr.NullifyAttack(C_EFFECT.CHARM);
  EffHndlr.NullifyAttack(C_EFFECT.SLEEP);
  EffHndlr.NullifyAttack(C_EFFECT.PARALYZED);
  EffHndlr.NullifyAttack(C_EFFECT.POISONED);
  EffHndlr.NoteImmunity(creature, effId);
  if FxEngine.saveType = C_SAVE.PARALYZE then
    FxEngine.saveRoll := 100;
end;

{ Suppressible gaze (eff 126): blocked by an equipped mirror (EffHndlr.IsMirror) or Wooden Holy Symbol of Tyr
  (C_ITEM.NAME_HOLY_SYMBOL with NAME_WOODEN) on the target }
procedure EffGazeBlock(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  j: Byte;
begin
  GameVars.combatTarget := EffHndlr.AttackTarget(creature);
  if GameVars.combatTarget = nil then
    Exit;
  item := GameVars.combatTarget^.itemsAddr;
  while (item <> nil) and (CbtActs.suppressTargeting = 0) do begin
    if item^.equipped <> 0 then begin
      if EffHndlr.IsMirror(item) then
        CbtActs.suppressTargeting := 1;
      { 3 = High(TItemRec.nameIds) }
      for j := 1 to 3 do
        if (item^.nameIds[j] = C_ITEM.NAME_HOLY_SYMBOL) and (item^.nameIds[3] = C_ITEM.NAME_WOODEN) then
          CbtActs.suppressTargeting := 1;
    end;
    item := item^.next;
  end;
end;

{ Ready item (eff 128, 129, 130, 133, 134, 136, 138, 139): p is the ITEM. Readying adds its effect byte as a permanent
  effect (strength 12) and, for an effect in ACTS_ON_READY, calls that handler with the new node. Unreadying removes the
  effect. SSI called every effect's handler, with nil, and the Cloak of Displacement's (eff 89) wrote its strength
  through it, into the interrupt vectors (#737). }
procedure EffReadyItem(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
const
  { The effects a ready item adds whose handler acts as the item is readied, and is called then: the Ring of
    Invisibility's and the Cloak of Elvenkind's, which make the wearer invisible at once, as at the start of a fight.
    The others act at their moment, through their conditions (an attack, damage, a save). Called with no attack under
    way, the Flame Tongue's and the Two-Handed Sword +3 vs. Undead's read a target that was not there, and natively
    crashed (POR-0231, #1094), and the Cloak of Displacement's spent its first miss on the readying (#784). A later
    game's item that acts as it is readied takes an entry here. }
  ACTS_ON_READY = [C_EFFECT.RING_INVIS, C_EFFECT.CAMOUFLAGE];
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
    if item^.effect in ACTS_ON_READY then
      FxEngine.CallEffectHandler(item^.effect, creature, effect, False);
  end;
end;

{ Gauntlets of Ogre Power (eff 131). Ready: Str 18/00 via FxEngine.AdjustForNewStrength plus a permanent eff 38 node
  holding the Strength to restore; "is stronger" shows only for the character readying them (GameVars.curChar), not for
  a monster loaded wearing them (EclMenu.LoadCreatureData). Unready: while the creature is still at 18/00 (with a
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
    if FxEngine.AdjustForNewStrength(creature, 18, 100, enc) and (creature = GameVars.curChar) then
      if GameVars.ifcState = C_IFC.IN_COMBAT then begin
        GameVars.ifcState := C_IFC.CAMPING;
        CharDisp.PrintNameString(creature, 'is stronger', 10, True);
        GameVars.ifcState := C_IFC.IN_COMBAT;
      end else
        CharDisp.PrintNameString(creature, 'is stronger', 10, True);
    GameVars.invRedraw := 1;
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
    GameVars.elementMask := C_EFFECT.ELEM_MAGIC;
    if GameVars.ifcState = C_IFC.IN_COMBAT then
      CharDisp.DisplayCombatInterface;
    FxEngine.InflictItemShock(creature, item, dmg);
    GameVars.invRedraw := 1;
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
    FxEngine.RemoveEffect(creature, C_EFFECT.SPIRITUAL_HAMMER, nil);
end;

{ the do-nothing handler (eff 5, 13, 16, 19, 24, 27, 54, 55, 60, 63, 92, 127) }
procedure EffNone(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

end.
