{ The Journal's quests (#851): the missions the City Council and its men give the party, each with where it comes from,
  whether the party has been given it and whether it is done, read from the game memory the scripts keep them in.

  A quest is addressed by its place on the Quests page, 1 to C_JRNL.QUEST_COUNT: first the proclamations' quests, in the
  Journal's order, then the commissions the clerk and the councilmen give with no proclamation. The scripts mark a
  mission done by writing C_GBVM.QUEST_DONE into its reward cell, and the clerk writes $FF there as she pays for it.
  Outside City Hall the party notes the proclamations posted so far, which follow how many of the major rewards the
  clerk has paid (C_GBVM.COUNCIL_REWARDS); a quest counts as given once its proclamation is posted, once the clerk or a
  councilman has given it where the scripts record that, or once it is done (the Clue Book: a mission done unasked is
  paid for all the same). The proclamations CXX, CLVI, CLXX and CXC are never posted, and nothing records LXIV, LXXVIII
  and CIX (the graveyard's rumours) or Cadorna's family treasure (a treasure kept from him ends as one returned), so
  none of them is a quest here. }
{$O+,F+}
{$I COMPILER.INC}
unit JrnlQst;

interface

{ The quest's line on the Quests page: its proclamation's numeral, or who gives it, and what to do, as
  CI: CLEAR SOKAL KEEP. Returns an empty string outside the 1-based quest list. }
function QuestLabel(n: Integer): string;

{ Returns the Journal item for the proclamation that gives this quest, or 0
  when the quest has no proclamation. }
function QuestItem(n: Integer): Integer;

{ Returns True when the quest's reward cell shows that it is complete. }
function IsDone(n: Integer): Boolean;

{ Returns True when the quest belongs on the page. A quest counts as given if
  its proclamation is posted, a script records it as given, or it is complete. }
function IsGiven(n: Integer): Boolean;

{ Returns True when a proclamation has been posted outside City Hall. The
  number is numeric, so LIX is passed as 59. }
function IsPosted(number: Integer): Boolean;

implementation

uses C_GBVM, C_JRNL, GameVars, JrnlList;

const
  { a proclamation the council never posts }
  NEVER = 255;

{ A word of the game memory's zone 0, where the scripts keep the missions. }
function Cell(address: Word): Word;
begin
  Cell := GameVars.zone0^.words[address];
end;

{ Whether the reward cell at address says its mission is done. }
function Done(address: Word): Boolean;
begin
  Done := JrnlQst.Cell(address) >= C_GBVM.QUEST_DONE;
end;

{ The number of the proclamation that gives quest n, or 0 for none. }
function Proclamation(n: Integer): Integer;
begin
  case n of
    1..6: Proclamation := 59;
    7: Proclamation := 101;
    8: Proclamation := 114;
    9: Proclamation := 126;
    10: Proclamation := 129;
    11: Proclamation := 134;
    12: Proclamation := 154;
    13: Proclamation := 201;
    14: Proclamation := 204;
    15: Proclamation := 214;
    else Proclamation := 0;
  end;
end;

{ What quest n asks, after its proclamation's numeral, or with who gives it for one no proclamation gives. }
function Task(n: Integer): string;
begin
  case n of
    1: Task := 'CLEAR THE SLUMS';
    2: Task := 'CLEAR KUTO''S WELL';
    3: Task := 'CLEAR PODOL PLAZA';
    4: Task := 'CLEAR THE TEXTILE HOUSE';
    5: Task := 'CLEAR MENDOR''S LIBRARY';
    6: Task := 'CLEAR THE WEALTHY AREA';
    7: Task := 'CLEAR SOKAL KEEP';
    8: Task := 'RESCUE THE BIVANT HEIR';
    9: Task := 'RETRIEVE THE FIVE TOMES';
    10: Task := 'CLEANSE THE RIVER';
    11: Task := 'CLEAR KOVEL MANSION';
    12: Task := 'CLEANSE VALHINGEN';
    13: Task := 'STOP THE LIZARD MEN';
    14: Task := 'STOP THE KOBOLDS';
    15: Task := 'STOP THE NOMADS';
    16: Task := 'CLERK: PODOL PLAZA AUCTION';
    17: Task := 'BRACCIO: CLEANSE BANE''S TEMPLE';
    18: Task := 'CADORNA: ZHENTIL KEEP MESSAGE';
    19: Task := 'COUNCIL: KILL TRAITOR CADORNA';
    20: Task := 'URSLINGEN: TAKE STOJANOW GATE';
    21: Task := 'COUNCIL: TAKE VALJEVO CASTLE';
    else Task := '';
  end;
end;

{ Whether the scripts record that quest n was given, for the quests they record it for: the clerk's offer, the
  party's acceptance, or her summons to the councilman or the bishop who gives it. }
function Recorded(n: Integer): Boolean;
begin
  case n of
    8: Recorded := JrnlQst.Cell(C_GBVM.BUCCANEERS_BASE_VISIBLE) = $FF;
    12: Recorded := JrnlQst.Cell(C_GBVM.GRAVEYARD_ACCEPTED) = $FF;
    16: Recorded := JrnlQst.Cell(C_GBVM.REWARD_AUCTION) <> 0;
    17: Recorded := JrnlQst.Done(C_GBVM.BRACCIO_SUMMONS);
    18: Recorded := JrnlQst.Done(C_GBVM.ZHENTIL_SUMMONS);
    19: Recorded := JrnlQst.Done(C_GBVM.REWARD_CADORNA_TRAITOR);
    20: Recorded := JrnlQst.Done(C_GBVM.URSLINGEN_SUMMONS);
    21: Recorded := JrnlQst.Done(C_GBVM.VALJEVO_SUMMONS);
    else Recorded := False;
  end;
end;

function QuestLabel(n: Integer): string;
var
  item: Integer;
begin
  item := JrnlQst.QuestItem(n);
  if item <> 0 then
    QuestLabel := JrnlList.EntryLabel(item) + ': ' + JrnlQst.Task(n)
  else
    QuestLabel := JrnlQst.Task(n);
end;

function QuestItem(n: Integer): Integer;
begin
  if JrnlQst.Proclamation(n) = 0 then
    QuestItem := 0
  else
    QuestItem := JrnlList.ProclamationItem(JrnlQst.Proclamation(n));
end;

function IsDone(n: Integer): Boolean;
var
  address: Word;
begin
  case n of
    { the Slums' cell counts the block's clear points until it is cleared }
    1: IsDone := JrnlQst.Done(C_GBVM.REWARD_SLUMS);
    { Norris the Gray beaten; the Clue Book: no commission of its own, the block's reward }
    2: IsDone := JrnlQst.Done(C_GBVM.REWARD_NORRIS);
    3: IsDone := JrnlQst.Done(C_GBVM.PODOL_CLEARED);
    4: IsDone := JrnlQst.Done(C_GBVM.TEXTILE_CLEARED);
    5: IsDone := JrnlQst.Cell(C_GBVM.LIBRARY_FIGHTS) and C_GBVM.LIBRARY_CLEARED = C_GBVM.LIBRARY_CLEARED;
    6: IsDone := JrnlQst.Done(C_GBVM.REWARD_WEALTHY);
    7: IsDone := JrnlQst.Done(C_GBVM.REWARD_SOKAL);
    { a heir left behind ends with the reward cell paid too: the base's own cell tells it }
    8: IsDone := JrnlQst.Done(C_GBVM.REWARD_BIVANT)
                 and (JrnlQst.Cell(C_GBVM.BUCCANEER_BASE) <> C_GBVM.BUCCANEER_FLED);
    { every one of the five tomes the council pays for }
    9: begin
         IsDone := True;
         for address := C_GBVM.REWARD_TOMES to C_GBVM.REWARD_TOMES_LAST do
           if not JrnlQst.Done(address) then
             IsDone := False;
       end;
    10: IsDone := JrnlQst.Done(C_GBVM.YARASH_MISSION_DONE);
    11: IsDone := JrnlQst.Done(C_GBVM.REWARD_KOVEL);
    12: IsDone := JrnlQst.Done(C_GBVM.REWARD_GRAVEYARD);
    13: IsDone := JrnlQst.Done(C_GBVM.REWARD_LIZARDMEN);
    14: IsDone := JrnlQst.Done(C_GBVM.REWARD_KOBOLDS);
    15: IsDone := JrnlQst.Done(C_GBVM.REWARD_NOMADS);
    16: IsDone := JrnlQst.Done(C_GBVM.REWARD_AUCTION);
    17: IsDone := JrnlQst.Done(C_GBVM.REWARD_BANE_TEMPLE);
    18: IsDone := JrnlQst.Done(C_GBVM.REWARD_ZHENTIL);
    19: IsDone := JrnlQst.Done(C_GBVM.REWARD_CADORNA_DEAD);
    20: IsDone := JrnlQst.Done(C_GBVM.REWARD_GATE);
    21: IsDone := JrnlQst.Done(C_GBVM.REWARD_VALJEVO);
    else IsDone := False;
  end;
end;

function IsGiven(n: Integer): Boolean;
begin
  if (n < 1) or (n > C_JRNL.QUEST_COUNT) then
    IsGiven := False
  else
    IsGiven := JrnlQst.IsPosted(JrnlQst.Proclamation(n)) or JrnlQst.Recorded(n) or JrnlQst.IsDone(n);
end;

function IsPosted(number: Integer): Boolean;
var
  { how many major rewards the clerk has paid when the council posts it }
  rewards: Byte;
begin
  { City Hall's script ($AC58 on): none paid notes LXIV, LXXVIII, CIX and LIX, then each reward one more. SSI's ninth
    named CXIV again where CCXIV, the one left, is meant; DataPat makes it CCXIV (POR-0209, #864). }
  case number of
    59, 64, 78, 109: rewards := 0;
    101: rewards := 1;
    110, 126: rewards := 2;
    134: rewards := 3;
    154: rewards := 4;
    114: rewards := 5;
    204: rewards := 6;
    129: rewards := 7;
    201: rewards := 8;
    214: rewards := 9;
    else rewards := NEVER;
  end;
  IsPosted := (rewards <> NEVER) and (JrnlQst.Cell(C_GBVM.COUNCIL_REWARDS) >= rewards);
end;

end.
