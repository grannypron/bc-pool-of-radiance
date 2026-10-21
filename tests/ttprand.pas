{ Tests TpRand, the native build's Turbo Pascal random numbers. Under Turbo Pascal it checks them against System's own,
  for several seeds and ranges, which is what proves them; under either compiler it checks the numbers Turbo Pascal
  gives from seed 1 (NORAND's), worked out from its formula: Random(100) ten times, and the seed after 1000 steps. }
{$I COMPILER.INC}
program TTpRand;

uses TpRand, TestKit;

const
  SEEDS: array[1..4] of LongInt = (1, 12345, -1, $7FFFFFFF);
  RANGES: array[1..10] of Word = (1, 2, 4, 6, 20, 100, 256, 1000, 10000, 65535);
  { from seed 1: Turbo Pascal 6 gave the first five so in a probe run in DOSBox-X, and the formula the rest }
  FROM_ONE: array[1..10] of Word = (56, 29, 76, 86, 17, 85, 3, 95, 96, 74);

var
  i: Word;
  k: Byte;
  r: Byte;
  same: Boolean;

begin
  TestKit.Start('TTPRAND');
{$IFNDEF FPC}
  for k := 1 to 4 do
    for r := 1 to 10 do begin
      System.RandSeed := SEEDS[k];
      TpRand.RandSeed := SEEDS[k];
      same := True;
      for i := 1 to 200 do
        same := same and (System.Random(RANGES[r]) = TpRand.Random(RANGES[r]));
      TestKit.Check(same and (System.RandSeed = TpRand.RandSeed), 'Random matches System.Random');
    end;
{$ENDIF}
  TpRand.RandSeed := 1;
  for i := 1 to 10 do
    TestKit.CheckEqualsL(FROM_ONE[i], TpRand.Random(100), 'Random(100) from seed 1');
  TestKit.CheckEqualsL(352239543, TpRand.RandSeed, 'the seed after ten');
  TpRand.RandSeed := 1;
  for i := 1 to 1000 do
    r := TpRand.Random(6);
  TestKit.CheckEqualsL(-1959460871, TpRand.RandSeed, 'the seed after 1000');
  TestKit.CheckEqualsL(0, TpRand.Random(0), 'Random(0) is 0');
  TestKit.Done;
end.
