{ The Tandy SN76489 sound driver: the sequencer's Tandy arrangements, played by SOUNDDRV.OBJ's timer driver. On DOS
  GameBoot installs it when POOL.CFG names T; the native build plays T with SndDig (phase 7 of docs/refactor-plan.md). }
{$F+}
{$I COMPILER.INC}
unit SndTdy;

interface

{ Make this the sound driver: fill GameVars.sound. }
procedure Install;

implementation

uses C_SOUND, GameVars, SoundDrv;

{ Load tune into the Tandy voices. }
procedure Play(tune: Word);
begin
  SoundDrv.ProgramTandyVoices(tune);
end;

procedure Install;
begin
  GameVars.sound.name := 'Tandy';
  GameVars.sound.mode := C_SOUND.MODE_TANDY;
  GameVars.sound.Play := SndTdy.Play;
  GameVars.sound.singleStep := False;
end;

end.
