{ Keyboard polling, control-key handling, sound toggling and return to DOS. }
{$F+}
{$I COMPILER.INC}
unit GameIo;

interface

type
  TSettingsHook = procedure;

var
  { Options.LoadOptions sets it to Options.SaveOptions once POOLOPT.CFG has been read; Ctrl-S calls it to write the
    Sound setting back. GameIo starts before the overlay manager and cannot use the overlaid Options itself. }
  saveSettings: TSettingsHook;
  { STING Ctrl-Y's memory display, MemShow.ShowMemory, which GameInit installs: it draws with TextRend, which GameIo
    cannot use without a unit cycle. }
  showMemory: TSettingsHook;
  { BeastFil.Flush, which GameInit installs: ExitGame writes the Bestiary's knowledge before the game ends (#842). }
  beforeExit: TSettingsHook;
  debugFile: Text;

{ Read a key and process the sound (Ctrl-S) and STING (Ctrl-D, Ctrl-L, Ctrl-Z, Ctrl-Y, Ctrl-C) controls on that first
  byte. After a nonzero byte, drain pending input without repeating those controls and return the last plain key read
  (an extended key in it is dropped whole, #0 and scan byte, so no scan byte is returned as a key). An initial zero is
  returned at once, leaving the extended scan byte pending when Crt's Ctrl-Break flag is clear; the next call returns
  that scan byte without the controls, so an extended key whose scan code matches one (Alt-R is 19, as Ctrl-S) does not
  run it (#736, #764). Ctrl-S turns the Sound setting over (SetSound) and, once POOLOPT.CFG has been read, writes it
  back (saveSettings). In the demo (GameVars.demoMode) it never waits: the demo reaches no wait for a key, so a call
  there comes from a key pressed (or a wait nobody foresaw) and ends the demo (GameVars.demoAbort), draining what is
  pending and returning Escape. }
function ReadGameKey: Char;

{ In the demo (GameVars.demoMode): True once it is to end, which a key pressed sets (GameVars.demoAbort), leaving the
  key unread. False outside the demo. }
function DemoEnding: Boolean;

{ ReadGameKey for a wait on one key: an extended key's scan byte is read too and dropped, so the next read does not take
  it for a typed key (after STING Ctrl-Y's last wait the menu took the next arrow for its scan byte's letter, #768).
  Returns #0 for an extended key. }
function ReadAnyKey: Char;

{ Turn sound on or off, as Ctrl-S does, and keep the Sound setting (GameVars.soundOn) in step. Off sends the stop
  command and disables soundMode, keeping the device in soundSaved; on restores the device. Without a sound device
  (POOL.CFG names none) nothing changes. }
procedure SetSound(turnOn: Boolean);

{ If input is pending, call ReadAnyKey once and discard its result. That call may consume several bytes; an extended
  key's scan byte is read and discarded too, so it is not taken for Ctrl-S. }
procedure DiscardPendingKeys;

{ Write what the Bestiary has learned (beforeExit), close the STING trace log if it is open, restore the saved sound
  mode, send the stop command, set the saved video mode through the BIOS and exit to DOS. }
procedure ExitGame;

{ Quit on an error the game cannot go on from: the text mode the game started in (GameVars.savedVideoMode, set directly,
  not through Blit.RestoreVideoMode, which would swap it with the game's mode), msg, a key, then ExitGame, which leaves
  DOS in that text mode (#641). }
procedure FatalError(msg: String);

implementation

uses C_KEYS, C_SOUND, GameDefs, GameVars, Crt, Dos, SoundDrv, Types{$IFDEF FPC}, Host, NatFile{$ENDIF};

var
  { showMemory is up: its own key waits do not open it again }
  memShown: Boolean;
  { the last byte ReadGameKey returned was #0: the next is an extended key's scan byte }
  scanPending: Boolean;

{ Set the video mode the game started in (GameVars.savedVideoMode) through the BIOS. }
procedure SetStartMode;
begin
  GameVars.interruptRegisters.ah := 0;
  GameVars.interruptRegisters.al := GameVars.savedVideoMode;
  Intr($10, GameVars.interruptRegisters);
end;

procedure ExitGame;
var
  hook: TSettingsHook;
begin
  { cleared first, so an exit from inside it does not run it again }
  hook := beforeExit;
  @beforeExit := nil;
  if @hook <> nil then
    hook;
  if GameVars.debugTraceEnabled then
    Close(debugFile);
  GameVars.soundMode := SoundDrv.soundSaved;
  SoundDrv.SoundCommand(GameDefs.soundIds.commands[0]);
  GameIo.SetStartMode;
  Halt(0);
end;

procedure FatalError(msg: String);
var
  key: Char;
begin
  GameIo.SetStartMode;
  WriteLn(msg);
  key := GameIo.ReadAnyKey;
  GameIo.ExitGame;
end;

{ STING Ctrl-Z, as Curse does: each creature's effects to the trace log, one 'who: <name>  sp#: <id>' line each. }
procedure DumpEffects;
var
  p: Types.PCharRecord;
  e: Types.PEffectRec;
begin
  p := GameVars.creatureList;
  while p <> nil do begin
    e := p^.effectsAddr;
    while e <> nil do begin
      WriteLn(debugFile, 'who: ', p^.name, '  sp#: ', e^.id);
      e := e^.next;
    end;
    p := p^.nextCharAddr;
  end;
end;

function ReadGameKey: Char;
var
  key: Char;

  { Discard type-ahead, keeping the newest plain key in key; an extended key goes whole, its #0 and its scan byte }
  procedure DropTypeAhead;
  var
    k: Char;
  begin
    while KeyPressed do begin
      k := ReadKey;
      if k = #0 then begin
        if KeyPressed then k := ReadKey;
      end else
        key := k;
    end;
  end;

begin
  if GameVars.demoMode then begin
    GameVars.demoAbort := True;
    key := C_KEYS.ESCAPE;
    DropTypeAhead;
    scanPending := False;
    ReadGameKey := C_KEYS.ESCAPE;
    Exit;
  end;
  key := ReadKey;
  if scanPending then begin
    scanPending := False;
    DropTypeAhead;
    ReadGameKey := key;
    Exit;
  end;
  scanPending := (key = #0) and KeyPressed;
  if key = C_KEYS.CTRL_S then begin
    GameIo.SetSound(GameVars.soundMode = C_SOUND.MODE_DISABLED);
    if @saveSettings <> nil then
      saveSettings;
  end;
  if GameVars.stingArg then begin
    if key = C_KEYS.CTRL_D then GameVars.stingHpFlag := Ord(GameVars.stingHpFlag = 0);
    if key = C_KEYS.CTRL_C then GameIo.ExitGame;
    { the script trace log, Curse's Ctrl-D (here Ctrl-D stays the hit-point pop-up) }
    if key = C_KEYS.CTRL_L then begin
      GameVars.debugTraceEnabled := not GameVars.debugTraceEnabled;
      if GameVars.debugTraceEnabled then begin
        Assign(debugFile, 'debug.txt');
        {$I-}
        Rewrite(debugFile);
        {$I+}
        if IOResult <> 0 then
          GameVars.debugTraceEnabled := False;
      end else
        Close(debugFile);
    end;
    if (key = C_KEYS.CTRL_Z) and GameVars.debugTraceEnabled then
      GameIo.DumpEffects;
    if (key = C_KEYS.CTRL_Y) and not memShown and (@showMemory <> nil) then begin
      memShown := True;
      showMemory;
      memShown := False;
    end;
  end;
  if key <> #0 then
    DropTypeAhead;
  ReadGameKey := key;
end;

function DemoEnding: Boolean;
begin
  if GameVars.demoMode and not GameVars.demoAbort and KeyPressed then
    GameVars.demoAbort := True;
  DemoEnding := GameVars.demoMode and GameVars.demoAbort;
end;

function ReadAnyKey: Char;
var
  key: Char;
  scan: Char;
begin
  key := GameIo.ReadGameKey;
  if (key = #0) and scanPending then begin
    scan := ReadKey;
    scanPending := False;
  end;
  ReadAnyKey := key;
end;

procedure SetSound(turnOn: Boolean);
begin
  if GameVars.sound.mode = C_SOUND.MODE_DISABLED then Exit;
  if not turnOn then begin
    if GameVars.soundMode <> C_SOUND.MODE_DISABLED then begin
      SoundDrv.SoundCommand(GameDefs.soundIds.commands[0]);
      GameVars.soundMode := C_SOUND.MODE_DISABLED;
    end;
  end else if GameVars.soundMode = C_SOUND.MODE_DISABLED then begin
    GameVars.soundMode := SoundDrv.soundSaved;
    SoundDrv.SoundSuspend;
  end;
  GameVars.soundOn := Ord(turnOn);
end;

procedure DiscardPendingKeys;
var
  key: Char;
begin
  if KeyPressed then
    key := GameIo.ReadAnyKey;
end;

begin
  memShown := False;
  scanPending := False;
  { the hooks start unset: global variables are not cleared at startup }
  @saveSettings := nil;
  @showMemory := nil;
  @beforeExit := nil;
end.
