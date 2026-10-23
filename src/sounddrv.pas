{ PC-speaker and Tandy SN76489 sound controls and clock delays. SoundCommand selects tunes, output gating and optional
  per-command cleanup. SoundSuspend saves the mode and silences the devices; PlayMusic and StopMusic start and end a
  piece of music; SoundSetAutoStop controls the timer driver's lifetime. The timer stays hooked while a resident window
  (auto-stop 0), a sound command or the music needs it. SOUNDDRV.OBJ owns the timer sequencer, streams and device voice
  state; GameVars holds the current and saved modes and the auto-stop setting. }
{$F+}
{$I COMPILER.INC}
unit SoundDrv;

interface

var
  { Copy of soundMode taken at suspend so the configured mode is not lost. }
  soundSaved: Byte;
  { Nonzero: SoundDrv.SoundCommand waits a fixed delay after each command, then silences the voices and removes its
    timer. Zero leaves the timer driver resident for persistent playback. }
  soundAutoStop: Word;

{ Provides the time base for SoundDelay by reading the DOS clock.
  @returns(Clock time in centiseconds.) }
function SoundTime: LongInt;

{ Paces sound cleanup. While the timer driver is hooked, counts its own ticks, so the wait does not depend on the DOS
  clock, midnight or the BIOS handler the driver chains. Otherwise busy-waits against SoundTime, ending early if a clock
  sample precedes the starting value or after MAX_CLOCK_PASSES samples, so neither a clock discontinuity nor a stopped
  clock can prolong the wait.
  @param(centiseconds Number of centiseconds to wait.) }
procedure SoundDelay(centiseconds: Word);

{ Single entry point for sound effects: mutes or restores output, silences the devices, or starts a tune on whichever
  device is configured. Does nothing when sound is disabled. Every command but CMD_ENABLE ends the music, which does not
  resume. With auto-stop on, hooks the timer driver first, then waits 10 centiseconds before silencing both devices and
  unhooking it.
  @param(cmd 0 silences both devices and disables output, 1 enables output, 255 silences both devices; other values
    select tune cmd minus one for the active device.) }
procedure SoundCommand(cmd: Word);

{ SoundCommand(cmd) for a sound effect of kind group (C_SOUND.GROUP_FOOTSTEPS..), when the Settings screen has that kind
  on (GameVars.soundGroups). }
procedure SoundEffect(cmd: Word; group: Byte);

{ Remembers the configured mode and, unless sound is disabled, ends the music, hooks the timer driver, silences both
  devices and unhooks it again so the game can leave sound idle. }
procedure SoundSuspend;

{ Starts a piece of music on the configured device and keeps the timer driver hooked while it plays. The piece ends by
  itself, or earlier at StopMusic or the next sound effect. Does nothing when sound is disabled, the Music setting is
  off or the tune's own setting is (GameVars.musicGroups).
  @param(tune A music tune, C_SOUND.MUSIC_TITLE and on.) }
procedure PlayMusic(tune: Word);

{ Ends the music now and silences the configured device; unhooks the timer driver unless a resident window holds it. }
procedure StopMusic;

{ @returns(True while the piece PlayMusic started is still playing.) }
function MusicPlaying: Boolean;

{ Ends the music when the Music setting, or the playing tune's own, is now off. }
procedure ApplyMusicSettings;

{ Chooses between a resident timer driver with persistent playback and per-command cleanup that unhooks the driver after
  each sound.
  @param(autoStop Zero installs the timer; nonzero enables fixed-delay cleanup, and a zero-to-nonzero change
    uninstalls it unless music is playing. When sound is disabled the setting is left unchanged.) }
procedure SoundSetAutoStop(autoStop: Word);

{ Loads a tune into the PC-speaker voices, for the speaker's driver (SndSpk).
  @param(tuneId Tune to play; SILENT_TUNE, or an id past the song table, silences the voices.) }
procedure ProgramSpeakerVoices(tuneId: Word);

{ Loads a tune into the Tandy SN76489 voices, for the Tandy's driver (SndTdy).
  @param(tuneId Tune to play; SILENT_TUNE, or an id past the song table, silences the voices.) }
procedure ProgramTandyVoices(tuneId: Word);

{ Writes one AdLib (OPL2) register, with the waits the chip needs after the address and the data, for the AdLib's driver
  (SndOpl).
  @param(reg The register, 01h to 0F5h.)
  @param(value Its new value.) }
procedure OplWrite(reg, value: Word);

{ Clears every OPL2 register and sets up the AdLib's voices: the tone patch on channels 0 to 2 and the noise patch on
  channel 3, all silent, for SndOpl once the chip is found. }
procedure OplReset;

{ Chooses the device the timer driver steps and writes, for a driver that plays some sounds on another device (an effect
  on the speaker beside AdLib music). Leaving the AdLib silences it, and leaving the speaker drops its gate.
  @param(mode A C_SOUND mode; MODE_DISABLED steps none.) }
procedure SetSoundDevice(mode: Word);

implementation

uses C_SOUND, Dos, GameDefs, GameVars{$IFDEF FPC}, SndSeq{$ENDIF};

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
  { Timer driver ticks in 1000 centiseconds: PIT ch0 runs at 1193182 / 5041 = 236.7 Hz while the driver is hooked. }
  TICKS_PER_1000_CS = 2367;
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

{ Gates the sound output without disturbing the loaded tune.
  @param(enabledValue OUTPUT_ENABLED or OUTPUT_DISABLED; only the low byte is used.) }
procedure SetSoundOutputEnabled(enabledValue: Word); external;

{ The timer driver's tick count, which wraps at 65536.
  @returns(Ticks the timer interrupt has run while hooked.) }
function SoundTimerTicks: Word; external;

{ @returns(True while the timer driver owns the timer interrupt.) }
function SoundTimerHooked: Boolean; external;

procedure SetSoundDevice(mode: Word); external;

{ @param(voice A voice, 0 to 3.)
  @returns(The tune that voice is still playing, 0 once its stream has ended.) }
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
    ticks := (LongInt(centiseconds) * TICKS_PER_1000_CS + 500) div 1000;
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
  SoundDrv.ProgramSpeakerVoices(SILENT_TUNE);
  SoundDrv.ProgramTandyVoices(SILENT_TUNE);
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

{ The GameVars.musicGroups bit of tune: C_SOUND.GROUP_TITLE_MUSIC or GROUP_BATTLE_MUSIC, or 0 for a tune with no setting
  of its own. }
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

{ Unhooks the timer on every way out of the program, Halt and run-time errors included: an INT 8 vector left pointing
  into a program that has ended crashes DOS at the next tick. }
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
