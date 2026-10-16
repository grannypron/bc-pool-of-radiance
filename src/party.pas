{ The party: which creatures in GDVars.creatureList are its members. Resident and using only GDVars, so units with
  tests (Stats) can use it. }
{$F+}
unit Party;

interface

uses Types;

{ True when creature is one of the party's PARTY_SIZE members, which lead GDVars.creatureList: in combat the monsters
  follow them in the list, and are not members. False for nil. }
function IsPartyMember(creature: Types.PCharRecord): Boolean;

{ Step curChar through the party on the extended scan codes the menus return: C_Keys.HOME selects the previous character
  and C_Keys.END_KEY the next. C_Keys.HOME from the head wraps to the tail; C_Keys.END_KEY from the tail wraps to the
  head; any other code selects the head. }
procedure SelectPrevNextChar(c: Char);

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
      C_Keys.HOME:
        if p = GDVars.curChar then begin
          while p^.nextCharAddr <> nil do
            p := p^.nextCharAddr;
        end else
          while (p <> nil) and (p^.nextCharAddr <> GDVars.curChar) do
            p := p^.nextCharAddr;
      C_Keys.END_KEY:
        if GDVars.curChar^.nextCharAddr <> nil then
          p := GDVars.curChar^.nextCharAddr;
    else
      p := GDVars.creatureList;
    end;
  GDVars.curChar := p;
end;

end.
