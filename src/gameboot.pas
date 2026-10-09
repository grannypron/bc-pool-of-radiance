{ Startup configuration: initialize the overlay manager, read POOL.CFG, select the video mode and reserve graphics
  memory. }
{$O+,F+,I-}
unit GameBoot;

interface

uses Types, C_Sound, GDConsts, GDVars, Crt, Dos, Overlay, TextRend, Blit, SoundDrv;

implementation

const
  { graphics memory reserve: 16 KB in paragraphs }
  GFX_RESERVE_PARAS = 1024;
  OVERLAY_BUF_BYTES = 100352;

var
  heapEndW: Types.THeapEndW absolute HeapEnd;
  { 0=CGA 1=EGA 2=Tandy }
  displayMode: Types.TVideoMode absolute GDVars.videoMode;
  { POOL.CFG line 5 = 'F' }
  fullIntro: Boolean absolute GDVars.fullIntro;

{ A POOL.CFG path made ready for file names to be appended: spaces trimmed, the current drive (or, for a relative path,
  the current directory) put in front of a path without a drive letter, and a closing backslash. An empty path gives
  the current directory, and a drive alone (C:) the current directory on that drive. A path that leaves no room for a
  file name within a DOS path (Types.TPathStr; the longest names, such as WALLDEF1.DAX, are 12 characters) stops the
  game with a message. }
function NormalizePath(path: String): String;
const
  LONGEST_NAME = 12;
var
  cur: String;
begin
  while (Length(path) > 0) and (path[1] = ' ') do
    Delete(path, 1, 1);
  while (Length(path) > 0) and (path[Length(path)] = ' ') do
    Dec(path[0]);
  if (Length(path) = 2) and (path[2] = ':') then
    GetDir(Ord(UpCase(path[1])) - Ord('A') + 1, path)
  else begin
    GetDir(0, cur);
    if cur[Length(cur)] <> '\' then cur := cur + '\';
    if (Length(path) < 2) or (path[2] <> ':') then
      if (Length(path) > 0) and (path[1] = '\') then
        path := Copy(cur, 1, 2) + path
      else
        path := cur + path;
  end;
  if path[Length(path)] <> '\' then path := path + '\';
  if Length(path) > SizeOf(Types.TPathStr) - 1 - LONGEST_NAME then begin
    Blit.RestoreVideoMode;
    WriteLn('POOL.CFG: this path is too long for DOS:');
    WriteLn(path);
    Halt;
  end;
  NormalizePath := path;
end;

{ Game startup runs through this unit's initialization section. }
begin
  DaxIo.OverlayPrompt;
  OvrInit('GAME.OVR');
  repeat
    Assign(GDVars.cfgFile, 'pool.cfg');
    Reset(GDVars.cfgFile, 128);
    GDVars.cfgErr := IOResult;
    if GDVars.cfgErr <> 0 then begin
      WriteLn('Please insert startup disk.');
      GDVars.cfgChar := GameIo.ReadGameKey;
    end;
  until GDVars.cfgErr = 0;
  Close(GDVars.cfgFile);
  CheckBreak := False;
  Assign(GDVars.cfgText, 'POOL.CFG');
  Reset(GDVars.cfgText);
  if IOResult <> 0 then begin
    WriteLn('Unable to find POOL.CFG');
    Halt;
  end;
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  { INT 10h AH=0Fh: get current video mode into AL }
  GDVars.dsInterruptRegisters.ah := $F;
  Intr($10, GDVars.dsInterruptRegisters);
  GDVars.savedVideoMode := GDVars.dsInterruptRegisters.al;
  GDVars.curVideoMode := GDVars.savedVideoMode;
  case GDVars.cfgChar of
    'E': begin
      displayMode := Types.vmEGA;
      Blit.SetVideoMode(13);
      GDVars.pageMain := 0;
      GDVars.pageNum := 0;
      TextRend.SetupEgaCurrentPage(GDVars.pageMain);
      TextRend.SetupEgaOtherPage(GDVars.pageNum);
    end;
    'T': begin
      displayMode := Types.vmTandy;
      { Lower HeapEnd by GFX_RESERVE_PARAS; the common code after the sound setting lowers it once more, so Tandy
        reserves twice as much }
      GDVars.gfxReserve := Ptr(heapEndW.s - GFX_RESERVE_PARAS, heapEndW.o);
      HeapEnd := GDVars.gfxReserve;
      Blit.SetVideoMode(9);
    end;
    else begin
      displayMode := Types.vmCGA;
      Blit.SetVideoMode(4);
    end;
  end;
  if OVERLAY_BUF_BYTES - OvrGetBuf <= MemAvail then
    OvrSetBuf(OVERLAY_BUF_BYTES)
  else begin
    Blit.RestoreVideoMode;
    WriteLn('Not enough memory to run game.  You need ', OVERLAY_BUF_BYTES - OvrGetBuf, ' more bytes.');
    Halt;
  end;
  if OvrResult <> 0 then begin
    Blit.RestoreVideoMode;
    WriteLn('Overlay error, program abort!');
    Halt;
  end;
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  case GDVars.cfgChar of
    'T': GDVars.soundMode := C_Sound.MODE_TANDY;
    'P': GDVars.soundMode := C_Sound.MODE_SPEAKER;
    else GDVars.soundMode := C_Sound.MODE_DISABLED;
  end;
  { Lower HeapEnd by GFX_RESERVE_PARAS (16 KB) and record the new limit in gfxReserve }
  GDVars.gfxReserve := Ptr(heapEndW.s - GFX_RESERVE_PARAS, heapEndW.o);
  HeapEnd := GDVars.gfxReserve;
  SoundDrv.SoundSuspend;
  ReadLn(GDVars.cfgText, GDVars.gameDir);
  GDVars.gameDir := NormalizePath(GDVars.gameDir);
  ReadLn(GDVars.cfgText, GDVars.dsSaveDirectory);
  GDVars.dsSaveDirectory := NormalizePath(GDVars.dsSaveDirectory);
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  if GDVars.cfgChar = 'F' then
    fullIntro := True
  else
    fullIntro := False;
  Close(GDVars.cfgText);
end.
