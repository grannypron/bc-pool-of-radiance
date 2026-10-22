{ Tests that GDVars' variables start at zero (#826). Turbo Pascal clears no variable, so under DOSBox-X, where the test
  programs before this one have dirtied the memory it runs in, the variables hold that memory's bytes unless GDVars'
  initialization clears them; Free Pascal clears them itself. Under Turbo Pascal every byte from the first variable
  (video) through the last (inEncMenu) is checked, and on both builds the lists and flags the game walks or tests
  first. }
{$I COMPILER.INC}
program TGdVars;

uses GDVars, TestKit;

{$IFNDEF FPC}
var
  n: Word;
  nonzero: Word;
{$ENDIF}

begin
  TestKit.Start('TGDVARS');
{$IFNDEF FPC}
  nonzero := 0;
  for n := Ofs(GDVars.video) to Ofs(GDVars.inEncMenu) + SizeOf(GDVars.inEncMenu) - 1 do
    if Mem[Seg(GDVars.video):n] <> 0 then
      Inc(nonzero);
  TestKit.CheckEqualsL(0, nonzero, 'every byte from video through inEncMenu is zero');
{$ENDIF}
  TestKit.Check(GDVars.creatureList = nil, 'there is no creature list');
  TestKit.Check(GDVars.stinkHead = nil, 'no Stinking Cloud list');
  TestKit.Check(GDVars.eclStackTopPtr = nil, 'no script return stack');
  TestKit.Check(GDVars.treasureItems = nil, 'no treasure');
  TestKit.CheckEqualsL(0, GDVars.pageMain, 'the screen is page 0');
  TestKit.CheckEqualsL(0, GDVars.downedCount, 'no one is down');
  TestKit.CheckEqualsL(0, GDVars.inEncMenu, 'no encounter menu is open');
  TestKit.Done;
end.
