{ Class-level slots: indexes into TCharRecord.classLevels and the tables kept per slot. A multiclass character has a
  level in each of its classes' slots. }
{$I COMPILER.INC}
unit C_LEVEL;

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
  { the highest level the experience tables reach (Types.TRuleXp.xp) }
  LEVEL_LAST = 9;

implementation

end.
