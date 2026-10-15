{ The full screen DataBld shows while it builds the merged data archives: the archive being made and its step, how many
  families are finished with a bar and the time left, and a row for each family with one cell per per-disk archive.
  The bar and the time left count bytes: each stale family's per-disk archives are read, then written and checked as
  its merged archive, and each of those three passes counts as the family's per-disk bytes. Only what changed is
  drawn again. When the game folder cannot be written, the status lines give way to a warning, the families that
  cannot be built show as failed, and the build's own calls draw nothing. The screen is cleared when the build ends.
  With too little memory for it, nothing is drawn and every call does nothing. }
{$O+,F+,I-}
unit BldShow;

interface

uses C_Data;

type
  { the families DataBld builds }
  TStaleList = array[1..C_Data.FAMILIES] of Boolean;

{ Clear the screen and draw the display. A stale family's cells wait, or, when the game folder cannot be written
  (writable False), show it failed under a warning; any other family with per-disk archives shows them done. }
procedure Open(var stale: TStaleList; writable: Boolean);

{ The family whose merged archive is made next. }
procedure StartFamily(fam: Byte);

{ The family's per-disk archive of disk is being read. }
procedure Reading(fam, disk: Byte);

{ A data fix is being made to a block of the family's per-disk archive of disk. }
procedure Fixing(fam, disk: Byte);

{ The merged archive is being written: bytes of blocks follow its directory. }
procedure Writing(bytes: LongInt);

{ The merged archive is being read back and checked. }
procedure Checking;

{ bytes more have been read, written or checked. }
procedure Advance(bytes: Word);

{ The family is finished: built or kept (ok), or failed. }
procedure EndFamily(fam: Byte; ok: Boolean);

{ Show the finished display for a second, or, when a family failed or the game folder cannot be written, until Enter
  is pressed, pointing to DATABLD.LOG when it was written; then clear the screen. }
procedure Finish(failed: Boolean);

implementation

uses Crt, Types, GDConsts, GDVars, DataArc, TextRend, Blit, Border, GameIo, StrUtil;

const
  { per-disk archives are numbered 1 to SOURCE_DISKS }
  SOURCE_DISKS = 8;
  { the frame's three parts: title, status and families, each a text rectangle inside its border }
  TITLE_ROW = 1;
  STATUS_TOP = 3;
  STATUS_BOTTOM = 9;
  PANEL_TOP = 11;
  PANEL_BOTTOM = 22;
  { the status lines; labels end at LABEL_END, values start two columns later }
  MAKE_ROW = 4;
  STEP_ROW = 5;
  OVERALL_ROW = 7;
  ETA_ROW = 8;
  LABEL_WIDTH = 9;
  LABEL_END = 13;
  VALUE_COL = 15;
  STEP_WIDTH = 13;
  COUNT_WIDTH = 5;
  { the bar: BAR_CELLS character cells of 8 pixels }
  BAR_COL = 21;
  BAR_CELLS = 16;
  BAR_PX = 128;
  { the family rows: two columns of PANEL_ROWS, each a name and then the cells }
  PANEL_FIRST = 13;
  PANEL_ROWS = 7;
  NAME_WIDTH = 8;
  LEFT_NAME_COL = 3;
  RIGHT_NAME_COL = 21;
  NOTE_ROW = 21;
  { cell states }
  CELL_NONE = 0;
  CELL_WAIT = 1;
  CELL_CURRENT = 2;
  CELL_DONE = 3;
  CELL_FAILED = 4;
  { the cell pictures: one frame per cell state from CELL_WAIT on, then the bar's cells with 0 to 8 pixels filled }
  FRAME_BAR = 4;
  FRAMES = 13;
  { the status texts drawn a character at a time, only where they change }
  FIELD_MAKE_LABEL = 0;
  FIELD_MAKE = 1;
  FIELD_STEP_LABEL = 2;
  FIELD_STEP = 3;
  FIELD_COUNT = 4;
  FIELD_ETA = 5;
  FIELDS = 6;
  FIELD_WIDTH = 16;
  { family name states }
  NAME_NONE = 0;
  NAME_SHOWN = 1;
  NAME_FAILED = 2;
  { steps }
  PHASE_READ = 0;
  PHASE_WRITE = 1;
  PHASE_CHECK = 2;
  { BIOS timer ticks: 18.2 a second, back to 0 at midnight after TICKS_PER_DAY }
  TICKS_PER_DAY = $1800B0;
  ETA_FIRST = 36;
  ETA_EVERY = 18;
  HOLD_TICKS = 18;
  { the most minutes the time left shows, and the most ticks it is worked out from }
  ETA_MAX_MINUTES = 99;
  ETA_MAX_TICKS = 200000;
  TITLE = 'Please wait, preparing files';
  { shown under the families when one failed, if DataBld could write its log }
  NOTE = 'See DATABLD.LOG';
  LOG_NAME = 'DATABLD.LOG';
  { the hold's prompt on the bottom line, the game's own }
  PROMPT = 'press <enter>/<return> to continue';
  { shown in the status box when the game folder cannot be written: WARN_LABEL in light red, then WARN_TEXT }
  WARN_ROW = 5;
  WARN_LABEL = 'Warning:';
  WARN_TEXT = ' Install folder is read only.';
  WARN_NEXT_ROW = 7;
  WARN_NEXT = 'Game data fixes will be unavailable.';

type
  TPixelRow = array[0..7] of Byte;
  PShowState = ^TShowState;
  TShowState = record
    { each per-disk archive's size, -1 when it is not there, and its cell's place in the family's row, 0 for none }
    size: array[1..C_Data.FAMILIES, 1..SOURCE_DISKS] of LongInt;
    place: array[1..C_Data.FAMILIES, 1..SOURCE_DISKS] of Byte;
    { what each cell and name shows now }
    cell: array[1..C_Data.FAMILIES, 1..SOURCE_DISKS] of Byte;
    name: array[1..C_Data.FAMILIES] of Byte;
    shown: array[0..FIELDS - 1] of String[FIELD_WIDTH];
    { the families shown: those with files }
    listed: array[1..C_Data.FAMILIES] of Boolean;
    { the family being made, its per-disk bytes and the work done when it started }
    family: Byte;
    familyBytes: LongInt;
    base: LongInt;
    { the step, its bytes done and expected, and the bytes done that move the bar a pixel }
    phase: Byte;
    phaseDone: LongInt;
    phaseTotal: LongInt;
    phaseNext: LongInt;
    { the work: three passes over every stale family's per-disk bytes }
    total: LongInt;
    done: LongInt;
    { the bar's filled pixels, and the work that fills the next one }
    barPx: Word;
    nextPx: LongInt;
    finished: Byte;
    { the game folder cannot be written: only the warning and the families are shown }
    readOnly: Boolean;
    { BIOS ticks since Open, the last tick read, and when the time left was last shown }
    elapsed: LongInt;
    lastTick: LongInt;
    etaAt: LongInt;
    { the cell pictures, and the one-frame picture each is drawn through }
    art: Types.PImgBuf;
    pic: Types.PImgBuf;
  end;

const
  st: PShowState = nil;

var
  displayMode: Types.TVideoMode absolute GDVars.videoMode;
  biosTicks: LongInt absolute $0040:$006C;

{ a * b div c for positive a, b and c; 0 when any of them is not positive. Until the product fits, the larger factor
  and c are halved together; once c is down to 1 the halving is made up by doubling the result instead. }
function MulDiv(a, b, c: LongInt): LongInt;
var
  doublings: Byte;
  q: LongInt;
begin
  if (a <= 0) or (b <= 0) or (c <= 0) then
    MulDiv := 0
  else begin
    doublings := 0;
    while (a > 46340) or (b > 46340) do begin
      if a > b then
        a := a shr 1
      else
        b := b shr 1;
      if c > 1 then
        c := c shr 1
      else
        Inc(doublings);
    end;
    q := a * b div c;
    while doublings > 0 do begin
      q := q * 2;
      Dec(doublings);
    end;
    MulDiv := q;
  end;
end;

{ Draw s in color at col, row, cut to the screen's width. }
procedure DrawText(col, row, color: Byte; s: string);
begin
  if (col < 40) and (row < 25) then
    TextRend.DisplayString(col, row, color, Copy(s, 1, 40 - col));
end;

{ Put a row of 8 pixel colors into line y of the frame of the cell pictures, in the layout of the video mode. }
procedure PutPixels(frame, y: Byte; var px: TPixelRow);
var
  at: Word;
  plane: Byte;
  i: Byte;
  k: Byte;
  b: Byte;
begin
  if (frame >= FRAMES) or (y > 7) then Exit;
  at := frame * st^.art^.imgSize;
  case displayMode of
    Types.vmEGA:
      for plane := 0 to 3 do begin
        b := 0;
        for k := 0 to 7 do
          if (px[k] and GDConsts.egaPlaneBit[plane]) <> 0 then
            b := b or ($80 shr k);
        st^.art^.data[at + y * 4 + plane] := b;
      end;
    Types.vmCGA:
      for i := 0 to 1 do begin
        b := 0;
        for k := 0 to 3 do
          b := b or ((GDConsts.attrTable[px[i * 4 + k] and $0F] and 3) shl (6 - 2 * k));
        st^.art^.data[at + y * 2 + i] := b;
      end;
    Types.vmTandy:
      for i := 0 to 3 do
        st^.art^.data[at + y * 4 + i] := ((px[i * 2] and $0F) shl 4) or (px[i * 2 + 1] and $0F);
  end;
end;

{ Draw a frame of the cell pictures: a block over lines 1 to 6 and pixels left to right, the first fill pixels in fg and
  the rest in bg; with outline, only the block's edge, in fg. Everything else in the cell is black. }
procedure MakeFrame(frame, left, right, fill, fg, bg: Byte; outline: Boolean);
var
  px: TPixelRow;
  x: Byte;
  y: Byte;
begin
  for y := 0 to 7 do begin
    for x := 0 to 7 do begin
      px[x] := Black;
      if (y >= 1) and (y <= 6) and (x >= left) and (x <= right) then
        if outline then begin
          if (y = 1) or (y = 6) or (x = left) or (x = right) then
            px[x] := fg;
        end else if x - left < fill then
          px[x] := fg
        else
          px[x] := bg;
    end;
    BldShow.PutPixels(frame, y, px);
  end;
end;

{ Draw the cell picture frame in the character cell at col, row. }
procedure ShowFrame(col, row, frame: Byte);
begin
  if (col > 39) or (row > 24) or (frame >= FRAMES) then Exit;
  Move(st^.art^.data[frame * st^.art^.imgSize], st^.pic^.data, st^.pic^.imgSize);
  Blit.ShowPic(col, row, st^.pic);
end;

{ The screen row and first cell column of the family's row; False for a family past the panel's two columns. }
function FamilyPlace(fam: Byte; var row, col: Byte): Boolean;
begin
  FamilyPlace := (fam >= 1) and (fam <= 2 * PANEL_ROWS);
  if fam <= PANEL_ROWS then begin
    row := PANEL_FIRST + fam - 1;
    col := LEFT_NAME_COL;
  end else begin
    row := PANEL_FIRST + fam - PANEL_ROWS - 1;
    col := RIGHT_NAME_COL;
  end;
end;

{ Show cell disk of the family in state, unless it already does. }
procedure SetCell(fam, disk, state: Byte);
var
  row: Byte;
  col: Byte;
begin
  if (fam < 1) or (fam > C_Data.FAMILIES) or (disk < 1) or (disk > SOURCE_DISKS) then Exit;
  if (st^.place[fam, disk] = 0) or (st^.cell[fam, disk] = state) then Exit;
  if not BldShow.FamilyPlace(fam, row, col) then Exit;
  st^.cell[fam, disk] := state;
  col := col + NAME_WIDTH + st^.place[fam, disk] - 1;
  if state <> CELL_NONE then
    BldShow.ShowFrame(col, row, state - CELL_WAIT);
end;

{ Show every cell of the family in state. }
procedure SetCells(fam, state: Byte);
var
  disk: Byte;
begin
  for disk := 1 to SOURCE_DISKS do
    BldShow.SetCell(fam, disk, state);
end;

{ Show the family's name in state, unless it already does. }
procedure SetName(fam, state: Byte);
var
  row: Byte;
  col: Byte;
  color: Byte;
begin
  if (fam < 1) or (fam > C_Data.FAMILIES) then Exit;
  if not st^.listed[fam] or (st^.name[fam] = state) then Exit;
  if not BldShow.FamilyPlace(fam, row, col) then Exit;
  st^.name[fam] := state;
  if state = NAME_FAILED then
    color := LightRed
  else
    color := LightGreen;
  BldShow.DrawText(col, row, color, StrUtil.PadRight(DataArc.MergedName(fam), NAME_WIDTH - 1));
end;

{ Show s, cut or padded to width, as status text field at col, row: only the characters that differ from what the field
  shows now are drawn. }
procedure Field(field, col, row, color: Byte; s: string; width: Byte);
var
  i: Byte;
begin
  if field >= FIELDS then Exit;
  if width > FIELD_WIDTH then
    width := FIELD_WIDTH;
  s := StrUtil.PadRight(s, width);
  for i := 1 to width do
    if (i > Length(st^.shown[field])) or (st^.shown[field][i] <> s[i]) then
      if col + i - 1 < 40 then
        TextRend.RenderChar(col + i - 1, row, color, 1, Ord(s[i]), 1);
  st^.shown[field] := s;
end;

{ Show a status line: its label, right-aligned to end at LABEL_END, and its value. }
procedure Status(labelField, valueField, row: Byte; lbl, value: string);
begin
  BldShow.Field(labelField, LABEL_END - LABEL_WIDTH + 1, row, Yellow, StrUtil.PadLeft(lbl, LABEL_WIDTH), LABEL_WIDTH);
  BldShow.Field(valueField, VALUE_COL, row, LightCyan, value, STEP_WIDTH);
end;

{ Show the families finished, as n/FAMILIES with n padded to two places. }
procedure ShowCount;
begin
  BldShow.Field(FIELD_COUNT, VALUE_COL, OVERALL_ROW, LightCyan, StrUtil.PadLeft(StrUtil.NumStr(st^.finished), 2) + '/' +
                StrUtil.NumStr(C_Data.FAMILIES), COUNT_WIDTH);
end;

{ Fill the bar to px pixels, drawing only the cells that change. }
procedure ShowBar(px: Word);
var
  c: Word;
  first: Word;
  last: Word;
  fill: Integer;
begin
  if px > BAR_PX then
    px := BAR_PX;
  if px = st^.barPx then Exit;
  if px > st^.barPx then begin
    first := st^.barPx div 8;
    last := (px - 1) div 8;
  end else begin
    first := px div 8;
    last := (st^.barPx - 1) div 8;
  end;
  if last >= BAR_CELLS then
    last := BAR_CELLS - 1;
  for c := first to last do begin
    fill := Integer(px) - Integer(c * 8);
    if fill < 0 then
      fill := 0
    else if fill > 8 then
      fill := 8;
    BldShow.ShowFrame(BAR_COL + c, OVERALL_ROW, FRAME_BAR + fill);
  end;
  st^.barPx := px;
end;

{ Show the time left: the elapsed time scaled by the work left over the work done, as m:ss. }
procedure ShowEta;
var
  secs: LongInt;
  mins: LongInt;
  s: Types.TStr20;
begin
  secs := BldShow.MulDiv(st^.elapsed, st^.total - st^.done, st^.done);
  if secs > ETA_MAX_TICKS then
    secs := ETA_MAX_TICKS;
  secs := (secs * 10 + 91) div 182;
  mins := secs div 60;
  if mins > ETA_MAX_MINUTES then begin
    mins := ETA_MAX_MINUTES;
    secs := 59;
  end else
    secs := secs mod 60;
  s := StrUtil.ZeroPad2(secs);
  BldShow.Field(FIELD_ETA, VALUE_COL, ETA_ROW, LightCyan, StrUtil.NumStr(mins) + ':' + s, COUNT_WIDTH);
end;

{ The BIOS tick count, read until two reads agree, so a timer tick between the two words of a read is not taken. }
function TicksNow: LongInt;
var
  now: LongInt;
  again: LongInt;
begin
  again := biosTicks;
  repeat
    now := again;
    again := biosTicks;
  until now = again;
  TicksNow := now;
end;

{ Add the BIOS ticks since the last call to elapsed, across midnight, and show the time left once ETA_FIRST ticks have
  gone and then every ETA_EVERY. }
procedure Tick;
var
  now: LongInt;
  delta: LongInt;
begin
  now := BldShow.TicksNow;
  if now >= st^.lastTick then
    delta := now - st^.lastTick
  else
    delta := now + TICKS_PER_DAY - st^.lastTick;
  if (delta < 0) or (delta > TICKS_PER_DAY) then
    delta := 0;
  Inc(st^.elapsed, delta);
  st^.lastTick := now;
  if (st^.elapsed >= ETA_FIRST) and (st^.elapsed - st^.etaAt >= ETA_EVERY) and (st^.done > 0) then begin
    st^.etaAt := st^.elapsed;
    BldShow.ShowEta;
  end;
end;

{ Count the work done up to units, never back; move the bar when it gains a pixel. }
procedure SetDone(units: LongInt);
var
  px: LongInt;
begin
  if units > st^.total then
    units := st^.total;
  if units > st^.done then begin
    st^.done := units;
    if st^.done >= st^.nextPx then begin
      px := BldShow.MulDiv(BAR_PX, st^.done, st^.total);
      BldShow.ShowBar(px);
      st^.nextPx := BldShow.MulDiv(st^.total, px + 1, BAR_PX);
      if st^.nextPx <= st^.done then
        st^.nextPx := st^.done + 1;
    end;
  end;
  BldShow.Tick;
end;

{ Show the step line: lbl and the file. }
procedure Step(lbl, fileName: string);
begin
  BldShow.Status(FIELD_STEP_LABEL, FIELD_STEP, STEP_ROW, lbl, fileName);
end;

{ Count the bytes the step has done as the family's share of the work, and set the bytes at which the bar next gains a
  pixel. A step's bytes count as the family's per-disk bytes in all. }
procedure Recount;
var
  start: LongInt;
  part: LongInt;
begin
  start := st^.base + LongInt(st^.phase) * st^.familyBytes;
  if st^.phaseDone >= st^.phaseTotal then
    part := st^.familyBytes
  else
    part := BldShow.MulDiv(st^.familyBytes, st^.phaseDone, st^.phaseTotal);
  BldShow.SetDone(start + part);
  if st^.nextPx - start >= st^.familyBytes then
    st^.phaseNext := st^.phaseTotal
  else
    st^.phaseNext := BldShow.MulDiv(st^.nextPx - start, st^.phaseTotal, st^.familyBytes);
  if st^.phaseNext <= st^.phaseDone then
    st^.phaseNext := st^.phaseDone + 1;
end;

{ Start step phase of the current family, of total bytes. }
procedure StartPhase(phase: Byte; total: LongInt);
begin
  st^.phase := phase;
  st^.phaseDone := 0;
  st^.phaseTotal := total;
  BldShow.Recount;
end;

{ True while the display shows a build: it is open and the game folder can be written. }
function Active: Boolean;
begin
  Active := st <> nil;
  if st <> nil then
    Active := not st^.readOnly;
end;

procedure Open(var stale: TStaleList; writable: Boolean);
var
  fam: Byte;
  disk: Byte;
  n: Byte;
  f: Byte;
  col: Byte;
  bytes: LongInt;
begin
  st := nil;
  { the state and both pictures: at most 4 bytes per pixel row of a cell, and a picture's header }
  if MaxAvail < SizeOf(TShowState) + (FRAMES + 1) * 32 + 2 * 64 + 1024 then Exit;
  GetMem(st, SizeOf(TShowState));
  FillChar(st^, SizeOf(TShowState), 0);
  Blit.AllocPic(8, 1, FRAMES, 0, st^.art);
  Blit.AllocPic(8, 1, 1, 0, st^.pic);
  BldShow.MakeFrame(CELL_WAIT - CELL_WAIT, 1, 6, 0, DarkGray, Black, True);
  BldShow.MakeFrame(CELL_CURRENT - CELL_WAIT, 1, 6, 6, Yellow, Black, False);
  BldShow.MakeFrame(CELL_DONE - CELL_WAIT, 1, 6, 6, LightGreen, Black, False);
  BldShow.MakeFrame(CELL_FAILED - CELL_WAIT, 1, 6, 6, LightRed, Black, False);
  for f := 0 to 8 do
    BldShow.MakeFrame(FRAME_BAR + f, 0, 7, f, LightGreen, DarkGray, False);
  for fam := 1 to C_Data.FAMILIES do begin
    n := 0;
    bytes := 0;
    for disk := 1 to SOURCE_DISKS do begin
      st^.size[fam, disk] := DataArc.FileLength(GDVars.gameDir + DataArc.SourceName(fam, disk) + '.DAX');
      if st^.size[fam, disk] >= 0 then begin
        Inc(n);
        st^.place[fam, disk] := n;
        Inc(bytes, st^.size[fam, disk]);
      end;
    end;
    if stale[fam] then
      Inc(st^.total, 3 * bytes)
    else
      Inc(st^.finished);
    { a family with no files is not shown }
    st^.listed[fam] := stale[fam] or (n > 0);
  end;
  st^.lastTick := BldShow.TicksNow;
  st^.readOnly := not writable;
  TextRend.ClearRect(0, 0, 39, 23);
  Border.DrawBorder(1, TITLE_ROW, 38, TITLE_ROW, 0);
  Border.DrawBorder(1, STATUS_TOP, 38, STATUS_BOTTOM, 0);
  Border.DrawBorder(1, PANEL_TOP, 38, PANEL_BOTTOM, 0);
  BldShow.DrawText(1 + (38 - Length(TITLE)) div 2, TITLE_ROW, White, TITLE);
  if st^.readOnly then begin
    col := 1 + (38 - Length(WARN_LABEL + WARN_TEXT)) div 2;
    BldShow.DrawText(col, WARN_ROW, LightRed, WARN_LABEL);
    BldShow.DrawText(col + Length(WARN_LABEL), WARN_ROW, Yellow, WARN_TEXT);
    BldShow.DrawText(1 + (38 - Length(WARN_NEXT)) div 2, WARN_NEXT_ROW, Yellow, WARN_NEXT);
  end else begin
    BldShow.Status(FIELD_MAKE_LABEL, FIELD_MAKE, MAKE_ROW, 'Creating:', '');
    BldShow.DrawText(LABEL_END - LABEL_WIDTH + 1, OVERALL_ROW, Yellow, StrUtil.PadLeft('Overall:', LABEL_WIDTH));
    BldShow.DrawText(LABEL_END - LABEL_WIDTH + 1, ETA_ROW, Yellow, StrUtil.PadLeft('ETA:', LABEL_WIDTH));
    BldShow.ShowCount;
    st^.barPx := BAR_PX;
    BldShow.ShowBar(0);
    st^.nextPx := 1;
  end;
  for fam := 1 to C_Data.FAMILIES do
    if not stale[fam] then begin
      BldShow.SetName(fam, NAME_SHOWN);
      BldShow.SetCells(fam, CELL_DONE);
    end else if st^.readOnly then begin
      BldShow.SetName(fam, NAME_FAILED);
      BldShow.SetCells(fam, CELL_FAILED);
    end else begin
      BldShow.SetName(fam, NAME_SHOWN);
      BldShow.SetCells(fam, CELL_WAIT);
    end;
end;

procedure StartFamily(fam: Byte);
var
  disk: Byte;
begin
  if not BldShow.Active or (fam < 1) or (fam > C_Data.FAMILIES) then Exit;
  st^.family := fam;
  st^.familyBytes := 0;
  for disk := 1 to SOURCE_DISKS do
    if st^.size[fam, disk] > 0 then
      Inc(st^.familyBytes, st^.size[fam, disk]);
  st^.base := st^.done;
  BldShow.Status(FIELD_MAKE_LABEL, FIELD_MAKE, MAKE_ROW, 'Creating:', DataArc.MergedName(fam) + '.DAX');
  BldShow.StartPhase(PHASE_READ, st^.familyBytes);
end;

procedure Reading(fam, disk: Byte);
var
  d: Byte;
begin
  if not BldShow.Active or (fam < 1) or (fam > C_Data.FAMILIES) then Exit;
  for d := 1 to SOURCE_DISKS do
    if d < disk then
      BldShow.SetCell(fam, d, CELL_DONE)
    else if d = disk then
      BldShow.SetCell(fam, d, CELL_CURRENT);
  BldShow.Step('Reading:', DataArc.SourceName(fam, disk) + '.DAX');
  BldShow.Tick;
end;

procedure Fixing(fam, disk: Byte);
begin
  if not BldShow.Active or (fam < 1) or (fam > C_Data.FAMILIES) then Exit;
  BldShow.SetCells(fam, CELL_DONE);
  BldShow.Step('Fixing:', DataArc.SourceName(fam, disk) + '.DAX');
  BldShow.Tick;
end;

procedure Writing(bytes: LongInt);
begin
  if not BldShow.Active then Exit;
  BldShow.SetCells(st^.family, CELL_DONE);
  BldShow.Step('Writing:', DataArc.MergedName(st^.family) + '.DAX');
  BldShow.StartPhase(PHASE_WRITE, bytes);
end;

procedure Checking;
begin
  if not BldShow.Active then Exit;
  BldShow.Step('Checking:', DataArc.MergedName(st^.family) + '.DAX');
  BldShow.StartPhase(PHASE_CHECK, st^.phaseTotal);
end;

procedure Advance(bytes: Word);
begin
  if not BldShow.Active then Exit;
  Inc(st^.phaseDone, bytes);
  if st^.phaseDone >= st^.phaseNext then
    BldShow.Recount
  else
    BldShow.Tick;
end;

procedure EndFamily(fam: Byte; ok: Boolean);
begin
  if not BldShow.Active or (fam < 1) or (fam > C_Data.FAMILIES) then Exit;
  if ok then
    BldShow.SetCells(fam, CELL_DONE)
  else begin
    BldShow.SetCells(fam, CELL_FAILED);
    BldShow.SetName(fam, NAME_FAILED);
    BldShow.Step('', '');
  end;
  Inc(st^.finished);
  BldShow.ShowCount;
  BldShow.SetDone(st^.base + 3 * st^.familyBytes);
end;

procedure Finish(failed: Boolean);
var
  start: LongInt;
  key: Char;
begin
  if st = nil then Exit;
  if not st^.readOnly then begin
    BldShow.SetDone(st^.total);
    BldShow.ShowBar(BAR_PX);
    BldShow.Status(FIELD_MAKE_LABEL, FIELD_MAKE, MAKE_ROW, '', '');
    BldShow.Step('', '');
    BldShow.Field(FIELD_ETA, VALUE_COL, ETA_ROW, LightCyan, '0:00', COUNT_WIDTH);
  end;
  if failed or st^.readOnly then begin
    if not st^.readOnly and (DataArc.FileLength(GDVars.gameDir + LOG_NAME) > 0) then
      BldShow.DrawText(1 + (38 - Length(NOTE)) div 2, NOTE_ROW, LightRed, NOTE);
    while KeyPressed do
      GameIo.DiscardPendingKeys;
    TextRend.ClearBottomLine;
    TextRend.DisplayString(0, 24, White, PROMPT);
    repeat
      key := GameIo.ReadGameKey;
    until key = #13;
    TextRend.ClearBottomLine;
  end else begin
    start := st^.elapsed;
    while st^.elapsed - start < HOLD_TICKS do
      BldShow.Tick;
  end;
  TextRend.ClearScreen;
  Blit.FreePic(st^.pic);
  Blit.FreePic(st^.art);
  FreeMem(st, SizeOf(TShowState));
  st := nil;
end;

end.
