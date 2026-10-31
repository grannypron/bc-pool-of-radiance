{ Tests for the combat core's rules that need no screen: the move and aim menus' cursor keys (CbtActs.DirOfKey), a
  blow's damage with a backstab and a ranger's bonus (CbtActs.WeaponDamage), the missiles a volley leaves
  (CbtActs.AmmoLeft), the wilderness arena's feature classes (CombatSt.TerrainClass), who the aim menu's Next and Prev
  reach (CbtActs.CanTarget's allowAlly, CbtActs.AimCycles, #1137) and a thrown weapon handed back to its thrower after
  the fight (CbtActs.NoteThrown, ReturnThrown, #1118). }
{$I COMPILER.INC}
program TCbtActs;

uses Types, C_DIR, C_KEYS, C_EFFECT, C_EQUIP, C_ITEM, GameVars, FxEngine, CharHlp, CbtActs, CombatSt, TestKit;

var
  att: Types.PCharRecord;
  ally: Types.PCharRecord;
  foe: Types.PCharRecord;
  hidden: Types.PCharRecord;
  axe: Types.TItemRec;
  thrower: Types.PCharRecord;
  back: Types.PItemRec;
  name: string;
  i: Byte;

{$F+}
{ An invisible creature's veto: it cannot be aimed at. }
procedure Veto(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  CbtActs.suppressTargeting := 1;
end;
{$F-}

{ A blank creature on side hostile, with a combat record, linked in front of GameVars.creatureList. }
function NewCreature(hostile: ShortInt): Types.PCharRecord;
var
  c: Types.PCharRecord;
begin
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  GetMem(c^.combatAddr, SizeOf(Types.TCombatRec));
  FillChar(c^.combatAddr^, SizeOf(Types.TCombatRec), 0);
  c^.hostile := hostile;
  c^.strCur := 18;
  c^.itemLimits := $FF;
  c^.nextCharAddr := GameVars.creatureList;
  GameVars.creatureList := c;
  NewCreature := c;
end;

{ How many items the loot holds. }
function LootCount: Byte;
var
  p: Types.PItemRec;
  n: Byte;
begin
  n := 0;
  p := GameVars.treasureItems;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  LootCount := n;
end;

{ att throws the hand axe: it drops into the loot, as MakeAttack drops it, and is noted. }
procedure Throw(c: Types.PCharRecord);
begin
  CharHlp.PrependItemCopy(GameVars.treasureItems, @axe);
  CbtActs.NoteThrown(c, GameVars.treasureItems);
end;

begin
  TestKit.Start('TCBTACTS');

  { cursor keys }
  TestKit.CheckEqualsL(C_DIR.NORTH, CbtActs.DirOfKey(C_KEYS.UP), 'Up is north');
  TestKit.CheckEqualsL(C_DIR.NORTHEAST, CbtActs.DirOfKey(C_KEYS.PAGE_UP), 'Page Up is north-east');
  TestKit.CheckEqualsL(C_DIR.EAST, CbtActs.DirOfKey(C_KEYS.RIGHT), 'Right is east');
  TestKit.CheckEqualsL(C_DIR.SOUTHEAST, CbtActs.DirOfKey(C_KEYS.PAGE_DOWN), 'Page Down is south-east');
  TestKit.CheckEqualsL(C_DIR.SOUTH, CbtActs.DirOfKey(C_KEYS.DOWN), 'Down is south');
  TestKit.CheckEqualsL(C_DIR.SOUTHWEST, CbtActs.DirOfKey(C_KEYS.END_KEY), 'End is south-west');
  TestKit.CheckEqualsL(C_DIR.WEST, CbtActs.DirOfKey(C_KEYS.LEFT), 'Left is west');
  TestKit.CheckEqualsL(C_DIR.NORTHWEST, CbtActs.DirOfKey(C_KEYS.HOME), 'Home is north-west');
  TestKit.CheckEqualsL(C_DIR.CENTER, CbtActs.DirOfKey(C_KEYS.ENTER), 'any other key (Enter) points nowhere');

  { a blow's damage }
  TestKit.CheckEqualsL(7, CbtActs.WeaponDamage(7, 1, 0), 'a plain blow');
  TestKit.CheckEqualsL(0, CbtActs.WeaponDamage(-3, 1, 0), 'a negative modifier stops at 0');
  TestKit.CheckEqualsL(4, CbtActs.WeaponDamage(-3, 2, 4), 'the ranger''s bonus on a blow of 0');
  TestKit.CheckEqualsL(30, CbtActs.WeaponDamage(10, 3, 0), 'a x3 backstab');
  TestKit.CheckEqualsL(255, CbtActs.WeaponDamage(52, 5, 0), 'a x5 backstab of 52 is held to 255, not wrapped to 4');
  TestKit.CheckEqualsL(255, CbtActs.WeaponDamage(250, 1, 9), 'a ranger''s bonus is held to 255');
  TestKit.CheckEqualsL(255, CbtActs.WeaponDamage(32767, 255, 255), 'the largest product is held to 255');

  { missiles left }
  TestKit.CheckEqualsL(8, CbtActs.AmmoLeft(10, 2), 'two of ten arrows shot');
  TestKit.CheckEqualsL(0, CbtActs.AmmoLeft(2, 2), 'the last two');
  TestKit.CheckEqualsL(0, CbtActs.AmmoLeft(1, 2), 'more shots than arrows leaves none, not 255');
  TestKit.CheckEqualsL(0, CbtActs.AmmoLeft(0, 1), 'a single thrown item is gone');

  { the wilderness feature classes }
  TestKit.CheckEqualsL($01, CombatSt.TerrainClass(1, False), 'terrain 1 is plain ground');
  TestKit.CheckEqualsL($01, CombatSt.TerrainClass(0, False), 'an unmatched terrain is plain ground');
  TestKit.CheckEqualsL($21, CombatSt.TerrainClass(168, False), 'terrain 168');
  TestKit.CheckEqualsL($11, CombatSt.TerrainClass(185, False), 'terrain 185');
  TestKit.CheckEqualsL($44, CombatSt.TerrainClass(93, False), 'terrain 93');
  TestKit.CheckEqualsL($80, CombatSt.TerrainClass(109, False), 'terrain 109 before Yarash');
  TestKit.CheckEqualsL($01, CombatSt.TerrainClass(109, True), 'and after: bit 7 collapses to bit 0');
  TestKit.CheckEqualsL($21, CombatSt.TerrainClass(225, True), 'terrain 225 after Yarash');
  TestKit.CheckEqualsL($11, CombatSt.TerrainClass(102, True), 'terrain 102 after Yarash');
  TestKit.CheckEqualsL($28, CombatSt.TerrainClass(126, True), 'a class without bit 7 is kept after Yarash');

  { who the aim reaches (#1137) }
  GetMem(GameVars.zone1, SizeOf(GameVars.zone1^));
  FillChar(GameVars.zone1^, SizeOf(GameVars.zone1^), 0);
  GameVars.effectFns[C_EFFECT.INVISIBLE] := Veto;
  att := NewCreature(0);
  ally := NewCreature(0);
  foe := NewCreature(1);
  hidden := NewCreature(1);
  FxEngine.AddEffect(hidden, C_EFFECT.INVISIBLE, 0, 0, False);
  TestKit.Check(CbtActs.CanTarget(att, att, False), 'CanTarget: the attacker may always aim at itself');
  TestKit.Check(not CbtActs.CanTarget(att, ally, False), 'not at an ally without allowAlly');
  TestKit.Check(CbtActs.CanTarget(att, ally, True), 'at an ally with it');
  TestKit.Check(CbtActs.CanTarget(att, foe, False), 'at an enemy either way');
  TestKit.Check(not CbtActs.CanTarget(att, hidden, True), 'not at an invisible enemy');
  TestKit.Check(not CbtActs.CanTarget(att, nil, True), 'nor at nothing');
  GameVars.aimEnemiesOn := 1;
  TestKit.Check(CbtActs.AimCycles(att, att, False) and CbtActs.AimCycles(att, att, True),
                'Aim Cycles ENEMIES: Next and Prev reach the attacker itself');
  TestKit.Check(CbtActs.AimCycles(att, foe, False), 'a weapon''s aim reaches an enemy');
  TestKit.Check(not CbtActs.AimCycles(att, ally, False), 'and not an ally');
  TestKit.Check(not CbtActs.AimCycles(att, hidden, False), 'nor an enemy it cannot target');
  TestKit.Check(CbtActs.AimCycles(att, ally, True), 'a spell that is not offensive reaches an ally');
  TestKit.Check(not CbtActs.AimCycles(att, foe, True), 'and not an enemy');
  TestKit.Check(CbtActs.AimCycles(hidden, foe, True), 'a monster''s own side is its allies');
  GameVars.aimEnemiesOn := 0;
  TestKit.Check(CbtActs.AimCycles(att, ally, False) and CbtActs.AimCycles(att, foe, False),
                'Aim Cycles ALL: a weapon''s aim reaches allies and enemies, as SSI''s did');
  TestKit.Check(CbtActs.AimCycles(att, foe, True), 'and so does a cure''s');
  TestKit.Check(not CbtActs.AimCycles(att, hidden, False), 'but not one it cannot target');

  { a thrown weapon back to its thrower (#1118) }
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  CharHlp.baseItems^[C_ITEM.HAND_AXE].slot := C_EQUIP.WEAPON;
  CharHlp.baseItems^[C_ITEM.HAND_AXE].hands := 1;
  CharHlp.baseItems^[C_ITEM.HAND_AXE].classMask := $FF;
  CharHlp.baseItems^[C_ITEM.HAND_AXE].props := C_ITEM.PROP_THROWN;
  FillChar(axe, SizeOf(axe), 0);
  axe.itemType := C_ITEM.HAND_AXE;
  axe.nameIds[3] := 1;
  GameVars.treasureItems := nil;
  CbtActs.thrownCount := 0;
  Throw(att);
  Throw(foe);
  TestKit.CheckEqualsL(1, CbtActs.thrownCount, 'NoteThrown notes a party member''s throw, not a monster''s');
  TestKit.Check(CbtActs.ReturnThrown(1, thrower, back, name), 'the thrower takes the axe back');
  TestKit.Check(thrower = att, 'the one who threw it');
  TestKit.Check((att^.itemsAddr <> nil) and (att^.itemsAddr = back), 'it is in its items');
  TestKit.Check((back <> nil) and (back^.equipped <> 0), 'readied, the weapon hand being empty');
  TestKit.Check(att^.equipped[C_EQUIP.WEAPON] = back, 'in the weapon hand');
  TestKit.CheckEqualsL(1, LootCount, 'and gone from the loot, the monster''s left');
  TestKit.Check(not CbtActs.ReturnThrown(1, thrower, back, name), 'it is not handed back twice');
  { a second axe, the hand full }
  Throw(att);
  TestKit.Check(CbtActs.ReturnThrown(2, thrower, back, name), 'a second throw comes back');
  TestKit.Check((back <> nil) and (back^.equipped = 0), 'not readied, the hand being full');
  TestKit.CheckEqualsL(1, LootCount, 'the loot keeps the monster''s');
  { a thrower who has left the party }
  Throw(ally);
  GameVars.creatureList := GameVars.creatureList^.nextCharAddr^.nextCharAddr^.nextCharAddr;
  TestKit.Check(GameVars.creatureList = att, 'the ally and the monsters are off the list');
  TestKit.Check(not CbtActs.ReturnThrown(3, thrower, back, name), 'a thrower no longer in the party gets nothing');
  TestKit.CheckEqualsL(2, LootCount, 'and the axe stays in the loot');
  { a thrower carrying all it can }
  while att^.itemsAddr <> nil do
    CharHlp.RemoveItem(att, att^.itemsAddr);
  for i := 1 to C_ITEM.CARRY_MAX do
    CharHlp.AppendItemCopy(att^.itemsAddr, @axe);
  Throw(att);
  TestKit.Check(not CbtActs.ReturnThrown(4, thrower, back, name), 'a thrower who cannot carry it gets nothing');
  TestKit.CheckEqualsL(3, LootCount, 'and the axe stays in the loot');

  TestKit.Done;
end.
