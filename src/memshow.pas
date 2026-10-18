{ STING Ctrl-Y's memory display. Resident, so looking at the overlay load count loads no overlay and leaves the count
  as it was; GameIo calls it through its showMemory hook, since GameIo cannot use TextRend. }
{$F+}
{$I COMPILER.INC}
unit MemShow;

interface

{ STING Ctrl-Y (#612): the overlay loads so far; the overlay buffer, its probation area and where the overlays load
  from (EMS or disk); the heap's free memory and largest block; and the heap pictures hold, with its peak. On the bottom
  line one after another, each until a key; the menu line is drawn again after. GameIo.ReadGameKey calls it through
  GameIo.showMemory. }
procedure ShowMemory;

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, GDVars, TextRend, StrUtil{$IFNDEF FPC}, Overlay{$ENDIF};

procedure ShowMemory;
var
  source: string[5];
begin
  if GDVars.ovrInEms then
    source := 'EMS'
  else
    source := 'disk';
  { the native build has no overlays }
{$IFNDEF FPC}
  TextRend.DisplayAndPause(LightGreen, 'Overlay loads ' + StrUtil.NumStr(GDVars.ovrLoads));
  TextRend.DisplayAndPause(LightGreen, 'Ovr buffer ' + StrUtil.NumStr(OvrGetBuf) + ' retry ' +
                                       StrUtil.NumStr(OvrGetRetry) + ' from ' + source);
{$ENDIF}
  TextRend.DisplayAndPause(LightGreen, 'Heap free ' + StrUtil.NumStr(MemAvail) + ' big ' + StrUtil.NumStr(MaxAvail));
  TextRend.DisplayAndPause(LightGreen, 'Pictures ' + StrUtil.NumStr(GDVars.picBytes) + ' peak ' +
                                       StrUtil.NumStr(GDVars.picPeak));
  TextRend.ClearBottomLine;
  GDVars.bottomLineTaken := True;
end;

end.
