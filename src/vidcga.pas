{ The CGA video driver: BIOS mode 4, 320x200 in 4 colours at 2 bits a pixel, even and odd rows in separate banks at
  $B800 and $BA00. Resident, since its routines are the hot ones; GameBoot installs it when POOL.CFG names CGA (phase 6
  of docs/refactor-plan.md). }
{$F+}
unit VidCga;

interface

{ Make this the video driver: fill GDVars.video. }
procedure Install;

implementation

uses Types, GDConsts, GDVars, Blit;

procedure CellFill(color: Byte; var colorMap: Types.TColorMap; var cell: Types.TCellBytes);
begin
  { the colour map picks which of the 4 colours shows color }
  FillChar(cell, SizeOf(cell), GDConsts.cgaColorFill[Blit.SrcNibble(color, colorMap)]);
end;

procedure Install;
begin
  with GDVars.video do begin
    name := 'CGA';
    colours := 4;
    hasPalette := False;
    cellShift := 1;
    screenShift := 1;
    maskShift := 0;
    CellFill := VidCga.CellFill;
  end;
end;

end.
