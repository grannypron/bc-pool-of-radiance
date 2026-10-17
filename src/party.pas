{ The party: which creatures in GDVars.creatureList are its members. Resident and using only GDVars, so units with
  tests (Stats) can use it. }
{$F+}
unit Party;

interface

uses Types;

{ True when creature is one of the party's PARTY_SIZE members, which lead GDVars.creatureList: in combat the monsters
  follow them in the list, and are not members. False for nil. }
function IsPartyMember(creature: Types.PCharRecord): Boolean;

{ Step curChar through the party on the extended scan codes the menus return: C_Keys.HOME or C_Keys.UP selects the
  previous character and C_Keys.END_KEY or C_Keys.DOWN the next (#650, #653). The previous from the head wraps to the
  tail, the next from the tail to the head; any other code selects the head. }
procedure SelectPrevNextChar(c: Char);

{ The last creature in GDVars.creatureList, or nil for an empty list. }
function LastCreature: Types.PCharRecord;

{ The creature before c in GDVars.creatureList, wrapping from the head to the last; nil when c is not in the list. }
function PrevCreature(c: Types.PCharRecord): Types.PCharRecord;

{ The creature after c in GDVars.creatureList, wrapping from the last to the head. }
function NextCreature(c: Types.PCharRecord): Types.PCharRecord;

implementation

uses GDVars, C_Gbvm, C_Keys;

function IsPartyMember(creature: Types.PCharRecord): Boolean;
var
  p: Types.PCharRecord;
  n: Integer;
begin
  IsPartyMember := False;
  if creature = nil then Exit;
  p := GDVars.creatureList;
  n := GDVars.zone1^[C_Gbvm.PARTY_SIZE];
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
  p := GDVars.creatureList;
  if p <> nil then
    case c of
      C_Keys.HOME, C_Keys.UP: p := Party.PrevCreature(GDVars.curChar);
      C_Keys.END_KEY, C_Keys.DOWN: p := Party.NextCreature(GDVars.curChar);
    end;
  GDVars.curChar := p;
end;

function LastCreature: Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  p := GDVars.creatureList;
  if p <> nil then
    while p^.nextCharAddr <> nil do
      p := p^.nextCharAddr;
  LastCreature := p;
end;

function PrevCreature(c: Types.PCharRecord): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  p := GDVars.creatureList;
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
    NextCreature := GDVars.creatureList;
end;

end.
