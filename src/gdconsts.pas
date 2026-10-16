{ Initialized data: every typed constant in the data segment, in link order. A new section starts wherever the data
  needs a word boundary. }
unit GDConsts;

interface

uses C_Gender, C_Class, C_Level, C_Money, Types, Crt, C_Effect, C_Dir, C_Race, C_Status, C_Align, C_Gbvm, C_Abil;

{ BUILD_VERSION and BUILD_COMMIT: build.sh writes them from git before each build. }
{$I ..\OBJ\BUILDID.INC}

const
  GAME_VERSION: String[40] = BUILD_VERSION + ' (BC)';

const
  { CureDisease }
  cureDiseaseEffects: array[1..6] of Byte = (
    C_Effect.HELPLESS, C_Effect.DISEASED, C_Effect.DISEASE_STR, C_Effect.DISEASE_HP,
        C_Effect.ROT_NO_HEAL, C_Effect.MUMMY_ROT);
  { HealMenu }
  templeSpells: array[1..10] of String[40] = (
    'Cure Blindness',
    'Cure Disease',
    'Cure Light Wounds',
    'Cure Serious Wounds',
    'Cure Critical Wounds',
    'Neutralize Poison',
    'Raise Dead',
    'Remove Curse',
    'Stone to Flesh',
    'Exit');
  { AI step patterns (aiStance 1..6): five direction offsets tried in order, each added to the base direction mod 8 (8 =
    straight ahead, 1/7 = one step clockwise/counterclockwise, 2/6 = two, 3/5 = three, 4 = reverse). Patterns 1..4 are
    kept on three turns out of four; sweep patterns 5..6 are rerolled every turn. }
  aiDirOffsets: array[1..6, 1..5] of Byte = (
    ( 8, 7, 6, 1, 2),
    ( 8, 1, 2, 7, 6),
    ( 7, 1, 8, 6, 2),
    ( 1, 7, 8, 2, 6),
    ( 8, 7, 6, 5, 4),
    ( 8, 1, 2, 3, 4));
  { Combat placement tables }
  ringDirTbl: array[0..3, 0..3] of Byte = (
    ( 8, 4, 6, 2),
    ( 8, 6, 4, 0),
    ( 8, 0, 6, 2),
    ( 8, 2, 0, 4));
  ringStart: array[0..3, 0..3] of Byte = (
    ( 0, 0, 2, 6),
    ( 2, 2, 0, 4),
    ( 4, 4, 2, 6),
    ( 6, 6, 4, 0));
  quadDir: array[0..3] of Byte = (
     7, 2, 3, 6);
  startQX: array[Boolean, 0..3] of ShortInt = (
    ( 5, 4, 5, 6),
    ( 3, 8, 7, 2));
  startQY: array[Boolean, 0..3] of ShortInt = (
    ( 3, 2, 2, 3),
    ( 0, 2, 5, 3));
  { [d, quad row]: the free quad-column range lo..hi; lo > hi closes the row }
  rowBand: array[0..4, 0..5] of Types.TBandRec = (
    ((lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)),
    ((lo: 0; hi: 2), (lo: 0; hi: 3), (lo: 1; hi: 4), (lo: 2; hi: 5), (lo: 3; hi: 6), (lo: 4; hi: 7)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0)),
    ((lo: 3; hi: 6), (lo: 4; hi: 7), (lo: 5; hi: 8), (lo: 6; hi: 9), (lo: 7; hi: 10), (lo: 8; hi: 10)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)));
  { Favoured enemies }
  gnomeFoes: array[1..5] of Types.TName15 = (
    'KOBOLD', 'KOBOLD LEADER', 'GOBLIN', 'GOBLIN LEADER', 'GOBLIN GUARD');
  dwarfFoes: array[1..11] of Types.TName15 = (
    'ORC', 'ORC LEADER', 'GOBLIN', 'GOBLIN LEADER',
    'HOBGOBLIN', 'HOBGOBLIN CHIEF', 'GAGOOL', 'MACE',
    'GOBLIN GUARD', 'HOBGOBLIN LDR', 'GRISHNAK');
  giantFoes: array[1..5] of Types.TName15 = (
    'OGRE', 'OGRE LEADER', 'TROLL', 'FIRE GIANT', 'HILL GIANT');
  { The giant class a ranger does extra damage to in melee: the game's monster names for kobolds, goblins, orcs,
    hobgoblins, gnolls, bugbears, ettins, ogres, trolls and giants }
  rangerFoes: array[1..16] of Types.TName15 = (
    'KOBOLD', 'KOBOLD LEADER', 'GOBLIN GUARD', 'GOBLIN LEADER', 'ORC', 'ORC LEADER', 'HOBGOBLIN', 'HOBGOBLIN LDR',
    'GNOLL', 'BUGBEAR', 'ETTIN', 'OGRE', 'OGRE LEADER', 'TROLL', 'HILL GIANT', 'FIRE GIANT');
  { Turning undead }
    { Turning table by undead level (row) and cleric level (column: levels 1..8 one each, then 9..13, then 14+). Roll
      d20 >= Abs(value): positive values turn, zero or negative values destroy. 1 turns automatically, 0 destroys
      automatically, and 99 is immune. A negative result extends exhausted attempts until six successes. An undead
      level above 10 (CbtActs.FindTurnUndeadTarget admits up to 12) is read from row 10. }
  turnTable: Types.TTurnUndeadTable = (
    { 1: Skeleton }
    (10, 7, 4, 1, 1, 0, 0, -1, -1, -1),
    { 2: Zombie }
    (13, 10, 7, 1, 1, 0, 0, 0, -1, -1),
    { 3: Ghoul }
    (16, 13, 10, 4, 1, 1, 0, 0, 0, -1),
    (19, 16, 13, 7, 4, 1, 1, 0, 0, -1),
    { 5: Wight }
    (20, 19, 16, 10, 7, 4, 1, 1, 0, 0),
    { 6: Ghast }
    (99, 20, 19, 13, 10, 7, 4, 1, 1, 0),
    { 7: Wraith }
    (99, 99, 20, 16, 13, 10, 7, 4, 1, 0),
    { 8: Mummy }
    (99, 99, 99, 20, 16, 13, 10, 7, 4, 1),
    { 9: Spectre }
    (99, 99, 99, 99, 20, 16, 13, 10, 7, 1),
    { 10: Vampire }
    (99, 99, 99, 99, 99, 20, 16, 13, 10, 4));
  { Movement menus }
  { 3D exploration menu }
  menu3D: String[40] = 'Area Cast View Encamp Search Look Jrnl';
  { wilderness exploration menu }
  menuWild: String[40] = 'Cast View Encamp Search Look Jrnl';
  { Camp menus }
  { camp actions }
  campMenu: String[40] = 'Save View Magic Rest Alter Fix Exit';
  { magic actions }
  magicMenu: String[40] = 'Cast Memorize Scribe Display Rest Exit';
  { Char (the character's icon or portrait) took Icon's place: the bottom line has no room for a seventh choice.
    Settings (S, free since Speed left for it) holds the game speed with the other settings. }
  alterMenu: String[40] = 'Order Drop Char Settings Exit';

const
  { CampOrderMenu }
  orderMenus: array[0..1] of String[40] = ('Select Exit', 'Place Exit');
  { TCharRecord.itemLimits usability bit for each class-level slot (C_Level). The ranger shares the paladin's bit: the
    item data gives it to the fighter's weapons and armor, and no item type carries 1 shl 7. }
  usabilityBit: array[C_Level.CLERIC..C_Level.MONK] of Byte = (
    1 shl 1, 1 shl 4, 1 shl 3, 1 shl 6, 1 shl 6, 1 shl 0, 1 shl 2, 1 shl 5);
  { Training-hall class bits (C_Gbvm.TRAIN_CLASS_MASK) by class slot; only entries 0..7 are read. Paladins and rangers
    train with fighters; the monk combines two bits. }
  classBit: array[0..16] of Byte = (
    2, 2, 8, 8, 8, 1, 4, 6, 16, 16, 16, 32, 32, 32, 64, 64, 64);

const
  { MainMenu }
  menuKeys: String[40] = 'C D M T V A R L S B G E J';
  { initial empty-roster state }
  menuItems: array[0..11] of Types.TMenuItem = (
    (name: 'Create New Character'; enabled: 1),
    (name: 'Drop Character'; enabled: 0),
    (name: 'Modify Character'; enabled: 0),
    (name: 'Train Character'; enabled: 0),
    (name: 'View Character'; enabled: 0),
    (name: 'Add Character to Party'; enabled: 1),
    (name: 'Remove Character from Party'; enabled: 0),
    (name: 'Load Saved Game'; enabled: 1),
    (name: 'Save Current Game'; enabled: 0),
    (name: 'BEGIN Adventuring'; enabled: 0),
    (name: 'Game Settings'; enabled: 1),
    (name: 'Exit to DOS'; enabled: 1));

const
  { RollFirstLevelHp }
  { dice per class, used by creation and training }
  hpDice: array[0..7] of Byte = (
    { Cleric: 1d8 }
    1,
    { Druid: 1d8 }
    1,
    { Fighter: 1d10 }
    1,
    { Paladin: 1d10 }
    1,
    { Ranger: 2d8 }
    2,
    { Magic-User: 1d4 }
    1,
    { Thief: 1d6 }
    1,
    { Monk: 2d4 }
    2);
  { hit-die sides per class }
  hpSides: array[0..7] of Byte = (
     { Cleric: d8 }
     8,
     { Druid: d8 }
     8,
    { Fighter: d10 }
    10,
    { Paladin: d10 }
    10,
     { Ranger: d8 }
     8,
     { Magic-User: d4 }
     4,
     { Thief: d6 }
     6,
     { Monk: d4 }
     4);
  { LoadCharIconAnim }
  { CHEAD/CBODY filename suffix indexed by iconSize: S for 1 (dwarf, gnome, halfling), T for 2 (tall races) }
  iconHeightSuffix: array[1..2] of Char = (
    'S',
    'T');
  { AddCreatureToParty }
  { portrait-head selectors indexed by gender (male, female) and a 1d8 roll }
  npcPortraitHeads: array[0..1, 1..8] of Byte = (
    (1, 2, 3, 4, 5, 8, 11, 12),
    (6, 7, 9, 10, 13, 14, 6, 7));
  { cleric portrait-body selectors indexed by gender (male, female) and a 1d5 roll }
  npcClericBodies: array[0..1, 1..5] of Byte = (
    (2, 4, 2, 4, 2),
    (2, 4, 8, 2, 4));
  { fighter portrait-body selectors, also the fallback for classes other than cleric, magic-user and thief; indexed by
    gender (male, female) and a 1d5 roll }
  npcFighterBodies: array[0..1, 1..5] of Byte = (
    (1, 3, 4, 5, 6),
    (7, 9, 11, 7, 9));
  { magic-user portrait-body selectors indexed by gender (male, female) and a 1d5 roll }
  npcMageBodies: array[0..1, 1..5] of Byte = (
    (2, 2, 2, 2, 2),
    (8, 10, 12, 8, 10));
  { thief portrait-body selectors indexed by gender (male, female) and a 1d5 roll }
  npcThiefBodies: array[0..1, 1..5] of Byte = (
    (6, 6, 6, 6, 6),
    (8, 10, 8, 10, 8));
  { YarashComplete }
  { Wilderness tiles remapped Black to Blue and LightGray to Green. Bit 7 selects the second tile set (ds2dMapTilePtr2),
    the low 7 bits the frame. }
  yarBlueGreenTiles: array[0..10] of Byte = (
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    113,
    128 + 96,
    128 + 97,
    128 + 98);
  { Wilderness tiles remapped LightGray to Green. Bit 7 selects the second tile set, the low 7 bits the frame. }
  yarGreenTiles: array[0..17] of Byte = (
    86,
    87,
    88,
    89,
    108,
    109,
    110,
    111,
    112,
    114,
    115,
    116,
    117,
    118,
    119,
    128 + 95,
    128 + 115,
    128 + 117);
  { Source side of both remaps: every color, in palette order. }
  yarRemapFrom: Types.TColorTab = (
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGray,
    DarkGray,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    Yellow,
    White);
  yarBlueGreenTo: Types.TColorTab = (
    { Black -> Blue }
    Blue,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> Green }
    Green,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> LightMagenta }
    LightMagenta,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  yarGreenTo: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> Green }
    Green,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> LightMagenta }
    LightMagenta,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  { Wilderness viewport left column for each animation step }
  yarViewX: array[0..8] of Word = (
    17,
    17,
    17,
    19,
    19,
    19,
    23,
    23,
    23);
  { Wilderness viewport top row for each animation step }
  yarViewY: array[0..8] of Word = (
    15,
    15,
    15,
    20,
    20,
    20,
    25,
    25,
    25);

const
  { Random item templates }
  randomItemTemplates: array[1..19] of Types.TRandomItemTemplate = (
    { Template 1: Potion of Extra Healing }
    (nameIds: (187, 167, 64); weight: 1; value: 800;
     properties: (3, 3, 0)),
    { Template 2: Potion of Giant Strength }
    (nameIds: (239, 167, 64); weight: 1; value: 1100;
     properties: (1, 82, 0)),
    { Template 3: Potion of Healing }
    (nameIds: (185, 167, 64); weight: 1; value: 400;
     properties: (1, 85, 0)),
    { Template 4: Potion of Speed }
    (nameIds: (173, 167, 64); weight: 1; value: 450;
     properties: (1, 80, 0)),
    { Template 5: Scroll of Restoring Levels }
    (nameIds: (240, 167, 65); weight: 1; value: 2100;
     properties: (56, 56, 0)),
    { Template 6: Ring of Feather Falling }
    (nameIds: (238, 167, 66); weight: 1; value: 5000;
     properties: (0, 27, 128)),
    { Template 7: Wand of Lightning }
    (nameIds: (157, 167, 69); weight: 1; value: 6000;
     properties: (20, 51, 0)),
    { Template 8: Wand of Magic Missiles }
    (nameIds: (206, 167, 69); weight: 1; value: 11000;
     properties: (30, 88, 0)),
    { Template 9: Wand of Paralyzation }
    (nameIds: (225, 167, 69); weight: 1; value: 5000;
     properties: (20, 84, 0)),
    { Template 10: Gauntlets of Ogre Power }
    (nameIds: (226, 167, 100); weight: 10; value: 15000;
     properties: (0, 38, 131)),
    { Template 11: Keoghtum's Ointment }
    (nameIds: (0, 111, 182); weight: 1; value: 10000;
     properties: (5, 81, 0)),
    { Template 12: Necklace of Missiles }
    (nameIds: (228, 167, 119); weight: 1; value: 16000;
     properties: (20, 87, 0)),
    { Template 13: Cloak of Displacement }
    (nameIds: (170, 167, 88); weight: 25; value: 17500;
     properties: (0, 89, 133)),
    { Template 14: Javelin of Lightning }
    (nameIds: (157, 167, 21); weight: 20; value: 3000;
     properties: (1, 83, 0)),
    { Template 15: Wand of Fireballs }
    (nameIds: (242, 167, 69); weight: 1; value: 5000;
     properties: (20, 47, 0)),
    { Template 16: Ring of Fire Resistance }
    (nameIds: (205, 167, 66); weight: 1; value: 5000;
     properties: (0, 61, 129)),
    { Template 17: Ring of Invisibility }
    (nameIds: (227, 167, 66); weight: 1; value: 7500;
     properties: (0, 56, 139)),
    { Template 18: Bag of Holding }
    (nameIds: (186, 167, 73); weight: 150; value: 25000;
     properties: (0, 0, 0)),
    { Template 19: Cloak of Elvenkind }
    (nameIds: (229, 167, 88); weight: 25; value: 6000;
     properties: (0, 72, 134)));
  { AddSpellToList }
  { Spell-list headings indexed by spell level }
  spellLevelNames: array[1..9] of String[40] = (
    '1st Level',
    '2nd Level',
    '3rd Level',
    '4th Level',
    '5th Level',
    '6th Level',
    '7th Level',
    '8th Level',
    '9th Level');

const
  { Effects removed by RemoveEffectsHp0 when a creature reaches zero hit points or is put out of play }
  hpZeroEffects: array[1..16] of Byte = (
    { Training/Manual }
    C_Effect.TRAIN_MANUAL,
    { Charm }
    C_Effect.CHARM,
    { Stinking cloud coughing }
    C_Effect.STINK_COUGH,
    { Helpless (nausea) }
    C_Effect.HELPLESS,
    { Animate Dead }
    C_Effect.ANIMATE_DEAD,
    { Snake Charm }
    C_Effect.SNAKE_CHARM,
    { Paralysis (Hold Person) }
    C_Effect.PARALYSIS,
    { Sleep }
    C_Effect.SLEEP,
    { Dragon Aura }
    C_Effect.DRAGON_AURA,
    { Immobile }
    C_Effect.IMMOBILE,
    { Troll Regeneration }
    C_Effect.TROLL_REGEN,
    { Fight On at 0 HP }
    C_Effect.FIGHT_ON,
    { Regeneration }
    C_Effect.REGEN3,
    { Spiritual Hammer expiry }
    C_Effect.SPIRIT_HAMMER_GONE,
    { Bite-and-Hold }
    C_Effect.BITE_HOLD,
    { Blood Drain }
    C_Effect.BLOOD_DRAIN);
  { Effects removed by RemoveAiEffects at the start of CombatAi.CheckMorale }
  aiRoundRemoveEffects: array[1..2] of Byte = (
    { Bite-and-Hold }
    C_Effect.BITE_HOLD,
    { Blood Drain }
    C_Effect.BLOOD_DRAIN);
  { DisplayMapView }
  { Display color for each zone sky/ceiling selector; selectors 8..15 repeat 0..7. }
  skyCeilingColors: array[0..15] of Byte = (
    Black,
    White,
    LightRed,
    LightCyan,
    LightMagenta,
    LightGreen,
    LightBlue,
    Yellow,
    Black,
    White,
    LightRed,
    LightCyan,
    LightMagenta,
    LightGreen,
    LightBlue,
    Yellow);
  { BuildWildernessMap }
  { Special-location overrides on the 44x36 wilderness map, indexed by the WILD_* constants. Entries 1 and 2 have no
    case arm below, so their icons are never applied. x/y are map cells; icon is a 1-based tile id. }
  wildernessSpecialLocations: array[1..9] of Types.TSpecLoc = (
    { 1 WILD_SILVER_DRAGON_DEN }
    (x: 10; y: 9; icon: 240),
    { 2 WILD_ZHENTIL_OUTPOST }
    (x: 3; y: 32; icon: 2),
    { 3 WILD_BUCCANEERS_BASE }
    (x: 12; y: 31; icon: 2),
    { 4 WILD_NOMAD_CAMP }
    (x: 25; y: 11; icon: 1),
    { 5 WILD_KOBOLD_CAVES }
    (x: 32; y: 15; icon: 165),
    { 6 WILD_UNNAMED_SITE }
    (x: 33; y: 23; icon: 157),
    { 7 WILD_LIZARD_MAN_KEEP }
    (x: 37; y: 8; icon: 147),
    { 8 WILD_SORCERERS_ISLAND }
    (x: 19; y: 16; icon: 247),
    { 9 WILD_PHLAN }
    (x: 25; y: 27; icon: 256));
  { LoadAnimation }
  { Sprite color remaps used when LoadAnimation's transp argument is odd (not under CGA). }
  animRemapFrom: Types.TColorTab = (
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGray,
    DarkGray,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    Yellow,
    White);
  animRemapTo: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> LightGray }
    LightGray,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> Black }
    Black,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  { Dungeon view geometry }
  viewSlotGeom: Types.TViewSlotGeom = (
    { First cell in a 156-cell WALLDEF slice }
    start: (0, 2, 6, 10, 22, 38, 54, 110, 132, 154);
    { Rectangle width in symbol cells }
    cols: (1, 1, 1, 3, 2, 2, 7, 2, 2, 1);
    { Rectangle height in symbol cells }
    rows: (2, 4, 4, 4, 8, 8, 8, 11, 11, 2);
    { Base column inside the 11-column view }
    xCol: (5, 4, 6, 4, 2, 7, 2, 0, 9, 5);
    { Base row inside the 11-row view }
    yRow: (4, 3, 3, 3, 1, 1, 1, 0, 0, 4));
  { LoadIconAnim: the identity table is the source side of both remaps, which turn LightMagenta into DarkGray or
    Black. }
  iconColorIdentity: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> LightGray }
    LightGray,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> LightMagenta }
    LightMagenta,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  iconColorPinkToDarkGray: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> LightGray }
    LightGray,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> DarkGray }
    DarkGray,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  iconColorPinkToBlack: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> LightGray }
    LightGray,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> Black }
    Black,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
  { Solid fill bytes for FillPicRect. Packed fill byte for each mapped CGA color (0..3), indexed by SrcNibble(color,
    map): four identical 2-bit pixels. }
  cgaColorFill: array[0..3] of Byte = ($00, $55, $AA, $FF);
  { Packed fill byte for each Tandy color, 0..15 (Black through White): two identical 4-bit pixels. }
  tandyColorFill: array[0..15] of Byte = (
    $00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $AA, $BB, $CC, $DD, $EE, $FF);
  { DisplayMessageWindow }
  { Word-wrap punctuation; space is tested separately }
  breakChars: Types.TBrkSet = ['!', ',', '-', '.', ':', ';', '?'];
  { SanitizeFileName }
  invalidFileChars: array[1..10] of Char = (
    { space }
    ' ',
    { period }
    '.',
    { asterisk }
    '*',
    { comma }
    ',',
    { question mark }
    '?',
    { slash }
    '/',
    { backslash }
    '\',
    { colon }
    ':',
    { semicolon }
    ';',
    { vertical bar }
    '|');
  { Character, money and item name strings; compass names }
  { Coin values in copper: copper 1, silver 10, electrum 100, gold 200, platinum 1000. }
  dsCoinValuationCopper: array[C_Money.COPPER..C_Money.PLATINUM] of LongInt = (
    1, 10, 100, 200, 1000);
  { Class names, indexed by TCharRecord.charClass. }
  classNames: array[C_Class.CLERIC..C_Class.MAGE_THIEF] of string[26] = (
    'Cleric',
    'Druid',
    'Fighter',
    'Paladin',
    'Ranger',
    'Magic-User',
    'Thief',
    'Monk',
    'Cleric/Fighter',
    'Cleric/Fighter/Magic-User',
    'Cleric/Ranger',
    'Cleric/Magic-User',
    'Cleric/Thief',
    'Fighter/Magic-User',
    'Fighter/Thief',
    'Fighter/Magic-User/Thief',
    'Magic-User/Thief');
  { Race names, indexed by TCharRecord.race. }
  raceNames: array[C_Race.MONSTER..C_Race.HUMAN] of string[9] = (
    'Monster',
    'Dwarf',
    'Elf',
    'Gnome',
    'Half-Elf',
    'Halfling',
    'Half-Orc',
    'Human');
  { Alignment names, indexed by TCharRecord.alignment. }
  alignNames: array[C_Align.LAWFUL_GOOD..C_Align.CHAOTIC_EVIL] of string[16] = (
    'Lawful Good',
    'Lawful Neutral',
    'Lawful Evil',
    'Neutral Good',
    'True Neutral',
    'Neutral Evil',
    'Chaotic Good',
    'Chaotic Neutral',
    'Chaotic Evil');
  { Gender names, indexed by TCharRecord.gender. }
  genderNames: array[C_Gender.MALE..C_Gender.FEMALE] of string[6] = (
    'Male',
    'Female');
  { Money names, indexed like TCharRecord.coins and TMoney. }
  moneyNames: array[C_Money.COPPER..C_Money.JEWELRY] of string[10] = (
    'Copper',
    'Silver',
    'Electrum',
    'Gold',
    'Platinum',
    'Gems',
    'Jewelry');
  { Status names, indexed by TCharRecord.status; see the STATUS_ constants. }
  statusStrs: array[C_Status.OKAY..C_Status.GONE] of string[12] = (
    'Okay',
    'Animated',
    'tempgone',
    'Running',
    'Unconscious',
    'Dying',
    'Dead',
    'Stoned',
    'Gone');
  { Item name components, indexed 1..255 by TItemRec.nameIds; a zero name ID adds no component. }
  nameParts: array[1..255] of string[20] = (
    'Battle Axe',
    'Hand Axe',
    'Bardiche',
    'Bec De Corbin',
    'Bill-Guisarme',
    'Bo Stick',
    'Club',
    'Dagger',
    'Dart',
    'Fauchard',
    'Fauchard-Fork',
    'Flail',
    'Military Fork',
    'Glaive',
    'Glaive-Guisarme',
    'Guisarme',
    'Guisarme-Voulge',
    'Halberd',
    'Lucern Hammer',
    'Hammer',
    'Javelin',
    'Jo Stick',
    'Mace',
    'Morning Star',
    'Partisan',
    'Military Pick',
    'Awl Pike',
    'Quarrel',
    'Ranseur',
    'Scimitar',
    'Spear',
    'Spetum',
    'Quarter Staff',
    'Bastard Sword',
    'Broad Sword',
    'Long Sword',
    'Short Sword',
    'Two-Handed Sword',
    'Trident',
    'Voulge',
    'Composite Long Bow',
    'Composite Short Bow',
    'Long Bow',
    'Short Bow',
    'Heavy Crossbow',
    'Light Crossbow',
    'Sling',
    'Mail',
    'Armor',
    'Leather',
    'Padded',
    'Studded',
    'Ring',
    'Scale',
    'Chain',
    'Splint',
    'Banded',
    'Plate',
    'Shield',
    'Woods',
    'Arrow',
    '',
    '',
    'Potion',
    'Scroll',
    'Ring',
    'Rod',
    'Stave',
    'Wand',
    'Jug',
    'Amulet',
    'Apparatus',
    'Bag',
    'Beaker',
    'Boat',
    'Book',
    'Boots',
    'Bowl',
    'Bracers',
    'Brazier',
    'Brooch',
    'Broom',
    'Purse',
    'Candle',
    'Carpet',
    'Censer',
    'Chime',
    'Cloak',
    'Crystal',
    'Cube',
    'Cubic',
    'Fortress',
    'Decanter',
    'Deck',
    'Drums',
    'Dust',
    'Eyes',
    'Figurine',
    'Flask',
    'Gauntlets',
    'Gem',
    'Girdle',
    'Helm',
    'Horn',
    'Horseshoes',
    'Incense',
    'Stone',
    'Instrument',
    'Javelin',
    'Jewel',
    'Ointment',
    'Libram',
    'Lyre',
    'Manual',
    'Mattock',
    'Maul',
    'Medallion',
    'Mirror',
    'Necklace',
    'Net',
    'Pigment',
    'Pearl',
    'Periapt',
    'Phylactery',
    'Pipes',
    'Hole',
    'Token',
    'Robe',
    'Rope',
    'Rug',
    'Saw',
    'Scarab',
    'Spade',
    'Sphere',
    '',
    'Talisman',
    'Tome',
    'Trident',
    'Grimoire',
    'Well',
    'Wings',
    'Vial',
    'Lantern',
    '',
    'Oil',
    '10 ft. Pole',
    '50 ft. Rope',
    'Iron',
    'Thf Prickly Tools',
    'Iron Rations',
    'Standard Rations',
    'Holy Symbol',
    'Holy Water vial',
    'Unholy Water vial',
    'Barding',
    'Dragon',
    'Lightning',
    'Saddle',
    'Small Raft',
    'Cart',
    'Wagon',
    '+1',
    '+2',
    '+3',
    '+4',
    '+5',
    'of',
    '',
    'Cloak',
    'Displacement',
    'Torches',
    'Oil',
    'Speed',
    'Tapestry',
    'Bodily Health',
    'Copper',
    'Silver',
    'Electrum',
    'Gold',
    'Platinum',
    'Ointment',
    'Keoghtum''s',
    'Sheet',
    'Strength',
    'Healing',
    'Holding',
    'Extra',
    'Gaseous Form',
    'Slipperiness',
    'Jewelled',
    'Flying',
    'Treasure Finding',
    'Fear',
    'Disappearance',
    'Statuette',
    'Fungus',
    'Chain',
    'Pendant',
    'Broach',
    'Of Seeking',
    '-1',
    '-2',
    '-3',
    'Lightning Bolt',
    'Fire Resistance',
    'Magic Missiles',
    'Save',
    'Clerical Scroll',
    'Magic User Scroll',
    'With 1 Spell',
    'With 2 Spells',
    'With 3 Spells',
    'Protection Scroll',
    'Jewelry',
    'Fine',
    'Huge',
    'Bone',
    'Brass',
    'Key',
    'AC 2',
    'AC 6',
    'AC 4',
    'AC 3',
    'Of Protection',
    'Paralyzation',
    'Ogre Power',
    'Invisibility',
    'Missiles',
    'Elvenkind',
    'Rotting',
    'Covered',
    'Efreeti',
    'Bottle',
    'Missile Attractor',
    'Of Maglubiyet',
    'Secr Door & Trap Det',
    'Gd Dragon Control',
    'Feather Falling',
    'Giant Strength',
    'Restoring Level(s)',
    'Flame Tongue',
    'Fireballs',
    'Spiritual',
    'Boulder',
    'Diamond',
    'Emerald',
    'Opal',
    'Saphire',
    'Of Tyr',
    'Of Tempus',
    'Of Sune',
    'Wooden',
    '+3 vs Undead',
    'Pass',
    'Cursed');

const
  { clockwise facing codes 0..7, starting at north }
  dirNames: array[C_Dir.NORTH..C_Dir.NORTHWEST] of string[2] = (
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW');
  { Text-mode colour and pixel tables; EGA plane and CGA pixel tables; icon colour map }
  { Direction code for a one-cell step, indexed [dy + 1, dx + 1]; the center entry (C_Dir.CENTER) means no movement. }
  dirByDelta: array[0..2, 0..2] of Byte = (
    (7, 0, 1),
    (6, 8, 2),
    (5, 4, 3));
  { EGA plane masks, highest plane first; TextRend reads [3 - k] for plane k }
  egaPlaneMask: array[0..3] of Byte = ($08, $04, $02, $01);
  { CGA colors 0..3 repeated across eight 2-bit pixels }
  cgaColorPat: array[0..3] of Word = (
    $0000, $5555, $AAAA, $FFFF);
  { EGA-to-CGA font color map. }
  attrTable: array[0..15] of Byte = (
    { EGA 0 Black -> CGA colour 0 }
    0,
    { EGA 1 Blue -> CGA colour 0 }
    0,
    { EGA 2 Green -> CGA colour 0 }
    0,
    { EGA 3 Cyan -> CGA colour 1 }
    1,
    { EGA 4 Red -> CGA colour 2 }
    2,
    { EGA 5 Magenta -> CGA colour 2 }
    2,
    { EGA 6 Brown -> CGA colour 2 }
    2,
    { EGA 7 LightGray -> CGA colour 3 }
    3,
    { EGA 8 DarkGray -> CGA colour 3 }
    3,
    { EGA 9 LightBlue -> CGA colour 1 }
    1,
    { EGA 10 LightGreen -> CGA colour 1 }
    1,
    { EGA 11 LightCyan -> CGA colour 1 }
    1,
    { EGA 12 LightRed -> CGA colour 2 }
    2,
    { EGA 13 LightMagenta -> CGA colour 2 }
    2,
    { EGA 14 Yellow -> CGA colour 3 }
    3,
    { EGA 15 White -> CGA colour 3 }
    3);
  { One mask per 2-bit pixel position within a CGA pixel word, high pair first. Blit uses them to isolate, place and
    reflect CGA pixels; TextRend.RenderChar uses them to draw characters. }
  cgaPixelMask: array[0..7] of Word = (
    $C000, $3000, $0C00, $0300, $00C0, $0030, $000C, $0003);

const
  { Color bit (1, 2, 4, 8) carried by each of the four EGA planes. Blit uses it to split a 4-bit color into plane bytes
    and to select planes through the sequencer map mask. }
  egaPlaneBit: array[0..3] of Byte = ($01, $02, $04, $08);
  { CGA color by pixel position within a packed byte. }
  cgaPixPos: array[0..3, 0..3] of Byte = (
    ($00, $00, $00, $00),
    ($40, $10, $04, $01),
    ($80, $20, $08, $02),
    ($C0, $30, $0C, $03));
  { Packed EGA-to-CGA color map, two EGA colors per byte, used by Blit.FillPicRect for the CharGen icon previews and the
    View3D backgrounds }
  dsIconColorMap: Types.TColorMap = (
    { EGA 0 Black -> CGA 0; EGA 1 Blue -> CGA 0 }
    $00,
    { EGA 2 Green -> CGA 1; EGA 3 Cyan -> CGA 1 }
    $11,
    { EGA 4 Red -> CGA 2; EGA 5 Magenta -> CGA 2 }
    $22,
    { EGA 6 Brown -> CGA 1; EGA 7 LightGray -> CGA 2 }
    $12,
    { EGA 8 DarkGray -> CGA 0; EGA 9 LightBlue -> CGA 0 }
    $00,
    { EGA 10 LightGreen -> CGA 2; EGA 11 LightCyan -> CGA 1 }
    $21,
    { EGA 12 LightRed -> CGA 3; EGA 13 LightMagenta -> CGA 0 }
    $30,
    { EGA 14 Yellow -> CGA 3; EGA 15 White -> CGA 3 }
    $33);
  { Sound command tables }
  { One table of sound command ids, a slice for each subsystem (C_Sound names the indexes). }
  soundIds: record
    commands: array[0..3] of Word;
    damage: Word;
    combat: array[0..10] of Word;
  end = (
    commands: (255, 0, 1, 2);
    damage: 3;
    combat: (4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14));
  { Insert-disk prompts, indexed by virtualDisk, which SaveLoad and the ECL keep in 1..LAST_DISK }
  insertDiskMsg: array[1..Types.LAST_DISK] of string[29] = (
    'Insert disk 1 in drive ',
    'Insert disk 2 in drive ',
    'Insert disk 3 in drive ',
    'Insert disk 4 in drive ',
    'Insert disk 5 in drive ',
    'Insert disk 6 in drive ',
    'Insert disk 7 in drive ',
    'Insert disk 8 in drive ');
  { Symbol-set ranges }
  symSetFirst: array[0..4] of Word = (1, 46, 116, 186, 256);
  symSetLast: array[0..4] of Word = (45, 115, 185, 255, 286);
  { Direction steps, combat terrain, icon footprints, helpless effects }
  dirDX: array[C_Dir.NORTH..C_Dir.CENTER] of ShortInt = (
    0, 1, 1, 1, 0, -1, -1, -1, 0);
  dirDY: array[C_Dir.NORTH..C_Dir.CENTER] of ShortInt = (
    -1, -1, 0, 1, 1, 1, 0, -1, 0);
  { Combat terrain by arena cell value: movement cost (255 = impassable), line-walk clearance and blocking, and the
    combat tile graphic }
  terrainInfo: array[1..65] of Types.TTerrainRec = (
    (cost: 255; clearance: 0; blocking: 2; tileId: 0),
    (cost: 255; clearance: 0; blocking: 2; tileId: 1),
    (cost: 255; clearance: 0; blocking: 2; tileId: 2),
    (cost: 255; clearance: 0; blocking: 2; tileId: 3),
    (cost: 1; clearance: 0; blocking: 0; tileId: 4),
    (cost: 255; clearance: 0; blocking: 2; tileId: 5),
    (cost: 255; clearance: 0; blocking: 2; tileId: 6),
    (cost: 255; clearance: 0; blocking: 2; tileId: 7),
    (cost: 1; clearance: 0; blocking: 0; tileId: 8),
    (cost: 255; clearance: 0; blocking: 2; tileId: 9),
    (cost: 1; clearance: 0; blocking: 0; tileId: 10),
    (cost: 255; clearance: 0; blocking: 2; tileId: 11),
    (cost: 1; clearance: 0; blocking: 0; tileId: 12),
    (cost: 255; clearance: 0; blocking: 2; tileId: 13),
    (cost: 1; clearance: 0; blocking: 0; tileId: 14),
    (cost: 255; clearance: 0; blocking: 2; tileId: 15),
    (cost: 1; clearance: 0; blocking: 0; tileId: 16),
    (cost: 255; clearance: 0; blocking: 2; tileId: 17),
    (cost: 255; clearance: 0; blocking: 2; tileId: 18),
    (cost: 255; clearance: 0; blocking: 2; tileId: 19),
    (cost: 255; clearance: 0; blocking: 2; tileId: 20),
    (cost: 255; clearance: 0; blocking: 2; tileId: 21),
    (cost: 1; clearance: 0; blocking: 0; tileId: 22),
    (cost: 1; clearance: 0; blocking: 0; tileId: 23),
    (cost: 255; clearance: 0; blocking: 2; tileId: 24),
    (cost: 1; clearance: 0; blocking: 0; tileId: 34),
    (cost: 1; clearance: 0; blocking: 0; tileId: 35),
    (cost: 1; clearance: 0; blocking: 0; tileId: 36),
    (cost: 1; clearance: 0; blocking: 0; tileId: 37),
    (cost: 1; clearance: 0; blocking: 0; tileId: 38),
    (cost: 1; clearance: 0; blocking: 0; tileId: 39),
    (cost: 255; clearance: 0; blocking: 2; tileId: 0),
    (cost: 255; clearance: 0; blocking: 2; tileId: 1),
    (cost: 255; clearance: 0; blocking: 2; tileId: 2),
    (cost: 255; clearance: 0; blocking: 2; tileId: 3),
    (cost: 1; clearance: 0; blocking: 0; tileId: 4),
    (cost: 1; clearance: 0; blocking: 0; tileId: 5),
    (cost: 1; clearance: 0; blocking: 0; tileId: 6),
    (cost: 1; clearance: 0; blocking: 0; tileId: 7),
    (cost: 255; clearance: 0; blocking: 0; tileId: 8),
    (cost: 255; clearance: 0; blocking: 0; tileId: 9),
    (cost: 1; clearance: 0; blocking: 0; tileId: 10),
    (cost: 1; clearance: 0; blocking: 0; tileId: 11),
    (cost: 1; clearance: 0; blocking: 0; tileId: 12),
    (cost: 1; clearance: 0; blocking: 0; tileId: 13),
    (cost: 1; clearance: 0; blocking: 0; tileId: 14),
    (cost: 1; clearance: 0; blocking: 0; tileId: 15),
    (cost: 1; clearance: 0; blocking: 0; tileId: 16),
    (cost: 1; clearance: 0; blocking: 0; tileId: 17),
    (cost: 255; clearance: 0; blocking: 0; tileId: 18),
    (cost: 255; clearance: 0; blocking: 0; tileId: 19),
    (cost: 1; clearance: 0; blocking: 0; tileId: 20),
    (cost: 1; clearance: 0; blocking: 0; tileId: 21),
    (cost: 1; clearance: 0; blocking: 0; tileId: 22),
    (cost: 255; clearance: 0; blocking: 0; tileId: 23),
    (cost: 255; clearance: 0; blocking: 0; tileId: 24),
    (cost: 1; clearance: 0; blocking: 0; tileId: 25),
    (cost: 1; clearance: 0; blocking: 0; tileId: 26),
    (cost: 1; clearance: 0; blocking: 0; tileId: 27),
    (cost: 255; clearance: 0; blocking: 0; tileId: 28),
    (cost: 255; clearance: 0; blocking: 2; tileId: 29),
    (cost: 255; clearance: 0; blocking: 2; tileId: 30),
    (cost: 255; clearance: 0; blocking: 2; tileId: 31),
    (cost: 1; clearance: 0; blocking: 0; tileId: 32),
    (cost: 255; clearance: 0; blocking: 2; tileId: 33));
  { Footprint cells of an icon, by icon size and cell; a negative dx marks an absent cell }
  iconDelta: array[1..4, 0..3] of Types.TIconCoordinateDelta = (
    ((dx:  0; dy:  0), (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx:  0; dy:  0), (dx:  0; dy:  1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx:  0; dy:  0), (dx:  1; dy:  0), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx:  0; dy:  0), (dx:  1; dy:  0), (dx:  0; dy:  1), (dx:  1; dy:  1)));
  { Effects that leave a creature helpless: Snake Charm, Paralysis, Sleep, Helpless }
  helplessFx: array[1..4] of Byte = (51, 52, 53, 31);
  { Portrait head and body tables }
  { portraitHead -> HEAD DAX ID: SSI's 14 player heads, then the other heads HEAD3.DAX holds, then the heads only the
    other disks hold. New heads go at the end so the numbers saved characters carry keep their faces. }
  headTbl: array[1..41] of Byte = (
     0,  8,  9, 13, 16, 18, 22, 
    34, 45, 51, 53, 57, 67, 68,
    24, 32, 42, 44, 55, 63, 71,
     1,  3,  5,  6, 10, 11, 12, 
    14, 25, 48, 52, 54, 56, 59, 
    61, 62, 69, 70, 72, 74
  );
  { portraitBody -> BODY DAX ID, extended the same way }
  bodyTbl: array[1..21] of Byte = (
     1,  2,  3,  4,  7,  8, 18, 
    24, 26, 33, 35, 37,  9, 31, 
    32, 34,  5,  6, 13, 25, 30
  );
  { how many of the first headTbl and bodyTbl entries HEAD3.DAX and BODY3.DAX hold }
  DISK3_HEADS = 21;
  DISK3_BODIES = 16;
  { unused }
  dsUnidentified14: array[0..1] of Byte = (
    0, 1);
  { Menu key and aim-vector tables }
  { keypad digits 1..9 to scan codes; MenuCore indexes Ord(ch) - Ord('1') }
  keypadScan: array[0..8] of Byte = (
    79, 80, 81, 75, 32, 77, 71, 72, 73);
  { Arrow-key scan code (72 up, 75 left, 77 right, 80 down) for an aim vector, rows Y, columns X; unused }
  vectorScan: array[-5..5, -5..5] of Byte = (
    (72, 72, 72, 72, 72, 72, 72, 72, 72, 72, 72),
    (75, 72, 72, 72, 72, 72, 72, 72, 72, 72, 77),
    (75, 75, 72, 72, 72, 72, 72, 72, 72, 77, 77),
    (75, 75, 75, 72, 72, 72, 72, 72, 77, 77, 77),
    (75, 75, 75, 75, 72, 72, 72, 77, 77, 77, 77),
    (75, 75, 75, 75, 75, 72, 77, 77, 77, 77, 77),
    (75, 75, 75, 75, 80, 80, 80, 77, 77, 77, 77),
    (75, 75, 75, 80, 80, 80, 80, 80, 77, 77, 77),
    (75, 75, 80, 80, 80, 80, 80, 80, 80, 77, 77),
    (75, 80, 80, 80, 80, 80, 80, 80, 80, 80, 77),
    (80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80));
  { Cloud directions, spell names and spell table }
  { direction indices: center, E, SE, S }
  cloudDir: array[1..4] of Byte = (
    8, 2, 3, 4);
  { spell IDs 1..56 }
  spellNames: array[1..56] of string[40] = (
    'Bless',
    'Curse',
    'Cure Light Wounds',
    'Cause Light Wounds',
    'Detect Magic',
    'Protection From Evil',
    'Protection from Good',
    'Resist Cold',
    'Burning Hands',
    'Charm Person',
    'Detect Magic',
    'Enlarge',
    'Reduce',
    'Friends',
    'Magic Missile',
    'Protection From Evil',
    'Protection From Good',
    'Read Magic',
    'Shield',
    'Shocking Grasp',
    'Sleep',
    'Find Traps',
    'Hold Person',
    'Resist Fire',
    'Silence, 15'' Radius',
    'Slow Poison',
    'Snake Charm',
    'Spiritual Hammer',
    'Detect Invisibility',
    'Invisibility',
    'Knock',
    'Mirror Image',
    'Ray of Enfeeblement',
    'Stinking Cloud',
    'Strength',
    'Animate Dead',
    'Cure Blindness',
    'Cause Blindness',
    'Cure Disease',
    'Cause Disease',
    'Dispel Magic',
    'Prayer',
    'Remove Curse',
    'Bestow Curse',
    'Blink',
    'Dispel Magic',
    'Fireball',
    'Haste',
    'Hold Person',
    'Invisibility, 10'' Radius',
    'Lightning Bolt',
    'Protection From Evil, 10'' Radius',
    'Protection From Good, 10'' Radius',
    'Protection From Normal Missiles',
    'Slow',
    'Restoration');
  { IDs 57..67 are item effects }
  spellTable: array[1..67] of Types.TSpellRec = (
    { Spell 1: Bless }
    (castClass: 0; level: 1; rangeFixed: 6; rangeVar: 0;
     durFixed: 6; durVar: 0; area: 10; target: 4;
     saveResult: 0; saveType: 4; effect: 1; whenCast: 2;
     castTime: 10; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 2: Curse }
    (castClass: 0; level: 1; rangeFixed: 6; rangeVar: 0;
     durFixed: 6; durVar: 0; area: 10; target: 0;
     saveResult: 0; saveType: 4; effect: 2; whenCast: 1;
     castTime: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { Spell 3: Cure Light Wounds }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 4: Cause Light Wounds }
    (castClass: 0; level: 1; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 5; aiPriority: 2; offensive: 1; aiRadius: 0),
    { Spell 5: Detect Magic }
    (castClass: 0; level: 1; rangeFixed: 3; rangeVar: 0;
     durFixed: 10; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 5; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 6: Protection From Evil }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 3; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 8; whenCast: 2;
     castTime: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 7: Protection from Good }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 3; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 9; whenCast: 2;
     castTime: 4; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 8: Resist Cold }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 10; whenCast: 2;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 9: Burning Hands }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 1; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 10: Charm Person }
    (castClass: 1; level: 1; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 11; whenCast: 1;
     castTime: 1; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 11: Detect Magic }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 5; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 12: Enlarge }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 2;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 12; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 13: Reduce }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 2;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 1; saveType: 4; effect: 13; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { Spell 14: Friends }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 14; whenCast: 0;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 15: Magic Missile }
    (castClass: 1; level: 1; rangeFixed: 6; rangeVar: 4;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 1; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 16: Protection From Evil }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 8; whenCast: 2;
     castTime: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 17: Protection From Good }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 9; whenCast: 2;
     castTime: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 18: Read Magic }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 16; whenCast: 0;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 19: Shield }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 5; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 17; whenCast: 2;
     castTime: 1; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 20: Shocking Grasp }
    (castClass: 1; level: 1; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 1; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 21: Sleep }
    (castClass: 1; level: 1; rangeFixed: 3; rangeVar: 4;
     durFixed: 0; durVar: 5; area: 9; target: 0;
     saveResult: 0; saveType: 4; effect: 53; whenCast: 1;
     castTime: 1; aiPriority: 7; offensive: 1; aiRadius: 1),
    { Spell 22: Find Traps }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 30; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 19; whenCast: 0;
     castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 23: Hold Person }
    (castClass: 0; level: 2; rangeFixed: 6; rangeVar: 0;
     durFixed: 4; durVar: 1; area: 6; target: 0;
     saveResult: 1; saveType: 4; effect: 52; whenCast: 1;
     castTime: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 24: Resist Fire }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 20; whenCast: 2;
     castTime: 5; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 25: Silence, 15' Radius }
    (castClass: 0; level: 2; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 31; target: 0;
     saveResult: 3; saveType: 4; effect: 21; whenCast: 1;
     castTime: 5; aiPriority: 4; offensive: 1; aiRadius: 1),
    { Spell 26: Slow Poison }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 60; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 22; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 27: Snake Charm }
    (castClass: 0; level: 2; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 240; target: 0;
     saveResult: 0; saveType: 4; effect: 51; whenCast: 1;
     castTime: 5; aiPriority: 0; offensive: 1; aiRadius: 0),
    { Spell 28: Spiritual Hammer }
    (castClass: 0; level: 2; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 23; whenCast: 2;
     castTime: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 29: Detect Invisibility }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 4;
     durFixed: 0; durVar: 5; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 24; whenCast: 2;
     castTime: 2; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 30: Invisibility }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 25; whenCast: 2;
     castTime: 2; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 31: Knock }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 0;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 32: Mirror Image }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 28; whenCast: 2;
     castTime: 2; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 33: Ray of Enfeeblement }
    (castClass: 1; level: 2; rangeFixed: 1; rangeVar: 1;
     durFixed: 0; durVar: 1; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 29; whenCast: 1;
     castTime: 2; aiPriority: 2; offensive: 1; aiRadius: 0),
    { Spell 34: Stinking Cloud }
    (castClass: 1; level: 2; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 9; target: 0;
     saveResult: 3; saveType: 0; effect: 30; whenCast: 1;
     castTime: 2; aiPriority: 7; offensive: 1; aiRadius: 1),
    { Spell 35: Strength }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 60; area: 0; target: 2;
     saveResult: 0; saveType: 4; effect: 38; whenCast: 0;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 36: Animate Dead }
    (castClass: 0; level: 3; rangeFixed: 1; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 240; target: 4;
     saveResult: 0; saveType: 4; effect: 32; whenCast: 2;
     castTime: 10; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 37: Cure Blindness }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 38: Cause Blindness }
    (castClass: 0; level: 3; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 33; whenCast: 1;
     castTime: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { Spell 39: Cure Disease }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 0;
     castTime: 100; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 40: Cause Disease }
    (castClass: 0; level: 3; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 34; whenCast: 1;
     castTime: 100; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 41: Dispel Magic }
    (castClass: 0; level: 3; rangeFixed: 6; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 9; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 4; aiPriority: 5; offensive: 1; aiRadius: 1),
    { Spell 42: Prayer }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 49; whenCast: 2;
     castTime: 6; aiPriority: 6; offensive: 0; aiRadius: 0),
    { Spell 43: Remove Curse }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 44: Bestow Curse }
    (castClass: 0; level: 3; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 36; whenCast: 1;
     castTime: 6; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 45: Blink }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 37; whenCast: 1;
     castTime: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 46: Dispel Magic }
    (castClass: 1; level: 3; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 9; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 3; aiPriority: 2; offensive: 1; aiRadius: 1),
    { Spell 47: Fireball }
    (castClass: 1; level: 3; rangeFixed: 10; rangeVar: 1;
     durFixed: 0; durVar: 0; area: 11; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 3),
    { Spell 48: Haste }
    (castClass: 1; level: 3; rangeFixed: 6; rangeVar: 0;
     durFixed: 3; durVar: 1; area: 10; target: 4;
     saveResult: 0; saveType: 4; effect: 39; whenCast: 2;
     castTime: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 49: Hold Person }
    (castClass: 1; level: 3; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 7; target: 0;
     saveResult: 1; saveType: 4; effect: 52; whenCast: 1;
     castTime: 3; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 50: Invisibility, 10' Radius }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 9; target: 4;
     saveResult: 0; saveType: 4; effect: 25; whenCast: 2;
     castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 51: Lightning Bolt }
    (castClass: 1; level: 3; rangeFixed: 4; rangeVar: 1;
     durFixed: 0; durVar: 0; area: 8; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 52: Protection From Evil, 10' Radius }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 45; whenCast: 2;
     castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 53: Protection From Good, 10' Radius }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 46; whenCast: 2;
     castTime: 3; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 54: Protection From Normal Missiles }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 41; whenCast: 2;
     castTime: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 55: Slow }
    (castClass: 1; level: 3; rangeFixed: 9; rangeVar: 1;
     durFixed: 3; durVar: 1; area: 10; target: 0;
     saveResult: 0; saveType: 4; effect: 42; whenCast: 1;
     castTime: 3; aiPriority: 5; offensive: 1; aiRadius: 0),
    { Spell 56: Restoration }
    (castClass: 0; level: 7; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 57 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 39; whenCast: 2;
     castTime: 0; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 58 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 59 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 38; whenCast: 2;
     castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 60 }
    (castClass: 2; level: 6; rangeFixed: 4; rangeVar: 4;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 61 }
    (castClass: 2; level: 6; rangeFixed: 6; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 0; effect: 52; whenCast: 1;
     castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 62 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 39; whenCast: 2;
     castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 63 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 7; target: 4;
     saveResult: 0; saveType: 4; effect: 71; whenCast: 2;
     castTime: 0; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 64 }
    (castClass: 2; level: 6; rangeFixed: 7; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 11; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 3),
    { Spell 65 }
    (castClass: 2; level: 6; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 0; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 66 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 67 }
    (castClass: 2; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 4; whenCast: 0;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0));
  { Rest time units }
  unitScale: array[0..6] of Word = (
    { segment, minute, turn, hour, day, month, year }
    10, 10, 6, 24, 30, 12, 256);
  { Wilderness map: 1-based tile ids; after the - 1, bit 7 selects the second tile set. }
  { row, column }
  wildMap: array[0..35, 0..43] of Byte = (
    ($01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02,
     $01, $02, $01, $02, $01, $28, $9D, $9E, $9B, $9C, $35, $65, $31, $9B, $33, $62, $5E, $9D, $35, $36, $9E, $37),
    ($02, $01, $02, $01, $02, $01, $05, $06, $08, $06, $08, $09, $02, $01, $02, $01, $02, $01, $02, $05, $06, $08,
     $09, $01, $02, $01, $25, $2D, $2E, $9C, $2D, $30, $62, $63, $64, $32, $9C, $35, $36, $44, $4A, $9D, $38, $63),
    ($01, $02, $01, $01, $02, $05, $12, $07, $0D, $21, $04, $12, $08, $09, $05, $06, $08, $06, $03, $12, $07, $04,
     $12, $10, $01, $02, $26, $1A, $62, $2F, $62, $62, $36, $5F, $5F, $9B, $37, $5E, $9D, $43, $4B, $9B, $9C, $33),
    ($02, $05, $06, $03, $0D, $0F, $0E, $0F, $0C, $0B, $0A, $23, $07, $04, $0D, $0E, $0F, $23, $12, $0D, $21, $04,
     $12, $07, $10, $01, $02, $27, $33, $65, $64, $5E, $9B, $9C, $9D, $44, $65, $34, $37, $34, $9C, $9D, $9E, $2D),
    ($03, $07, $0D, $0F, $0C, $0B, $22, $0C, $0B, $22, $0B, $1F, $12, $07, $0E, $22, $0C, $0B, $0A, $0C, $0B, $21,
     $04, $12, $07, $10, $01, $02, $28, $38, $65, $34, $9D, $9E, $9B, $43, $62, $63, $62, $63, $4C, $9B, $9C, $48),
    ($0E, $0F, $22, $0B, $22, $0C, $0B, $22, $24, $24, $1F, $07, $04, $0D, $22, $24, $22, $0C, $0B, $24, $22, $24,
     $21, $04, $12, $11, $02, $29, $9C, $37, $62, $63, $32, $9D, $37, $63, $64, $65, $64, $65, $62, $32, $9D, $43),
    ($0C, $0B, $24, $22, $24, $22, $0C, $0B, $22, $1F, $07, $04, $12, $0E, $0C, $0B, $24, $22, $24, $22, $0C, $0B,
     $1F, $07, $04, $11, $01, $02, $28, $33, $64, $5E, $9B, $9C, $48, $65, $3A, $62, $3A, $62, $63, $4D, $9E, $35),
    ($0B, $24, $22, $24, $0C, $0B, $22, $24, $22, $21, $12, $0E, $0F, $22, $24, $22, $0B, $24, $22, $24, $22, $1F,
     $04, $12, $16, $13, $02, $29, $9B, $33, $62, $5E, $9D, $9E, $43, $42, $7B, $3D, $93, $3B, $65, $4B, $44, $63),
    ($22, $22, $0C, $0B, $22, $24, $24, $22, $0C, $0B, $C9, $CA, $22, $0C, $0B, $24, $22, $0C, $0B, $22, $1F, $12,
     $07, $11, $01, $02, $01, $02, $27, $9C, $35, $65, $32, $44, $42, $93, $92, $FF, $A7, $3C, $64, $4D, $43, $65),
    ($24, $0B, $22, $0C, $0B, $22, $0C, $0B, $22, $24, $CB, $CC, $24, $22, $0C, $0B, $24, $20, $1B, $1C, $16, $04,
     $12, $13, $02, $01, $02, $01, $29, $37, $62, $63, $32, $49, $41, $88, $93, $A7, $3E, $65, $62, $63, $64, $36),
    ($0B, $22, $24, $24, $22, $24, $22, $22, $24, $22, $CD, $CE, $CF, $24, $1F, $1D, $1C, $04, $12, $13, $01, $17,
     $15, $02, $01, $02, $01, $02, $01, $2A, $64, $5E, $9B, $37, $62, $41, $3F, $3E, $62, $63, $64, $65, $36, $9C),
    ($24, $0C, $0B, $22, $24, $22, $0C, $0B, $22, $24, $D0, $D1, $D2, $1C, $12, $07, $04, $12, $D8, $94, $02, $01,
     $02, $01, $02, $FB, $02, $01, $02, $01, $2A, $36, $2C, $62, $46, $47, $62, $63, $64, $65, $62, $36, $9E, $9B),
    ($22, $24, $22, $24, $22, $0B, $22, $24, $22, $1F, $04, $12, $D3, $D4, $EF, $D5, $D6, $D7, $79, $7A, $95, $02,
     $01, $02, $01, $8A, $95, $02, $01, $02, $01, $2B, $01, $45, $9B, $9C, $48, $62, $63, $64, $34, $9B, $9C, $9D),
    ($1B, $1B, $1C, $1D, $1E, $0C, $0B, $22, $1F, $04, $12, $07, $04, $12, $07, $DA, $D9, $79, $7C, $79, $7A, $95,
     $02, $01, $8A, $91, $7B, $95, $02, $01, $02, $01, $02, $39, $9D, $9E, $43, $36, $33, $62, $36, $9D, $9E, $2D),
    ($04, $12, $07, $04, $12, $1D, $1E, $1F, $04, $12, $07, $04, $14, $18, $15, $EE, $DB, $DC, $79, $7A, $79, $91,
     $95, $86, $7A, $90, $91, $7B, $95, $02, $01, $02, $40, $9B, $2D, $30, $36, $9E, $44, $64, $4C, $9C, $44, $62),
    ($14, $15, $2B, $17, $18, $18, $19, $14, $15, $17, $18, $15, $01, $02, $8A, $91, $79, $DD, $E7, $E6, $E5, $7D,
     $88, $89, $79, $7A, $7B, $91, $92, $96, $02, $29, $FC, $2F, $62, $4A, $9B, $9C, $5D, $65, $63, $32, $61, $63),
    ($01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $8A, $89, $93, $7B, $91, $DE, $E9, $E8, $E4, $01,
     $7D, $88, $7A, $90, $91, $7B, $92, $93, $95, $02, $27, $BA, $64, $4B, $9D, $9E, $9B, $48, $4A, $9B, $43, $64),
    ($02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $86, $89, $7B, $91, $92, $93, $79, $DF, $E1, $E2, $E3, $6F,
     $01, $7D, $88, $92, $93, $92, $93, $79, $7B, $95, $02, $B9, $B8, $2E, $2D, $4C, $9C, $5D, $4B, $44, $62, $63),
    ($01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $86, $88, $91, $7B, $92, $93, $79, $E0, $6D, $72, $66, $70,
     $02, $01, $7D, $91, $92, $93, $91, $7C, $91, $8E, $01, $02, $BB, $B7, $48, $63, $4D, $9D, $9E, $61, $64, $65),
    ($02, $01, $02, $01, $02, $01, $52, $5C, $02, $01, $02, $7D, $88, $92, $93, $79, $7B, $8F, $76, $68, $67, $71,
     $01, $02, $8A, $91, $7B, $91, $7B, $91, $79, $8D, $02, $01, $29, $B6, $5D, $65, $60, $9B, $9C, $61, $62, $36),
    ($01, $02, $01, $02, $01, $02, $53, $4F, $5B, $02, $01, $02, $7D, $88, $91, $7C, $8E, $02, $77, $69, $6D, $70,
     $02, $01, $88, $90, $91, $7B, $93, $7B, $91, $93, $95, $02, $99, $C8, $B5, $48, $60, $9D, $9E, $43, $36, $9B),
    ($02, $01, $02, $01, $02, $01, $54, $4F, $50, $01, $02, $01, $02, $7D, $7B, $79, $8D, $01, $F6, $6A, $6B, $73,
     $01, $02, $7D, $7A, $7B, $91, $92, $93, $79, $7A, $8C, $01, $9F, $C7, $9C, $43, $31, $9B, $44, $4A, $9D, $9E),
    ($01, $02, $01, $02, $01, $02, $55, $4F, $5B, $02, $01, $02, $01, $86, $88, $A7, $8C, $02, $8A, $59, $6A, $6B,
     $74, $01, $02, $A6, $91, $7B, $92, $93, $79, $97, $9A, $9A, $9B, $C6, $44, $62, $F2, $4D, $61, $60, $9C, $44),
    ($02, $01, $02, $01, $02, $01, $02, $54, $5C, $01, $02, $01, $02, $01, $7D, $8C, $02, $8A, $91, $58, $6D, $66,
     $6D, $74, $01, $7D, $93, $92, $93, $79, $7B, $97, $9C, $FA, $9E, $C5, $5D, $F1, $01, $2A, $5D, $31, $9B, $43),
    ($01, $02, $01, $02, $01, $02, $01, $53, $4F, $5B, $01, $02, $01, $02, $01, $02, $8A, $91, $7B, $91, $59, $6A,
     $6B, $6D, $75, $01, $A6, $93, $91, $7C, $91, $97, $9C, $C2, $C3, $C4, $A4, $01, $02, $01, $F3, $62, $4C, $35),
    ($02, $01, $02, $01, $02, $01, $52, $4F, $4F, $50, $02, $01, $02, $01, $02, $86, $7A, $90, $91, $7B, $58, $6D,
     $6A, $6C, $6B, $75, $7D, $88, $7B, $79, $7B, $93, $98, $C5, $A4, $01, $01, $02, $8A, $89, $B4, $64, $65, $B2),
    ($01, $02, $01, $02, $01, $02, $55, $4F, $51, $02, $01, $02, $01, $02, $01, $02, $7D, $7A, $7B, $91, $92, $59,
     $6D, $6D, $66, $6D, $75, $7D, $88, $A7, $8C, $A6, $92, $C0, $02, $8A, $89, $89, $92, $93, $87, $B2, $B3, $4E),
    ($02, $01, $02, $01, $02, $01, $02, $54, $4F, $5B, $02, $01, $02, $01, $02, $01, $86, $90, $91, $7B, $92, $93,
     $5A, $59, $F4, $FD, $6E, $01, $7D, $8C, $02, $7D, $93, $BF, $A3, $A1, $A2, $92, $A0, $83, $84, $4E, $4E, $4E),
    ($01, $02, $01, $02, $01, $02, $01, $53, $4F, $50, $01, $02, $01, $02, $01, $02, $01, $7D, $88, $92, $93, $79,
     $7B, $7A, $57, $F5, $AE, $AD, $01, $02, $01, $02, $A6, $BE, $BD, $EB, $ED, $83, $84, $4E, $4E, $4E, $4E, $4E),
    ($02, $01, $02, $01, $02, $01, $02, $54, $51, $01, $02, $01, $02, $01, $02, $01, $02, $01, $7D, $88, $92, $7C,
     $91, $93, $85, $4E, $4E, $4E, $AC, $AA, $A9, $A9, $A8, $BC, $EA, $EC, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($01, $02, $01, $02, $01, $02, $01, $55, $56, $02, $01, $02, $01, $02, $AA, $AB, $AD, $AA, $AF, $7E, $7F, $80,
     $81, $83, $84, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $F9, $B0, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $82, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($01, $02, $01, $FE, $01, $02, $AD, $02, $01, $02, $01, $02, $B0, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($B1, $AD, $B1, $AD, $AA, $AF, $4E, $AC, $B1, $AD, $AA, $AF, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E));
  { map column offset for location types 2..4 }
  wildColOfs: array[2..4] of Byte = (0, 13, 26);

const
  { Class, race and level rules }
  { 60 - THAC0 }
  thac0Tbl: array[C_Level.CLERIC..C_Level.MONK, 0..10] of Byte = (
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 40, 40, 40, 40, 41, 41, 41, 41, 41),
    (40, 40, 40, 40, 40, 41, 41, 41, 41, 44, 44),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46));
  krynnRules: Types.TKrynnClassRules = (
    createClassBits: ($02, $20, $08, $40, $80, $01, $04, $10);
    unidentifiedByte: 0;
    classBits: ($02, $02, $08, $10, $20, $01, $04, $10);
    unidentifiedTail: ($10, $10, $10, $20, $20, $20, $40, $40, $40);
    maxClassLevels: (10, 15, 10, 10, 11, 12, 11, 10));
  defIconCol: array[1..6] of Byte = (1, 2, 3, 4, 6, 7);
  { Base thief abilities by thief level }
  thiefBase: array[1..9] of Types.TRuleThief = (
    (pickPockets: 30; openLocks: 25; findTraps: 20; moveSilently: 15; hideShadows: 10;
     hearNoise: 10; climbWalls: 85; readLanguages: 0),
    (pickPockets: 35; openLocks: 29; findTraps: 25; moveSilently: 21; hideShadows: 15;
     hearNoise: 10; climbWalls: 86; readLanguages: 0),
    (pickPockets: 40; openLocks: 33; findTraps: 30; moveSilently: 27; hideShadows: 20;
     hearNoise: 15; climbWalls: 87; readLanguages: 0),
    (pickPockets: 45; openLocks: 37; findTraps: 35; moveSilently: 33; hideShadows: 25;
     hearNoise: 15; climbWalls: 88; readLanguages: 20),
    (pickPockets: 50; openLocks: 42; findTraps: 40; moveSilently: 40; hideShadows: 31;
     hearNoise: 20; climbWalls: 90; readLanguages: 25),
    (pickPockets: 55; openLocks: 47; findTraps: 45; moveSilently: 47; hideShadows: 37;
     hearNoise: 20; climbWalls: 92; readLanguages: 30),
    (pickPockets: 60; openLocks: 52; findTraps: 50; moveSilently: 55; hideShadows: 43;
     hearNoise: 25; climbWalls: 94; readLanguages: 35),
    (pickPockets: 65; openLocks: 57; findTraps: 55; moveSilently: 62; hideShadows: 49;
     hearNoise: 25; climbWalls: 96; readLanguages: 40),
    (pickPockets: 70; openLocks: 62; findTraps: 60; moveSilently: 70; hideShadows: 56;
     hearNoise: 30; climbWalls: 98; readLanguages: 45));
  { Racial thief ability adjustments: dwarf, elf, gnome, half-elf, halfling, half-orc, human }
  raceAdj: array[1..7] of Types.TRuleThief = (
    (pickPockets: 0; openLocks: 10; findTraps: 15; moveSilently: 0; hideShadows: 0;
     hearNoise: 0; climbWalls: -10; readLanguages: -5),
    (pickPockets: 5; openLocks: -5; findTraps: 0; moveSilently: 5; hideShadows: 10;
     hearNoise: 5; climbWalls: 0; readLanguages: 0),
    (pickPockets: 0; openLocks: 5; findTraps: 10; moveSilently: 5; hideShadows: 5;
     hearNoise: 10; climbWalls: -15; readLanguages: 0),
    (pickPockets: 10; openLocks: 0; findTraps: 0; moveSilently: 0; hideShadows: 5;
     hearNoise: 0; climbWalls: 0; readLanguages: 0),
    (pickPockets: 5; openLocks: 5; findTraps: 5; moveSilently: 10; hideShadows: 15;
     hearNoise: 5; climbWalls: -15; readLanguages: -5),
    (pickPockets: -5; openLocks: 5; findTraps: 5; moveSilently: 0; hideShadows: 0;
     hearNoise: 5; climbWalls: 5; readLanguages: -10),
    (pickPockets: 0; openLocks: 0; findTraps: 0; moveSilently: 0; hideShadows: 0;
     hearNoise: 0; climbWalls: 0; readLanguages: 0));
  { Dexterity thief ability adjustments for Dexterity 9..19 }
  dexAdj: array[9..19] of Types.TRuleThiefDex = (
    (pickPockets: -15; openLocks: -10; findTraps: -10; moveSilently: -20; hideShadows: -10),
    (pickPockets: -10; openLocks:  -5; findTraps: -10; moveSilently: -15; hideShadows:  -5),
    (pickPockets:  -5; openLocks:   0; findTraps:  -5; moveSilently: -10; hideShadows:   0),
    (pickPockets:   0; openLocks:   0; findTraps:   0; moveSilently:  -5; hideShadows:   0),
    (pickPockets:   0; openLocks:   0; findTraps:   0; moveSilently:   0; hideShadows:   0),
    (pickPockets:   0; openLocks:   0; findTraps:   0; moveSilently:   0; hideShadows:   0),
    (pickPockets:   0; openLocks:   0; findTraps:   0; moveSilently:   0; hideShadows:   0),
    (pickPockets:   0; openLocks:   5; findTraps:   0; moveSilently:   0; hideShadows:   0),
    (pickPockets:   5; openLocks:  10; findTraps:   0; moveSilently:   5; hideShadows:   5),
    (pickPockets:  10; openLocks:  15; findTraps:   5; moveSilently:  10; hideShadows:  10),
    (pickPockets:  15; openLocks:  20; findTraps:  10; moveSilently:  12; hideShadows:  12));
  { Racial ability limits, by race; the strength columns are by gender. Human women reach 18/00 like human men. }
  dsMinimumMaximumStatistics: array[1..7] of Types.TRuleRace = (
    (strMin: (8, 8); strMax: (18, 17); excMax: (99, 0); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 17; conMin: 12; conMax: 19; chaMin: 3; chaMax: 16),
    (strMin: (3, 3); strMax: (18, 16); excMax: (75, 0); intMin: 8; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 7; dexMax: 19; conMin: 6; conMax: 18; chaMin: 8; chaMax: 18),
    (strMin: (6, 6); strMax: (18, 15); excMax: (50, 0); intMin: 7; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 8; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (3, 3); strMax: (18, 17); excMax: (90, 0); intMin: 4; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 6; dexMax: 18; conMin: 6; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (6, 6); strMax: (17, 14); excMax: (0, 0); intMin: 6; intMax: 18;
     wisMin: 3; wisMax: 17; dexMin: 8; dexMax: 18; conMin: 10; conMax: 19; chaMin: 3; chaMax: 18),
    (strMin: (6, 6); strMax: (18, 18); excMax: (99, 75); intMin: 3; intMax: 17;
     wisMin: 3; wisMax: 14; dexMin: 3; dexMax: 17; conMin: 13; conMax: 19; chaMin: 3; chaMax: 12),
    (strMin: (3, 3); strMax: (18, 18); excMax: (100, 100); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 3; conMax: 18; chaMin: 3; chaMax: 18));
  { The classes each race can take, in the order the class menu lists them. Humans take
    paladins and rangers, and half-elves rangers and cleric/rangers, in Curse's order. }
  classesByRace: array[1..7] of Types.TRuleRaceClasses = (
    { dwarf }
    (count: 3; classes: (2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
    { elf }
    (count: 7; classes: (2, 5, 6, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0)),
    { gnome }
    (count: 3; classes: (2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
    { half-elf }
    (count: 13; classes: (0, 2, 5, 6, 4, 8, 10, 9, 11, 13, 14, 15, 16)),
    { halfling }
    (count: 3; classes: (2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
    { half-orc }
    (count: 6; classes: (0, 2, 6, 8, 12, 14, 0, 0, 0, 0, 0, 0, 0)),
    { human }
    (count: 6; classes: (0, 2, 5, 6, 3, 4, 0, 0, 0, 0, 0, 0, 0)));
  { The classLevels indexes each class trains, in the order its name gives them; -1 fills a shorter list. }
  classParts: array[C_Class.CLERIC..C_Class.MAGE_THIEF] of Types.TRuleClassParts = (
    (first: 0; second: -1; third: -1), { cleric }
    (first: 1; second: -1; third: -1), { druid }
    (first: 2; second: -1; third: -1), { fighter }
    (first: 3; second: -1; third: -1), { paladin }
    (first: 4; second: -1; third: -1), { ranger }
    (first: 5; second: -1; third: -1), { magic-user }
    (first: 6; second: -1; third: -1), { thief }
    (first: 7; second: -1; third: -1), { monk }
    (first: 0; second: 2; third: -1), { cleric/fighter }
    (first: 0; second: 2; third: 5), { cleric/fighter/magic-user }
    (first: 0; second: 4; third: -1), { cleric/ranger }
    (first: 0; second: 5; third: -1), { cleric/magic-user }
    (first: 0; second: 6; third: -1), { cleric/thief }
    (first: 2; second: 5; third: -1), { fighter/magic-user }
    (first: 2; second: 6; third: -1), { fighter/thief }
    (first: 2; second: 5; third: 6), { fighter/magic-user/thief }
    (first: 5; second: 6; third: -1)); { magic-user/thief }
  { Racial ability adjustments, by race and ability, added to each 3d6 roll before the racial limits apply. }
  raceAbilityAdj: array[C_Race.DWARF..C_Race.HUMAN] of Types.TRuleAbilities = (
    (strength: 0; intelligence: 0; wisdom: 0; dexterity: 0; constitution: 1; charisma: -1), { dwarf }
    (strength: 0; intelligence: 0; wisdom: 0; dexterity: 1; constitution: -1; charisma: 0), { elf }
    (strength: 0; intelligence: 0; wisdom: 0; dexterity: 0; constitution: 0; charisma: 0), { gnome }
    (strength: 0; intelligence: 0; wisdom: 0; dexterity: 0; constitution: 0; charisma: 0), { half-elf }
    (strength: -1; intelligence: 0; wisdom: 0; dexterity: 1; constitution: 0; charisma: 0), { halfling }
    (strength: 1; intelligence: 0; wisdom: 0; dexterity: 0; constitution: 1; charisma: -2), { half-orc }
    (strength: 0; intelligence: 0; wisdom: 0; dexterity: 0; constitution: 0; charisma: 0)); { human }
  { The rule book's racial level maximums (Character Race Limits), by race and classLevels index: 0 is no maximum (U)
    and -1 a class the race cannot take. A fighter's or ranger's is the best case, with Strength 18. Half-orcs are not
    offered at creation, so their row is empty. }
  raceMaxLevel: array[C_Race.DWARF..C_Race.HUMAN] of Types.TRuleClassLevels = (
    { dwarf }
    (cleric: -1; druid: -1; fighter: 9; paladin: -1; ranger: -1; mage: -1; thief: 0; monk: -1),
    { elf }
    (cleric: -1; druid: -1; fighter: 7; paladin: -1; ranger: -1; mage: 11; thief: 0; monk: -1),
    { gnome }
    (cleric: -1; druid: -1; fighter: 6; paladin: -1; ranger: -1; mage: -1; thief: 0; monk: -1),
    { half-elf }
    (cleric: 5; druid: -1; fighter: 8; paladin: -1; ranger: 8; mage: 8; thief: 0; monk: -1),
    { halfling }
    (cleric: -1; druid: -1; fighter: 6; paladin: -1; ranger: -1; mage: -1; thief: 0; monk: -1),
    { half-orc }
    (cleric: -1; druid: -1; fighter: -1; paladin: -1; ranger: -1; mage: -1; thief: -1; monk: -1),
    { human }
    (cleric: 0; druid: -1; fighter: 0; paladin: 0; ranger: 0; mage: 0; thief: 0; monk: -1));
  { race, class; the monk column (7) has only the DMG's human monk, 21 + 1d4, as creation offers no monk }
  dsStartingAge: array[1..7, C_Class.CLERIC..C_Class.MONK] of Types.TRuleAge = (
    ((base: 250; num: 2; sides: 20), (base: 0; num: 0; sides: 0), (base: 40; num: 5; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 75; num: 3; sides: 6), (base: 0; num: 0; sides: 0)),
    ((base: 650; num: 10; sides: 10), (base: 0; num: 0; sides: 0), (base: 130; num: 5; sides: 6),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 150; num: 5; sides: 6),
     (base: 100; num: 5; sides: 6), (base: 0; num: 0; sides: 0)),
    ((base: 300; num: 3; sides: 12), (base: 0; num: 0; sides: 0), (base: 60; num: 5; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 100; num: 2; sides: 12),
     (base: 80; num: 5; sides: 4), (base: 0; num: 0; sides: 0)),
    ((base: 40; num: 2; sides: 4), (base: 0; num: 0; sides: 0), (base: 22; num: 3; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 22; num: 3; sides: 4), (base: 30; num: 2; sides: 8),
     (base: 22; num: 3; sides: 8), (base: 0; num: 0; sides: 0)),
    ((base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 20; num: 3; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 40; num: 2; sides: 4), (base: 0; num: 0; sides: 0)),
    ((base: 20; num: 1; sides: 4), (base: 0; num: 0; sides: 0), (base: 13; num: 1; sides: 4),
     (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0), (base: 0; num: 0; sides: 0),
     (base: 20; num: 2; sides: 4), (base: 0; num: 0; sides: 0)),
    ((base: 18; num: 1; sides: 4), (base: 18; num: 1; sides: 4), (base: 15; num: 1; sides: 4),
     (base: 17; num: 1; sides: 4), (base: 20; num: 1; sides: 4), (base: 24; num: 2; sides: 4),
     (base: 18; num: 1; sides: 4), (base: 21; num: 1; sides: 4)));
  { The oldest age in each age category, in years, by race }
  ageCat: array[1..7] of Types.TRuleAgeCategories = (
    (youngAdult: 50; mature: 150; middleAged: 250; old: 350; venerable: 450), { dwarf }
    (youngAdult: 175; mature: 550; middleAged: 875; old: 1200; venerable: 1600), { elf }
    (youngAdult: 90; mature: 300; middleAged: 450; old: 600; venerable: 750), { gnome }
    (youngAdult: 40; mature: 100; middleAged: 175; old: 250; venerable: 325), { half-elf }
    (youngAdult: 33; mature: 68; middleAged: 101; old: 144; venerable: 199), { halfling }
    (youngAdult: 15; mature: 30; middleAged: 45; old: 60; venerable: 80), { half-orc }
    (youngAdult: 20; mature: 40; middleAged: 60; old: 90; venerable: 120)); { human }
  { Ability minimums by class }
  classMin: array[0..16] of Types.TRuleAbilities = (
    { cleric }
    (strength: 6; intelligence: 6; wisdom: 9; dexterity: 0; constitution: 0; charisma: 0),
    { druid }
    (strength: 0; intelligence: 0; wisdom: 12; dexterity: 0; constitution: 0; charisma: 15),
    { fighter }
    (strength: 9; intelligence: 0; wisdom: 6; dexterity: 6; constitution: 7; charisma: 0),
    { paladin }
    (strength: 12; intelligence: 9; wisdom: 13; dexterity: 0; constitution: 9; charisma: 17),
    { ranger }
    (strength: 13; intelligence: 13; wisdom: 14; dexterity: 0; constitution: 14; charisma: 0),
    { magic-user }
    (strength: 0; intelligence: 9; wisdom: 6; dexterity: 6; constitution: 0; charisma: 0),
    { thief }
    (strength: 6; intelligence: 6; wisdom: 0; dexterity: 9; constitution: 0; charisma: 0),
    { monk }
    (strength: 15; intelligence: 0; wisdom: 15; dexterity: 15; constitution: 11; charisma: 0),
    { cleric/fighter }
    (strength: 9; intelligence: 0; wisdom: 9; dexterity: 0; constitution: 0; charisma: 0),
    { cleric/fighter/magic-user }
    (strength: 9; intelligence: 9; wisdom: 9; dexterity: 0; constitution: 0; charisma: 0),
    { cleric/ranger }
    (strength: 13; intelligence: 13; wisdom: 14; dexterity: 0; constitution: 14; charisma: 0),
    { cleric/magic-user }
    (strength: 0; intelligence: 9; wisdom: 9; dexterity: 0; constitution: 0; charisma: 0),
    { cleric/thief }
    (strength: 0; intelligence: 0; wisdom: 9; dexterity: 9; constitution: 0; charisma: 0),
    { fighter/magic-user }
    (strength: 9; intelligence: 9; wisdom: 0; dexterity: 0; constitution: 0; charisma: 0),
    { fighter/thief }
    (strength: 9; intelligence: 0; wisdom: 0; dexterity: 9; constitution: 0; charisma: 0),
    { fighter/magic-user/thief }
    (strength: 9; intelligence: 9; wisdom: 0; dexterity: 9; constitution: 0; charisma: 0),
    { magic-user/thief }
    (strength: 0; intelligence: 9; wisdom: 0; dexterity: 9; constitution: 0; charisma: 0));
  { The alignments each class can take, in the order the alignment menu lists them }
  alignByClass: array[0..16] of Types.TRuleClassAlignments = (
    { cleric }
    (count: 9; alignments: (C_Align.LG, C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN,
                            C_Align.NE, C_Align.CG, C_Align.CN, C_Align.CE)),
    { druid }
    (count: 5; alignments: (C_Align.LN, C_Align.NG, C_Align.TN, C_Align.NE, C_Align.CN, 0, 0, 0, 0)),
    { fighter }
    (count: 9; alignments: (C_Align.LG, C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN,
                            C_Align.NE, C_Align.CG, C_Align.CN, C_Align.CE)),
    { paladin }
    (count: 1; alignments: (C_Align.LG, 0, 0, 0, 0, 0, 0, 0, 0)),
    { ranger }
    (count: 3; alignments: (C_Align.LG, C_Align.NG, C_Align.CG, 0, 0, 0, 0, 0, 0)),
    { magic-user }
    (count: 9; alignments: (C_Align.LG, C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN,
                            C_Align.NE, C_Align.CG, C_Align.CN, C_Align.CE)),
    { thief }
    (count: 7; alignments: (C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN, C_Align.NE,
                            C_Align.CN, C_Align.CE, 0, 0)),
    { monk }
    (count: 9; alignments: (C_Align.LG, C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN,
                            C_Align.NE, C_Align.CG, C_Align.CN, C_Align.CE)),
    { cleric/fighter }
    (count: 9; alignments: (C_Align.LG, C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN,
                            C_Align.NE, C_Align.CG, C_Align.CN, C_Align.CE)),
    { cleric/fighter/magic-user }
    (count: 9; alignments: (C_Align.LG, C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN,
                            C_Align.NE, C_Align.CG, C_Align.CN, C_Align.CE)),
    { cleric/ranger }
    (count: 3; alignments: (C_Align.LG, C_Align.NG, C_Align.CG, 0, 0, 0, 0, 0, 0)),
    { cleric/magic-user }
    (count: 9; alignments: (C_Align.LG, C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN,
                            C_Align.NE, C_Align.CG, C_Align.CN, C_Align.CE)),
    { cleric/thief }
    (count: 9; alignments: (C_Align.LG, C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN,
                            C_Align.NE, C_Align.CG, C_Align.CN, C_Align.CE)),
    { fighter/magic-user }
    (count: 9; alignments: (C_Align.LG, C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN,
                            C_Align.NE, C_Align.CG, C_Align.CN, C_Align.CE)),
    { fighter/thief }
    (count: 7; alignments: (C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN, C_Align.NE,
                            C_Align.CN, C_Align.CE, 0, 0)),
    { fighter/magic-user/thief }
    (count: 7; alignments: (C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN, C_Align.NE,
                            C_Align.CN, C_Align.CE, 0, 0)),
    { magic-user/thief }
    (count: 7; alignments: (C_Align.LN, C_Align.LE, C_Align.NG, C_Align.TN, C_Align.NE,
                            C_Align.CN, C_Align.CE, 0, 0)));
  conBonusTbl: array[3..20] of ShortInt = (
    -2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2);
  { Experience and spell slots by class slot. A -1 marks a level the class cannot reach, so cleric and magic-user stop
    at 6, paladin and ranger at 7 and fighter at 8; the thief's row runs to the end of the table at 9. }
  dsExperienceSpellsClass: array[C_Level.CLERIC..C_Level.MONK] of Types.TRuleXp = (
    (xp: (1501, 3001, 6001, 13001, 27501, -1, -1, -1);
     slots: ((2, 0, 0), (2, 1, 0), (3, 2, 0), (3, 3, 1), (3, 3, 2), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (-1, -1, -1, -1, -1, -1, -1, -1);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (2001, 4001, 8001, 18001, 35001, 70001, 125001, -1);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (2751, 5501, 12001, 24001, 45001, 95001, -1, -1);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (2251, 4501, 10001, 20001, 40001, 90001, -1, -1);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (2501, 5001, 10001, 22501, 40001, -1, -1, -1);
     slots: ((2, 0, 0), (2, 1, 0), (3, 2, 0), (4, 2, 1), (4, 2, 2), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (1251, 2501, 5001, 10001, 20001, 42501, 70001, 110001);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))),
    (xp: (-1, -1, -1, -1, -1, -1, -1, -1);
     slots: ((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))));
  dsStartingGoldClass: array[C_Level.CLERIC..C_Level.MONK] of Types.TRuleGold = (
    (num: 3; sides: 6), (num: 3; sides: 6), (num: 5; sides: 4), (num: 5; sides: 4),
    (num: 5; sides: 4), (num: 2; sides: 4), (num: 2; sides: 6), (num: 5; sides: 4));
  { ClassCal: Saving throws indexed by class-level slot (C_Level), level 1..9 and save column 0..4. The paladin's row
    is the fighter's less 2. }
  saveTbl: array[C_Level.CLERIC..C_Level.MONK, 1..9] of Types.TRuleSaves = (
    { cleric }
    ((paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12)),
    { druid }
    ((paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 10; petrify: 13; wand: 14; breath: 16; spell: 15),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 9; petrify: 12; wand: 13; breath: 15; spell: 14),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12),
     (paralyze: 7; petrify: 10; wand: 11; breath: 13; spell: 12)),
    { fighter }
    ((paralyze: 14; petrify: 15; wand: 16; breath: 17; spell: 17),
     (paralyze: 14; petrify: 15; wand: 16; breath: 17; spell: 17),
     (paralyze: 13; petrify: 14; wand: 15; breath: 16; spell: 16),
     (paralyze: 13; petrify: 14; wand: 15; breath: 16; spell: 16),
     (paralyze: 11; petrify: 12; wand: 13; breath: 13; spell: 14),
     (paralyze: 11; petrify: 12; wand: 13; breath: 13; spell: 14),
     (paralyze: 10; petrify: 11; wand: 12; breath: 12; spell: 13),
     (paralyze: 10; petrify: 11; wand: 12; breath: 12; spell: 13),
     (paralyze: 8; petrify: 9; wand: 10; breath: 9; spell: 11)),
    { paladin }
    ((paralyze: 12; petrify: 13; wand: 14; breath: 15; spell: 15),
     (paralyze: 12; petrify: 13; wand: 14; breath: 15; spell: 15),
     (paralyze: 11; petrify: 12; wand: 13; breath: 14; spell: 14),
     (paralyze: 11; petrify: 12; wand: 13; breath: 14; spell: 14),
     (paralyze: 9; petrify: 10; wand: 11; breath: 11; spell: 12),
     (paralyze: 9; petrify: 10; wand: 11; breath: 11; spell: 12),
     (paralyze: 8; petrify: 9; wand: 10; breath: 10; spell: 11),
     (paralyze: 8; petrify: 9; wand: 10; breath: 10; spell: 11),
     (paralyze: 6; petrify: 7; wand: 8; breath: 7; spell: 9)),
    { ranger }
    ((paralyze: 14; petrify: 15; wand: 16; breath: 17; spell: 17),
     (paralyze: 14; petrify: 15; wand: 16; breath: 17; spell: 17),
     (paralyze: 13; petrify: 14; wand: 15; breath: 16; spell: 16),
     (paralyze: 13; petrify: 14; wand: 15; breath: 16; spell: 16),
     (paralyze: 11; petrify: 12; wand: 13; breath: 13; spell: 14),
     (paralyze: 11; petrify: 12; wand: 13; breath: 13; spell: 14),
     (paralyze: 10; petrify: 11; wand: 12; breath: 12; spell: 13),
     (paralyze: 10; petrify: 11; wand: 12; breath: 12; spell: 13),
     (paralyze: 8; petrify: 9; wand: 10; breath: 9; spell: 11)),
    { magic-user }
    ((paralyze: 14; petrify: 13; wand: 11; breath: 15; spell: 12),
     (paralyze: 14; petrify: 13; wand: 11; breath: 15; spell: 12),
     (paralyze: 14; petrify: 13; wand: 11; breath: 15; spell: 12),
     (paralyze: 14; petrify: 13; wand: 11; breath: 15; spell: 12),
     (paralyze: 14; petrify: 13; wand: 11; breath: 15; spell: 12),
     (paralyze: 13; petrify: 11; wand: 9; breath: 13; spell: 10),
     (paralyze: 13; petrify: 11; wand: 9; breath: 13; spell: 10),
     (paralyze: 13; petrify: 11; wand: 9; breath: 13; spell: 10),
     (paralyze: 13; petrify: 11; wand: 9; breath: 13; spell: 10)),
    { thief }
    ((paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 11; petrify: 10; wand: 10; breath: 14; spell: 11)),
    { monk }
    ((paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 13; petrify: 12; wand: 14; breath: 16; spell: 15),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 12; petrify: 11; wand: 12; breath: 15; spell: 13),
     (paralyze: 11; petrify: 10; wand: 10; breath: 14; spell: 11)));

implementation

end.
