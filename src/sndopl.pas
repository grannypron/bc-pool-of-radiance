{ AdLib (OPL2) sound driver. The timer sequencer plays the Tandy music
  arrangements through the OPL2 while effects use the PC speaker. GameBoot
  installs this driver for AdLib sound and as Sound Blaster's fallback. If no
  OPL2 responds at ports 388h/389h, Install falls back to the speaker driver. }
{$F+}
{$I COMPILER.INC}
unit SndOpl;

interface

{ Installs this driver when an OPL2 responds, or the speaker driver otherwise. }
procedure Install;

{ Plays music through the AdLib and effects through the speaker. SndSb also
  uses this for effects without a recorded sample. }
procedure Play(tune: Word);

{ Detects an OPL2 by checking that timer 1 changes the expected status bits. }
function Detect: Boolean;

implementation

uses C_SOUND, GameVars, SoundDrv, SndSpk{$IFDEF FPC}, PortIO{$ENDIF};

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
  { the waiting reads, which only spend time }
  spent: Byte;
  i: Word;
begin
  SoundDrv.OplWrite($04, TIMER_RESET);
  SoundDrv.OplWrite($04, IRQ_RESET);
  before := Port[OPL_STATUS];
  SoundDrv.OplWrite($02, $FF);
  SoundDrv.OplWrite($04, TIMER1_START);
  for i := 1 to TIMER_WAIT do
    spent := Port[OPL_STATUS];
  after := Port[OPL_STATUS];
  SoundDrv.OplWrite($04, TIMER_RESET);
  SoundDrv.OplWrite($04, IRQ_RESET);
  Detect := (before and STATUS_FLAGS = 0) and (after and STATUS_FLAGS = TIMER1_DONE);
end;

{ Music uses the Tandy arrangements on the AdLib. Effects and silence switch to
  the PC speaker, which also silences the AdLib. Gold Box games did not play
  their effects through FM. }
procedure Play(tune: Word);
begin
  if tune >= C_SOUND.MUSIC_TITLE then begin
    SoundDrv.SetSoundDevice(C_SOUND.MODE_ADLIB);
    SoundDrv.ProgramTandyVoices(tune);
  end else begin
    SoundDrv.SetSoundDevice(C_SOUND.MODE_SPEAKER);
    SoundDrv.ProgramSpeakerVoices(tune);
  end;
end;

procedure Install;
begin
  if SndOpl.Detect then begin
    SoundDrv.OplReset;
    GameVars.sound.name := 'AdLib';
    GameVars.sound.mode := C_SOUND.MODE_ADLIB;
    GameVars.sound.Play := SndOpl.Play;
    GameVars.sound.singleStep := False;
  end else begin
    SndSpk.Install;
    GameVars.sound.name := 'Speaker (no AdLib)';
  end;
end;

end.
