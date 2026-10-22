{ Money types. }
{$I COMPILER.INC}
unit C_Money;

interface

const
  { Money types: the indexes of TMoney and of a character's coins }
  COPPER = 0;
  SILVER = 1;
  ELECTRUM = 2;
  GOLD = 3;
  PLATINUM = 4;
  GEMS = 5;
  JEWELRY = 6;
  { the most of one type a character holds: its coins are Words }
  MAX_COINS = 65535;

implementation

end.
