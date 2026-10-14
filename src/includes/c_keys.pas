{ Menu key values. Enter, Escape and Backspace are ASCII; the arrow, Home and End keys and the group marked extended
  are BIOS extended scan codes, returned with the menu routines' extended-key flag set (ALT_Q is Q's scan code, not
  Ctrl-P). }
unit C_Keys;

interface

const
  ENTER = #13;
  ESC = #27;
  BACKSPACE = #8;
  UP = #72;
  DOWN = #80;
  LEFT = #75;
  RIGHT = #77;
  HOME = #71;
  END_KEY = #79;
  { Menu result meaning no selection: MenuCore.MenuHorizontal and MenuVertical return it for Escape, and MenuVertical
    also for Exit or an empty list. }
  NONE = #0;
  { extended scan codes }
  PGUP = #73;
  PGDN = #81;
  ALT_Q = #16;
  ALT_R = #19;
  ALT_X = #45;
  ALT_M = #50;
  { quick save and quick load, on the map menu }
  F5 = #63;
  F8 = #66;

implementation

end.
