{ Converts records between their in-memory and SSI disk layouts. Character,
  item, and effect records contain four-byte far pointers on disk. That layout
  matches 16- and 32-bit builds but not a 64-bit build, where pointers are eight
  bytes and move every following field.

  Native writes replace pointers with four zero bytes and native reads restore
  them as nil. Turbo Pascal can copy the records directly. Port-specific fields
  after TCharRecord.portExt, and TItemRec.weaponSet, are not part of SSI's
  records; CharExt stores them separately. }
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
  { drainedLevels in SSI's monster records: no drain (CharFromDisk) }
  DRAINED_FILLER = $FF;

type
  TCharDisk = array[0..CHAR_DISK_BYTES - 1] of Byte;
  TItemDisk = array[0..ITEM_DISK_BYTES - 1] of Byte;
  TEffectDisk = array[0..EFFECT_DISK_BYTES - 1] of Byte;

{ A record to its disk form (disk: a TCharDisk, TItemDisk or TEffectDisk, or a buffer at least that long). }
procedure CharToDisk(var c: Types.TCharRecord; var disk);
procedure ItemToDisk(var it: Types.TItemRec; var disk);
procedure EffectToDisk(var ef: Types.TEffectRec; var disk);

{ A record from its disk form: a file's or a DAX block's bytes. Its pointers are nil natively; under Turbo Pascal they
  are the bytes the file held, which the callers clear. A character's port fields (portExt) and an item's weaponSet are
  cleared. A name whose length byte is past its field is cut to the field (StrUtil.FitLength, #917): a damaged save or
  DAX record is read whatever it holds. A character's drainedLevels of DRAINED_FILLER, SSI's monster records' filler, is
  read as no drain (#1155). An item that is Keoghtom's Ointment or the Manual of Bodily Health by its name parts and
  still has the effect SSI's data gave it, spell 58's or 67's, gets its spell's new effect (C_SPELL.ITEM_OINTMENT's,
  ITEM_BODILY_HEALTH's), as Curse's numbers have other spells there (#1121): a save, a vault, a script's item or a
  shop's all come in through here. }
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

uses StrUtil, C_ITEM, C_SPELL;

{$IFDEF FPC}
type
  { a record's pointer fields' memory offsets, in ascending order }
  TPtrOffsets = array[0..CHAR_POINTERS - 1] of Word;
  TByteBuf = array[0..65534] of Byte;
  PByteBuf = ^TByteBuf;

var
  { the bytes of TCharRecord in memory before portExt, and of TItemRec before weaponSet: the parts the disk forms hold }
  charMem: Word;
  itemMem: Word;
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
  itemMem := PtrUInt(@it.weaponSet) - PtrUInt(@it);
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
  Pack(it, itemMem, disk, itemPtrs, ITEM_POINTERS);
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
var
  ok: Boolean;
begin
{$IFDEF FPC}
  Unpack(disk, c, charMem, charPtrs, CHAR_POINTERS);
{$ELSE}
  Move(disk, c, CHAR_DISK_BYTES);
{$ENDIF}
  FillChar(c.portExt, SizeOf(c.portExt), 0);
  ok := StrUtil.FitLength(c.name, SizeOf(c.name) - 1);
  { SSI's monster records (every MONxCHA.DAX block) hold $FF in drainedLevels and drainedHps, filler, not 255 lost
    levels; an NPC joins the party with them, and a save keeps them. No character loses 255 levels, so $FF is read as
    none: the temple's Repair quoted a Restoration for each (#1155), and Restoration gave such an NPC a hit point. }
  if c.drainedLevels = DRAINED_FILLER then begin
    c.drainedLevels := 0;
    c.drainedHps := 0;
  end;
end;

{ True when one of item it's name parts is part. }
function HasNamePart(var it: Types.TItemRec; part: Byte): Boolean;
begin
  HasNamePart := (it.nameIds[1] = part) or (it.nameIds[2] = part) or (it.nameIds[3] = part);
end;

procedure ItemFromDisk(var disk; var it: Types.TItemRec);
var
  ok: Boolean;
begin
{$IFDEF FPC}
  Unpack(disk, it, itemMem, itemPtrs, ITEM_POINTERS);
{$ELSE}
  Move(disk, it, ITEM_DISK_BYTES);
{$ENDIF}
  it.weaponSet := C_ITEM.SET_NONE;
  ok := StrUtil.FitLength(it.name, SizeOf(it.name) - 1);
  if (it.effect = C_SPELL.OLD_OINTMENT_EFFECT) and
      (HasNamePart(it, C_ITEM.NAME_OINTMENT) or HasNamePart(it, C_ITEM.NAME_OINTMENT_2)) then
    it.effect := C_SPELL.ITEM_OINTMENT + C_SPELL.ITEM_EFFECT_SHIFT
  else if (it.effect = C_SPELL.OLD_BODILY_HEALTH_EFFECT) and HasNamePart(it, C_ITEM.NAME_MANUAL) then
    it.effect := C_SPELL.ITEM_BODILY_HEALTH + C_SPELL.ITEM_EFFECT_SHIFT;
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
{$IFNDEF FPC}
var
  it: Types.TItemRec;
{$ENDIF}
begin
{$IFDEF FPC}
  ItemDiskSize := itemMem - ITEM_POINTERS * Types.PTR_GROWTH;
{$ELSE}
  ItemDiskSize := Ofs(it.weaponSet) - Ofs(it);
{$ENDIF}
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
