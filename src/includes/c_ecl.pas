{ ECL script opcodes, plus the search entry-header slot. }
{$I COMPILER.INC}
unit C_ECL;

interface

const
  EXIT_SCRIPT = $00;
  JUMP = $01;
  GOSUB = $02;
  COMPARE = $03;
  ADD = $04;
  SUBTRACT = $05;
  DIVIDE = $06;
  MULTIPLY = $07;
  RANDOM_NUMBER = $08;
  SAVE = $09;
  LOAD_CHAR = $0A;
  LOAD_MON = $0B;
  SETUP_MON = $0C;
  APPROACH = $0D;
  PICTURE = $0E;
  INPUT_NUM = $0F;
  INPUT_STR = $10;
  PRINT = $11;
  PRINTCLEAR = $12;
  RETURN = $13;
  COMPARE_AND = $14;
  VMENU = $15;
  IF_EQ = $16;
  IF_NE = $17;
  IF_LT = $18;
  IF_GT = $19;
  IF_LE = $1A;
  IF_GE = $1B;
  CLEAR_MON = $1C;
  PARTY_STR = $1D;
  CHECK_PARTY = $1E;
  NEWECL = $20;
  LOADFILES = $21;
  PARTY_SURPR = $22;
  SURPRISE = $23;
  START_COMBAT = $24;
  ONGOTO = $25;
  ONGOSUB = $26;
  TREASURE = $27;
  ROB = $28;
  ENCOUNTER = $29;
  GETTABLE = $2A;
  HMENU = $2B;
  PARLAY = $2C;
  CALL = $2D;
  DAMAGE = $2E;
  BIT_AND = $2F;
  BIT_OR = $30;
  SPRITE_OFF = $31;
  FIND_ITEM = $32;
  PRINT_RET = $33;
  CLOCK = $34;
  SAVE_TABLE = $35;
  ADD_NPC = $36;
  LOADPIECES = $37;
  RUN_PROGRAM = $38;
  WHO = $39;
  PAUSE = $3A;
  SPELL = $3B;
  PROTECTION = $3C;
  CLEAR_BOX = $3D;

  { Entry-header slot used for search and Look }
  ENTRY_SEARCH = 2;

implementation

end.
