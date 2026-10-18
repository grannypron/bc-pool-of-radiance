{$I COMPILER.INC}
{ The native build's sound sequencer: the Pascal counterpart of sounddrv.asm, whose routines SoundDrv forwards to here.
  For now it is silent and never hooks a timer, so SoundDrv's waits run on the clock instead (SoundDelay's unhooked
  path); the port of the asm sequencer and its devices (speaker, Tandy, OPL, mixed into SDL's audio) replaces it.
  Free Pascal only. }
unit SndSeq;

interface

procedure InstallSoundTimer;
procedure UninstallSoundTimer;
procedure ProgramSpeakerVoices(tuneId: Word);
procedure ProgramTandyVoices(tuneId: Word);
procedure OplWrite(reg, value: Word);
procedure OplReset;
procedure SetSoundOutputEnabled(enabledValue: Word);
function SoundTimerTicks: Word;
function SoundTimerHooked: Boolean;
procedure SetSoundDevice(mode: Word);
function SoundVoiceTune(voice: Word): Word;

implementation

procedure InstallSoundTimer;
begin
end;

procedure UninstallSoundTimer;
begin
end;

procedure ProgramSpeakerVoices(tuneId: Word);
begin
end;

procedure ProgramTandyVoices(tuneId: Word);
begin
end;

procedure OplWrite(reg, value: Word);
begin
end;

procedure OplReset;
begin
end;

procedure SetSoundOutputEnabled(enabledValue: Word);
begin
end;

function SoundTimerTicks: Word;
begin
  SoundTimerTicks := 0;
end;

function SoundTimerHooked: Boolean;
begin
  SoundTimerHooked := False;
end;

procedure SetSoundDevice(mode: Word);
begin
end;

function SoundVoiceTune(voice: Word): Word;
begin
  SoundVoiceTune := 0;
end;

end.
