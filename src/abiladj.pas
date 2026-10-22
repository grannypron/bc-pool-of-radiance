{ Ability score adjustments: the Strength and Dexterity tables for to-hit, damage, armor class and carrying. Resident
  and using only Types, so combat can call it and tests can use it. }
{$F+}
{$I COMPILER.INC}
unit AbilAdj;

interface

uses Types;

{ Map strCur (with exceptional strength at 18) onto the 0..30 combined strength scale used by the strength tables:
  0..17 as they are, 18 and 18/01..18/00 as 18..23, 19..25 as 24..30. }
function TranslatedStrength(creature: Types.PCharRecord): Byte;

function StrToHitAdjust(creature: Types.PCharRecord): ShortInt;

function StrDamageAdjust(creature: Types.PCharRecord): ShortInt;

function WeightAllowance(creature: Types.PCharRecord): Integer;

function DexMissileAdjust(creature: Types.PCharRecord): ShortInt;

function DexterityArmorAdjustment(creature: Types.PCharRecord): ShortInt;

{ The Constitution bonus to poison saves (dwarves, halflings) and to spell and wand saves (dwarves, gnomes, halflings):
  +1 per 3 1/2 points of Constitution, so 1 at 4..6, 2 at 7..10, 3 at 11..13, 4 at 14..17, 5 at 18..20, 6 at 21..24,
  7 at 25. }
function ConSaveBonus(con: Byte): Byte;

const
  { the lowest and highest an ability score goes in play (#615); creation and Modify Character have their own limits }
  SCORE_MIN = 3;
  SCORE_MAX = 25;

{ score kept within SCORE_MIN..SCORE_MAX, for every change play makes to an ability score (#615). }
function ClampScore(score: Integer): Byte;

{ The resurrection survival chance, in percent, for Constitution con (1st-edition PHB): 40 at 3, 5 more a point to 90 at
  13, then 2 more a point to 100 at 18, and 100 above it (Deities & Demigods); below 3 counts as 3. }
function ConResurrectionSurvival(con: Byte): Byte;

{ The poison save bonus any creature gets from a Constitution above 18 (Deities & Demigods): +1 at 19..20, +2 at
  21..22, +3 at 23..24 and +4 from 25; 0 below 19. }
function ConPoisonSave(con: Byte): Byte;

{ How often a Constitution of 20 or more regenerates a hit point, in minutes (Deities & Demigods): 60 at 20, 50 at 21,
  40 at 22, 30 at 23, 20 at 24 and 10 from 25; 0 below 20, which does not regenerate. }
function ConRegenMinutes(con: Byte): Word;

implementation

{ Armor class adjustment for the creature's Dexterity (positive is better, as AC is stored biased). }
function DexterityArmorAdjustment(creature: Types.PCharRecord): ShortInt;
var
  d: Byte;
begin
  d := creature^.dexCur;
  case d of
    1..3: DexterityArmorAdjustment := -4;
    4..6: DexterityArmorAdjustment := d - 7;
    15..18: DexterityArmorAdjustment := d - 14;
    19..20: DexterityArmorAdjustment := 4;
    21..23: DexterityArmorAdjustment := 5;
    24..25: DexterityArmorAdjustment := 6;
  else
    DexterityArmorAdjustment := 0;
  end;
end;

{ Missile to-hit adjustment for the creature's Dexterity: -4 below 3, -3 at 3 rising to +3 at 18, then +3..+5 for higher
  scores. }
function DexMissileAdjust(creature: Types.PCharRecord): ShortInt;
var
  d: Byte;
begin
  d := creature^.dexCur;
  case d of
    0..2: DexMissileAdjust := -4;
    3..5: DexMissileAdjust := d - 6;
    16..18: DexMissileAdjust := d - 15;
    19..20: DexMissileAdjust := 3;
    21..23: DexMissileAdjust := 4;
    24..25: DexMissileAdjust := 5;
  else
    DexMissileAdjust := 0;
  end;
end;

{ Map strCur (with exceptional strength at 18) onto the 0..30 combined strength scale used by the strength tables.
  Strength above 25 counts as 25 and exceptional strength above 100 as 18/00. }
function TranslatedStrength(creature: Types.PCharRecord): Byte;
begin
  case creature^.strCur of
    0..17: TranslatedStrength := creature^.strCur;
    18:
      case creature^.strExc of
        0: TranslatedStrength := 18;
        1..50: TranslatedStrength := 19;
        51..75: TranslatedStrength := 20;
        76..90: TranslatedStrength := 21;
        91..99: TranslatedStrength := 22;
      else
        TranslatedStrength := 23;
      end;
    19..25: TranslatedStrength := creature^.strCur + 5;
  else
    TranslatedStrength := 30;
  end;
end;

{ Strength to-hit adjustment over the translated scale; zero unless the creature's strength bonus applies. }
function StrToHitAdjust(creature: Types.PCharRecord): ShortInt;
var
  ts: Byte;
begin
  StrToHitAdjust := 0;
  ts := AbilAdj.TranslatedStrength(creature);
  if creature^.useStrength <> 0 then
    case ts of
      1..3: StrToHitAdjust := -3;
      4..5: StrToHitAdjust := -2;
      6..7: StrToHitAdjust := -1;
      17..19: StrToHitAdjust := 1;
      20..22: StrToHitAdjust := 2;
      23..25: StrToHitAdjust := 3;
      26..27: StrToHitAdjust := 4;
      28..30: StrToHitAdjust := ts - 23;
    end;
end;

{ Strength damage adjustment over the translated scale; zero unless the creature's strength bonus applies. }
function StrDamageAdjust(creature: Types.PCharRecord): ShortInt;
var
  ts: Byte;
begin
  StrDamageAdjust := 0;
  ts := AbilAdj.TranslatedStrength(creature);
  if creature^.useStrength <> 0 then
    case ts of
      1..2: StrDamageAdjust := -2;
      3..5: StrDamageAdjust := -1;
      16: StrDamageAdjust := 1;
      17..19: StrDamageAdjust := ts - 16;
      20..29: StrDamageAdjust := ts - 17;
      30: StrDamageAdjust := 14;
    end;
end;

{ Strength's encumbrance allowance in coins; translated strength 1..7 gives a negative allowance, while 0 gives zero.
  Strength 19 (translated 24) gets the AD&D 4500, not the 4000 its neighbours' formula gives. }
function WeightAllowance(creature: Types.PCharRecord): Integer;
var
  ts: Byte;
begin
  ts := AbilAdj.TranslatedStrength(creature);
  case ts of
    1..3: WeightAllowance := -350;
    4..5: WeightAllowance := -250;
    6..7: WeightAllowance := -150;
    12..13: WeightAllowance := 100;
    14..15: WeightAllowance := 200;
    16: WeightAllowance := 350;
    17..21: WeightAllowance := (ts - 17) * 250 + 500;
    22, 23, 25, 26: WeightAllowance := (ts - 22) * 1000 + 2000;
    24: WeightAllowance := 4500;
    27: WeightAllowance := 7500;
    28..30: WeightAllowance := (ts - 28) * 3000 + 9000;
  else
    WeightAllowance := 0;
  end;
end;

function ConSaveBonus(con: Byte): Byte;
begin
  ConSaveBonus := Word(con) * 2 div 7;
end;

function ConPoisonSave(con: Byte): Byte;
begin
  case con of
    19, 20: ConPoisonSave := 1;
    21, 22: ConPoisonSave := 2;
    23, 24: ConPoisonSave := 3;
    25..255: ConPoisonSave := 4;
  else
    ConPoisonSave := 0;
  end;
end;

function ConRegenMinutes(con: Byte): Word;
begin
  if con < 20 then
    ConRegenMinutes := 0
  else if con > 25 then
    ConRegenMinutes := 10
  else
    ConRegenMinutes := (26 - con) * 10;
end;

function ConResurrectionSurvival(con: Byte): Byte;
begin
  if con <= 3 then
    ConResurrectionSurvival := 40
  else if con <= 12 then
    ConResurrectionSurvival := 40 + (con - 3) * 5
  else if con < 18 then
    ConResurrectionSurvival := 90 + (con - 13) * 2
  else
    ConResurrectionSurvival := 100;
end;

function ClampScore(score: Integer): Byte;
begin
  if score < SCORE_MIN then
    ClampScore := SCORE_MIN
  else if score > SCORE_MAX then
    ClampScore := SCORE_MAX
  else
    ClampScore := score;
end;

end.
