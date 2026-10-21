{ The text window's message area: its first and last column and its bottom and top row. }
{$I COMPILER.INC}
unit C_Msg;

interface

const
  TEXT_LEFT = 1;
  TEXT_TOP = 1;
  TEXT_RIGHT = 38;
  TEXT_BOTTOM = 22;
  MESSAGE_TOP = 17;
  { the combat message panel, right of the arena: from COMBAT_LEFT to TEXT_RIGHT, its messages from COMBAT_MESSAGE_TOP
    down to COMBAT_BOTTOM }
  COMBAT_LEFT = 23;
  COMBAT_MESSAGE_TOP = 10;
  COMBAT_BOTTOM = 21;

implementation

end.
