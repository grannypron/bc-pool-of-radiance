{ Tests for DataPat's table: the rules DataBld relies on when it makes the fixes, and a script fix run through the
  interpreter's operand loader. }
{$I COMPILER.INC}
program TDataPat;

uses C_DATA, C_GBVM, GameVars, DataPat, EclVars, StrUtil, TestKit;

var
  p: Word;
  q: Word;
  total: LongInt;
  ok: Boolean;
  sizesOk: Boolean;
  runsOk: Boolean;
  offsetsOk: Boolean;
  familiesOk: Boolean;
  { #864's two parts, and where each one's bytes start in patchBytes }
  jumpPart: Word;
  codePart: Word;
  jumpPos: Word;
  codePos: Word;
  { the address #864's new code runs at }
  codeAddr: Word;
  pos: Word;

function SameBlock(a, b: Word): Boolean;
begin
  SameBlock := (DataPat.parts[a].family = DataPat.parts[b].family) and (DataPat.parts[a].disk = DataPat.parts[b].disk)
               and (DataPat.parts[a].id = DataPat.parts[b].id);
end;

function SameFix(a, b: Word): Boolean;
begin
  SameFix := (DataPat.parts[a].issue = DataPat.parts[b].issue) and SameBlock(a, b);
end;

{ The GBVM address of offset in a script block: the block's two-byte leader is not loaded (EclMenu). }
function ScriptAddr(offset: Word): Word;
begin
  ScriptAddr := C_GBVM.SCRIPT_FIRST + offset - 2;
end;

{ The block's size once part a is made. }
function SizeAfter(a: Word): LongInt;
begin
  SizeAfter := LongInt(DataPat.parts[a].size) - DataPat.parts[a].origLen + DataPat.parts[a].newLen;
end;

begin
  TestKit.Start('TDATAPAT');
  total := 0;
  for p := 1 to DataPat.PART_COUNT do
    Inc(total, DataPat.parts[p].origLen + DataPat.parts[p].newLen);
  TestKit.CheckEqualsL(DataPat.BYTE_COUNT, total, 'the parts use every byte of patchBytes');

  familiesOk := True;
  offsetsOk := True;
  sizesOk := True;
  runsOk := True;
  for p := 1 to DataPat.PART_COUNT do begin
    with DataPat.parts[p] do begin
      if not (family in [C_DATA.FAMILY_ECL, C_DATA.FAMILY_GEO, C_DATA.FAMILY_ITEM, C_DATA.FAMILY_MONCHA,
                         C_DATA.FAMILY_MONITM]) then begin
        familiesOk := False;
        TestKit.Check(False, 'part ' + StrUtil.NumStr(p) + ': an unknown family');
      end;
      if LongInt(offset) + origLen > size then begin
        offsetsOk := False;
        TestKit.Check(False, 'part ' + StrUtil.NumStr(p) + ': the original bytes run past the block');
      end;
    end;
    { the size is the block's as the last part before it on the same block leaves it }
    ok := True;
    for q := 1 to p - 1 do
      if SameBlock(q, p) then
        ok := SizeAfter(q) = DataPat.parts[p].size;
    if not ok then begin
      sizesOk := False;
      TestKit.Check(False, 'part ' + StrUtil.NumStr(p) + ': the size is not the block''s after the parts before it');
    end;
    { a fix's parts are one run: once another part comes between, the fix does not go on }
    ok := True;
    if (p > 1) and not SameFix(p - 1, p) then
      for q := 1 to p - 2 do
        if SameFix(q, p) then
          ok := False;
    if not ok then begin
      runsOk := False;
      TestKit.Check(False, 'part ' + StrUtil.NumStr(p) + ': its fix''s parts are not together');
    end;
  end;
  TestKit.Check(familiesOk, 'every part names a family DataBld builds');
  TestKit.Check(offsetsOk, 'every part''s original bytes lie inside the block');
  TestKit.Check(sizesOk, 'every part''s size is the block''s after the fixes before it');
  TestKit.Check(runsOk, 'every fix''s parts are together');

  { #864: the ninth posted proclamation's ON GOSUB entry goes to the new code, which loads "CCXIV." }
  jumpPart := 0;
  codePart := 0;
  pos := 0;
  for p := 1 to DataPat.PART_COUNT do begin
    if DataPat.parts[p].issue = 864 then
      if DataPat.parts[p].origLen = 0 then begin
        codePart := p;
        codePos := pos;
      end else begin
        jumpPart := p;
        jumpPos := pos;
      end;
    Inc(pos, DataPat.parts[p].origLen + DataPat.parts[p].newLen);
  end;
  TestKit.Check((jumpPart > 0) and (codePart > 0), '#864 has its jump and its new code');
  if (jumpPart > 0) and (codePart > 0) then begin
    codeAddr := ScriptAddr(DataPat.parts[codePart].offset);
    TestKit.CheckEqualsL(codeAddr, DataPat.patchBytes[jumpPos + 2] + 256 * Word(DataPat.patchBytes[jumpPos + 3]),
                         '#864: the ninth entry goes to the new code');
    GetMem(GameVars.zone2, SizeOf(GameVars.zone2^));
    GetMem(GameVars.zone3, SizeOf(GameVars.zone3^));
    GetMem(GameVars.gbStrings, SizeOf(GameVars.gbStrings^));
    FillChar(GameVars.zone2^, SizeOf(GameVars.zone2^), 0);
    FillChar(GameVars.zone3^, SizeOf(GameVars.zone3^), 0);
    Move(DataPat.patchBytes[codePos], GameVars.zone3^[codeAddr], DataPat.parts[codePart].newLen);
    TestKit.CheckEqualsL($09, GameVars.zone3^[codeAddr], '#864: the new code is a SAVE');
    GameVars.eclIp := codeAddr;
    EclVars.LoadEclVars(2);
    TestKit.CheckEqualsS('CCXIV.', GameVars.gbStrings^[1], '#864: the SAVE loads CCXIV.');
    TestKit.CheckEqualsL($13, GameVars.zone3^[GameVars.eclIp], '#864: then RETURN');
    TestKit.CheckEqualsL(codeAddr + DataPat.parts[codePart].newLen - 1, GameVars.eclIp, '#864: the RETURN ends it');
  end;
  TestKit.Done;
end.
