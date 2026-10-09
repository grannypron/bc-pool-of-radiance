{ DATABLD.EXE: build the merged data archives from the player's own copy of the game, in the current directory. Each
  data family's per-disk archives (ECL1-8.DAX, MON1-8CHA.DAX and so on; DataArc's family table) are gathered into one
  archive (ECL.DAX, MONCHA.DAX) that DaxIo.LoadDax reads in their place, so nothing is tied to the current disk. Blocks
  are copied packed, byte for byte. When two disks give one block id different contents, the first disk's block keeps
  the id and the other is stored under a spare id, listed in the archive's remap block. A data patch fixes a known
  fault in one block, only when the block still holds the bytes it replaces; adding one means bumping C_Data.VERSION.
  Each archive records the size and CRC-32 of every per-disk archive it was built from, and ends with its version and
  the CRC-32 of everything before that. An archive that is whole, of this version, matches its CRC-32 and records the
  per-disk archives as they are now is kept; any other is rebuilt. Each step goes to the screen and to DATABLD.LOG. The
  game's own files are only read. }
{$I-}
program DataBld;

uses Types, C_Data, DataArc;

const
  { the most directory entries a family's per-disk archives may hold between them, plus the three reserved blocks }
  MAX_BLOCKS = 512;
  { the most collisions one family may have }
  MAX_REMAPS = 16;
  { bytes moved per read when copying, comparing or checksumming }
  CHUNK_SIZE = 4096;
  { per-disk archives are numbered 1 to SOURCE_DISKS }
  SOURCE_DISKS = 8;
  { the most bytes one literal run of a packed block holds }
  RUN_SIZE = 127;
  { the most bytes the sources block holds }
  SOURCES_SIZE = SOURCE_DISKS * C_Data.SOURCE_RECORD;
  { the most packed bytes the sources block takes }
  SOURCES_PACKED = SOURCES_SIZE + (SOURCES_SIZE + RUN_SIZE - 1) div RUN_SIZE;
  { the version block: C_Data.VERSION and a CRC-32, packed as one literal run }
  VERSION_RAW = 5;
  VERSION_PACKED = 6;
  LOG_NAME = 'DATABLD.LOG';
  { the data patches: how many, and the bytes each replaces }
  PATCH_COUNT = 1;
  PATCH_SIZE = 87;

type
  { A block: packed bytes in the per-disk archive of disk at file position start, or, with disk 0, in memory at mem. }
  TBlock = record
    id: Byte;
    rawSize: Word;
    packedSize: Word;
    disk: Byte;
    start: LongInt;
    mem: Types.PByteArr;
  end;
  PBlockList = ^TBlockList;
  TBlockList = array[1..MAX_BLOCKS] of TBlock;
  TBytes = array[0..65534] of Byte;
  PBytes = ^TBytes;
  { A CRC-32 being computed, also seen as its low and high words. }
  TCrc = record
    case Byte of
      0: (value: LongInt);
      1: (lo: Word; hi: Word);
  end;
  TSources = array[0..SOURCES_PACKED - 1] of Byte;
  { A fix to one block: PATCH_SIZE bytes at offset in the decoded block id of the family's archive on disk. }
  TPatch = record
    family: Byte;
    disk: Byte;
    id: Byte;
    offset: Word;
  end;

const
  patches: array[1..PATCH_COUNT] of TPatch = (
    { POR-0038, Kovel Mansion's weapons-pile ambush (ECL3 block 14, script addresses $AAB9-$AB0F): 0..7 thieves
      killed give 5 1st-level thieves, 8..12 give c-7 6th-level and 12-c 1st-level as before, 13..16 give 5 6th-level
      and 17 gives 4, where the shipped script took the 1st-level count below zero or left it stale }
    (family: C_Data.FAMILY_ECL; disk: 3; id: 14; offset: 4539));
  patchOriginal: array[1..PATCH_COUNT, 0..PATCH_SIZE - 1] of Byte = ((
    $04, $00, $05, $01, $45, $4A, $01, $79, $6E, $03, $01, $79, $6E, $00, $15, $1B,
    $01, $01, $EE, $AA, $03, $01, $79, $6E, $00, $0C, $1A, $01, $01, $04, $AB, $05,
    $00, $0C, $01, $79, $6E, $01, $7A, $6E, $05, $01, $7A, $6E, $00, $05, $01, $7B,
    $6E, $01, $01, $10, $AB, $05, $00, $15, $01, $79, $6E, $01, $7A, $6E, $05, $01,
    $7A, $6E, $00, $05, $01, $7A, $6E, $01, $01, $10, $AB, $09, $00, $05, $01, $7B,
    $6E, $09, $00, $00, $01, $7A, $6E));
  patchFixed: array[1..PATCH_COUNT, 0..PATCH_SIZE - 1] of Byte = ((
    $09, $02, $05, $00, $01, $7B, $6E, $09, $02, $00, $00, $01, $7A, $6E, $03, $01,
    $45, $4A, $00, $07, $1A, $01, $01, $10, $AB, $05, $00, $07, $01, $45, $4A, $01,
    $7A, $6E, $05, $01, $7A, $6E, $00, $05, $01, $7B, $6E, $03, $01, $45, $4A, $00,
    $0C, $1A, $01, $01, $10, $AB, $09, $02, $00, $00, $01, $7B, $6E, $05, $01, $45,
    $4A, $00, $15, $01, $7A, $6E, $03, $01, $7A, $6E, $00, $05, $1A, $01, $01, $10,
    $AB, $09, $00, $05, $01, $7A, $6E));

var
  logFile: Text;
  logOpen: Boolean;
  { the CRC-32 table's low and high words }
  crcLo: array[0..255] of Word;
  crcHi: array[0..255] of Word;
  bufA: PBytes;
  bufB: PBytes;
  { the per-disk archives' directory entries, in disk order, and the merged archive's blocks }
  sources: PBlockList;
  sourceCount: Word;
  blocks: PBlockList;
  blockCount: Word;
  { the sources block of the family being built: disk, size and CRC-32 of each per-disk archive }
  sourceList: TSources;
  sourceListLen: Word;
  { the collisions: a load of remapFrom on remapDisk reads remapTo, which is block remapBlock }
  remapCount: Byte;
  remapDisk: array[1..MAX_REMAPS] of Byte;
  remapFrom: array[1..MAX_REMAPS] of Byte;
  remapTo: array[1..MAX_REMAPS] of Byte;
  remapBlock: array[1..MAX_REMAPS] of Word;
  { the merged archive being worked on, for messages }
  archiveName: Types.TStr20;
  { why the family being built failed, for the log; empty while all is well }
  failNote: string;
  { the last DOS error a read or write met }
  lastError: Integer;
  builtCount: Byte;
  keptCount: Byte;
  failedCount: Byte;
  family: Byte;
  n: Integer;

{ Write a line to DATABLD.LOG and push it to disk, so the log ends at the step that was running if the program stops. A
  log that cannot be written is given up; the build carries on. }
procedure LogLine(s: string);
begin
  if logOpen then begin
    WriteLn(logFile, s);
    Flush(logFile);
    if IOResult <> 0 then
      logOpen := False;
  end;
end;

{ Show s and log it. }
procedure Progress(s: string);
begin
  WriteLn(s);
  LogLine(s);
end;

function NumStr(n: LongInt): Types.TStr20;
var
  s: Types.TStr20;
begin
  Str(n, s);
  NumStr := s;
end;

{ Note why the family failed, unless an earlier step already has. }
procedure Fail(why: string);
begin
  if failNote = '' then
    failNote := why;
end;

{ True when the last file operation succeeded; otherwise its DOS error goes to lastError. }
function IoOk: Boolean;
var
  err: Integer;
begin
  err := IOResult;
  if err <> 0 then
    lastError := err;
  IoOk := err = 0;
end;

{ Fill crcLo and crcHi for the CRC-32 of zip and PNG (reflected polynomial $EDB88320). }
procedure InitCrcTable;
var
  i: Word;
  k: Byte;
  c: TCrc;
begin
  for i := 0 to 255 do begin
    c.value := i;
    for k := 1 to 8 do
      if c.value and 1 <> 0 then
        c.value := (c.value shr 1) xor $EDB88320
      else
        c.value := c.value shr 1;
    crcLo[i] := c.lo;
    crcHi[i] := c.hi;
  end;
end;

{ Add count bytes at buf to crc, which starts at -1; the CRC-32 is crc's bitwise not once every byte is in. Word
  arithmetic throughout: this loop is most of the program's time. }
procedure AddCrc(var crc: TCrc; var buf; count: Word);
var
  i: Word;
  idx: Byte;
  low16: Word;
  high16: Word;
begin
  low16 := crc.lo;
  high16 := crc.hi;
  i := 0;
  while i < count do begin
    idx := Byte(low16) xor TBytes(buf)[i];
    low16 := ((low16 shr 8) or (high16 shl 8)) xor crcLo[idx];
    high16 := (high16 shr 8) xor crcHi[idx];
    Inc(i);
  end;
  crc.lo := low16;
  crc.hi := high16;
end;

{ Read count bytes at position pos of the open file f into buf. False on a read error or a short read. }
function ReadAt(var f: file; pos: LongInt; var buf; count: Word): Boolean;
var
  got: Word;
begin
  Seek(f, pos);
  BlockRead(f, buf, count, got);
  ReadAt := IoOk and (got = count);
end;

{ The CRC-32 of the first size bytes of the open file f. False on a read error or a file shorter than size. }
function CrcOfFile(var f: file; size: LongInt; var crc: LongInt): Boolean;
var
  c: TCrc;
  pos: LongInt;
  part: Word;
  ok: Boolean;
begin
  c.value := -1;
  pos := 0;
  ok := True;
  while ok and (pos < size) do begin
    part := CHUNK_SIZE;
    if size - pos < part then
      part := size - pos;
    ok := ReadAt(f, pos, bufA^, part);
    AddCrc(c, bufA^, part);
    Inc(pos, part);
  end;
  crc := not c.value;
  CrcOfFile := ok;
end;

{ The file name of the family's per-disk archive of disk. }
function SourcePath(fam, disk: Byte): Types.TStr20;
begin
  SourcePath := DataArc.SourceName(fam, disk) + '.DAX';
end;

{ Remove a file from the current directory if it is there; an error is ignored. }
procedure RemoveFile(name: Types.TStr20);
var
  f: file;
begin
  Assign(f, name);
  Erase(f);
  n := IOResult;
end;

{ Read the open per-disk archive f of disk: its directory into sources, and its disk, size and CRC-32 onto sourceList.
  False, with failNote set, when it cannot be read, is damaged (its directory or a block runs past its end) or its
  entries do not fit. }
function ReadSource(var f: file; fam, disk: Byte): Boolean;
var
  dirSize: Word;
  dataStart: LongInt;
  size: LongInt;
  crc: LongInt;
  i: Word;
  e: DataArc.TDirEntry;
  ok: Boolean;
begin
  lastError := 0;
  size := FileSize(f);
  ok := IoOk and ReadAt(f, 0, dirSize, SizeOf(dirSize));
  dataStart := SizeOf(dirSize) + LongInt(dirSize);
  ok := ok and (dirSize mod SizeOf(e) = 0) and (dataStart <= size);
  i := 1;
  while ok and (i <= dirSize div SizeOf(e)) do begin
    ok := ReadAt(f, SizeOf(dirSize) + LongInt(i - 1) * SizeOf(e), e, SizeOf(e));
    ok := ok and (e.offset >= 0) and (dataStart + e.offset + e.packedSize <= size);
    if ok then
      if sourceCount + 3 >= MAX_BLOCKS then begin
        Fail('too many blocks');
        ok := False;
      end else begin
        Inc(sourceCount);
        sources^[sourceCount].id := e.id;
        sources^[sourceCount].rawSize := e.rawSize;
        sources^[sourceCount].packedSize := e.packedSize;
        sources^[sourceCount].disk := disk;
        sources^[sourceCount].start := dataStart + e.offset;
        sources^[sourceCount].mem := nil;
      end;
    Inc(i);
  end;
  ok := ok and CrcOfFile(f, size, crc);
  if ok and (sourceListLen + C_Data.SOURCE_RECORD <= SOURCES_SIZE) then begin
    sourceList[sourceListLen] := disk;
    Move(size, sourceList[sourceListLen + 1], 4);
    Move(crc, sourceList[sourceListLen + 5], 4);
    Inc(sourceListLen, C_Data.SOURCE_RECORD);
  end;
  if not ok then
    if lastError <> 0 then
      Fail('reading ' + SourcePath(fam, disk) + ': DOS error ' + NumStr(lastError))
    else
      Fail(SourcePath(fam, disk) + ' is damaged');
  ReadSource := ok;
end;

{ Read the family's per-disk archives that are present, disks 1 to SOURCE_DISKS. False, with failNote set, when one
  cannot be read or is damaged. }
function ReadSources(fam: Byte): Boolean;
var
  disk: Byte;
  f: file;
  ok: Boolean;
begin
  sourceCount := 0;
  sourceListLen := 0;
  ok := True;
  for disk := 1 to SOURCE_DISKS do
    if ok then begin
      Assign(f, SourcePath(fam, disk));
      Reset(f, 1);
      if IOResult = 0 then begin
        Progress(archiveName + '.DAX: reading ' + SourcePath(fam, disk));
        ok := ReadSource(f, fam, disk);
        Close(f);
        n := IOResult;
      end;
    end;
  ReadSources := ok;
end;

{ True when blocks a and b, both in per-disk archives of the family, hold the same packed bytes. A read error sets
  failNote. }
function SameBlock(fam: Byte; var a, b: TBlock): Boolean;
var
  fa: file;
  fb: file;
  left: Word;
  part: Word;
  posA: LongInt;
  posB: LongInt;
  i: Word;
  same: Boolean;
begin
  same := a.packedSize = b.packedSize;
  if same then begin
    lastError := 0;
    Assign(fa, SourcePath(fam, a.disk));
    Reset(fa, 1);
    if IoOk then begin
      Assign(fb, SourcePath(fam, b.disk));
      Reset(fb, 1);
      if IoOk then begin
        left := a.packedSize;
        posA := a.start;
        posB := b.start;
        while same and (left > 0) do begin
          part := left;
          if part > CHUNK_SIZE then
            part := CHUNK_SIZE;
          if ReadAt(fa, posA, bufA^, part) and ReadAt(fb, posB, bufB^, part) then begin
            i := 0;
            while same and (i < part) do begin
              same := bufA^[i] = bufB^[i];
              Inc(i);
            end;
          end else
            same := False;
          Inc(posA, part);
          Inc(posB, part);
          Dec(left, part);
        end;
        Close(fb);
      end;
      Close(fa);
    end;
    n := IOResult;
    if lastError <> 0 then begin
      Fail('comparing ' + SourcePath(fam, b.disk) + ': DOS error ' + NumStr(lastError));
      same := False;
    end;
  end;
  SameBlock := same;
end;

{ Pack rawSize bytes at raw as literal runs of at most RUN_SIZE bytes, into a new buffer of packedSize bytes (nil when
  rawSize is 0). }
procedure EncodeRuns(var raw; rawSize: Word; var packedBuf: Types.PByteArr; var packedSize: Word);
var
  i: Word;
  o: Word;
  run: Word;
begin
  packedSize := rawSize + (rawSize + RUN_SIZE - 1) div RUN_SIZE;
  packedBuf := nil;
  if packedSize > 0 then
    GetMem(packedBuf, packedSize);
  i := 0;
  o := 0;
  while i < rawSize do begin
    run := rawSize - i;
    if run > RUN_SIZE then
      run := RUN_SIZE;
    PBytes(packedBuf)^[o] := run - 1;
    Move(TBytes(raw)[i], PBytes(packedBuf)^[o + 1], run);
    Inc(o, run + 1);
    Inc(i, run);
  end;
end;

{ Add a block holding size bytes at raw, packed into memory, under blockId. }
procedure AddMemoryBlock(blockId: Byte; var raw; size: Word);
begin
  Inc(blockCount);
  blocks^[blockCount].id := blockId;
  blocks^[blockCount].rawSize := size;
  blocks^[blockCount].disk := 0;
  blocks^[blockCount].start := 0;
  EncodeRuns(raw, size, blocks^[blockCount].mem, blocks^[blockCount].packedSize);
end;

{ True when the archive called name is whole, of version C_Data.VERSION, and its bytes match the CRC-32 in its version
  block. When it is, list receives its sources block's packed bytes and listLen their count (0 when there is none or it
  is too long). }
function ArchiveSound(name: Types.TStr20; var list: TSources; var listLen: Word): Boolean;
var
  f: file;
  dirSize: Word;
  e: DataArc.TDirEntry;
  i: Word;
  size: LongInt;
  crc: LongInt;
  version: array[0..VERSION_PACKED - 1] of Byte;
  stored: LongInt;
  ok: Boolean;
begin
  ok := False;
  listLen := 0;
  if DataArc.ArchiveIntact(name) then begin
    Assign(f, name);
    Reset(f, 1);
    if IoOk then begin
      size := FileSize(f);
      ok := ReadAt(f, size - VERSION_PACKED, version, VERSION_PACKED) and (version[0] = VERSION_RAW - 1) and
            (version[1] = C_Data.VERSION);
      if ok then begin
        Move(version[2], stored, 4);
        ok := CrcOfFile(f, size - VERSION_PACKED, crc) and (crc = stored);
      end;
      if ok then begin
        ok := ReadAt(f, 0, dirSize, SizeOf(dirSize));
        i := 1;
        while ok and (i <= dirSize div SizeOf(e)) do begin
          ok := ReadAt(f, SizeOf(dirSize) + LongInt(i - 1) * SizeOf(e), e, SizeOf(e));
          if ok and (e.id = C_Data.SOURCES_BLOCK) and (e.packedSize <= SizeOf(list)) then begin
            ok := ReadAt(f, SizeOf(dirSize) + LongInt(dirSize) + e.offset, list, e.packedSize);
            listLen := e.packedSize;
          end;
          Inc(i);
        end;
      end;
      Close(f);
      n := IOResult;
    end;
  end;
  if not ok then
    listLen := 0;
  ArchiveSound := ok;
end;

{ True when the family's merged archive is sound and was built from the per-disk archives as sourceList has them now. }
function ArchiveCurrent: Boolean;
var
  old: TSources;
  oldLen: Word;
  packedBuf: Types.PByteArr;
  packedLen: Word;
  i: Word;
  same: Boolean;
begin
  same := False;
  if ArchiveSound(archiveName + '.DAX', old, oldLen) then begin
    EncodeRuns(sourceList, sourceListLen, packedBuf, packedLen);
    same := oldLen = packedLen;
    i := 0;
    while same and (i < packedLen) do begin
      same := old[i] = PBytes(packedBuf)^[i];
      Inc(i);
    end;
    if packedLen > 0 then
      FreeMem(packedBuf, packedLen);
  end;
  ArchiveCurrent := same;
end;

{ Fill blocks from sources: the first copy of an id keeps it; a later copy with other bytes goes to a spare id, and a
  remap entry says so. Several disks with the same other bytes share one spare id. False, with failNote set, on a read
  error or when the collisions or spare ids run out. }
function ChooseIds(fam: Byte): Boolean;
var
  used: array[0..255] of Boolean;
  taken: array[0..255] of Boolean;
  owner: array[0..255] of Word;
  i: Word;
  r: Word;
  hit: Word;
  spare: Word;
  id: Byte;
begin
  FillChar(used, SizeOf(used), 0);
  FillChar(taken, SizeOf(taken), 0);
  FillChar(owner, SizeOf(owner), 0);
  for i := 1 to sourceCount do
    used[sources^[i].id] := True;
  i := 1;
  while (i <= sourceCount) and (failNote = '') do begin
    id := sources^[i].id;
    if owner[id] = 0 then begin
      Inc(blockCount);
      blocks^[blockCount] := sources^[i];
      owner[id] := blockCount;
    end else if not SameBlock(fam, blocks^[owner[id]], sources^[i]) and (failNote = '') then begin
      hit := 0;
      for r := 1 to remapCount do
        if (hit = 0) and (remapFrom[r] = id) and (failNote = '') then
          if SameBlock(fam, blocks^[remapBlock[r]], sources^[i]) then
            hit := r;
      if remapCount = MAX_REMAPS then
        Fail('too many collisions')
      else if failNote = '' then begin
        Inc(remapCount);
        remapDisk[remapCount] := sources^[i].disk;
        remapFrom[remapCount] := id;
        if hit > 0 then begin
          remapTo[remapCount] := remapTo[hit];
          remapBlock[remapCount] := remapBlock[hit];
        end else begin
          spare := 1;
          while (spare < C_Data.SOURCES_BLOCK) and (used[spare] or taken[spare]) do
            Inc(spare);
          if spare >= C_Data.SOURCES_BLOCK then
            Fail('no spare block id left')
          else begin
            taken[spare] := True;
            Inc(blockCount);
            blocks^[blockCount] := sources^[i];
            blocks^[blockCount].id := spare;
            remapTo[remapCount] := spare;
            remapBlock[remapCount] := blockCount;
          end;
        end;
      end;
    end;
    Inc(i);
  end;
  ChooseIds := failNote = '';
end;

{ Append block b's packed bytes to dst, from memory or copied from its per-disk archive, adding them to crc. False on a
  read or write error. }
function CopyBlock(fam: Byte; var b: TBlock; var dst: file; var crc: TCrc): Boolean;
var
  src: file;
  left: Word;
  part: Word;
  pos: LongInt;
  ok: Boolean;
begin
  if b.disk = 0 then begin
    BlockWrite(dst, b.mem^, b.packedSize);
    AddCrc(crc, b.mem^, b.packedSize);
    ok := IoOk;
  end else begin
    Assign(src, SourcePath(fam, b.disk));
    Reset(src, 1);
    ok := IoOk;
    if ok then begin
      left := b.packedSize;
      pos := b.start;
      while ok and (left > 0) do begin
        part := left;
        if part > CHUNK_SIZE then
          part := CHUNK_SIZE;
        ok := ReadAt(src, pos, bufA^, part);
        if ok then begin
          BlockWrite(dst, bufA^, part);
          AddCrc(crc, bufA^, part);
          ok := IoOk;
        end;
        Inc(pos, part);
        Dec(left, part);
      end;
      Close(src);
      n := IOResult;
    end;
  end;
  CopyBlock := ok;
end;

{ Write blocks to <archiveName>.$$$: the directory, the blocks, then the version block (the last of blocks, its id and
  sizes set) holding C_Data.VERSION and the CRC-32 of everything before it. False, with failNote set, on an error. }
function WriteArchive(fam: Byte): Boolean;
var
  dst: file;
  dirSize: Word;
  e: DataArc.TDirEntry;
  nextOffset: LongInt;
  crc: TCrc;
  version: array[0..VERSION_PACKED - 1] of Byte;
  i: Word;
  ok: Boolean;
begin
  lastError := 0;
  Assign(dst, archiveName + '.$$$');
  Rewrite(dst, 1);
  ok := IoOk;
  if ok then begin
    crc.value := -1;
    dirSize := blockCount * SizeOf(e);
    BlockWrite(dst, dirSize, SizeOf(dirSize));
    AddCrc(crc, dirSize, SizeOf(dirSize));
    nextOffset := 0;
    for i := 1 to blockCount do begin
      e.id := blocks^[i].id;
      e.offset := nextOffset;
      e.rawSize := blocks^[i].rawSize;
      e.packedSize := blocks^[i].packedSize;
      BlockWrite(dst, e, SizeOf(e));
      AddCrc(crc, e, SizeOf(e));
      Inc(nextOffset, blocks^[i].packedSize);
    end;
    ok := IoOk;
    i := 1;
    while ok and (i < blockCount) do begin
      ok := CopyBlock(fam, blocks^[i], dst, crc);
      Inc(i);
    end;
    if ok then begin
      version[0] := VERSION_RAW - 1;
      version[1] := C_Data.VERSION;
      crc.value := not crc.value;
      Move(crc.value, version[2], 4);
      BlockWrite(dst, version, VERSION_PACKED);
      ok := IoOk;
    end;
    Close(dst);
    ok := IoOk and ok;
  end;
  if not ok then
    if lastError <> 0 then
      Fail('writing ' + archiveName + '.$$$: DOS error ' + NumStr(lastError))
    else
      Fail('writing ' + archiveName + '.$$$');
  WriteArchive := ok;
end;

{ Decode packedSize bytes of DAX run-length data at packedBuf into rawSize bytes at raw, as DaxIo.DecompressDax does:
  controls 0..$7E copy the next b+1 bytes, $81..$FF repeat the next byte -b times, $7F and $80 are skipped; runs are cut
  at the end of either buffer and output the input does not reach is zero. }
procedure DecodeRuns(var packedBuf; packedSize: Word; var raw; rawSize: Word);
var
  i: Word;
  o: Word;
  b: Byte;
  run: Word;
begin
  FillChar(raw, rawSize, 0);
  i := 0;
  o := 0;
  while (i < packedSize) and (o < rawSize) do begin
    b := TBytes(packedBuf)[i];
    Inc(i);
    if b <= $7E then begin
      run := b + 1;
      if run > packedSize - i then
        run := packedSize - i;
      if run > rawSize - o then
        run := rawSize - o;
      Move(TBytes(packedBuf)[i], TBytes(raw)[o], run);
      Inc(i, run);
      Inc(o, run);
    end else if (b >= $81) and (i < packedSize) then begin
      run := 256 - b;
      if run > rawSize - o then
        run := rawSize - o;
      FillChar(TBytes(raw)[o], run, TBytes(packedBuf)[i]);
      Inc(i);
      Inc(o, run);
    end;
  end;
end;

{ Apply patch p to block b (decoded, its original bytes checked, the fix put in and the block repacked into memory), or
  log why not. False, with failNote set, on a read error. }
function ApplyPatch(fam: Byte; p: Byte; var b: TBlock): Boolean;
var
  f: file;
  packedBuf: PBytes;
  raw: PBytes;
  k: Word;
  ok: Boolean;
  same: Boolean;
begin
  GetMem(packedBuf, b.packedSize);
  GetMem(raw, b.rawSize);
  lastError := 0;
  Assign(f, SourcePath(fam, b.disk));
  Reset(f, 1);
  ok := IoOk;
  if ok then begin
    ok := ReadAt(f, b.start, packedBuf^, b.packedSize);
    Close(f);
    n := IOResult;
  end;
  if not ok then
    Fail('reading ' + SourcePath(fam, b.disk) + ' for a patch: DOS error ' + NumStr(lastError))
  else begin
    DecodeRuns(packedBuf^, b.packedSize, raw^, b.rawSize);
    same := LongInt(patches[p].offset) + PATCH_SIZE <= b.rawSize;
    k := 0;
    while same and (k < PATCH_SIZE) do begin
      same := raw^[patches[p].offset + k] = patchOriginal[p, k];
      Inc(k);
    end;
    if same then begin
      for k := 0 to PATCH_SIZE - 1 do
        raw^[patches[p].offset + k] := patchFixed[p, k];
      b.disk := 0;
      b.start := 0;
      EncodeRuns(raw^, b.rawSize, b.mem, b.packedSize);
      Progress(archiveName + '.DAX: patch applied');
    end else
      Progress(archiveName + '.DAX: patch skipped: original bytes differ');
  end;
  FreeMem(packedBuf, b.packedSize);
  FreeMem(raw, b.rawSize);
  ApplyPatch := ok;
end;

{ Apply the family's patches to the blocks taken from their disk. False, with failNote set, on a read error. }
function ApplyPatches(fam: Byte): Boolean;
var
  p: Byte;
  i: Word;
  target: Word;
  ok: Boolean;
begin
  ok := True;
  for p := 1 to PATCH_COUNT do
    if ok and (patches[p].family = fam) then begin
      Progress(archiveName + '.DAX: fixing ' + SourcePath(fam, patches[p].disk) + ' block ' +
               NumStr(patches[p].id));
      target := 0;
      for i := 1 to blockCount do
        if (blocks^[i].id = patches[p].id) and (blocks^[i].disk = patches[p].disk) then
          target := i;
      if target = 0 then
        Progress(archiveName + '.DAX: patch skipped: block not found')
      else
        ok := ApplyPatch(fam, p, blocks^[target]);
    end;
  ApplyPatches := ok;
end;

{ Build the family's merged archive from sources: choose ids, apply patches, add the sources, remap and version blocks,
  write <name>.$$$, read it back and rename it to <name>.DAX. False, with failNote set, on any failure. }
function BuildArchive(fam: Byte): Boolean;
var
  table: array[0..3 * MAX_REMAPS - 1] of Byte;
  version: array[0..VERSION_RAW - 1] of Byte;
  check: TSources;
  checkLen: Word;
  r: Word;
  f: file;
  ok: Boolean;
begin
  ok := ChooseIds(fam);
  if ok then
    ok := ApplyPatches(fam);
  if ok then begin
    AddMemoryBlock(C_Data.SOURCES_BLOCK, sourceList, sourceListLen);
    if remapCount > 0 then begin
      for r := 1 to remapCount do begin
        table[3 * (r - 1)] := remapDisk[r];
        table[3 * (r - 1) + 1] := remapFrom[r];
        table[3 * (r - 1) + 2] := remapTo[r];
      end;
      AddMemoryBlock(C_Data.REMAP_BLOCK, table, 3 * remapCount);
    end;
    { WriteArchive puts in the version and the CRC-32 }
    FillChar(version, SizeOf(version), 0);
    AddMemoryBlock(C_Data.VERSION_BLOCK, version, VERSION_RAW);
    Progress(archiveName + '.DAX: writing');
    ok := WriteArchive(fam);
  end;
  if ok then begin
    Progress(archiveName + '.DAX: checking');
    ok := ArchiveSound(archiveName + '.$$$', check, checkLen);
    if not ok then
      Fail(archiveName + '.$$$ did not read back whole');
  end;
  if ok then begin
    RemoveFile(archiveName + '.DAX');
    Assign(f, archiveName + '.$$$');
    Rename(f, archiveName + '.DAX');
    lastError := 0;
    ok := IoOk;
    if not ok then
      Fail('renaming ' + archiveName + '.$$$: DOS error ' + NumStr(lastError));
  end;
  BuildArchive := ok;
end;

{ Bring the family's merged archive up to date: keep it when it is sound and records the per-disk archives as they are
  now, otherwise build it. Every outcome is shown and logged. A family that fails is left without a merged archive, so
  the game reads its per-disk archives. }
procedure UpdateFamily(fam: Byte);
var
  i: Word;
begin
  archiveName := DataArc.MergedName(fam);
  failNote := '';
  blockCount := 0;
  remapCount := 0;
  if ReadSources(fam) then
    if sourceCount = 0 then begin
      Progress(archiveName + '.DAX skipped: no per-disk archives');
      RemoveFile(archiveName + '.DAX');
    end else if ArchiveCurrent then begin
      Progress(archiveName + '.DAX up to date');
      Inc(keptCount);
    end else begin
      for i := 1 to sourceCount do
        if sources^[i].id >= C_Data.SOURCES_BLOCK then
          Fail('a per-disk archive uses block ' + NumStr(sources^[i].id));
      if failNote = '' then
        if BuildArchive(fam) then begin
          Progress(archiveName + '.DAX built: ' + NumStr(blockCount) + ' blocks, ' + NumStr(remapCount) +
                   ' collisions');
          Inc(builtCount);
        end;
    end;
  if failNote <> '' then begin
    Progress(archiveName + '.DAX FAILED: ' + failNote);
    RemoveFile(archiveName + '.$$$');
    RemoveFile(archiveName + '.DAX');
    Inc(failedCount);
  end;
  for i := 1 to blockCount do
    if (blocks^[i].disk = 0) and (blocks^[i].packedSize > 0) then
      FreeMem(blocks^[i].mem, blocks^[i].packedSize);
end;

begin
  { the game's files are only read }
  FileMode := 0;
  InitCrcTable;
  GetMem(bufA, CHUNK_SIZE);
  GetMem(bufB, CHUNK_SIZE);
  GetMem(sources, SizeOf(TBlockList));
  GetMem(blocks, SizeOf(TBlockList));
  Assign(logFile, LOG_NAME);
  Rewrite(logFile);
  logOpen := IOResult = 0;
  Progress('Please wait, constructing data files...');
  LogLine('Merged data archives, version ' + NumStr(C_Data.VERSION));
  builtCount := 0;
  keptCount := 0;
  failedCount := 0;
  for family := 1 to C_Data.FAMILIES do
    UpdateFamily(family);
  Progress('Done: ' + NumStr(builtCount) + ' built, ' + NumStr(keptCount) + ' up to date, ' + NumStr(failedCount) +
           ' failed.');
  if not logOpen then
    WriteLn('DATABLD.LOG could not be written.');
  if logOpen then
    Close(logFile);
  n := IOResult;
  if failedCount > 0 then
    Halt(1);
end.
