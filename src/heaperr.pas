{$O+,F+}

{ Heap-allocation failure handler. When heapFailureSaveEnabled is nonzero it forces a save before returning to DOS. }
unit HeapErr;

interface

uses Crt, GDConsts, GDVars, SaveLoad;

{ ** Installed as the System.HeapError hook so that a failed heap allocation gives the player a chance to save instead
  of crashing with a runtime error. Never returns normally when a real allocation failed; it ends by exiting the game.

  @param(size Size in bytes of the failed request. Zero requests are ignored.)
  @returns(Nothing meaningful, since the game exits before returning.) }
function HeapErrorHandler(size: Word): Integer;

implementation

{ ** Warns the player about the low-memory condition and, when heap-failure saving is enabled, forces a save (repeating
  until one succeeds) before quitting to DOS. When saving is disabled it just reports the failure and exits.

  @param(size Size in bytes of the failed request. Zero requests are ignored.)
  @returns(Nothing meaningful, since the game exits before returning. Note: for a zero request the result is never
  set.) }
function HeapErrorHandler(size: Word): Integer;
var
  { ** Loop terminator: set once a save succeeded or saving is disabled. }
  exitFlag: Byte;
begin
  if size > 0 then begin
    exitFlag := 0;

    repeat
      TextRend.DisplayAndPause(Yellow, 'WARNING: Insufficient Memory');
      if GDVars.heapFailureSaveEnabled <> 0 then begin
        {* Attempt to save the game. Throws up the save game menu. *}
        GDVars.recentSaved := 0;
        SaveLoad.SaveGame;
        exitFlag := GDVars.recentSaved;
      end else begin
        exitFlag := 1;
        TextRend.DisplayAndPause(Yellow, 'Insufficient Memory. Exiting Program');
      end;
    until exitFlag <> 0;

    GameIo.ExitGame;
  end;
end;

begin
  HeapError := @HeapErr.HeapErrorHandler;
end.
