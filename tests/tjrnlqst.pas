{ Tests for JrnlQst: the Journal's quests (#851), their labels and proclamations, and when the game memory the scripts
  keep the missions in makes one given and done. }
{$I COMPILER.INC}
program TJrnlQst;

uses GameVars, C_GBVM, C_JRNL, JrnlList, JrnlQst, StrUtil, TestKit;

var
  n: Integer;
  given: Integer;
  fits: Boolean;
  labelled: Boolean;
  where: String;

{ Clear the game memory's zone 0: a new game. }
procedure NewGame;
begin
  FillChar(GameVars.zone0^, SizeOf(GameVars.zone0^), 0);
end;

{ Set a word of zone 0. }
procedure Put(address, value: Word);
begin
  GameVars.zone0^.words[address] := value;
end;

{ How many quests are given. }
function GivenCount: Integer;
var
  k: Integer;
  c: Integer;
begin
  c := 0;
  for k := 1 to C_JRNL.QUEST_COUNT do
    if JrnlQst.IsGiven(k) then
      Inc(c);
  GivenCount := c;
end;

begin
  TestKit.Start('TJRNLQST');
  GetMem(GameVars.zone0, SizeOf(GameVars.zone0^));
  NewGame;

  { every quest has a label that fits the page, and a proclamation's quest starts with its numeral }
  fits := True;
  labelled := True;
  where := '';
  for n := 1 to C_JRNL.QUEST_COUNT do begin
    if (JrnlQst.QuestLabel(n) = '') or (Length(JrnlQst.QuestLabel(n)) > C_JRNL.QUEST_WIDTH) then begin
      fits := False;
      where := where + ' ' + StrUtil.NumStr(n);
    end;
    if (JrnlQst.QuestItem(n) <> 0)
       and (Pos(JrnlList.EntryLabel(JrnlQst.QuestItem(n)) + ': ', JrnlQst.QuestLabel(n)) <> 1) then
      labelled := False;
  end;
  TestKit.Check(fits, 'every quest''s label fits;' + where);
  TestKit.Check(labelled, 'a proclamation''s quest starts with its numeral');
  TestKit.CheckEqualsS('CI: CLEAR SOKAL KEEP', JrnlQst.QuestLabel(7), 'Sokal Keep''s label');
  TestKit.CheckEqualsS('LIX: CLEAR THE SLUMS', JrnlQst.QuestLabel(1), 'the Slums'' label');
  TestKit.CheckEqualsL(1, JrnlQst.QuestItem(1), 'the Slums come from LIX, item 1');
  TestKit.CheckEqualsL(18, JrnlQst.QuestItem(15), 'the nomads from CCXIV, item 18');
  TestKit.CheckEqualsL(0, JrnlQst.QuestItem(16), 'the auction from no proclamation');
  TestKit.CheckEqualsS('', JrnlQst.QuestLabel(0), 'no label before the list');
  TestKit.CheckEqualsS('', JrnlQst.QuestLabel(C_JRNL.QUEST_COUNT + 1), 'nor past it');
  TestKit.CheckEqualsL(4, JrnlList.ProclamationItem(101), 'CI is item 4');
  TestKit.CheckEqualsL(0, JrnlList.ProclamationItem(100), 'there is no proclamation C');

  { a new game: LIX's six blocks only, none done }
  given := GivenCount;
  TestKit.CheckEqualsL(6, given, 'a new game gives LIX''s six blocks');
  TestKit.Check(JrnlQst.IsPosted(64) and JrnlQst.IsPosted(78) and JrnlQst.IsPosted(109), 'LXIV, LXXVIII, CIX posted');
  TestKit.Check(not JrnlQst.IsPosted(101), 'CI is not posted yet');
  TestKit.Check(not JrnlQst.IsPosted(120) and not JrnlQst.IsPosted(156), 'CXX and CLVI are never posted');
  TestKit.Check(not JrnlQst.IsDone(1), 'the Slums are not done');

  { the clerk's rewards post the rest, one a reward }
  Put(C_GBVM.COUNCIL_REWARDS, 1);
  TestKit.Check(JrnlQst.IsGiven(7), 'one reward posts CI, Sokal Keep');
  TestKit.Check(not JrnlQst.IsGiven(9), 'but not CXXVI');
  Put(C_GBVM.COUNCIL_REWARDS, 9);
  TestKit.Check(JrnlQst.IsGiven(15), 'nine post CCXIV, the nomads (SSI wrote CXIV)');
  TestKit.CheckEqualsL(15, GivenCount, 'nine post every proclamation''s quest');
  NewGame;

  { done: a reward cell at QUEST_DONE (the script) or $FF (paid) }
  Put(C_GBVM.REWARD_SOKAL, C_GBVM.QUEST_DONE);
  TestKit.Check(JrnlQst.IsDone(7), 'Sokal Keep done at QUEST_DONE');
  TestKit.Check(JrnlQst.IsGiven(7), 'and given, done before CI was posted');
  Put(C_GBVM.REWARD_SOKAL, $FF);
  TestKit.Check(JrnlQst.IsDone(7), 'and once paid');
  Put(C_GBVM.REWARD_SLUMS, $18);
  TestKit.Check(not JrnlQst.IsDone(1), 'the Slums'' count of clear points is not done');
  Put(C_GBVM.REWARD_SLUMS, C_GBVM.QUEST_DONE);
  TestKit.Check(JrnlQst.IsDone(1), 'the Slums cleared');

  { the library: both fights }
  Put(C_GBVM.LIBRARY_FIGHTS, C_GBVM.LIBRARY_SPECTRE or $80);
  TestKit.Check(not JrnlQst.IsDone(5), 'the library with the spectre beaten only');
  Put(C_GBVM.LIBRARY_FIGHTS, C_GBVM.LIBRARY_CLEARED or $03);
  TestKit.Check(JrnlQst.IsDone(5), 'the library with both beaten');

  { the tomes: all five }
  for n := C_GBVM.REWARD_TOMES to C_GBVM.REWARD_TOMES_LAST - 1 do
    Put(n, C_GBVM.QUEST_DONE);
  TestKit.Check(not JrnlQst.IsDone(9), 'four tomes are not all');
  Put(C_GBVM.REWARD_TOMES_LAST, $FF);
  TestKit.Check(JrnlQst.IsDone(9), 'five are');

  { the Bivant heir: given when offered; lost is not done, even paid }
  TestKit.Check(not JrnlQst.IsGiven(8), 'the heir not yet offered');
  Put(C_GBVM.BIVANT_OFFERED, $FF);
  TestKit.Check(JrnlQst.IsGiven(8), 'the heir offered');
  Put(C_GBVM.REWARD_BIVANT, C_GBVM.BUCCANEER_FLED);
  Put(C_GBVM.BUCCANEER_BASE, C_GBVM.BUCCANEER_FLED);
  TestKit.Check(not JrnlQst.IsDone(8), 'the heir left behind');
  Put(C_GBVM.REWARD_BIVANT, $FF);
  TestKit.Check(not JrnlQst.IsDone(8), 'still not done once the clerk has spoken of it');
  Put(C_GBVM.BUCCANEER_BASE, $FF);
  TestKit.Check(JrnlQst.IsDone(8), 'the heir rescued, the base taken');
  Put(C_GBVM.BUCCANEER_BASE, 0);
  TestKit.Check(JrnlQst.IsDone(8), 'the heir bought');

  { the commissions with no proclamation: given when recorded }
  NewGame;
  TestKit.Check(not JrnlQst.IsGiven(16), 'the auction not offered');
  Put(C_GBVM.REWARD_AUCTION, 1);
  TestKit.Check(JrnlQst.IsGiven(16) and not JrnlQst.IsDone(16), 'the auction offered, not done');
  Put(C_GBVM.REWARD_AUCTION, C_GBVM.QUEST_DONE);
  TestKit.Check(JrnlQst.IsDone(16), 'the auction done');
  Put(C_GBVM.ZHENTIL_SUMMONS, C_GBVM.QUEST_DONE);
  TestKit.Check(JrnlQst.IsGiven(18), 'Cadorna''s summons gives the Zhentil Keep message');
  Put(C_GBVM.REWARD_ZHENTIL, $FD);
  TestKit.Check(not JrnlQst.IsDone(18), 'leaving the outpost ($FD) is not done');
  Put(C_GBVM.REWARD_ZHENTIL, C_GBVM.QUEST_DONE);
  TestKit.Check(JrnlQst.IsDone(18), 'back from the outpost is');
  Put(C_GBVM.REWARD_CADORNA_TRAITOR, C_GBVM.QUEST_DONE);
  TestKit.Check(JrnlQst.IsGiven(19) and not JrnlQst.IsDone(19), 'Cadorna a traitor: kill him');
  Put(C_GBVM.REWARD_CADORNA_DEAD, C_GBVM.QUEST_DONE);
  TestKit.Check(JrnlQst.IsDone(19), 'Cadorna killed');
  Put(C_GBVM.GRAVEYARD_ACCEPTED, $FF);
  TestKit.Check(JrnlQst.IsGiven(12), 'the graveyard accepted before CLIV is posted');
  TestKit.CheckEqualsL(6 + 4, GivenCount, 'LIX''s six, the auction, the message, Cadorna and the graveyard');
  TestKit.Check(not JrnlQst.IsGiven(0) and not JrnlQst.IsDone(C_JRNL.QUEST_COUNT + 1), 'nothing outside the list');

  TestKit.Done;
end.
