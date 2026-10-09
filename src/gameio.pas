{ Keyboard polling, control-key handling, sound toggling and return to DOS. }
{$F+}
unit GameIo;

interface

uses C_Sound, GDConsts, GDVars, Crt, Dos, SoundDrv;

{ Read a key and process the sound (Ctrl-S) and STING (Ctrl-D, Ctrl-C) controls on that first byte. After a nonzero
  byte, drain pending input without repeating those controls and return the last byte read. An initial zero is returned
  at once, leaving the extended scan byte pending when Crt's Ctrl-Break flag is clear. }
function ReadGameKey: Char;

{ Disabled: return at once without polling the keyboard. The polling loop is kept but unreachable }
procedure PollGameKeys;

{ If input is pending, call ReadGameKey once and discard its result. That call may consume several bytes or leave an
  extended scan byte pending }
procedure DiscardPendingKeys;

{ Restore the saved sound mode, send the stop command, set the saved video mode through the BIOS and exit to DOS. }
procedure ExitGame;

implementation

procedure ExitGame;
begin
  GDVars.soundMode := GDVars.soundSaved;
  SoundDrv.SoundCommand(GDConsts.soundIds.commands[0]);
  GDVars.dsInterruptRegisters.ah := 0;
  GDVars.dsInterruptRegisters.al := GDVars.savedVideoMode;
  Intr($10, GDVars.dsInterruptRegisters);
  Halt(0);
end;

function ReadGameKey: Char;
var
  key: Char;
begin
  key := ReadKey;
  { Ctrl-S toggles sound; a cached extended scan code of 19 (Alt-R) also matches }
  if key = #19 then
    if GDVars.soundMode <> C_Sound.MODE_DISABLED then begin
      GDVars.soundSaved := GDVars.soundMode;
      SoundDrv.SoundCommand(GDConsts.soundIds.commands[0]);
      GDVars.soundMode := C_Sound.MODE_DISABLED;
    end else begin
      if GDVars.soundSaved in [C_Sound.MODE_TANDY, C_Sound.MODE_SPEAKER] then begin
        GDVars.soundMode := GDVars.soundSaved;
        SoundDrv.SoundSuspend;
      end;
    end;
  if ParamStr(1) = 'STING' then begin
    if key = #4 then GDVars.stingHpFlag := Ord(GDVars.stingHpFlag = 0);
    if key = #3 then GameIo.ExitGame;
  end;
  if key <> #0 then
    while KeyPressed do
      key := ReadKey;
  ReadGameKey := key;
end;

procedure PollGameKeys;
var key: Char;
begin
  { Polling is disabled; the loop below is unreachable. }
  Exit;
  while KeyPressed do
    key := GameIo.ReadGameKey;
end;

procedure DiscardPendingKeys;
var key: Char;
begin
  if KeyPressed then
    key := GameIo.ReadGameKey;
end;

begin
end.
