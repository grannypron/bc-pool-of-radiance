{ Tests for EffHndlr.EffReadyItem (POR-0231, #1094): readying an item adds its effect, but calls the effect's handler
  only for the effects that act as the item is readied (the Ring of Invisibility's and the Cloak of Elvenkind's, which
  make the wearer invisible at once). The Flame Tongue's and the Two-Handed Sword +3 vs. Undead's act on an attack:
  readied with no target, in combat or out, they neither crash nor touch the attack's roll, damage or element. And the
  attack-time handlers themselves do nothing with no target (EffHndlr.AttackTarget). }
{$I COMPILER.INC}
program TReadyFx;

uses Types, C_EFFECT, C_IFC, GameVars, CharHlp, FxEngine, EffHndlr, TestKit;

var
  c: Types.PCharRecord;
  cbt: Types.TCombatRec;
  item: Types.TItemRec;
  effect: Types.PEffectRec;

{ True when readying an item with effect eff leaves eff on c and the attack's globals as they were. }
function ReadiesQuietly(eff: Byte): Boolean;
begin
  FillChar(item, SizeOf(item), 0);
  item.effect := eff;
  GameVars.gAttackRoll := 7;
  GameVars.pendingDamage := 5;
  GameVars.elementMask := 0;
  EffHndlr.EffReadyItem(c, @item, False);
  ReadiesQuietly := CharHlp.HasEffect(c, eff, effect) and (GameVars.gAttackRoll = 7) and
                    (GameVars.pendingDamage = 5) and (GameVars.elementMask = 0);
  EffHndlr.EffReadyItem(c, @item, True);
end;

begin
  TestKit.Start('TREADYFX');
  GameVars.effectFns[C_EFFECT.FLAME_TONGUE] := EffHndlr.EffFlameTongue;
  GameVars.effectFns[C_EFFECT.UNDEAD_SLAYER] := EffHndlr.EffUndeadSlayer;
  GameVars.effectFns[C_EFFECT.RING_FIRE_RES] := EffHndlr.EffRingFireRes;
  GameVars.effectFns[C_EFFECT.RING_INVIS] := EffHndlr.EffRingInvis;
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  FillChar(cbt, SizeOf(cbt), 0);

  { in combat, before the creature's first target (the AI readies at the start of its turn) }
  GameVars.ifcState := C_IFC.IN_COMBAT;
  c^.combatAddr := @cbt;
  cbt.other := nil;
  TestKit.Check(ReadiesQuietly(C_EFFECT.FLAME_TONGUE), 'a Flame Tongue readied with no target');
  TestKit.Check(ReadiesQuietly(C_EFFECT.UNDEAD_SLAYER), 'a sword +3 vs. undead readied with no target');
  TestKit.Check(ReadiesQuietly(C_EFFECT.RING_FIRE_RES), 'a Ring of Fire Resistance readied');

  { out of combat, with no combat record }
  GameVars.ifcState := C_IFC.INDOORS;
  c^.combatAddr := nil;
  TestKit.Check(ReadiesQuietly(C_EFFECT.FLAME_TONGUE), 'a Flame Tongue readied out of combat');

  { the ones that act as they are readied }
  GameVars.ifcState := C_IFC.IN_COMBAT;
  c^.combatAddr := @cbt;
  FillChar(item, SizeOf(item), 0);
  item.effect := C_EFFECT.RING_INVIS;
  EffHndlr.EffReadyItem(c, @item, False);
  TestKit.Check(CharHlp.HasEffect(c, C_EFFECT.INVISIBLE, effect), 'a Ring of Invisibility makes its wearer invisible');
  FxEngine.RemoveEffect(c, C_EFFECT.INVISIBLE, nil);
  EffHndlr.EffReadyItem(c, @item, True);

  { the attack-time handlers with no target }
  cbt.other := nil;
  GameVars.gAttackRoll := 7;
  GameVars.pendingDamage := 5;
  EffHndlr.EffFlameTongue(c, nil, False);
  EffHndlr.EffUndeadSlayer(c, nil, False);
  TestKit.CheckEqualsL(7, GameVars.gAttackRoll, 'no target: the roll is untouched');
  TestKit.CheckEqualsL(5, GameVars.pendingDamage, 'no target: the damage is untouched');
  TestKit.Done;
end.
