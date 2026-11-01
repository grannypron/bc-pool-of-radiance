{ Tests for the spells of levels 4 and 5 and the druid's first (#1121), Curse's at Curse's ids: their spell-table rows
  (class, level, name) and the ids that hold no spell (C_SPELL.LAST, EMPTY_IDS); the shapes they reach
  (CharHlp.SpellArea: the cones, the pools) and what a pool's target costs (CharHlp.PoolCost); and their effects'
  handlers: Faerie Fire's armor class, Entangle's movement, Fire Shield's saves and damage (FxEngine.FireShieldDamage),
  the Minor Globe, Dispel Evil, Invisibility to Animals and Fear's flight. }
{$I COMPILER.INC}
program TSpell45;

uses Types, C_EFFECT, C_ALIGN, C_LEVEL, C_NPC, C_SPELL, GameDefs, GameVars, FxEngine, EffHndlr, CharHlp, CbtActs,
  CbtMap, Magic, StrUtil, TestKit;

const
  { open ground: terrain 5, cost 1 }
  GROUND = 5;

var
  c: Types.PCharRecord;
  foe: Types.PCharRecord;
  id: Byte;
  size: Byte;
  ok: Boolean;
  named: Boolean;
  { the cone test's creatures: ahead on the line, beside it, past its reach and behind the caster }
  ahead: Types.TCharRecord;
  beside: Types.TCharRecord;
  beyond: Types.TCharRecord;
  behind: Types.TCharRecord;
  cells: Types.TCellList;
  i: Byte;
  far: Boolean;

{ Put slot's one-tile body, creature cr, at (x, y) and rebuild the arena's creature cells. }
procedure Place(slot: Byte; cr: Types.PCharRecord; x, y: ShortInt);
begin
  FillChar(cr^, SizeOf(Types.TCharRecord), 0);
  cr^.enabled := 1;
  GameVars.creatureArr[slot] := cr;
  GameVars.arenaLoc[slot].x := x;
  GameVars.arenaLoc[slot].y := y;
  GameVars.arenaLoc[slot].size := 1;
  CbtMap.BuildArenaArrays;
end;

{ True when cr is among the spell's targets. }
function Targeted(cr: Types.PCharRecord): Boolean;
var
  k: Byte;
begin
  Targeted := False;
  for k := 1 to GameVars.spellTargetCount do
    if GameVars.spellTargets[k] = cr then
      Targeted := True;
end;

function NewCreature: Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  GetMem(p, SizeOf(Types.TCharRecord));
  FillChar(p^, SizeOf(Types.TCharRecord), 0);
  GetMem(p^.combatAddr, SizeOf(Types.TCombatRec));
  FillChar(p^.combatAddr^, SizeOf(Types.TCombatRec), 0);
  NewCreature := p;
end;

{ spell id's row is of class cls and level lvl, and has a name }
procedure CheckRow(spell, cls, lvl: Byte);
begin
  TestKit.Check(CharHlp.IsSpell(spell) and (GameDefs.spellTable[spell].castClass = cls) and
                (GameDefs.spellTable[spell].level = lvl) and (GameDefs.spellNames[spell] <> ''),
                GameDefs.spellNames[spell] + ' (' + StrUtil.NumStr(spell) + '): class ' + StrUtil.NumStr(cls) +
                ', level ' + StrUtil.NumStr(lvl));
end;

{ the damage left of 10 of element elem on c, saved or not, after Fire Shield (FxEngine.FireShieldDamage) }
function Shielded(elem: Byte; saved: Boolean): Integer;
begin
  GameVars.elementMask := elem;
  GameVars.pendingDamage := 10;
  FxEngine.FireShieldDamage(c, saved);
  Shielded := GameVars.pendingDamage;
end;

begin
  TestKit.Start('TSPELL45');
  c := NewCreature;
  foe := NewCreature;
  GameVars.curChar := c;
  GameVars.usingItem := False;

  { the rows, Curse's with its class remapped: cleric 0, magic-user 1, druid 2 }
  CheckRow(C_SPELL.CURE_SERIOUS_WOUNDS, C_SPELL.CLASS_CLERIC, 4);
  CheckRow(C_SPELL.CAUSE_SERIOUS_WOUNDS, C_SPELL.CLASS_CLERIC, 4);
  CheckRow(C_SPELL.NEUTRALIZE_POISON, C_SPELL.CLASS_CLERIC, 4);
  CheckRow(C_SPELL.POISON, C_SPELL.CLASS_CLERIC, 4);
  CheckRow(69, C_SPELL.CLASS_CLERIC, 4);
  CheckRow(C_SPELL.STICKS_TO_SNAKES, C_SPELL.CLASS_CLERIC, 4);
  for id := C_SPELL.CURE_CRITICAL_WOUNDS to C_SPELL.SLAY_LIVING do
    CheckRow(id, C_SPELL.CLASS_CLERIC, 5);
  for id := C_SPELL.DETECT_MAGIC_DRUID to C_SPELL.INVISIBILITY_TO_ANIMALS do
    CheckRow(id, C_SPELL.CLASS_DRUID, 1);
  for id := C_SPELL.CHARM_MONSTERS to 89 do
    CheckRow(id, C_SPELL.CLASS_MAGE, 4);
  CheckRow(C_SPELL.BESTOW_CURSE_MU, C_SPELL.CLASS_MAGE, 4);
  CheckRow(C_SPELL.ANIMATE_DEAD_MU, C_SPELL.CLASS_MAGE, 5);
  for id := C_SPELL.CONE_OF_COLD to C_SPELL.HOLD_MONSTERS do
    CheckRow(id, C_SPELL.CLASS_MAGE, 5);
  TestKit.CheckEqualsL(C_EFFECT.PROT_EVIL_10FT, GameDefs.spellTable[69].effect, 'the cleric''s 10'' protection');
  TestKit.CheckEqualsL(C_EFFECT.CHARM, GameDefs.spellTable[C_SPELL.CHARM_MONSTERS].effect, 'Charm Monsters charms');
  TestKit.CheckEqualsL(C_EFFECT.PARALYZED, GameDefs.spellTable[C_SPELL.HOLD_MONSTERS].effect, 'Hold Monsters holds');
  TestKit.CheckEqualsL(0, GameDefs.spellTable[C_SPELL.RAISE_DEAD].whenCast, 'Raise Dead is cast in camp');
  TestKit.CheckEqualsL(0, GameDefs.spellTable[C_SPELL.NEUTRALIZE_POISON].whenCast, 'so is Neutralize Poison');

  { the ids: every spell of 1..LAST has a name and is no empty id; an empty id has neither a name nor a class; past
    LAST only the item spells hold anything }
  ok := True;
  for id := 1 to C_SPELL.TABLE_LAST do begin
    named := (id <= C_SPELL.LAST) and (GameDefs.spellNames[id] <> '');
    if CharHlp.IsSpell(id) <> named then
      ok := False;
    if (id in C_SPELL.EMPTY_IDS) and
       (named or (GameDefs.spellTable[id].castClass <> C_SPELL.CLASS_SPECIAL) or
        (GameDefs.spellTable[id].effect <> 0)) then
      ok := False;
    if not (id in C_SPELL.EMPTY_IDS) and not named and
       not ((id = C_SPELL.ITEM_SPEED) or ((id >= C_SPELL.ITEM_GIANT_STRENGTH) and (id <= C_SPELL.WAND_MAGIC_MISSILES))
            or (id = C_SPELL.ITEM_OINTMENT) or (id = C_SPELL.ITEM_BODILY_HEALTH)) then
      ok := False;
  end;
  TestKit.Check(ok, 'the named spells, the item spells and the empty ids account for every id');
  TestKit.Check(CharHlp.IsSpell(C_SPELL.LAST) and not (C_SPELL.LAST in C_SPELL.EMPTY_IDS), 'LAST is a spell');
  TestKit.Check(not CharHlp.IsSpell(91) and (91 in C_SPELL.EMPTY_IDS), 'Cloudkill''s id holds no spell');
  TestKit.Check(not CharHlp.IsSpell(C_SPELL.ITEM_SPEED), 'an item spell inside 1..LAST is no spell');

  { the shapes }
  TestKit.CheckEqualsL(C_SPELL.AREA_CONE, CharHlp.SpellArea(C_SPELL.FEAR, size), 'Fear is a cone');
  TestKit.CheckEqualsL(C_SPELL.FEAR_CONE_CELLS, size, '6 squares long');
  c^.classLevels[C_LEVEL.MAGE] := 9;
  TestKit.CheckEqualsL(C_SPELL.AREA_CONE, CharHlp.SpellArea(C_SPELL.CONE_OF_COLD, size), 'Cone of Cold is a cone');
  TestKit.CheckEqualsL(5, size, 'half the caster level, 9, rounded up');
  c^.classLevels[C_LEVEL.MAGE] := 0;
  TestKit.CheckEqualsL(C_SPELL.AREA_CONE, CharHlp.SpellArea(C_SPELL.CONE_OF_COLD, size), 'still a cone');
  TestKit.CheckEqualsL(1, size, 'never shorter than 1');
  TestKit.CheckEqualsL(C_SPELL.AREA_POOL, CharHlp.SpellArea(C_SPELL.FAERIE_FIRE, size), 'Faerie Fire buys from a pool');
  TestKit.CheckEqualsL(C_SPELL.AREA_POOL, CharHlp.SpellArea(C_SPELL.CHARM_MONSTERS, size), 'so does Charm Monsters');
  TestKit.CheckEqualsL(C_SPELL.AREA_RADIUS, CharHlp.SpellArea(C_SPELL.ICE_STORM, size), 'Ice Storm a radius');
  TestKit.CheckEqualsL(2, size, 'of 2');
  TestKit.CheckEqualsL(C_SPELL.AREA_RADIUS, CharHlp.SpellArea(C_SPELL.ENTANGLE, size), 'Entangle a radius');
  TestKit.CheckEqualsL(3, size, 'of 3');
  TestKit.CheckEqualsL(C_SPELL.AREA_TARGETS, CharHlp.SpellArea(C_SPELL.HOLD_MONSTERS, size), 'Hold Monsters picks');
  TestKit.CheckEqualsL(4, size, 'up to 4');
  TestKit.CheckEqualsL(C_SPELL.AREA_SELF, CharHlp.SpellArea(C_SPELL.FIRE_SHIELD, size), 'Fire Shield the caster');

  { the pools' costs }
  foe^.iconDimensions := 1;
  TestKit.CheckEqualsL(1, CharHlp.PoolCost(C_SPELL.FAERIE_FIRE, foe), 'Faerie Fire: man-sized 1');
  foe^.iconDimensions := 1 + Types.ICON_LARGE;
  TestKit.CheckEqualsL(2, CharHlp.PoolCost(C_SPELL.FAERIE_FIRE, foe), 'a Large one 2');
  foe^.iconDimensions := 2;
  TestKit.CheckEqualsL(2, CharHlp.PoolCost(C_SPELL.FAERIE_FIRE, foe), 'a two-square icon 2');
  foe^.iconDimensions := 4;
  TestKit.CheckEqualsL(4, CharHlp.PoolCost(C_SPELL.FAERIE_FIRE, foe), 'a huge one 4');
  foe^.levelHighest := 1;
  TestKit.CheckEqualsL(1, CharHlp.PoolCost(C_SPELL.CHARM_MONSTERS, foe), 'Charm Monsters: level 1 costs 1');
  foe^.levelHighest := 2;
  TestKit.CheckEqualsL(2, CharHlp.PoolCost(C_SPELL.CHARM_MONSTERS, foe), 'level 2 costs 2');
  foe^.levelHighest := 3;
  TestKit.CheckEqualsL(4, CharHlp.PoolCost(C_SPELL.CHARM_MONSTERS, foe), 'level 3 costs 4');
  foe^.levelHighest := 7;
  TestKit.CheckEqualsL(8, CharHlp.PoolCost(C_SPELL.CHARM_MONSTERS, foe), 'higher costs 8');

  { Faerie Fire: armor class 2 worse, front and rear, not below 0 }
  c^.acCur := 55;
  c^.acBehind := 1;
  EffHndlr.EffFaerieFire(c, nil, False);
  TestKit.CheckEqualsL(53, c^.acCur, 'Faerie Fire: AC 2 worse');
  TestKit.CheckEqualsL(0, c^.acBehind, 'and no lower than 0');

  { Entangle: held still, or halved when it saved, only while movement is worked out }
  FxEngine.AddEffect(c, C_EFFECT.ENTANGLE, 10, 0, False);
  GameVars.currentCreatureCalculatingFlag := 1;
  GameVars.currentAttackCurrent := 24;
  EffHndlr.EffEntangle(c, c^.effectsAddr, False);
  TestKit.CheckEqualsL(0, GameVars.currentAttackCurrent, 'Entangle holds a creature still');
  c^.effectsAddr^.strength := 1;
  GameVars.currentAttackCurrent := 24;
  EffHndlr.EffEntangle(c, c^.effectsAddr, False);
  TestKit.CheckEqualsL(12, GameVars.currentAttackCurrent, 'one that saved moves at half');
  GameVars.currentCreatureCalculatingFlag := 0;
  GameVars.currentAttackCurrent := 2;
  EffHndlr.EffEntangle(c, c^.effectsAddr, False);
  TestKit.CheckEqualsL(2, GameVars.currentAttackCurrent, 'its attacks are left alone');
  FxEngine.RemoveEffect(c, C_EFFECT.ENTANGLE, nil);

  { Fire Shield }
  GameVars.elementMask := C_EFFECT.ELEM_COLD;
  FxEngine.saveRoll := 10;
  EffHndlr.EffFireShieldHot(c, nil, False);
  TestKit.CheckEqualsL(12, FxEngine.saveRoll, 'the hot flames: +2 to save against cold');
  GameVars.elementMask := C_EFFECT.ELEM_FIRE;
  EffHndlr.EffFireShieldHot(c, nil, False);
  TestKit.CheckEqualsL(12, FxEngine.saveRoll, 'not against fire');
  EffHndlr.EffFireShieldCold(c, nil, False);
  TestKit.CheckEqualsL(14, FxEngine.saveRoll, 'the cold flames: +2 against fire');
  TestKit.CheckEqualsL(10, Shielded(C_EFFECT.ELEM_FIRE, False), 'no flames: fire as it is');
  FxEngine.AddEffect(c, C_EFFECT.FIRE_SHIELD_HOT, 10, 1, False);
  TestKit.CheckEqualsL(20, Shielded(C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC, False), 'hot: unsaved fire doubled');
  TestKit.CheckEqualsL(10, Shielded(C_EFFECT.ELEM_FIRE, True), 'saved fire as it is');
  TestKit.CheckEqualsL(5, Shielded(C_EFFECT.ELEM_COLD, False), 'unsaved cold halved');
  TestKit.CheckEqualsL(0, Shielded(C_EFFECT.ELEM_COLD, True), 'saved cold none');
  TestKit.CheckEqualsL(10, Shielded(C_EFFECT.ELEM_MAGIC, False), 'magic as it is');
  FxEngine.RemoveEffect(c, C_EFFECT.FIRE_SHIELD_HOT, nil);
  FxEngine.AddEffect(c, C_EFFECT.FIRE_SHIELD_COLD, 10, 1, False);
  TestKit.CheckEqualsL(20, Shielded(C_EFFECT.ELEM_COLD, False), 'cold: unsaved cold doubled');
  TestKit.CheckEqualsL(5, Shielded(C_EFFECT.ELEM_FIRE, False), 'unsaved fire halved');
  FxEngine.RemoveEffect(c, C_EFFECT.FIRE_SHIELD_COLD, nil);

  { the Minor Globe: spells of level 3 and below do nothing }
  GameVars.spellId := C_SPELL.FIREBALL;
  GameVars.pendingDamage := 9;
  GameVars.pendingEffectId := C_EFFECT.SLEEP;
  EffHndlr.EffMinorGlobe(c, nil, False);
  TestKit.Check((GameVars.pendingDamage = 0) and (GameVars.pendingEffectId = 0), 'the globe stops a Fireball');
  GameVars.spellId := C_SPELL.CONE_OF_COLD;
  GameVars.pendingDamage := 9;
  EffHndlr.EffMinorGlobe(c, nil, False);
  TestKit.CheckEqualsL(9, GameVars.pendingDamage, 'not a Cone of Cold');
  GameVars.spellId := C_SPELL.NONE;
  EffHndlr.EffMinorGlobe(c, nil, False);
  TestKit.CheckEqualsL(9, GameVars.pendingDamage, 'nor what no spell does');
  GameVars.spellId := C_SPELL.ITEM_FIREBALL;
  EffHndlr.EffMinorGlobe(c, nil, False);
  TestKit.CheckEqualsL(9, GameVars.pendingDamage, 'nor an item''s fireball, which is no spell of a level');
  GameVars.spellId := C_SPELL.NONE;

  { Dispel Evil reaches evil undead and otherworldly creatures }
  foe^.alignment := C_ALIGN.CHAOTIC_EVIL;
  foe^.charType := CharHlp.UNDEAD_TYPE;
  TestKit.Check(EffHndlr.DispelEvilReaches(foe), 'Dispel Evil reaches an evil undead');
  foe^.charType := 7;
  TestKit.Check(EffHndlr.DispelEvilReaches(foe), 'and an evil efreeti');
  foe^.charType := 1;
  TestKit.Check(not EffHndlr.DispelEvilReaches(foe), 'not an evil orc');
  foe^.charType := CharHlp.UNDEAD_TYPE;
  foe^.alignment := C_ALIGN.TRUE_NEUTRAL;
  TestKit.Check(not EffHndlr.DispelEvilReaches(foe), 'nor a neutral zombie');
  foe^.alignment := C_ALIGN.LAWFUL_EVIL;
  GameVars.curChar := foe;
  GameVars.gAttackRoll := 15;
  EffHndlr.EffDispelEvil(c, nil, False);
  TestKit.CheckEqualsL(8, GameVars.gAttackRoll, 'an evil undead attacks the caster at -7');
  foe^.charType := 0;
  EffHndlr.EffDispelEvil(c, nil, False);
  TestKit.CheckEqualsL(8, GameVars.gAttackRoll, 'an evil man as he would');

  { Invisibility to Animals }
  foe^.charType := 15;
  CbtActs.suppressTargeting := 0;
  GameVars.gAttackRoll := 15;
  EffHndlr.EffInvisibleToAnimals(c, nil, False);
  TestKit.Check(CbtActs.suppressTargeting <> 0, 'a wolf cannot target one invisible to animals');
  TestKit.CheckEqualsL(11, GameVars.gAttackRoll, 'and attacks at -4');
  foe^.charType := 0;
  CbtActs.suppressTargeting := 0;
  EffHndlr.EffInvisibleToAnimals(c, nil, False);
  TestKit.Check(CbtActs.suppressTargeting = 0, 'a man can');
  GameVars.curChar := c;

  { Fear: the creature flees under computer control, and gets its control back when the fear ends }
  GameVars.effectFns[C_EFFECT.FEAR] := EffHndlr.EffFear;
  FxEngine.AddEffect(foe, C_EFFECT.FEAR, 10, 1, True);
  EffHndlr.StartFear(foe);
  TestKit.Check((foe^.combatAddr^.turned = 1) and (foe^.quickfight = 1) and (foe^.npc = C_NPC.ANIMATED_PC),
                'a frightened party member flees under the computer');
  FxEngine.RemoveEffect(foe, C_EFFECT.FEAR, nil);
  TestKit.Check((foe^.combatAddr^.turned = 0) and (foe^.quickfight = 0) and (foe^.npc = 0),
                'and comes back to the player when the fear ends');

  { Fear's cone from (10, 10) aimed east at (12, 10): the line runs on to its 6 squares, with a ray on either side }
  GetMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  FillChar(GameVars.arenaPtr^, SizeOf(Types.TArena), 0);
  FillChar(GameVars.arenaPtr^.cells, SizeOf(GameVars.arenaPtr^.cells), GROUND);
  FillChar(GameVars.arenaLoc, SizeOf(GameVars.arenaLoc), 0);
  GameVars.arenaCount := 6;
  GameVars.curChar := c;
  GameVars.creatureArr[1] := c;
  GameVars.arenaLoc[1].x := 10;
  GameVars.arenaLoc[1].y := 10;
  GameVars.arenaLoc[1].size := 1;
  Place(2, @ahead, 15, 10);
  Place(3, @beside, 16, 11);
  Place(4, @beyond, 18, 10);
  Place(5, @behind, 8, 10);
  Magic.TraceCone(10, 10, 12, 10, C_SPELL.FEAR_CONE_RAYS, C_SPELL.FEAR_CONE_CELLS, cells);
  ok := False;
  far := False;
  for i := 1 to cells.count do begin
    if (cells.x[i] = 16) and (cells.y[i] = 10) then
      ok := True;
    if (cells.x[i] > 16) or (cells.x[i] < 11) then
      far := True;
  end;
  TestKit.Check(ok, 'the cone''s line reaches its sixth square');
  TestKit.Check(not far, 'and no further, nor behind the caster');
  Magic.CollectConeTargets(10, 10, 12, 10, C_SPELL.FEAR_CONE_RAYS, C_SPELL.FEAR_CONE_CELLS);
  TestKit.Check(Targeted(@ahead), 'Fear catches the creature ahead on its line');
  TestKit.Check(Targeted(@beside), 'and the one at the end of a side ray');
  TestKit.Check(not Targeted(@beyond) and not Targeted(@behind), 'not one past its reach nor one behind');
  TestKit.Check(not Targeted(c), 'nor the caster');
  Magic.CollectConeTargets(10, 10, 12, 10, C_SPELL.COLD_CONE_RAYS, 2);
  TestKit.Check(not Targeted(@ahead), 'a cone of 2 squares stops short of the creature ahead');
  Magic.CollectConeTargets(10, 10, 10, 10, C_SPELL.FEAR_CONE_RAYS, C_SPELL.FEAR_CONE_CELLS);
  TestKit.CheckEqualsL(0, GameVars.spellTargetCount, 'a cone aimed at its own origin catches no one');
  GameVars.arenaPtr^.cells[10, 13] := 1;
  Magic.CollectConeTargets(10, 10, 12, 10, C_SPELL.FEAR_CONE_RAYS, C_SPELL.FEAR_CONE_CELLS);
  TestKit.Check(not Targeted(@ahead), 'a wall on the line stops it');
  GameVars.arenaCount := 0;
  FreeMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  GameVars.arenaPtr := nil;

  TestKit.Done;
end.
