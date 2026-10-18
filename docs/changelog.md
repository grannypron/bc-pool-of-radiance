# Changelog

## Pool of Radiance port: October 2026 update

This update to the Pool of Radiance port (SSI's 1988 game, version 1.3, rebuilt from its source) collects a week of work from 10 to 17 October 2026. It adds paladins and rangers at character creation, a settings screen, a full-screen load and save menu with quick save and quick load, a vault in New Phlan, and statistics for each character. The rules now run to an ability score of 25, a long list of bugs from SSI's original is fixed, and the combat AI no longer runs in circles. Behind the scenes the code has been restructured and put under automated tests, and the game gains a VGA mode and can load its overlays from expanded memory. Your existing saved games and characters still load.

### New features

- You can now create paladins and rangers. Humans can be either; half-elves can be rangers or cleric/rangers. The usual party rules apply when adding them: a paladin will not join a party with an evil member (nor an evil character a party with a paladin), and a party may have at most three rangers. The race screen shows the new classes and their level limits.
- A new Settings screen, reached from the start menu (Game Settings) and from Alter during play, gathers game speed, monster pictures, portraits, music, sound, Auto End Quick Mode and the starting state of Quick Mode Magic in one list. Settings are now kept for all your games in POOLOPT.CFG rather than in each saved game. The screen also shows your video and sound setup, the game and data versions, and free memory.
- Loading and saving now use a full-screen menu that shows each slot's description, the area it was saved in, and the date and time. Press a slot's letter to load or save it at once. When saving you can type a description of up to 27 characters; left empty, it reads SAVE GAME and the slot's letter.
- Quick save and quick load: on the map, press F5 to save to a dedicated quick-save slot and F8 to load it. The quick save also appears on the load and save menu.
- The Hoarder's Respite, a vault in New Phlan in the building that was a tavern at (8,9), as in Secret of the Silver Blades. You can deposit money and up to 100 items there and take them out later. The vault is saved with each saved game.
- Each character now keeps statistics: kills (by type of creature), damage dealt and taken, healing given and received, times raised, poisoned, knocked down and killed, spells cast, items looted, and coins looted (net of pooling and sharing). The game keeps party totals too. Find them on the character's More Info page under Stats, which has a Game page and an alphabetical Kills page.
- A paladin's Heal and Cure now appear directly on the View menu instead of being hidden under More. More Info (the saving throws and the statistics) is opened with M, shown under the portrait.
- When you choose Exit to DOS with unsaved changes you are asked whether to save first, and you can now quit without saving. This also works in the training hall.
- When the party is destroyed you now return to the main menu instead of being dropped to DOS.
- If the game runs out of memory it now offers to save before quitting: press Enter to save, or Escape to quit.
- When choosing who will fight a duel (the training hall arena, the buccaneer in the Pitt, the Lizardman Keep's champion), you can now press Escape to change your mind.
- Journal entries that run over several pages show "(more)" at the top or bottom of the page.
- For testers, the STING debug mode gains Curse of the Azure Bonds' tools: a script trace log, a dump of creature effects, a raw item viewer, automapping anywhere, a free-training toggle, and a memory display.

### Gameplay changes

- Ability scores now run all the way to 25, using the Deities & Demigods tables above 18. High Constitution gives a larger hit-point bonus, raises the lowest possible roll on each hit die, improves saves against poison, and speeds up regeneration. High Dexterity improves thief skills, and high Wisdom gives clerics more bonus spells.
- Multi-class characters with a fighter, paladin or ranger class now get the warrior's Constitution hit-point bonus for that class, as the rules intend.
- Ability scores can no longer fall below 3 or rise above 25 during play. Raise Dead, for example, can no longer reduce Constitution below 3.
- The Manual of Bodily Health now always raises your hit points as well as your Constitution, and reading a second one no longer stacks extra regeneration.
- Keoghtom's Ointment now revives only a character killed by poison, not one who was poisoned and then died of wounds.
- Party members fighting under Quick Mode now bandage dying teammates, as in Curse of the Azure Bonds.
- When the surprise roll succeeds for both sides, both sides are now surprised.
- Robbers' chances of stealing heavy items no longer protect the items after them in your pack.
- A randomly generated javelin is now sometimes a Javelin of Lightning, instead of a nameless broken item.
- Characters without magic-user levels are now told that scribing a scroll requires arcane training.
- Camp's Fix now tells you why it cannot help: no clerics, no cleric able to cast, nothing left to heal, or no spells left to heal with.

### Fixes

- Fixed a bug where a character hit while casting kept the spell and the attacker lost it instead.
- Fixed monsters and Quick Mode characters losing an extra copy of a spell when caught in their own spell's area.
- Fixed monsters and Quick Mode characters sometimes dropping a spell they had begun casting in order to use an item.
- Fixed the combat AI running back and forth against walls and dead ends; creatures now find their way around walls and other bodies to reach their target.
- Fixed Share handing out more money than the pool held when a hired NPC was in the party.
- Fixed Restoration never appearing in the spell book.
- Fixed pressing 2 or - during the computer's combat turns toggling quick magic or triggering a debug cheat.
- Fixed Space in combat treating animated creatures differently depending on whose turn it was.
- Fixed fleeing monsters running diagonally when the party faced north or south.
- Fixed removing the Gauntlets of Ogre Power sometimes removing the wrong Strength effect.
- Fixed joining a readied stack of items (arrows, for example) into an unreadied one losing its Ready status.
- Fixed the temple's "you left some money here" prompt erasing the priest's words before you could read them.
- Fixed the message when dropping an item: "Your Long Sword will be gone forever" now has exactly one space.
- Fixed the missing space in the buccaneer's challenge in Podal Plaza: "WHO WILL IT BE?' WHAT DO YOU DO?".
- Fixed a stray letter at the end of Camp's Rest menu ("EXITT").
- Fixed missing full stops in Camp's scribe and drop messages, and the misspelling "scibing".
- Fixed the last picture shown (often the treasure after a fight) appearing over the 3D view after saving.
- Fixed camp showing a black view behind the "Quit to DOS?" question after saving.
- Fixed the rest timer showing 24 or more hours during long memorizing rests.
- Fixed a newly loaded game sometimes running an old copy of the area's script; the area's script is now always loaded fresh, so data fixes take effect in older saves.
- Fixed a quick load sometimes starting by itself on the first step after starting the game.
- Fixed fatal error messages being wiped from the screen and leaving DOS in graphics mode.
- Fixed text in CGA mode changing colour partway through repeated letters.
- Fixed a wrong picture (or none) sometimes appearing after the game changed disks.
- Fixed a write-protected usual-spells file being treated as missing.
- Fixed a missing data file producing an unhelpful "Insert disk" prompt; the game now names the file it could not find and the right drive.
- Fixed the game stopping at start-up when the Brazen Crows title picture (RAVFULL.DAX) is not present; it is now skipped.
- Fixed many rare crashes and hangs that damaged saves or unusual situations could cause, found by a review of the whole source.

### Interface improvements

- The arrow keys now step through your characters on every menu where Home and End do, including the start menu and camp, and move characters in Party Order.
- The combat icon editor now has Keep and Exit: Keep accepts your design, Exit discards your changes. E works as Exit's key, the character's name is shown in cyan, and long lists show "(more)".
- The portrait picker's Okay is now Keep.
- Under Quick Mode, the bottom line shows how to leave it (Space) and whether Quick Mode Magic is on (Alt-M).
- The message when an aligned weapon shocks its wielder now shows the weapon and character in green and the rest in white, so it is easier to read.
- The start menu's title now shows the game's version.

### Under the hood

- The source has been reorganised: shared code has been gathered into common routines, tangled dependencies between parts of the program removed, and many magic numbers given names. The game uses its memory more carefully as a result, with more free memory and fewer disk loads during combat.
- The port is now covered by automated tests: unit tests of the rules, and recorded play-throughs replayed against earlier builds in every video mode to catch any change in behaviour. Saved games and character files are checked against SSI's original formats.
- Saved games no longer contain stray memory contents, so the same game always saves to the same file.
- A new VGA video mode is available (choose V for video in POOL.CFG), alongside CGA, EGA and Tandy. The video code has been rebuilt around one driver per mode.
- The game loads its overlays from expanded memory (EMS) when enough is available, which avoids reading them from disk during play, and the second wilderness tile set is now loaded only when needed.
- The script area has room for longer area scripts, so future data fixes are easier to make. Saved games keep their original size and layout.
