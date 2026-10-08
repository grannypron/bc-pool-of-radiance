{$O+,F+}

{ Heap-allocation failure handler. Forces a save before returning to DOS. Note: recentSaved is not cleared before the
  save attempt, so a flag still set from an earlier save ends the loop after one attempt. }
unit HeapErr;

interface

uses Crt, GDConsts, GDVars, TextRend, GameIo, SaveLoad;

{ ** Installed as the System.HeapError hook so that a failed heap allocation gives the player a chance to save instead
  of crashing with a runtime error. Never returns normally; it always ends by exiting the game.

  @param(size Size in bytes of the failed request. Unused.)
  @returns(Nothing meaningful, since the game exits before returning.) }
function HeapErrorHandler(size: Word): Integer;

implementation

{ ** Forces the player to save the game before exiting. Repeats the save prompt until a save succeeds, so progress is
  not lost to the out-of-memory condition, then quits to DOS.

  @param(size Size in bytes of the failed request. Unused.)
  @returns(Nothing meaningful, since the game exits before returning.) }
function HeapErrorHandler(size: Word): Integer;
begin
  repeat
    TextRend.DisplayAndPause(Yellow, 'Time to save your game.  [return]');
    SaveLoad.SaveGame;
  until GDVars.recentSaved <> 0;

  GameIo.ExitGame;
end;

begin
  HeapError := @HeapErr.HeapErrorHandler;
end.
