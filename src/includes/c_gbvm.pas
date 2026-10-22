{ Script-visible game-memory addresses. }
{$I COMPILER.INC}
unit C_Gbvm;

interface

const
  { The script buffer, zone 3 (#607): the running area's script, from its first byte at SCRIPT_FIRST. SSI's 7680 bytes
    ended at $B6FF; it now runs to $BFFF, below the first special cell a script reads or writes ($C04B, the party's X),
    so a script can be 9984 bytes. A saved game keeps SSI's SAVED_SCRIPT_BYTES of it, where SSI kept them, so saves stay
    SSI's size; a load does not use them, but loads the area's script from the data (#609). }
  SCRIPT_FIRST = $9900;
  SCRIPT_LAST = $BFFF;
  SAVED_SCRIPT_BYTES = 7680;
  { The zones, word cells except zone 3 (EclVars.GbvmZone). Anything outside them is zone 4: the special cells below,
    which EclVars' address map reads and writes as game variables. }
  ZONE0_FIRST = $4900;
  ZONE0_LAST = $4CFF;
  ZONE1_FIRST = $6B00;
  ZONE1_LAST = $6EFF;
  ZONE2_FIRST = $9700;
  ZONE2_LAST = $98FF;
  { Script-visible game-memory addresses, used as word-array indices through the zone pointers. }
  { zone 0 ($4900 bank: zone0) }
  { The party's effects, read only (EclVars.PartyEffectsTable): effect ids from PARTY_EFFECTS, their owners' party
    indexes from PARTY_EFFECT_OWNERS, to PARTY_EFFECTS_LAST. }
  PARTY_EFFECTS = $4900;
  PARTY_EFFECT_OWNERS = $4940;
  PARTY_EFFECTS_LAST = $497F;
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
  { the sky and ceiling colour and the alternate sky colour; a write redraws the sky }
  SKY_CEILING_COLOR = $49FD;
  ALT_SKY_COLOR = $49FE;
  { SaveLoad packs 2 * monster-pictures flag + portraits flag }
  SETTINGS = $49FF;
  { The day the Temple of Bane was freed with Dirten in the party (#682, a DataPat fix to its script): year * 360 +
    month * 30 + day + 1 from CLOCK, so 0 is none; $FFFF when it was freed without him. 14 days on, Dirten serves the
    party there a tenth off. One of the cells that no script and no unit used ($4A53..$4A58, $4A6E..$4A71, $4A79..$4A7B:
    every script's disassembly, its indexed tables included, and the source). }
  DIRTEN_TEMPLE_DAY = $4A79;
  { quest: left Yarash pyramid, cleared }
  YARASH_PYRAMID_LEFT = $4AA2;
  { quest: Yarash mission successful }
  YARASH_MISSION_DONE = $4AB3;
  { saved wall-set IDs: base + slot 1..3 }
  WALLSLOT_ID = $4AF9;
  { saved wall-set symbol slots: base + 1..3 }
  WALLSLOT_SLOT = $4AFC;
  { zone 1 ($6B00 bank: zone1) }
  { The current character (GDVars.curChar), which EclVars' map reads and writes in place of these cells. }
  { its name, as a string (a read or write of a string at this address) }
  CHAR_NAME = $6B00;
  { a write of 0 marks the character for removal (with CHAR_ENABLED's 0) }
  CHAR_DUMP = $6B00;
  CHAR_CON = $6B18;
  { a raw window into the character record from memorizedSpells[1], running on past it (TCharRecord's layout) }
  CHAR_MEMORIZED_FIRST = $6B20;
  CHAR_MEMORIZED_LAST = $6B70;
  CHAR_SAVE_PETRIFY = $6B9B;
  CHAR_LEVEL = $6BA0;
  { thief skills 1..8 }
  CHAR_THIEF_SKILLS = $6BA5;
  CHAR_THIEF_SKILLS_LAST = $6BAC;
  CHAR_NPC = $6BB8;
  { coins, copper to platinum, a cell apart; a write recalculates the character's stats }
  CHAR_COPPER = $6BBB;
  CHAR_SILVER = $6BBD;
  CHAR_ELECTRUM = $6BBF;
  CHAR_GOLD = $6BC1;
  CHAR_PLATINUM = $6BC3;
  CHAR_ALIGNMENT = $6BD8;
  CHAR_XP_AWARD = $6BF7;
  CHAR_XP_PER_HP = $6BF9;
  { 1 enabled, $80 not; a write of $80 or more disables it ($87 also stones it), 0 marks it for removal }
  CHAR_ENABLED = $6C00;
  { 0 manual, $80 quick-fight, $81 hostile }
  CHAR_CONTROL = $6C0C;
  { read: handled, no value }
  CHAR_CONTROL_HI = $6C0D;
  CHAR_MOVEMENT = $6C1B;
  { its zero-based index in the party (two cells) }
  CHAR_PARTY_INDEX = $6DB1;
  CHAR_PARTY_INDEX2 = $6DB4;
  { the loyalty base its Charisma gives }
  CHAR_LOYALTY = $6DCF;
  { a write of $80 + id loads wall set id into slot 1, 2 or 3 }
  WALLSET_LOAD1 = $6E22;
  WALLSET_LOAD2 = $6E24;
  WALLSET_LOAD3 = $6E26;
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
  { 1 => party about to enter temple; 2 => the temple a tenth off (MoneyCal.TEMPLE_TENTH_OFF, #682) }
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
  { a to-hit bonus a script gives the monsters' attacks (signed, low byte) }
  MONSTER_HIT_MOD = $6E70;
  { a to-hit bonus a script gives the party's attacks (signed, low byte) }
  PARTY_HIT_MOD = $6E71;
  { int8 ad-hoc monster THAC0 modifier }
  MOD_MONSTER_THAC0 = $6E70;
  { int8 ad-hoc party THAC0 modifier }
  MOD_PARTY_THAC0 = $6E71;
  { int8 ad-hoc party movement modifier }
  MOD_PARTY_MOVE = $6E72;
  { zone 4: special cells }
  { registers: the read ones always read 0; the written ones keep the value, which nothing reads }
  READ_REG3 = $B1;
  WRITE_REG1 = $B8;
  WRITE_REG2 = $B9;
  READ_REG1 = $FB;
  READ_REG2 = $FC;
  { the party's facing as stored (0, 2, 4, 6) }
  FACING_RAW = $33D;
  { read: handled, no value }
  CELL_35F = $35F;
  { a sound effect to play }
  SOUND_EFFECT = $3DE;
  { the party and the view: position, facing (0..3), the wall ahead and the event byte at its cell }
  CELL_PARTY_X = $C04B;
  CELL_PARTY_Y = $C04C;
  CELL_FACING = $C04D;
  CELL_WALL_AHEAD = $C04E;
  CELL_EVENT = $C04F;
  { write only: the wall colour and the ceiling and floor colour of the 3D view }
  CELL_WALL_COLOR = $C059;
  CELL_CEIL_FLOOR_COLOR = $C05F;
  { written by scripts and ignored }
  CELL_IGNORED = $D022;

implementation

end.
