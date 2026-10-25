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
  { a script fix's two parts, and where each one's bytes start in patchBytes (FindJump) }
  jumpPart: Word;
  codePart: Word;
  jumpPos: Word;
  codePos: Word;
  { the address the new code runs at }
  codeAddr: Word;

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

{ The word at patchBytes[pos], low byte first. }
function PatchWord(pos: Word): Word;
begin
  PatchWord := DataPat.patchBytes[pos] + 256 * Word(DataPat.patchBytes[pos + 1]);
end;

{ Issue fix's change to script block on ECL disk onDisk that sends a 2-byte address to new code at the script's end:
  jumpPart the part that changes the address, codePart the new code, each with where its bytes start in patchBytes
  (jumpPos, codePos), and codeAddr the address the code runs at. False, with a failed check named by what, when the
  fix has not both. }
function FindJump(fix: Word; onDisk, block: Byte; what: string): Boolean;
var
  p: Word;
  pos: Word;
begin
  jumpPart := 0;
  codePart := 0;
  pos := 0;
  for p := 1 to DataPat.PART_COUNT do begin
    with DataPat.parts[p] do
      if (issue = fix) and (family = C_DATA.FAMILY_ECL) and (disk = onDisk) and (id = block) then
        if origLen = 0 then begin
          codePart := p;
          codePos := pos;
        end else if origLen = 2 then begin
          jumpPart := p;
          jumpPos := pos;
        end;
    Inc(pos, DataPat.parts[p].origLen + DataPat.parts[p].newLen);
  end;
  FindJump := (jumpPart > 0) and (codePart > 0);
  TestKit.Check((jumpPart > 0) and (codePart > 0), what + ' has its jump and its new code');
  if (jumpPart > 0) and (codePart > 0) then begin
    codeAddr := ScriptAddr(DataPat.parts[codePart].offset);
    TestKit.CheckEqualsL(codeAddr, PatchWord(jumpPos + 2), what + ': the jump goes to the new code');
  end;
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
  if FindJump(864, 3, 0, '#864') then begin
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

  { #868: the fortune teller's murder goes through new code that marks it, then on to the GOSUB's own target; New
    Phlan's event 20 goes to the sage's code, whose first GOTO sends other squares where the entry went }
  if FindJump(868, 2, 20, '#868 Slums') then begin
    TestKit.CheckEqualsL(C_GBVM.GYPSY_KILLED, PatchWord(codePos + 4), '#868 Slums: the SAVE is to GYPSY_KILLED');
    TestKit.CheckEqualsL($01, DataPat.patchBytes[codePos + 6], '#868 Slums: then a GOTO');
    TestKit.CheckEqualsL(PatchWord(jumpPos), PatchWord(codePos + 8), '#868 Slums: to where the GOSUB went');
  end;
  if FindJump(868, 3, 0, '#868 New Phlan') then begin
    TestKit.CheckEqualsL($01, DataPat.patchBytes[codePos + 12], '#868 New Phlan: other squares GOTO');
    TestKit.CheckEqualsL(PatchWord(jumpPos), PatchWord(codePos + 14), '#868 New Phlan: where event 20 went');
    TestKit.CheckEqualsL(C_GBVM.REWARD_SLUMS, PatchWord(codePos + 18), '#868 New Phlan: the Slums cleared');
    TestKit.CheckEqualsL(C_GBVM.QUEST_DONE, DataPat.patchBytes[codePos + 21], '#868 New Phlan: as QUEST_DONE');
    TestKit.CheckEqualsL(C_GBVM.GYPSY_KILLED, PatchWord(codePos + 26), '#868 New Phlan: the fortune teller alive');
  end;
  TestKit.Done;
end.
