{ The PC speaker sound driver: the sequencer's PC Speaker arrangements, played by SOUNDDRV.OBJ's timer driver. GameBoot
  installs it when POOL.CFG names P (phase 7 of docs/refactor-plan.md). }
{$F+}
{$I COMPILER.INC}
unit SndSpk;

interface

{ Make this the sound driver: fill GameVars.sound. }
procedure Install;

implementation

uses C_SOUND, GameVars, SoundDrv;

{ Load tune into the PC Speaker voices. }
procedure Play(tune: Word);
begin
  SoundDrv.ProgramSpeakerVoices(tune);
end;

procedure Install;
begin
  GameVars.sound.name := 'PC Speaker';
  GameVars.sound.mode := C_SOUND.MODE_SPEAKER;
  GameVars.sound.Play := SndSpk.Play;
  GameVars.sound.singleStep := False;
end;

end.
