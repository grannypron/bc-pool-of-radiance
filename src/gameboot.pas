{ Startup configuration: initialize the overlay manager, read POOL.CFG, select the video mode and reserve graphics
  memory. }
{$O+,F+,I-}
unit GameBoot;

interface

uses Types, C_Sound, GDConsts, GDVars, Crt, Dos, Overlay, DaxIo, GameIo, TextRend, Blit, SoundDrv;

implementation

const
  { graphics memory reserve: 16 KB in paragraphs }
  GFX_RESERVE_PARAS = 1024;
  OVERLAY_BUF_BYTES = 100352;

var
  freePtrW: Types.TFreePtrW absolute FreePtr;
  { free-range table front -- Move source }
  freeRangeHead: Types.PFreeRange absolute FreePtr;
  { 0=CGA 1=EGA 2=Tandy }
  displayMode: Types.TVideoMode absolute GDVars.videoMode;
  { POOL.CFG line 5 = 'F' }
  fullIntro: Boolean absolute GDVars.fullIntro;
  { Receives the FreePtr snapshot published to other units }
  gfxReserve: Pointer absolute GDVars.dsReservedGraphicalAreaPtr;

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
      { Move the free-list entry at FreePtr down by GFX_RESERVE_PARAS paragraphs, keeping its offset, then repoint
        FreePtr at the copy }
      GDVars.gfxRelocDest := Ptr(freePtrW.s - GFX_RESERVE_PARAS, freePtrW.o);
      Move(freeRangeHead^, GDVars.gfxRelocDest^, SizeOf(Types.TFreeRange));
      FreePtr := GDVars.gfxRelocDest;
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
  { Set the minimum free-list size and publish FreePtr to other units through gfxReserve }
  freePtrW.freeMin := 80;
  gfxReserve := FreePtr;
  SoundDrv.SoundSuspend;
  ReadLn(GDVars.cfgText, GDVars.gameDir);
  GDVars.gameDir := GDVars.gameDir;
  ReadLn(GDVars.cfgText, GDVars.dsSaveDirectory);
  GDVars.dsSaveDirectory := GDVars.dsSaveDirectory;
  ReadLn(GDVars.cfgText, GDVars.cfgChar);
  if GDVars.cfgChar = 'F' then
    fullIntro := True
  else
    fullIntro := False;
  Close(GDVars.cfgText);
end.
