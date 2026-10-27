{ Describes the per-disk archives that make up each merged data family and
  provides the archive checks shared by the game and DataBld. A merged archive
  is a normal DAX file with the reserved C_DATA blocks appended. Checks always
  open files read-only, regardless of FileMode. }
{$I COMPILER.INC}
unit DataArc;

interface

uses Types;

type
  { One DAX directory entry; offset counts from the end of the directory. }
  TDirEntry = record
    id: Byte;
    offset: LongInt;
    rawSize: Word;
    packedSize: Word;
  end;

{ Returns a per-disk archive name without its extension. For example,
  SourceName(10, 5) is 'MON5CHA'. Invalid family or disk values return ''. }
function SourceName(family, disk: Byte): Types.TStr20;

{ Returns the per-disk archive filename, including .DAX. }
function SourceFile(family, disk: Byte): Types.TStr20;

{ Returns a family's merged archive name without its extension. }
function MergedName(family: Byte): Types.TStr20;

{ The family whose per-disk archive fileName (any case, no extension) names, with that archive's disk,
  1..Types.LAST_DISK, in disk; 0 when it names none. }
function MatchFamily(fileName: Types.TStr20; var disk: Byte): Byte;

{ True when the file at path is a whole merged archive: its directory is non-empty, its last entry is the version block,
  and the file ends exactly where that block does. A file cut short while being written fails this. }
function ArchiveIntact(path: Types.TPathStr): Boolean;

{ Returns whether the DAX archive at path lists block id. Read failures return
  False without prompting for another disk. }
function HasBlock(path: Types.TPathStr; id: Byte): Boolean;

{ The size in bytes of the file at path; -1 when it cannot be opened. }
function FileLength(path: Types.TPathStr): LongInt;

implementation

uses C_DATA, FileUtil;

type
  { A data family: its per-disk archives are <prefix><disk digit><suffix>.DAX, merged into <merged>.DAX. }
  TFamily = record
    prefix: String[7];
    suffix: String[3];
    merged: String[8];
  end;

const
  { In DataBld's build order. This table, with DataBld and DataPat, is the only model of the merged archives. }
  families: array[1..C_DATA.FAMILIES] of TFamily = (
    (prefix: 'ECL'; suffix: ''; merged: 'ECL'),
    (prefix: 'GEO'; suffix: ''; merged: 'GEO'),
    (prefix: 'WALLDEF'; suffix: ''; merged: 'WALLDEF'),
    (prefix: 'PIC'; suffix: ''; merged: 'PIC'),
    (prefix: 'SPRIT'; suffix: ''; merged: 'SPRIT'),
    (prefix: 'CPIC'; suffix: ''; merged: 'CPIC'),
    (prefix: 'FINAL'; suffix: ''; merged: 'FINAL'),
    (prefix: '8X8D'; suffix: ''; merged: '8X8D'),
    (prefix: 'ITEM'; suffix: ''; merged: 'ITEM'),
    (prefix: 'MON'; suffix: 'CHA'; merged: 'MONCHA'),
    (prefix: 'MON'; suffix: 'ITM'; merged: 'MONITM'),
    (prefix: 'MON'; suffix: 'SPC'; merged: 'MONSPC'),
    (prefix: 'HEAD'; suffix: ''; merged: 'HEAD'),
    (prefix: 'BODY'; suffix: ''; merged: 'BODY'));

function SourceName(family, disk: Byte): Types.TStr20;
begin
  if (family >= 1) and (family <= C_DATA.FAMILIES) and (disk >= 1) and (disk <= Types.LAST_DISK) then
    SourceName := families[family].prefix + Chr(Ord('0') + disk) + families[family].suffix
  else
    SourceName := '';
end;

function SourceFile(family, disk: Byte): Types.TStr20;
var
  name: Types.TStr20;
begin
  name := DataArc.SourceName(family, disk);
  if name <> '' then
    name := name + '.DAX';
  SourceFile := name;
end;

function MergedName(family: Byte): Types.TStr20;
begin
  if (family >= 1) and (family <= C_DATA.FAMILIES) then
    MergedName := families[family].merged
  else
    MergedName := '';
end;

function MatchFamily(fileName: Types.TStr20; var disk: Byte): Byte;
var
  u: Types.TStr20;
  i: Byte;
  f: Byte;
  digit: Byte;
begin
  MatchFamily := 0;
  u := fileName;
  for i := 1 to Length(u) do
    u[i] := UpCase(u[i]);
  for f := 1 to C_DATA.FAMILIES do
    with families[f] do begin
      digit := Length(prefix) + 1;
      if Length(u) = digit + Length(suffix) then
        if (Copy(u, 1, digit - 1) = prefix) and (u[digit] >= '1') and
            (u[digit] <= Chr(Ord('0') + Types.LAST_DISK)) and
            (Copy(u, digit + 1, Length(suffix)) = suffix) then begin
          disk := Ord(u[digit]) - Ord('0');
          MatchFamily := f;
        end;
    end;
end;

{$I-}
function ArchiveIntact(path: Types.TPathStr): Boolean;
var
  f: file;
  dirSize: Word;
  e: TDirEntry;
  n: Word;
  size: LongInt;
  ok: Boolean;
begin
  ok := False;
  if FileUtil.OpenReadOnly(f, path) then begin
    size := FileSize(f);
    BlockRead(f, dirSize, SizeOf(dirSize), n);
    if (IOResult = 0) and (n = SizeOf(dirSize)) and (dirSize > 0) and (dirSize mod SizeOf(TDirEntry) = 0) and
        (SizeOf(dirSize) + LongInt(dirSize) <= size) then begin
      Seek(f, SizeOf(dirSize) + LongInt(dirSize) - SizeOf(TDirEntry));
      BlockRead(f, e, SizeOf(e), n);
      ok := (IOResult = 0) and (n = SizeOf(e)) and (e.id = C_DATA.VERSION_BLOCK) and (e.offset >= 0) and
            (SizeOf(dirSize) + LongInt(dirSize) + e.offset + e.packedSize = size);
    end;
    Close(f);
    n := IOResult;
  end;
  ArchiveIntact := ok;
end;

function HasBlock(path: Types.TPathStr; id: Byte): Boolean;
var
  f: file;
  dirSize: Word;
  e: TDirEntry;
  n: Word;
  i: Word;
  found: Boolean;
begin
  found := False;
  if FileUtil.OpenReadOnly(f, path) then begin
    BlockRead(f, dirSize, SizeOf(dirSize), n);
    if (IOResult = 0) and (n = SizeOf(dirSize)) then begin
      i := 0;
      while (i < dirSize div SizeOf(TDirEntry)) and not found do begin
        BlockRead(f, e, SizeOf(e), n);
        if (IOResult <> 0) or (n <> SizeOf(e)) then
          i := dirSize
        else begin
          found := e.id = id;
          Inc(i);
        end;
      end;
    end;
    Close(f);
    n := IOResult;
  end;
  HasBlock := found;
end;

function FileLength(path: Types.TPathStr): LongInt;
var
  f: file;
  size: LongInt;
begin
  size := -1;
  if FileUtil.OpenReadOnly(f, path) then begin
    size := FileSize(f);
    if IOResult <> 0 then
      size := -1;
    Close(f);
    if IOResult <> 0 then
      size := -1;
  end;
  FileLength := size;
end;
{$I+}

end.
