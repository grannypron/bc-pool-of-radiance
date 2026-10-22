{ The script opcodes' mnemonics, for the debug trace log (STING: Ctrl-L), as Curse of the Azure Bonds writes them. }
{$O+,F+}
{$I COMPILER.INC}
unit EclTrace;

interface

{ The mnemonic of script opcode op, as Curse spells it (its subtract is SUBTRAT); '?' for a value with no opcode. }
function OpName(op: Byte): String;

implementation

uses C_ECL;

function OpName(op: Byte): String;
begin
  case op of
    C_ECL.EXIT_SCRIPT: OpName := 'EXIT';
    C_ECL.JUMP: OpName := 'GOTO';
    C_ECL.GOSUB: OpName := 'GOSUB';
    C_ECL.COMPARE: OpName := 'COMPARE';
    C_ECL.ADD: OpName := 'ADD';
    C_ECL.SUBTRACT: OpName := 'SUBTRAT';
    C_ECL.DIVIDE: OpName := 'DIVIDE';
    C_ECL.MULTIPLY: OpName := 'MULTIPLY';
    C_ECL.RANDOM_NUMBER: OpName := 'RANDOM';
    C_ECL.SAVE: OpName := 'SAVE';
    C_ECL.LOAD_CHAR: OpName := 'LOAD CHARACTER';
    C_ECL.LOAD_MON: OpName := 'LOAD MONSTER';
    C_ECL.SETUP_MON: OpName := 'SETUP MONSTER';
    C_ECL.APPROACH: OpName := 'APPROACH';
    C_ECL.PICTURE: OpName := 'PICTURE';
    C_ECL.INPUT_NUM: OpName := 'INPUT NUMBER';
    C_ECL.INPUT_STR: OpName := 'INPUT STRING';
    C_ECL.PRINT: OpName := 'PRINT';
    C_ECL.PRINTCLEAR: OpName := 'PRINTCLEAR';
    C_ECL.RETURN: OpName := 'RETURN';
    C_ECL.COMPARE_AND: OpName := 'COMPARE AND';
    C_ECL.VMENU: OpName := 'VERTICAL MENU';
    C_ECL.IF_EQ: OpName := 'IF = ';
    C_ECL.IF_NE: OpName := 'IF <>';
    C_ECL.IF_LT: OpName := 'IF <';
    C_ECL.IF_GT: OpName := 'IF >';
    C_ECL.IF_LE: OpName := 'IF <=';
    C_ECL.IF_GE: OpName := 'IF >=';
    C_ECL.CLEAR_MON: OpName := 'CLEARMONSTERS';
    C_ECL.PARTY_STR: OpName := 'PARTYSTRENGTH';
    C_ECL.CHECK_PARTY: OpName := 'CHECKPARTY';
    C_ECL.NEWECL: OpName := 'NEWECL';
    C_ECL.LOADFILES: OpName := 'LOAD FILES';
    C_ECL.LOADPIECES: OpName := 'LOAD PIECES';
    C_ECL.PARTY_SURPR: OpName := 'PARTY SURPRISE';
    C_ECL.SURPRISE: OpName := 'SURPRISE';
    C_ECL.START_COMBAT: OpName := 'COMBAT';
    C_ECL.ONGOTO: OpName := 'ON GOTO';
    C_ECL.ONGOSUB: OpName := 'ON GOSUB';
    C_ECL.TREASURE: OpName := 'TREASURE';
    C_ECL.ROB: OpName := 'ROB';
    C_ECL.ENCOUNTER: OpName := 'ENCOUNTER MENU';
    C_ECL.GETTABLE: OpName := 'GETTABLE';
    C_ECL.HMENU: OpName := 'HORIZONTAL MENU';
    C_ECL.PARLAY: OpName := 'PARLAY';
    C_ECL.CALL: OpName := 'CALL';
    C_ECL.DAMAGE: OpName := 'DAMAGE';
    C_ECL.BIT_AND: OpName := 'AND';
    C_ECL.BIT_OR: OpName := 'OR';
    C_ECL.SPRITE_OFF: OpName := 'SPRITE OFF';
    C_ECL.FIND_ITEM: OpName := 'FIND ITEM';
    C_ECL.PRINT_RET: OpName := 'PRINT RETURN';
    C_ECL.CLOCK: OpName := 'ECL CLOCK';
    C_ECL.SAVE_TABLE: OpName := 'SAVE TABLE';
    C_ECL.ADD_NPC: OpName := 'ADD NPC';
    C_ECL.RUN_PROGRAM: OpName := 'PROGRAM';
    C_ECL.WHO: OpName := 'WHO';
    C_ECL.PAUSE: OpName := 'DELAY';
    C_ECL.SPELL: OpName := 'SPELL';
    C_ECL.PROTECTION: OpName := 'PROTECTION';
    C_ECL.CLEAR_BOX: OpName := 'CLEAR BOX';
  else
    OpName := '?';
  end;
end;

end.
