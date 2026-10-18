{ The PC speaker sound driver: the sequencer's PC Speaker arrangements, played by SOUNDDRV.OBJ's timer driver. GameBoot
  installs it when POOL.CFG names P (phase 7 of docs/refactor-plan.md). }
{$F+}
unit SndSpk;

interface

{ Make this the sound driver: fill GDVars.sound. }
procedure Install;

implementation

uses C_Sound, GDVars, SoundDrv;

{ Load tune into the PC Speaker voices. }
procedure Play(tune: Word);
begin
  SoundDrv.ProgramSpeakerVoices(tune);
end;

procedure Install;
begin
  GDVars.sound.name := 'PC Speaker';
  GDVars.sound.mode := C_Sound.MODE_SPEAKER;
  GDVars.sound.Play := SndSpk.Play;
end;

end.
