{ PC-speaker and Tandy SN76489 sound controls and clock delays. SoundCommand selects tunes, output gating and optional
  per-command cleanup. SoundSuspend saves the mode and silences the devices; PlayMusic and StopMusic start and end a
  piece of music; SoundSetAutoStop controls the timer driver's lifetime. The timer stays hooked while a resident
  window (auto-stop 0), a sound command or the music needs it. SOUNDDRV.OBJ owns the timer sequencer, streams and
  device voice state; GameDat1 holds the current and saved modes and the auto-stop setting. }
{$F+}
unit SoundDrv;

interface

{ * Provides the time base for SoundDelay by reading the DOS clock.
   @returns(Clock time in centiseconds.) }
function SoundTime: LongInt;

{ * Paces sound cleanup. While the timer driver is hooked, counts its own ticks, so the wait does not depend on the
   DOS clock, midnight or the BIOS handler the driver chains. Otherwise busy-waits against SoundTime, ending early if a
   clock sample precedes the starting value or after MAX_CLOCK_PASSES samples, so neither a clock discontinuity nor a
   stopped clock can prolong the wait.
   @param(centiseconds Number of centiseconds to wait.) }
procedure SoundDelay(centiseconds: Word);

{ * Single entry point for sound effects: mutes or restores output, silences the devices, or starts a tune on whichever
   device is configured. Does nothing when sound is disabled. Every command but CMD_ENABLE ends the music, which does
   not resume. With auto-stop on, hooks the timer driver first, then waits 10 centiseconds before silencing both devices
   and unhooking it.
   @param(cmd 0 silences both devices and disables output, 1 enables output, 255 silences both devices; other values
     select tune cmd minus one for the active device.) }
procedure SoundCommand(cmd: Word);

{ * Remembers the configured mode and, unless sound is disabled, ends the music, hooks the timer driver, silences both
   devices and unhooks it again so the game can leave sound idle. }
procedure SoundSuspend;

{ * Starts a piece of music on the configured device and keeps the timer driver hooked while it plays. The piece ends
   by itself, or earlier at StopMusic or the next sound effect. Does nothing when sound is disabled or the Music
   setting is off.
   @param(tune A music tune, C_Sound.MUSIC_TITLE and on.) }
procedure PlayMusic(tune: Word);

{ * Ends the music now and silences the configured device; unhooks the timer driver unless a resident window holds
   it. }
procedure StopMusic;

{ * @returns(True while the piece PlayMusic started is still playing.) }
function MusicPlaying: Boolean;

{ * Chooses between a resident timer driver with persistent playback and per-command cleanup that unhooks the driver
   after each sound.
   @param(autoStop Zero installs the timer; nonzero enables fixed-delay cleanup, and a zero-to-nonzero change
     uninstalls it unless music is playing. When sound is disabled the setting is left unchanged.) }
procedure SoundSetAutoStop(autoStop: Word);

{ * Loads a tune into the PC-speaker voices, for the speaker's driver (SndSpk).
   @param(tuneId Tune to play; SILENT_TUNE, or an id past the song table, silences the voices.) }
procedure ProgramSpeakerVoices(tuneId: Word);

{ * Loads a tune into the Tandy SN76489 voices, for the Tandy's driver (SndTdy).
   @param(tuneId Tune to play; SILENT_TUNE, or an id past the song table, silences the voices.) }
procedure ProgramTandyVoices(tuneId: Word);

{ * Writes one AdLib (OPL2) register, with the waits the chip needs after the address and the data, for the AdLib's
   driver (SndOpl).
   @param(reg The register, 01h to 0F5h.)
   @param(value Its new value.) }
procedure OplWrite(reg, value: Word);

{ * Clears every OPL2 register and sets up the AdLib's voices: the tone patch on channels 0 to 2 and the noise patch
   on channel 3, all silent, for SndOpl once the chip is found. }
procedure OplReset;

{ * Chooses the device the timer driver steps and writes, for a driver that plays some sounds on another device (an
   effect on the speaker beside AdLib music). Leaving the AdLib silences it, and leaving the speaker drops its gate.
   @param(mode A C_Sound mode; MODE_DISABLED steps none.) }
procedure SetSoundDevice(mode: Word);

implementation

uses C_Sound, Dos, GDConsts, GDVars;

var
  { the exit procedure SoundDrv.SoundExit hands on to }
  soundExitSaved: Pointer;
  { the music tune SoundDrv.PlayMusic started; 0 once it is stopped or an effect has ended it }
  musicTune: Word;

const
  { * SoundCommand selector that turns sound output off. }
  CMD_DISABLE = 0;
  { * SoundCommand selector that turns sound output back on. }
  CMD_ENABLE = 1;
  { * SoundCommand selector that stops playback and silences both devices. }
  CMD_STOP = 255;
  { * Tune id that leaves a device's voices silent. }
  SILENT_TUNE = 0;
  { * Value passed to SetSoundOutputEnabled to mute output. }
  OUTPUT_DISABLED = 0;
  { * Value passed to SetSoundOutputEnabled to allow output. }
  OUTPUT_ENABLED = 1;
  { * Timer driver ticks in 1000 centiseconds: PIT ch0 runs at 1193182 / 5041 = 236.7 Hz while the driver is hooked. }
  TICKS_PER_1000_CS = 2367;
  { * SoundTime samples after which an unhooked SoundDelay gives up on a clock that does not move. }
  MAX_CLOCK_PASSES = 60000;

{$L SOUNDDRV.OBJ}
{ * Hooks the timer interrupt so the sequencer runs in the background. Does nothing while it is hooked already. }
procedure InstallSoundTimer; external;

{ * Restores the original timer interrupt and the BIOS timer rate, and silences the speaker and, when it is the
   configured device, the Tandy chip. Does nothing while the timer is not hooked. }
procedure UninstallSoundTimer; external;

procedure ProgramSpeakerVoices(tuneId: Word); external;

procedure ProgramTandyVoices(tuneId: Word); external;

procedure OplWrite(reg, value: Word); external;

procedure OplReset; external;

{ * Gates the sound output without disturbing the loaded tune.
   @param(enabledValue OUTPUT_ENABLED or OUTPUT_DISABLED; only the low byte is used.) }
procedure SetSoundOutputEnabled(enabledValue: Word); external;

{ * The timer driver's tick count, which wraps at 65536.
   @returns(Ticks the timer interrupt has run while hooked.) }
function SoundTimerTicks: Word; external;

{ * @returns(True while the timer driver owns the timer interrupt.) }
function SoundTimerHooked: Boolean; external;

procedure SetSoundDevice(mode: Word); external;

{ * @param(voice A voice, 0 to 3.)
   @returns(The tune that voice is still playing, 0 once its stream has ended.) }
function SoundVoiceTune(voice: Word): Word; external;

{ * Silences both devices' voices, whichever is configured, as the stop commands always have. }
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
  if GDVars.soundMode = C_Sound.MODE_DISABLED then Exit;
  SoundDrv.SetSoundDevice(GDVars.sound.mode);
  if cmd <> CMD_ENABLE then musicTune := 0;
  if GDVars.soundAutoStop > 0 then SoundDrv.InstallSoundTimer;
  case cmd of
    CMD_DISABLE: begin
      SoundDrv.SilenceAll;
      SoundDrv.SetSoundOutputEnabled(OUTPUT_DISABLED);
    end;
    CMD_ENABLE: SoundDrv.SetSoundOutputEnabled(OUTPUT_ENABLED);
    CMD_STOP: SoundDrv.SilenceAll;
  else
    GDVars.sound.Play(cmd - 1);
  end;
  { only CMD_ENABLE leaves music playing, and the music keeps the timer }
  if (GDVars.soundAutoStop > 0) and not SoundDrv.MusicPlaying then begin
    SoundDrv.SoundDelay(10);
    SoundDrv.SilenceAll;
    SoundDrv.UninstallSoundTimer;
  end;
end;

procedure SoundSuspend;
begin
  GDVars.soundSaved := GDVars.soundMode;
  if GDVars.soundMode = C_Sound.MODE_DISABLED then Exit;
  musicTune := 0;
  SoundDrv.SetSoundDevice(GDVars.sound.mode);
  SoundDrv.InstallSoundTimer;
  SoundDrv.ProgramSpeakerVoices(SILENT_TUNE);
  SoundDrv.ProgramTandyVoices(SILENT_TUNE);
  SoundDrv.UninstallSoundTimer;
end;

procedure SoundSetAutoStop(autoStop: Word);
begin
  if GDVars.soundMode = C_Sound.MODE_DISABLED then Exit;
  if autoStop > 0 then begin
    if (GDVars.soundAutoStop = 0) and not SoundDrv.MusicPlaying then SoundDrv.UninstallSoundTimer;
  end else
    SoundDrv.InstallSoundTimer;
  GDVars.soundAutoStop := autoStop;
end;

procedure PlayMusic(tune: Word);
begin
  if (GDVars.soundMode = C_Sound.MODE_DISABLED) or (GDVars.musicOn = 0) then Exit;
  SoundDrv.SetSoundDevice(GDVars.sound.mode);
  SoundDrv.InstallSoundTimer;
  musicTune := tune;
  GDVars.sound.Play(tune);
end;

procedure StopMusic;
begin
  if musicTune = 0 then Exit;
  musicTune := 0;
  if GDVars.soundMode = C_Sound.MODE_DISABLED then Exit;
  GDVars.sound.Play(SILENT_TUNE);
  if GDVars.soundAutoStop > 0 then SoundDrv.UninstallSoundTimer;
end;

function MusicPlaying: Boolean;
begin
  MusicPlaying := (musicTune <> 0) and SoundDrv.SoundTimerHooked and
                  (SoundDrv.SoundVoiceTune(0) = musicTune);
end;

{ * Unhooks the timer on every way out of the program, Halt and run-time errors included: an INT 8 vector left pointing
   into a program that has ended crashes DOS at the next tick. }
procedure SoundExit;
begin
  ExitProc := soundExitSaved;
  SoundDrv.UninstallSoundTimer;
end;

begin
  soundExitSaved := ExitProc;
  ExitProc := @SoundDrv.SoundExit;
end.
