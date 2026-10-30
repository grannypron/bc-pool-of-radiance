Pool of Radiance for Windows
============================

This is SSI's Pool of Radiance rebuilt as a native Windows program,
along with this project's fixes and extra features. It doesn't include
the original game data. Instead, it uses the data from your own GOG or
Steam copy and will usually find that copy for you. The original game
only needs to be installed; you don't have to run it first.

The game itself is poolrad.exe, and poolcfg.exe is the optional set-up
program. Use the x64 build on 64-bit Windows. The x86 build also runs on
32-bit Windows.


Getting started
---------------

Unpack this folder wherever you like, then run poolrad.exe. Keep
SDL3.dll beside it, or the game won't start. Because the program isn't
signed, Windows may warn that it doesn't recognize it. Choose More
info, then Run anyway.

If you close the window or press Alt-F4, the game asks before quitting.
Any progress since your last save will be lost.

For more control, run poolcfg.exe from Command Prompt or PowerShell. It
lets you choose the video and sound options, whether to play the
introduction, every option on the Settings screen, and the data and
save folders. You don't need to run it before playing: if there is no
POOL.CFG, the game simply uses the defaults.


How the game finds your data
----------------------------

When it starts, the game looks for GEO1.DAX in the following places and
uses the first matching data folder it finds:

  1. A folder supplied with --data-folder (see below).
  2. The folder you launched the game from, followed by the folder that
     contains poolrad.exe. This is useful if you unpacked the zip into
     your original game folder.
  3. The folder you found or chose the last time you played.
  4. The usual folders used by game stores:
       Steam:  Forgotten Realms: The Archives - Collection Two, in
               each of Steam's libraries
       GOG:    the folder GOG Galaxy installed it in, C:\GOG Games,
               and GOG's folders under Program Files (x86)
       Heroic: %USERPROFILE%\Games\Heroic
     If the game finds one copy, it uses that copy and remembers it. If
     it finds several, it shows you a list to choose from.
  5. If nothing has turned up, the game opens a folder picker. Choose
     the folder containing GEO1.DAX. Cancelling quits the game.

To choose a different copy later, or supply the folder yourself, open
Command Prompt and use:

  poolrad.exe --choose-data-folder
  poolrad.exe --data-folder "C:\path\to\POOLRAD"


Where your games are saved
--------------------------

If the game data isn't beside poolrad.exe--for example, if it's in a
Steam or GOG folder, or in a folder you chose--the game won't write
anything there. Saved games, settings (POOLOPT.CFG), the Bestiary, the
combined data files created on the first launch, and DATABLD.LOG are
stored in:

  %APPDATA%\Pool of Radiance\

Saved games are in its SAVE folder. If poolrad.exe is placed in a
writable game folder, these files go there instead, just as they did in
the DOS version.


Files included with this release
--------------------------------

RAVFULL.DAX (the title picture) and SBSFX.DAT (the recorded Sound
Blaster effects) belong to this release rather than the original SSI
game. Keep both files beside poolrad.exe. Without them, the game falls
back to SSI's title screen and the PC speaker sound effects.

SHA256.TXT contains the SHA-256 checksum of each file.
