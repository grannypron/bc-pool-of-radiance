{ Menu key values. Enter, Escape and Backspace are ASCII; the arrow, Home and End keys and the group marked extended
  are BIOS extended scan codes, returned with the menu routines' extended-key flag set (ALT_Q is Q's scan code, not
  Ctrl-P). }
{$I COMPILER.INC}
unit C_KEYS;

interface

const
  ENTER = #13;
  ESCAPE = #27;
  BACKSPACE = #8;
  TAB = #9;
  { the control keys GameIo.ReadGameKey acts on: Ctrl-S turns the sound over; the rest are STING's (Ctrl-C quits,
    Ctrl-D the hit-point pop-up, Ctrl-L the script trace log, Ctrl-Y the memory display, Ctrl-Z the effects dump) }
  CTRL_C = #3;
  CTRL_D = #4;
  CTRL_L = #12;
  CTRL_S = #19;
  CTRL_Y = #25;
  CTRL_Z = #26;
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
  PAGE_UP = #73;
  PAGE_DOWN = #81;
  ALT_Q = #16;
  ALT_X = #45;
  ALT_M = #50;
  { the Command Keys window (#855), on the map and camp menus }
  F1 = #59;
  { the Bestiary (#842), on the map and camp menus }
  F2 = #60;
  { quick save and quick load, on the map menu }
  F5 = #63;
  { the Companion Tools (phase 8), when the setting is on }
  F6 = #64;
  { the combat log (#841), in combat; its scan code is the character code of 'A' }
  F7 = #65;
  F8 = #66;
  { POOLCFG (#876): F10 saves and leaves, and its line editor's Insert and Delete }
  F10 = #68;
  INS = #82;
  DEL = #83;

implementation

end.
