{ Common sound controls and timing routines. GameBoot selects the active driver
  in GameVars.sound: PC speaker, Tandy, AdLib, or Sound Blaster.

  SOUNDDRV.OBJ owns the timer-based sequencer and device state. The timer stays
  installed while music, a sound command, or a resident window needs it. }
{$F+}
{$I COMPILER.INC}
unit SoundDrv;

interface

var
  { Copy of soundMode taken at suspend so the configured mode is not lost. }
  soundSaved: Byte;
  { A nonzero value makes SoundCommand clean up after each command. Zero keeps
    the timer handler installed for persistent playback. }
  soundAutoStop: Word;

{ Returns the DOS clock in centiseconds for SoundDelay. }
function SoundTime: LongInt;

{ Waits for the requested number of centiseconds. Use the sound driver's ticks
  while its timer handler is installed. Otherwise poll the DOS clock, with
  guards against midnight rollover, clock jumps, and a stopped clock. }
procedure SoundDelay(centiseconds: Word);

{ Handles a sound-effect command for the active device. CMD_DISABLE mutes and
  silences both devices, CMD_ENABLE restores output, and CMD_STOP only silences
  them. Other values select tune cmd - 1. Commands other than Enable stop any
  music currently playing. Auto-stop mode removes the timer after a short delay. }
procedure SoundCommand(cmd: Word);

{ Plays cmd when the requested sound-effect group is enabled in Settings. }
procedure SoundEffect(cmd: Word; group: Byte);

{ Saves the configured mode and leaves the sound hardware idle. }
procedure SoundSuspend;

{ Starts a music tune and keeps the timer handler installed while it plays.
  Does nothing when sound, music, or that tune's music group is disabled. A
  sound effect or StopMusic ends the tune early. }
procedure PlayMusic(tune: Word);

{ Stops the music and removes the timer handler unless a resident window still
  needs it. }
procedure StopMusic;

{ Returns True while the tune started by PlayMusic is still running. }
function MusicPlaying: Boolean;

{ Returns True while the timer handler is installed, the PIT then running at its rate rather than the BIOS's. }
function SoundTimerHooked: Boolean;

{ Ends the music when the Music setting, or the playing tune's own, is now off. }
procedure ApplyMusicSettings;

{ Selects persistent playback or per-command cleanup. Zero installs the timer
  handler. A nonzero value removes it after each sound and immediately removes
  an idle persistent handler. Sound-disabled mode leaves the setting alone. }
procedure SoundSetAutoStop(autoStop: Word);

{ Loads tuneId into the PC-speaker voices. SILENT_TUNE and invalid IDs silence
  the voices. }
procedure ProgramSpeakerVoices(tuneId: Word);

{ Loads tuneId into the Tandy voices. SILENT_TUNE and invalid IDs silence the
  voices. }
procedure ProgramTandyVoices(tuneId: Word);

{ Writes an OPL2 register, including the required delays after the address and
  data writes. }
procedure OplWrite(reg, value: Word);

{ Clears the OPL2 and installs the initial silent patches: tones on channels
  0..2 and noise on channel 3. }
procedure OplReset;

{ Selects the device driven by the timer handler. This allows, for example,
  AdLib music with PC-speaker effects. Leaving a device also silences it. }
procedure SetSoundDevice(mode: Word);

implementation

uses C_SOUND, Dos, GameVars{$IFDEF FPC}, SndSeq{$ENDIF};

var
  { the exit procedure SoundDrv.SoundExit hands on to }
  soundExitSaved: Pointer;
  { the music tune SoundDrv.PlayMusic started; 0 once it is stopped or an effect has ended it }
  musicTune: Word;

const
  { SoundCommand selector that turns sound output off. }
  CMD_DISABLE = 0;
  { SoundCommand selector that turns sound output back on. }
  CMD_ENABLE = 1;
  { SoundCommand selector that stops playback and silences both devices. }
  CMD_STOP = 255;
  { Tune id that leaves a device's voices silent. }
  SILENT_TUNE = 0;
  { Value passed to SetSoundOutputEnabled to mute output. }
  OUTPUT_DISABLED = 0;
  { Value passed to SetSoundOutputEnabled to allow output. }
  OUTPUT_ENABLED = 1;
  { SoundTime samples after which an unhooked SoundDelay gives up on a clock that does not move. }
  MAX_CLOCK_PASSES = 60000;

{$IFDEF FPC}
{ The native build's sequencer is Pascal (SndSeq): these forward to it. }
procedure InstallSoundTimer; begin SndSeq.InstallSoundTimer; end;
procedure UninstallSoundTimer; begin SndSeq.UninstallSoundTimer; end;
procedure ProgramSpeakerVoices(tuneId: Word); begin SndSeq.ProgramSpeakerVoices(tuneId); end;
procedure ProgramTandyVoices(tuneId: Word); begin SndSeq.ProgramTandyVoices(tuneId); end;
procedure OplWrite(reg, value: Word); begin SndSeq.OplWrite(reg, value); end;
procedure OplReset; begin SndSeq.OplReset; end;
procedure SetSoundOutputEnabled(enabledValue: Word); begin SndSeq.SetSoundOutputEnabled(enabledValue); end;
function SoundTimerTicks: Word; begin SoundTimerTicks := SndSeq.SoundTimerTicks; end;
function SoundTimerHooked: Boolean; begin SoundTimerHooked := SndSeq.SoundTimerHooked; end;
procedure SetSoundDevice(mode: Word); begin SndSeq.SetSoundDevice(mode); end;
function SoundVoiceTune(voice: Word): Word; begin SoundVoiceTune := SndSeq.SoundVoiceTune(voice); end;
{$ELSE}
{$L SOUNDDRV.OBJ}
{ Hooks the timer interrupt so the sequencer runs in the background. Does nothing while it is hooked already. }
procedure InstallSoundTimer; external;

{ Restores the original timer interrupt and the BIOS timer rate, and silences the speaker and, when it is the configured
  device, the Tandy chip. Does nothing while the timer is not hooked. }
procedure UninstallSoundTimer; external;

procedure ProgramSpeakerVoices(tuneId: Word); external;

procedure ProgramTandyVoices(tuneId: Word); external;

procedure OplWrite(reg, value: Word); external;

procedure OplReset; external;

{ Enables or disables output without changing the loaded tune. Only the low
  byte of enabledValue is used. }
procedure SetSoundOutputEnabled(enabledValue: Word); external;

{ Returns the timer interrupt's tick count, which wraps at 65536. }
function SoundTimerTicks: Word; external;

{ Returns True while the timer handler is installed. }
function SoundTimerHooked: Boolean; external;

procedure SetSoundDevice(mode: Word); external;

{ Returns the tune still playing on voice 0..3, or zero after its stream ends. }
function SoundVoiceTune(voice: Word): Word; external;
{$ENDIF}

{ Silences both devices' voices, whichever is configured, as the stop commands always have. }
procedure SilenceAll;
begin
  SoundDrv.ProgramTandyVoices(SILENT_TUNE);
  SoundDrv.ProgramSpeakerVoices(SILENT_TUNE);
end;

function SoundTime: LongInt;
var
  hour: Word;
  minute: Word;
  second: Word;
  hundredthSecond: Word;
begin
  GetTime(hour, minute, second, hundredthSecond);
  SoundTime := hour * 360000 + LongInt(minute) * 6000 + second * 100 + hundredthSecond;
end;

procedure SoundDelay(centiseconds: Word);
var
  target: LongInt;
  now: LongInt;
  passes: Word;
  ticks: LongInt;
  elapsed: LongInt;
  last: Word;
  sample: Word;
begin
  if SoundDrv.SoundTimerHooked then begin
    { the PIT's clocks in that time over the driver's divisor, rounded: 2.367 ticks a centisecond }
    ticks := (LongInt(centiseconds) * (C_SOUND.PIT_HZ div 100) + C_SOUND.TIMER_DIVISOR div 2) div C_SOUND.TIMER_DIVISOR;
    elapsed := 0;
    last := SoundDrv.SoundTimerTicks;
    while elapsed < ticks do begin
      sample := SoundDrv.SoundTimerTicks;
      elapsed := elapsed + Word(sample - last);
      last := sample;
    end;
    Exit;
  end;
  target := SoundDrv.SoundTime + centiseconds;
  passes := 0;
  repeat
    now := SoundDrv.SoundTime;
    if target - now > centiseconds then now := target + 1;
    Inc(passes);
    if passes = MAX_CLOCK_PASSES then now := target;
  until now >= target;
end;

procedure SoundCommand(cmd: Word);
begin
  if GameVars.soundMode = C_SOUND.MODE_DISABLED then Exit;
  SoundDrv.SetSoundDevice(GameVars.sound.mode);
  if cmd <> CMD_ENABLE then musicTune := 0;
  if soundAutoStop > 0 then SoundDrv.InstallSoundTimer;
  case cmd of
    CMD_DISABLE: begin
      SoundDrv.SilenceAll;
      SoundDrv.SetSoundOutputEnabled(OUTPUT_DISABLED);
    end;
    CMD_ENABLE: SoundDrv.SetSoundOutputEnabled(OUTPUT_ENABLED);
    CMD_STOP: SoundDrv.SilenceAll;
  else
    GameVars.sound.Play(cmd - 1);
  end;
  { only CMD_ENABLE leaves music playing, and the music keeps the timer }
  if (soundAutoStop > 0) and not SoundDrv.MusicPlaying then begin
    SoundDrv.SoundDelay(10);
    SoundDrv.SilenceAll;
    SoundDrv.UninstallSoundTimer;
  end;
end;

procedure SoundSuspend;
begin
  soundSaved := GameVars.soundMode;
  if GameVars.soundMode = C_SOUND.MODE_DISABLED then Exit;
  musicTune := 0;
  SoundDrv.SetSoundDevice(GameVars.sound.mode);
  SoundDrv.InstallSoundTimer;
  SoundDrv.SilenceAll;
  SoundDrv.UninstallSoundTimer;
end;

procedure SoundSetAutoStop(autoStop: Word);
begin
  if GameVars.soundMode = C_SOUND.MODE_DISABLED then Exit;
  if autoStop > 0 then begin
    if (soundAutoStop = 0) and not SoundDrv.MusicPlaying then SoundDrv.UninstallSoundTimer;
  end else
    SoundDrv.InstallSoundTimer;
  soundAutoStop := autoStop;
end;

{ Returns the Settings bit for tune, or zero when the tune has no independent
  music setting. }
function TuneGroup(tune: Word): Byte;
begin
  case tune of
    C_SOUND.MUSIC_TITLE: TuneGroup := C_SOUND.GROUP_TITLE_MUSIC;
    C_SOUND.MUSIC_BATTLE: TuneGroup := C_SOUND.GROUP_BATTLE_MUSIC;
  else
    TuneGroup := 0;
  end;
end;

{ True when the Music setting and tune's own setting let it play. }
function TuneAllowed(tune: Word): Boolean;
begin
  TuneAllowed := (GameVars.musicOn <> 0) and
                 ((SoundDrv.TuneGroup(tune) = 0) or (GameVars.musicGroups and SoundDrv.TuneGroup(tune) <> 0));
end;

procedure SoundEffect(cmd: Word; group: Byte);
begin
  if GameVars.soundGroups and group <> 0 then
    SoundDrv.SoundCommand(cmd);
end;

procedure PlayMusic(tune: Word);
begin
  if (GameVars.soundMode = C_SOUND.MODE_DISABLED) or not SoundDrv.TuneAllowed(tune) then Exit;
  SoundDrv.SetSoundDevice(GameVars.sound.mode);
  SoundDrv.InstallSoundTimer;
  musicTune := tune;
  GameVars.sound.Play(tune);
end;

procedure StopMusic;
begin
  if musicTune = 0 then Exit;
  musicTune := 0;
  if GameVars.soundMode = C_SOUND.MODE_DISABLED then Exit;
  GameVars.sound.Play(SILENT_TUNE);
  if soundAutoStop > 0 then SoundDrv.UninstallSoundTimer;
end;

function MusicPlaying: Boolean;
begin
  MusicPlaying := (musicTune <> 0) and SoundDrv.SoundTimerHooked and
                  (SoundDrv.SoundVoiceTune(0) = musicTune);
end;

procedure ApplyMusicSettings;
begin
  if (musicTune <> 0) and not SoundDrv.TuneAllowed(musicTune) then
    SoundDrv.StopMusic;
end;

{ Always remove the timer handler when the program exits, including after Halt
  or a run-time error. Leaving INT 8 pointed into an unloaded program would
  crash DOS on the next tick. }
procedure SoundExit;
begin
  ExitProc := soundExitSaved;
  SoundDrv.UninstallSoundTimer;
end;

begin
  soundExitSaved := ExitProc;
  ExitProc := @SoundDrv.SoundExit;
  soundSaved := 0;
  soundAutoStop := 0;
end.
