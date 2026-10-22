{ The game clock's components. }
{$I COMPILER.INC}
unit C_TIME;

interface

const
  { Game-clock components in C_GBVM.CLOCK word order: indices into TClock and GameDefs.unitScale, and the tUnit argument
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
