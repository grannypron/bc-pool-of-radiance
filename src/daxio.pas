{ BIOS text output, bottom-line prompts, rounded memory allocation and DAX archive loading. }
{$O+,F+}
{$I COMPILER.INC}
unit DaxIo;

interface

uses Types;

var
  { disk saved by DaxIo.PushState for PopState }
  prevVirtualDisk: Byte;

procedure FreeRounded(var p: Pointer; n: Word);

procedure AllocRounded(var p: Pointer; n: Word);

procedure WriteChar(col, row, attr, count, ch: Byte);

{ Position the cursor on display page page and write count copies of ch in attr there, through the BIOS (INT 10h). The
  video drivers' WriteChar calls it once for each page they keep. }
procedure BiosWriteChar(page, col, row, attr, count, ch: Byte);

procedure WriteString(col, row, attr: Byte; source: string);

procedure WriteBlock(col, row, attr, count: Byte);

procedure PromptBox(attr: Byte; message: Types.TStr40);

{ PromptBox, returning the key (#0 for an extended key). }
function PromptKey(attr: Byte; message: Types.TStr40): Char;

{ name's full path (expanded from the current directory), or its end, where the file's name is, after '...' when it
  is longer than room characters. }
function PathForLine(name: Types.TPathStr; room: Byte): Types.TPathStr;

{ On the bottom line, problem and name's path ('Not found: C:\POOL\ITEMS'), then diskMsg, each until a key: the key
  that answered diskMsg. }
function AskForDisk(problem: Types.TStr40; name: Types.TPathStr; diskMsg: Types.TStr40): Char;

{ 'Insert disk N in drive X: (Esc quits)', for the current virtual disk and the data drive. }
function DataDiskMsg: Types.TStr40;

{ Before the game's screen is up (plain DOS text): until file name is there, say it is not, with its path, and ask
  with diskMsg, each time until a key; Escape quits to DOS (SSI asked until it was there). }
procedure WaitForFile(name: Types.TPathStr; diskMsg: Types.TStr40);

function OpenWithRetry(fileName: Types.TPathStr; promptMsg: Types.TStr40; noPrompt, escQuits: Boolean;
  var f: file): Boolean;

{ The drive the game's data is read from: GameVars.gameDir's, or the current drive while GameVars.gameDir is empty
  (GameInit and the introduction clear it to read their files from the current directory, as SSI's startup disk). }
function DataDrive: Char;

function FileExists(name: Types.TPathStr): Boolean;

function SanitizeString(src, del: string): string;

function SanitizeFileName(name: string): Types.TStr40;

procedure DecompressDax(var src, dst: Types.PByteArr; var lenCompressed, lenDecompressed: Word);

function OpenDax(dirName, ext: Types.TPathStr; var headerSize: Word; var f1, f2: file): Boolean;

procedure CloseDax(var f1, f2: file);

procedure LoadDax(fileName, ext: Types.TStr20; fileID: Byte; var sizeRead: Word; var data: Types.PByteArr);

{ Read and decode one block of f, an archive OpenDax opened with hdrSize bytes before its first block, into a new
  buffer of sizeRead bytes in data: the block whose directory entry gives its offset and packed size compSize. Only the
  bytes actually read are decoded, so a block cut short is zeroed past what the file holds. }
procedure ReadBlock(var f: file; hdrSize: Word; offset: LongInt; compSize, sizeRead: Word; var data: Types.PByteArr);

{ True when the family's merged archive is whole, holds C_DATA.VERSION and was built from the per-disk archives there
  now (DaxIo.SourcesMatch). The answer is remembered until ResetArchiveCache; the first True also reads the archive's
  remap entries, and is False instead when they do not all fit in the table (C_DATA.FAMILY_REMAPS per family). }
function FamilyUsable(family: Byte): Boolean;

{ Forget what FamilyUsable has found, so the next load looks at the merged archives afresh. DataBld calls it before
  checking them at startup and after building them. }
procedure ResetArchiveCache;

{ The archive a load of an ordinary block id from fileName (no extension) really opens: the merged archive of its data
  family when fileName names a per-disk archive that exists and the merged archive is usable, otherwise fileName
  itself. A load of one of C_DATA's reserved ids always opens fileName (LoadDax). }
function ArchiveName(fileName: Types.TStr20): Types.TStr20;

{ The id a load of id from the family's archive on disk reads in the merged archive: id itself unless that disk's block
  went to a spare id when the merged archive was built (its remap block). Valid once FamilyUsable has said True. }
function RemapId(family, disk, id: Byte): Byte;

{ True when the per-disk archive GameVars.gameDir + fileName + '.DAX' itself, never a merged archive read in its place,
  lists block fileID. False, with no prompt, when that file cannot be read. }
function DiskHasBlock(fileName: Types.TStr20; fileID: Byte): Boolean;

procedure PushState(v: Byte);

procedure PopState;

implementation

uses Crt, GameDefs, GameVars, Dos, GameIo, C_DATA, C_KEYS, DataArc, FileUtil{$IFDEF FPC}, Host, NatFile{$ENDIF};

var
  { Temporary compressed DAX data buffer. }
  daxCompressedFilePtr: Types.PByteArr;

const
  { the most remap entries kept from all merged archives together: as many per family as DataBld builds }
  MAX_REMAPS = C_DATA.FAMILIES * C_DATA.FAMILY_REMAPS;

var
  { Per data family: 0 = not looked at yet, 1 = its merged archive is usable, 2 = it is not. }
  familyState: array[1..C_DATA.FAMILIES] of Byte;
  { Per usable family: bit d - 1 set when disk d has its own per-disk archive. A disk without one is never redirected,
    so a load that found nothing before still finds nothing. }
  familyDisks: array[1..C_DATA.FAMILIES] of Byte;
  { Remap entries read from the usable merged archives: a load of remapFrom on remapDisk of remapFamily reads remapTo. }
  remapCount: Byte;
  remapFamily: array[1..MAX_REMAPS] of Byte;
  remapDisk: array[1..MAX_REMAPS] of Byte;
  remapFrom: array[1..MAX_REMAPS] of Byte;
  remapTo: array[1..MAX_REMAPS] of Byte;

{ Free a block using the same eight-byte size rounding as allocation. }
procedure FreeRounded(var p: Pointer; n: Word);
begin
  FreeMem(p, (n + 7) and $FFF8);
end;

{ GetMem, with the size rounded up to a multiple of 8. }
procedure AllocRounded(var p: Pointer; n: Word);
begin
  GetMem(p, (n + 7) and $FFF8);
end;

{ Count copies of ch in attr at (col, row) through the BIOS, as the video driver writes them (GameVars.video.WriteChar,
  which calls BiosWriteChar for each display page it keeps). }
procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  GameVars.video.WriteChar(col, row, attr, count, ch);
end;

{ Position the cursor on page (INT 10h AH=2), then write count copies of ch in attr there (AH=9). }
procedure BiosWriteChar(page, col, row, attr, count, ch: Byte);
begin
  GameVars.interruptRegisters.ah := 2;
  GameVars.interruptRegisters.bh := page;
  GameVars.interruptRegisters.dh := row;
  GameVars.interruptRegisters.dl := col;
  Intr($10, GameVars.interruptRegisters);
  GameVars.interruptRegisters.ah := 9;
  GameVars.interruptRegisters.al := ch;
  GameVars.interruptRegisters.bh := page;
  GameVars.interruptRegisters.bl := attr;
  GameVars.interruptRegisters.cx := count;
  Intr($10, GameVars.interruptRegisters);
end;

{ Write each char of source at (col, row) in attr, advancing col. }
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

{ Write count solid blocks (219). }
procedure WriteBlock(col, row, attr, count: Byte);
begin
  DaxIo.WriteChar(col, row, attr, count, 219);
end;

{ Show a bottom-line (row 24) prompt, wait for a key and clear the 40-column prompt bar. }
procedure PromptBox(attr: Byte; message: Types.TStr40);
var key: Char;
begin
  key := DaxIo.PromptKey(attr, message);
end;

function PromptKey(attr: Byte; message: Types.TStr40): Char;
begin
  DaxIo.WriteBlock(0, 24, Black, 40);
  DaxIo.WriteString(0, 24, attr, message);
  PromptKey := GameIo.ReadAnyKey;
  DaxIo.WriteBlock(0, 24, Black, 40);
end;

{ I/O checking is off ($I-) across WaitForFile/OpenWithRetry/FileExists so IOResult is usable; it is back on ($I+) for
  the rest of the unit }
{$I-}

function PathForLine(name: Types.TPathStr; room: Byte): Types.TPathStr;
var
  full: Types.TPathStr;
begin
  full := FExpand(name);
  if Length(full) > room then
    full := '...' + Copy(full, Length(full) - room + 4, room - 3);
  PathForLine := full;
end;

function AskForDisk(problem: Types.TStr40; name: Types.TPathStr; diskMsg: Types.TStr40): Char;
begin
  DaxIo.PromptBox(Yellow, problem + ': ' + DaxIo.PathForLine(name, 38 - Length(problem)));
  AskForDisk := DaxIo.PromptKey(Yellow, diskMsg);
end;

function DataDiskMsg: Types.TStr40;
const
  { Insert-disk prompts, indexed by virtualDisk, which SaveLoad and the ECL keep in 1..LAST_DISK }
  insertDiskMsg: array[1..Types.LAST_DISK] of string[29] = (
    'Insert disk 1 in drive ',
    'Insert disk 2 in drive ',
    'Insert disk 3 in drive ',
    'Insert disk 4 in drive ',
    'Insert disk 5 in drive ',
    'Insert disk 6 in drive ',
    'Insert disk 7 in drive ',
    'Insert disk 8 in drive ');
begin
  DataDiskMsg := insertDiskMsg[GameVars.virtualDisk] + DaxIo.DataDrive + ': (Esc quits)';
end;

procedure WaitForFile(name: Types.TPathStr; diskMsg: Types.TStr40);
begin
  while not DaxIo.FileExists(name) do begin
    WriteLn('Not found: ', DaxIo.PathForLine(name, 68));
    WriteLn(diskMsg, ' (Esc quits)');
    { nothing is set up yet: no screen mode or sound to put back }
    if GameIo.ReadAnyKey = C_KEYS.ESC then
      Halt;
  end;
end;

function DataDrive: Char;
var
  s: String;
begin
  if Length(GameVars.gameDir) > 0 then
    DataDrive := UpCase(GameVars.gameDir[1])
  else begin
    GetDir(0, s);
    DataDrive := UpCase(s[1]);
  end;
end;

{ Try to open fileName; if missing and prompts are allowed (noPrompt False), say which file is missing, with its path,
  then ask with promptMsg (AskForDisk), and retry. Escape at promptMsg gives up, or with escQuits (the game's data,
  which it cannot go on without) quits to DOS (GameIo.ExitGame); SSI asked until the file was there (#794). On success
  open the caller's untyped file f for reading only (FileUtil.OpenReadOnly, recsize 1), so a read-only file opens too:
  every caller only reads. Returns found. }
function OpenWithRetry(fileName: Types.TPathStr; promptMsg: Types.TStr40; noPrompt, escQuits: Boolean;
  var f: file): Boolean;
var
  found: Boolean;
  gaveUp: Boolean;
begin
  gaveUp := False;
  repeat
    found := DaxIo.FileExists(fileName);
    if (not found) and not noPrompt then
      if DaxIo.AskForDisk('Not found', fileName, promptMsg) = C_KEYS.ESC then begin
        if escQuits then
          GameIo.ExitGame;
        gaveUp := True;
      end;
  until found or noPrompt or gaveUp;
  if found then
    found := FileUtil.OpenReadOnly(f, fileName);
  OpenWithRetry := found;
end;

{ Open name for reading only (FileUtil.OpenReadOnly, so a read-only file counts), close it and report success: opened
  and closed clean AND the name non-empty. }
function FileExists(name: Types.TPathStr): Boolean;
var
  f: file;
  found: Boolean;
begin
  found := FileUtil.OpenReadOnly(f, name);
  if found then begin
    Close(f);
    found := IOResult = 0;
  end;
  FileExists := found and (name <> '');
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
  uppercase it. A DOS device's name (FileUtil.IsDeviceName) gets an underscore, so a character called Con or Lpt1 is
  kept in a file, as in Curse. }
function SanitizeFileName(name: string): Types.TStr40;
const
  invalidFileChars: array[1..10] of Char = (
    { space }
    ' ',
    { period }
    '.',
    { asterisk }
    '*',
    { comma }
    ',',
    { question mark }
    '?',
    { slash }
    '/',
    { backslash }
    '\',
    { colon }
    ':',
    { semicolon }
    ';',
    { vertical bar }
    '|');
var i: Byte;
begin
  for i := 1 to 10 do
    name := DaxIo.SanitizeString(name, invalidFileChars[i]);
  name := Copy(name, 1, 8);
  for i := 1 to Length(name) do
    name[i] := UpCase(name[i]);
  if FileUtil.IsDeviceName(name) then
    name := name + '_';
  SanitizeFileName := name;
end;

{ Decode DAX run-length data. Controls 0..$7E copy the next b+1 bytes; $81..$FF repeat the next byte -b times; $7F and
  $80 are skipped, as Secret does. A run is cut short at the end of either buffer, and decoding stops when the input
  runs out or lenDecompressed bytes have been written. Output the input did not reach is zeroed. }
procedure DecompressDax(var src, dst: Types.PByteArr; var lenCompressed, lenDecompressed: Word);
var
  srcIdx: Word;
  dstIdx: Word;
  b: ShortInt;
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
  if dstIdx < lenDecompressed then
    FillChar(dst^[dstIdx], lenDecompressed - dstIdx, 0);
end;

{ Open two handles on the same DAX archive. Use one for directory entries and position the other at the data area, after
  the two-byte header size and directory. Missing media prompts through OpenWithRetry with DataDiskMsg (Escape quits),
  unless GameVars.suppressingInsertDiskFlag is set. False, with both handles closed, when the header size cannot be read
  or the directory it gives runs past the end of the file, whose scan would never end. }
function OpenDax(dirName, ext: Types.TPathStr; var headerSize: Word; var f1, f2: file): Boolean;
var nread: Word;
begin
  if DaxIo.OpenWithRetry(dirName + ext, DaxIo.DataDiskMsg, GameVars.suppressingInsertDiskFlag, True, f1) then begin
    { read-only, as f1 is }
    if not FileUtil.OpenReadOnly(f2, dirName + ext) then begin
      Close(f1);
      OpenDax := False;
      Exit;
    end;
    BlockRead(f2, headerSize, SizeOf(headerSize), nread);
    if (nread = SizeOf(headerSize)) and (LongInt(headerSize) + SizeOf(headerSize) <= FileSize(f2)) then begin
      Inc(headerSize, SizeOf(headerSize));
      Seek(f1, headerSize);
      OpenDax := True;
    end else begin
      DaxIo.CloseDax(f1, f2);
      OpenDax := False;
    end;
  end else
    OpenDax := False;
end;

{ Close both archive file handles (they refer to the same physical file). }
procedure CloseDax(var f1, f2: file);
begin
  Close(f1);
  Close(f2);
end;

{ True when disk has its own per-disk archive in the family; valid once FamilyUsable has said True. }
function DiskHasSource(family, disk: Byte): Boolean;
begin
  DiskHasSource := familyDisks[family] and (1 shl (disk - 1)) <> 0;
end;

{ True when the family's per-disk archives are the ones its merged archive's sources block (size bytes at data) lists,
  as far as their sizes tell: each listed file is there with the listed size, and no other is. Notes the listed disks in
  familyDisks. }
function SourcesMatch(family: Byte; data: Types.PByteArr; size: Word): Boolean;
var
  i: Word;
  d: Byte;
  listed: LongInt;
  ok: Boolean;
begin
  familyDisks[family] := 0;
  ok := size mod C_DATA.SOURCE_RECORD = 0;
  i := 0;
  while ok and (i < size) do begin
    d := Byte(data^[i]);
    ok := (d >= 1) and (d <= 8);
    if ok then begin
      Move(data^[i + 1], listed, SizeOf(listed));
      familyDisks[family] := familyDisks[family] or (1 shl (d - 1));
      ok := DataArc.FileLength(GameVars.gameDir + DataArc.SourceName(family, d) + '.DAX') = listed;
    end;
    Inc(i, C_DATA.SOURCE_RECORD);
  end;
  for d := 1 to 8 do
    if ok and not DaxIo.DiskHasSource(family, d) then
      ok := DataArc.FileLength(GameVars.gameDir + DataArc.SourceName(family, d) + '.DAX') < 0;
  SourcesMatch := ok;
end;

function FamilyUsable(family: Byte): Boolean;
var
  size: Word;
  data: Types.PByteArr;
  i: Word;
  first: Byte;
begin
  if familyState[family] = 0 then begin
    familyState[family] := 2;
    if DataArc.ArchiveIntact(GameVars.gameDir + DataArc.MergedName(family) + '.DAX') then begin
      DaxIo.LoadDax(DataArc.MergedName(family), '.dax', C_DATA.VERSION_BLOCK, size, data);
      if data <> nil then begin
        if (size >= 1) and (Byte(data^[0]) = C_DATA.VERSION) then begin
          FreeMem(data, size);
          DaxIo.LoadDax(DataArc.MergedName(family), '.dax', C_DATA.SOURCES_BLOCK, size, data);
          if data <> nil then
            if DaxIo.SourcesMatch(family, data, size) then
              familyState[family] := 1;
        end;
        if data <> nil then
          FreeMem(data, size);
      end;
    end;
    if familyState[family] = 1 then begin
      DaxIo.LoadDax(DataArc.MergedName(family), '.dax', C_DATA.REMAP_BLOCK, size, data);
      if data <> nil then begin
        first := remapCount;
        i := 0;
        while (i + 2 < size) and (familyState[family] = 1) do begin
          { an entry naming no disk, or a reserved id on either side, is skipped: a load is never sent to the merged
            archive's own blocks }
          if (Byte(data^[i]) in [1..8]) and (Byte(data^[i + 1]) < C_DATA.SOURCES_BLOCK) and
              (Byte(data^[i + 2]) < C_DATA.SOURCES_BLOCK) then
            if remapCount = MAX_REMAPS then begin
              { more than the table holds: the family's entries are dropped and it reads its per-disk archives,
                rather than reading other disks' blocks under the ids that did not fit }
              familyState[family] := 2;
              remapCount := first;
            end else begin
              Inc(remapCount);
              remapFamily[remapCount] := family;
              remapDisk[remapCount] := Byte(data^[i]);
              remapFrom[remapCount] := Byte(data^[i + 1]);
              remapTo[remapCount] := Byte(data^[i + 2]);
            end;
          Inc(i, 3);
        end;
        FreeMem(data, size);
      end;
    end;
  end;
  FamilyUsable := familyState[family] = 1;
end;

procedure ResetArchiveCache;
begin
  FillChar(familyState, SizeOf(familyState), 0);
  FillChar(familyDisks, SizeOf(familyDisks), 0);
  remapCount := 0;
end;

function RemapId(family, disk, id: Byte): Byte;
var
  i: Byte;
begin
  RemapId := id;
  for i := 1 to remapCount do
    if (remapFamily[i] = family) and (remapDisk[i] = disk) and (remapFrom[i] = id) then
      RemapId := remapTo[i];
end;

function ArchiveName(fileName: Types.TStr20): Types.TStr20;
var
  family: Byte;
  disk: Byte;
begin
  ArchiveName := fileName;
  family := DataArc.MatchFamily(fileName, disk);
  if family > 0 then
    if DaxIo.FamilyUsable(family) and DaxIo.DiskHasSource(family, disk) then
      ArchiveName := DataArc.MergedName(family);
end;

function DiskHasBlock(fileName: Types.TStr20; fileID: Byte): Boolean;
begin
  DiskHasBlock := DataArc.HasBlock(GameVars.gameDir + fileName + '.DAX', fileID);
end;

{ Find a DAX block by ID in GameVars.gameDir + fileName + ext, read and decompress it into a new buffer of sizeRead
  bytes, then release the compressed buffer. A per-disk archive name of a data family whose merged archive is usable
  reads the merged archive instead (when that disk has its own per-disk archive and fileID is not one of C_DATA's
  reserved ids), with fileID remapped where that disk's block was stored under another id. Only the bytes actually read
  are decoded, so a truncated archive yields a block zeroed past what it holds. Any directory entry scanned with a
  compressed size above 36000 shows a 'tempsize' prompt and exits the game. Return sizeRead=0 and data=nil if the
  archive cannot be opened or the ID is absent. }
procedure LoadDax(fileName, ext: Types.TStr20; fileID: Byte; var sizeRead: Word; var data: Types.PByteArr);
var
  compSize: Word;
  offset: LongInt;
  id: Byte;
  n: Word;
  f1: file;
  f2: file;
  hdrSize: Word;
  numStr: String[6];
  family: Byte;
  disk: Byte;
  cut: Boolean;
begin
  family := DataArc.MatchFamily(fileName, disk);
  { the reserved ids name the merged archive's own blocks, which no per-disk archive holds: such a load reads the
    per-disk archive and finds nothing there, as it did before the merged archives }
  if (family > 0) and (fileID < C_DATA.SOURCES_BLOCK) then
    if DaxIo.FamilyUsable(family) and DaxIo.DiskHasSource(family, disk) then begin
      fileID := DaxIo.RemapId(family, disk, fileID);
      fileName := DataArc.MergedName(family);
    end;
  if not DaxIo.OpenDax(GameVars.gameDir + fileName, ext, hdrSize, f1, f2) then begin
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
    { an entry cut short by the end of the file ends the scan, unfound }
    cut := n < SizeOf(compSize);
    if not cut and (compSize > 36000) then begin
      Str(LongInt(compSize), numStr);
      DaxIo.PromptBox(Yellow, 'tempsize ' + numStr);
      GameIo.ExitGame;
    end;
  until cut or (id = fileID) or (FilePos(f2) >= hdrSize);
  if cut or (id <> fileID) then begin
    sizeRead := 0;
    data := nil;
  end else
    DaxIo.ReadBlock(f1, hdrSize, offset, compSize, sizeRead, data);
  DaxIo.CloseDax(f1, f2);
end;

procedure ReadBlock(var f: file; hdrSize: Word; offset: LongInt; compSize, sizeRead: Word; var data: Types.PByteArr);
var
  n: Word;
begin
  DaxIo.AllocRounded(Pointer(daxCompressedFilePtr), compSize);
  GetMem(data, sizeRead);
  Seek(f, hdrSize + offset);
  BlockRead(f, daxCompressedFilePtr^, compSize, n);
  { n, the bytes read: FreeRounded still needs compSize }
  DaxIo.DecompressDax(daxCompressedFilePtr, data, n, sizeRead);
  DaxIo.FreeRounded(Pointer(daxCompressedFilePtr), compSize);
end;

{ Save the current resource disk and select a new one. }
procedure PushState(v: Byte);
begin
  prevVirtualDisk := GameVars.virtualDisk;
  GameVars.virtualDisk := v;
end;

{ Restore the saved resource disk. }
procedure PopState;
begin
  GameVars.virtualDisk := prevVirtualDisk;
end;

begin
  DaxIo.ResetArchiveCache;
  prevVirtualDisk := 0;
end.
