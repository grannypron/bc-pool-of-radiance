{ The game clock's components. }
{$I COMPILER.INC}
unit C_Time;

interface

const
  { Game-clock components in C_Gbvm.CLOCK word order: indices into TClock and GDConsts.unitScale, and the tUnit argument
    of FxEngine.AdvanceTime }
  SEGMENTS = 0;
  MINUTES = 1;
  { ten minutes }
  TURNS = 2;
  HOURS = 3;
  DAYS = 4;
  MONTHS = 5;
  YEARS = 6;

implementation

end.
