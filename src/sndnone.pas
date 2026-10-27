{ Silent sound driver. GameBoot installs it when POOL.CFG disables sound.
  SoundDrv ignores playback while this driver is active, so Play is never called. }
{$F+}
{$I COMPILER.INC}
unit SndNone;

interface

{ Make this the sound driver: fill GameVars.sound. }
procedure Install;

implementation

uses C_SOUND, GameVars;

{ Nothing to play. }
procedure Play(tune: Word);
begin
end;

procedure Install;
begin
  GameVars.sound.name := 'None';
  GameVars.sound.mode := C_SOUND.MODE_DISABLED;
  GameVars.sound.Play := SndNone.Play;
  GameVars.sound.singleStep := False;
end;

end.
