{ STING hit-point debug display. GameIo toggles its flag on Ctrl-D when the first command-line argument is STING. }
{$O+,F+}
unit Debug;

interface

uses Types;

{ When the STING flag is set, show three hit-point values on the top row and pause on msg. EffHndlr.DrainLevels passes
  hpMax, hpCur and drainedHps for each drained level, before removing its hit points }
procedure PrintHpDebug(msg: Types.TStr40; maximumHitPoints, currentHitPoints, drainedHitPoints: Byte);

{ STING Ctrl-Y (#612): the overlay loads so far, the overlay buffer and its probation area, and the heap's free memory
  and largest block, on the bottom line one after another, each until a key; the menu line is drawn again after.
  GameIo.ReadGameKey calls it through GameIo.showMemory. }
procedure ShowMemory;

implementation


uses Crt, GDConsts, GDVars, TextRend, Overlay, StrUtil;
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

procedure ShowMemory;
begin
  TextRend.DisplayAndPause(LightGreen, 'Overlay loads ' + StrUtil.NumStr(GDVars.ovrLoads));
  TextRend.DisplayAndPause(LightGreen, 'Ovr buffer ' + StrUtil.NumStr(OvrGetBuf) + ' retry ' +
                                       StrUtil.NumStr(OvrGetRetry));
  TextRend.DisplayAndPause(LightGreen, 'Heap free ' + StrUtil.NumStr(MemAvail) + ' big ' + StrUtil.NumStr(MaxAvail));
  TextRend.ClearBottomLine;
  GDVars.bottomLineTaken := True;
end;

end.
