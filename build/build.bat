@echo off
rem Build Pool of Radiance from src, including sounddrv.asm, and pack START.EXE.
rem build.sh runs this batch from e:\src with D: Turbo Pascal, E: the
rem repository root, F: TASM and G: EXEPACK. It creates e:\obj for outputs.
rem Keep PATH at the compiler root to avoid DOS 8.3 directory aliases.
rem Remove stale units and objects from both source and output directories.
if exist *.TPU del *.TPU
if exist *.OBJ del *.OBJ
if exist e:\obj\*.TPU del e:\obj\*.TPU
if exist e:\obj\*.OBJ del e:\obj\*.OBJ
if exist e:\obj\FIXMAIN.EXE del e:\obj\FIXMAIN.EXE
if exist e:\obj\FIXMAIN.OVR del e:\obj\FIXMAIN.OVR
if exist e:\obj\FIXMAIN.MAP del e:\obj\FIXMAIN.MAP
if exist e:\obj\START.EXE del e:\obj\START.EXE
if exist e:\obj\GAME.OVR del e:\obj\GAME.OVR
f:\tasm sounddrv,e:\obj\sounddrv > e:\build\logs\TASM.OUT
rem  The trace build of the sequencer, for the tests (tests\sndtrc.pas): its port writes go to a buffer.
f:\tasm /dTRACE sounddrv,e:\obj\sndtrace >> e:\build\logs\TASM.OUT
path d:\
tpc fixmain.pas /B /E..\obj /O..\obj > e:\build\logs\TPC.OUT
rem  TPC names the overlay after the root; SSI shipped it as GAME.OVR.
ren e:\obj\FIXMAIN.OVR GAME.OVR
g:\exepack e:\obj\FIXMAIN.EXE e:\obj\START.EXE > e:\build\logs\PACK.OUT
