{ Tests for the sound sequencer's output (refactor phase 7, step 0): every tune, on the speaker and on the Tandy, run
  tick by tick through the trace build (SndTrc), each tick's port writes folded into a CRC-32 with their count, until
  every voice has run out or MAX_TICKS have passed. Each digest must match the record taken from SSI's sequencer before
  the phase began, so the driver work changes no write. With no record (RECORDED False), the digests are written to
  SNDSEQ.TXT as the record's source lines, and the test fails. }
{$I COMPILER.INC}
program TSndSeq;

uses C_SOUND, SndTrc, TestKit;

const
  { tunes 0..LAST_TUNE: the rows of both of the sequencer's tune tables }
  LAST_TUNE = 28;
  MAX_TICKS = 6000;
  { a tick writes at most a dozen ports }
  BUF_WORDS = 64;
  RECORDED = True;

type
  TDigest = record
    ticks: Word;
    writes: LongInt;
    crc: LongInt;
  end;

const
  { [device, tune]: the record, taken from SSI's sequencer at 30614a4 (sounddrv.asm before phase 7) }
  EXPECTED: array[C_SOUND.MODE_TANDY..C_SOUND.MODE_SPEAKER, 0..LAST_TUNE] of TDigest = (
    { Tandy }
    ((ticks: 1; writes: 4; crc: $B223DE06), (ticks: 193; writes: 2123; crc: $9967CC9F),
     (ticks: 51; writes: 561; crc: $C657B029), (ticks: 241; writes: 2651; crc: $C4B35CE9),
     (ticks: 377; writes: 4147; crc: $B4202E2C), (ticks: 241; writes: 2651; crc: $D00D26AA),
     (ticks: 21; writes: 231; crc: $7859A132), (ticks: 605; writes: 6655; crc: $1824CA8B),
     (ticks: 61; writes: 671; crc: $453F4A2B), (ticks: 17; writes: 187; crc: $EADCC074),
     (ticks: 429; writes: 4719; crc: $3A2F90AB), (ticks: 31; writes: 341; crc: $0D49D07C),
     (ticks: 119; writes: 1309; crc: $45AAA4D6), (ticks: 26; writes: 286; crc: $D19DC663),
     (ticks: 29; writes: 319; crc: $E1BA436D), (ticks: 106; writes: 1166; crc: $897EE20C),
     (ticks: 41; writes: 451; crc: $E43084F8), (ticks: 61; writes: 671; crc: $548DE460),
     (ticks: 56; writes: 616; crc: $EAAB5457), (ticks: 17; writes: 187; crc: $F01A782D),
     (ticks: 1; writes: 11; crc: $1EBB6C7A), (ticks: 4753; writes: 52283; crc: $D4996795),
     (ticks: 2305; writes: 25355; crc: $65C7D75A), (ticks: 4177; writes: 45947; crc: $13909F33),
     (ticks: 1681; writes: 18491; crc: $7E410712), (ticks: 3361; writes: 36971; crc: $A8FFBD7C),
     (ticks: 2305; writes: 25355; crc: $09DB3BF4), (ticks: 2305; writes: 25355; crc: $35A2319A),
     (ticks: 3025; writes: 33275; crc: $12FF7794)),
    { speaker }
    ((ticks: 1; writes: 1; crc: $7D9A163C), (ticks: 241; writes: 721; crc: $68E4E914),
     (ticks: 36; writes: 106; crc: $71A967E7), (ticks: 211; writes: 631; crc: $02287718),
     (ticks: 177; writes: 529; crc: $EFB9772C), (ticks: 151; writes: 451; crc: $14AEB941),
     (ticks: 66; writes: 196; crc: $4BC33A65), (ticks: 601; writes: 1801; crc: $DE9548DE),
     (ticks: 10; writes: 28; crc: $98BC0D9B), (ticks: 9; writes: 25; crc: $7E17D15A),
     (ticks: 341; writes: 997; crc: $1A5D8DAB), (ticks: 31; writes: 91; crc: $6C656AED),
     (ticks: 108; writes: 318; crc: $99EF3C29), (ticks: 34; writes: 98; crc: $68957DDB),
     (ticks: 29; writes: 85; crc: $4CCAB19B), (ticks: 107; writes: 317; crc: $877D3359),
     (ticks: 49; writes: 113; crc: $FBB5511D), (ticks: 61; writes: 141; crc: $115BDA35),
     (ticks: 84; writes: 248; crc: $FADF8551), (ticks: 17; writes: 49; crc: $2DC926F2),
     (ticks: 1; writes: 1; crc: $7D9A163C), (ticks: 4753; writes: 13537; crc: $53EBAF90),
     (ticks: 2305; writes: 5833; crc: $5EC5A9F4), (ticks: 4177; writes: 12013; crc: $C6CC4B20),
     (ticks: 1681; writes: 4529; crc: $6A20487A), (ticks: 3361; writes: 9193; crc: $3CE8806B),
     (ticks: 2305; writes: 6457; crc: $6DD9C922), (ticks: 2305; writes: 6529; crc: $6FA9E7D8),
     (ticks: 3025; writes: 8437; crc: $8C3B2E1E)));

var
  buf: array[0..BUF_WORDS - 1] of Word;
  got: array[C_SOUND.MODE_TANDY..C_SOUND.MODE_SPEAKER, 0..LAST_TUNE] of TDigest;
  dev: Word;
  tune: Word;
  f: Text;
  s: String;

{ Fold byte b into the CRC-32 (reflected, polynomial EDB88320). }
procedure CrcByte(var crc: LongInt; b: Byte);
var
  k: Byte;
begin
  crc := crc xor b;
  for k := 1 to 8 do
    if Odd(crc) then
      crc := (crc shr 1) xor LongInt($EDB88320)
    else
      crc := crc shr 1;
end;

{ Play tune on dev and digest its writes. }
procedure Digest(dev, tune: Word; var d: TDigest);
var
  n: Word;
  i: Word;
  v: Word;
  idle: Boolean;
begin
  SndTrc.SetSoundDevice(dev);
  if dev = C_SOUND.MODE_SPEAKER then
    SndTrc.ProgramSpeakerVoices(tune)
  else
    SndTrc.ProgramTandyVoices(tune);
  d.ticks := 0;
  d.writes := 0;
  d.crc := LongInt($FFFFFFFF);
  repeat
    SndTrc.SetTraceBuffer(@buf, BUF_WORDS);
    SndTrc.TraceTick;
    n := SndTrc.TraceCount;
    Inc(d.ticks);
    Inc(d.writes, n);
    { the tick's write count, then each write's port and value }
    CrcByte(d.crc, Lo(n));
    { a while loop: with no writes, n - 1 would be 65535 }
    i := 0;
    while i < n do begin
      CrcByte(d.crc, Hi(buf[i]));
      CrcByte(d.crc, Lo(buf[i]));
      Inc(i);
    end;
    idle := True;
    for v := 0 to 3 do
      if SndTrc.SoundVoiceTune(v) <> 0 then
        idle := False;
  until idle or (d.ticks >= MAX_TICKS);
end;

function Hex(l: LongInt): String;
const
  DIGITS: string[16] = '0123456789ABCDEF';
var
  i: Byte;
  r: String;
begin
  r := '';
  for i := 7 downto 0 do
    r := r + DIGITS[((l shr (4 * i)) and $F) + 1];
  Hex := '$' + r;
end;

begin
  TestKit.Start('TSNDSEQ');
  for dev := C_SOUND.MODE_TANDY to C_SOUND.MODE_SPEAKER do
    for tune := 0 to LAST_TUNE do
      Digest(dev, tune, got[dev, tune]);
  SndTrc.SetSoundDevice(C_SOUND.MODE_DISABLED);
  if not RECORDED then begin
    Assign(f, 'SNDSEQ.TXT');
    Rewrite(f);
    for dev := C_SOUND.MODE_TANDY to C_SOUND.MODE_SPEAKER do
      for tune := 0 to LAST_TUNE do
        WriteLn(f, dev, ' ', tune, ' (ticks: ', got[dev, tune].ticks, '; writes: ', got[dev, tune].writes,
                '; crc: ', Hex(got[dev, tune].crc), ')');
    Close(f);
    TestKit.Check(False, 'no record yet: the digests are in SNDSEQ.TXT');
  end else
    for dev := C_SOUND.MODE_TANDY to C_SOUND.MODE_SPEAKER do
      for tune := 0 to LAST_TUNE do begin
        Str(tune, s);
        if dev = C_SOUND.MODE_TANDY then
          s := 'Tandy tune ' + s
        else
          s := 'speaker tune ' + s;
        TestKit.CheckEqualsL(EXPECTED[dev, tune].ticks, got[dev, tune].ticks, s + ': ticks');
        TestKit.CheckEqualsL(EXPECTED[dev, tune].writes, got[dev, tune].writes, s + ': writes');
        TestKit.CheckEqualsL(EXPECTED[dev, tune].crc, got[dev, tune].crc, s + ': CRC');
      end;
  TestKit.Done;
end.
