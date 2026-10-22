{ The Tandy SN76489 sound driver: the sequencer's Tandy arrangements, played by SOUNDDRV.OBJ's timer driver. On DOS
  GameBoot installs it when POOL.CFG names T; the native build plays T with SndDig (phase 7 of docs/refactor-plan.md). }
{$F+}
{$I COMPILER.INC}
unit SndTdy;

interface

{ Make this the sound driver: fill GDVars.sound. }
procedure Install;

implementation

uses C_Sound, GDVars, SoundDrv;

{ Load tune into the Tandy voices. }
procedure Play(tune: Word);
begin
  SoundDrv.ProgramTandyVoices(tune);
end;

procedure Install;
begin
  GDVars.sound.name := 'Tandy';
  GDVars.sound.mode := C_Sound.MODE_TANDY;
  GDVars.sound.Play := SndTdy.Play;
  GDVars.sound.singleStep := False;
end;

end.
