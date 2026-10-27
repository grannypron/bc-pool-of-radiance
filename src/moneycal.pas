{ Money calculations shared by menus, combat results, Stats, and tests. This
  unit handles coin values, change, payment sources, item values, and service
  prices without depending on UI code. }
{$O+,F+}
{$I COMPILER.INC}
unit MoneyCal;

interface

uses Types;

const
  { who pays a price (WhoPays): nobody can, the current character, or the treasure pool }
  PAY_NOBODY = 0;
  PAY_CHARACTER = 1;
  PAY_POOL = 2;
  { a temple's prices (TemplePrice), the value a script stores in C_GBVM.ENTER_TEMPLE before the COMBAT that opens it:
    SSI's full prices, or a tenth off (the Temple of Bane that Dirten rebuilds, #682) }
  TEMPLE_FULL_PRICE = 1;
  TEMPLE_TENTH_OFF = 2;
  { the sage's fee for telling of a creature (SageFee, #868): so much a hit die, and no less than the least }
  SAGE_FEE_PER_HD = 50;
  SAGE_FEE_MIN = 100;

{ The copper value of the five coin types in m. }
function CopperValue(var m: Types.TMoney): LongInt;

function CoinValueInGold(m: Types.TMoney): LongInt;

{ The creature's five coin types as a TMoney; its gems and jewelry are left out (0). }
procedure CoinsOf(creature: Types.PCharRecord; var m: Types.TMoney);

{ How many more of money type mType the creature can hold before its count reaches C_MONEY.MAX_COINS. }
function CoinRoom(creature: Types.PCharRecord; mType: ShortInt): Word;

{ The creature's five coin types in copper. }
function CreatureCopper(creature: Types.PCharRecord): LongInt;

{ The creature's five coin types in whole gold pieces, as CoinValueInGold. }
function CreatureGold(creature: Types.PCharRecord): LongInt;

procedure MakeChange(rem, cap: LongInt; var m: Types.TMoney);

{ Selects buyer or the treasure pool as the payment source, or PAY_NOBODY when
  neither can cover the price. }
function WhoPays(buyer: Types.PCharRecord; gp: LongInt): Byte;

{ Returns the bundle size used when valuing an item. Ammunition is priced in
  bundles of 20; everything else is priced per piece. }
function ItemBundle(item: Types.PItemRec): Byte;

{ What an item or stack is worth in gold: value * quantity div ItemBundle (quantity 0 is a single unstacked item). }
function ItemValue(item: Types.PItemRec): LongInt;

{ What a shop pays for an item or stack: half its ItemValue, at most 65535. }
function ItemSalePrice(item: Types.PItemRec): Word;

function ParseMoneyType(s: String; var typeName: String): ShortInt;

{ What a temple asks for a service listed at cost gold pieces: cost itself, or with mode TEMPLE_TENTH_OFF a tenth less,
  the tenth rounded down (every listed price is a multiple of 10). }
function TemplePrice(cost: Word; mode: Byte): Word;

{ Calculates the sage's fee from hit dice, subject to the minimum charge. }
function SageFee(hd: ShortInt): Word;

implementation

uses GameDefs, GameVars, C_ITEM, C_MONEY;

function CopperValue(var m: Types.TMoney): LongInt;
var
  total: LongInt;
  i: ShortInt;
begin
  total := 0;
  for i := C_MONEY.COPPER to C_MONEY.PLATINUM do
    Inc(total, GameDefs.coinValues[i] * m[i]);
  CopperValue := total;
end;

{ The value of the five coin types in m in whole gold pieces; a part of a gold piece does not count, so 999 gp and an
  electrum piece cannot pay 1000. }
function CoinValueInGold(m: Types.TMoney): LongInt;
begin
  CoinValueInGold := MoneyCal.CopperValue(m) div GameDefs.coinValues[C_MONEY.GOLD];
end;

procedure CoinsOf(creature: Types.PCharRecord; var m: Types.TMoney);
var
  i: ShortInt;
begin
  FillChar(m, SizeOf(m), 0);
  for i := C_MONEY.COPPER to C_MONEY.PLATINUM do
    m[i] := creature^.coins[i];
end;

function CoinRoom(creature: Types.PCharRecord; mType: ShortInt): Word;
begin
  CoinRoom := C_MONEY.MAX_COINS - creature^.coins[mType];
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
  CreatureGold := MoneyCal.CreatureCopper(creature) div GameDefs.coinValues[C_MONEY.GOLD];
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
  for i := C_MONEY.PLATINUM downto C_MONEY.COPPER do begin
    n := rem div GameDefs.coinValues[i];
    if n > cap then
      n := cap;
    m[i] := n;
    Dec(rem, n * GameDefs.coinValues[i]);
  end;
end;

function WhoPays(buyer: Types.PCharRecord; gp: LongInt): Byte;
begin
  if gp <= MoneyCal.CreatureGold(buyer) then
    WhoPays := PAY_CHARACTER
  else if gp <= MoneyCal.CoinValueInGold(GameVars.treasureMoney) then
    WhoPays := PAY_POOL
  else
    WhoPays := PAY_NOBODY;
end;

function ItemBundle(item: Types.PItemRec): Byte;
begin
  case item^.itemType of
    C_ITEM.DART, C_ITEM.QUARREL, C_ITEM.ARROW: ItemBundle := 20;
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

{ Return the money type named by s and its display name in typeName. Leading spaces are skipped; the first letter
  selects the type, and for 'G' the second letter, upper-cased, tells Gems from Gold. An unmatched letter, or a blank s,
  returns -1 and leaves typeName as it was. }
function ParseMoneyType(s: String; var typeName: String): ShortInt;
var
  i: Byte;
begin
  ParseMoneyType := -1;
  i := 1;
  while (i < Length(s)) and (s[i] = ' ') do
    Inc(i);
  if i > Length(s) then Exit;
  case s[i] of
    'G': if UpCase(s[i + 1]) = 'E' then begin
           ParseMoneyType := C_MONEY.GEMS;
           typeName := 'Gems ';
         end else begin
           typeName := 'Gold ';
           ParseMoneyType := C_MONEY.GOLD;
         end;
    'P': begin
           typeName := 'Platinum ';
           ParseMoneyType := C_MONEY.PLATINUM;
         end;
    'E': begin
           typeName := 'electrum ';
           ParseMoneyType := C_MONEY.ELECTRUM;
         end;
    'S': begin
           typeName := 'silver ';
           ParseMoneyType := C_MONEY.SILVER;
         end;
    'C': begin
           typeName := 'Copper ';
           ParseMoneyType := C_MONEY.COPPER;
         end;
    'J': begin
           typeName := 'Jewelry ';
           ParseMoneyType := C_MONEY.JEWELRY;
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

function SageFee(hd: ShortInt): Word;
begin
  if hd * MoneyCal.SAGE_FEE_PER_HD > MoneyCal.SAGE_FEE_MIN then
    SageFee := hd * MoneyCal.SAGE_FEE_PER_HD
  else
    SageFee := MoneyCal.SAGE_FEE_MIN;
end;

end.
