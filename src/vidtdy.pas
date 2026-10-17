{ The Tandy video driver: BIOS mode 9, 320x200 in 16 colours at 4 bits a pixel, four banks from $B800. Resident,
  since its routines are the hot ones; GameBoot installs it when POOL.CFG names Tandy (phase 6 of
  docs/refactor-plan.md). }
{$F+}
unit VidTdy;

interface

{ Make this the video driver: fill GDVars.video. }
procedure Install;

implementation

uses Types, GDConsts, GDVars;

procedure CellFill(color: Byte; var colorMap: Types.TColorMap; var cell: Types.TCellBytes);
begin
  FillChar(cell, SizeOf(cell), GDConsts.tandyColorFill[color]);
end;

procedure Install;
begin
  with GDVars.video do begin
    name := 'Tandy';
    colours := 16;
    hasPalette := False;
    cellShift := 2;
    screenShift := 2;
    maskShift := 0;
    CellFill := VidTdy.CellFill;
  end;
end;

end.
