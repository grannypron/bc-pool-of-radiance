{ Implements STING's Ctrl-Y memory display. It stays resident so opening the
  display does not itself increase the overlay-load count. GameIo reaches it
  through showMemory because GameIo cannot depend on TextRend. }
{$F+}
{$I COMPILER.INC}
unit MemShow;

interface

{ Shows overlay and heap statistics one screen at a time until dismissed
  (#612), then restores the menu line. }
procedure ShowMemory;

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, GameVars, Blit, TextRend, StrUtil{$IFNDEF FPC}, Overlay{$ENDIF};

procedure ShowMemory;
{ the native build has no overlays }
{$IFNDEF FPC}
var
  source: string[5];
{$ENDIF}
begin
{$IFNDEF FPC}
  if GameVars.ovrInEms then
    source := 'EMS'
  else
    source := 'disk';
  TextRend.DisplayAndPause(LightGreen, 'Overlay loads ' + StrUtil.NumStr(GameVars.ovrLoads));
  TextRend.DisplayAndPause(LightGreen, 'Ovr buffer ' + StrUtil.NumStr(OvrGetBuf) + ' retry ' +
                                       StrUtil.NumStr(OvrGetRetry) + ' from ' + source);
{$ENDIF}
  TextRend.DisplayAndPause(LightGreen, 'Heap free ' + StrUtil.NumStr(MemAvail) + ' big ' + StrUtil.NumStr(MaxAvail));
  TextRend.DisplayAndPause(LightGreen, 'Pictures ' + StrUtil.NumStr(Blit.picBytes) + ' peak ' +
                                       StrUtil.NumStr(Blit.picPeak));
  TextRend.ClearBottomLine;
  GameVars.bottomLineTaken := True;
end;

end.
