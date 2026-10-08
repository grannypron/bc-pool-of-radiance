{ Game-font text rendering, message-window input and centisecond timing. }
{$O+,F+}
unit TextRend;

interface

uses Types, DaxIo, C_Video, C_Ega, GDConsts, GDVars, Crt, Dos, GameIo, Video, C_Keys;

procedure NoopTextrend;

procedure LoadGameFont;

procedure DisplayString(col, row, color: Byte; source: string);

procedure RenderChar(col, row, color, count, ch, isASCII: Byte);

procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, color: Byte; clearFirst: Boolean; source: string);

procedure PrintSpaces(col, row, color, count: Byte);

function ReadString(query: Types.TStr40; color, maxLen: Byte): Types.TStr40;

function InputUint16(query: Types.TStr40; color: Byte): Word;

procedure DisplayAndPause(color: Byte; msg: Types.TStr40);

function GetTicks: LongInt;

procedure ClearScreen;

procedure PrintAndPause(msg: Types.TStr40; color: Byte);

procedure PauseOnly;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);

implementation

var

  displayMode: Types.TVideoMode absolute GDVars.videoMode;
  cgaB800: array[0..255] of Types.TCgaRow absolute C_Video.GFX_BANK0_SEG:$0000;
  cgaBA00: array[0..255] of Types.TCgaRow absolute C_Video.GFX_BANK1_SEG:$0000;
  tdyB800: array[0..255] of Types.TTdyRow absolute C_Video.GFX_BANK0_SEG:$0000;
  tdyBA00: array[0..255] of Types.TTdyRow absolute C_Video.GFX_BANK1_SEG:$0000;
  tdyBC00: array[0..255] of Types.TTdyRow absolute C_Video.GFX_BANK2_SEG:$0000;
  tdyBE00: array[0..255] of Types.TTdyRow absolute C_Video.GFX_BANK3_SEG:$0000;

{ Load font block 201 from 8X8D1.DAX, copy it into gameFont and free the loader's buffer. Nothing is copied if the block
  cannot be loaded. }
procedure LoadGameFont;
var
  compSize: Word;
  dataPtr: Types.PByteArr;
begin
  DaxIo.LoadDax('8X8d1', '.dax', 201, compSize, dataPtr);
  if compSize = 0 then Exit;
  Move(dataPtr^, GDVars.gameFont^, compSize);
  FreeMem(dataPtr, compSize);
end;

{ Draw count copies of a game-font glyph at character coordinates, advancing one column per copy. isASCII <> 0 maps ch
  through UpCase mod 64; otherwise ch is the glyph index. Ignore an out-of-range starting position or an unloaded font;
  later copies are not range-checked. CGA maps colors and writes packed pixels, EGA writes all four planes to both
  pages, and Tandy packs two pixels per byte across four banks. Note: the CGA arm maps color through attrTable once per
  copy, so with count > 1 every copy after the first uses a re-mapped color. }
procedure RenderChar(col, row, color, count, ch, isASCII: Byte);
var
  i: Byte;
  charIdx: Byte;
  dstOff: Word;
  cnt: Word;
  colBase: Word;
  cgaWord: Word;
  tandyPx: Byte;
  k: Byte;
  mask: Byte;
  bank: Byte;
  outerRow: Byte;
  pad: Byte;
begin
  if (col > 39) or (row > 24) or (GDVars.gameFont = nil) then Exit;
  if isASCII <> 0 then
    charIdx := Ord(UpCase(Chr(ch))) mod 64
  else
    charIdx := ch;
  for i := 1 to count do begin
    case displayMode of
      Types.vmCGA: begin
        color := GDConsts.attrTable[color];
        dstOff := row * 4;
        cnt := 0;
        for outerRow := 0 to 3 do begin
          cgaWord := 0;
          mask := $80;
          for k := 0 to 7 do begin
            if (GDVars.gameFont^[charIdx][cnt] and mask) > 0 then
              cgaWord := cgaWord or (GDConsts.cgaPixelMask[k] and GDConsts.cgaColorPat[color]);
            mask := mask shr 1;
          end;
          cgaB800[dstOff][col] := Swap(cgaWord);
          Inc(cnt);
          cgaWord := 0;
          mask := $80;
          for k := 0 to 7 do begin
            if (GDVars.gameFont^[charIdx][cnt] and mask) > 0 then
              cgaWord := cgaWord or (GDConsts.cgaPixelMask[k] and GDConsts.cgaColorPat[color]);
            mask := mask shr 1;
          end;
          cgaBA00[dstOff][col] := Swap(cgaWord);
          Inc(cnt);
          Inc(dstOff);
        end;
      end;
      Types.vmEGA: begin
        dstOff := (row * 8) * 40 + col;
        Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG;
        for outerRow := 0 to 7 do begin
          for k := 0 to 3 do begin
            Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneMask[3 - k];
            if (GDConsts.egaPlaneMask[3 - k] and color) > 0 then begin
              Mem[GDVars.egaCurPage: dstOff] := GDVars.gameFont^[charIdx][outerRow];
              Mem[GDVars.egaOtherPage: dstOff] := GDVars.gameFont^[charIdx][outerRow];
            end else begin
              Mem[GDVars.egaCurPage: dstOff] := 0;
              Mem[GDVars.egaOtherPage: dstOff] := 0;
            end;
          end;
          Inc(dstOff, 40);
        end;
        Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
      end;
      Types.vmTandy: begin
        dstOff := 0;
        cnt := row * 2;
        colBase := col * 4;
        for outerRow := 0 to 1 do begin
          for bank := 0 to 3 do begin
            mask := $80;
            for k := 0 to 3 do begin
              if (GDVars.gameFont^[charIdx][dstOff] and mask) > 0 then
                tandyPx := color shl 4
              else
                tandyPx := 0;
              mask := mask shr 1;
              if (GDVars.gameFont^[charIdx][dstOff] and mask) > 0 then
                tandyPx := tandyPx or color;
              mask := mask shr 1;
              case bank of
                0: tdyB800[cnt][k + colBase] := tandyPx;
                1: tdyBA00[cnt][k + colBase] := tandyPx;
                2: tdyBC00[cnt][k + colBase] := tandyPx;
                3: tdyBE00[cnt][k + colBase] := tandyPx;
              end;
            end;
            Inc(dstOff);
          end;
          Inc(cnt);
        end;
      end;
    end;
    Inc(col);
  end;
end;

{ Draw count spaces from (col, row); an off-screen start is ignored. }
procedure PrintSpaces(col, row, color, count: Byte);
begin
  if (col < 0) or (col > 39) or (row < 0) or (row > 24) then Exit;
  TextRend.RenderChar(col, row, color, count, 32, 1);
end;

{ Draw a string in the game font at the requested column, row and color. The row guard here tests 39, not 24; RenderChar
  applies the real bound. }
procedure DisplayString(col, row, color: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin
  if (col > 39) or (row > 39) then Exit;
  n := Length(source);
  for i := 1 to n do begin
    TextRend.RenderChar(col, row, color, 1, Ord(source[i]), 1);
    Inc(col);
  end;
end;

{ Print text with word wrapping and paging inside the requested window. Skip leading break characters, scan each word
  and include trailing punctuation before deciding where to wrap. }
procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, color: Byte; clearFirst: Boolean; source: string);
var
  len: Byte;
  width: Byte;
  idx: Byte;
  lineEnd: Byte;
  pad: Byte;

  { PrintCharInWindow: Flush source[idx..lineEnd] at the cursor, advancing idx/curCol; per-char Delay when slow text is
    on }
  procedure PrintCharInWindow;
  begin
    while idx <= lineEnd do begin
      TextRend.RenderChar(GDVars.curCol, GDVars.curRow, color, 1, Ord(source[idx]), 1);
      if GDVars.msgDelayFlag <> 0 then Delay(GDVars.gameDelay * 10);
      Inc(idx);
      Inc(GDVars.curCol);
    end;
  end;

  { FindNewIndex: Skip the spaces a line break consumed }
  procedure FindNewIndex;
  begin
    while (idx < len) and (source[idx] = ' ') do Inc(idx);
  end;

begin
  if (ulCol > 39) or (ulRow > 24) or (lrCol > 39) or (lrRow > 39) then Exit;
  if (GDVars.curCol < ulCol) or (GDVars.curCol > lrCol) or (GDVars.curRow < ulRow) or
      (GDVars.curRow > lrRow) then begin
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow;
  end;
  if clearFirst then begin
    TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow;
  end;
  idx := 1;
  len := Length(source);
  if len = 0 then Exit;
  width := lrCol - ulCol + 1;
  repeat
    lineEnd := idx;
    while (lineEnd < len) and (source[lineEnd] in GDConsts.breakChars) do
      Inc(lineEnd);
    while (lineEnd < len) and not (source[lineEnd] in GDConsts.breakChars) and (source[lineEnd] <> ' ') do
      Inc(lineEnd);
    if source[lineEnd] <> ' ' then
      while (lineEnd + 1 < len) and (source[lineEnd + 1] in GDConsts.breakChars) do
        Inc(lineEnd);
    if lineEnd - idx + GDVars.curCol > lrCol then begin
      if (lineEnd - idx + GDVars.curCol = lrCol) and (source[lineEnd] = ' ') then begin
        Dec(lineEnd);
        PrintCharInWindow;
      end;
      GDVars.curCol := ulCol;
      Inc(GDVars.curRow);
      FindNewIndex;
      if (GDVars.curRow > lrRow) and (idx < len) then begin
        GDVars.curCol := ulCol;
        GDVars.curRow := ulRow;
        TextRend.DisplayAndPause(LightMagenta, 'Press any key to continue');
        GameIo.PollGameKeys;
        TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
        PrintCharInWindow;
      end;
    end else
      PrintCharInWindow;
  until idx > len;
  if GDVars.curCol > lrCol then begin
    GDVars.curCol := ulCol;
    Inc(GDVars.curRow);
  end;
end;

{ ReadString: Prompt with query on the bottom row, then edit a line of up to maxLen chars: printable keys ' '..'z'
  append + echo in white (game font), backspace trims, Return/Escape ends (Escape does not discard the input); the
  result is uppercased }
function ReadString(query: Types.TStr40; color, maxLen: Byte): Types.TStr40;
var
  col: Byte;
  reply: string;
  key: Char;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, query);
  col := Length(query);
  reply := '';
  repeat
    key := GameIo.ReadGameKey;
    case key of
      ' '..'z':
        if Length(reply) < maxLen then begin
          reply := reply + key;
          Inc(col);
          TextRend.DisplayString(col, 24, White, key);
        end;
      C_Keys.BACKSPACE:
        if Length(reply) > 0 then begin
          reply := Copy(reply, 1, Length(reply) - 1);
          TextRend.PrintSpaces(col, 24, Black, 1);
          Dec(col);
        end;
    end;
  until (key = C_Keys.ENTER) or (key = C_Keys.ESC);
  TextRend.PrintSpaces(0, 24, Black, 40);
  for col := 1 to Length(reply) do
    reply[col] := UpCase(reply[col]);
  ReadString := reply;
end;

{ Prompt for up to six characters until they parse as an integer in 0..65536. Note: the range test admits 65536, which
  wraps to 0 in the Word result. }
function InputUint16(query: Types.TStr40; color: Byte): Word;
var
  num: LongInt;
  reply: Types.TStr40;
  code: Integer;
begin
  repeat
    reply := TextRend.ReadString(query, color, 6);
    Val(reply, num, code);
    if code = 0 then
      if (num > 65536) or (num < 0) then code := 1;
  until code = 0;
  InputUint16 := num;
end;

{ Clear the bottom row, print a message in the requested color and wait for a key. }
procedure DisplayAndPause(color: Byte; msg: Types.TStr40);
var
  key: Char;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, msg);
  key := GameIo.ReadGameKey;
end;

{ Return the DOS clock in centiseconds. Note: the minute product wraps at 16 bits before accumulation, so the value can
  jump backward within an hour. }
function GetTicks: LongInt;
var
  h: Word;
  m: Word;
  s: Word;
  s100: Word;
begin
  GetTime(h, m, s, s100);
  GetTicks := LongInt(h) * 360000 + m * 6000 + s * 100 + s100;
end;

{ Clear the whole screen to black: both EGA pages, or every CGA or Tandy bank. }
procedure ClearScreen;
begin
  case displayMode of
    Types.vmCGA: begin
      FillChar(cgaBA00, SizeOf(Types.TCgaBank), 0);
      FillChar(cgaB800, SizeOf(Types.TCgaBank), 0);
    end;
    Types.vmEGA: begin
      Video.FillRectEga(0, 0, 39, 24, 0, Black);
      Video.FillRectEga(0, 0, 39, 24, 1, Black);
    end;
    Types.vmTandy: begin
      FillChar(tdyB800, SizeOf(Types.TTandyBank), 0);
      FillChar(tdyBA00, SizeOf(Types.TTandyBank), 0);
      FillChar(tdyBC00, SizeOf(Types.TTandyBank), 0);
      FillChar(tdyBE00, SizeOf(Types.TTandyBank), 0);
    end;
  end;
end;

{ PrintAndPause: Clear the bottom row, print msg in color, pause on the text delay (not a keywait), clear again. Note
  the param order is (msg, color) -- reversed vs DisplayAndPause }
procedure PrintAndPause(msg: Types.TStr40; color: Byte);
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, msg);
  TextRend.PauseOnly;
  TextRend.PrintSpaces(0, 24, Black, 40);
end;

{ PauseOnly: Crt.Delay scaled by the shared text delay: gameDelay * 225 ms }
procedure PauseOnly;
begin
  Delay(GDVars.gameDelay * 225);
end;

{ Clear a character-cell rectangle to black (on both EGA pages). }
procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);
var
  firstRow: Word;
  lastRow: Word;
  firstByteColumn: Word;
  byteCount: Word;
  row: Word;
begin
  case displayMode of
    Types.vmCGA: begin
      firstRow := ulRow * 4;
      lastRow := lrRow * 4 + 3;
      byteCount := (lrCol - ulCol + 1) * 2;
      for row := firstRow to lastRow do begin
        FillChar(cgaB800[row][ulCol], byteCount, 0);
        FillChar(cgaBA00[row][ulCol], byteCount, 0);
      end;
    end;
    Types.vmEGA: begin
      Video.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, Black);
      Video.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, Black);
    end;
    Types.vmTandy: begin
      firstRow := ulRow * 2;
      lastRow := lrRow * 2 + 1;
      firstByteColumn := ulCol * 4;
      byteCount := (lrCol - ulCol + 1) * 4;
      for row := firstRow to lastRow do begin
        FillChar(tdyB800[row][firstByteColumn], byteCount, 0);
        FillChar(tdyBA00[row][firstByteColumn], byteCount, 0);
        FillChar(tdyBC00[row][firstByteColumn], byteCount, 0);
        FillChar(tdyBE00[row][firstByteColumn], byteCount, 0);
      end;
    end;
  end;
end;

{ Reserved entry point; does nothing }
procedure NoopTextrend;
begin
end;

begin
end.
