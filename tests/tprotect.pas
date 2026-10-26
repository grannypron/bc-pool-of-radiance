{ Tests for Protection from Evil and from Good (EffHndlr.EffProtEvil, EffProtGood, triggered through FxEngine): a
  paladin's aura (eff 45) reaches only his own side (#782), and a protection applies once however many sources there
  are, a spell (eff 8) and an aura together giving +2 to saves, not +4 (#783), and its -2 to be hit is taken off the
  rolled d20, not before it (#789). Prayer applies once from each side in reach (#801), and its side is the caster's
  team, hostile and 1, whatever larger hostile byte a damaged save holds (#827). A protection aura or Prayer lapses
  while its carrier is out of action (POR-0220, #941). }
{$I COMPILER.INC}
program TProtect;

uses Types, C_EFFECT, C_COND, C_ALIGN, GameVars, FxEngine, EffHndlr, TestKit;

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
{ The attacker's C_COND.ATTACK_ROLL_ATT effect: note the d20. }
procedure NoteNatural(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  natural := GameVars.gAttackRoll;
end;

{ The defender's C_COND.ATTACK_ROLL_DEF effect, run after its protection: note the roll as it then stands. }
procedure NoteSeen(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  seen := GameVars.gAttackRoll;
end;
{$F-}

function NewCreature(hostile: ShortInt; alignment: Byte): Types.PCharRecord;
var
  c: Types.PCharRecord;
begin
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.hostile := hostile;
  c^.enabled := 1;
  c^.alignment := alignment;
  NewCreature := c;
end;

{ Empty a creature's effect list. }
procedure ClearEffects(c: Types.PCharRecord);
begin
  while c^.effectsAddr <> nil do
    FxEngine.RemoveEffect(c, Types.PEffectRec(c^.effectsAddr)^.id, nil);
end;

{ The defender's saving-throw bonus against the attacker (GameVars.curChar), from its C_COND.SAVING_THROW effects }
function SaveBonus: Integer;
begin
  GameVars.curChar := att;
  FxEngine.saveRoll := 10;
  FxEngine.TriggerEffectsWithCondition(C_COND.SAVING_THROW, def);
  SaveBonus := Integer(FxEngine.saveRoll) - 10;
end;

{ What the defender's protection takes off the attacker's (GameVars.curChar's) d20 }
function HitPenalty: Integer;
begin
  GameVars.curChar := att;
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
  GameVars.curChar := cur;
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
  GetMem(GameVars.zone1, SizeOf(GameVars.zone1^));
  FillChar(GameVars.zone1^, SizeOf(GameVars.zone1^), 0);
  GameVars.effectFns[C_EFFECT.BLESS] := NoteNatural;
  GameVars.effectFns[C_EFFECT.DISPLACED] := NoteSeen;
  GameVars.effectFns[C_EFFECT.PROTECTION_FROM_EVIL] := EffHndlr.EffProtEvil;
  GameVars.effectFns[C_EFFECT.PROT_GOOD] := EffHndlr.EffProtGood;
  GameVars.effectFns[C_EFFECT.PROT_EVIL_10FT] := EffHndlr.EffProtEvil;
  GameVars.effectFns[C_EFFECT.PROT_GOOD_10FT] := EffHndlr.EffProtGood;
  { out of combat any carrier is in range }
  GameVars.ifcState := 0;
  att := NewCreature(1, C_ALIGN.CHAOTIC_EVIL);
  def := NewCreature(0, C_ALIGN.LAWFUL_GOOD);
  ally := NewCreature(0, C_ALIGN.LAWFUL_GOOD);
  foe := NewCreature(1, C_ALIGN.LAWFUL_GOOD);
  GameVars.creatureList := def;
  def^.nextCharAddr := ally;
  ally^.nextCharAddr := foe;
  foe^.nextCharAddr := att;

  FxEngine.AddEffect(att, C_EFFECT.BLESS, 0, 0, False);
  FxEngine.AddEffect(def, C_EFFECT.DISPLACED, 0, 0, False);
  TestKit.CheckEqualsL(0, SaveBonus, 'no protection, no bonus');
  FxEngine.AddEffect(def, C_EFFECT.PROTECTION_FROM_EVIL, 10, 1, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'Protection from Evil: +2 to saves against an evil attacker');
  att^.alignment := C_ALIGN.TRUE_NEUTRAL;
  TestKit.CheckEqualsL(0, SaveBonus, 'and none against a neutral one');
  att^.alignment := C_ALIGN.CHAOTIC_EVIL;
  FxEngine.AddEffect(def, C_EFFECT.PROTECTION_FROM_EVIL, 10, 1, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'two spells give +2');
  TestKit.CheckEqualsL(2, HitPenalty, 'and -2 to be hit, off the rolled d20');
  ClearEffects(def);
  FxEngine.AddEffect(def, C_EFFECT.DISPLACED, 0, 0, False);

  { a script's attack has no attacker: curChar is a party member, evil or not }
  FxEngine.AddEffect(def, C_EFFECT.PROTECTION_FROM_EVIL, 10, 1, False);
  ally^.alignment := C_ALIGN.CHAOTIC_EVIL;
  TestKit.CheckEqualsL(100, ScriptAttackHighest(ally), 'no penalty to a script''s attack');
  TestKit.CheckEqualsL(98, ScriptAttackHighest(att), 'which an evil foe would have');
  ally^.alignment := C_ALIGN.LAWFUL_GOOD;
  ClearEffects(def);
  FxEngine.AddEffect(def, C_EFFECT.DISPLACED, 0, 0, False);

  { the aura (#782) }
  FxEngine.AddEffect(ally, C_EFFECT.PROT_EVIL_10FT, 0, 255, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'an ally''s aura protects');
  ClearEffects(ally);
  FxEngine.AddEffect(foe, C_EFFECT.PROT_EVIL_10FT, 0, 255, False);
  TestKit.CheckEqualsL(0, SaveBonus, 'an enemy''s aura does not');
  ClearEffects(foe);

  { one protection from any number of sources (#783) }
  FxEngine.AddEffect(def, C_EFFECT.PROT_EVIL_10FT, 0, 255, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'a paladin''s own aura gives +2');
  FxEngine.AddEffect(def, C_EFFECT.PROTECTION_FROM_EVIL, 10, 1, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'and with the spell as well, still +2');
  TestKit.CheckEqualsL(2, HitPenalty, 'and -2 to be hit');
  ClearEffects(def);
  FxEngine.AddEffect(def, C_EFFECT.DISPLACED, 0, 0, False);
  FxEngine.AddEffect(def, C_EFFECT.PROTECTION_FROM_EVIL, 10, 1, False);
  FxEngine.AddEffect(ally, C_EFFECT.PROT_EVIL_10FT, 0, 255, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'the spell and an ally''s aura: +2');
  TestKit.CheckEqualsL(2, HitPenalty, 'and -2 to be hit');
  ClearEffects(def);
  FxEngine.AddEffect(def, C_EFFECT.DISPLACED, 0, 0, False);
  ClearEffects(ally);

  { Protection from Good, the same way }
  att^.alignment := C_ALIGN.LAWFUL_GOOD;
  FxEngine.AddEffect(def, C_EFFECT.PROT_GOOD, 10, 1, False);
  FxEngine.AddEffect(ally, C_EFFECT.PROT_GOOD_10FT, 0, 255, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'Protection from Good: +2 against a good attacker, once');
  FxEngine.AddEffect(def, C_EFFECT.PROTECTION_FROM_EVIL, 10, 1, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'and Protection from Evil adds nothing against him');
  TestKit.CheckEqualsL(2, HitPenalty, 'nor to the -2 to be hit');
  ClearEffects(def);
  ClearEffects(ally);

  { Prayer (#801): one from each side in reach applies, two from one side once }
  GameVars.effectFns[C_EFFECT.PRAYER] := EffHndlr.EffPrayer;
  FxEngine.AddEffect(ally, C_EFFECT.PRAYER, 10, 0 * C_EFFECT.PRAYER_SIDE + 5, False);
  TestKit.CheckEqualsL(1, SaveBonus, 'an ally''s Prayer: +1');
  FxEngine.AddEffect(def, C_EFFECT.PRAYER, 10, 0 * C_EFFECT.PRAYER_SIDE + 5, False);
  TestKit.CheckEqualsL(1, SaveBonus, 'and his own as well, still +1');
  ClearEffects(def);
  ClearEffects(ally);
  FxEngine.AddEffect(foe, C_EFFECT.PRAYER, 10, 1 * C_EFFECT.PRAYER_SIDE + 5, False);
  TestKit.CheckEqualsL(-1, SaveBonus, 'an enemy''s Prayer: -1');
  FxEngine.AddEffect(ally, C_EFFECT.PRAYER, 10, 0 * C_EFFECT.PRAYER_SIDE + 5, False);
  FxEngine.AddEffect(att, C_EFFECT.PRAYER, 10, 1 * C_EFFECT.PRAYER_SIDE + 5, False);
  TestKit.CheckEqualsL(0, SaveBonus, 'one from each side: both, +1 and -1');
  ClearEffects(ally);
  TestKit.CheckEqualsL(-1, SaveBonus, 'two enemy Prayers apply once');
  ClearEffects(foe);
  ClearEffects(att);

  { Prayer's side is the caster's team, hostile and 1 (#827): a hostile of 2 or 3 set bits above the side bit }
  foe^.hostile := 2;
  TestKit.CheckEqualsL(5, FxEngine.PrayerStrength(foe, 5), 'a caster with hostile 2 prays for side 0');
  foe^.hostile := 3;
  TestKit.CheckEqualsL(C_EFFECT.PRAYER_SIDE + 5, FxEngine.PrayerStrength(foe, 5),
                       'a caster with hostile 3 prays for side 1');
  TestKit.CheckEqualsL(C_EFFECT.PRAYER_SIDE + 15, FxEngine.PrayerStrength(foe, 20),
                       'and a level above 15 is kept out of the side');
  FxEngine.AddEffect(foe, C_EFFECT.PRAYER, 10, FxEngine.PrayerStrength(foe, 5), False);
  TestKit.CheckEqualsL(-1, SaveBonus, 'the hostile-3 caster''s Prayer is an enemy''s: -1');
  ClearEffects(foe);
  foe^.hostile := 2;
  FxEngine.AddEffect(foe, C_EFFECT.PRAYER, 10, FxEngine.PrayerStrength(foe, 5), False);
  TestKit.CheckEqualsL(1, SaveBonus, 'the hostile-2 caster''s Prayer is an ally''s: +1');
  ClearEffects(foe);
  foe^.hostile := 1;
  def^.hostile := 2;
  FxEngine.AddEffect(ally, C_EFFECT.PRAYER, 10, FxEngine.PrayerStrength(ally, 5), False);
  TestKit.CheckEqualsL(1, SaveBonus, 'a defender with hostile 2 is on side 0: +1');
  ClearEffects(ally);
  def^.hostile := 0;

  { Protection's sides are teams too (2026-10-25 review): an attacker with hostile 2 is on side 0 }
  att^.alignment := C_ALIGN.CHAOTIC_EVIL;
  att^.hostile := 2;
  FxEngine.AddEffect(def, C_EFFECT.PROTECTION_FROM_EVIL, 10, 1, False);
  TestKit.CheckEqualsL(0, SaveBonus, 'no protection against an evil attacker with hostile 2, on the defender''s side');
  att^.hostile := 3;
  TestKit.CheckEqualsL(2, SaveBonus, 'but against one with hostile 3, on the other');
  ClearEffects(def);
  att^.hostile := 1;
  ally^.hostile := 2;
  FxEngine.AddEffect(ally, C_EFFECT.PROT_EVIL_10FT, 0, 255, False);
  TestKit.CheckEqualsL(2, SaveBonus, 'an ally with hostile 2 lends its aura');
  ClearEffects(ally);
  ally^.hostile := 0;

  { an aura or a Prayer lapses while its carrier is out of action (POR-0220, #941) }
  FxEngine.AddEffect(ally, C_EFFECT.PROT_EVIL_10FT, 0, 255, False);
  ally^.enabled := 0;
  TestKit.CheckEqualsL(0, SaveBonus, 'a downed ally''s aura protects no one');
  ally^.enabled := 1;
  TestKit.CheckEqualsL(2, SaveBonus, 'and does again once it is back up');
  ClearEffects(ally);
  FxEngine.AddEffect(foe, C_EFFECT.PRAYER, 10, FxEngine.PrayerStrength(foe, 5), False);
  foe^.enabled := 0;
  TestKit.CheckEqualsL(0, SaveBonus, 'nor does a downed enemy''s Prayer');
  foe^.enabled := 1;
  TestKit.CheckEqualsL(-1, SaveBonus, 'which counts again once it is back up');
  ClearEffects(foe);
  TestKit.Done;
end.
