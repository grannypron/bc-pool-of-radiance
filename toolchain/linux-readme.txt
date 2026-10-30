Pool of Radiance for Linux
==========================

This is SSI's Pool of Radiance, rebuilt as a Linux program, with this
project's fixes and features. The game's data is not included: it
reads it from your own copy (GOG's or Steam's), which it finds by
itself. Your copy only needs to be installed; you don't need to run it.

poolrad is the game and poolcfg the set-up program. The x86_64 build
is for 64-bit PCs. The i386 build is for 32-bit x86 Linux, and on a
64-bit PC needs the 32-bit C library (lib32-glibc on Arch,
libc6:i386 on Debian and Ubuntu).


Starting it
-----------

Unpack this folder anywhere and run ./poolrad. Closing the window
or pressing Alt-F4 asks before quitting: progress since your last
save is lost.

Run ./poolcfg in a terminal to choose the video and sound, the
introduction, every setting on the Settings screen, and the data and
save folders. The game does not need it: with no POOL.CFG it plays
with the defaults.


Finding the game's data
-----------------------

At start the game takes the first of these that holds the data
(GEO1.DAX):

  1. A folder given with --data-folder (below).
  2. The folder you start it from, then the folder poolrad is in, as
     when this archive is unpacked into a copy of the game's folder.
  3. The folder found or chosen the last time.
  4. The stores' own folders:
       Steam:  Forgotten Realms: The Archives - Collection Two, in
               each of Steam's libraries (~/.local/share/Steam,
               ~/.steam/steam, and Flatpak Steam's)
       GOG:    ~/GOG Games and /opt/GOG Games
       Heroic: ~/Games/Heroic
     One copy found is used and remembered. With several, the game
     lists them and you pick one.
  5. With none, the game opens a folder picker (or, where none opens,
     asks you to type the folder): choose the folder that holds
     GEO1.DAX. Cancelling it quits.

To choose again, or to give the folder yourself:

  ./poolrad --choose-data-folder
  ./poolrad --data-folder /path/to/POOLRAD


Where your games are saved
--------------------------

When the data is anywhere but beside poolrad (in Steam's or GOG's
folder, or a folder you chose), the game writes nothing there. Saved
games, settings (POOLOPT.CFG), the Bestiary, the combined data files
it builds on its first start, and DATABLD.LOG go to

  ~/.local/share/pool-of-radiance/

(or $XDG_DATA_HOME/pool-of-radiance; saved games in its SAVE folder).
When poolrad sits in a game folder it may write to, they go in that
folder, as with the DOS version.


This release's own files
------------------------

RAVFULL.DAX (the title picture) and SBSFX.DAT (the Sound Blaster's
recorded effects) are this release's own data files, not SSI's. Keep
them beside poolrad. Without them the game shows SSI's title and
plays the speaker's effects.

SHA256.TXT holds the SHA-256 of each file.
