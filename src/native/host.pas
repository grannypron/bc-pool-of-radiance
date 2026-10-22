{$I COMPILER.INC}
{ The native build's stand-ins for the PC the game ran on: the VGA's memory and DAC, the video BIOS's INT 10h, the BIOS
  clock and the BIOS's keyboard buffer. Plain memory, no SDL, so the unit tests link without it: SdlHost shows this
  screen and fills the keyboard buffer, through serviceHook. Free Pascal only: the DOS build has the hardware. The units
  that call INT 10h use this unit after Dos, so its Registers and Intr are the ones they see. }
unit Host;

interface

const
  SCREEN_WIDTH = 320;
  SCREEN_HEIGHT = 200;
  { the video mode a program starts in: DOS's 80x25 colour text }
  TEXT_MODE = 3;
  { the game's one native mode: 320x200, a byte a pixel }
  VGA_MODE = $13;

type
  TScreen = array[0..SCREEN_WIDTH * SCREEN_HEIGHT - 1] of Byte;

  { Turbo Pascal's Dos.Registers, which Intr reads and writes }
  Registers = record
    case Integer of
      0: (ax, bx, cx, dx, bp, si, di, ds, es, flags: Word);
      1: (al, ah, bl, bh, cl, ch, dl, dh: Byte);
  end;

var
  { mode 13h's memory at $A000: a byte a pixel, each a DAC entry }
  screen: TScreen;
  { the DAC: 256 entries of red, green and blue, 6 bits each (0..63) }
  dac: array[0..255, 0..2] of Byte;
  { the mode INT 10h AH=0 last set }
  videoMode: Byte;

  { SdlHost's routine that takes the window's events in (keys to PushKey) and shows the screen; nil in the unit tests }
  serviceHook: procedure;

{ Run serviceHook, when there is one: the game calls this wherever DOS would have let the hardware get on with it
  (waiting for a key, Delay). }
procedure Service;

{ The BIOS keyboard buffer: a key as INT 16h gives it, scan code in the high byte and character in the low (0 for a key
  with no character: a function key, a cursor key, an Alt combination). A full buffer drops the key, as the BIOS's
  does. }
procedure PushKey(scan, ch: Byte);
function KeyWaiting: Boolean;
{ The next key; 0 when there is none. }
function PopKey: Word;

{ The BIOS timer's count, 18.2 ticks a second, as DOS keeps it at 0040:006C: here counted from the program's start
  rather than from midnight, which the game does not depend on (its waits handle the count's wrap). }
function BiosTicks: LongInt;

{ The video BIOS's functions the game calls, on screen and videoMode; any other interrupt or function does nothing.
    AH=0    set mode AL (mode 13h clears the screen)
    AH=2    put page BH's cursor at row DH, column DL
    AH=5    show page AL (the native screen has one page: nothing)
    AH=9    write CX copies of character AL in colour BL at the cursor, without moving it (mode 13h only: BIOS_FONT's
            set bits in BL, XORed when BL's bit 7 is set, the clear bits black)
    AH=0Fh  AL := the mode
    AH=10h  EGA palette registers (the native screen is VGA's: nothing) }
procedure Intr(intNo: Byte; var regs: Registers);

implementation

uses SysUtils;

{$I BIOSFONT.INC}

const
  { a ring of 16 words, one always empty: it holds 15 keys, as the BIOS's does }
  KEY_BUFFER_KEYS = 16;

var
  startMs: QWord;
  keyBuffer: array[0..KEY_BUFFER_KEYS - 1] of Word;
  keyHead: Byte;
  keyTail: Byte;
  { each page's cursor, as INT 10h AH=2 set it }
  cursorRow: array[0..7] of Byte;
  cursorCol: array[0..7] of Byte;

procedure Service;
begin
  if Assigned(serviceHook) then
    serviceHook;
end;

procedure PushKey(scan, ch: Byte);
var
  next: Byte;
begin
  next := (keyTail + 1) mod KEY_BUFFER_KEYS;
  if next = keyHead then
    Exit;
  keyBuffer[keyTail] := Word(scan) shl 8 or ch;
  keyTail := next;
end;

function KeyWaiting: Boolean;
begin
  KeyWaiting := keyHead <> keyTail;
end;

function PopKey: Word;
begin
  if keyHead = keyTail then
    PopKey := 0
  else begin
    PopKey := keyBuffer[keyHead];
    keyHead := (keyHead + 1) mod KEY_BUFFER_KEYS;
  end;
end;

function BiosTicks: LongInt;
begin
  { 1,193,182 Hz / 65,536 = 18.2065 ticks a second }
  BiosTicks := LongInt(((GetTickCount64 - startMs) * 1193182) div 65536000);
end;

{ count copies of ch from (col, row) rightwards, in colour, as mode 13h's BIOS draws them }
procedure WriteBiosChars(col, row, ch, color: Byte; count: Word);
var
  n: Word;
  r: Byte;
  k: Byte;
  bits: Byte;
  ofs: LongInt;
begin
  n := 0;
  while (n < count) and (col + n < SCREEN_WIDTH div 8) and (row < SCREEN_HEIGHT div 8) do begin
    for r := 0 to 7 do begin
      if ch < 128 then
        bits := BIOS_FONT[ch, r]
      else
        bits := 0;
      ofs := (LongInt(row) * 8 + r) * SCREEN_WIDTH + (col + n) * 8;
      for k := 0 to 7 do
        if (bits and ($80 shr k)) = 0 then
          screen[ofs + k] := 0
        else if (color and $80) <> 0 then
          screen[ofs + k] := screen[ofs + k] xor (color and $7F)
        else
          screen[ofs + k] := color;
    end;
    Inc(n);
  end;
end;

procedure Intr(intNo: Byte; var regs: Registers);
begin
  if intNo <> $10 then
    Exit;
  case regs.ah of
    0: begin
         videoMode := regs.al and $7F;
         if videoMode = VGA_MODE then
           FillChar(screen, SizeOf(screen), 0);
       end;
    2: begin
         cursorRow[regs.bh and 7] := regs.dh;
         cursorCol[regs.bh and 7] := regs.dl;
       end;
    9: if videoMode = VGA_MODE then
         WriteBiosChars(cursorCol[regs.bh and 7], cursorRow[regs.bh and 7], regs.al, regs.bl, regs.cx);
    $F: regs.al := videoMode;
  end;
end;

begin
  startMs := GetTickCount64;
  videoMode := TEXT_MODE;
  { DOS without SHARE let a file be open twice for writing (DaxIo opens each archive twice); Windows refuses the second
    unless the first shares writing: files open sharing everything (fmShareDenyNone), which other systems ignore }
  FileMode := FileMode or $40;
end.
