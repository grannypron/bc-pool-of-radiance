{ The records SSI's files hold a pointer in, as the files have them: a character (TCharRecord, 285 bytes in a .CHA or
  .SAV and in MONxCHA.DAX), an item (TItemRec, 63 in .ITM, vault files, ITEMx.DAX and MONxITM.DAX) and an effect
  (TEffectRec, 9 in .SPC and MONxSPC.DAX). On disk each pointer is a 4-byte far pointer; in a 32-bit or 16-bit program
  the record in memory is the same bytes, but a 64-bit one's pointers are 8, so every field after one moves. These
  routines copy between the two: natively a pointer goes to disk as 4 zero bytes and comes back nil. Under Turbo Pascal
  both forms are one and each routine is a Move, so a pointer goes as it is: the game clears them before saving, and
  rebuilds its lists on loading. A character's disk form ends where the port's own fields (TCharRecord.portExt) start:
  they are not written, and a record read from disk has them zero (CharExt keeps them in a file of their own). }
{$I COMPILER.INC}
unit DiskRec;

interface

uses Types, C_EQUIP;

const
  CHAR_DISK_BYTES = 285;
  ITEM_DISK_BYTES = 63;
  EFFECT_DISK_BYTES = 9;
  { the pointers each record holds: TCharRecord's effects, items, 13 equipped items, next character and combatant }
  CHAR_POINTERS = 4 + C_EQUIP.BOLT - C_EQUIP.WEAPON + 1;
  ITEM_POINTERS = 1;
  EFFECT_POINTERS = 1;

type
  TCharDisk = array[0..CHAR_DISK_BYTES - 1] of Byte;
  TItemDisk = array[0..ITEM_DISK_BYTES - 1] of Byte;
  TEffectDisk = array[0..EFFECT_DISK_BYTES - 1] of Byte;

{ A record to its disk form (disk: a TCharDisk, TItemDisk or TEffectDisk, or a buffer at least that long). }
procedure CharToDisk(var c: Types.TCharRecord; var disk);
procedure ItemToDisk(var it: Types.TItemRec; var disk);
procedure EffectToDisk(var ef: Types.TEffectRec; var disk);

{ A record from its disk form: a file's or a DAX block's bytes. Its pointers are nil natively; under Turbo Pascal they
  are the bytes the file held, which the callers clear. A character's port fields (portExt) are cleared. }
procedure CharFromDisk(var disk; var c: Types.TCharRecord);
procedure ItemFromDisk(var disk; var it: Types.TItemRec);
procedure EffectFromDisk(var disk; var ef: Types.TEffectRec);

{ The disk offset of the field at memory offset memOfs, for the layout test (tests/treclay.pas). }
function CharDiskOfs(memOfs: Word): Word;
function ItemDiskOfs(memOfs: Word): Word;
function EffectDiskOfs(memOfs: Word): Word;

{ The size each record's disk form works out to from its type: CHAR_DISK_BYTES and so on, when the types are right. }
function CharDiskSize: Word;
function ItemDiskSize: Word;
function EffectDiskSize: Word;

implementation

{$IFDEF FPC}
type
  { a record's pointer fields' memory offsets, in ascending order }
  TPtrOffsets = array[0..CHAR_POINTERS - 1] of Word;
  TByteBuf = array[0..65534] of Byte;
  PByteBuf = ^TByteBuf;

var
  { the bytes of TCharRecord in memory before portExt, the part the disk form holds }
  charMem: Word;
  charPtrs: TPtrOffsets;
  itemPtrs: TPtrOffsets;
  effectPtrs: TPtrOffsets;

{ memory to disk: the bytes between pointers as they are, each pointer as 4 zero bytes }
procedure Pack(var mem; memBytes: Word; var disk; var ptrs: TPtrOffsets; n: Byte);
var
  src: PByteBuf;
  dst: PByteBuf;
  from: Word;
  put: Word;
  i: Byte;
begin
  src := @mem;
  dst := @disk;
  from := 0;
  put := 0;
  for i := 0 to n - 1 do begin
    Move(src^[from], dst^[put], ptrs[i] - from);
    Inc(put, ptrs[i] - from);
    FillChar(dst^[put], 4, 0);
    Inc(put, 4);
    from := ptrs[i] + SizeOf(Pointer);
  end;
  Move(src^[from], dst^[put], memBytes - from);
end;

{ disk to memory: the bytes between pointers as they are, each pointer nil (all zero bytes) }
procedure Unpack(var disk; var mem; memBytes: Word; var ptrs: TPtrOffsets; n: Byte);
var
  src: PByteBuf;
  dst: PByteBuf;
  from: Word;
  at: Word;
  i: Byte;
begin
  src := @disk;
  dst := @mem;
  from := 0;
  at := 0;
  for i := 0 to n - 1 do begin
    Move(src^[at], dst^[from], ptrs[i] - from);
    Inc(at, ptrs[i] - from + 4);
    FillChar(dst^[ptrs[i]], SizeOf(Pointer), 0);
    from := ptrs[i] + SizeOf(Pointer);
  end;
  Move(src^[at], dst^[from], memBytes - from);
end;

function DiskOfs(memOfs: Word; var ptrs: TPtrOffsets; n: Byte): Word;
var
  i: Byte;
  d: Word;
begin
  d := memOfs;
  for i := 0 to n - 1 do
    if ptrs[i] < memOfs then
      Dec(d, Types.PTR_GROWTH);
  DiskOfs := d;
end;

procedure FindPointers;
var
  c: Types.TCharRecord;
  it: Types.TItemRec;
  ef: Types.TEffectRec;
  i: Byte;
begin
  charMem := PtrUInt(@c.portExt) - PtrUInt(@c);
  charPtrs[0] := PtrUInt(@c.effectsAddr) - PtrUInt(@c);
  charPtrs[1] := PtrUInt(@c.itemsAddr) - PtrUInt(@c);
  for i := C_EQUIP.WEAPON to C_EQUIP.BOLT do
    charPtrs[2 + i - C_EQUIP.WEAPON] := PtrUInt(@c.equipped[i]) - PtrUInt(@c);
  charPtrs[CHAR_POINTERS - 2] := PtrUInt(@c.nextCharAddr) - PtrUInt(@c);
  charPtrs[CHAR_POINTERS - 1] := PtrUInt(@c.combatAddr) - PtrUInt(@c);
  itemPtrs[0] := PtrUInt(@it.next) - PtrUInt(@it);
  effectPtrs[0] := PtrUInt(@ef.next) - PtrUInt(@ef);
end;
{$ENDIF}

procedure CharToDisk(var c: Types.TCharRecord; var disk);
begin
{$IFDEF FPC}
  Pack(c, charMem, disk, charPtrs, CHAR_POINTERS);
{$ELSE}
  Move(c, disk, CHAR_DISK_BYTES);
{$ENDIF}
end;

procedure ItemToDisk(var it: Types.TItemRec; var disk);
begin
{$IFDEF FPC}
  Pack(it, SizeOf(it), disk, itemPtrs, ITEM_POINTERS);
{$ELSE}
  Move(it, disk, ITEM_DISK_BYTES);
{$ENDIF}
end;

procedure EffectToDisk(var ef: Types.TEffectRec; var disk);
begin
{$IFDEF FPC}
  Pack(ef, SizeOf(ef), disk, effectPtrs, EFFECT_POINTERS);
{$ELSE}
  Move(ef, disk, EFFECT_DISK_BYTES);
{$ENDIF}
end;

procedure CharFromDisk(var disk; var c: Types.TCharRecord);
begin
{$IFDEF FPC}
  Unpack(disk, c, charMem, charPtrs, CHAR_POINTERS);
{$ELSE}
  Move(disk, c, CHAR_DISK_BYTES);
{$ENDIF}
  FillChar(c.portExt, SizeOf(c.portExt), 0);
end;

procedure ItemFromDisk(var disk; var it: Types.TItemRec);
begin
{$IFDEF FPC}
  Unpack(disk, it, SizeOf(it), itemPtrs, ITEM_POINTERS);
{$ELSE}
  Move(disk, it, ITEM_DISK_BYTES);
{$ENDIF}
end;

procedure EffectFromDisk(var disk; var ef: Types.TEffectRec);
begin
{$IFDEF FPC}
  Unpack(disk, ef, SizeOf(ef), effectPtrs, EFFECT_POINTERS);
{$ELSE}
  Move(disk, ef, EFFECT_DISK_BYTES);
{$ENDIF}
end;

function CharDiskOfs(memOfs: Word): Word;
begin
{$IFDEF FPC}
  CharDiskOfs := DiskOfs(memOfs, charPtrs, CHAR_POINTERS);
{$ELSE}
  CharDiskOfs := memOfs;
{$ENDIF}
end;

function ItemDiskOfs(memOfs: Word): Word;
begin
{$IFDEF FPC}
  ItemDiskOfs := DiskOfs(memOfs, itemPtrs, ITEM_POINTERS);
{$ELSE}
  ItemDiskOfs := memOfs;
{$ENDIF}
end;

function EffectDiskOfs(memOfs: Word): Word;
begin
{$IFDEF FPC}
  EffectDiskOfs := DiskOfs(memOfs, effectPtrs, EFFECT_POINTERS);
{$ELSE}
  EffectDiskOfs := memOfs;
{$ENDIF}
end;

function CharDiskSize: Word;
{$IFNDEF FPC}
var
  c: Types.TCharRecord;
{$ENDIF}
begin
{$IFDEF FPC}
  CharDiskSize := charMem - CHAR_POINTERS * Types.PTR_GROWTH;
{$ELSE}
  CharDiskSize := Ofs(c.portExt) - Ofs(c);
{$ENDIF}
end;

function ItemDiskSize: Word;
begin
  ItemDiskSize := SizeOf(Types.TItemRec) - ITEM_POINTERS * Types.PTR_GROWTH;
end;

function EffectDiskSize: Word;
begin
  EffectDiskSize := SizeOf(Types.TEffectRec) - EFFECT_POINTERS * Types.PTR_GROWTH;
end;

{$IFDEF FPC}
begin
  FindPointers;
{$ENDIF}
end.
