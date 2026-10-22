{ Introduction, credits and title screens, with delays that can be interrupted by a keypress. }
{$O+,F+}
{$I COMPILER.INC}
unit Intro;

interface

procedure Introduction;

implementation

uses Types, GDConsts, GameVars, Crt, TextRend, Blit, Border, C_SOUND, SoundDrv, DaxIo{$IFDEF FPC}, TpRand{$ENDIF};

{ Wait for the requested number of seconds or a keypress, whichever comes first. The key is left unread. }
procedure DelayOrKey(seconds: Word);
var
  start: LongInt;
  deadline: LongInt;
  now: LongInt;
begin
  start := TextRend.GetTicks;
  deadline := start + 100 * seconds;
  repeat
    now := TextRend.GetTicks;
    { a reading below the start means the tick count restarted at midnight }
  until (now >= deadline) or (now < start) or KeyPressed;
end;

{ Show the credits screen for 10 seconds or until a keypress; a key still pending from the title ends it at once. }
procedure Credits;
begin
  Border.DrawWindow(1, 1, 38, 3, 0, Black, '');
  Border.DrawWindow(1, 5, 38, 23, 0, Black, '');
  TextRend.DisplayString(5, 1, LightGreen, 'scenario created by:');
  TextRend.DisplayString(26, 1, Yellow, 'tsr, inc.');
  TextRend.DisplayString(15, 2, LightGreen, 'jim ward');
  TextRend.DisplayString(2, 3, LightGreen, 'david cook,steve winter,mike breault');
  TextRend.DisplayString(1, 5, LightGreen, 'game created by:');
  TextRend.DisplayString(18, 5, Yellow, 'ssi special projects');

  TextRend.DisplayCentered(0, 39, 6, LightCyan, GDConsts.GAME_VERSION);
  TextRend.DisplayString(2, 7, Yellow, 'programming:');
  TextRend.DisplayString(20, 7, Yellow, 'original');
  TextRend.DisplayString(2, 8, LightCyan, 'scot bayless');
  TextRend.DisplayString(20, 8, Yellow, 'programming:');
  TextRend.DisplayString(2, 9, LightCyan, 'brad myers');
  TextRend.DisplayString(20, 9, LightCyan, 'keith brors');
  TextRend.DisplayString(2, 10, LightCyan, 'russ brown');
  TextRend.DisplayString(20, 10, LightCyan, 'brad myers');
  TextRend.DisplayString(2, 11, LightCyan, 'ted greer');
  TextRend.DisplayString(2, 13, Yellow, 'graphic arts:');
  TextRend.DisplayString(20, 13, Yellow, 'encounter coding:');
  TextRend.DisplayString(2, 14, LightCyan, 'tom wahl');
  TextRend.DisplayString(20, 14, LightCyan, 'paul murray');
  TextRend.DisplayString(2, 15, LightCyan, 'fred butts');
  TextRend.DisplayString(20, 15, LightCyan, 'russ brown');
  TextRend.DisplayString(2, 16, LightCyan, 'darla marasco');
  TextRend.DisplayString(20, 16, LightCyan, 'victor penman');
  TextRend.DisplayString(2, 17, LightCyan, 'susan halbleib');
  TextRend.DisplayString(20, 17, LightCyan, 'dave shelley');
  TextRend.DisplayString(2, 19, Yellow, 'project manager');
  TextRend.DisplayString(20, 19, Yellow, 'developer:');
  TextRend.DisplayString(2, 20, LightCyan, 'victor penman');
  TextRend.DisplayString(20, 20, LightCyan, 'george mac donald');
  TextRend.DisplayString(2, 22, Yellow, 'testing:');
  TextRend.DisplayString(11, 22, LightCyan, 'joel billings,steve salyer');
  TextRend.DisplayString(2, 23, LightCyan, 'james kucera,robert daly,rick white');
  Intro.DelayOrKey(10);
end;

{ Show the Brazen Crows picture (RAVFULL.DAX, skipped when the file is missing) for 2 seconds, then TITLE picture 1 for
  5 seconds or until a key, with the game directory blanked while loading. With the full intro, show picture 2 for
  another 5 seconds, flashing EGA palette register 1 at random, then the credits. No screen reads the key, so one key
  ends the screen it is pressed on and every screen after it; FixMain discards it afterwards. }
procedure Introduction;
var
  pic: Types.PImgBuf;
  rndAcc: LongInt;
  i: Byte;
  savedDir: Types.TPathStr;
  deadline: LongInt;
  now: LongInt;
begin
  rndAcc := 0;
  pic := nil;
  savedDir := GameVars.gameDir;
  GameVars.gameDir[0] := #0;
  { Brazen Crows, when its picture is there: it is not one of the game's own files, so without it the introduction goes
    straight on to the title rather than asking for a disk }
  if DaxIo.FileExists(GameVars.gameDir + 'RAVFULL.DAX') then begin
    Blit.LoadPic('RAVFULL', 1, False, 0, pic);
    Blit.ShowPic(0, 0, pic);
    Intro.DelayOrKey(2);
  end;

  Blit.LoadPic('title', 1, False, 0, pic);
  Blit.ShowPic(0, 0, pic);
  { the title theme plays out by itself, under the credits or the menu }
  SoundDrv.PlayMusic(C_SOUND.MUSIC_TITLE);
  Intro.DelayOrKey(5);
  if not GameVars.fullIntro then begin
    GameVars.gameDir := savedDir;
    Blit.FreePic(pic);
    Exit;
  end;
  Blit.LoadPic('title', 2, False, 0, pic);
  GameVars.gameDir := savedDir;
  Blit.ShowPic(0, 0, pic);
  Blit.FreePic(pic);
  deadline := TextRend.GetTicks + 500;
  repeat
    if Blit.HasPalette then begin
      Inc(rndAcc, Random(4));
      if rndAcc > 50000 then begin
        rndAcc := 0;
        for i := 0 to Random(3) + 1 do begin
          Blit.SetPaletteRegister(1, LightBlue);
          Delay(150);
          Blit.SetPaletteRegister(1, LightCyan);
          Delay(100);
          Blit.SetPaletteRegister(1, White);
          Delay(50);
          Blit.SetPaletteRegister(1, LightCyan);
          Delay(100);
          Blit.SetPaletteRegister(1, LightBlue);
          Delay(150);
          Blit.SetPaletteRegister(1, Blue);
        end;
      end;
    end;
    now := TextRend.GetTicks;
    { a reading below the start means the tick count restarted at midnight }
  until KeyPressed or (now >= deadline) or (now < deadline - 500);
  Intro.Credits;
end;

end.
