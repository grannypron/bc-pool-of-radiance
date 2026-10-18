{ The vault, The Hoarder's Respite in New Phlan (#606): money and items the party leaves there are kept with the saved
  game, as Pools of Darkness keeps its vault. While a game is played its vault is the session file tmpvault.dat in the
  save directory; saving a game copies it to vault<x>.dat beside savgam<x>.dat, and loading one copies that back, so
  what is left in the vault and then given up with an unsaved game is gone with it. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit Vault;

interface

uses Types;

const
  { the most items the vault holds }
  MAX_ITEMS = 100;

{ Forget the session vault: a new game, or one left unsaved last time, starts with an empty vault. }
procedure ForgetSessionVault;

{ Saving into slot letter: copy the session vault to vault<x>.dat, or delete that file when the vault is empty. }
procedure CommitToSlot(letter: Char);

{ Loading slot letter: copy its vault<x>.dat to the session vault, or forget the session vault when it has none. }
procedure RestoreFromSlot(letter: Char);

{ True while the vault (GDVars.treasureItems, in the vault) has room for another item. }
function HasRoom: Boolean;

{ Deposit: move item from creature's pack to the end of the vault's items. }
procedure DepositItem(creature: Types.PCharRecord; item: Types.PItemRec);

{ Read the session vault into the treasure pool: its money, then its items after any already there. An unreadable or
  missing file is an empty vault never visited. }
procedure ReadVault;

{ Write the treasure pool to the session vault, then free its items and empty it. }
procedure WriteVault;

{ True when the party has been to the vault before (its ledger says so), as ReadVault found it. }
function WasVisited: Boolean;

implementation

uses Crt, GDVars, Dos, CharHlp, TextRend, SaveMenu, FileUtil;

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

function SlotFile(letter: Char): Types.TPathStr;
begin
  SlotFile := GDVars.dsSaveDirectory + 'vault' + letter + '.dat';
end;

const
  { CopyOrDelete's buffer, taken from the heap: the stack is not the place for it }
  COPY_BUF = 512;

type
  TCopyBuf = array[1..COPY_BUF] of Byte;

{ Copy file src to dst, or delete dst when src cannot be read. }
procedure CopyOrDelete(src, dst: Types.TPathStr);
var
  fIn: file;
  fOut: file;
  buf: ^TCopyBuf;
  n: Word;
  w: Word;
  ok: Boolean;
  ioRes: Integer;
begin
  if not FileUtil.OpenReadOnly(fIn, src) then begin
    FileUtil.DeleteFile(dst);
    Exit;
  end;
  Assign(fOut, dst);
  Rewrite(fOut, 1);
  ok := IOResult = 0;
  if ok then begin
    GetMem(buf, SizeOf(TCopyBuf));
    repeat
      BlockRead(fIn, buf^, SizeOf(TCopyBuf), n);
      if IOResult <> 0 then
        n := 0;
      if n > 0 then begin
        BlockWrite(fOut, buf^, n, w);
        if (IOResult <> 0) or (w <> n) then
          n := 0;
      end;
    until n = 0;
    FreeMem(buf, SizeOf(TCopyBuf));
    Close(fOut);
  end;
  Close(fIn);
  ioRes := IOResult;
end;

procedure ForgetSessionVault;
begin
  FileUtil.DeleteFile(GDVars.dsSaveDirectory + SESSION_FILE);
end;

procedure CommitToSlot(letter: Char);
begin
  Vault.CopyOrDelete(GDVars.dsSaveDirectory + SESSION_FILE, Vault.SlotFile(letter));
end;

procedure RestoreFromSlot(letter: Char);
begin
  Vault.CopyOrDelete(Vault.SlotFile(letter), GDVars.dsSaveDirectory + SESSION_FILE);
end;

function ItemCount: Word;
var
  p: Types.PItemRec;
  n: Word;
begin
  n := 0;
  p := GDVars.treasureItems;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ItemCount := n;
end;

function HasRoom: Boolean;
begin
  HasRoom := Vault.ItemCount < MAX_ITEMS;
end;

procedure DepositItem(creature: Types.PCharRecord; item: Types.PItemRec);
begin
  CharHlp.AppendItemCopy(GDVars.treasureItems, item);
  CharHlp.RemoveItem(creature, item);
end;

procedure ReadVault;
var
  f: file;
  head: TVaultHeader;
  item: Types.TItemRec;
  n: Word;
  ioRes: Integer;
begin
  visited := 0;
  FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
  if not FileUtil.OpenReadOnly(f, GDVars.dsSaveDirectory + SESSION_FILE) then
    Exit;
  BlockRead(f, head, SizeOf(head), n);
  if (IOResult = 0) and (n = SizeOf(head)) and (head.sig = VAULT_SIG) and (head.version = VAULT_VERSION) then begin
    visited := head.visited;
    Move(head.money, GDVars.treasureMoney, SizeOf(GDVars.treasureMoney));
    repeat
      BlockRead(f, item, SizeOf(item), n);
      if IOResult <> 0 then
        n := 0;
      if (n = SizeOf(item)) and Vault.HasRoom then
        CharHlp.AppendItemCopy(GDVars.treasureItems, @item);
    until n <> SizeOf(item);
  end;
  Close(f);
  ioRes := IOResult;
end;

procedure WriteVault;
var
  f: file;
  head: TVaultHeader;
  p: Types.PItemRec;
  next: Types.PItemRec;
  ioRes: Integer;
  item: Types.TItemRec;
begin
  SaveMenu.CheckSaveDir;
  FillChar(head, SizeOf(head), 0);
  head.sig := VAULT_SIG;
  head.version := VAULT_VERSION;
  head.visited := 1;
  Move(GDVars.treasureMoney, head.money, SizeOf(head.money));
  Assign(f, GDVars.dsSaveDirectory + SESSION_FILE);
  Rewrite(f, 1);
  if IOResult = 0 then begin
    BlockWrite(f, head, SizeOf(head));
    p := GDVars.treasureItems;
    while p <> nil do begin
      { without its link, which ReadVault rebuilds: a heap address would make two saves of one vault differ }
      item := p^;
      item.next := nil;
      BlockWrite(f, item, SizeOf(Types.TItemRec));
      p := p^.next;
    end;
    Close(f);
  end;
  ioRes := IOResult;
  if ioRes <> 0 then
    TextRend.DisplayAndPause(Yellow, 'The vault''s ledger was not written.');
  CharHlp.ClearTreasure;
end;

function WasVisited: Boolean;
begin
  WasVisited := visited <> 0;
end;

end.
