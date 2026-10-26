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
    C_ECL.OP_EXIT: OpName := 'EXIT';
    C_ECL.OP_GOTO: OpName := 'GOTO';
    C_ECL.GOSUB: OpName := 'GOSUB';
    C_ECL.COMPARE: OpName := 'COMPARE';
    C_ECL.ADD: OpName := 'ADD';
    C_ECL.SUBTRACT: OpName := 'SUBTRAT';
    C_ECL.DIVIDE: OpName := 'DIVIDE';
    C_ECL.MULTIPLY: OpName := 'MULTIPLY';
    C_ECL.OP_RANDOM: OpName := 'RANDOM';
    C_ECL.SAVE: OpName := 'SAVE';
    C_ECL.LOAD_CHARACTER: OpName := 'LOAD CHARACTER';
    C_ECL.LOAD_MONSTER: OpName := 'LOAD MONSTER';
    C_ECL.SETUP_MONSTER: OpName := 'SETUP MONSTER';
    C_ECL.APPROACH: OpName := 'APPROACH';
    C_ECL.PICTURE: OpName := 'PICTURE';
    C_ECL.INPUT_NUMBER: OpName := 'INPUT NUMBER';
    C_ECL.INPUT_STRING: OpName := 'INPUT STRING';
    C_ECL.PRINT: OpName := 'PRINT';
    C_ECL.PRINT_CLEAR: OpName := 'PRINTCLEAR';
    C_ECL.RETURN: OpName := 'RETURN';
    C_ECL.COMPARE_AND: OpName := 'COMPARE AND';
    C_ECL.VERTICAL_MENU: OpName := 'VERTICAL MENU';
    C_ECL.IF_EQ: OpName := 'IF = ';
    C_ECL.IF_NE: OpName := 'IF <>';
    C_ECL.IF_LT: OpName := 'IF <';
    C_ECL.IF_GT: OpName := 'IF >';
    C_ECL.IF_LE: OpName := 'IF <=';
    C_ECL.IF_GE: OpName := 'IF >=';
    C_ECL.CLEAR_MONSTERS: OpName := 'CLEARMONSTERS';
    C_ECL.PARTY_STRENGTH: OpName := 'PARTYSTRENGTH';
    C_ECL.CHECK_PARTY: OpName := 'CHECKPARTY';
    C_ECL.NEW_ECL: OpName := 'NEWECL';
    C_ECL.LOAD_FILES: OpName := 'LOAD FILES';
    C_ECL.LOAD_PIECES: OpName := 'LOAD PIECES';
    C_ECL.PARTY_SURPRISE: OpName := 'PARTY SURPRISE';
    C_ECL.SURPRISE: OpName := 'SURPRISE';
    C_ECL.OP_COMBAT: OpName := 'COMBAT';
    C_ECL.ON_GOTO: OpName := 'ON GOTO';
    C_ECL.ON_GOSUB: OpName := 'ON GOSUB';
    C_ECL.TREASURE: OpName := 'TREASURE';
    C_ECL.ROB: OpName := 'ROB';
    C_ECL.ENCOUNTER_MENU: OpName := 'ENCOUNTER MENU';
    C_ECL.GET_TABLE: OpName := 'GETTABLE';
    C_ECL.HORIZONTAL_MENU: OpName := 'HORIZONTAL MENU';
    C_ECL.PARLAY: OpName := 'PARLAY';
    C_ECL.CALL: OpName := 'CALL';
    C_ECL.DAMAGE: OpName := 'DAMAGE';
    C_ECL.OP_AND: OpName := 'AND';
    C_ECL.OP_OR: OpName := 'OR';
    C_ECL.SPRITE_OFF: OpName := 'SPRITE OFF';
    C_ECL.FIND_ITEM: OpName := 'FIND ITEM';
    C_ECL.PRINT_RETURN: OpName := 'PRINT RETURN';
    C_ECL.CLOCK: OpName := 'ECL CLOCK';
    C_ECL.SAVE_TABLE: OpName := 'SAVE TABLE';
    C_ECL.ADD_NPC: OpName := 'ADD NPC';
    C_ECL.OP_PROGRAM: OpName := 'PROGRAM';
    C_ECL.WHO: OpName := 'WHO';
    C_ECL.OP_DELAY: OpName := 'DELAY';
    C_ECL.SPELL: OpName := 'SPELL';
    C_ECL.PROTECTION: OpName := 'PROTECTION';
    C_ECL.CLEAR_BOX: OpName := 'CLEAR BOX';
  else
    OpName := '?';
  end;
end;

end.
