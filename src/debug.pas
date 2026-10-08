{ STING hit-point debug display. GameIo toggles its flag on Ctrl-D when the first command-line argument is STING. }
{$O+,F+}
unit Debug;

interface

uses Types, Crt, GDConsts, GDVars, TextRend;

{ When the STING flag is set, show three hit-point values on the top row and pause on msg. No unit calls it. }
procedure PrintHpDebug(msg: Types.TStr40; maximumHitPoints, currentHitPoints, drainedHitPoints: Byte);

implementation

procedure PrintHpDebug(msg: Types.TStr40; maximumHitPoints, currentHitPoints, drainedHitPoints: Byte);
var
  s1: String;
  s2: String;
  s3: String;
begin
  if GDVars.stingHpFlag <> 0 then begin
    Str(maximumHitPoints, s1);
    Str(currentHitPoints, s2);
    Str(drainedHitPoints, s3);
    { columns 0..39: the whole row, wider than the TEXT_RIGHT window }
    TextRend.ClearRect(0, 0, 39, 0);
    TextRend.DisplayString(0, 0, Yellow, s1 + ' , ' + s2 + ' , ' + s3);
    TextRend.DisplayAndPause(Yellow, msg);
    TextRend.ClearRect(0, 0, 39, 0);
  end;
end;

begin
end.
