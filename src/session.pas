unit Session;

{ Indexed view of GameDat1's four game-memory VM buffer pointers: three word banks and the ECL script bytes. }

interface

uses GDConsts, GDVars;

var
  { Indices 0..2 are the word banks zone0..zone2 and 3 is the script buffer zone3. GameInit allocates them (2048, 2048,
    1024 and 9984 bytes, SizeOf each zone) and clears them through this view, which adds no storage. }
  dsGbvmZones: array[0..3] of Pointer absolute GDVars.zone0;

implementation

end.
