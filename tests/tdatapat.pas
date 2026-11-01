{ Tests for DataPat's table: the rules DataBld relies on when it makes the fixes, and script fixes run through the
  interpreter's operand loader. }
{$I COMPILER.INC}
program TDataPat;

uses C_DATA, C_GBVM, C_ECL, C_ITEM, GameVars, DataPat, EclVars, StrUtil, TestKit;

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
  { a place in the new code }
  pos: Word;
  { the part after the new code, and where its bytes start }
  nextPart: Word;
  nextPos: Word;

function SameBlock(a, b: Word): Boolean;
begin
  SameBlock := (DataPat.parts^[a].family = DataPat.parts^[b].family) and
               (DataPat.parts^[a].disk = DataPat.parts^[b].disk) and (DataPat.parts^[a].id = DataPat.parts^[b].id);
end;

function SameFix(a, b: Word): Boolean;
begin
  SameFix := (DataPat.parts^[a].issue = DataPat.parts^[b].issue) and SameBlock(a, b);
end;

{ The GBVM address of offset in a script block: the block's two-byte leader is not loaded (EclMenu). }
function ScriptAddr(offset: Word): Word;
begin
  ScriptAddr := C_GBVM.SCRIPT_FIRST + offset - 2;
end;

{ The block's size once part a is made. }
function SizeAfter(a: Word): LongInt;
begin
  SizeAfter := LongInt(DataPat.parts^[a].size) - DataPat.parts^[a].origLen + DataPat.parts^[a].newLen;
end;

{ The word at patchBytes[pos], low byte first. }
function PatchWord(pos: Word): Word;
begin
  PatchWord := DataPat.patchBytes^[pos] + 256 * Word(DataPat.patchBytes^[pos + 1]);
end;

{ The n-th part of issue fix in the table, with where its bytes start in patchBytes (partPos); 0 when there is none. }
function NthPart(fix, n: Word; var partPos: Word): Word;
var
  p: Word;
  pos: Word;
  seen: Word;
begin
  NthPart := 0;
  partPos := 0;
  pos := 0;
  seen := 0;
  for p := 1 to DataPat.PART_COUNT do begin
    if DataPat.parts^[p].issue = fix then begin
      Inc(seen);
      if seen = n then begin
        NthPart := p;
        partPos := pos;
      end;
    end;
    Inc(pos, DataPat.parts^[p].origLen + DataPat.parts^[p].newLen);
  end;
end;

{ Put the new bytes of part p, which start at pos in patchBytes, in the script buffer at the address they run at. }
procedure LoadPart(p, pos: Word);
begin
  Move(DataPat.patchBytes^[pos + DataPat.parts^[p].origLen],
       GameVars.zone3^[ScriptAddr(DataPat.parts^[p].offset)], DataPat.parts^[p].newLen);
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
    with DataPat.parts^[p] do
      if (issue = fix) and (family = C_DATA.FAMILY_ECL) and (disk = onDisk) and (id = block) then
        if origLen = 0 then begin
          codePart := p;
          codePos := pos;
        end else if origLen = 2 then begin
          jumpPart := p;
          jumpPos := pos;
        end;
    Inc(pos, DataPat.parts^[p].origLen + DataPat.parts^[p].newLen);
  end;
  FindJump := (jumpPart > 0) and (codePart > 0);
  TestKit.Check((jumpPart > 0) and (codePart > 0), what + ' has its jump and its new code');
  if (jumpPart > 0) and (codePart > 0) then begin
    codeAddr := ScriptAddr(DataPat.parts^[codePart].offset);
    TestKit.CheckEqualsL(codeAddr, PatchWord(jumpPos + 2), what + ': the jump goes to the new code');
  end;
end;

begin
  TestKit.Start('TDATAPAT');
  TestKit.Check(DataPat.LoadTable, 'the table gives PART_COUNT parts and BYTE_COUNT bytes');
  total := 0;
  for p := 1 to DataPat.PART_COUNT do
    Inc(total, DataPat.parts^[p].origLen + DataPat.parts^[p].newLen);
  TestKit.CheckEqualsL(DataPat.BYTE_COUNT, total, 'the parts use every byte of patchBytes');

  familiesOk := True;
  offsetsOk := True;
  sizesOk := True;
  runsOk := True;
  for p := 1 to DataPat.PART_COUNT do begin
    with DataPat.parts^[p] do begin
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
        ok := SizeAfter(q) = DataPat.parts^[p].size;
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

  GetMem(GameVars.zone2, SizeOf(GameVars.zone2^));
  GetMem(GameVars.zone3, SizeOf(GameVars.zone3^));
  GetMem(GameVars.gbStrings, SizeOf(GameVars.gbStrings^));
  FillChar(GameVars.zone2^, SizeOf(GameVars.zone2^), 0);
  FillChar(GameVars.zone3^, SizeOf(GameVars.zone3^), 0);
  { #864: the ninth posted proclamation's ON GOSUB entry goes to the new code, which loads "CCXIV." }
  if FindJump(864, 3, 0, '#864') then begin
    Move(DataPat.patchBytes^[codePos], GameVars.zone3^[codeAddr], DataPat.parts^[codePart].newLen);
    TestKit.CheckEqualsL($09, GameVars.zone3^[codeAddr], '#864: the new code is a SAVE');
    GameVars.eclIp := codeAddr;
    EclVars.LoadEclVars(2);
    TestKit.CheckEqualsS('CCXIV.', GameVars.gbStrings^[1], '#864: the SAVE loads CCXIV.');
    TestKit.CheckEqualsL($13, GameVars.zone3^[GameVars.eclIp], '#864: then RETURN');
    TestKit.CheckEqualsL(codeAddr + DataPat.parts^[codePart].newLen - 1, GameVars.eclIp, '#864: the RETURN ends it');
  end;

  { #868: the fortune teller's murder goes through new code that marks it, then on to the GOSUB's own target; New
    Phlan's event 20 goes to the sage's code, whose first GOTO sends other squares where the entry went }
  if FindJump(868, 2, 20, '#868 Slums') then begin
    TestKit.CheckEqualsL(C_GBVM.GYPSY_KILLED, PatchWord(codePos + 4), '#868 Slums: the SAVE is to GYPSY_KILLED');
    TestKit.CheckEqualsL($01, DataPat.patchBytes^[codePos + 6], '#868 Slums: then a GOTO');
    TestKit.CheckEqualsL(PatchWord(jumpPos), PatchWord(codePos + 8), '#868 Slums: to where the GOSUB went');
  end;
  if FindJump(868, 3, 0, '#868 New Phlan') then begin
    TestKit.CheckEqualsL($01, DataPat.patchBytes^[codePos + 12], '#868 New Phlan: other squares GOTO');
    TestKit.CheckEqualsL(PatchWord(jumpPos), PatchWord(codePos + 14), '#868 New Phlan: where event 20 went');
    TestKit.CheckEqualsL(C_GBVM.REWARD_SLUMS, PatchWord(codePos + 22), '#868 New Phlan: the Slums cleared');
    TestKit.CheckEqualsL(C_GBVM.QUEST_DONE, DataPat.patchBytes^[codePos + 25], '#868 New Phlan: as QUEST_DONE');
    TestKit.CheckEqualsL(C_GBVM.GYPSY_KILLED, PatchWord(codePos + 33), '#868 New Phlan: the fortune teller alive');
    { both GOTOs to the empty shop land on its PRINTCLEAR, inside the new code }
    pos := PatchWord(codePos + 29) - codeAddr;
    TestKit.CheckEqualsL(pos, PatchWord(codePos + 40) - codeAddr, '#868 New Phlan: one empty shop');
    TestKit.Check(pos < DataPat.parts^[codePart].newLen, '#868 New Phlan: the empty shop is in the new code');
    if pos + 22 < DataPat.parts^[codePart].newLen then begin
      TestKit.CheckEqualsL($12, DataPat.patchBytes^[codePos + pos], '#868 New Phlan: the empty shop is a PRINTCLEAR');
      { then the crystal ball for a murdered fortune teller: PRINTCLEAR's 3 bytes and its text, then a COMPARE }
      pos := pos + 3 + DataPat.patchBytes^[codePos + pos + 2];
      TestKit.CheckEqualsL(C_GBVM.GYPSY_KILLED, PatchWord(codePos + pos + 2),
                           '#868 New Phlan: the crystal ball for the murdered fortune teller');
    end;
  end;
  { #1096: SANCTIFY goes to new code that uses up holy water, or else a holy symbol, before it goes where SANCTIFY went;
    an IF steps over a USE UP ITEM whole }
  if FindJump(1096, 4, 10, '#1096') then begin
    TestKit.CheckEqualsL(C_ECL.USE_UP_ITEM, DataPat.patchBytes^[codePos], '#1096: the new code uses up an item');
    TestKit.CheckEqualsL(C_ITEM.HOLY_WATER_VIAL, DataPat.patchBytes^[codePos + 2], '#1096: holy water first');
    TestKit.CheckEqualsL(PatchWord(jumpPos), PatchWord(codePos + 6), '#1096: and with it on to the sanctifying');
    TestKit.CheckEqualsL(C_ECL.USE_UP_ITEM, DataPat.patchBytes^[codePos + 8], '#1096: then uses up another');
    TestKit.CheckEqualsL(C_ITEM.FIND_HOLY_SYMBOL, DataPat.patchBytes^[codePos + 10], '#1096: a holy symbol');
    TestKit.CheckEqualsL(PatchWord(jumpPos), PatchWord(codePos + 14), '#1096: and with it on to the sanctifying');
    Move(DataPat.patchBytes^[codePos], GameVars.zone3^[codeAddr], DataPat.parts^[codePart].newLen);
    GameVars.eclIp := codeAddr;
    EclVars.SkipEclCmd;
    TestKit.CheckEqualsL(codeAddr + 3, GameVars.eclIp, '#1096: skipping USE UP ITEM steps over its operand');
  end;

  { #1113 and #1117: the mage's join goes to new code that names the new member ODRAN (a string SAVE to the current
    character's name) and, by #1117, takes his picture down before it exits }
  codePart := NthPart(1113, 2, codePos);
  jumpPart := NthPart(1113, 1, jumpPos);
  nextPart := NthPart(1117, 1, nextPos);
  TestKit.Check((codePart > 0) and (jumpPart > 0) and (nextPart > 0), '#1113 and #1117 have their parts');
  if (codePart > 0) and (jumpPart > 0) and (nextPart > 0) then begin
    codeAddr := ScriptAddr(DataPat.parts^[codePart].offset);
    pos := jumpPos + DataPat.parts^[jumpPart].origLen;
    TestKit.CheckEqualsL(C_ECL.OP_GOTO, DataPat.patchBytes^[pos], '#1113: the join goes on by a GOTO');
    TestKit.CheckEqualsL(codeAddr, PatchWord(pos + 2), '#1113: to the new code');
    LoadPart(codePart, codePos);
    LoadPart(nextPart, nextPos);
    TestKit.CheckEqualsL(C_ECL.SAVE, GameVars.zone3^[codeAddr], '#1113: the new code is a SAVE');
    GameVars.eclIp := codeAddr;
    EclVars.LoadEclVars(2);
    TestKit.CheckEqualsS('ODRAN', GameVars.gbStrings^[1], '#1113: of ODRAN');
    TestKit.CheckEqualsL(C_GBVM.CHAR_NAME,
                         EclVars.CombineBytesToWord(GameVars.varLo[2], GameVars.varHi[2]), '#1113: to the name');
    TestKit.CheckEqualsL(DataPat.parts^[codePart].offset + DataPat.parts^[codePart].newLen - 1,
                         DataPat.parts^[nextPart].offset, '#1117: replaces the new code''s last byte');
    pos := ScriptAddr(DataPat.parts^[nextPart].offset);
    TestKit.CheckEqualsL(C_ECL.PICTURE, GameVars.zone3^[pos], '#1117: with a PICTURE');
    TestKit.CheckEqualsL(255, GameVars.zone3^[pos + 2], '#1117: of none, which takes his picture down');
    TestKit.CheckEqualsL(C_ECL.OP_EXIT, GameVars.zone3^[pos + 3], '#1117: then EXIT');
  end;
  { #1091, #1158: event 22 goes to new code that sends every square but (11,12) on to the arms shops, and there fills
    the magic shop's stock with PROGRAM 11 (EclVm.PROG_MAGIC_SHOP) and enters the shop: [$6E6C] = 1, then COMBAT }
  if FindJump(1091, 3, 0, '#1091') then begin
    TestKit.CheckEqualsL(11, DataPat.patchBytes^[codePos + 5], '#1091: the magic shop is at x 11');
    TestKit.CheckEqualsL(12, DataPat.patchBytes^[codePos + 10], '#1091: and y 12');
    TestKit.CheckEqualsL(C_ECL.OP_GOTO, DataPat.patchBytes^[codePos + 12], '#1091: other squares GOTO');
    TestKit.CheckEqualsL(PatchWord(jumpPos), PatchWord(codePos + 14), '#1091: where event 22 went');
    pos := DataPat.parts^[codePart].newLen - 14;
    TestKit.CheckEqualsL(C_ECL.OP_PROGRAM, DataPat.patchBytes^[codePos + pos], '#1091: a PROGRAM');
    TestKit.CheckEqualsL(11, DataPat.patchBytes^[codePos + pos + 2], '#1091: of the magic shop');
    TestKit.CheckEqualsL(C_ECL.SAVE, DataPat.patchBytes^[codePos + pos + 3], '#1091: then a SAVE');
    TestKit.CheckEqualsL(1, DataPat.patchBytes^[codePos + pos + 5], '#1091: of 1');
    TestKit.CheckEqualsL(C_GBVM.ENTER_SHOP, PatchWord(codePos + pos + 7), '#1091: to ENTER_SHOP');
    TestKit.CheckEqualsL(C_ECL.OP_COMBAT, DataPat.patchBytes^[codePos + pos + 9], '#1091: then COMBAT');
  end;
  DataPat.FreeTable;
  TestKit.Done;
end.
