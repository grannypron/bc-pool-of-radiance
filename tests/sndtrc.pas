{ The trace build of the sound sequencer (SNDTRACE.OBJ, sounddrv.asm assembled with /dTRACE), for the tests: the same
  tunes, voices and device code as SoundDrv's, but each port write is recorded in a buffer instead of reaching the
  hardware, and one timer tick's sequencing can be run on demand. }
unit SndTrc;

interface

{ The device the sequencer ticks: C_Sound's MODE_TANDY, MODE_SPEAKER or MODE_DISABLED. }
procedure SetSoundDevice(mode: Word);

{ Load tune tuneId's speaker or Tandy streams into the voices. }
procedure ProgramSpeakerVoices(tuneId: Word);
procedure ProgramTandyVoices(tuneId: Word);

{ The tune voice (0..3) is playing, 0 once it has run out. }
function SoundVoiceTune(voice: Word): Word;

{ Record the port writes into buf, capacity words (the port's low byte high, the value low), from its start. }
procedure SetTraceBuffer(buf: Pointer; capacity: Word);

{ The words recorded since SetTraceBuffer. }
function TraceCount: Word;

{ One timer tick's sequencing, as the interrupt runs it. }
procedure TraceTick;

implementation

{$L SNDTRACE.OBJ}

procedure SetSoundDevice(mode: Word); external;
procedure ProgramSpeakerVoices(tuneId: Word); external;
procedure ProgramTandyVoices(tuneId: Word); external;
function SoundVoiceTune(voice: Word): Word; external;
procedure SetTraceBuffer(buf: Pointer; capacity: Word); external;
function TraceCount: Word; external;
procedure TraceTick; external;

end.
