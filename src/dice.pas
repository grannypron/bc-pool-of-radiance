{ The dice. Resident, and using only GDVars, so every unit can roll without loading an overlay and tests can fix
  RandSeed (#642). }
{$F+}
{$I COMPILER.INC}
unit Dice;

interface

{ Roll n dice with the given number of sides and return the total (0 when n = 0; the Byte sum wraps past 255). }
function RollDice(n, sides: Byte): Byte;

{ RollDice that also posts the dice count n to gDamageDice. Does not set GDVars.pendingDamage. }
function RollDamageDice(n, sides: Byte): Byte;

implementation

uses GDVars{$IFDEF FPC}, TpRand{$ENDIF};

function RollDice(n, sides: Byte): Byte;
var
  i: Byte;
  total: Byte;
begin
  total := 0;
  if n > 0 then
    for i := 1 to n do
      Inc(total, Random(sides) + 1);
  RollDice := total;
end;

function RollDamageDice(n, sides: Byte): Byte;
begin
  GDVars.gDamageDice := n;
  RollDamageDice := Dice.RollDice(n, sides);
end;

end.
