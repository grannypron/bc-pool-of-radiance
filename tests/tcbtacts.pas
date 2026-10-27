{ Tests for the combat core's rules that need no screen: the move and aim menus' cursor keys (CbtActs.DirOfKey), a
  blow's damage with a backstab and a ranger's bonus (CbtActs.WeaponDamage), the missiles a volley leaves
  (CbtActs.AmmoLeft) and the wilderness arena's feature classes (CombatSt.TerrainClass). }
{$I COMPILER.INC}
program TCbtActs;

uses C_DIR, C_KEYS, CbtActs, CombatSt, TestKit;

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

  TestKit.Done;
end.
