{ Money arithmetic: coin values, making change, who pays a price, what items are worth, money type names and temple
  prices. Using only data units, so Stats can use it and tests can too; overlaid, as only menus and the end of a combat
  call it. }
{$O+,F+}
unit MoneyCal;

interface

uses Types;

const
  { who pays a price (WhoPays): nobody can, the current character, or the treasure pool }
  PAY_NOBODY = 0;
  PAY_CHARACTER = 1;
  PAY_POOL = 2;
  { a temple's prices (TemplePrice), the value a script stores in C_Gbvm.ENTER_TEMPLE before the COMBAT that opens it:
    SSI's full prices, or a tenth off (the Temple of Bane that Dirten rebuilds, #682) }
  TEMPLE_FULL_PRICE = 1;
  TEMPLE_TENTH_OFF = 2;

{ The copper value of the five coin types in m. }
function CopperValue(var m: Types.TMoney): LongInt;

function CoinValueInGold(m: Types.TMoney): LongInt;

{ The creature's five coin types as a TMoney; its gems and jewelry are left out (0). }
procedure CoinsOf(creature: Types.PCharRecord; var m: Types.TMoney);

{ The creature's five coin types in copper. }
function CreatureCopper(creature: Types.PCharRecord): LongInt;

{ The creature's five coin types in whole gold pieces, as CoinValueInGold. }
function CreatureGold(creature: Types.PCharRecord): LongInt;

procedure MakeChange(rem, cap: LongInt; var m: Types.TMoney);

{ Who pays gp gold pieces for buyer: buyer when its coins cover it, else the treasure pool when it does. }
function WhoPays(buyer: Types.PCharRecord; gp: LongInt): Byte;

{ How many pieces an item's value is for: ammunition (darts, quarrels and arrows) is valued per bundle of 20, as the
  game's own 20 Arrows +1 for 100 gp are; anything else is valued per piece (3 Potions of Healing at 400 each). }
function ItemBundle(item: Types.PItemRec): Byte;

{ What an item or stack is worth in gold: value * quantity div ItemBundle (quantity 0 is a single unstacked item). }
function ItemValue(item: Types.PItemRec): LongInt;

{ What a shop pays for an item or stack: half its ItemValue, at most 65535. }
function ItemSalePrice(item: Types.PItemRec): Word;

function ParseMoneyType(s: String; var typeName: String): ShortInt;

{ What a temple asks for a service listed at cost gold pieces: cost itself, or with mode TEMPLE_TENTH_OFF a tenth less,
  the tenth rounded down (every listed price is a multiple of 10). }
function TemplePrice(cost: Word; mode: Byte): Word;

implementation

uses GDConsts, GDVars, C_Money;

function CopperValue(var m: Types.TMoney): LongInt;
var
  total: LongInt;
  i: ShortInt;
begin
  total := 0;
  for i := C_Money.COPPER to C_Money.PLATINUM do
    Inc(total, GDConsts.dsCoinValuationCopper[i] * m[i]);
  CopperValue := total;
end;

{ The value of the five coin types in m in whole gold pieces; a part of a gold piece does not count, so 999 gp and an
  electrum piece cannot pay 1000. }
function CoinValueInGold(m: Types.TMoney): LongInt;
begin
  CoinValueInGold := MoneyCal.CopperValue(m) div GDConsts.dsCoinValuationCopper[C_Money.GOLD];
end;

procedure CoinsOf(creature: Types.PCharRecord; var m: Types.TMoney);
var
  i: ShortInt;
begin
  FillChar(m, SizeOf(m), 0);
  for i := C_Money.COPPER to C_Money.PLATINUM do
    m[i] := creature^.coins[i];
end;

function CreatureCopper(creature: Types.PCharRecord): LongInt;
var
  m: Types.TMoney;
begin
  MoneyCal.CoinsOf(creature, m);
  CreatureCopper := MoneyCal.CopperValue(m);
end;

function CreatureGold(creature: Types.PCharRecord): LongInt;
begin
  CreatureGold := MoneyCal.CreatureCopper(creature) div GDConsts.dsCoinValuationCopper[C_Money.GOLD];
end;

{ Replace the five coin types in m with rem copper given as the largest coins, platinum first, each type at most cap.
  Gems and jewelry are kept. A negative rem gives nothing; copper the caps cannot hold is lost. At a cap of 65535 that
  takes more than 65535 of every type (about 429,581 gp), more than a character's Word-sized coins can hold. }
procedure MakeChange(rem, cap: LongInt; var m: Types.TMoney);
var
  i: ShortInt;
  n: LongInt;
begin
  if rem < 0 then
    rem := 0;
  for i := C_Money.PLATINUM downto C_Money.COPPER do begin
    n := rem div GDConsts.dsCoinValuationCopper[i];
    if n > cap then
      n := cap;
    m[i] := n;
    Dec(rem, n * GDConsts.dsCoinValuationCopper[i]);
  end;
end;

function WhoPays(buyer: Types.PCharRecord; gp: LongInt): Byte;
begin
  if gp <= MoneyCal.CreatureGold(buyer) then
    WhoPays := PAY_CHARACTER
  else if gp <= MoneyCal.CoinValueInGold(GDVars.treasureMoney) then
    WhoPays := PAY_POOL
  else
    WhoPays := PAY_NOBODY;
end;

function ItemBundle(item: Types.PItemRec): Byte;
begin
  case item^.itemType of
    9, 28, 73: ItemBundle := 20;
    else ItemBundle := 1;
  end;
end;

function ItemValue(item: Types.PItemRec): LongInt;
var
  q: LongInt;
begin
  q := item^.quantity;
  if q = 0 then
    q := 1;
  ItemValue := LongInt(item^.value) * q div MoneyCal.ItemBundle(item);
end;

function ItemSalePrice(item: Types.PItemRec): Word;
var
  v: LongInt;
begin
  v := MoneyCal.ItemValue(item) div 2;
  if v > 65535 then
    v := 65535;
  ItemSalePrice := v;
end;

{ Return the money type named by s and its display name in typeName. Leading spaces are skipped (no bounds check); the
  first letter selects the type, and for 'G' the second letter, upper-cased, tells Gems from Gold. An unmatched letter
  leaves the result and typeName unset. }
function ParseMoneyType(s: String; var typeName: String): ShortInt;
var
  i: Byte;
begin
  i := 1;
  while s[i] = ' ' do
    Inc(i);
  case s[i] of
    'G': if UpCase(s[i + 1]) = 'E' then begin
           ParseMoneyType := C_Money.GEMS;
           typeName := 'Gems ';
         end else begin
           typeName := 'Gold ';
           ParseMoneyType := C_Money.GOLD;
         end;
    'P': begin
           typeName := 'Platinum ';
           ParseMoneyType := C_Money.PLATINUM;
         end;
    'E': begin
           typeName := 'electrum ';
           ParseMoneyType := C_Money.ELECTRUM;
         end;
    'S': begin
           typeName := 'silver ';
           ParseMoneyType := C_Money.SILVER;
         end;
    'C': begin
           typeName := 'Copper ';
           ParseMoneyType := C_Money.COPPER;
         end;
    'J': begin
           typeName := 'Jewelry ';
           ParseMoneyType := C_Money.JEWELRY;
         end;
  end;
end;

function TemplePrice(cost: Word; mode: Byte): Word;
begin
  if mode = MoneyCal.TEMPLE_TENTH_OFF then
    TemplePrice := cost - cost div 10
  else
    TemplePrice := cost;
end;

end.
