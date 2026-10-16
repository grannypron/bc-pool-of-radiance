{ Keyboard polling, control-key handling, sound toggling and return to DOS. }
{$F+}
unit GameIo;

interface

type
  TSettingsHook = procedure;

var
  { Options.LoadOptions sets it to Options.SaveOptions once POOLOPT.CFG has been read; Ctrl-S calls it to write the
    Sound setting back. GameIo starts before the overlay manager and cannot use the overlaid Options itself. }
  saveSettings: TSettingsHook;
  { STING Ctrl-Y's memory display, Debug.ShowMemory, which GameInit installs; the overlaid Debug draws with TextRend,
    which GameIo cannot use without a unit cycle. }
  showMemory: TSettingsHook;

{ Read a key and process the sound (Ctrl-S) and STING (Ctrl-D, Ctrl-L, Ctrl-Z, Ctrl-Y, Ctrl-C) controls on that first
  byte. After a nonzero
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

uses C_Sound, GDConsts, GDVars, Crt, Dos, SoundDrv, Types;

var
  { showMemory is up: its own key waits do not open it again }
  memShown: Boolean;

procedure ExitGame;
begin
  if GDVars.debugTraceEnabled then
    Close(GDVars.debugFile);
  GDVars.soundMode := GDVars.soundSaved;
  SoundDrv.SoundCommand(GDConsts.soundIds.commands[0]);
  GDVars.dsInterruptRegisters.ah := 0;
  GDVars.dsInterruptRegisters.al := GDVars.savedVideoMode;
  Intr($10, GDVars.dsInterruptRegisters);
  Halt(0);
end;

{ STING Ctrl-Z, as Curse does: each creature's effects to the trace log, one 'who: <name>  sp#: <id>' line each. }
procedure DumpEffects;
var
  p: Types.PCharRecord;
  e: Types.PEffectRec;
begin
  p := GDVars.creatureList;
  while p <> nil do begin
    e := p^.effectsAddr;
    while e <> nil do begin
      WriteLn(GDVars.debugFile, 'who: ', p^.name, '  sp#: ', e^.id);
      e := e^.next;
    end;
    p := p^.nextCharAddr;
  end;
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
  if GDVars.stingArg then begin
    if key = #4 then GDVars.stingHpFlag := Ord(GDVars.stingHpFlag = 0);
    if key = #3 then GameIo.ExitGame;
    { Ctrl-L: the script trace log, Curse's Ctrl-D (here Ctrl-D stays the hit-point pop-up) }
    if key = #12 then begin
      GDVars.debugTraceEnabled := not GDVars.debugTraceEnabled;
      if GDVars.debugTraceEnabled then begin
        Assign(GDVars.debugFile, 'debug.txt');
        {$I-}
        Rewrite(GDVars.debugFile);
        {$I+}
        if IOResult <> 0 then
          GDVars.debugTraceEnabled := False;
      end else
        Close(GDVars.debugFile);
    end;
    if (key = #26) and GDVars.debugTraceEnabled then
      GameIo.DumpEffects;
    if (key = #25) and not memShown and (@showMemory <> nil) then begin
      memShown := True;
      showMemory;
      memShown := False;
    end;
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

begin
  memShown := False;
end.
