{ Introduction, credits and title screens, with delays that can be interrupted by a keypress. }
{$O+,F+}
{$I COMPILER.INC}
unit Intro;

interface

procedure Introduction;

implementation

uses Types, GameDefs, GameVars, Crt, TextRend, Blit, Border, C_SOUND, SoundDrv, FileUtil
  {$IFDEF FPC}, TpRand, GameDirs{$ENDIF};

const
  { Give title picture 2 a one-in-FLASH_TICKS chance to flash on each 18.2 Hz
    timer tick, averaging about 16 seconds. SSI tied this to loop speed, which
    made native builds flash too slowly and fast DOS machines flash too often
    (#1011). }
  FLASH_TICKS = 290;

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

  TextRend.DisplayCentered(0, 39, 6, LightCyan, GameDefs.GAME_VERSION);
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
  TextRend.DelayOrKey(10);
end;

{ Runs the introduction sequence. RAVFULL.DAX is optional; the title and credit
  screens continue without it. In full-intro mode the second title picture
  occasionally flashes its EGA palette. A key skips the current and remaining
  screens, then FixMain discards it. }
procedure Introduction;
var
  pic: Types.PImgBuf;
  i: Byte;
  savedDir: Types.TPathStr;
  deadline: LongInt;
  now: LongInt;
  last: LongInt;
begin
  pic := nil;
  savedDir := GameVars.gameDir;
  GameVars.gameDir[0] := #0;
{$IFDEF FPC}
  { natively from beside the program, where the release zip puts it, else the data folder (#1064) }
  GameVars.gameDir := GameDirs.OwnFolder('RAVFULL.DAX');
{$ENDIF}
  { Brazen Crows, when its picture is there: it is not one of the game's own files, so without it the introduction goes
    straight on to the title rather than asking for a disk }
  if FileUtil.Exists(GameVars.gameDir + 'RAVFULL.DAX') then begin
    Blit.LoadPic('RAVFULL', 1, False, 0, pic);
    Blit.ShowPic(0, 0, pic);
    TextRend.DelayOrKey(2);
  end;
{$IFDEF FPC}
  GameVars.gameDir[0] := #0;
{$ENDIF}

  Blit.LoadPic('title', 1, False, 0, pic);
  Blit.ShowPic(0, 0, pic);
  { the title theme plays on under the credits, and FixMain ends it at the main menu (#1070) }
  SoundDrv.PlayMusic(C_SOUND.MUSIC_TITLE);
  TextRend.DelayOrKey(5);
  if not GameVars.fullIntro then begin
    GameVars.gameDir := savedDir;
    Blit.FreePic(pic);
    Exit;
  end;
  Blit.LoadPic('title', 2, False, 0, pic);
  GameVars.gameDir := savedDir;
  Blit.ShowPic(0, 0, pic);
  Blit.FreePic(pic);
  last := TextRend.GetTicks;
  deadline := last + 500;
  repeat
    now := TextRend.GetTicks;
    { a new timer tick: GetTicks counts in hundredths, so it moves only with the tick count }
    if now <> last then begin
      last := now;
      if Blit.HasPalette and (Random(FLASH_TICKS) = 0) then
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
    { a reading below the start means the tick count restarted at midnight }
  until KeyPressed or (now >= deadline) or (now < deadline - 500);
  Intro.Credits;
end;

end.
