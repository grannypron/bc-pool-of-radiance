{ The party: which creatures in GDVars.creatureList are its members. Resident and using only GDVars, so units with
  tests (Stats) can use it. }
{$F+}
unit Party;

interface

uses Types;

{ True when creature is one of the party's PARTY_SIZE members, which lead GDVars.creatureList: in combat the monsters
  follow them in the list, and are not members. False for nil. }
function IsPartyMember(creature: Types.PCharRecord): Boolean;

implementation

uses GDVars, C_Gbvm;

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

end.
