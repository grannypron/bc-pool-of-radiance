{ Reads the recorded effects in SBSFX.DAT for the DOS Sound Blaster and native
  digital-audio drivers. The file contains an SBFX header, seven-byte directory
  entries, and the sample data. tools/sbsfx.py creates it. }
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

{ Loads SBSFX.DAT into one heap block. Native builds prefer the copy beside the
  executable and otherwise use the game-data directory (#1064). Returns False
  and leaves p nil when the file cannot be read, does not fit, or has an invalid
  header. The caller owns the returned block. }
function Load(var p: Types.PBytes; var size: Word; var count: Byte): Boolean;

{ Validates the signature, version, and directory size, and returns the number
  of entries in count. }
function CheckHeader(p: Types.PBytes; size: Word; var count: Byte): Boolean;

{ Reads and validates directory entry i. A playable entry must name a known
  tune and format, contain sample data entirely inside the file, and fit the
  native decoder's Word-sized sample count (#916). Drivers let later entries
  replace earlier entries for the same tune. }
function GetEntry(p: Types.PBytes; size: Word; i: Byte; var e: TSfxEntry): Boolean;

{ Returns the decoded sample count. PCM has one sample per byte. ADPCM stores
  the first sample directly and two samples in each remaining byte. }
function DecodedLength(var e: TSfxEntry): LongInt;

implementation

uses C_SOUND, FileUtil, GameVars{$IFDEF FPC}, GameDirs{$ENDIF};

const
  FILE_NAME = 'SBSFX.DAT';
  SIGNATURE = 'SBFX';
  VERSION = 2;
  HEADER_BYTES = 6;
  ENTRY_BYTES = 7;
  { the largest block the heap gives }
  MAX_SIZE = $FFF0;
  { the most ADPCM bytes whose samples (DecodedLength) a Word counts: 2 * 32768 - 1 = 65535 }
  MAX_ADPCM_BYTES = 32768;

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
              (e.start >= HEADER_BYTES) and (LongInt(e.start) + e.len <= size) and
              ((e.format <> C_SOUND.SFX_ADPCM4) or (e.len <= MAX_ADPCM_BYTES));
end;

function DecodedLength(var e: TSfxEntry): LongInt;
begin
  if e.format = C_SOUND.SFX_ADPCM4 then
    DecodedLength := 2 * (LongInt(e.len) - 1) + 1
  else
    DecodedLength := e.len;
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
  if not FileUtil.OpenReadOnly(f, {$IFDEF FPC}GameDirs.OwnFolder(FILE_NAME){$ELSE}GameVars.gameDir{$ENDIF} + FILE_NAME)
    then Exit;
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
