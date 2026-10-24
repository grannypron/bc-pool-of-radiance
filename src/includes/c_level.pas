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
  { One bit per slot, 1 shl the slot: the class masks CharHlp.GetClassLevel takes and TCharExt.formerClasses holds.
    (GameDefs.classBit is the training hall's, which gives several classes one bit.) }
  CLERIC_BIT = $01;
  DRUID_BIT = $02;
  FIGHTER_BIT = $04;
  PALADIN_BIT = $08;
  RANGER_BIT = $10;
  MAGE_BIT = $20;
  THIEF_BIT = $40;
  MONK_BIT = $80;
  { the classes that fight as warriors (CharHlp.WarriorLevel), and every class }
  WARRIOR_BITS = FIGHTER_BIT + PALADIN_BIT + RANGER_BIT;
  ALL_BITS = $FF;

implementation

end.
