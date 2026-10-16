{ Startup configuration: initialize the overlay manager, read POOL.CFG, select the video mode and reserve graphics
  memory. }
{$O+,F+,I-}
unit GameBoot;

interface

implementation

uses Types, C_Sound, GDConsts, GDVars, Crt, Dos, Overlay, TextRend, Blit, SoundDrv, DaxIo, GameIo;

var
  { lowered HeapEnd snapshot }
  gfxReserve: Pointer;
  { POOL.CFG character input }
  cfgChar: Char;
  { POOL.CFG text input }
  cfgText: Text;
  { POOL.CFG existence check }
  cfgFile: file;
  { low byte of the existence-check IOResult }
  cfgErr: Byte;

const
  { graphics memory reserve: 16 KB in paragraphs }
  GFX_RESERVE_PARAS = 1024;
  OVERLAY_BUF_BYTES = 100352;

var
  heapEndW: Types.THeapEndW absolute HeapEnd;
  { the overlay manager's own read routine, which CountOvrRead calls }
  ovrRead: OvrReadFunc;

{ The overlay manager's read routine (OvrReadBuf), counting each overlay it loads in GDVars.ovrLoads (#612). }
function CountOvrRead(ovrSeg: Word): Integer;
begin
  Inc(GDVars.ovrLoads);
  CountOvrRead := ovrRead(ovrSeg);
end;

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
  GDVars.stingArg := ParamStr(1) = 'STING';
  DaxIo.OverlayPrompt;
  OvrInit('GAME.OVR');
  GDVars.ovrLoads := 0;
  ovrRead := OvrReadBuf;
  OvrReadBuf := CountOvrRead;
  repeat
    Assign(cfgFile, 'pool.cfg');
    Reset(cfgFile, 128);
    cfgErr := IOResult;
    if cfgErr <> 0 then begin
      WriteLn('Please insert startup disk.');
      cfgChar := GameIo.ReadGameKey;
    end;
  until cfgErr = 0;
  Close(cfgFile);
  CheckBreak := False;
  Assign(cfgText, 'POOL.CFG');
  Reset(cfgText);
  if IOResult <> 0 then begin
    WriteLn('Unable to find POOL.CFG');
    Halt;
  end;
  ReadLn(cfgText, cfgChar);
  { INT 10h AH=0Fh: get current video mode into AL }
  GDVars.dsInterruptRegisters.ah := $F;
  Intr($10, GDVars.dsInterruptRegisters);
  GDVars.savedVideoMode := GDVars.dsInterruptRegisters.al;
  GDVars.curVideoMode := GDVars.savedVideoMode;
  case cfgChar of
    'E': begin
      GDVars.videoMode := Types.vmEGA;
      Blit.SetVideoMode(13);
      GDVars.pageMain := 0;
      GDVars.pageNum := 0;
      TextRend.SetupEgaCurrentPage(GDVars.pageMain);
      TextRend.SetupEgaOtherPage(GDVars.pageNum);
    end;
    'T': begin
      GDVars.videoMode := Types.vmTandy;
      { Lower HeapEnd by GFX_RESERVE_PARAS; the common code after the sound setting lowers it once more, so Tandy
        reserves twice as much }
      gfxReserve := Ptr(heapEndW.s - GFX_RESERVE_PARAS, heapEndW.o);
      HeapEnd := gfxReserve;
      Blit.SetVideoMode(9);
    end;
    else begin
      GDVars.videoMode := Types.vmCGA;
      Blit.SetVideoMode(4);
    end;
  end;
  if OVERLAY_BUF_BYTES - OvrGetBuf <= MemAvail then begin
    OvrSetBuf(OVERLAY_BUF_BYTES);
    { probation (#612): an overlay called while it sits in the last third of the buffer is kept rather than dropped,
      so the units a stretch of play keeps calling stay loaded }
    OvrSetRetry(OvrGetBuf div 3);
  end else begin
    Blit.RestoreVideoMode;
    WriteLn('Not enough memory to run game.  You need ', OVERLAY_BUF_BYTES - OvrGetBuf, ' more bytes.');
    Halt;
  end;
  if OvrResult <> 0 then begin
    Blit.RestoreVideoMode;
    WriteLn('Overlay error, program abort!');
    Halt;
  end;
  ReadLn(cfgText, cfgChar);
  case cfgChar of
    'T': GDVars.soundMode := C_Sound.MODE_TANDY;
    'P': GDVars.soundMode := C_Sound.MODE_SPEAKER;
    else GDVars.soundMode := C_Sound.MODE_DISABLED;
  end;
  { Lower HeapEnd by GFX_RESERVE_PARAS (16 KB) and record the new limit in gfxReserve }
  gfxReserve := Ptr(heapEndW.s - GFX_RESERVE_PARAS, heapEndW.o);
  HeapEnd := gfxReserve;
  SoundDrv.SoundSuspend;
  ReadLn(cfgText, GDVars.gameDir);
  GDVars.gameDir := NormalizePath(GDVars.gameDir);
  ReadLn(cfgText, GDVars.dsSaveDirectory);
  GDVars.dsSaveDirectory := NormalizePath(GDVars.dsSaveDirectory);
  ReadLn(cfgText, cfgChar);
  if cfgChar = 'F' then
    GDVars.fullIntro := True
  else
    GDVars.fullIntro := False;
  Close(cfgText);
end.
