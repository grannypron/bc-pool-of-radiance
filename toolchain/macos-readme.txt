Pool of Radiance for macOS
==========================

Runs natively on Apple Silicon. Your GOG or Steam copy only needs to be
installed; you don't need to run it.

This is SSI's Pool of Radiance, rebuilt as a Mac program, with this
project's fixes and features. The game's data is not included: it
reads it from your own copy, which it finds by itself.


Keys
----

The game's Alt is Option (⌥): Option-Q is Quick, Option-M quick
magic. Command-Q asks before quitting.


Finding the game's data
-----------------------

At start the game takes the first of these that holds the data
(GEO1.DAX):

  1. A folder given with --data-folder (below).
  2. The folder Pool of Radiance.app is in, as when this zip is
     unpacked into a copy of the game's folder.
  3. The folder found or chosen the last time.
  4. The stores' own folders:
       GOG:    Pool of Radiance.app in /Applications or ~/Applications
               (GOG's app; its data is read from inside it)
       Steam:  Forgotten Realms: The Archives - Collection Two, in
               each of Steam's libraries
       Heroic: ~/Games/Heroic
     One copy found is used and remembered. With several, the game
     lists them and you pick one.
  5. With none, the game opens a folder picker: choose the folder
     that holds GEO1.DAX. Cancelling it quits.

To choose again, or to give the folder yourself, start the game from
Terminal:

  open "Pool of Radiance.app" --args --choose-data-folder
  open "Pool of Radiance.app" --args --data-folder "/path/to/POOLRAD"

GOG's own Mac version is DOS in an Intel DOSBox, which needs Rosetta;
this one does not. GOG's app is only read: nothing in it is changed,
so its signature stays good. Both apps are called Pool of
Radiance.app, so keep this one out of the folder GOG's is in.


Where your games are saved
--------------------------

When the data is anywhere but beside this app (inside GOG's app, in
Steam's folder, or a folder you chose), the game writes nothing
there. Saved games, settings (POOLOPT.CFG), the Bestiary, the combined
data files it builds on its first start, and DATABLD.LOG go to

  ~/Library/Application Support/Pool of Radiance/

(saved games in its SAVE folder). When this app sits in a game folder
it may write to, they go in that folder, as with the DOS version.


This release's own files
------------------------

RAVFULL.DAX (the title picture) and SBSFX.DAT (the Sound Blaster's
recorded effects) are this release's own data files, not SSI's. Keep
them beside Pool of Radiance.app. Without them the game shows SSI's
title and plays the speaker's effects.

If macOS runs the app from a hidden read-only copy (it can, for an app
opened where it was downloaded), it cannot see the files beside it.
Moving the unpacked folder somewhere else with Finder stops that.
