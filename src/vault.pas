{ Persistence for The Hoarder's Respite vault in New Phlan (#606). During play,
  the session vault is tmpvault.dat. Saving copies it into the selected slot as
  vault<x>.dat; loading restores that copy to the session file. This makes vault
  changes part of the saved game rather than global state.

  Writes use temporary files and atomic file-set commits, so a failed write
  leaves the previous vault intact. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit Vault;

interface

uses Types, FileUtil;

const
  { the most items the vault holds }
  MAX_ITEMS = 100;

{ Forget the session vault: a new game, or one left unsaved last time, starts with an empty vault. }
procedure ForgetSessionVault;

{ Saving into slot letter: copy the session vault to the temporary copy of vault<x>.dat and add it to save s, or, with
  no session vault, have s erase vault<x>.dat. False when the copy was not written whole (none is then left). }
function AddToSave(var s: FileUtil.TFileSet; letter: Char): Boolean;

{ Loading slot letter: copy its vault<x>.dat to the session vault, or forget the session vault when it has none. A copy
  not written whole is reported, and the session vault forgotten, so no other game's vault stays in its place. }
procedure RestoreFromSlot(letter: Char);

{ True while the vault (GameVars.treasureItems, in the vault) has room for another item. }
function HasRoom: Boolean;

{ Deposit: move item from creature's pack to the end of the vault's items. }
procedure DepositItem(creature: Types.PCharRecord; item: Types.PItemRec);

{ Read the session vault into the treasure pool: its money, then its items after any already there. An unreadable or
  missing file is an empty vault never visited. }
procedure ReadVault;

{ Write the treasure pool to the session vault: True when it was written whole. Else it says so on the bottom line,
  and the session vault is left as it was. The pool is left for the caller to clear. }
function WriteVault: Boolean;

{ True when the party has been to the vault before (its ledger says so), as ReadVault found it. }
function WasVisited: Boolean;

implementation

uses Crt, GameVars, Dos, CharHlp, MenuCore, TextRend, SaveMenu, DiskRec{$IFDEF FPC}, NatFile{$ENDIF};

const
  SESSION_FILE = 'tmpvault.dat';
  VAULT_SIG = 'VALT';
  VAULT_VERSION = 1;

type
  { The head of a vault file; the items follow, one TItemRec each, to the end of the file. }
  TVaultHeader = record
    sig: string[4];
    version: Byte;
    { nonzero once the party has been in the vault }
    visited: Byte;
    money: Types.TMoney;
  end;

var
  visited: Byte;


const
  { CopyToTemp's buffer, taken from the heap: the stack is not the place for it }
  COPY_BUF = 512;

type
  TCopyBuf = array[1..COPY_BUF] of Byte;

{ Copy the open file fIn to dst's temporary copy (FileUtil.TempName), and close fIn: True when it was read and written
  whole, else no copy is left. }
function CopyToTemp(var fIn: file; dst: Types.TPathStr): Boolean;
var
  fOut: file;
  buf: ^TCopyBuf;
  n: Word;
  ok: Boolean;
  ioRes: Integer;
begin
  ok := FileUtil.RewriteTemp(fOut, dst);
  if ok then begin
    GetMem(buf, SizeOf(TCopyBuf));
    repeat
      BlockRead(fIn, buf^, SizeOf(TCopyBuf), n);
      if IOResult <> 0 then
        ok := False;
      if ok and (n > 0) then
        FileUtil.WriteChecked(fOut, buf^, n, ok);
    until (n = 0) or not ok;
    FreeMem(buf, SizeOf(TCopyBuf));
    ok := FileUtil.CloseTemp(fOut, dst, ok);
  end;
  Close(fIn);
  ioRes := IOResult;
  CopyToTemp := ok;
end;

procedure ForgetSessionVault;
begin
  FileUtil.DeleteFile(GameVars.saveDirectory + SESSION_FILE);
end;

function AddToSave(var s: FileUtil.TFileSet; letter: Char): Boolean;
var
  fIn: file;
  ok: Boolean;
begin
  ok := True;
  if not FileUtil.OpenReadOnly(fIn, GameVars.saveDirectory + SESSION_FILE) then
    FileUtil.AddToSet(s, SaveMenu.VaultName(letter), False)
  else begin
    ok := Vault.CopyToTemp(fIn, s.dir + SaveMenu.VaultName(letter));
    if ok then
      FileUtil.AddToSet(s, SaveMenu.VaultName(letter), True);
  end;
  AddToSave := ok;
end;

procedure RestoreFromSlot(letter: Char);
var
  fIn: file;
  ok: Boolean;
begin
  { the slot's copy becomes the session vault; a slot with none leaves no session vault }
  if FileUtil.OpenReadOnly(fIn, GameVars.saveDirectory + SaveMenu.VaultName(letter)) then
    ok := Vault.CopyToTemp(fIn, GameVars.saveDirectory + SESSION_FILE) and
          FileUtil.PutInPlace(GameVars.saveDirectory + SESSION_FILE)
  else
    ok := FileUtil.DeleteChecked(GameVars.saveDirectory + SESSION_FILE);
  if not ok then begin
    Vault.ForgetSessionVault;
    TextRend.DisplayAndPause(Yellow, 'The vault''s ledger was not copied.');
  end;
end;

function HasRoom: Boolean;
begin
  HasRoom := MenuCore.ListCount(GameVars.treasureItems) < MAX_ITEMS;
end;

procedure DepositItem(creature: Types.PCharRecord; item: Types.PItemRec);
begin
  CharHlp.AppendItemCopy(GameVars.treasureItems, item);
  CharHlp.RemoveItem(creature, item);
end;

procedure ReadVault;
var
  f: file;
  head: TVaultHeader;
  item: Types.TItemRec;
  { the item as the file has it (DiskRec) }
  disk: DiskRec.TItemDisk;
  n: Word;
  ioRes: Integer;
begin
  visited := 0;
  FillChar(GameVars.treasureMoney, SizeOf(GameVars.treasureMoney), 0);
  { a write the game was ended in is undone first }
  if not FileUtil.RecoverFile(GameVars.saveDirectory + SESSION_FILE) then
    Exit;
  if not FileUtil.OpenReadOnly(f, GameVars.saveDirectory + SESSION_FILE) then
    Exit;
  BlockRead(f, head, SizeOf(head), n);
  if (IOResult = 0) and (n = SizeOf(head)) and (head.sig = VAULT_SIG) and (head.version = VAULT_VERSION) then begin
    visited := head.visited;
    Move(head.money, GameVars.treasureMoney, SizeOf(GameVars.treasureMoney));
    repeat
      BlockRead(f, disk, DiskRec.ITEM_DISK_BYTES, n);
      if IOResult <> 0 then
        n := 0;
      if (n = DiskRec.ITEM_DISK_BYTES) and Vault.HasRoom then begin
        DiskRec.ItemFromDisk(disk, item);
        CharHlp.AppendItemCopy(GameVars.treasureItems, @item);
      end;
    until n <> DiskRec.ITEM_DISK_BYTES;
  end;
  Close(f);
  ioRes := IOResult;
end;

function WriteVault: Boolean;
var
  f: file;
  head: TVaultHeader;
  p: Types.PItemRec;
  ok: Boolean;
  item: Types.TItemRec;
  { the item as the file has it (DiskRec) }
  disk: DiskRec.TItemDisk;
begin
  SaveMenu.CheckSaveDir;
  FillChar(head, SizeOf(head), 0);
  head.sig := VAULT_SIG;
  head.version := VAULT_VERSION;
  head.visited := 1;
  Move(GameVars.treasureMoney, head.money, SizeOf(head.money));
  ok := FileUtil.RewriteTemp(f, GameVars.saveDirectory + SESSION_FILE);
  if ok then begin
    FileUtil.WriteChecked(f, head, SizeOf(head), ok);
    p := GameVars.treasureItems;
    while ok and (p <> nil) do begin
      { without its link, which ReadVault rebuilds: a heap address would make two saves of one vault differ }
      item := p^;
      item.next := nil;
      DiskRec.ItemToDisk(item, disk);
      FileUtil.WriteChecked(f, disk, DiskRec.ITEM_DISK_BYTES, ok);
      p := p^.next;
    end;
    ok := FileUtil.CloseTemp(f, GameVars.saveDirectory + SESSION_FILE, ok) and
          FileUtil.PutInPlace(GameVars.saveDirectory + SESSION_FILE);
  end;
  if not ok then
    TextRend.DisplayAndPause(Yellow, 'The vault''s ledger was not written.');
  WriteVault := ok;
end;

function WasVisited: Boolean;
begin
  WasVisited := visited <> 0;
end;

end.
