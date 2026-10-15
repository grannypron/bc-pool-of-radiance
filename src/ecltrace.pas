{ The script opcodes' mnemonics, for the debug trace log (STING: Ctrl-L), as Curse of the Azure Bonds writes them. }
{$O+,F+}
unit EclTrace;

interface

{ The mnemonic of script opcode op, as Curse spells it (its subtract is SUBTRAT); '?' for a value with no opcode. }
function OpName(op: Byte): String;

implementation

uses C_Ecl;

function OpName(op: Byte): String;
begin
  case op of
    C_Ecl.EXIT_SCRIPT: OpName := 'EXIT';
    C_Ecl.JUMP: OpName := 'GOTO';
    C_Ecl.GOSUB: OpName := 'GOSUB';
    C_Ecl.COMPARE: OpName := 'COMPARE';
    C_Ecl.ADD: OpName := 'ADD';
    C_Ecl.SUBTRACT: OpName := 'SUBTRAT';
    C_Ecl.DIVIDE: OpName := 'DIVIDE';
    C_Ecl.MULTIPLY: OpName := 'MULTIPLY';
    C_Ecl.RANDOM_NUMBER: OpName := 'RANDOM';
    C_Ecl.SAVE: OpName := 'SAVE';
    C_Ecl.LOAD_CHAR: OpName := 'LOAD CHARACTER';
    C_Ecl.LOAD_MON: OpName := 'LOAD MONSTER';
    C_Ecl.SETUP_MON: OpName := 'SETUP MONSTER';
    C_Ecl.APPROACH: OpName := 'APPROACH';
    C_Ecl.PICTURE: OpName := 'PICTURE';
    C_Ecl.INPUT_NUM: OpName := 'INPUT NUMBER';
    C_Ecl.INPUT_STR: OpName := 'INPUT STRING';
    C_Ecl.PRINT: OpName := 'PRINT';
    C_Ecl.PRINTCLEAR: OpName := 'PRINTCLEAR';
    C_Ecl.RETURN: OpName := 'RETURN';
    C_Ecl.COMPARE_AND: OpName := 'COMPARE AND';
    C_Ecl.VMENU: OpName := 'VERTICAL MENU';
    C_Ecl.IF_EQ: OpName := 'IF = ';
    C_Ecl.IF_NE: OpName := 'IF <>';
    C_Ecl.IF_LT: OpName := 'IF <';
    C_Ecl.IF_GT: OpName := 'IF >';
    C_Ecl.IF_LE: OpName := 'IF <=';
    C_Ecl.IF_GE: OpName := 'IF >=';
    C_Ecl.CLEAR_MON: OpName := 'CLEARMONSTERS';
    C_Ecl.PARTY_STR: OpName := 'PARTYSTRENGTH';
    C_Ecl.CHECK_PARTY: OpName := 'CHECKPARTY';
    C_Ecl.NEWECL: OpName := 'NEWECL';
    C_Ecl.LOADFILES: OpName := 'LOAD FILES';
    C_Ecl.LOADPIECES: OpName := 'LOAD PIECES';
    C_Ecl.PARTY_SURPR: OpName := 'PARTY SURPRISE';
    C_Ecl.SURPRISE: OpName := 'SURPRISE';
    C_Ecl.START_COMBAT: OpName := 'COMBAT';
    C_Ecl.ONGOTO: OpName := 'ON GOTO';
    C_Ecl.ONGOSUB: OpName := 'ON GOSUB';
    C_Ecl.TREASURE: OpName := 'TREASURE';
    C_Ecl.ROB: OpName := 'ROB';
    C_Ecl.ENCOUNTER: OpName := 'ENCOUNTER MENU';
    C_Ecl.GETTABLE: OpName := 'GETTABLE';
    C_Ecl.HMENU: OpName := 'HORIZONTAL MENU';
    C_Ecl.PARLAY: OpName := 'PARLAY';
    C_Ecl.CALL: OpName := 'CALL';
    C_Ecl.DAMAGE: OpName := 'DAMAGE';
    C_Ecl.BIT_AND: OpName := 'AND';
    C_Ecl.BIT_OR: OpName := 'OR';
    C_Ecl.SPRITE_OFF: OpName := 'SPRITE OFF';
    C_Ecl.FIND_ITEM: OpName := 'FIND ITEM';
    C_Ecl.PRINT_RET: OpName := 'PRINT RETURN';
    C_Ecl.CLOCK: OpName := 'ECL CLOCK';
    C_Ecl.SAVE_TABLE: OpName := 'SAVE TABLE';
    C_Ecl.ADD_NPC: OpName := 'ADD NPC';
    C_Ecl.RUN_PROGRAM: OpName := 'PROGRAM';
    C_Ecl.WHO: OpName := 'WHO';
    C_Ecl.PAUSE: OpName := 'DELAY';
    C_Ecl.SPELL: OpName := 'SPELL';
    C_Ecl.PROTECTION: OpName := 'PROTECTION';
    C_Ecl.CLEAR_BOX: OpName := 'CLEAR BOX';
  else
    OpName := '?';
  end;
end;

end.
