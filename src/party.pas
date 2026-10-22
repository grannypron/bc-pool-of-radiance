{ The party: which creatures in GameVars.creatureList are its members. Resident and using only GameVars, so units with
  tests (Stats) can use it. }
{$F+}
{$I COMPILER.INC}
unit Party;

interface

uses Types;

{ True when creature is one of the party's PARTY_SIZE members, which lead GameVars.creatureList: in combat the monsters
  follow them in the list, and are not members. False for nil. }
function IsPartyMember(creature: Types.PCharRecord): Boolean;

{ Step curChar through the party on the extended scan codes the menus return: C_KEYS.HOME or C_KEYS.UP selects the
  previous character and C_KEYS.END_KEY or C_KEYS.DOWN the next (#650, #653). The previous from the head wraps to the
  tail, the next from the tail to the head; any other code keeps the current character (the head when there is none,
  #733). With no current character the step starts from the head (#806). }
procedure SelectPrevNextChar(c: Char);

{ The last creature in GameVars.creatureList, or nil for an empty list. }
function LastCreature: Types.PCharRecord;

{ The creature before c in GameVars.creatureList, wrapping from the head to the last; nil when c is not in the list. }
function PrevCreature(c: Types.PCharRecord): Types.PCharRecord;

{ The creature after c in GameVars.creatureList, wrapping from the last to the head. }
function NextCreature(c: Types.PCharRecord): Types.PCharRecord;

implementation

uses GameVars, C_GBVM, C_KEYS;

function IsPartyMember(creature: Types.PCharRecord): Boolean;
var
  p: Types.PCharRecord;
  n: Integer;
begin
  IsPartyMember := False;
  if creature = nil then Exit;
  p := GameVars.creatureList;
  n := GameVars.zone1^[C_GBVM.PARTY_SIZE];
  while (p <> nil) and (n > 0) do begin
    if p = creature then begin
      IsPartyMember := True;
      Exit;
    end;
    p := p^.nextCharAddr;
    Dec(n);
  end;
end;

procedure SelectPrevNextChar(c: Char);
var
  p: Types.PCharRecord;
begin
  { any other key keeps the current character: SSI's fell back to the first, so a digit, F-key or other extended key in
    a menu that passes them here jumped to the head of the party (#733) }
  p := GameVars.curChar;
  if p = nil then
    p := GameVars.creatureList;
  if p <> nil then
    case c of
      C_KEYS.HOME, C_KEYS.UP: p := Party.PrevCreature(p);
      C_KEYS.END_KEY, C_KEYS.DOWN: p := Party.NextCreature(p);
    end;
  GameVars.curChar := p;
end;

function LastCreature: Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  p := GameVars.creatureList;
  if p <> nil then
    while p^.nextCharAddr <> nil do
      p := p^.nextCharAddr;
  LastCreature := p;
end;

function PrevCreature(c: Types.PCharRecord): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  p := GameVars.creatureList;
  if p = c then
    p := Party.LastCreature
  else
    while (p <> nil) and (p^.nextCharAddr <> c) do
      p := p^.nextCharAddr;
  PrevCreature := p;
end;

function NextCreature(c: Types.PCharRecord): Types.PCharRecord;
begin
  if c^.nextCharAddr <> nil then
    NextCreature := c^.nextCharAddr
  else
    NextCreature := GameVars.creatureList;
end;

end.
