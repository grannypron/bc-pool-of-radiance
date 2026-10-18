{ The AdLib (OPL2) sound driver: the sequencer's Tandy arrangements, played as FM through the OPL2 by SOUNDDRV.OBJ's
  timer driver (sndopl.inc). GameBoot installs it when POOL.CFG names A; with no OPL2 answering at ports 388h and 389h
  the speaker's driver is installed instead, and the settings screen says so (phase 7 of docs/refactor-plan.md). }
{$F+}
unit SndOpl;

interface

{ Make this the sound driver if an OPL2 answers, else the speaker's: fill GDVars.sound. }
procedure Install;

{ True when an OPL2 answers: its first timer, started, sets the status port's timer flags, and was clear before. }
function Detect: Boolean;

implementation

uses C_Sound, GDVars, SoundDrv, SndSpk;

const
  OPL_STATUS = $388;
  { status port bits: an interrupt, and timers 1 and 2 expired }
  STATUS_FLAGS = $E0;
  { the flags timer 1 sets }
  TIMER1_DONE = $C0;
  { timer control (04h): reset both timers' flags, then reset the interrupt; start timer 1 }
  TIMER_RESET = $60;
  IRQ_RESET = $80;
  TIMER1_START = $21;
  { status reads spent waiting for timer 1 (80 us a count, from FFh one count) }
  TIMER_WAIT = 200;

function Detect: Boolean;
var
  before: Byte;
  after: Byte;
  i: Word;
begin
  SoundDrv.OplWrite($04, TIMER_RESET);
  SoundDrv.OplWrite($04, IRQ_RESET);
  before := Port[OPL_STATUS];
  SoundDrv.OplWrite($02, $FF);
  SoundDrv.OplWrite($04, TIMER1_START);
  for i := 1 to TIMER_WAIT do
    after := Port[OPL_STATUS];
  after := Port[OPL_STATUS];
  SoundDrv.OplWrite($04, TIMER_RESET);
  SoundDrv.OplWrite($04, IRQ_RESET);
  Detect := (before and STATUS_FLAGS = 0) and (after and STATUS_FLAGS = TIMER1_DONE);
end;

{ Load tune into the Tandy voices, which the AdLib plays. }
procedure Play(tune: Word);
begin
  SoundDrv.ProgramTandyVoices(tune);
end;

procedure Install;
begin
  if SndOpl.Detect then begin
    SoundDrv.OplReset;
    GDVars.sound.name := 'AdLib';
    GDVars.sound.mode := C_Sound.MODE_ADLIB;
    GDVars.sound.Play := SndOpl.Play;
  end else begin
    SndSpk.Install;
    GDVars.sound.name := 'Speaker (no AdLib)';
  end;
end;

end.
