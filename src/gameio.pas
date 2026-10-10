{ Keyboard polling, control-key handling, sound toggling and return to DOS. }
{$F+}
unit GameIo;

interface

uses C_Sound, GDConsts, GDVars, Crt, Dos, SoundDrv;

type
  TSettingsHook = procedure;

var
  { Options.LoadOptions sets it to Options.SaveOptions once POOLOPT.CFG has been read; Ctrl-S calls it to write the
    Sound setting back. GameIo starts before the overlay manager and cannot use the overlaid Options itself. }
  saveSettings: TSettingsHook;

{ Read a key and process the sound (Ctrl-S) and STING (Ctrl-D, Ctrl-C) controls on that first byte. After a nonzero
  byte, drain pending input without repeating those controls and return the last byte read. An initial zero is returned
  at once, leaving the extended scan byte pending when Crt's Ctrl-Break flag is clear. Ctrl-S turns the Sound setting
  over (SetSound) and, once POOLOPT.CFG has been read, writes it back (saveSettings). }
function ReadGameKey: Char;

{ Turn sound on or off, as Ctrl-S does, and keep the Sound setting (GDVars.soundOn) in step. Off sends the stop command
  and disables soundMode, keeping the device in soundSaved; on restores the device. Without a sound device (POOL.CFG
  names none) nothing changes. }
procedure SetSound(turnOn: Boolean);

{ If input is pending, call ReadGameKey once and discard its result. That call may consume several bytes; an extended
  key's scan byte is then read and discarded too, so it is not taken for Ctrl-S. }
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
  if key = #19 then begin
    GameIo.SetSound(GDVars.soundMode = C_Sound.MODE_DISABLED);
    if @saveSettings <> nil then
      saveSettings;
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

procedure SetSound(turnOn: Boolean);
begin
  if not (GDVars.soundSaved in [C_Sound.MODE_TANDY, C_Sound.MODE_SPEAKER]) then Exit;
  if not turnOn then begin
    if GDVars.soundMode <> C_Sound.MODE_DISABLED then begin
      SoundDrv.SoundCommand(GDConsts.soundIds.commands[0]);
      GDVars.soundMode := C_Sound.MODE_DISABLED;
    end;
  end else if GDVars.soundMode = C_Sound.MODE_DISABLED then begin
    GDVars.soundMode := GDVars.soundSaved;
    SoundDrv.SoundSuspend;
  end;
  GDVars.soundOn := Ord(turnOn);
end;

procedure DiscardPendingKeys;
var key: Char;
begin
  if KeyPressed then begin
    key := GameIo.ReadGameKey;
    if (key = #0) and KeyPressed then
      key := ReadKey;
  end;
end;

end.
