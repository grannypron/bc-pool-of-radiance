{ Saving-throw categories. }
{$I COMPILER.INC}
unit C_Save;

interface

const
  { Saving-throw categories in AD&D 1e order: indices into TCharRecord.saves and the saveType argument of
    FxEngine.RollSavingThrow }
  { paralyzation / poison / death magic }
  PARALYZE = 0;
  { petrification / polymorph }
  PETRIFY = 1;
  { Saving-throw category (TCharRecord.saves index): rod / staff / wand }
  WAND = 2;
  { breath weapon }
  BREATH = 3;
  { spell }
  SPELL = 4;

implementation

end.
