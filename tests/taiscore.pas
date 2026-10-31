{ Tests for what the combat AI weighs (#1087, #1143). CombatAi.KnowsItem and CalcWeaponPriority: the party's AI scores
  an unidentified weapon as the mundane weapon, with no plus and no curse, while a monster knows its own gear.
  CombatAi.SpellImpact: Resist Fire and Resist Cold are worth casting only once an enemy has been seen doing that
  element's damage (FxEngine.seenElements), Protection From Normal Missiles only while an enemy has a missile weapon
  readied, and Silence counts a single seen caster, held to no floor. }
{$I COMPILER.INC}
program TAiScore;

uses Types, C_EFFECT, C_EQUIP, C_ITEM, C_RACE, C_SPELL, GameDefs, GameVars, CharHlp, FxEngine, CbtMap, CbtActs,
  CombatAi, TestKit;

const
  { open ground: terrain 5, cost 1 }
  GROUND = 5;

var
  cleric: Types.TCharRecord;
  mage: Types.TCharRecord;
  archer: Types.TCharRecord;
  clericCombat: Types.TCombatRec;
  mageCombat: Types.TCombatRec;
  archerCombat: Types.TCombatRec;
  sword: Types.TItemRec;
  bow: Types.TItemRec;

{ c as an enabled human on one tile, of the given side (hostile), with combat record cr. }
procedure Make(var c: Types.TCharRecord; var cr: Types.TCombatRec; name: Types.TName15; hostile: ShortInt);
begin
  FillChar(c, SizeOf(c), 0);
  FillChar(cr, SizeOf(cr), 0);
  c.race := C_RACE.HUMAN;
  c.iconDimensions := 1;
  c.name := name;
  c.enabled := 1;
  c.levelHighest := 5;
  c.hostile := hostile;
  c.combatAddr := @cr;
end;

{ Put slot's one-tile body at (x, y) and rebuild the arena's creature cells. }
procedure Place(slot: Byte; x, y: ShortInt);
begin
  GameVars.arenaLoc[slot].x := x;
  GameVars.arenaLoc[slot].y := y;
  GameVars.arenaLoc[slot].size := 1;
  CbtMap.BuildArenaArrays;
end;

begin
  TestKit.Start('TAISCORE');
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  with CharHlp.baseItems^[C_ITEM.LONG_SWORD] do begin
    slot := C_EQUIP.WEAPON;
    hands := 1;
    dmgSmDice := 8;
    dmgSmRolls := 1;
  end;
  with CharHlp.baseItems^[C_ITEM.LONG_BOW] do begin
    slot := C_EQUIP.WEAPON;
    hands := 2;
    range := 15;
  end;
  Make(cleric, clericCombat, 'CLERIC', 0);
  Make(mage, mageCombat, 'MAGE', 1);
  Make(archer, archerCombat, 'ARCHER', 1);

  { an unidentified +2 sword: the party's AI scores it as a long sword, a monster as what it is }
  FillChar(sword, SizeOf(sword), 0);
  sword.itemType := C_ITEM.LONG_SWORD;
  sword.plus := 2;
  sword.unidMask := 6;
  TestKit.Check(not CombatAi.KnowsItem(@cleric, @sword), 'the party does not know an unidentified sword');
  TestKit.Check(CombatAi.KnowsItem(@mage, @sword), 'a monster knows its own');
  TestKit.CheckEqualsL(8 + 3, CombatAi.CalcWeaponPriority(@cleric, @sword), 'unidentified: scored as a long sword');
  TestKit.CheckEqualsL(8 + 3 + 16, CombatAi.CalcWeaponPriority(@mage, @sword), 'the monster counts the plus');
  sword.unidMask := 0;
  TestKit.CheckEqualsL(8 + 3 + 16, CombatAi.CalcWeaponPriority(@cleric, @sword), 'identified: the plus counts');
  { a cursed one: no one can tell until it is identified }
  sword.plus := -1;
  sword.cursed := 1;
  TestKit.CheckEqualsL(0, CombatAi.CalcWeaponPriority(@cleric, @sword), 'an identified cursed sword is never chosen');
  sword.unidMask := 6;
  TestKit.CheckEqualsL(8 + 3, CombatAi.CalcWeaponPriority(@cleric, @sword),
                       'an unidentified one looks like any long sword');

  { the arena: the cleric at (5, 5), the mage and the archer, enemies, at (8, 5) and (8, 8) }
  GetMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  FillChar(GameVars.arenaPtr^, SizeOf(Types.TArena), 0);
  FillChar(GameVars.arenaPtr^.cells, SizeOf(GameVars.arenaPtr^.cells), GROUND);
  FillChar(GameVars.arenaLoc, SizeOf(GameVars.arenaLoc), 0);
  GameVars.creatureList := nil;
  GameVars.arenaCount := 3;
  GameVars.creatureArr[1] := @cleric;
  GameVars.creatureArr[2] := @mage;
  GameVars.creatureArr[3] := @archer;
  Place(1, 5, 5);
  Place(2, 8, 5);
  Place(3, 8, 8);
  GameVars.curChar := @cleric;
  FillChar(FxEngine.seenElements, SizeOf(FxEngine.seenElements), 0);

  { Resist Fire and Resist Cold: only once an enemy has done that damage }
  TestKit.CheckEqualsL(0, CombatAi.SpellImpact(@cleric, C_SPELL.RESIST_FIRE), 'no Resist Fire with no fire seen');
  FxEngine.seenElements[1] := C_EFFECT.ELEM_FIRE;
  TestKit.CheckEqualsL(0, CombatAi.SpellImpact(@cleric, C_SPELL.RESIST_FIRE), 'nor for fire from the cleric''s side');
  FxEngine.seenElements[2] := C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC;
  TestKit.CheckEqualsL(1, CombatAi.SpellImpact(@cleric, C_SPELL.RESIST_FIRE), 'Resist Fire once the mage burns');
  TestKit.CheckEqualsL(0, CombatAi.SpellImpact(@cleric, C_SPELL.RESIST_COLD), 'but not Resist Cold');
  mage.enabled := 0;
  TestKit.CheckEqualsL(0, CombatAi.SpellImpact(@cleric, C_SPELL.RESIST_FIRE), 'nor once that mage is down');
  mage.enabled := 1;
  FxEngine.AddEffect(@cleric, GameDefs.spellTable[C_SPELL.RESIST_FIRE].effect, 0, 0, False);
  TestKit.CheckEqualsL(0, CombatAi.SpellImpact(@cleric, C_SPELL.RESIST_FIRE), 'nor while the cleric resists already');
  FxEngine.RemoveEffect(@cleric, GameDefs.spellTable[C_SPELL.RESIST_FIRE].effect, nil);

  { Protection From Normal Missiles: only while an enemy has a missile weapon readied }
  TestKit.CheckEqualsL(0, CombatAi.SpellImpact(@cleric, C_SPELL.PROT_NORMAL_MISSILES),
                       'no Protection From Normal Missiles with no bow in sight');
  FillChar(bow, SizeOf(bow), 0);
  bow.itemType := C_ITEM.LONG_BOW;
  archer.equipped[C_EQUIP.WEAPON] := @bow;
  TestKit.CheckEqualsL(1, CombatAi.SpellImpact(@cleric, C_SPELL.PROT_NORMAL_MISSILES), 'but with the archer''s bow');
  archer.equipped[C_EQUIP.WEAPON] := nil;

  { Silence: one seen caster is enough, though it is an area spell }
  CbtActs.seenCasting := [];
  TestKit.CheckEqualsL(0, CombatAi.SpellImpact(@cleric, C_SPELL.SILENCE), 'no Silence with no one seen casting');
  CbtActs.seenCasting := [2];
  TestKit.CheckEqualsL(1, CombatAi.SpellImpact(@cleric, C_SPELL.SILENCE), 'Silence for the one mage seen casting');

  GameVars.curChar := nil;
  FreeMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  GameVars.arenaPtr := nil;
  FreeMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  TestKit.Done;
end.
