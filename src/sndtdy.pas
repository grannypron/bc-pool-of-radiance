{ Tandy SN76489 sound driver. SOUNDDRV.OBJ's timer sequencer plays the Tandy
  arrangements. DOS uses this driver; native builds use SndDig instead. }
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
