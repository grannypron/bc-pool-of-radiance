{ Tests for SfxFile: SBSFX.DAT's header and entries, as SndSb and SndDig read them, on a file built in memory. }
{$I COMPILER.INC}
program TSfxFile;

uses Types, C_SOUND, SfxFile, TestKit;

const
  { a header, six entries and 16 bytes of samples }
  SIZE = 64;
  DATA_START = 48;

var
  p: Types.PBytes;
  count: Byte;
  e: SfxFile.TSfxEntry;

{ Entry i: tune, format, time constant, length and offset. }
procedure SetEntry(i, tune, format, timeConstant: Byte; len, start: Word);
var
  rec: Word;
begin
  rec := 6 + 7 * i;
  p^[rec] := tune;
  p^[rec + 1] := format;
  p^[rec + 2] := timeConstant;
  p^[rec + 3] := Lo(len);
  p^[rec + 4] := Hi(len);
  p^[rec + 5] := Lo(start);
  p^[rec + 6] := Hi(start);
end;

procedure Build;
begin
  FillChar(p^, SIZE, 0);
  p^[0] := Ord('S');
  p^[1] := Ord('B');
  p^[2] := Ord('F');
  p^[3] := Ord('X');
  p^[4] := 2;
  p^[5] := 6;
  SetEntry(0, 1, C_SOUND.SFX_ADPCM4, 121, 8, DATA_START);
  SetEntry(1, C_SOUND.SFX_LAST, C_SOUND.SFX_PCM8, 145, 16, DATA_START);
  SetEntry(2, C_SOUND.MUSIC_TITLE, C_SOUND.SFX_PCM8, 145, 4, DATA_START);
  SetEntry(3, 0, C_SOUND.SFX_PCM8, 145, 4, DATA_START);
  SetEntry(4, 3, 2, 145, 4, DATA_START);
  SetEntry(5, 4, C_SOUND.SFX_PCM8, 145, 17, DATA_START);
end;

begin
  TestKit.Start('TSFXFILE');
  GetMem(p, SIZE);
  Build;
  TestKit.Check(SfxFile.CheckHeader(p, SIZE, count), 'a whole file passes');
  TestKit.CheckEqualsL(6, count, 'its entries are counted');
  TestKit.Check(SfxFile.CheckHeader(p, 48, count), 'entries that end at the file''s end fit');
  TestKit.Check(not SfxFile.CheckHeader(p, 47, count), 'entries past the file''s end do not');
  TestKit.Check(not SfxFile.CheckHeader(p, 5, count), 'a file shorter than the header does not');
  p^[4] := 1;
  TestKit.Check(not SfxFile.CheckHeader(p, SIZE, count), 'another version does not');
  p^[4] := 2;
  p^[3] := Ord('Y');
  TestKit.Check(not SfxFile.CheckHeader(p, SIZE, count), 'another signature does not');
  Build;

  TestKit.Check(SfxFile.GetEntry(p, SIZE, 0, e), 'entry 0 plays');
  TestKit.CheckEqualsL(1, e.tune, 'entry 0: its tune');
  TestKit.CheckEqualsL(C_SOUND.SFX_ADPCM4, e.format, 'entry 0: its format');
  TestKit.CheckEqualsL(121, e.timeConstant, 'entry 0: its time constant');
  TestKit.CheckEqualsL(8, e.len, 'entry 0: its length');
  TestKit.CheckEqualsL(DATA_START, e.start, 'entry 0: its offset');
  TestKit.Check(SfxFile.GetEntry(p, SIZE, 1, e), 'the last effect, to the file''s last byte, plays');
  TestKit.Check(not SfxFile.GetEntry(p, SIZE, 2, e), 'music has no recording');
  TestKit.Check(not SfxFile.GetEntry(p, SIZE, 3, e), 'tune 0 has no recording');
  TestKit.Check(not SfxFile.GetEntry(p, SIZE, 4, e), 'an unknown format does not play');
  TestKit.Check(not SfxFile.GetEntry(p, SIZE, 5, e), 'bytes past the file''s end do not play');
  SetEntry(0, 1, C_SOUND.SFX_PCM8, 121, 0, DATA_START);
  TestKit.Check(not SfxFile.GetEntry(p, SIZE, 0, e), 'no bytes do not play');
  SetEntry(0, 1, C_SOUND.SFX_PCM8, 121, 4, 5);
  TestKit.Check(not SfxFile.GetEntry(p, SIZE, 0, e), 'bytes inside the header do not play');
  SetEntry(0, 1, C_SOUND.SFX_PCM8, 121, $FFFF, $FFF0);
  TestKit.Check(not SfxFile.GetEntry(p, SIZE, 0, e), 'an offset and length that pass 64K do not wrap');
  { an ADPCM entry decodes to 2 * len - 1 samples, which SndDig counts in a Word (#916) }
  SetEntry(0, 1, C_SOUND.SFX_ADPCM4, 121, 1, DATA_START);
  TestKit.Check(SfxFile.GetEntry(p, SIZE, 0, e), 'an ADPCM entry of one byte plays');
  TestKit.CheckEqualsL(1, SfxFile.DecodedLength(e), 'as one sample');
  SetEntry(0, 1, C_SOUND.SFX_ADPCM4, 121, 32768, DATA_START);
  TestKit.Check(SfxFile.GetEntry(p, $FFF0, 0, e), 'one of 32768 bytes plays');
  TestKit.CheckEqualsL(65535, SfxFile.DecodedLength(e), 'as 65535 samples');
  SetEntry(0, 1, C_SOUND.SFX_ADPCM4, 121, 32769, DATA_START);
  TestKit.Check(not SfxFile.GetEntry(p, $FFF0, 0, e), 'one of 32769 bytes does not');
  SetEntry(0, 1, C_SOUND.SFX_PCM8, 121, 32769, DATA_START);
  TestKit.Check(SfxFile.GetEntry(p, $FFF0, 0, e), 'an 8-bit PCM entry of 32769 bytes still plays');
  TestKit.CheckEqualsL(32769, SfxFile.DecodedLength(e), 'its samples are its bytes');
  FreeMem(p, SIZE);
  TestKit.Done;
end.
