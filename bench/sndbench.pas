{ Measures the CPU cost of the sound sequencer's timer interrupt. A busy loop
  runs with the timer disabled, enabled but silent, and playing the title music.
  The reduction in loop iterations gives the interrupt's cost.

  bench/sndbench.sh runs this program in DOSBox-X at a fixed speed. Pass T for
  Tandy or P for PC speaker. SNDBENCH.LOG records the device, state, loop count,
  and cost in hundredths of a percent. Results are comparable only when they
  were measured at the same DOSBox-X speed. }
program SndBench;

const
  RUN_TICKS = 54;
  LOG_NAME = 'SNDBENCH.LOG';
  { C_SOUND's MODE_TANDY and MODE_SPEAKER }
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

{ Counts busy-loop iterations for RUN_TICKS complete BIOS ticks. }
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

{ Logs the loop count and its cost relative to the idle measurement. }
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
