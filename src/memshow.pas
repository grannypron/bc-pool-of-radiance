{ STING Ctrl-Y's memory display. Resident, so looking at the overlay load count loads no overlay and leaves the count
  as it was; GameIo calls it through its showMemory hook, since GameIo cannot use TextRend. }
{$F+}
unit MemShow;

interface

{ STING Ctrl-Y (#612): the overlay loads so far, the overlay buffer and its probation area, and the heap's free memory
  and largest block, on the bottom line one after another, each until a key; the menu line is drawn again after.
  GameIo.ReadGameKey calls it through GameIo.showMemory. }
procedure ShowMemory;

implementation

uses Crt, GDVars, TextRend, StrUtil, Overlay;

procedure ShowMemory;
begin
  TextRend.DisplayAndPause(LightGreen, 'Overlay loads ' + StrUtil.NumStr(GDVars.ovrLoads));
  TextRend.DisplayAndPause(LightGreen, 'Ovr buffer ' + StrUtil.NumStr(OvrGetBuf) + ' retry ' +
                                       StrUtil.NumStr(OvrGetRetry));
  TextRend.DisplayAndPause(LightGreen, 'Heap free ' + StrUtil.NumStr(MemAvail) + ' big ' + StrUtil.NumStr(MaxAvail));
  TextRend.DisplayAndPause(LightGreen, 'Pictures ' + StrUtil.NumStr(GDVars.picBytes) + ' peak ' +
                                       StrUtil.NumStr(GDVars.picPeak));
  TextRend.ClearBottomLine;
  GDVars.bottomLineTaken := True;
end;

end.
