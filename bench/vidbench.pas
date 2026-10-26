{ Benchmarks the video primitives using workloads modeled on the game.
  bench/vidbench.sh runs this program once per video mode in DOSBox-X at a fixed
  speed. Pass the POOL.CFG video letter C, E, or T. VIDBENCH.LOG records the
  mode, workload, run count, elapsed BIOS ticks, and runs per second. Results
  are comparable only when measured at the same DOSBox-X speed. }
program VidBench;

uses Types, C_VIDEO, GameVars, Blit, TextRend, VidCga, VidEga, VidTdy;

const
  { Run each workload for roughly three seconds. }
  RUN_TICKS = 54;
  LOG_NAME = 'VIDBENCH.LOG';

var
  log: Text;
  mode: Char;
  tile: Types.PImgBuf;
  noMap: Types.TColorMap;
  i: Integer;
  arg: String;

{ Returns the BIOS tick count through TextRend. }
function Ticks: LongInt;
begin
  Ticks := TextRend.TickCount;
end;

{ Draws 1,000 characters, 40 per row across rows 0..24. }
procedure Text1000;
var
  n: Integer;
begin
  for n := 0 to 999 do
    TextRend.RenderChar(n mod 40, (n div 40) mod 25, 15, 1, Ord('A') + n mod 26, 1);
end;

{ Draws a 21x21 grid of masked tiles, matching one 3D view. }
procedure Tiles441;
var
  x: Integer;
  y: Integer;
begin
  for y := 0 to 20 do
    for x := 0 to 20 do
      Blit.BlitTileCell(x, y, 0, 1, tile, GameVars.dsViewImageBufferPtr);
end;

{ Fills the complete 168x168 3D view. }
procedure FillView;
begin
  Blit.FillPicRect(0, 0, 21, 168, 1, noMap, GameVars.dsViewImageBufferPtr);
end;

{ Fills the backdrop and flushes all 168 dirty rows to the screen. }
procedure FillAndFlush;
begin
  Blit.FillPicRect(0, 0, 21, 168, 1, noMap, GameVars.dsViewImageBufferPtr);
  Blit.FlushView;
end;

type
  TWorkload = procedure;

{ Runs work for RUN_TICKS and logs its rate. }
procedure Measure(name: String; work: TWorkload);
var
  start: LongInt;
  stop: LongInt;
  runs: LongInt;
  rate: Real;
begin
  runs := 0;
  start := Ticks;
  { Start on a tick boundary so the first measured tick is complete. }
  repeat until Ticks <> start;
  start := Ticks;
  repeat
    work;
    Inc(runs);
    stop := Ticks;
  until stop - start >= RUN_TICKS;
  rate := runs * 18.2065 / (stop - start);
  WriteLn(log, mode, ' ', name, ' ', runs, ' ', stop - start, ' ', rate:0:2);
end;

begin
  arg := ParamStr(1) + ' ';
  mode := UpCase(arg[1]);
  { RestoreVideoMode returns to 80-column text mode. }
  GameVars.savedVideoMode := 3;
  case mode of
    'E': VidEga.Install;
    'T': VidTdy.Install;
  else begin
    mode := 'C';
    VidCga.Install;
  end;
  end;
  Blit.SetVideoMode(GameVars.video.biosMode);
  GameVars.video.Start;
  { Build the same row tables as GameInit2. }
  for i := 0 to 199 do begin
    if Odd(i) then
      GameVars.cgaRowSeg[i] := (i div 2) * 5 + C_VIDEO.GFX_BANK1_SEG
    else
      GameVars.cgaRowSeg[i] := (i div 2) * 5 + C_VIDEO.GFX_BANK0_SEG;
    GameVars.fbRowOfs[i] := i * 40;
    case i mod 4 of
      0: GameVars.tandyRowSeg[i] := (i div 4) * 10 + C_VIDEO.GFX_BANK0_SEG;
      1: GameVars.tandyRowSeg[i] := (i div 4) * 10 + C_VIDEO.GFX_BANK1_SEG;
      2: GameVars.tandyRowSeg[i] := (i div 4) * 10 + C_VIDEO.GFX_BANK2_SEG;
      3: GameVars.tandyRowSeg[i] := (i div 4) * 10 + C_VIDEO.GFX_BANK3_SEG;
    end;
  end;
  GetMem(GameVars.gameFont, SizeOf(Types.TFontArr));
  FillChar(GameVars.gameFont^, SizeOf(Types.TFontArr), $5A);
  Blit.AllocPic(168, 21, 1, 0, GameVars.dsViewImageBufferPtr);
  FillChar(GameVars.spanActive, SizeOf(GameVars.spanActive), 0);
  FillChar(GameVars.spanScreenOfs, SizeOf(GameVars.spanScreenOfs), 0);
  FillChar(GameVars.spanFirstOfs, SizeOf(GameVars.spanFirstOfs), $FF);
  FillChar(GameVars.spanLastOfs, SizeOf(GameVars.spanLastOfs), 0);
  { Allocate one masked 8x8 tile. }
  Blit.AllocPic(8, 1, 1, 1, tile);
  FillChar(noMap, SizeOf(noMap), 0);

  Assign(log, LOG_NAME);
  {$I-}
  Append(log);
  if IOResult <> 0 then
    Rewrite(log);
  {$I+}
  Measure('text1000', Text1000);
  Measure('tiles441', Tiles441);
  Measure('fillview', FillView);
  Measure('fillflush', FillAndFlush);
  Close(log);
  Blit.RestoreVideoMode;
end.
