Pool of Radiance for Linux
==========================

This is SSI's Pool of Radiance rebuilt as a native Linux program,
along with this project's fixes and extra features. It doesn't include
the original game data. Instead, it uses the data from your own GOG or
Steam copy and will usually find that copy for you. The original game
only needs to be installed; you don't have to run it first.

The game itself is poolrad, and poolcfg is the optional set-up program.
Use the x86_64 build on a 64-bit PC. The i386 build is for 32-bit x86
Linux; on a 64-bit system it also needs the 32-bit C library
(lib32-glibc on Arch, or libc6:i386 on Debian and Ubuntu).


Getting started
---------------

Unpack this folder wherever you like, then run ./poolrad. If you close
the window or press Alt-F4, the game asks before quitting. Any progress
since your last save will be lost.

For more control, run ./poolcfg in a terminal. It lets you choose the
video and sound options, whether to play the introduction, every option
on the Settings screen, and the data and save folders. You don't need
to run it before playing: if there is no POOL.CFG, the game simply uses
the defaults.


How the game finds your data
----------------------------

When it starts, the game looks for GEO1.DAX in the following places and
uses the first matching data folder it finds:

  1. A folder supplied with --data-folder (see below).
  2. The folder you launched the game from, followed by the folder that
     contains poolrad. This is useful if you unpacked the archive into
     your original game folder.
  3. The folder you found or chose the last time you played.
  4. The usual folders used by game stores:
       Steam:  Forgotten Realms: The Archives - Collection Two, in
               each of Steam's libraries (~/.local/share/Steam,
               ~/.steam/steam, and Flatpak Steam's)
       GOG:    ~/GOG Games and /opt/GOG Games
       Heroic: ~/Games/Heroic
     If the game finds one copy, it uses that copy and remembers it. If
     it finds several, it shows you a list to choose from.
  5. If nothing has turned up, the game opens a folder picker. Choose
     the folder containing GEO1.DAX. On systems where no picker opens,
     you'll be asked to type the folder instead. Cancelling quits the
     game.

To choose a different copy later, or supply the folder yourself, use:

  ./poolrad --choose-data-folder
  ./poolrad --data-folder /path/to/POOLRAD


Where your games are saved
--------------------------

If the game data isn't beside poolrad--for example, if it's in a Steam
or GOG folder, or in a folder you chose--the game won't write anything
there. Saved games, settings (POOLOPT.CFG), the Bestiary, the combined
data files created on the first launch, and DATABLD.LOG are stored in:

  ~/.local/share/pool-of-radiance/

If XDG_DATA_HOME is set, the game uses
$XDG_DATA_HOME/pool-of-radiance instead. Saved games are in its SAVE
folder. If poolrad is placed in a writable game folder, these files go
there instead, just as they did in the DOS version.


Files included with this release
--------------------------------

RAVFULL.DAX (the title picture) and SBSFX.DAT (the recorded Sound
Blaster effects) belong to this release rather than the original SSI
game. Keep both files beside poolrad. Without them, the game falls back
to SSI's title screen and the PC speaker sound effects.

SHA256.TXT contains the SHA-256 checksum of each file.


Questions and bug reports
-------------------------

This is a modified version of the game. GOG, Steam and SNEG can't
help with it. Please send questions and bug reports to
talonius@brazencrows.com. The game says so too, on its first start
after each new version and on the System page of the Settings screen.
