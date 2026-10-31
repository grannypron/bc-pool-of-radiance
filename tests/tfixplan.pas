{ Tests for FixPlan (#1129): a drained cleric plans no cure it lacks the slots for, and is noted for it; a member with
  mummy rot gets no Cure Light Wounds unless its rot is cured first; the cures and heals and the rest they take; and
  the scrolls, potions and paladin's powers the Fix settings let Fix use, each only while its setting is on. }
{$I COMPILER.INC}
program TFixPlan;

uses Types, GameVars, C_EFFECT, C_IFC, C_ITEM, C_LEVEL, C_SPELL, C_STATUS, CharHlp, FixPlan, TestKit;

const
  { the item types the test gives a cleric's scroll and a potion: any free rows of the base item table }
  SCROLL_TYPE = 100;
  POTION_TYPE = 101;

var
  cleric: Types.PCharRecord;
  rotted: Types.PCharRecord;
  fighter: Types.PCharRecord;
  rot: Types.TEffectRec;
  disease: Types.TEffectRec;
  cureUsed: Types.TEffectRec;
  scroll: Types.TItemRec;
  potion: Types.TItemRec;
  plan: FixPlan.TFixPlan;
  use: FixPlan.TFixUse;

{ A new okay party member named name, with hp of maxHp hit points. }
function NewMember(name: string; hp, maxHp: Byte): Types.PCharRecord;
var
  c: Types.PCharRecord;
begin
  New(c);
  FillChar(c^, SizeOf(c^), 0);
  c^.name := name;
  c^.hpCur := hp;
  c^.hpMax := maxHp;
  c^.status := C_STATUS.OKAY;
  c^.enabled := 1;
  NewMember := c;
end;

{ Give the cleric level lvl's slots (the cleric's table: 3/2/0 at 4, 3/3/1 at 5), drained by drained levels. }
procedure SetCleric(lvl, drained: Byte);
begin
  cleric^.classLevels[C_LEVEL.CLERIC] := lvl;
  cleric^.levelHighest := lvl;
  cleric^.drainedLevels := drained;
  cleric^.clericSpells[1] := 3;
  if lvl >= 5 then begin
    cleric^.clericSpells[2] := 3;
    cleric^.clericSpells[3] := 1;
  end else begin
    cleric^.clericSpells[2] := 2;
    cleric^.clericSpells[3] := 0;
  end;
end;

{ Turn every Fix setting off. }
procedure AllOff;
begin
  GameVars.fixScrollsOn := 0;
  GameVars.fixPotionsOn := 0;
  GameVars.fixCureOn := 0;
  GameVars.fixHealOn := 0;
end;

begin
  TestKit.Start('TFIXPLAN');
  GameVars.ifcState := C_IFC.CAMPING;
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  CharHlp.baseItems^[SCROLL_TYPE].slot := C_ITEM.SLOT_CLERIC_SCROLL;
  CharHlp.baseItems^[SCROLL_TYPE].classMask := 1;

  { the party: a cleric, a fighter with mummy rot, and a wounded fighter }
  cleric := NewMember('CLERIC', 20, 20);
  cleric^.spellsKnown[C_SPELL.CURE_LIGHT_WOUNDS] := 1;
  cleric^.spellsKnown[C_SPELL.CURE_DISEASE] := 1;
  cleric^.spellsKnown[C_SPELL.CURE_BLINDNESS] := 1;
  cleric^.itemLimits := 1;
  rotted := NewMember('ROTTED', 10, 30);
  rotted^.classLevels[C_LEVEL.FIGHTER] := 5;
  FillChar(rot, SizeOf(rot), 0);
  rot.id := C_EFFECT.ROT_NO_HEAL;
  FillChar(disease, SizeOf(disease), 0);
  disease.id := C_EFFECT.MUMMY_ROT;
  rot.next := @disease;
  rotted^.effectsAddr := @rot;
  fighter := NewMember('FIGHTER', 20, 30);
  fighter^.classLevels[C_LEVEL.FIGHTER] := 5;
  cleric^.nextCharAddr := rotted;
  rotted^.nextCharAddr := fighter;
  GameVars.creatureList := cleric;

  { the cure table }
  TestKit.CheckEqualsL(C_SPELL.RESTORATION, FixPlan.CureSpell(FixPlan.FIX_DRAIN), 'Restoration cures a drained level');
  TestKit.CheckEqualsL(C_SPELL.CURE_DISEASE, FixPlan.CureSpell(FixPlan.FIX_DISEASE), 'Cure Disease a disease');
  TestKit.CheckEqualsL(C_SPELL.REMOVE_CURSE, FixPlan.CureSpell(FixPlan.FIX_CURSE), 'Remove Curse a curse');
  TestKit.CheckEqualsL(1, FixPlan.CondCount(rotted, FixPlan.FIX_DISEASE), 'mummy rot is a disease');
  TestKit.Check(FixPlan.Rotted(rotted) and not FixPlan.Rotted(fighter), 'and stops healing');

  { a cleric drained from 5 to 4: no Cure Disease, and no healing wasted on the rotted fighter }
  SetCleric(4, 1);
  FixPlan.Plan(plan);
  TestKit.CheckEqualsL(3, plan.n, 'three members');
  TestKit.CheckEqualsL(1, plan.clerics, 'one cleric');
  TestKit.CheckEqualsL(0, plan.cures[2, FixPlan.FIX_DISEASE], 'no slot for Cure Disease');
  TestKit.CheckEqualsL(1, plan.left[2, FixPlan.FIX_DISEASE], 'so the rot is left');
  TestKit.CheckEqualsL(1, plan.left[1, FixPlan.FIX_DRAIN], 'and the drain, with no slot for Restoration');
  TestKit.CheckEqualsL(10, plan.need, 'only the fighter''s wounds count, not the rotted one''s');
  TestKit.CheckEqualsL(3, plan.healCasts, 'three Cure Light Wounds for 10 hit points');
  TestKit.CheckEqualsL(240 + 45, FixPlan.RestMinutes(plan), 'four hours and 15 minutes a cast');
  TestKit.Check(FixPlan.DrainedOutOf(cleric, C_SPELL.CURE_DISEASE), 'the drained cleric lacks Cure Disease');
  TestKit.Check(not FixPlan.DrainedOutOf(cleric, C_SPELL.CURE_LIGHT_WOUNDS), 'not Cure Light Wounds');
  TestKit.Check(not FixPlan.DrainedOutOf(cleric, C_SPELL.RESTORATION), 'nor Restoration, past any slot here');
  cleric^.drainedLevels := 0;
  TestKit.Check(not FixPlan.DrainedOutOf(cleric, C_SPELL.CURE_DISEASE), 'an undrained level 4 cleric is not noted');

  { a level 5 cleric cures the rot first, and then the rotted fighter's wounds count }
  SetCleric(5, 0);
  FixPlan.Plan(plan);
  TestKit.CheckEqualsL(1, plan.cures[2, FixPlan.FIX_DISEASE], 'a level 5 cleric plans Cure Disease');
  TestKit.CheckEqualsL(30, plan.need, 'and the rotted fighter''s wounds count with the cure');
  TestKit.CheckEqualsL(3, plan.healCasts, 'as many heals as the slots allow');
  TestKit.CheckEqualsL(360 + 45 + 45, FixPlan.RestMinutes(plan), 'six hours with a level 3 spell');
  TestKit.Check(FixPlan.HasCasts(plan), 'the clerics cast');

  { an unconscious cleric casts nothing }
  cleric^.status := C_STATUS.UNCONSCIOUS;
  FixPlan.Plan(plan);
  TestKit.CheckEqualsL(0, plan.ableClerics, 'an unconscious cleric is not able');
  TestKit.Check(not FixPlan.HasCasts(plan), 'and casts nothing');
  cleric^.status := C_STATUS.OKAY;

  { with every setting off, Fix uses nothing }
  AllOff;
  SetCleric(4, 1);
  FillChar(scroll, SizeOf(scroll), 0);
  scroll.itemType := SCROLL_TYPE;
  scroll.spells[1] := C_SPELL.RESTORATION;
  scroll.spells[2] := C_SPELL.CURE_DISEASE;
  scroll.nameIds[2] := C_ITEM.NAME_WITH_1_SPELL + 1;
  cleric^.itemsAddr := @scroll;
  TestKit.Check(not FixPlan.NextUse(True, use), 'scrolls off: no Restoration');
  TestKit.Check(not FixPlan.NextUse(False, use), 'nor anything else');

  { with Use Scrolls on, the drained cleric reads Restoration on itself first }
  GameVars.fixScrollsOn := 1;
  TestKit.Check(FixPlan.NextUse(True, use), 'scrolls on: a Restoration');
  TestKit.Check((use.kind = FixPlan.USE_ITEM) and (use.user = cleric) and (use.item = @scroll) and
                (use.spell = C_SPELL.RESTORATION) and (use.target = cleric), 'read by the cleric on itself');
  { the cast gives the level back and spends the copy }
  scroll.spells[1] := 0;
  cleric^.drainedLevels := 0;
  TestKit.Check(not FixPlan.NextUse(True, use), 'the drain gone, no more Restoration');
  TestKit.Check(FixPlan.NextUse(False, use), 'the disease left');
  TestKit.Check((use.spell = C_SPELL.CURE_DISEASE) and (use.target = rotted), 'takes the scroll''s Cure Disease');
  scroll.spells[2] := 0;
  TestKit.Check(not FixPlan.NextUse(False, use), 'the scroll spent, nothing more');

  { a paladin's cure comes before a scroll }
  fighter^.classLevels[C_LEVEL.FIGHTER] := 0;
  fighter^.classLevels[C_LEVEL.PALADIN] := 3;
  scroll.spells[2] := C_SPELL.CURE_DISEASE;
  GameVars.fixCureOn := 1;
  TestKit.Check(FixPlan.NextUse(False, use), 'Use Paladin''s Cure');
  TestKit.Check((use.kind = FixPlan.USE_PALADIN_CURE) and (use.user = fighter) and (use.target = rotted),
                'the paladin cures the rotted fighter');
  FillChar(cureUsed, SizeOf(cureUsed), 0);
  cureUsed.id := C_EFFECT.RECENT_CURE;
  cureUsed.strength := 1;
  fighter^.effectsAddr := @cureUsed;
  TestKit.Check(FixPlan.NextUse(False, use) and (use.kind = FixPlan.USE_ITEM),
                'a level 3 paladin''s one cure a week spent, the scroll');
  scroll.spells[2] := 0;
  fighter^.effectsAddr := nil;

  { the rot gone, the wounds: a paladin lays on hands on the most wounded }
  rotted^.effectsAddr := nil;
  AllOff;
  GameVars.fixHealOn := 1;
  TestKit.Check(FixPlan.NextUse(False, use), 'Use Paladin''s Heal');
  TestKit.Check((use.kind = FixPlan.USE_LAY_ON_HANDS) and (use.user = fighter) and (use.target = rotted),
                'on the most wounded member');
  rotted^.effectsAddr := @rot;
  rot.next := nil;
  TestKit.Check(FixPlan.NextUse(False, use) and (use.target = fighter), 'one with mummy rot is passed by');
  rot.next := @disease;

  { a Potion of Healing for a member lacking at least 7 hit points, none for one with mummy rot }
  AllOff;
  GameVars.fixPotionsOn := 1;
  FillChar(potion, SizeOf(potion), 0);
  potion.itemType := POTION_TYPE;
  potion.effect := C_SPELL.ITEM_HEALING + C_SPELL.ITEM_EFFECT_SHIFT;
  potion.charges := 1;
  fighter^.itemsAddr := @potion;
  TestKit.Check(FixPlan.NextUse(False, use), 'Use Potions');
  TestKit.Check((use.spell = C_SPELL.ITEM_HEALING) and (use.user = fighter) and (use.target = fighter),
                'the fighter drinks its Potion of Healing; the rotted one gets none');
  fighter^.hpCur := 25;
  TestKit.Check(not FixPlan.NextUse(False, use), 'a member lacking 5 hit points gets none');
  potion.charges := 0;
  fighter^.hpCur := 20;
  TestKit.Check(not FixPlan.NextUse(False, use), 'nor from an empty potion');

  TestKit.Done;
end.
