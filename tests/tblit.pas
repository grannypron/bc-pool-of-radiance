{ Golden tests for Blit and the picture drivers in each mode (CGA, EGA, Tandy, VGA), over pictures larger than
  TVidPic's: a three-frame picture three cells wide and 16 rows tall, made from fixed pseudo-random DAX bytes with
  colour 0 transparent, is converted, mirrored, remapped (plainly and dithered), recoloured, merged and overlaid, and
  drawn into a view-sized buffer with fills and clipped blits. Each result is checked by a hash of its bytes, recorded
  from the code as it stood at 6ba5b5e, so a refactor that keeps behaviour keeps them. }
{$I COMPILER.INC}
program TBlit;

uses Types, GameDefs, GameVars, Blit, VidOps, {$IFDEF FPC}TpRand, {$ENDIF}
  {$IFNDEF FPC}VidCga, VidEga, VidTdy, {$ENDIF}VidVga, TestKit;

const
  { the test picture: 16 rows of 3 cells, 3 frames, 4 DAX bytes a cell row }
  ROWS = 16;
  CELLS = 3;
  FRAMES = 3;
  DAX_BYTES = ROWS * CELLS * FRAMES * 4;

var
  dax: array[0..DAX_BYTES - 1] of Byte;
  seed: LongInt;

{ The next of a fixed sequence of numbers 0..n-1. }
function Next(n: Word): Word;
begin
  seed := seed * 1103515245 + 12345;
  Next := ((seed shr 16) and $7FFF) mod n;
end;

{ Fill dax from the sequence started at s: a fifth of the pixels colour 0, the rest any colour. }
procedure MakeDax(s: LongInt);
var
  i: Word;
  hi: Byte;
  lo: Byte;
begin
  seed := s;
  for i := 0 to DAX_BYTES - 1 do begin
    hi := 0;
    lo := 0;
    if Next(5) <> 0 then hi := Next(16);
    if Next(5) <> 0 then lo := Next(16);
    dax[i] := (hi shl 4) or lo;
  end;
end;

{ Fold n bytes at p into the hash h: rotate and add, so that bytes that all change alike do not cancel out. }
procedure Hash(var h: LongInt; p: Types.PByteArr; n: Word);
var
  i: Word;
begin
  if n = 0 then Exit;
  for i := 0 to n - 1 do
    h := ((h shl 5) or ((h shr 27) and $1F)) + p^[i] + 1;
end;

{ The hash of pic's frames and mask, all blocks. }
function PicHash(pic: Types.PImgBuf): LongInt;
var
  h: LongInt;
begin
  h := 0;
  while pic <> nil do begin
    Hash(h, Types.PByteArr(@pic^.data), pic^.count * pic^.imgSize);
    if pic^.transp <> nil then
      Hash(h, Types.PByteArr(pic^.transp), Blit.MaskBytes(pic^.count * pic^.imgSize));
    pic := pic^.more;
  end;
  PicHash := h;
end;

{ The hash of the span tables' active rows. }
function SpanHash: LongInt;
var
  h: LongInt;
  r: Word;
begin
  h := 0;
  for r := 0 to SizeOf(GameVars.spanActive) - 1 do
    if GameVars.spanActive[r] <> 0 then begin
      Hash(h, Types.PByteArr(@r), 2);
      Hash(h, Types.PByteArr(@GameVars.spanFirstOfs[r]), 2);
      Hash(h, Types.PByteArr(@GameVars.spanLastOfs[r]), 2);
      Hash(h, Types.PByteArr(@GameVars.spanScreenOfs[r]), 2);
    end;
  SpanHash := h;
end;

{ Mark no row dirty, as FlushView leaves the tables (FlushView itself would write the screen). }
procedure ClearSpans;
begin
  FillChar(GameVars.spanActive, SizeOf(GameVars.spanActive), 0);
  FillChar(GameVars.spanFirstOfs, SizeOf(GameVars.spanFirstOfs), $FF);
  FillChar(GameVars.spanLastOfs, SizeOf(GameVars.spanLastOfs), 0);
end;

{ A converted picture of FRAMES frames from the sequence started at s. }
function MakePic(s: LongInt; frames: Byte): Types.PImgBuf;
var
  pic: Types.PImgBuf;
  i: Byte;
begin
  MakeDax(s);
  Blit.AllocPic(ROWS, CELLS, frames, 1, pic);
  for i := 0 to 7 do
    pic^.map[i] := (((2 * i + 1) mod 4) shl 4) or ((2 * i + 2) mod 4);
  VidOps.ExpandPicFrames(Types.PByteArr(@dax), 0, 0, pic);
  MakePic := pic;
end;

{ The checks in the installed mode, against the hashes expected. }
procedure CheckMode(hExpand, hMirror, hRemap, hDither, hRecolor, hMerge, hOverlay, hView, hSpans, hSave: LongInt);
var
  name: String;
  pic: Types.PImgBuf;
  other: Types.PImgBuf;
  mir: Types.PImgBuf;
  dest: Types.PImgBuf;
  fromT: Types.TColorTab;
  toT: Types.TColorTab;
  map: Types.TColorMap;
  i: Byte;
begin
  name := GameVars.video.name;
  pic := MakePic(1, FRAMES);
  TestKit.CheckEqualsL(hExpand, PicHash(pic), name + ': expand');
  Blit.AllocPic(ROWS, CELLS, 1, 1, mir);
  Blit.MirrorPic(pic, mir);
  TestKit.CheckEqualsL(hMirror, PicHash(mir), name + ': mirror');
  for i := 0 to 15 do begin
    fromT[i] := i;
    toT[i] := i;
  end;
  { a swap and a chain: 3 and 9 trade places, 5 becomes 12 }
  toT[3] := 9;
  toT[9] := 3;
  toT[5] := 12;
  Blit.RemapPic(fromT, toT, -1, False, pic);
  TestKit.CheckEqualsL(hRemap, PicHash(pic), name + ': remap every frame');
  RandSeed := 4242;
  toT[3] := 3;
  toT[9] := 9;
  toT[12] := 1;
  Blit.RemapPic(fromT, toT, 1, True, pic);
  TestKit.CheckEqualsL(hDither, PicHash(pic), name + ': dithered remap of frame 1');
  for i := 0 to 15 do
    toT[i] := 15 - i;
  VidOps.RecolorPic(toT, mir);
  TestKit.CheckEqualsL(hRecolor, PicHash(mir), name + ': recolour');
  other := MakePic(7, 1);
  VidOps.MergePic(mir, other);
  TestKit.CheckEqualsL(hMerge, PicHash(other), name + ': merge');
  Blit.FreePic(other);
  other := MakePic(9, 1);
  VidOps.OverlayPic(mir, other);
  TestKit.CheckEqualsL(hOverlay, PicHash(other), name + ': overlay');
  Blit.FreePic(other);
  { the view: fills and blits, clipped at each edge, with a save-under }
  Blit.AllocPic(168, 21, 1, 0, dest);
  Blit.AllocPic(24, 3, 1, 0, GameVars.iconImageBufferPtr);
  ClearSpans;
  for i := 0 to 7 do
    map[i] := (((2 * i) mod 4) shl 4) or ((2 * i + 1) mod 4);
  Blit.FillPicRect(-2, -5, 30, 200, 7, map, dest);
  Blit.FillPicRect(3, 10, 5, 20, 12, map, dest);
  Blit.FillPicRect(18, 150, 6, 40, 2, map, dest);
  Blit.BlitTileCell(4, 4, 1, 1, pic, dest);
  Blit.BlitTileCell(10, 2, 2, 0, pic, dest);
  Blit.BlitTileClipped(-1, -1, 2, 1, pic, dest);
  Blit.BlitTileClipped(19, 19, 0, 5, pic, dest);
  Blit.BlitTileClipped(8, -1, 1, 4, pic, dest);
  Blit.BlitTileClipped(0, 20, 0, 1, pic, dest);
  Blit.BlitTileClipped(-3, 5, 0, 1, pic, dest);
  Blit.BlitTileClipped(21, 5, 0, 1, pic, dest);
  Blit.BlitTileClipped(12, 30, 0, 1, pic, dest);
  TestKit.CheckEqualsL(hView, PicHash(dest), name + ': the view');
  TestKit.CheckEqualsL(hSpans, SpanHash, name + ': its dirty spans');
  TestKit.CheckEqualsL(hSave, PicHash(GameVars.iconImageBufferPtr), name + ': the save-under');
  ClearSpans;
  Blit.FreePic(GameVars.iconImageBufferPtr);
  Blit.FreePic(dest);
  Blit.FreePic(mir);
  Blit.FreePic(pic);
end;

begin
  TestKit.Start('TBLIT');
{$IFNDEF FPC}
  VidTdy.Install;
  CheckMode(1312691623, -577498055, -1692010776, -1608147257, 573503015, -291232899, -1535596804, -1240945127,
            -1026930244, -402653185);
  VidEga.Install;
  CheckMode(1969444250, 1130247146, 1287423695, 955468360, 1361351795, 1889696382, 40432812, -804427705,
            -1026930244, -1431655766);
  VidCga.Install;
  CheckMode(2013371070, -189610700, 1102751854, 1331543892, -535403827, -1306384808, -1947252339, 453298316,
            -1742296210, -663801968);
{$ENDIF}
  VidVga.Install;
  CheckMode(-1469357773, 1744798254, -1851751357, 828998018, -2103238238, 976113281, -1611165980, 686670744,
            -1722318564, -939524097);
  TestKit.Done;
end.
