{ Startup configuration: initialize the overlay manager, read POOL.CFG, select the video mode and reserve graphics
  memory. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit GameBoot;

interface

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Types, C_Sound, GDConsts, GDVars, Crt, Dos, {$IFNDEF FPC}Overlay, {$ENDIF}Blit,
  SoundDrv, DaxIo, GameIo, {$IFNDEF FPC}VidCga, VidEga, VidTdy, {$ENDIF}VidVga,
  {$IFDEF FPC}SndDig{$ELSE}SndTdy{$ENDIF}, SndSpk, {$IFNDEF FPC}SndOpl, SndSb, {$ENDIF}SndNone
  {$IFDEF FPC}, Host, NatFile{$ENDIF};

var
  { lowered HeapEnd snapshot }
  gfxReserve: Pointer;
  { POOL.CFG character input }
  cfgChar: Char;
  { POOL.CFG text input }
  cfgText: Text;

const
  { graphics memory reserve: 16 KB in paragraphs }
  GFX_RESERVE_PARAS = 1024;
  OVERLAY_BUF_BYTES = 100352;

{ The native build has no overlays, no EMS and no HeapEnd to lower: its heap grows as it needs. }
{$IFNDEF FPC}
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
{$ENDIF}

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

{$IFDEF FPC}
{ POOL.CFG's folders are a DOS install's (C:\POOLRAD\ and C:\POOLRAD\SAVE\). Natively the game is the current folder
  (the one NatFile.EnterGameFolder found), and the saves the folder POOL.CFG names inside the game's (SAVE\), or SAVE\ when it
  names one elsewhere. NatFile turns the backslashes into the system's separator as each file is opened. }
procedure NativeFolders(var gameDir, saveDir: String);
var
  game: String;
  save: String;
begin
  game := NormalizePath(gameDir);
  save := NormalizePath(saveDir);
  GetDir(0, gameDir);
  if gameDir[Length(gameDir)] <> '/' then
    gameDir := gameDir + '/';
  if (Length(save) > Length(game)) and NatFile.SameName(Copy(save, 1, Length(game)), game) then
    saveDir := gameDir + Copy(save, Length(game) + 1, 255)
  else
    saveDir := gameDir + 'SAVE\';
end;
{$ENDIF}

{ Game startup runs through this unit's initialization section. }
begin
  GDVars.stingArg := ParamStr(1) = 'STING';
{$IFDEF FPC}
  NatFile.EnterGameFolder;
  GDVars.ovrInEms := False;
{$ELSE}
  DaxIo.OverlayPrompt;
  OvrInit('GAME.OVR');
  { Copy the overlays into EMS when there is enough of it, so they load from memory rather than disk; without an EMS
    driver, or with too little EMS, they keep loading from GAME.OVR. This comes before CountOvrRead hooks in, since
    OvrInitEMS installs its own reader for CountOvrRead to call. }
  OvrInitEMS;
  GDVars.ovrInEms := OvrResult = ovrOk;
  GDVars.ovrLoads := 0;
  GDVars.picBytes := 0;
  GDVars.picPeak := 0;
  ovrRead := OvrReadBuf;
  OvrReadBuf := CountOvrRead;
{$ENDIF}
  { a read-only POOL.CFG is there too (DaxIo.FileExists) }
  while not DaxIo.FileExists('pool.cfg') do begin
    WriteLn('Please insert startup disk.');
    cfgChar := GameIo.ReadAnyKey;
  end;
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
  { the video driver for POOL.CFG's mode: E for EGA, T for Tandy, V for VGA, anything else CGA; natively VGA, which
    shows EGA's colours }
{$IFDEF FPC}
  VidVga.Install;
{$ELSE}
  case cfgChar of
    'E': VidEga.Install;
    'T': VidTdy.Install;
    'V': VidVga.Install;
  else
    VidCga.Install;
  end;
  { Keep a screen that lives in system RAM (Tandy's) out of the heap: lower HeapEnd by it. The common code after the
    sound setting lowers HeapEnd by GFX_RESERVE_PARAS once more, so Tandy reserves twice as much. }
  if GDVars.video.ramVideoParas > 0 then begin
    gfxReserve := Ptr(heapEndW.s - GDVars.video.ramVideoParas, heapEndW.o);
    HeapEnd := gfxReserve;
  end;
{$ENDIF}
  Blit.SetVideoMode(GDVars.video.biosMode);
  GDVars.video.Start;
{$IFNDEF FPC}
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
{$ENDIF}
  ReadLn(cfgText, cfgChar);
  { the sound driver POOL.CFG names: T Tandy, P the speaker, A AdLib music and speaker effects, S a Sound Blaster's
    recorded effects with its AdLib music (each falling back to the next when its card does not answer), anything else
    none }
  case cfgChar of
{$IFDEF FPC}
    { natively, the Tandy's music and the Sound Blaster's recorded effects for any of the three (SndDig) }
    'T', 'A', 'S': SndDig.Install;
    'P': SndSpk.Install;
{$ELSE}
    'T': SndTdy.Install;
    'P': SndSpk.Install;
    'A': SndOpl.Install;
    'S': SndSb.Install;
{$ENDIF}
  else
    SndNone.Install;
  end;
  GDVars.soundMode := GDVars.sound.mode;
  { Lower HeapEnd by GFX_RESERVE_PARAS (16 KB) and record the new limit in gfxReserve }
{$IFNDEF FPC}
  gfxReserve := Ptr(heapEndW.s - GFX_RESERVE_PARAS, heapEndW.o);
  HeapEnd := gfxReserve;
{$ENDIF}
  SoundDrv.SoundSuspend;
  ReadLn(cfgText, GDVars.gameDir);
  ReadLn(cfgText, GDVars.dsSaveDirectory);
{$IFDEF FPC}
  NativeFolders(GDVars.gameDir, GDVars.dsSaveDirectory);
{$ELSE}
  GDVars.gameDir := NormalizePath(GDVars.gameDir);
  GDVars.dsSaveDirectory := NormalizePath(GDVars.dsSaveDirectory);
{$ENDIF}
  ReadLn(cfgText, cfgChar);
  if cfgChar = 'F' then
    GDVars.fullIntro := True
  else
    GDVars.fullIntro := False;
  Close(cfgText);
end.
