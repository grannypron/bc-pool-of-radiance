{ Tests the demo's hooks into the game (#1109): GameIo.DemoEnding; the C64 cells its script reads and writes (the key
  count it ends on, the game speed that is its text delay); the Bestiary learning nothing from it; and its battle's end
  in PostCbt.PostCombat, which takes the monsters away and keeps the result for the script, with no experience and
  without taking the party of NPCs for a destroyed one; and the check of DEMO.DAX before the demo starts
  (DataArc.BlockRawSize, Demo.Complete), on archives written here, whole, short of a block or cut short. }
{$I COMPILER.INC}
program TDemo;

uses Types, GameVars, GameIo, C_GBVM, C_STATUS, C_NPC, C_MONEY, C_DEMO, EclVars, Bestiary, PostCbt, DataArc,
  Demo, TestKit;

const
  ARC = 'TDEMO.DAX';
  { the demo's blocks: the script, the four records, their items }
  BLOCKS = 9;

var
  pc1, pc2, orc: Types.PCharRecord;
  ids: array[1..BLOCKS] of Byte;
  sizes: array[1..BLOCKS] of Word;
  i: Byte;
  f: file;

{ Write ARC with the first count of ids and sizes as blocks of zeros, stored unpacked (a run of 127 bytes a control
  byte), and cut lastShort bytes off its end. }
procedure WriteArchive(count: Byte; lastShort: Word);
var
  f: file;
  e: DataArc.TDirEntry;
  dirSize: Word;
  offset: LongInt;
  k: Byte;
  w: Word;
  n: Word;
  chunk: Word;
  buf: array[0..127] of Byte;
  packedSize: Word;
begin
  FillChar(buf, SizeOf(buf), 0);
  Assign(f, ARC);
  Rewrite(f, 1);
  dirSize := count * SizeOf(DataArc.TDirEntry);
  BlockWrite(f, dirSize, SizeOf(dirSize));
  offset := 0;
  for k := 1 to count do begin
    packedSize := sizes[k] + (sizes[k] + 126) div 127;
    e.id := ids[k];
    e.offset := offset;
    e.rawSize := sizes[k];
    e.packedSize := packedSize;
    BlockWrite(f, e, SizeOf(e));
    Inc(offset, packedSize);
  end;
  for k := 1 to count do begin
    w := sizes[k];
    while w > 0 do begin
      chunk := w;
      if chunk > 127 then chunk := 127;
      buf[0] := chunk - 1;
      n := chunk + 1;
      if (k = count) and (w = chunk) and (lastShort > 0) then
        n := n - lastShort;
      BlockWrite(f, buf, n);
      Dec(w, chunk);
    end;
  end;
  Close(f);
end;

function NewCreature(name: String; monster: Boolean): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  GetMem(p, SizeOf(Types.TCharRecord));
  FillChar(p^, SizeOf(Types.TCharRecord), 0);
  p^.name := name;
  p^.enabled := 1;
  p^.status := C_STATUS.OKAY;
  p^.hpMax := 10;
  p^.hpCur := 10;
  GetMem(p^.combatAddr, SizeOf(Types.TCombatRec));
  FillChar(p^.combatAddr^, SizeOf(Types.TCombatRec), 0);
  if monster then begin
    p^.combatAddr^.notPcNpc := 1;
    p^.hostile := 1;
  end else
    p^.npc := C_NPC.FLAG or 50;
  NewCreature := p;
end;

{ The demo's party, two NPCs, and an orc, standing (orcUp) or out of the fight. }
procedure Fight(orcUp: Boolean);
begin
  pc1 := NewCreature('RESTAL', False);
  pc2 := NewCreature('DIANE', False);
  orc := NewCreature('ORC', True);
  orc^.xpAward := 100;
  orc^.coins[C_MONEY.GOLD] := 50;
  if not orcUp then begin
    orc^.enabled := 0;
    orc^.status := C_STATUS.DEAD_STATUS;
  end;
  GameVars.creatureList := pc1;
  pc1^.nextCharAddr := pc2;
  pc2^.nextCharAddr := orc;
  GameVars.zone1^[C_GBVM.PARTY_SIZE] := 2;
end;

function ListLength: Integer;
var
  p: Types.PCharRecord;
  n: Integer;
begin
  n := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    Inc(n);
    p := p^.nextCharAddr;
  end;
  ListLength := n;
end;

begin
  TestKit.Start('TDEMO');
  GetMem(GameVars.zone0, SizeOf(GameVars.zone0^));
  GetMem(GameVars.zone1, SizeOf(GameVars.zone1^));
  FillChar(GameVars.zone0^, SizeOf(GameVars.zone0^), 0);
  FillChar(GameVars.zone1^, SizeOf(GameVars.zone1^), 0);

  { the end of the demo: only in it, and once set; no key is pressed here }
  GameVars.demoMode := False;
  GameVars.demoAbort := True;
  TestKit.Check(not GameIo.DemoEnding, 'nothing ends outside the demo');
  GameVars.demoMode := True;
  GameVars.demoAbort := False;
  TestKit.Check(not GameIo.DemoEnding, 'the demo goes on without a key');
  GameVars.demoAbort := True;
  TestKit.Check(GameIo.DemoEnding, 'and ends once a key has ended it');

  { the C64's key count, which the script tests after every pause }
  GameVars.demoMode := False;
  TestKit.CheckEqualsL(0, EclVars.ReadGbvm(C_GBVM.KEY_COUNT), 'KEY_COUNT reads 0 outside the demo');
  GameVars.demoMode := True;
  GameVars.demoAbort := False;
  TestKit.CheckEqualsL(0, EclVars.ReadGbvm(C_GBVM.KEY_COUNT), 'and in the demo with no key');
  GameVars.demoAbort := True;
  TestKit.CheckEqualsL(1, EclVars.ReadGbvm(C_GBVM.KEY_COUNT), 'and 1 once a key ends it');

  { the game speed: the demo's text delay, and only the demo's }
  GameVars.gameDelay := 5;
  GameVars.demoMode := False;
  EclVars.WriteGbvm(C_GBVM.GAME_SPEED, 0);
  TestKit.CheckEqualsL(5, GameVars.gameDelay, 'a script''s GAME_SPEED leaves the text delay outside the demo');
  GameVars.demoMode := True;
  EclVars.WriteGbvm(C_GBVM.GAME_SPEED, 0);
  TestKit.CheckEqualsL(0, GameVars.gameDelay, 'and sets it in the demo');
  EclVars.WriteGbvm(C_GBVM.GAME_SPEED, 2);
  TestKit.CheckEqualsL(2, GameVars.gameDelay, 'to whatever the script writes');

  { the Bestiary lives outside the saves: the demo's monsters teach it nothing }
  GameVars.creatureList := nil;
  orc := NewCreature('ORC', True);
  GameVars.demoMode := True;
  Bestiary.Met(orc);
  Bestiary.Killed(orc);
  TestKit.CheckEqualsL(0, Bestiary.Count, 'the demo''s orc is neither met nor killed');
  GameVars.demoMode := False;
  Bestiary.Met(orc);
  TestKit.CheckEqualsL(1, Bestiary.Count, 'outside the demo it is met');

  { the battle won: the orc goes, no experience, and the NPCs are no destroyed party }
  GameVars.demoMode := True;
  GameVars.demoAbort := False;
  GameVars.partyDefeated := False;
  Fight(False);
  PostCbt.PostCombat;
  TestKit.CheckEqualsL(2, ListLength, 'the orc is taken away');
  TestKit.CheckEqualsL(0, GameVars.zone1^[C_GBVM.COMBAT_RESULT], 'COMBAT_RESULT 0: the party won');
  TestKit.Check(not GameVars.partyDefeated, 'a party of NPCs is not taken for destroyed');
  TestKit.Check((pc1^.experience = 0) and (pc2^.experience = 0), 'and earns no experience');
  TestKit.CheckEqualsL(0, GameVars.treasureMoney[C_MONEY.GOLD], 'or treasure');

  { a battle cut short, the orc still standing: not won, and the orc goes all the same }
  Fight(True);
  PostCbt.PostCombat;
  TestKit.CheckEqualsL(2, ListLength, 'the standing orc is taken away too');
  TestKit.CheckEqualsL(1, GameVars.zone1^[C_GBVM.COMBAT_RESULT], 'COMBAT_RESULT 1: the party did not win');

  { DEMO.DAX checked before the demo starts }
  ids[1] := C_DEMO.SCRIPT_BLOCK;
  sizes[1] := 1300;
  for i := 0 to 3 do begin
    ids[2 + i] := C_DEMO.FIRST_NPC + i;
    sizes[2 + i] := 285;
    ids[6 + i] := C_DEMO.FIRST_NPC + i + C_DEMO.ITEMS_OFFSET;
    sizes[6 + i] := 63;
  end;
  WriteArchive(BLOCKS, 0);
  TestKit.CheckEqualsL(1300, DataArc.BlockRawSize(ARC, C_DEMO.SCRIPT_BLOCK), 'the script''s size');
  TestKit.CheckEqualsL(-1, DataArc.BlockRawSize(ARC, 7), 'a block not listed');
  TestKit.Check(Demo.Complete(ARC), 'a whole archive is complete');
  WriteArchive(BLOCKS - 1, 0);
  TestKit.Check(not Demo.Complete(ARC), 'one without the last character''s items is not');
  sizes[3] := 200;
  WriteArchive(BLOCKS, 0);
  TestKit.Check(not Demo.Complete(ARC), 'nor one with a record too short');
  sizes[3] := 285;
  WriteArchive(BLOCKS, 10);
  TestKit.CheckEqualsL(-1, DataArc.BlockRawSize(ARC, C_DEMO.SCRIPT_BLOCK), 'a file cut short reads as no archive');
  TestKit.Check(not Demo.Complete(ARC), 'and is not complete');
  TestKit.Check(not Demo.Complete('NOSUCH.DAX'), 'nor is a file that is not there');
  Assign(f, ARC);
  Erase(f);
  TestKit.Done;
end.
