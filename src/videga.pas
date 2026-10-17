{ The EGA video driver: BIOS mode 0Dh, 320x200 in 16 colours on four planes at $A000, two pages. Resident, since its
  routines are the hot ones; GameBoot installs it when POOL.CFG names EGA (phase 6 of docs/refactor-plan.md). }
{$F+}
unit VidEga;

interface

{ Make this the video driver: fill GDVars.video. }
procedure Install;

implementation

uses Types, GDConsts, GDVars;

procedure CellFill(color: Byte; var colorMap: Types.TColorMap; var cell: Types.TCellBytes);
var
  plane: Byte;
begin
  { a byte a plane: all set where the colour has that plane's bit }
  for plane := 0 to 3 do
    if (GDConsts.egaPlaneBit[plane] and color) > 0 then
      cell[plane] := $FF
    else
      cell[plane] := 0;
end;

procedure Install;
begin
  with GDVars.video do begin
    name := 'EGA';
    colours := 16;
    hasPalette := True;
    cellShift := 2;
    screenShift := 0;
    maskShift := 2;
    CellFill := VidEga.CellFill;
  end;
end;

end.
