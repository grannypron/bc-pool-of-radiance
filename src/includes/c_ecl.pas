{ ECL script opcodes, plus the search entry-header slot. }
{$I COMPILER.INC}
unit C_ECL;

interface

const
  OP_EXIT = $00;
  OP_GOTO = $01;
  GOSUB = $02;
  COMPARE = $03;
  ADD = $04;
  SUBTRACT = $05;
  DIVIDE = $06;
  MULTIPLY = $07;
  OP_RANDOM = $08;
  SAVE = $09;
  LOAD_CHARACTER = $0A;
  LOAD_MONSTER = $0B;
  SETUP_MONSTER = $0C;
  APPROACH = $0D;
  PICTURE = $0E;
  INPUT_NUMBER = $0F;
  INPUT_STRING = $10;
  PRINT = $11;
  PRINT_CLEAR = $12;
  RETURN = $13;
  COMPARE_AND = $14;
  VERTICAL_MENU = $15;
  IF_EQ = $16;
  IF_NE = $17;
  IF_LT = $18;
  IF_GT = $19;
  IF_LE = $1A;
  IF_GE = $1B;
  CLEAR_MONSTERS = $1C;
  PARTY_STRENGTH = $1D;
  CHECK_PARTY = $1E;
  { no handler runs it (EclVm.ExecNextEclCmd steps over it); it takes two operands (EclVars.SkipEclCmd) }
  UNUSED_1F = $1F;
  NEW_ECL = $20;
  LOAD_FILES = $21;
  PARTY_SURPRISE = $22;
  SURPRISE = $23;
  OP_COMBAT = $24;
  ON_GOTO = $25;
  ON_GOSUB = $26;
  TREASURE = $27;
  ROB = $28;
  ENCOUNTER_MENU = $29;
  GET_TABLE = $2A;
  HORIZONTAL_MENU = $2B;
  PARLAY = $2C;
  CALL = $2D;
  DAMAGE = $2E;
  OP_AND = $2F;
  OP_OR = $30;
  SPRITE_OFF = $31;
  FIND_ITEM = $32;
  PRINT_RETURN = $33;
  CLOCK = $34;
  SAVE_TABLE = $35;
  ADD_NPC = $36;
  LOAD_PIECES = $37;
  OP_PROGRAM = $38;
  WHO = $39;
  OP_DELAY = $3A;
  SPELL = $3B;
  PROTECTION = $3C;
  CLEAR_BOX = $3D;
  { Not SSI's: a data fix's command (#1096). It uses up one item a FIND ITEM selector names (EclVm.EclUseUpItem), and
    takes one operand. Curse's and Pools of Darkness's $40 takes away every item of a type, and Pools has a $41, so it
    is given a number no SSI game uses. }
  USE_UP_ITEM = $80;

  { The script header's entry slots (GameVars.scriptEntryAddrs), the addresses EclMenu.EclInit reads from the script's
    first ENTRY_COUNT variables. }
  { run after each map-menu command, before the party moves }
  ENTRY_MOVE = 1;
  { run after a step, and for search and Look }
  ENTRY_SEARCH = 2;
  { run before the camp menu }
  ENTRY_PRE_CAMP = 3;
  { run when the party's rest is interrupted }
  ENTRY_CAMP_INTERRUPT = 4;
  { run when the script is loaded }
  ENTRY_LOAD = 5;
  ENTRY_COUNT = 5;

implementation

end.
