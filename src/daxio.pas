{ BIOS text output, bottom-line prompts, rounded memory allocation and DAX archive loading. }
{$O+,F+}
unit DaxIo;

interface

uses Types, Crt, GDConsts, GDVars, Dos, GameIo;

procedure FreeRounded(var p: Pointer; n: Word);

procedure AllocRounded(var p: Pointer; n: Word);

procedure WriteChar(col, row, attr, count, ch: Byte);

procedure WriteString(col, row, attr: Byte; source: string);

procedure WriteBlock(col, row, attr, count: Byte);

procedure PromptBox(attr: Byte; message: Types.TStr40);

procedure OverlayPrompt;

function OpenWithRetry(fileName: Types.TPathStr; promptMsg: Types.TStr40; noPrompt: Char; var f: file): Boolean;

function FileExists(name: Types.TPathStr): Boolean;

function SanitizeString(src, del: string): string;

function SanitizeFileName(name: string): Types.TStr40;

procedure DecompressDax(var src, dst: Types.PByteArr; var lenCompressed, lenDecompressed: Word);

function OpenDax(dirName, ext: Types.TPathStr; var headerSize: Word; var f1, f2: file): Boolean;

procedure CloseDax(var f1, f2: file);

procedure LoadDax(fileName, ext: Types.TStr20; fileID: Byte; var sizeRead: Word; var data: Types.PByteArr);

procedure PushState(v: Byte);

procedure PopState;

implementation

var
  { current data-path prefix string }
  gameDir: String absolute GDVars.gameDir;
  { OpenDax's suppress-prompt flag }
  suppressInsertPrompt: Char absolute GDVars.dsSuppressingInsertDiskFlag;

{ Free a block using the same eight-byte size rounding as allocation. }
procedure FreeRounded(var p: Pointer; n: Word);
begin
  FreeMem(p, (n + 7) and $FFF8);
end;

{ AllocRounded: GetMem, size rounded up to a multiple of 8 }
procedure AllocRounded(var p: Pointer; n: Word);
begin
  GetMem(p, (n + 7) and $FFF8);
end;

{ WriteChar: Position the cursor (int10 AH=2) then write count copies of ch+attr (int10 AH=9) on the main page. In CGA
  mode (display mode 0) the attribute is first mapped through the 16-entry EGA->CGA table; in EGA mode (1) the pair is
  repeated, unmapped, on the alternate page. Note: attr is not range-checked against that table }
procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  GDVars.dsInterruptRegisters.ah := 2;
  GDVars.dsInterruptRegisters.bh := GDVars.pageMain;
  GDVars.dsInterruptRegisters.dh := row;
  GDVars.dsInterruptRegisters.dl := col;
  Intr($10, GDVars.dsInterruptRegisters);
  GDVars.dsInterruptRegisters.ah := 9;
  GDVars.dsInterruptRegisters.al := ch;
  GDVars.dsInterruptRegisters.bh := GDVars.pageMain;
  if GDVars.videoMode = 0 then
    GDVars.dsInterruptRegisters.bl := GDConsts.attrTable[attr]
  else
    GDVars.dsInterruptRegisters.bl := attr;
  GDVars.dsInterruptRegisters.cx := count;
  Intr($10, GDVars.dsInterruptRegisters);
  if GDVars.videoMode = 1 then begin
    GDVars.dsInterruptRegisters.ah := 2;
    GDVars.dsInterruptRegisters.bh := GDVars.pageNum;
    GDVars.dsInterruptRegisters.dh := row;
    GDVars.dsInterruptRegisters.dl := col;
    Intr($10, GDVars.dsInterruptRegisters);
    GDVars.dsInterruptRegisters.ah := 9;
    GDVars.dsInterruptRegisters.al := ch;
    GDVars.dsInterruptRegisters.bh := GDVars.pageNum;
    GDVars.dsInterruptRegisters.bl := attr;
    GDVars.dsInterruptRegisters.cx := count;
    Intr($10, GDVars.dsInterruptRegisters);
  end;
end;

{ WriteString: Write each char of source at (col,row)/attr, advancing col }
procedure WriteString(col, row, attr: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin
  n := Length(source);
  for i := 1 to n do begin
    DaxIo.WriteChar(col, row, attr, 1, Ord(source[i]));
    Inc(col);
  end;
end;

{ WriteBlock: Write count solid blocks (219) }
procedure WriteBlock(col, row, attr, count: Byte);
begin
  DaxIo.WriteChar(col, row, attr, count, 219);
end;

{ Show a bottom-line (row 24) prompt, wait for a key and clear the 40-column prompt bar. }
procedure PromptBox(attr: Byte; message: Types.TStr40);
var key: Char;
begin
  DaxIo.WriteBlock(0, 24, Black, 40);
  DaxIo.WriteString(0, 24, attr, message);
  key := GameIo.ReadGameKey;
  DaxIo.WriteBlock(0, 24, Black, 40);
end;

{ I/O checking is off ($I-) across OverlayPrompt/OpenWithRetry/FileExists so IOResult is usable; it is back on ($I+) for
  the rest of the unit }
{$I-}

{ Wait for GAME.OVR to be found, asking for the overlay disk and a key between tries. }
procedure OverlayPrompt;
var key: Char; found: Boolean;
begin
  repeat
    found := DaxIo.FileExists('game.ovr');
    if not found then begin
      WriteLn('Please insert overlay disk.');
      key := GameIo.ReadGameKey;
    end;
  until found;
end;

{ OpenWithRetry: Try to open fileName; if missing and prompts are allowed (noPrompt = #0), show promptMsg (attr 14)
  through PromptBox and retry. On success Assign+Reset the caller's untyped file f (recsize 1). Returns found }
function OpenWithRetry(fileName: Types.TPathStr; promptMsg: Types.TStr40; noPrompt: Char; var f: file): Boolean;
var found: Boolean;
begin
  repeat
    found := DaxIo.FileExists(fileName);
    if (not found) and (noPrompt = #0) then
      DaxIo.PromptBox(Yellow, promptMsg);
  until found or (noPrompt <> #0);
  if found then begin
    Assign(f, fileName);
    Reset(f, 1);
  end;
  OpenWithRetry := found;
end;

{ FileExists: Assign/Reset(recsize 128)/Close the name and report success: IOResult (kept in ioErr) clean AND the name
  non-empty }
function FileExists(name: Types.TPathStr): Boolean;
var f: file;
begin
  Assign(f, name);
  Reset(f, 128);
  Close(f);
  GDVars.ioErr := IOResult;
  FileExists := (GDVars.ioErr = 0) and (name <> '');
end;

{$I+}

{ Remove occurrences of del from src in one left-to-right pass. After a deletion the scan moves on, so an occurrence
  that slides into the deleted position is kept (adjacent repeats lose only every other copy). }
function SanitizeString(src, del: string): string;
var
  limit: Byte;
  delLen: Byte;
  i: Byte;
begin
  delLen := Length(del);
  limit := Length(src) - delLen + 1;
  for i := 1 to limit do
    if Copy(src, i, delLen) = del then
      Delete(src, i, delLen);
  SanitizeString := src;
end;

{ Remove invalid filename characters (with SanitizeString's single-pass rule), limit the name to eight characters and
  uppercase it. }
function SanitizeFileName(name: string): Types.TStr40;
var i: Byte;
begin
  for i := 1 to 10 do
    name := DaxIo.SanitizeString(name, GDConsts.invalidFileChars[i]);
  name := Copy(name, 1, 8);
  for i := 1 to Length(name) do
    name[i] := UpCase(name[i]);
  SanitizeFileName := name;
end;

{ Decode DAX run-length data. Controls 0..$7E copy the next b+1 bytes; $81..$FF repeat the next byte -b times; $7F and
  $80 are skipped, as Secret does. A run is cut short at the end of either buffer, and decoding stops when the input
  runs out or lenDecompressed bytes have been written. }
procedure DecompressDax(var src, dst: Types.PByteArr; var lenCompressed, lenDecompressed: Word);
var
  srcIdx: Word;
  dstIdx: Word; b: ShortInt;
  n: Word;
begin
  srcIdx := 0;
  dstIdx := 0;
  while (srcIdx < lenCompressed) and (dstIdx < lenDecompressed) do begin
    b := src^[srcIdx];
    Inc(srcIdx);
    case b of
      0..$7E: begin
        n := b + 1;
        if n > lenCompressed - srcIdx then n := lenCompressed - srcIdx;
        if n > lenDecompressed - dstIdx then n := lenDecompressed - dstIdx;
        Move(src^[srcIdx], dst^[dstIdx], n);
        Inc(srcIdx, n);
        Inc(dstIdx, n);
      end;
      -127..-1:
        if srcIdx < lenCompressed then begin
          n := -b;
          if n > lenDecompressed - dstIdx then n := lenDecompressed - dstIdx;
          FillChar(dst^[dstIdx], n, src^[srcIdx]);
          Inc(srcIdx);
          Inc(dstIdx, n);
        end;
    end;
  end;
end;

{ Open two handles on the same DAX archive. Use one for directory entries and position the other at the data area, after
  the two-byte header size and directory. Missing media prompts through OpenWithRetry with insertDiskMsg for the current
  virtual disk, unless suppressInsertPrompt is set. }
function OpenDax(dirName, ext: Types.TPathStr; var headerSize: Word; var f1, f2: file): Boolean;
var nread: Word;
begin
  if DaxIo.OpenWithRetry(dirName + ext, GDConsts.insertDiskMsg[GDVars.virtualDisk] + GDVars.gameDir[1] + ':',
                         suppressInsertPrompt, f1) then begin
    Assign(f2, dirName + ext);
    Reset(f2, 1);
    BlockRead(f2, headerSize, SizeOf(headerSize), nread);
    Inc(headerSize, SizeOf(headerSize));
    Seek(f1, headerSize);
    OpenDax := True;
  end else
    OpenDax := False;
end;

{ CloseDax: Close both archive file handles (they refer to the same physical file) }
procedure CloseDax(var f1, f2: file);
begin
  Close(f1);
  Close(f2);
end;

{ Find a DAX block by ID in gameDir + fileName + ext, read and decompress it into a new buffer of sizeRead bytes, then
  release the compressed buffer. Any directory entry scanned with a compressed size above 36000 shows a 'tempsize'
  prompt and exits the game. Return sizeRead=0 and data=nil if the archive cannot be opened or the ID is absent. }
procedure LoadDax(fileName, ext: Types.TStr20; fileID: Byte; var sizeRead: Word; var data: Types.PByteArr);
var compSize: Word; offset: LongInt; id: Byte; n: Word;
    f1: file;
    f2: file; hdrSize: Word; pad802: Byte; numStr: String[6];
begin
  if not DaxIo.OpenDax(gameDir + fileName, ext, hdrSize, f1, f2) then begin
    sizeRead := 0;
    data := nil;
    Exit;
  end;
  repeat
    BlockRead(f2, id, SizeOf(id), n);
    BlockRead(f2, offset, SizeOf(offset), n);
    { decompressed size }
    BlockRead(f2, sizeRead, SizeOf(sizeRead), n);
    { compressed size }
    BlockRead(f2, compSize, SizeOf(compSize), n);
    if compSize > 36000 then begin
      Str(LongInt(compSize), numStr);
      DaxIo.PromptBox(Yellow, 'tempsize ' + numStr);
      GameIo.ExitGame;
    end;
  until (id = fileID) or (FilePos(f2) >= hdrSize);
  if id <> fileID then begin
    sizeRead := 0;
    data := nil;
    DaxIo.CloseDax(f1, f2);
  end else begin
    DaxIo.AllocRounded(Pointer(GDVars.dsDaxCompressedFilePtr), compSize);
    GetMem(data, sizeRead);
    Seek(f1, hdrSize + offset);
    BlockRead(f1, GDVars.dsDaxCompressedFilePtr^, compSize, n);
    DaxIo.CloseDax(f1, f2);
    DaxIo.DecompressDax(GDVars.dsDaxCompressedFilePtr, data, compSize, sizeRead);
    DaxIo.FreeRounded(Pointer(GDVars.dsDaxCompressedFilePtr), compSize);
  end;
end;

{ Save the current resource disk and select a new one. }
procedure PushState(v: Byte);
begin
  GDVars.prevVirtualDisk := GDVars.virtualDisk;
  GDVars.virtualDisk := v;
end;

{ Restore the saved resource disk. }
procedure PopState;
begin
  GDVars.virtualDisk := GDVars.prevVirtualDisk;
end;

end.
