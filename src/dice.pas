{ The dice. Resident, and using only GameVars, so every unit can roll without loading an overlay and tests can fix
  RandSeed (#642). }
{$F+}
{$I COMPILER.INC}
unit Dice;

interface

{ Roll n dice with the given number of sides and return the total (0 when n = 0; the Byte sum wraps past 255). }
function RollDice(n, sides: Byte): Byte;

{ RollDice that also posts the dice count n to gDamageDice. Does not set GameVars.pendingDamage. }
function RollDamageDice(n, sides: Byte): Byte;

{ Take perDie off GameVars.pendingDamage for each of the gDamageDice dice rolled, leaving no die below 1: the damage
  stops at the dice count, and damage already at or below it is left alone. }
procedure ReduceDamagePerDie(perDie: Byte);

implementation

uses GameVars{$IFDEF FPC}, TpRand{$ENDIF};

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
  GameVars.gDamageDice := n;
  RollDamageDice := Dice.RollDice(n, sides);
end;

procedure ReduceDamagePerDie(perDie: Byte);
begin
  if GameVars.pendingDamage > GameVars.gDamageDice then
    if GameVars.pendingDamage - GameVars.gDamageDice > Word(perDie) * GameVars.gDamageDice then
      Dec(GameVars.pendingDamage, perDie * GameVars.gDamageDice)
    else
      GameVars.pendingDamage := GameVars.gDamageDice;
end;

end.
