Pool of Radiance for Windows
============================

This is SSI's Pool of Radiance, rebuilt as a Windows program, with
this project's fixes and features. The game's data is not included:
it reads it from your own copy (GOG's or Steam's), which it finds by
itself. Your copy only needs to be installed; you don't need to run
it.

poolrad.exe is the game and poolcfg.exe the set-up program. The x64
build is for 64-bit Windows; the x86 build runs on 32-bit Windows
too.


Starting it
-----------

Unpack this folder anywhere and run poolrad.exe. Keep SDL3.dll beside
it: the game does not start without it. Windows may warn that it does
not know the program (it is not signed): choose More info, then Run
anyway.

Closing the window or pressing Alt-F4 asks before quitting: progress
since your last save is lost.

Run poolcfg.exe from a Command Prompt or PowerShell window to choose
the video and sound, the introduction, every setting on the Settings
screen, and the data and save folders. The game does not need it:
with no POOL.CFG it plays with the defaults.


Finding the game's data
-----------------------

At start the game takes the first of these that holds the data
(GEO1.DAX):

  1. A folder given with --data-folder (below).
  2. The folder you start it from, then the folder poolrad.exe is
     in, as when this zip is unpacked into a copy of the game's
     folder.
  3. The folder found or chosen the last time.
  4. The stores' own folders:
       Steam:  Forgotten Realms: The Archives - Collection Two, in
               each of Steam's libraries
       GOG:    the folder GOG Galaxy installed it in, C:\GOG Games,
               and GOG's folders under Program Files (x86)
       Heroic: %USERPROFILE%\Games\Heroic
     One copy found is used and remembered. With several, the game
     lists them and you pick one.
  5. With none, the game opens a folder picker: choose the folder
     that holds GEO1.DAX. Cancelling it quits.

To choose again, or to give the folder yourself, start it from a
Command Prompt:

  poolrad.exe --choose-data-folder
  poolrad.exe --data-folder "C:\path\to\POOLRAD"


Where your games are saved
--------------------------

When the data is anywhere but beside poolrad.exe (in Steam's or GOG's
folder, or a folder you chose), the game writes nothing there. Saved
games, settings (POOLOPT.CFG), the Bestiary, the combined data files
it builds on its first start, and DATABLD.LOG go to

  %APPDATA%\Pool of Radiance\

(saved games in its SAVE folder). When poolrad.exe sits in a game
folder it may write to, they go in that folder, as with the DOS
version.


This release's own files
------------------------

RAVFULL.DAX (the title picture) and SBSFX.DAT (the Sound Blaster's
recorded effects) are this release's own data files, not SSI's. Keep
them beside poolrad.exe. Without them the game shows SSI's title and
plays the speaker's effects.

SHA256.TXT holds the SHA-256 of each file.
