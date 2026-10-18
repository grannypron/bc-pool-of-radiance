{ The sound interrupt's cost (refactor plan, phase 7, step 0): how much of the processor the sequencer's timer
  interrupt takes on one device, while silent and while playing the title music. A busy loop counts for RUN_TICKS BIOS
  ticks with the sound timer off, then on and silent, then on and playing; the cost is the share of the loop's count
  lost. bench/sndbench.sh compiles it and runs it under DOSBox-X at a fixed speed; the first argument is the device,
  T (Tandy) or P (speaker). Each line of SNDBENCH.LOG is the device, the state, the loop count and the cost in
  hundredths of a percent. Only figures taken at the same DOSBox-X speed compare. }
program SndBench;

const
  RUN_TICKS = 54;
  LOG_NAME = 'SNDBENCH.LOG';
  { C_Sound's MODE_TANDY and MODE_SPEAKER }
  MODE_TANDY = 0;
  MODE_SPEAKER = 1;
  MUSIC_TITLE = 21;

var
  biosTicks: LongInt absolute $0040:$006C;
  log: Text;
  dev: Char;
  mode: Word;
  idle: LongInt;
  n: LongInt;
  arg: String;

{$L SOUNDDRV.OBJ}
procedure InstallSoundTimer; external;
procedure UninstallSoundTimer; external;
procedure ProgramSpeakerVoices(tuneId: Word); external;
procedure ProgramTandyVoices(tuneId: Word); external;
procedure SetSoundOutputEnabled(enabledValue: Word); external;
function SoundTimerTicks: Word; external;
function SoundTimerHooked: Boolean; external;
procedure SetSoundDevice(mode: Word); external;
function SoundVoiceTune(voice: Word): Word; external;

{ Count a busy loop for RUN_TICKS BIOS ticks, starting on a tick edge. }
function Count: LongInt;
var
  start: LongInt;
  c: LongInt;
begin
  start := biosTicks;
  repeat until biosTicks <> start;
  start := biosTicks;
  c := 0;
  repeat
    Inc(c);
  until biosTicks - start >= RUN_TICKS;
  Count := c;
end;

{ Log the state's count and its cost against the idle count. }
procedure Report(state: String; c: LongInt);
begin
  WriteLn(log, dev, ' ', state, ' ', c, ' ', Round((1 - c / idle) * 10000));
end;

procedure Play(tune: Word);
begin
  if mode = MODE_TANDY then
    ProgramTandyVoices(tune)
  else
    ProgramSpeakerVoices(tune);
end;

begin
  arg := ParamStr(1) + ' ';
  dev := UpCase(arg[1]);
  if dev = 'T' then
    mode := MODE_TANDY
  else begin
    dev := 'P';
    mode := MODE_SPEAKER;
  end;
  Assign(log, LOG_NAME);
  {$I-}
  Append(log);
  if IOResult <> 0 then
    Rewrite(log);
  {$I+}
  idle := Count;
  Report('off', idle);
  SetSoundDevice(mode);
  InstallSoundTimer;
  Play(0);
  Report('silent', Count);
  Play(MUSIC_TITLE);
  Report('music', Count);
  Play(0);
  UninstallSoundTimer;
  Close(log);
end.
