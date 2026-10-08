{ Class values (TCharRecord.charClass): single classes 0..7, then multiclass combinations 8..16. }
unit C_Class;

interface

const
  CLERIC = 0;
  DRUID = 1;
  { classLevels indices }
  LEVEL_DRUID = 1;
  FIGHTER = 2;
  PALADIN = 3;
  LEVEL_PALADIN = 3;
  LEVEL_RANGER = 4;
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
  { classLevels indices }
  LEVEL_CLERIC = 0;
  LEVEL_FIGHTER = 2;
  LEVEL_MAGE = 5;
  LEVEL_THIEF = 6;
  LEVEL_MONK = 7;

implementation

end.
