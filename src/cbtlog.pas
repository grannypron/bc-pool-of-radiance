{ The combat message history (#841): the last fight's messages, kept so the player can page back through them. Each
  entry is one message as the combat window showed it, its pieces in their own colours: a colour change is COLOR_MARK
  followed by the colour's byte. Entries are kept unwrapped, up to 255 characters, and wrapped again for a wider page by
  LogWrap.

  The entries live in a ring of SLOT_SIZE-byte slots outside the data segment and the heap: under DOS one EMS page,
  copied to and from with the EMS driver's Move Memory Region (function 57h), which leaves the page frame's mapping
  alone, so the overlay manager's own use of EMS is not disturbed. Without an EMS 4.0 driver, or with no page free once
  the overlays have taken theirs, the history is not usable and nothing is kept. The native build has no EMS and memory
  to spare: its ring is on the heap, and always usable. The entry being built is here until the next one starts.

  Resident, not overlaid, so logging a blow in combat loads no overlay. Nothing here knows the game: the callers say
  what to log and in what colour, and the ring's size comes from the caller. }
{$F+,I-}
{$I COMPILER.INC}
unit CbtLog;

interface

uses C_OPT;

const
  { the fewest and most entries a ring holds, and the default: the Log Lines setting's range (#876) }
  MIN_ENTRIES = C_OPT.LOG_MIN;
  MAX_ENTRIES = C_OPT.LOG_MAX;
  DEFAULT_ENTRIES = C_OPT.LOG_DEFAULT;
  { an entry's slot: a whole string }
  SLOT_SIZE = 256;
  { an entry's colour change: this character, then the colour }
  COLOR_MARK = #1;

{ Find the ring's store: under DOS an EMS page, natively the heap. Call once at start-up, after the overlay manager has
  taken the EMS it wants. Under DOS the page is given back when the program ends. }
procedure Startup;

{ True when Startup found a store, so the history can be kept. }
function Usable: Boolean;

{ Empty the history at the start of a fight and size the ring for capacity entries (kept within MIN_ENTRIES and
  MAX_ENTRIES). The fight is logged only when enabled is set and the history is usable. }
procedure Clear(capacity: Byte; enabled: Boolean);

{ True while the history is being kept: Clear turned it on. }
function Active: Boolean;

{ End the entry being built, keeping it when it holds anything; the next Add starts a new one. }
procedure NewEntry;

{ Add s in color to the entry being built, as it is: the pieces of a message shown one after another on a line. }
procedure Add(color: Byte; s: string);

{ Separate what follows from what came before with a space, as a piece shown on a line of its own is: nothing at the
  start of an entry or after a space. }
procedure NextLine;

{ A heading of its own, s in color, such as a round's number: the entry being built ends, and so does the heading. }
procedure Heading(color: Byte; s: string);

{ The number of entries kept, the one being built among them. }
function Count: Byte;

{ Entry n, from 1 for the oldest kept to Count for the newest; empty for any other n. }
procedure Entry(n: Byte; var s: string);


implementation

{$IFNDEF FPC}
uses Dos;
{$ENDIF}

type
  TSlot = string[SLOT_SIZE - 1];
{$IFDEF FPC}
  TRing = array[0..MAX_ENTRIES - 1] of TSlot;
  PRing = ^TRing;
{$ELSE}
  { EMS function 57h's region description: the length, then the source and the destination, each as its memory type (0
    conventional, 1 expanded), its EMS handle, its offset and its segment (conventional) or logical page (expanded) }
  TEmsMove = record
    size: LongInt;
    srcType: Byte;
    srcHandle: Word;
    srcOfs: Word;
    srcSeg: Word;
    dstType: Byte;
    dstHandle: Word;
    dstOfs: Word;
    dstSeg: Word;
  end;
{$ENDIF}

var
  haveStore: Boolean;
  logging: Boolean;
  { the ring's size, its next slot to fill and how many slots hold an entry }
  ringSize: Byte;
  ringNext: Byte;
  ringCount: Byte;
  { the entry being built, and the colour its last piece set (0 before the first) }
  current: TSlot;
  curColor: Byte;
{$IFDEF FPC}
  ring: PRing;
{$ELSE}
  { the EMS handle of the ring's page }
  emsHandle: Word;
  savedExit: Pointer;
{$ENDIF}

{$IFNDEF FPC}
{ Call EMS function ah with the given bx and dx, and return its status (0 when it worked); regs keeps what it
  returned. }
function Ems(var regs: Registers; ah: Byte; bx, dx: Word): Byte;
begin
  regs.ah := ah;
  regs.bx := bx;
  regs.dx := dx;
  Intr($67, regs);
  Ems := regs.ah;
end;

{ True when an EMS driver is installed: its device name, EMMXXXX0, is in the header of the segment INT 67h points
  into. }
function DriverThere: Boolean;
const
  NAME: string[8] = 'EMMXXXX0';
var
  vec: Pointer;
  i: Byte;
  same: Boolean;
begin
  GetIntVec($67, vec);
  same := vec <> nil;
  if same then
    for i := 1 to Length(NAME) do
      if Mem[Seg(vec^):9 + i] <> Ord(NAME[i]) then
        same := False;
  DriverThere := same;
end;

{ The exit procedure: give the ring's page back, as an EMS page is not freed when a program ends. }
procedure FreePage;
var
  regs: Registers;
begin
  ExitProc := savedExit;
  if haveStore then
    if CbtLog.Ems(regs, $45, 0, emsHandle) = 0 then
      haveStore := False;
end;

{ Copy size bytes between the conventional memory at p and the ring's page at offset at, into the page when toPage is
  set. }
procedure MovePage(p: Pointer; at: Word; size: Word; toPage: Boolean);
var
  region: TEmsMove;
  regs: Registers;
begin
  region.size := size;
  if toPage then begin
    region.srcType := 0;
    region.srcHandle := 0;
    region.srcOfs := Ofs(p^);
    region.srcSeg := Seg(p^);
    region.dstType := 1;
    region.dstHandle := emsHandle;
    region.dstOfs := at;
    region.dstSeg := 0;
  end else begin
    region.srcType := 1;
    region.srcHandle := emsHandle;
    region.srcOfs := at;
    region.srcSeg := 0;
    region.dstType := 0;
    region.dstHandle := 0;
    region.dstOfs := Ofs(p^);
    region.dstSeg := Seg(p^);
  end;
  regs.ax := $5700;
  regs.ds := Seg(region);
  regs.si := Ofs(region);
  Intr($67, regs);
end;
{$ENDIF}

procedure Startup;
{$IFNDEF FPC}
var
  regs: Registers;
{$ENDIF}
begin
  if haveStore then Exit;
{$IFDEF FPC}
  New(ring);
  haveStore := True;
{$ELSE}
  { the driver, working (40h), at version 4.0 or later for 57h (46h), with a page to give (43h) }
  if not CbtLog.DriverThere then Exit;
  if CbtLog.Ems(regs, $40, 0, 0) <> 0 then Exit;
  if CbtLog.Ems(regs, $46, 0, 0) <> 0 then Exit;
  if regs.al < $40 then Exit;
  if CbtLog.Ems(regs, $43, 1, 0) <> 0 then Exit;
  emsHandle := regs.dx;
  haveStore := True;
  savedExit := ExitProc;
  ExitProc := @FreePage;
{$ENDIF}
end;

function Usable: Boolean;
begin
  Usable := haveStore;
end;

{ Write s to slot n. }
procedure PutSlot(n: Byte; var s: TSlot);
begin
{$IFDEF FPC}
  ring^[n] := s;
{$ELSE}
  CbtLog.MovePage(@s, n * SLOT_SIZE, Length(s) + 1, True);
{$ENDIF}
end;

{ Read slot n into s. }
procedure GetSlot(n: Byte; var s: TSlot);
begin
{$IFDEF FPC}
  s := ring^[n];
{$ELSE}
  CbtLog.MovePage(@s, n * SLOT_SIZE, SLOT_SIZE, False);
{$ENDIF}
end;

procedure Clear(capacity: Byte; enabled: Boolean);
begin
  if capacity < MIN_ENTRIES then
    capacity := MIN_ENTRIES;
  if capacity > MAX_ENTRIES then
    capacity := MAX_ENTRIES;
  ringSize := capacity;
  ringNext := 0;
  ringCount := 0;
  current := '';
  curColor := 0;
  logging := enabled and haveStore;
end;

function Active: Boolean;
begin
  Active := logging;
end;

procedure NewEntry;
begin
  if not logging then Exit;
  if current <> '' then begin
    CbtLog.PutSlot(ringNext, current);
    ringNext := (ringNext + 1) mod ringSize;
    if ringCount < ringSize then
      Inc(ringCount);
  end;
  current := '';
  curColor := 0;
end;

procedure Add(color: Byte; s: string);
var
  room: Integer;
begin
  if not logging or (s = '') then Exit;
  if color <> curColor then begin
    { a colour change with nothing after it is not worth its room }
    if Length(current) + 3 > SizeOf(current) - 1 then Exit;
    current := current + COLOR_MARK + Chr(color);
    curColor := color;
  end;
  room := SizeOf(current) - 1 - Length(current);
  if Length(s) > room then
    s[0] := Chr(room);
  current := current + s;
end;

procedure NextLine;
begin
  if not logging or (current = '') then Exit;
  if current[Length(current)] <> ' ' then
    if Length(current) < SizeOf(current) - 1 then
      current := current + ' ';
end;

procedure Heading(color: Byte; s: string);
begin
  CbtLog.NewEntry;
  CbtLog.Add(color, s);
  CbtLog.NewEntry;
end;

function Count: Byte;
begin
  Count := ringCount + Ord(logging and (current <> ''));
end;

procedure Entry(n: Byte; var s: string);
var
  slot: TSlot;
begin
  s := '';
  if (n < 1) or (n > CbtLog.Count) then Exit;
  if n > ringCount then
    s := current
  else begin
    { the oldest kept is ringNext once the ring has wrapped, else slot 0 }
    if ringCount < ringSize then
      CbtLog.GetSlot(n - 1, slot)
    else
      CbtLog.GetSlot((ringNext + n - 1) mod ringSize, slot);
    s := slot;
  end;
end;

{ Turbo Pascal clears no variable: nothing is kept until Startup and Clear say so. }
begin
  haveStore := False;
  logging := False;
  ringSize := DEFAULT_ENTRIES;
  ringNext := 0;
  ringCount := 0;
  current := '';
  curColor := 0;
end.
