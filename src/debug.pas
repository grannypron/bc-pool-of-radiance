{ STING hit-point debug display. GameIo toggles its flag on Ctrl-D when the first command-line argument is STING. }
{$O+,F+}
{$I COMPILER.INC}
unit Debug;

interface

uses Types;

{ When the STING flag is set, show three hit-point values on the top row and pause on msg. EffHndlr.DrainLevels passes
  hpMax, hpCur and drainedHps for each drained level, before removing its hit points, and tests the flag first. }
procedure PrintHpDebug(msg: Types.TStr40; maximumHitPoints, currentHitPoints, drainedHitPoints: Byte);

implementation


uses Crt, GDConsts, GDVars, TextRend, StrUtil;
procedure PrintHpDebug(msg: Types.TStr40; maximumHitPoints, currentHitPoints, drainedHitPoints: Byte);
begin
  if GDVars.stingHpFlag <> 0 then begin
    { columns 0..39: the whole row, wider than the TEXT_RIGHT window }
    TextRend.ClearRect(0, 0, 39, 0);
    TextRend.DisplayString(0, 0, Yellow, StrUtil.NumStr(maximumHitPoints) + ' , ' + StrUtil.NumStr(currentHitPoints) +
                                         ' , ' + StrUtil.NumStr(drainedHitPoints));
    TextRend.DisplayAndPause(Yellow, msg);
    TextRend.ClearRect(0, 0, 39, 0);
  end;
end;

end.
