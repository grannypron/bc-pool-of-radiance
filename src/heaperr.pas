{ Heap-allocation failure handler: it frees a reserve kept for the purpose and offers the player a save before the game
  quits to DOS (#643). }
{$O+,F+}
{$I COMPILER.INC}
unit HeapErr;

interface

{ System.HeapError hook. A failed allocation frees the emergency reserve and
  gives the player a chance to save before exiting. A zero-byte request, or an
  allocation that fails while the handler is already running, returns 0 to the
  heap manager. Any other call exits the game instead of returning. }
function HeapErrorHandler(size: Word): Integer;

{ Take the reserve the save needs once the heap is exhausted: Vault's copy buffer, a new statistics block and the menu
  nodes. GameInit2 calls it once the overlay buffer is set up, which needs the heap empty. }
procedure KeepReserve;

implementation

uses Crt, C_KEYS, GameVars, SaveLoad, GameIo, TextRend;

const
  RESERVE_BYTES = 4096;

var
  { the reserve, nil until KeepReserve and once the handler has freed it }
  reserve: Pointer;
  { set while the handler runs, so a failure inside it does not run it again }
  handling: Boolean;

procedure KeepReserve;
begin
  if reserve = nil then
    GetMem(reserve, RESERVE_BYTES);
end;

{ Handles an allocation failure. Free the reserve, then keep asking until the
  player saves or chooses to quit. Backing out of the save menu or failing to
  save returns to the prompt. The game exits to DOS either way. }
function HeapErrorHandler(size: Word): Integer;
var
  ch: Char;
  done: Boolean;
begin
  HeapErrorHandler := 0;
  if (size = 0) or handling then Exit;
  handling := True;
  if reserve <> nil then begin
    FreeMem(reserve, RESERVE_BYTES);
    reserve := nil;
  end;
  done := False;
  repeat
    TextRend.ClearBottomLine;
    TextRend.DisplayString(0, 24, Yellow, 'OUT OF MEMORY: ENTER SAVES, ESC QUITS');
    GameIo.DiscardPendingKeys;
    repeat
      { an extended key's scan byte is read and passed over }
      ch := GameIo.ReadAnyKey;
    until (ch = C_KEYS.ENTER) or (ch = C_KEYS.ESCAPE);
    if ch = C_KEYS.ESCAPE then
      done := True
    else begin
      done := SaveLoad.SaveGame;
    end;
  until done;
  GameIo.ExitGame;
end;

begin
  reserve := nil;
  handling := False;
  { Free Pascal has no HeapError hook, and a native heap runs out only when the machine does }
{$IFNDEF FPC}
  HeapError := @HeapErr.HeapErrorHandler;
{$ENDIF}
end.
