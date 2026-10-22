{ Interface states. }
{$I COMPILER.INC}
unit C_IFC;

interface

const
  { Interface states (GameVars.ifcState) }
  { incl. training hall }
  MAIN_MENU = 0;
  SHOP_TEMPLE = 1;
  CAMPING = 2;
  { moving outdoors }
  OUTDOORS = 3;
  { moving indoors }
  INDOORS = 4;
  COMBAT = 5;
  LOOT = 6;
  WON_GAME = 7;
  { in the vault, The Hoarder's Respite (#606) }
  VAULT = 8;

implementation

end.
