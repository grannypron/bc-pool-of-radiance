{ SBSFX.DAT, the Sound Blaster's recorded effects (built by tools/sbsfx.py), read for the two drivers that play them:
  SndSb's DSP under DOS and SndDig natively. The file is a header (the signature SBFX, its version and the count of
  entries), the entries (an effect's tune, format, time constant, length and offset, 7 bytes each) and the recordings'
  bytes. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit SfxFile;

interface

uses Types;

type
  { One entry: an effect's recording. }
  TSfxEntry = record
    { the effect, 1 to C_SOUND.SFX_LAST; its format, C_SOUND.SFX_PCM8 or SFX_ADPCM4; the DSP's time constant }
    tune: Byte;
    format: Byte;
    timeConstant: Byte;
    { its bytes' count, and their offset in the file (0 in an entry that holds none) }
    len: Word;
    start: Word;
  end;

{ Read SBSFX.DAT from the game's folder onto the heap: p holds its size bytes, and count is the entries the header
  gives. False, with nothing held, when the file is missing or unreadable, larger than one heap block or (under DOS)
  the heap's largest free block, or CheckHeader refuses it. }
function Load(var p: Types.PBytes; var size: Word; var count: Byte): Boolean;

{ True when the size bytes at p start with the signature and the version and hold the entries they count; count is
  that number. }
function CheckHeader(p: Types.PBytes; size: Word; var count: Byte): Boolean;

{ Entry i (0 to count - 1) of a file CheckHeader passed, in e. True when it is a recording that can play: tune 1 to
  C_SOUND.SFX_LAST, a known format, and at least one byte, all past the header and inside the file. }
function GetEntry(p: Types.PBytes; size: Word; i: Byte; var e: TSfxEntry): Boolean;

implementation

uses C_SOUND, FileUtil, GameVars;

const
  FILE_NAME = 'SBSFX.DAT';
  SIGNATURE = 'SBFX';
  VERSION = 2;
  HEADER_BYTES = 6;
  ENTRY_BYTES = 7;
  { the largest block the heap gives }
  MAX_SIZE = $FFF0;

function CheckHeader(p: Types.PBytes; size: Word; var count: Byte): Boolean;
var
  sig: string[4];
begin
  CheckHeader := False;
  count := 0;
  if size < HEADER_BYTES then Exit;
  sig[0] := #4;
  Move(p^[0], sig[1], 4);
  count := p^[5];
  CheckHeader := (sig = SIGNATURE) and (p^[4] = VERSION) and (HEADER_BYTES + ENTRY_BYTES * Word(count) <= size);
end;

function GetEntry(p: Types.PBytes; size: Word; i: Byte; var e: TSfxEntry): Boolean;
var
  rec: Word;
begin
  rec := HEADER_BYTES + ENTRY_BYTES * Word(i);
  e.tune := p^[rec];
  e.format := p^[rec + 1];
  e.timeConstant := p^[rec + 2];
  Move(p^[rec + 3], e.len, 2);
  Move(p^[rec + 5], e.start, 2);
  GetEntry := (e.tune >= 1) and (e.tune <= C_SOUND.SFX_LAST) and (e.format <= C_SOUND.SFX_ADPCM4) and (e.len > 0) and
              (e.start >= HEADER_BYTES) and (LongInt(e.start) + e.len <= size);
end;

function Load(var p: Types.PBytes; var size: Word; var count: Byte): Boolean;
var
  f: file;
  bytes: LongInt;
  got: Word;
  ok: Boolean;
  ioRes: Integer;
begin
  Load := False;
  p := nil;
  size := 0;
  count := 0;
  if not FileUtil.OpenReadOnly(f, GameVars.gameDir + FILE_NAME) then Exit;
  bytes := FileSize(f);
  ok := (IOResult = 0) and (bytes >= HEADER_BYTES) and (bytes <= MAX_SIZE);
{$IFNDEF FPC}
  ok := ok and (bytes <= MaxAvail);
{$ENDIF}
  if not ok then begin
    Close(f);
    ioRes := IOResult;
    Exit;
  end;
  size := bytes;
  GetMem(p, size);
  BlockRead(f, p^, size, got);
  Close(f);
  ok := (IOResult = 0) and (got = size);
  if ok then
    ok := SfxFile.CheckHeader(p, size, count);
  if not ok then begin
    FreeMem(p, size);
    p := nil;
    size := 0;
    count := 0;
    Exit;
  end;
  Load := True;
end;

end.
