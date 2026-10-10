{ Script-visible game-memory addresses. }
unit C_Gbvm;

interface

const
  { Script-visible game-memory addresses, used as word-array indices through the zone pointers. }
  { zone 0 ($4900 bank: zone0) }
  { party X-coordinate (map) }
  PARTY_X = $49C3;
  { party Y-coordinate (map) }
  PARTY_Y = $49C4;
  { current map ID }
  MAP_ID = $49C5;
  { Script-visible game-memory address of the 7-word clock block: segment, minute, turn, hour, day, month, year }
  CLOCK = $49C6;
  { <>0 => spellcasting forbidden here }
  ANTIMAGIC = $49E5;
  { Nonzero when a 3D map is loaded, including indoor areas and town streets; zero in the wilderness. This selects wall
    graphics or the wilderness backdrop. }
  VIEW_3D = $49E6;
  MAP_3D_GFX1 = $49E7;
  { with MAP_3D_GFX1, controls the combined wall load }
  MAP_3D_GFX2 = $49E8;
  { previous X-coordinate }
  PREV_X = $49F0;
  { previous Y-coordinate }
  PREV_Y = $49F1;
  { previous ECL script ID }
  PREV_SCRIPT_ID = $49F2;
  { 1 => automap disabled }
  NO_AUTOMAP = $49FB;
  { game speed }
  GAME_SPEED = $49FC;
  { SaveLoad packs 2 * monster-pictures flag + portraits flag }
  SETTINGS = $49FF;
  { quest: left Yarash pyramid, cleared }
  YARASH_PYRAMID_LEFT = $4AA2;
  { quest: Yarash mission successful }
  YARASH_MISSION_DONE = $4AB3;
  { saved wall-set IDs: base + slot 1..3 }
  WALLSLOT_ID = $4AF9;
  { saved wall-set symbol slots: base + 1..3 }
  WALLSLOT_SLOT = $4AFC;
  { zone 1 ($6B00 bank: zone1) }
  { Script-visible game-memory address of the bitmask of trainable classes }
  TRAIN_CLASS_MASK = $6DA8;
  { requested monster distance (0..2) }
  MONSTER_DIST_REQ = $6DC0;
  { actual monster distance (0..2) }
  MONSTER_DIST = $6DC1;
  { morale-check % threshold }
  MORALE_THRESHOLD = $6DC6;
  { 0 won, 128 lost, 129 fled }
  COMBAT_RESULT = $6DC7;
  { # monsters defeated last combat }
  MONSTERS_DEFEATED = $6DC8;
  { 255 => party X/Y move locked }
  MOVE_LOCKED = $6DC9;
  { bit0 Search on, bit1 Look pending }
  SEARCH_FLAGS = $6DCA;
  { surprise state for next combat }
  SURPRISE = $6DCB;
  { uninterrupted rest time (min/5) }
  REST_SAFE_TIME = $6DD2;
  { % chance rest interrupted }
  REST_INTERRUPT_PCT = $6DD3;
  { 1 => party to leave current map }
  LEAVE_MAP = $6DD5;
  { picture loading (255 = none) }
  PIC_LOADING = $6DE1;
  { 1 => party about to enter temple }
  ENTER_TEMPLE = $6DE2;
  { 1 => next combat drops no items }
  NO_COMBAT_ITEMS = $6DE3;
  { 1 => next combat is a mirror duel }
  MIRROR_DUEL = $6DE6;
  { current disk number }
  DISK_NUM = $6E12;
  { 1 => party attacked allies last fight }
  ATTACKED_ALLIES = $6E33;
  { party size }
  PARTY_SIZE = $6E3E;
  { 1 => party about to enter shop }
  ENTER_SHOP = $6E6C;
  { int8 ad-hoc monster THAC0 modifier }
  MOD_MONSTER_THAC0 = $6E70;
  { int8 ad-hoc party THAC0 modifier }
  MOD_PARTY_THAC0 = $6E71;
  { int8 ad-hoc party movement modifier }
  MOD_PARTY_MOVE = $6E72;

implementation

end.
