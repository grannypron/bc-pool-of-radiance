# Changelog

## Since the October 2026 update

### New features

- A set-up program, POOLCFG.EXE, comes with the game. Run it in the game's folder to choose the video mode, the sound device and the introduction, every setting on the Settings screen, and the data and save folders of Pool of Radiance and the three later games. A folder you type must already exist: if it is not there you are told "Please verify the directory exists.", and nothing is created. Nothing is written until you choose Save and Exit (or press F10). If there is no POOL.CFG, or it is damaged, START now runs POOLCFG for you (saying "POOL.CFG was damaged, unreadable, or unparseable. Please reconfigure the game." first when it is damaged) and then starts the game with what you chose; leave POOLCFG without saving and you are back at DOS. A letter in lower case in POOL.CFG now counts too.
- The Linux, Windows and macOS versions now come with the set-up program too, as `poolcfg` beside `poolrad`: run it from a terminal (on a Mac, from Terminal) and it finds the game's folder as the game does. It has the same pages as POOLCFG.EXE, with what each choice means there: the picture is always VGA, and Tandy, AdLib and Sound Blaster all play the game's digital music and sound effects. The data folder is always the game's own, shown but not changed, and the save folder you choose must be inside it. The game never starts it for you: with no POOL.CFG, or one that cannot be read, the game now plays with the defaults (digital sound, the full introduction, saves in SAVE) and says on the terminal that poolcfg can set it up, where before it asked for the startup disk. It also finds its folder by the game's data when there is no POOL.CFG yet.
- Stojanow Gate changes once you have taken it. New Phlan's guards on the walls cheer as you come up to the gate and again once you are through it (once each visit, with a guard's portrait), and the two guard rooms have become makeshift barracks for New Phlan's troops. None of these waits for Return.
- If Dirten is in your party when you free the Temple of Bane, he stays to restore it, as before; and if he has fallen in the fight, the temple guards come in and a cleric rushes to his side. Two weeks of game time later, Dirten welcomes you at the old altar and offers the temple's healing at a tenth off. Before then you are told the rebuilding is underway. A game saved before this update in which Dirten joined you and the temple is already free starts the two weeks on your first visit to the altar.
- While you aim an area spell in combat, the line above the menu names the spell and counts who it will catch where the cursor is: your enemies in yellow, then your own characters and allies in cyan, the colours their names have in combat, as "FIREBALL: 3 ENEMIES, 1 ALLY", or "No targets". A side it catches no one of is left out. Fireball, Lightning Bolt (its bounce too), Stinking Cloud and the other area spells all count, even creatures just out of view. Sleep adds how many it can put to sleep at most when that is fewer than all of them ("SLEEP: 3 OF 2 ENEMIES"). No count gives away a creature's immunities: an immune creature counts as any other.
- A human can now change class at a training hall that trains the new class, as in Curse of the Azure Bonds: Dual Class on the party menu shows the classes a human can take, what each one's prime requisites need and what the character has, and why the highlighted class can or cannot be taken. It costs 2,500 gp. The character keeps its old levels and starts again at level 1 in the new class, with no experience; the old class's skills rest, with no hit points gained, until the new class passes it, and then the character uses the better of both, training only the new class. A character changes class only once, and not while it is drained of a level: it needs restoration first.
- The Journal's new Quests page lists the City Council's missions you have been given: a block of the old city to clear, a proclamation's quest once the council has posted it outside City Hall, and the commissions the clerk, Bishop Braccio, Cadorna, Lord Urslingen and the council hand out. Each one shows DONE once it is finished. The page's bottom line reads JOURNAL: ENTRIES QUESTS EXIT: Entries (E) goes back to the Journal's entries, and Escape or Exit leaves the Journal.
- The Companion Tools' map now shows the Clue Book's map keys ("Boat", "Temple of Tyr", and "Maze: Teleporters" for the part of a maze an area holds) on the squares where the book's maps print them, in every area the book maps, with each key on every place it appears; the book's key numbers, which mean nothing without its page, are left off. Keyed squares have light cyan walls, and the Map tool shows the key under the cursor above your own note, which it never replaces. The legend reads Dim: Not Visited and Yellow: Player Note. Turn the keys off with Clue Book Notes under Companion Tools in Settings.
- A Bestiary, opened with F2 on the map, in the wilderness and in camp, lists every creature you have met and what your party has learned about each: how often you have met and killed them, their size, armor class (narrowed from your attack rolls until it is exact), hit dice once you have killed one, the most damage one has done in a blow, and the defenses and attacks you have seen at work, such as half damage from blunt weapons, immunity to sleep, regeneration, poison or level drain. What you have not yet learned shows as ??. The Bestiary is kept in BESTIARY.DAT in the save folder, not in your saved games, so what you learn carries over to every game you play.
- Once the Slums are cleared, the fortune teller from the Slums, if you let her live, keeps a room of her own beside the tavern on New Phlan's east edge, with a door onto the lane; until then it stands bare, and if you murdered her, her crystal ball lies shattered on the floor. For a fee of 50 gold pieces a hit die (at least 100), paid as the temples are paid, she tells you all she knows of any creature in your Bestiary: its size, hit dice, exact armor class, defenses and attacks go into its entry, which she then shows you, and the entry no longer shows ?? after its defenses and attacks. She asks nothing for a creature you already know as well as she does, and has heard of nothing she has no record of.
- Every spell list (Cast, Memorize, Scribe, the spells in memory, learning a spell on gaining a level, and a scroll's spells under Use) now shows a summary line under the list for the highlighted spell: its range in squares, area or number of targets, duration, saving throw, and whether it is cast only in camp or only in combat, worked out for the character casting it (a scroll's spell at the scroll's level). Info (I) opens a page for the spell with those figures, its casting time and a description of what it does in this game; Next and Prev step through the list's spells, and Exit goes back to the list on the spell you were reading.
- On a character's items, Info (I) now opens the same spell page for a wand, potion or other magic item that casts a spell, such as the Potion of Speed, Keoghtum's Ointment, the Javelin of Lightning, Dust of Disappearance, the Necklace of Missiles or the Manual of Bodily Health: its range, area, duration, saving throw, when it can be used and what it does, worked out as the item casts it. Next and Prev step through the character's other such items. An item shows its page once it is identified. Aiming the Javelin of Lightning now shows the bolt that runs on past the creature it strikes, and who it will catch, as aiming Lightning Bolt does.
- In combat, F7 shows the fight's messages so far: who attacked whom, hits and damage, misses, spells cast and lost, effects and characters going down, and who is guarding ("MORRIGAN is Guarding"), a page at a time with the newest at the bottom, each round under its number. Up, Down, Page Up, Page Down, Home and End move through them. The Settings screen turns it on or off (Combat Log) and sets how many messages it keeps (Log Lines, 10 to 60; 50 to start). It needs EMS: without it the two settings are grey and Combat Log says Needs EMS. The messages are not saved and are gone after the fight.

### Interface improvements

- At the vault's counter the Up and Down arrows now step through the party, as they do at the shop's.
- The menu for taking coins from the treasure now lists them as a character's coin menus do, jewelry first, with the names lined up.
- A character's items menu now offers only what you can do with the highlighted item: Halve on a stack of two or more, Join when another stack can join it, and Id in a shop on an item not yet identified. The menu no longer runs off the bottom line in a shop.
- When you change a character's portrait from camp, Escape now leaves the portrait picker and keeps the portrait the character had.
- A character's More Info screen now has its own menu: Saves, Stats, Kills, Thief (for characters with thief levels, single or multi-class) and Exit. Stats and Kills show the game statistics and the kill count on the More Info screen itself, without a menu of their own; on the kill count, the Up and Down arrows scroll a row and Page Up and Page Down a page. Thief shows each thief skill with its racial, Dexterity and level parts and the total.
- A character who can turn undead (a cleric, or a paladin of 3rd level or more) has a Cleric page on the More Info screen, Cler (C) on its menu, now headed INFO: so that Thief and Cler fit together. It shows the level the character turns undead at and, for each kind of undead from skeleton to vampire, what turning does at that level: D destroys it automatically, T turns it automatically, a number is the least roll on a d20 that works, and a dash means the character cannot turn it yet. The figures are the ones combat uses.
- The Companion Tools (F6, when turned on in Settings) open straight onto the area's map. Map and Notes are now one tool: Map puts a cursor on the map to write and clear your notes on squares. The map also draws much faster in areas with many event squares, such as the Temple of Bane.
- The Settings screen now has three pages, chosen on the bottom line: Game, Paths and System. Game holds the settings, and each can now be turned off on its own: monster and character portraits under Portraits, the title and battle music under Music, and under Sound the footsteps, ranged weapons, melee attacks, the death scream and walking into a wall. Paths shows where Pool of Radiance's data and saves are, with places for Curse of the Azure Bonds, Secret of the Silver Blades and Pools of Darkness that a configuration program will set later. System shows the video and sound device, the game, data and memory details, and whether the overlays are in EMS.
- Spell sounds can now be turned off on their own in Settings: Spell Effects, under Sound, silences spells being cast and the flash and damage of their effects, while the other sounds play on.
- The character screen shows the attacks a round the character's classes give (Att/Rnd), under Damage: 1, or 3/2 for a fighter of 7th level or more.
- A spell memorized more than once now shows once, with how many copies are memorized after it ("Bless (x3)"), on the Cast list, the Spells in Memory list and the Memorize screen's list of spells still to be memorized. Spells on scrolls show once on the Cast list too, counted across all your scrolls, and casting one uses up the scroll with the fewest spells left on it first.
- F1 on the map or in camp shows the command keys on a full screen of their own, framed as the Quests page is: F5 and F8 (quick save and load) on the map, F6 while the Companion Tools are on, F7 (the combat log, in combat only) while the Combat Log is on, and, set apart below the function keys, Ctrl-S to turn the sound on or off. Escape or Exit closes it.
- When adding bracers with the Companion's character editor, Left and Right now choose Bracers of AC 6, 4 or 2, as they choose a weapon's plus; before, the AC was whatever was rolled.
- The party menu in the training halls now lists its commands in two columns, Party and Game on the left and Character on the right, with Settings and Exit to DOS on a row below them, Begin Adventuring (B) at the bottom and the game's version on the bottom line; the menu no longer runs off the window at a training hall. The Up and Down arrows move a highlight through the commands and Left and Right jump between the columns, Enter or a command's key carries it out, and Home and End choose the character. A command you cannot use there is grey. Dual Class (U) is always on the menu, and says on the bottom line why a character cannot dual class, such as "Only humans can dual class." The menu you see after the title screen, and after your party is lost, is SSI's own, one command to a line, with Game Settings added.
- The Journal's bottom line now reads JOURNAL: and offers Quests, which turns to a Quests page; Entries there turns back to the Journal as you left it, and Escape or Exit leaves the Journal.
- The Cast, Memorize and Scribe screens now look alike. Each is headed with the character's name, "RAVEN'S SPELLS", whatever the list, so a cleric's spells no longer claim to be in a spell book. The spells sit indented under their level, the highlighted spell's summary is on the line just above the window's bottom edge, and the bottom line names the screen: CAST: CAST INFO EXIT. Next and Prev appear only when the list runs past one page, and then on every page, with (MORE) under a page that has more below it. Memorize shows the spell slots you have left in a box of their own under the list, a line for each of your classes ("MAGIC-USER  1:0  2:0  3:0").
- The Load/Save menu has a Quit option, which asks "Exit to DOS?", as SSI asked after a save in camp. If the game has changed since it was last saved, Yes asks whether to save first. Camp no longer asks to quit after every save.

### Fixes

- Stone to Flesh at a temple now calls for a system shock roll, as in the 1st-edition rules: the lower the character's Constitution, the likelier the character "DOESN'T SURVIVE THE TRANSFORMATION." and dies. The fee is spent either way.
- The temple no longer takes your money for Cure Light, Serious or Critical Wounds on a character the cure cannot help (dead, turned to stone, or with mummy rot, or not wounded) without asking: it says why and asks whether to cast the cure anyway.
- A random potion found as treasure is always a potion. Before, about one in eleven was a nameless item that did nothing.
- The lightning on the second title screen now flashes at the same pace on every computer, and in the native version, where it never flashed before.
- In CGA, the Companion Tools map's legend now names the colour your notes are drawn in, magenta, instead of saying yellow.
- Shield now stops the missiles of a Wand of Magic Missiles, as it does the spell's, and creatures immune to Magic Missile are immune to the wand too.
- Fix in camp no longer heals where magic does not work; it says "Spells cannot be cast in this area." as Cast does.
- A character whose status is changed with the Companion's character editor (Health, Status) is now put in or out of action to match. Before, a character set back to Okay stayed in red on the party list and lay as a body in combat, and one knocked down stayed in action.
- Monsters now strike the character they moved to attack. Before, they hit a random character within reach.
- An enemy's free attack when you step away from it is now a single attack, and it no longer costs the enemy its own turn.
- In combat, pressing Escape after attacking by moving into an enemy no longer puts your character back where it started with its full move.
- The game no longer hangs when a monster with a cursed bow or crossbow has one of your characters next to it.
- A hostile cleric's Cure Light Wounds no longer heals your dying characters.
- A bite-and-hold creature lets go of a victim that is no longer held, and a corpse animated by a high-level caster returns to the right side when the spell ends. Several rare memory faults in combat are fixed too.
- Function keys, Delete and the other special keys no longer run commands in the treasure, shop and temple menus. Before, Delete shared out the money and F10 cast Detect Magic.
- Pressing Escape when asked to Sell or Keep an appraised gem or piece of jewelry no longer sells it; the question stays until you choose.
- Pressing a digit, a function key or another special key in the camp menus no longer selects the first party member.
- Backspace when typing an amount ("How much ...?") now erases the digit from the screen.
- Typed text (a character's name, a note) now starts right after the prompt, and a full-length entry fits on the line.
- Alt-R no longer turns the sound on or off and rewrites your settings; only Ctrl-S does.
- Escape in a list of choices that a scene asks you to pick from no longer picks the highlighted one; you must choose.
- To-hit penalties now only lower an attack roll: a strong attacker no longer misses on a low roll that would still hit, and scripted trap attacks hit as often as a creature's attack with the same THAC0.
- A creature coughing in a Stinking Cloud keeps its Shield and Blindness armor class changes when attacked.
- Attacks from behind and backstabs no longer ignore a clumsy creature's Dexterity armor class penalty.
- A magic bow or crossbow adds its bonus to hit only; magic arrows and quarrels add theirs to hit and damage.
- Protection from Normal Missiles now takes 1 point per die off magical missiles (no die below 1).
- Only Large monsters take a weapon's damage against large targets: wolves, wild boars, basilisks and large scorpions now take its normal damage, while gnolls, huge scorpions and phase spiders count as Large.
- Dwarves and gnomes get their armor class bonus against ettins.
- A free attack on a retreating foe no longer costs the attacker its sweep against weak foes on its own turn.
- Protection from paralysis now stops a paralyzing touch, and creatures immune to poison no longer die of a poisonous hit when they roll a natural 1.
- An anhkheg's acid spit now does acid damage; fire protection no longer reduces it.
- Readying a Cloak of Displacement no longer corrupts memory.
- A monster's readied magic cloak, gauntlets or ring now gives it the item's effect. Tyranthraxus, for one, now has the strength of his Gauntlets of Ogre Power.
- A paladin's protection from evil now also guards allies within 10 feet.
- Bec de corbin, military fork, partisan, ranseur, spetum, short sword, trident and arrows now count as piercing weapons, and the battle axe as a slashing one, against creatures that take half damage from some kinds of weapon.
- Curing a disease now gives back the Strength it took.
- Ring of Fire Resistance and other fire protection now take a steady amount off Burning Hands, instead of an amount left over from an earlier damage roll.
- Dispelling a caster's newer stinking cloud now clears that cloud, not an older one, and clouds cast above level 15 are cleared and dispelled correctly.
- Dispel Magic on an animated corpse no longer reads effects that were already removed.
- A scroll spell, wand charge or other item use that is aborted in combat is no longer used up.
- Slow Poison no longer "stands up" a character who is still standing, stoned, disintegrated or fled.
- Scribing a scroll spell no longer adds 128 to a wand's charges (or changes another item) and scribes nothing.
- Train Character is offered on the party menu only at a training hall (or with free training on), not on every later menu.
- Declining to drop a character with a 14- or 15-letter name now shows the whole message.
- Demi-human fighter level limits use the character's own Strength, not Gauntlets of Ogre Power, Enlarge or Strength, and a lowered Strength no longer lets a capped fighter train past the limit.
- Declining training, or being turned away at the hall, no longer cuts the character's experience.
- With free training on, a character with no class left to train is turned away instead of gaining a hit point per Train.
- New characters get the Dungeon Master's Guide's young-adult +1 Constitution, so starting Constitution is no longer one low at every age.
- Class ability minimums follow the 1st-edition Player's Handbook (Charisma 6 for most classes, and the other missing minimums), and a multi-class character must meet every class's minimums.
- A thief, multi-class included, can use thief skills only in leather or no armor and without a shield; the More Info Thief page says when armor is stopping them. A shield also stops a backstab.
- The temple will not raise a character who is still poisoned: cure the poison first.
- Raise Dead at the temple now makes the resurrection survival roll for the character's Constitution; a character who fails it is dead for good.
- Dropping money on the View screen updates the Encumbrance and Movement shown.
- Selling an item while near capacity gives the seller only the coins they can carry; the rest really goes to the pool.
- A 255-character message now prints once instead of repeating forever.
- Walls loaded into the second or third wall slot no longer show a stray 8x8 cell from another wall set.
- A picture that could not load for lack of memory is tried again instead of staying blank.
- Fleeing an encounter now takes Haste and Slow on the first party member into account.
- After the STING memory pop-up, the next arrow key works normally, and an arrow key that answers any "press a key" message no longer leaks into the next menu.
- Several faults that the shipped scripts never reach are fixed too: a box fill of zero height, monster icons loaded over the combat sprites, and a script removing a character by number.
- A save that runs out of disk space now says "The game was not saved." and keeps your old save in that slot, and a failed quick save no longer says it is done.
- If the vault's ledger can't be written when you leave the vault, your stored items and money stay there for you to take back, unless you choose to leave anyway.
- Camp's Save no longer asks whether to quit to DOS when you cancelled the save or it failed.
- A character whose file can't be saved when you remove it now stays in the party, and you can try again to save a newly created character whose save failed.
- Characters named Con, Aux, Nul, Prn, Com1 to Com4 or Lpt1 to Lpt3 are now saved to a file instead of being sent to a printer port or the screen.
- The game now runs from read-only files (copied from a CD, or a read-only folder), and read-only saved games and characters load.
- Loading or saving a game no longer deletes the separate saved copies of its characters, which stay on the Add list. Dropping a character forever deletes its copy.
- A game loaded from the training hall's party menu now starts in the loaded game's area instead of carrying on with the hall's script.
- Monsters now find their way to any party member they can reach: they switch to a reachable target, wait their turn behind their own side in narrow passages, and walk round Stinking Clouds. A party can no longer stay out of reach of monsters that have a way to it.
- A paladin's protection aura no longer protects the monsters fighting him.
- Protection from Evil or Good no longer stacks when it comes from more than one source, such as a paladin's aura and the spell, and it now makes the protected character 2 harder to hit as well as giving +2 to saves.
- A Cloak of Displacement readied during combat gives its free miss in that combat, and the free miss is no longer lost when a first-round attack's roll comes to exactly 0.
- A drider's paralyzing touch is now saved against at -2.
- Magic resistance against gazes and touches now uses the creature's listed resistance.
- Haste and Slow cancel each other out everywhere, so a character both hasted and slowed moves at its normal rate on the View screen and when the party tries to flee an encounter.
- Gauntlets of Ogre Power, Enlarge or the Strength spell no longer earn the 10% experience bonus.
- A half-elf's cleric multi-class needs Wisdom 13 on the modify screen too, as it does when rolled.
- A character's coins stop at 65,535 of a kind; anything more goes to the treasure pool instead of wrapping to zero.
- Dispel Magic no longer makes a disease worse; Cure Disease is what removes it.
- The bill-guisarme no longer counts as a bow for arrows.
- The statistics count a death once, not once for every round a character lay dying.
- Removing a character from the party while an area's script is running no longer brings the removed character back as the current one.
- An arrow or function key pressed at a "press a key" prompt, a disk prompt or a number or name entry no longer types a letter or picks a menu option afterwards.
- Every "insert disk" prompt now names the file it is looking for (or could not write). Escape at the save disk prompt gives up: a roster character whose file is gone is taken off the roster, and a save to a folder that can't be written fails instead of asking forever. Escape at a game data prompt quits to DOS.
- Charm Person and Hold Person now work on gnolls, as in 1st edition, and no longer on the ogre leader, who also takes weapons' damage against large creatures now; the huge scorpion counts as Medium.
- Effects that act at the start of a character's action in combat (Silence, Stinking Cloud coughing, holds, blood drain, charm) now act once per turn, not every time the combat menu is redrawn.
- Creatures placed at the start of combat are no longer sometimes left unplaced at random, and distance checks no longer report a distance to a creature they could not find.
- Alt-R is no longer accepted on the combat menu, where no command answered it.
- Random treasure can include the Wand of Lightning again, and no longer sometimes produces an empty item.
- A character with a Dexterity of 0 takes the same -4 armor class penalty as one with 1 to 3.
- Paging through the party with no character selected starts from the first character instead of crashing.
- Resting to prepare a very long list of scroll spells no longer comes up far too short.
- A save whose side files (the slot's description, statistics, explored map, map notes, usual spells) could not be written now says so, and saving an empty vault reports a failure when the slot's old vault file cannot be erased.
- On a Sound Blaster that does not answer, sound effects play on the speaker instead of not at all.
- Digits in a script's menu options show as digits instead of turning into letters (no menu in this game has one).
- Following the 1st-edition rules: the temple will not raise a dead elf ("RAISE DEAD cannot restore ... Elven souls lie beyond its reach.") and tells you a poisoned character is poisoned and Raise Dead cannot help; scribing a spell depends on the magic-user's Intelligence, and a failed attempt loses the spell from the scroll; a cleric with Wisdom below 13 can fail to cast a clerical spell, losing it.
- Saving is now all or nothing: every file of a save (the party, each character, the description, statistics, explored map, notes and vault) is put in place together, and a save that can't be written whole leaves the old one exactly as it was. A save cut off by a crash or power cut gives the slot back its old save.
- A javelin can now be used in melee as well as thrown, by your characters and by monsters.
- Magic resistance no longer protects against a monster's poisonous or paralyzing touch, and meets a vampire's charm gaze at its listed figure.
- A creature within reach of Prayers from both sides now gets both: its own side's bonus and the enemy's penalty.
- Snake Charm no longer charms scorpions.
- A hasted, fast monster no longer stops partway through its move.
- The statistics count a death by poison, level drain or mummy rot as Died.
- Several values the DOS game assumed would start at zero now do: the first menu of a session no longer sometimes answers Enter to the wrong place, a script's monster setup starts empty, and the Stinking Cloud list starts clear.
- Loading a game or starting a new one no longer keeps the monsters the last area set up.
- Magic Missile now fires one missile at levels 1 and 2, two at 3 and 4, and so on, as the rule book says. Before, a 1st-level magic-user's Magic Missile did no damage and each later missile came a level late.
- A successful saving throw against Silence, 15' Radius now spares the target, as the rule book says. Before, the save was rolled and then ignored.
- POOL.CFG's sound letter S means silent again, as SSI's data card says; the Sound Blaster is now B. A POOL.CFG set to S for the Sound Blaster now runs without sound until its second line is changed to B.
- With nine of the council's rewards paid, the proclamations you note outside City Hall now end with CCXIV, the nomads' proclamation, which was never named. Before, the ninth repeated CXIV.

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
- Clerics, and multi-class characters with a cleric class, can no longer be created true neutral, as the rules require. Existing characters keep their alignment.
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
