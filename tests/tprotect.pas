{ Tests for Protection from Evil and from Good (EffHndlr.EffProtEvil, EffProtGood, triggered through FxEngine): a
  paladin's aura (eff 45) reaches only his own side (#782), and a protection applies once however many sources there
  are, a spell (eff 8) and an aura together giving +2 to saves, not +4 (#783), and its -2 to be hit is taken off the
  rolled d20, not before it (#789). }
{$I COMPILER.INC}
program TProtect;

uses Types, C_Effect, C_Cond, C_Align, GDVars, FxEngine, EffHndlr, TestKit;

const
  TRIES = 200;

var
  att: Types.PCharRecord;
  def: Types.PCharRecord;
  ally: Types.PCharRecord;
  foe: Types.PCharRecord;
  natural: Integer;
  seen: Integer;
  i: Integer;
  hit: Boolean;

{$F+}
{ The attacker's C_Cond.ATTACK_ROLL_ATT effect: note the d20. }
procedure NoteNatural(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  natural := GDVars.gAttackRoll;
end;

{ The defender's C_Cond.ATTACK_ROLL_DEF effect, run after its protection: note the roll as it then stands. }
procedure NoteSeen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  seen := GDVars.gAttackRoll;
end;
{$F-}

function NewCreature(hostile: ShortInt; alignment: Byte): Types.PCharRecord;
var
  c: Types.PCharRecord;
begin
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.hostile := hostile;
  c^.alignment := alignment;
  NewCreature := c;
end;

{ Empty a creature's effect list. }
procedure ClearEffects(c: Types.PCharRecord);
begin
  while c^.effectsAddr <> nil do
    FxEngine.RemoveEffect(c, Types.PEffectRec(c^.effectsAddr)^.id, nil);
end;

{ The defender's saving-throw bonus against the attacker (GDVars.curChar), from its C_Cond.SAVING_THROW effects }
function SaveBonus: Integer;
begin
  GDVars.curChar := att;
  GDVars.gSaveRoll := 10;
  FxEngine.TriggerEffectsWithCondition(C_Cond.SAVING_THROW, def);
  SaveBonus := Integer(GDVars.gSaveRoll) - 10;
end;

{ What the defender's protection takes off the attacker's (GDVars.curChar's) d20 }
function HitPenalty: Integer;
begin
  GDVars.curChar := att;
  repeat
    natural := 0;
    hit := FxEngine.AttackRoll(att, def, 50);
  until natural > 1;
  HitPenalty := natural - seen;
end;

{ The highest roll a script's attack (no attacker) shows, over TRIES attacks, while curChar is cur }
function ScriptAttackHighest(cur: Types.PCharRecord): Integer;
var
  highest: Integer;
begin
  GDVars.curChar := cur;
  highest := 0;
  for i := 1 to TRIES do begin
    seen := 0;
    hit := FxEngine.AttackRollNoAttacker(def, 40);
    if seen > highest then
      highest := seen;
  end;
  ScriptAttackHighest := highest;
end;

begin
  TestKit.Start('TPROTECT');
  GetMem(GDVars.zone1, SizeOf(GDVars.zone1^));
  FillChar(GDVars.zone1^, SizeOf(GDVars.zone1^), 0);
  GDVars.effectFns[C_Effect.BLESS] := NoteNatural;
  GDVars.effectFns[C_Effect.DISPLACED] := NoteSeen;
  GDVars.effectFns[C_Effect.PROT_EVIL] := EffHndlr.EffProtEvil;
  GDVars.effectFns[C_Effect.PROT_GOOD] := EffHndlr.EffProtGood;
  GDVars.effectFns[C_Effect.PROT_EVIL_10FT] := EffHndlr.EffProtEvil;
  GDVars.effectFns[C_Effect.PROT_GOOD_10FT] := EffHndlr.EffProtGood;
  { out of combat any carrier is in range }
  GDVars.ifcState := 0;
  att := NewCreature(1, C_Align.CHAOTIC_EVIL);
  def := NewCreature(0, C_Align.LAWFUL_GOOD);
  ally := NewCreature(0, C_Align.LAWFUL_GOOD);
  foe := NewCreature(1, C_Align.LAWFUL_GOOD);
  GDVars.creatureList := def;
  def^.nextCharAddr := ally;
  ally^.nextCharAddr := foe;
  foe^.nextCharAddr := att;

  FxEngine.AddEffect(att, C_Effect.BLESS, 0, 0, False);
  FxEngine.AddEffect(def, C_Effect.DISPLACED, 0, 0, False);
  TestKit.CheckEqualsL(0, SaveBonus, 'no protection, no bonus');
  FxEngine.AddEffect(def, C_Effect.PROT_EVIL, 10, 1, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'Protection from Evil: +2 to saves against an evil attacker');
  att^.alignment := C_Align.TRUE_NEUTRAL;
  TestKit.CheckEqualsL(0, SaveBonus, 'and none against a neutral one');
  att^.alignment := C_Align.CHAOTIC_EVIL;
  FxEngine.AddEffect(def, C_Effect.PROT_EVIL, 10, 1, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'two spells give +2');
  TestKit.CheckEqualsL(2, HitPenalty, 'and -2 to be hit, off the rolled d20');
  ClearEffects(def);
  FxEngine.AddEffect(def, C_Effect.DISPLACED, 0, 0, False);

  { a script's attack has no attacker: curChar is a party member, evil or not }
  FxEngine.AddEffect(def, C_Effect.PROT_EVIL, 10, 1, False);
  ally^.alignment := C_Align.CHAOTIC_EVIL;
  TestKit.CheckEqualsL(100, ScriptAttackHighest(ally), 'no penalty to a script''s attack');
  TestKit.CheckEqualsL(98, ScriptAttackHighest(att), 'which an evil foe would have');
  ally^.alignment := C_Align.LAWFUL_GOOD;
  ClearEffects(def);
  FxEngine.AddEffect(def, C_Effect.DISPLACED, 0, 0, False);

  { the aura (#782) }
  FxEngine.AddEffect(ally, C_Effect.PROT_EVIL_10FT, 0, 255, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'an ally''s aura protects');
  ClearEffects(ally);
  FxEngine.AddEffect(foe, C_Effect.PROT_EVIL_10FT, 0, 255, False);
  TestKit.CheckEqualsL(0, SaveBonus, 'an enemy''s aura does not');
  ClearEffects(foe);

  { one protection from any number of sources (#783) }
  FxEngine.AddEffect(def, C_Effect.PROT_EVIL_10FT, 0, 255, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'a paladin''s own aura gives +2');
  FxEngine.AddEffect(def, C_Effect.PROT_EVIL, 10, 1, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'and with the spell as well, still +2');
  TestKit.CheckEqualsL(2, HitPenalty, 'and -2 to be hit');
  ClearEffects(def);
  FxEngine.AddEffect(def, C_Effect.DISPLACED, 0, 0, False);
  FxEngine.AddEffect(def, C_Effect.PROT_EVIL, 10, 1, False);
  FxEngine.AddEffect(ally, C_Effect.PROT_EVIL_10FT, 0, 255, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'the spell and an ally''s aura: +2');
  TestKit.CheckEqualsL(2, HitPenalty, 'and -2 to be hit');
  ClearEffects(def);
  FxEngine.AddEffect(def, C_Effect.DISPLACED, 0, 0, False);
  ClearEffects(ally);

  { Protection from Good, the same way }
  att^.alignment := C_Align.LAWFUL_GOOD;
  FxEngine.AddEffect(def, C_Effect.PROT_GOOD, 10, 1, False);
  FxEngine.AddEffect(ally, C_Effect.PROT_GOOD_10FT, 0, 255, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'Protection from Good: +2 against a good attacker, once');
  FxEngine.AddEffect(def, C_Effect.PROT_EVIL, 10, 1, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'and Protection from Evil adds nothing against him');
  TestKit.CheckEqualsL(2, HitPenalty, 'nor to the -2 to be hit');
  ClearEffects(def);
  ClearEffects(ally);
  TestKit.Done;
end.
