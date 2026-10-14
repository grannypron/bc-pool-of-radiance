{ Class values (TCharRecord.charClass): single classes 0..7, then multiclass combinations 8..16. A single class's value
  equals its C_Level index. }
unit C_Class;

interface

const
  CLERIC = 0;
  DRUID = 1;
  FIGHTER = 2;
  PALADIN = 3;
  RANGER = 4;
  MAGE = 5;
  THIEF = 6;
  MONK = 7;
  CLERIC_FIGHTER = 8;
  CLERIC_FIGHTER_MAGE = 9;
  CLERIC_RANGER = 10;
  CLERIC_MAGE = 11;
  CLERIC_THIEF = 12;
  FIGHTER_MAGE = 13;
  FIGHTER_THIEF = 14;
  FIGHTER_MAGE_THIEF = 15;
  MAGE_THIEF = 16;

implementation

end.
