Pool of Radiance for macOS
==========================

This is SSI's Pool of Radiance rebuilt as a native Mac app, along with
this project's fixes and extra features. It runs natively on Apple
Silicon.

The original game data isn't included. Instead, the app uses the data
from your own GOG or Steam copy and will usually find that copy for you.
The original game only needs to be installed; you don't have to run it
first.


Keys
----

On a Mac, use Option (⌥) for the game's Alt key. For example, Option-Q
is Quick and Option-M is quick magic. Command-Q asks before quitting.


How the game finds your data
----------------------------

When it starts, the game looks for GEO1.DAX in the following places and
uses the first matching data folder it finds:

  1. A folder supplied with --data-folder (see below).
  2. The folder containing Pool of Radiance.app. This is useful if you
     unpacked the zip into your original game folder.
  3. The folder you found or chose the last time you played.
  4. The usual folders used by game stores:
       GOG:    Pool of Radiance.app in /Applications or ~/Applications
               (GOG's app; its data is read from inside it)
       Steam:  Forgotten Realms: The Archives - Collection Two, in
               each of Steam's libraries
       Heroic: ~/Games/Heroic
     If the game finds one copy, it uses that copy and remembers it. If
     it finds several, it shows you a list to choose from.
  5. If nothing has turned up, the game opens a folder picker. Choose
     the folder containing GEO1.DAX. Cancelling quits the game.

To choose a different copy later, or supply the folder yourself, open
Terminal and use:

  open "Pool of Radiance.app" --args --choose-data-folder
  open "Pool of Radiance.app" --args --data-folder "/path/to/POOLRAD"

GOG's Mac release runs the DOS game in an Intel version of DOSBox, so
it needs Rosetta. This version doesn't. It only reads data from GOG's
app and never changes it, which keeps that app's signature intact.
Because both apps are named Pool of Radiance.app, don't put this one in
the same folder as GOG's version.


Where your games are saved
--------------------------

If the game data isn't beside this app--for example, if it's inside
GOG's app, in a Steam folder, or in a folder you chose--the game won't
write anything there. Saved games, settings (POOLOPT.CFG), the
Bestiary, the combined data files created on the first launch, and
DATABLD.LOG are stored in:

  ~/Library/Application Support/Pool of Radiance/

Saved games are in its SAVE folder. If this app is placed in a writable
game folder, these files go there instead, just as they did in the DOS
version.


Files included with this release
--------------------------------

RAVFULL.DAX (the title picture) and SBSFX.DAT (the recorded Sound
Blaster effects) belong to this release rather than the original SSI
game. Keep both files beside Pool of Radiance.app. Without them, the
game falls back to SSI's title screen and the PC speaker sound effects.

macOS may run an app from a hidden, read-only copy when you open it in
the folder where it was downloaded. If that happens, the app won't be
able to see the files beside it. Move the unpacked folder somewhere
else in Finder to fix the problem.


Questions and bug reports
-------------------------

This is a modified version of the game. GOG, Steam and SNEG can't
help with it. Please send questions and bug reports to
talonius@brazencrows.com. The game says so too, on its first start
after each new version and on the System page of the Settings screen.
