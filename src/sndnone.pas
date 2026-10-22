{ The silent sound driver, for no sound device: GameBoot installs it when POOL.CFG names none (phase 7 of
  docs/refactor-plan.md). SoundDrv does nothing while soundMode is C_SOUND.MODE_DISABLED, so Play is never reached. }
{$F+}
{$I COMPILER.INC}
unit SndNone;

interface

{ Make this the sound driver: fill GDVars.sound. }
procedure Install;

implementation

uses C_SOUND, GDVars;

{ Nothing to play. }
procedure Play(tune: Word);
begin
end;

procedure Install;
begin
  GDVars.sound.name := 'None';
  GDVars.sound.mode := C_SOUND.MODE_DISABLED;
  GDVars.sound.Play := SndNone.Play;
  GDVars.sound.singleStep := False;
end;

end.
