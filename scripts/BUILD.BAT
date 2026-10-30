@echo off
rem Standalone DOS build for a source tree copied to C:\POR-SRC.
rem Run this batch file inside DOSBox or DOSBox-X, never from Windows.
rem
rem BUILD.BAT [TP50 | TP6-1991]
rem
rem With no argument, TP6-1991 is used when it is installed; otherwise TP50.

if not exist FIXMAIN.PAS goto wrongdir
if not exist C:\TASM\TASM.EXE goto notasm

if "%1"=="TP50" goto tp50
if "%1"=="TP6-1991" goto tp6
if exist C:\TP6-1991\TPC.EXE goto tp6
if exist C:\TP50\TPC.EXE goto tp50
goto notp

:tp50
if not exist C:\TP50\TPC.EXE goto notp50
set TP=C:\TP50
set PACK=NO
goto toolsready

:tp6
if not exist C:\TP6-1991\TPC.EXE goto notp6
if not exist C:\EXEPACK\EXEPACK.EXE goto nopack
set TP=C:\TP6-1991
set PACK=YES

:toolsready
if not exist OBJ\NUL md OBJ
if not exist LOGS\NUL md LOGS

rem Current sources display a build identifier. Historical SSI sources ignore it.
echo const>BUILDID.INC
echo   BUILD_VERSION = 'MANUAL';>>BUILDID.INC
echo   BUILD_COMMIT = 'DOSBOX';>>BUILDID.INC

if exist *.TPU del *.TPU
if exist *.OBJ del *.OBJ
if exist OBJ\*.TPU del OBJ\*.TPU
if exist OBJ\*.OBJ del OBJ\*.OBJ
if exist OBJ\FIXMAIN.EXE del OBJ\FIXMAIN.EXE
if exist OBJ\FIXMAIN.OVR del OBJ\FIXMAIN.OVR
if exist OBJ\FIXMAIN.MAP del OBJ\FIXMAIN.MAP
if exist OBJ\START.EXE del OBJ\START.EXE
if exist OBJ\GAME.OVR del OBJ\GAME.OVR
if exist OBJ\POOLCFG.EXE del OBJ\POOLCFG.EXE

echo Assembling SOUNDDRV.ASM...
C:\TASM\TASM SOUNDDRV,OBJ\SOUNDDRV > LOGS\TASM.OUT
if errorlevel 1 goto tasmfail

echo Compiling FIXMAIN.PAS...
path %TP%
TPC FIXMAIN.PAS /B /EOBJ /OOBJ > LOGS\TPC.OUT
if errorlevel 1 goto tpcfail
if not exist OBJ\FIXMAIN.EXE goto tpcfail
if not exist OBJ\FIXMAIN.OVR goto tpcfail
ren OBJ\FIXMAIN.OVR GAME.OVR

if "%PACK%"=="YES" goto pack
ren OBJ\FIXMAIN.EXE START.EXE
goto config

:pack
echo Packing START.EXE...
C:\EXEPACK\EXEPACK OBJ\FIXMAIN.EXE OBJ\START.EXE > LOGS\PACK.OUT
if errorlevel 1 goto packfail
if not exist OBJ\START.EXE goto packfail

:config
if not exist POOLCFG.PAS goto done
echo Compiling POOLCFG.PAS...
TPC POOLCFG.PAS /B /EOBJ /OOBJ > LOGS\TPCCFG.OUT
if errorlevel 1 goto cfgfail
if not exist OBJ\POOLCFG.EXE goto cfgfail

:done
echo.
echo Build complete. The finished files are in C:\POR-SRC\OBJ.
echo Copy START.EXE and GAME.OVR to a backed-up Pool of Radiance install.
if exist OBJ\POOLCFG.EXE echo Copy POOLCFG.EXE too.
goto end

:wrongdir
echo BUILD.BAT must be run from C:\POR-SRC, beside FIXMAIN.PAS.
goto failed
:notasm
echo C:\TASM\TASM.EXE was not found.
goto failed
:notp
echo No supported Turbo Pascal compiler was found.
echo Install TP 5.0 in C:\TP50 or TP 6.0 with the 1991 RTL in C:\TP6-1991.
goto failed
:notp50
echo C:\TP50\TPC.EXE was not found.
goto failed
:notp6
echo C:\TP6-1991\TPC.EXE was not found.
goto failed
:nopack
echo C:\EXEPACK\EXEPACK.EXE was not found.
goto failed
:tasmfail
echo TASM failed. Read LOGS\TASM.OUT.
goto failed
:tpcfail
echo The game did not compile. Read LOGS\TPC.OUT.
goto failed
:packfail
echo EXEPACK failed. Read LOGS\PACK.OUT.
goto failed
:cfgfail
echo POOLCFG did not compile. Read LOGS\TPCCFG.OUT.
goto failed

:failed
echo Build failed.

:end
set TP=
set PACK=
