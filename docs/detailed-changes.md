# Detailed changes since 5debfb7

This document records every change made to the Pool of Radiance port (the Turbo Pascal 6 reconstruction of SSI's v1.3) from commit 5debfb7 (2026-10-10) up to the head of branch `fix/issues-670-672` (3b52671, 2026-10-17); 5debfb7 itself is not included. The range holds 238 non-merge commits, delivered through 54 merged pull requests plus one open pull request (#673, which carries the last three commits, for issues #670, #671 and #672). The commit messages are the authority for what each change does; the entries below restate them.

The document is organised by area, not by date. Each entry gives a short title, what was wrong or missing, what changed (with unit and routine names where they help), the Forge issue numbers (#NNN) and SSI quirk numbers (POR-NNNN) where there are any, and the short commit hashes. Where a change deliberately departs from SSI's v1.3 behaviour, the entry says so under "Differs from SSI". Related commits are merged into one entry where they make one change.

The areas are:

1. New features
2. Gameplay and rules fixes
3. SSI quirks fixed (and the ones labelled)
4. Combat and the combat AI
5. User interface: menus, screens, keys and messages
6. Saving, loading, quick save and the vault
7. Data fixes to the shipped scripts and items (DataPat)
8. Video (the driver refactor and VGA), memory, overlays and EMS
9. Robustness guards from the source review
10. Refactor phases 0 to 6 (structure, units, tests, sizes)
11. Tools, CI, tests and regression scenarios
12. Documentation

---

## 1. New features

**Paladins and rangers can be created.** The earlier #209 work gave both classes their tables, hit points, warrior rules and special abilities, but character creation could not make them. Humans can now be paladins and rangers, and half-elves rangers and cleric/rangers, in Curse of the Azure Bonds' order; the half-elf row of `classesByRace` grows to 13 classes, and the class menu guards its count and pick. Adding a character follows Curse's party rules: a paladin does not join a party with an evil member, an evil character does not join a party with a paladin, and a party has at most three rangers. A refused character gets Curse's message on the bottom line, which waits for a key, and stays on the roster; as in Curse, the first character joins unchecked and scripted NPC joins are not checked. The race screen shows the new classes with the rule book's maximums (U for a human paladin or ranger, 8 for a half-elf ranger, CL/RA among the half-elf multiclasses), and its multiclass column may run on beside the note at the foot of the box. Differs from SSI: SSI's Pool offered neither class at creation. #209. 11a5399. A related guard: paladin and ranger share usability bit 6, and the one place that builds `itemLimits` summed class bits with `Inc`, which would carry into bit 7 for a class holding both; the bits are now or-ed (no class combines them, so nothing changes). #445. 1683b84.

**Settings screen, saved globally in POOLOPT.CFG.** One screen for the game's settings, in the list style of the Journal and race screens, as designed in #549. It opens from the start menu (Game Settings) and from Alter in game (Settings), replacing Alter's Prefs and Speed. Up and Down pick a setting; Enter, Left or Right turn it over; the speed line offers Slower and Faster, chosen with Left and Right and applied with Enter. The settings are game speed, monster pictures, character portraits, music, sound, Auto End Quick Mode (#338's behaviour, now a setting) and Quick Mode Magic (the Alt-M state each fight starts with; off by default, as in SSI's game). They are global: POOLOPT.CFG in the save folder keeps them as KEY=VALUE lines, read in GameInit before the title music and written back on every change (also by Ctrl-S and the combat speed menu). Unknown keys are ignored and kept, missing or bad ones take the defaults, and if the file cannot be written a change holds for the session. Saves still write SSI's copies of speed and the settings word, but loading a save no longer changes the settings. Below the settings the screen shows, for display only, what the game runs with from POOL.CFG (video, sound device, data and save paths), the build version and commit, the data archive version and how many families read their merged archive, and free memory and the largest free block; NORAND and STING show at the right of the last rows when given. `build.sh` writes `obj/BUILDID.INC` from git for the version and commit. Differs from SSI: settings were per saved game. #549. efccdbf.

**The game version string and the start menu title.** The owner's batch "Updates from BC." added `GDConsts.GAME_VERSION`, the build version from `BUILDID.INC` followed by " (BC)", shown centred on the credits screen (in place of the fixed "version 1.3") and as the Settings screen's Version line. The start menu's prompt, "Choose a function", is now "pool of radiance" and the version, in magenta. The same batch added the Brazen Crows picture (RAVFULL.DAX) at the start of the introduction (see section 5 for the later change that skips it when the file is missing). 038f32e.

**View: Heal and Cure on the main menu, More Info under the portrait.** A paladin's Heal and Cure were reachable only from the More page. As in Curse, they are now on the View menu itself while each can be used (Items Spells Trade Drop Heal Cure Exit). The menu line drops its "View:" prompt, as Curse's does, since a paladin with items and money would not otherwise fit in 40 columns. More moves off the menu line to a "More Info" label under the portrait frame (column 29, row 13, the M in white and the rest in green), drawn whether or not a portrait is shown; M opens the More Info page, now the saving throws alone with an Exit menu. `MenuCore` gains `extraKeys`, keys a caller takes although the menu line does not show them, returned upper-cased without changing the current option and cleared on every return. #592. 2a9448f.

**Full-screen Load/Save menu.** See section 6 (#604, #652, #656, #657).

**Quick save (F5) and quick load (F8).** See section 6 (#605).

**The vault: The Hoarder's Respite.** See section 6 and section 7 (#606).

**Statistics per character and per game.** A new resident unit, `Stats`, keeps for each party member and for the game: kills, in all and by kind (the creature's name; past 47 kinds the rest go under OTHER), damage done and taken, healing given and taken, times raised, times poisoned, items and coin looted (coin by its worth in copper, shown in gold), spells cast, times knocked down and times died. Counters are LongInts that stop at 2,147,483,647 rather than wrap. The unit is not overlaid, so counting a blow in combat loads no overlay. Credit goes to the creature acting (`curChar`): in combat a party member's blow on anyone outside the party is damage done, and its fall is a kill; healing given counts while a spell or an item's spell is resolved and for a paladin's laying on of hands; healing taken counts every hit point a party member gets back; coin and items count when taken from the loot after a fight, not from the vault. A party member's block is on the heap, found by record and name as the usual spells are, and freed with it; it is written to `<character>.sts` beside the character's file and read back with it, and the game's totals go to `savgam<x>.sts`. Older files start from nothing. The 1 KB file record is static, not on the stack. #611. 2f26748. Coin looted was then made net: the post-combat loot menu notes each member's coin before every action (Take, Pool, Share, Drop in View) and adds the difference after, so pooling the party's own money and taking it back no longer counts as loot; a character's figure can go below zero. Shops, temples and the vault do not count. #611. 7edfa4f.

**The Stats screen: a Game page and a Kills page.** The first version (2f26748) put Stats on More Info, showing the character's counters with its ten most-killed kinds, and a Game page with the party's totals. The screen is now remodelled: Stats opens on Game, the character's twelve counters in this game, and Kills lists the kinds it has killed in alphabetical order, the count right-aligned before each name, in two columns; Up and Down scroll a row and, past a page, Next and Prev turn it, with "(more)" above or below. The bottom line reads Stats: Game Kills Exit. The party-wide totals page is gone from the screen; the game's totals are still kept and saved. #672 (open PR #673). 3b52671.

**STING debug tools from Curse.** From Curse of the Azure Bonds' debug mode, under Pool's STING parameter (Curse asks for a second word; Pool keeps the one): Ctrl-L turns the script trace log on and off (debug.txt gets each opcode's mnemonic as it runs, from the new `EclTrace` unit with Curse's `OpName` for opcodes $00..$3D, SUBTRAT included, and the status line shows '*'; Curse's key was Ctrl-D, which here stays the hit-point pop-up); Ctrl-Z, while the log is open, writes each creature's effects to it; V in the Items menu (not shown on the menu line) shows the selected item's raw record (Curse's ViewItemDetail); A on the 3D menu maps anywhere, ignoring the area's no-automap flag; J turns free training on and off, as in Curse, where Pool had turned it on for good. Ctrl-Y shows the overlay load count, buffer and probation sizes, and the heap's free memory and largest block on the bottom line, then redraws the menu line (`GDVars.bottomLineTaken`). `MenuVertical` now passes its caller's `extraKeys` to every key it waits for, not only the first. #612. 5226426. Later additions to Ctrl-Y (picture memory, EMS) are in section 8.

**Camp's Fix rest explains why it does nothing.** In the owner's batch, `CampFixMenu` now tells a party with no cleric "No clerics available to heal.", one whose clerics are all unable to cast "No cleric is in a condition to heal.", and, when nothing can be treated, "Further healing would do no good." (nothing to treat) or "Further healing isn't possible." (conditions remain but no slot can treat them), instead of returning silently. 038f32e.

**Journal pages show "(more)".** In the owner's batch, the in-game Journal's entry pane draws "(more)", centred, on its top row when a page comes before and on its bottom row when one follows; pages are counted accordingly (a page holds the full rows alone, one fewer first or last, two fewer between). 038f32e.

**Exit to DOS without saving.** The main menu's and the training hall's Exit to DOS ran the save menu until a save was made, so Escape could not leave it. A party not saved since it changed is now asked "Save first": Yes opens the save menu (leaving it unsaved stays in the menu), No quits without saving. #660. 09aa25f.

**A destroyed party returns to the main menu.** After "PARTY HAS BEEN DESTROYED" the program exited to DOS. It now frees the party (`SaveLoad.FreeParty`, shared with QuickLoad), forgets the session vault, resets the game (`GameInit.ResetGameState`, split out of `GameInit2`, as in Curse) and returns to the main menu. Differs from SSI. #658. 5d4e0cc.

**Out of memory, the game offers a save.** `HeapErr`'s save ran only while `heapFailureSaveEnabled` was nonzero, and nothing ever set it (in SSI's v1.3 either), so a failed allocation always quit to DOS unsaved; had it been set, a save that could not finish would have looped. The handler now frees a 4 KB reserve that `GameInit2` takes once the overlay buffer is set up (enough for the vault's copy buffer, a new statistics block and menu nodes), then asks on the bottom line: Enter opens the save menu, Escape quits. A save backed out of or failed asks again; a failure inside the handler returns 0, the runtime error the game had before, rather than re-entering. The flag is gone. Not exercised by any scenario. POR-0168, #643. e9e0acb.

---

## 2. Gameplay and rules fixes

**Ability rules run to 25 (Deities & Demigods).** So that the code ports to the later Gold Box games as it is, every ability rule now covers scores up to 25, with the 1st-edition values up to 18 and Deities & Demigods above:
- Constitution hit-point bonus: a fighter, paladin or ranger class now gets the warrior Constitution bonus whatever the character's other classes, as the PHB works the bonus out per class before dividing by the class count; before, `ConHpBonus` and `ConHpTotal` gave it only to single-class warriors. `ClassCal.ConHpPerDie` gives a class's adjustment per hit die for Constitution 3 to 25 (`conBonusTbl` was 3..20, and the warrior extra stopped at +2 for 18): +3 at 17, +4 at 18, +5 at 19..20, +6 at 21..23, +7 at 24..25, as Curse's fix for the same bug does. #616. a43f9c9.
- Thief skills: `dexAdj` ran Dexterity 9..19; 20..25 come from Deities & Demigods. Cleric bonus spells: `AwardWisdomBonus` stopped at Wisdom 17; it now adds `GDConsts.wisBonusSpells`' rows cumulatively from 13 to the cleric's Wisdom (PHB to 18, D&DG 19..25, spell levels 1..7). Clerics here cast levels 1..3 (`Types.CASTER_LEVEL_LAST`), and only those take slots, still only where the level already has some. b0d6276. The running totals for 18..25 at every spell level are pinned in TClasCal for the later games. dd34e93.
- Hit-die floor: from Constitution 19 a hit-die roll of 1 counts as 2, from 21 a 1 or 2 counts as 3, from 23 anything below 4 counts as 4, in any class. `ClassCal.HitDieFloor` gives the floor, and `RollFirstLevelHp` (creation and training) rolls the dice one at a time and raises each to it before the level-1 minimum; below 19 every roll is as before. 9be4553.
- Poison saves and regeneration: `AbilAdj.ConPoisonSave` (+1 at 19..20 up to +4 at 25) is added to the two poison saves the engine rolls (a monster's poison touch and a stinking cloud). `AbilAdj.ConRegenMinutes` gives a point every 60 minutes at Constitution 20 down to every 10 at 25, and `EffConRegen` re-arms at the creature's interval. The Manual of Bodily Health gave regeneration instead of the hit-point change at Constitution 20 or more, so the table above 20 never paid out, and each further Manual stacked another regeneration effect; it now applies the hit-point change at every Constitution and adds regeneration only to a creature without it. e02aa7e.
- Strength and Dexterity's combat adjustments already matched D&DG to 25.
Differs from SSI: SSI's tables stopped at 18 to 20 and multi-class warriors lost their bonus. #646 (PR).

**Ability scores stay within 3..25 in play.** `AbilAdj.ClampScore` keeps a score within `SCORE_MIN..SCORE_MAX` (3..25), and every place play changes an ability score goes through it: the Manual of Bodily Health's +1 Constitution, Enlarge and Strength setting and restoring Strength (`EffExtraStr`, `AdjustForNewStrength`), Friends' Charisma and its restore, and mummy rot's Charisma loss. Raise Dead lowered Constitution down to 0; it now stops at 3. The disease Strength drain keeps its own stop at 3, where the creature becomes helpless; creation and Modify keep their own limits; scripts cannot write ability scores. #615. 4ab81cb.

**Keoghtom's Ointment revives only a character the poison killed.** Since the POR-0016 fix the ointment brought back any dead target carrying POISONED. POISONED survives death from any cause, so a character kept up by Slow Poison and then killed by a wound or by bleeding out got up again. The handler now notes whether Slow Poison is still on the target (`SLOW_POISON_END` or `SLOW_POISON_HIT`) before curing, and revives only when it is not, the rule #423 gave the temple's Neutralize Poison. #475 (caused under #16). 5626d78.

**Join keeps a readied stack's Ready.** Joining merged every matching stack into the one Join was chosen on, and that stack kept its own state, so a readied stack merged into an unreadied one lost its Ready (readied arrows 83 joined from an unreadied 20 gave 118 arrows, none readied). A readied stack merged away now leaves the result readied; the count of readied stacks never goes up. #595. cf01d69.

**A random javelin is a Javelin of Lightning one time in five.** `GenerateRandomItem`'s javelin case took word index 144 of the random-item templates one time in five. Templates start at 8n - 7, so 144 straddled the end of template 18 (Bag of Holding) and the start of 19 (Cloak of Elvenkind), and the javelin was named from neither (name ids 0, 229, 167, weight 88, value 25, junk spells). It now takes template 14 (index 105), the Javelin of Lightning, which nothing had selected. POR-0165, #638. f4a2cb0.

**Camp's two rests set the rest clock the same way.** The memorize and scribe rest (`CampRestMenu`, SSI's code) put every whole hour into the rest clock's hours with days 0, while the Fix rest split its minutes into days, hours, turns and minutes; a memorize rest past a day showed 24 or more hours until the countdown carried them. Both now start the clock through `Clock.SetFromMinutes`, so the Rest Time line is always in range; the time rested is unchanged. #644. 99753e5.

**Share pays out only what the pool holds.** See section 3 (POR-0151).

**Racial level caps read from a table; a level at or past the cap counts as capped.** `CharHlp.AtLevelCap` now reads the racial caps from a table by race and Strength band. SSI's tests matched some levels past a cap and not others, which only a character over its cap (after a Strength drain) could reach; at or past the cap now always counts as capped. TCharHlp checks the table against SSI's tests for every race, class, Strength and level. f8bcdf0.

**Scribing needs magic-user levels.** Clerics, fighters, thieves and the rest were told they had no copyable scrolls. A character with no magic-user levels is now told "Scribing a scroll requires arcane training." in the message window. #671 (open PR #673). 97f6859.

---

## 3. SSI quirks fixed (and the ones labelled)

During the byte-for-byte reconstruction SSI's oddities were kept and marked with `Note:` comments. Phase 3 of the refactor dealt with all of them, and a later batch fixed the ones first kept.

**Quirks without effect removed.** `Portrait.DisplayCharPortrait` built head and body numbers as strings and never used them; `Money.TakeMoneyMenu` counted into `cnt`, never set and never read; `EffHndlr.EffGauntlets` tested `q^.id < $80`, always true for `C_Effect.STRENGTH`, now written as what it came to; `EclMenu.GetEclVar`'s `vHi` held the low byte and `vLo` the high one, now `lo` and `hi`. No behaviour change. f0178a8.

**CGA text colour on repeated glyphs.** `TextRend.RenderChar` mapped a CGA colour through `attrTable` once per copy, so a run of the same glyph drew every copy after the first in another colour. The colour is mapped once. POR-0155, #625. b808e70.

**Restoration in the spell book.** The spell book listed known spells 1..55, so Restoration (56) never showed. It lists all 56. POR-0153, #623. b808e70.

**Plain '2' and '-' during the AI's turns.** During AI turns a plain '2' toggled quick magic and a plain '-' ran the STING victory cheat, as Alt-M and Alt-X do: the extended-key prefix was read and then forgotten. Both now need it. POR-0154, #624. b808e70.

**Share pays out only what the pool holds.** `Money.ShareMoney` divided each coin type by the creatures `PoolMoney` empties (npc 0 or an animated party member) but paid a share to every creature without `C_Npc.FLAG`, hired NPCs too, so with a hired NPC more went out than the pool held. The divisor (`CountSharers`, was `CountPoolers`) now counts the creatures that are paid. POR-0151, #621. 74825ad.

**CalcDistance restores the target count.** `CharHlp.CalcDistance` rebuilt the target list to measure, then put the old list back but left the rebuilt list's count. It restores the count too. POR-0152, #622. 74825ad.

**The rest fixed or labelled.** Fixed without effect on play: CombatSt's terrain classes repeated eight values in later case arms that the first arm always took; `DaxIo.WriteChar` indexed the 16-entry CGA attribute table with the whole attribute byte and now maps the low four bits (POR-0156, #626); `GDConsts.insertDiskMsg` is sized by `Types.LAST_DISK`. Labelled "SSI quirk, kept" at the time: the Surprise result, fleeing hostiles' diagonals, `Blit.FillPicRect`'s extra row, the $80 string value's address in `GetEclVar`, and `RobItems`' cumulative weight penalties. No `Note:` comment is left. d9dbbc1.

**The six kept quirks fixed (POR-0159..0164).** Each had been kept only so the port matched v1.3; judged on its merits each is a bug, and all are now fixed. Differs from SSI in each case:
- ECL SURPRISE: both rolls succeeding now stores 3, both sides surprised; SSI overwrote it with 2. POR-0159, #629.
- Fleeing hostiles take the party's facing; SSI's arithmetic turned north into NW and south into SE. POR-0160, #630.
- `FillPicRect` with a negative y fills from row 0 to the rectangle's bottom inside the picture; SSI filled a row more and skipped the bottom check. No caller passes a negative y. POR-0161, #631.
- `GetEclVar` gives 0 for a string value, whose text is in `gbStrings`; SSI read the GBVM at an address made of the packed length and a stale byte. POR-0162, #632.
- ECL ROB: each item's weight penalty comes off the robbery's chance (`CharHlp.TheftChance`), not off the running chance, so heavy items no longer shield the items after them. POR-0163, #633.
- Removing the Gauntlets of Ogre Power takes off the first Strength effect that is not superseded while the wearer is at 18/00; SSI tested the effect id against $80, always true, and could take off a superseded one. POR-0164, #634.
bf00fc8.

**Fatal errors quit to DOS in text mode.** Seven fatal errors restored the screen, printed a message and quit, in three variations. `Blit.RestoreVideoMode` swaps the current and saved modes, so the four that restored twice left DOS in text mode, but `Put8x8Symbol`, `Show3DSprite` and `Load24x24Set` restored once and `ExitGame` then set graphics mode again: their message was wiped and DOS left in graphics mode. SSI's v1.3 has the same sequences. `GameIo.FatalError` sets the starting text mode directly, prints, waits for a key and exits through `ExitGame`; all seven call it. POR-0167, #641. 06edb0d.

**Space in combat treats animated creatures the same from the menu and the AI's turn.** The combat menu's Space put every non-NPC creature back under manual control, animated ones included, while Space during AI turns (`CombatAi.CheckKeystroke`) left animated creatures on quick-fight through `CharHlp.ComesUnderPlayer`. SSI had the same split. Both now call `CombatAi.AllToManual`; Alt-M in both places is `CombatAi.ToggleQuickMagic`. POR-0166, #640. 206471b.

**The temple's "you left some money here" prompt.** The temple's copy of the go-back prompt cleared the window before drawing its question, so the priest's words vanished before they could be read; with `Money.GoBackForIt` shared by the shop, temple and post-combat loot, it now shows both lines. POR-0157, #627. 4d84fd9.

**"will be gone forever".** Dropping an item said "Your Long Swordwill be gone forever"; a space was added (POR-0158, #628, 563481a). That then gave two spaces, because `CharHlp.ItemLabel` already ends the label with one, and the extra space was removed (#655, 1ebfea6).

**A 39-column bottom menu clears column 39.** `MenuCore.HorizontalMenu` blanked the rest of the bottom line only when the query and menu were under 39 columns, so a line exactly 39 long left column 39 as the previous line had it; Camp's Rest menu showed "EXITT". The test is now `<= 39`. The `< 39` is SSI's own, in the v1.1, v1.2 and v1.3 sources. #502. 9c30121.

**The out-of-memory save.** See section 1 (POR-0168).

**A random javelin.** See section 2 (POR-0165).

The picture cache's disk-blind key (POR-0134) is in section 9.

---

## 4. Combat and the combat AI

**The combat AI walks round walls and bodies to its target.** The AI headed straight at its target each step, falling back on a few fixed side-steps, so a wall or a dead end left it strafing back and forth. `Pathing.RouteStep` now finds, breadth first over the arena, the first step of a shortest walk that brings the creature's body next to its target's: a cell is open when it is on the arena, not a wall and no other creature's (`CbtMap.OccupantAt`), for bodies of every size, with the steps nearest the heading tried first. The AI takes that step when it can pay for it (`CanStepDir`, split out of `AiCanStep`); otherwise, and when fleeing, it moves as before. TPathing checks routes on open ground, round a wall, out of a dead end, through and blocked gaps, and for a 2x2 body. Differs from SSI. #668. d184cc3.

**A party member under Quick bandages a dying teammate.** As in Curse, the AI's move and attack loop starts, for a party member, by bandaging the first dying teammate, which ends its turn. `Combat.BandageDying` moves to Combat's interface. Differs from SSI. #654. ae01b88.

**A hit that interrupts a spell takes it from the caster.** When a creature casting a spell with a casting time is damaged, the game prints "<name> lost a spell" and removes the spell. `CharHlp.RemoveSpell` took only the spell id and cleared it on `GDVars.curChar`, which at both interruption sites is someone else (the attacker in `CbtActs.ProcessAttackResult`, the caster of the damaging spell in FxEngine's damage path). So the interrupted caster kept the spell and the attacker lost a copy. `RemoveSpell` now takes the creature, as in Curse, Secret and Pools. POR-0148, #540. 7ea2a30.

**An AI caster hurt by its own delayed spell keeps its other copies.** `CombatAiControl` resolved a spell begun earlier with `spellCast` still set, which `EndActions` cleared only afterwards, so an AI-run caster caught in its own spell's area counted as interrupted and lost a second memorized copy. The AI path now copies and clears `spellCast` before it casts, as the manual path does. POR-0149, #556. f248c91.

**An AI caster with a pending spell resolves it before anything else.** `CombatAiControl` tried `SelectItemToUse` before the pending spell, so an AI-run caster could use an item instead, and the spell was dropped yet stayed memorized. The pending spell now comes first and is the whole action, as on the manual path. POR-0150, #557. c89d49e.

**Under Quick, the bottom line shows how to leave it and whether its magic is on.** While any of the player's characters fights under Quick, each AI turn shows "Quick: On (Space) Magic: On/Off (Alt-M)", labels in light magenta and the rest in white, and the moves-left prompt no longer writes over it. Alt-M redraws the line; with no one under Quick it still says Magic On or Off. #665. c06be1b.

**Space and Alt-M in combat.** See section 3 (POR-0166) and the plain '2' and '-' fix (POR-0154).

**Combat slot 0 and the hold effects.** See section 9 (#515, #530).

---

## 5. User interface: menus, screens, keys and messages

**Up and Down step through the party.** On the start menu only Home and End stepped through the characters added; Up and Down now do the same (#590, bdb935b). Then `Party.SelectPrevNextChar`, which every menu that switches character uses (Camp's menus, the shop, the vault, post-combat and the script menus), takes Up as Home and Down as End; before, Up and Down selected the head of the party. The start menu's own mapping was then no longer needed (#653). Party Order's Place mode moves the selected character up with Up as well as Home and down with Down as well as End (#650). 14829ff.

**Icon editor.** Exit was drawn on the bottom line as one of the editor's own items while keys were read through an empty menu, so E did nothing; the bottom line is now a real `MenuHorizontal` menu with E as Exit's hotkey, cleared while the grid is up (#585, c4897b7). The menu now reads Keep Exit: Keep (K) asks "Is this icon ok?" and ends with the icon as designed; Exit (E, or Escape) ends with the icon as it was when the editor opened, putting back head, weapon, size and colours (#586, 4f38cd6). The character's name at the top of the left pane is cyan rather than item green (#587, 41897c3). When an item has more than 16 options the grid shows "(more)" rows (the 32 weapons are now three pages: 1-12, 13-20 and 21-32); the font has no arrows, so the rows read "(more)" (#589, a75e6de).

**Portrait picker: Keep instead of Okay.** The menu reads Keep, with K as its hotkey; it shows the pick alone and asks "Is this portrait ok?" as Okay did. #588. e0d8e0a.

**Menu prompts and settings notes.** In the owner's batch, the Alter, Camp, Aim, Settings, More and View prompts gain a trailing space, and the STING and NORAND notes on the Settings screen likewise. 038f32e.

**An aligned weapon's shock message in two colours.** `CharDisp.PrintMessageWait` printed the whole message in light green. It now prints through `MessageText`, which shows a part in a colour of its own and carries on where the last part stopped, and `MessageWait`; the shock message (`FxEngine.NonWeaponDamage`, for an aligned weapon its wielder may not use) prints the item and the character's name in light green and "shocks", the damage and "has been unequipped" in white. #637. 3b91dfe.

**Camp's scribe and drop messages end with full stops.** The scribe menu ("has no copyable scrolls", "You already know that spell", "You are already scribing that spell", which read "scibing") and drop menu ("bids you farewell", "is dumped in a ditch", "Breathes A sigh of relief") end their sentences with a full stop. #648. 1ebfea6.

**The campfire shows as soon as camp's screen is redrawn.** The campfire is an animation the camp menu draws while it waits, so after the save menu the "Quit to DOS" prompt sat over an empty, black view. Redrawing camp's screen now draws the current frame at once. #666. 72ba6aa. (Camp had already been changed to redraw its screen after Save, before asking Quit to DOS, in 3b2c103.)

**Escape backs out of choosing who duels.** The three WHO prompts that choose who duels (the training hall's arena, the Pitt's buccaneer, the Lizardman Keep's champion) add Exit: Exit or Escape picks no one and sends the script back to the duel's question. Other WHO prompts still need a character, as SSI's did. #661. c6af0e8.

**Missing data files say which file, and the right drive.** A data file that could not be opened brought up only "Insert disk N in drive X:". `OpenWithRetry` now first shows "Not found: " and the file's full path (a path too long for the line keeps its end), then the prompt. The drive letter came from `gameDir[1]`, which GameInit and the introduction empty while they read from the current directory, so it was a stale byte; `DaxIo.DataDrive` gives `gameDir`'s drive, or the current drive while it is empty. 5f94e63.

**The introduction skips the Brazen Crows picture when RAVFULL.DAX is missing.** RAVFULL.DAX is not one of the game's own files; without it the game stopped at "Insert disk 1" before the title. The picture is now shown only when the file is in the directory the introduction reads from. 4d19483.

**Statistics screen, View menu, Settings screen, Load/Save menu, Fix messages, Journal "(more)", scribing message.** See sections 1, 2 and 6.

---

## 6. Saving, loading, quick save and the vault

**Full-screen Load/Save menu, with descriptions, areas and times.** Loading and saving chose a slot from a one-line letter prompt. The new `SaveMenu` unit shows the slots full screen, titled "Load/Save Game Menu": each slot shows its letter and description, then the area and the time the file was written. Up and Down move a slot at a time and the list scrolls, with "(more)" when slots are hidden, and Page Up and Page Down move a screenful; the menu opens on the newest save. Loading lists saved games only; saving lists every slot, an unused one as EMPTY. Saving asks for a description (30 characters at most) starting from the slot's old one. The description and area go in `savgam<x>.inf` beside the save, a small versioned record. The area comes from the new `AreaName` unit: the Clue Book's names for scripts 0..29, shortened to 18 columns, keyed by the script a save reopens (`previousScriptId`) and, for the four scripts that run two maps, the map; anything else reads UNKNOWN AREA; a save without an .inf has its area read from the save file. Camp redraws its screen after Save. #604. 3b2c103.

**Load/Save menu revised: letters take a slot, a new layout, a one-step save prompt.** A slot's letter (A-J, Q) now takes it at once: saving opens its description prompt, loading loads it (#652). The list keeps a column clear inside its border, shows the time beside the description and the date under it, each letter in white; the bottom line reads Game: Next Prev Save (or Load) Exit, with Exit reached by the arrows only, since E is a slot (`MenuCore.unmarked`) (#657). The save prompt shows the slot, location and description, which reads SAVE GAME X while empty (#656). A description is typed, and shown, up to 27 characters (`DESC_SHOWN`), so the time fits beside it; the slot-info file still holds 30, and a longer old description is cut to 27 when shown or edited. 078b01f. Because every letter goes to the description, the save prompt's bottom line then became "Save: Exit" with no hotkeys: Enter saves and Escape goes back (#657 follow-up). 2748c77.

**F5 quick save and F8 quick load.** On the map menu (3D or wilderness), F5 saves into a new slot Q, described as QUICK SAVE, with no menu, and says so; F8 loads it. Q is listed after J on the Load/Save menu. F8 with no quick save says so. Elsewhere F5 and F8 say quick save and load are unavailable, and in combat they are ignored silently (`MenuCore.quickKeysToCaller`, set by the map menu). A quick save records the running script as the one it reopens. F8 sets `Explore.quickLoadAsked` and returns from `GameLoop`; the program frees the party (records, items, effects, usual spells and icon animations), loads Q as the main menu would, and runs `GameLoop` again. `LoadGame` and `SaveGame` are split into `LoadSlot` and `SaveToSlot`. #605. 7a3305d. Follow-up fixes: `quickLoadAsked`, `extraKeys` and `quickKeysToCaller` are now set in their units' initialization (`quickLoadAsked` could start nonzero, making the first move on the map run a quick load), and QuickLoad checks the quick save exists before freeing the party, resuming the game in memory if not. #605. a955646.

**The vault: The Hoarder's Respite in New Phlan.** New Phlan's tavern at (8,9) becomes a vault, after Secret of the Silver Blades and Pools of Darkness. The merchant greets the party ("WELCOME TO THE HOARDER'S RESPITE. LET ME LIGHTEN YOUR LOAD.", or on a return visit, one time in 20, "OH, YOU'RE ALIVE... I MEAN  WELCOME BACK!"). Its menu is View, Take (while there is anything), Pool, Share (while there is money) and Exit; in View, Drop becomes Deposit for money and items, which go into the vault. The vault holds at most 100 items. Storage follows Pools of Darkness: during play the vault is `tmpvault.dat` in the save directory (a small header with the money and a visited flag, then the items); saving copies it to `vault<x>.dat` beside `savgam<x>.dat`, loading copies it back, and starting the program forgets it. New interface state `C_Ifc.VAULT`. The data change is in section 7. New feature, not in SSI's Pool. #606. a955646.

**The script buffer grows to 9,984 bytes; the area's script is reloaded with a saved game.** The script buffer (zone 3) held 7,680 bytes ($9900..$B6FF), SSI's size from the 8-bit versions, and five area scripts were within 26 bytes of it, so data fixes had to be same-length rewrites. It now runs to $BFFF: nothing in the script address map lies between $B700 and the first special cell, $C04B, and scripts address themselves absolutely from $9900. `C_Gbvm.SCRIPT_FIRST` and `SCRIPT_LAST` name it; `LoadEclScript` and DataBld's cap follow `SizeOf(TZone3)`. A saved game still holds SSI's 7,680 bytes where SSI held them (`C_Gbvm.SAVED_SCRIPT_BYTES`), so save files stay 13,137 bytes and older ones load as before (#607). A loaded game now loads its area's script from the data, as Secret of the Silver Blades does, instead of the copy in the save, which kept a script from before any later data fix (a game saved in New Phlan kept the tavern where the vault now is). `EclInit` still keeps a loaded game's script words. A save now records the running script as the one it reopens, since `NEWECL` leaves the old area's id until the map menu returns (#609). Differs from SSI. d23c774.

**Deterministic saves.** Two saves of the same game differed byte for byte. Character, item and effect records were written raw, heap pointers included (loading ignores them); they are now written with their pointers nil, layout and pads unchanged, so the files still load here and in SSI's executable. `SaveToSlot`'s table of party names was not cleared, leaving stack bytes; it is cleared first. The vault's items are written without their link. 8048f48. A character's `equipped[]` slots, pointers into its items, were saved as they were and kept on load until something called `RecalcStats`; `CharHlp.LinkEquipped` (RecalcStats' slot rebuild) now runs once the items are read, and `SaveChar` writes the slots cleared. #620. 9a3f33c.

**A save no longer sets the menu animating over the view.** A save wrote the wall slots into zone 0, where the last of them is the GBVM's menu-animation flag, so the next menu drew the last picture loaded (the treasure, after a fight) over the 3D view. The slots now go to the file only, and a load clears the flag it reads in. The save files are unchanged. #651. 5d4e0cc.

**One "Put save disk" retry.** The save files were created in two copies of the same loop and the "Put save disk in C:" text built in six places; they are now `SaveLoad.RewriteSaveFile` and `SaveDiskMsg`. Loading a slot that cannot be opened now asks as the rest do (it showed the whole path with no colon). 35f21e7.

**The usual-spells file is read when write-protected.** The .mem file was opened read-write, so a write-protected one was taken for missing; it is opened read-only (via `FileUtil.OpenReadOnly`). #635. 55b640e.

**Saved map position written field by field.** `SaveGame` and `LoadGame` wrote and read five bytes from `gMapX` on as one block; each is now read and written by itself, in the same order, so the file is unchanged and the variables can move. 10f9b84.

**Exit to DOS, the destroyed party, the out-of-memory save.** See section 1 (#660, #658, #643).

**Load-time guards.** `LoadGame` holds `gameDelay` to 9 (see section 9, #440).

---

## 7. Data fixes to the shipped scripts and items (DataPat)

DataPat is the table of patches DataBld applies to SSI's data when it builds the merged archives. `C_Data.VERSION` is the data version; raising it makes the game rebuild the merged archives at the next start.

**The vault's script (data version 32).** A DataPat fix sends event 20 in New Phlan's event table to new code at the end of the script. Every other event-20 square (six other tavern doors) goes on to the tavern as before; at (8,9) the code does what the arms shop does (once a visit, the shopkeeper, the refusal after an attack on the city watch), stores 2 in [$6E6C], the shop cell, and runs COMBAT with no monsters, which `EclCombat` now takes to the vault. 52 bytes; the script stayed under the then 7,682-byte limit with 157 to spare. A game saved inside New Phlan before this kept the tavern until the party left and came back (later fixed by #609, section 6). #606. a955646.

**The Pitt's buccaneer's question gets its space (data version 33).** The PRINTCLEAR at $A90D (Podal Plaza, script 18) ran the closing quote into the next sentence: "WHO WILL IT BE?'WHAT DO YOU DO?". The packed string had an empty six-bit slot at its end, so the space fits in the same 66 bytes. The boot scenario strips the data version from the settings screen, since the golden build has its own. #670 (open PR #673). e747259.

**Random javelin template.** Not a DataPat change but a fix to item generation; see section 2 (POR-0165).

**Tests for the patch table.** TDataPat checks the rules DataBld relies on: the parts use every byte of `patchBytes`, each names a family DataBld builds, its original bytes lie inside the block, its size is the block's after the parts before it, and a fix's parts are together. 41160a7.

---

## 8. Video (the driver refactor, VGA), memory, overlays and EMS

This is phase 6 of the refactor plan, with the overlay and memory work around it.

**A video benchmark, and the regression suite in CGA and Tandy (phase 6, step 0).** `bench/vidbench.sh` compiles `bench/vidbench.pas` and runs it in each video mode under DOSBox-X at a fixed 10,000 cycles, timing `RenderChar`, `BlitTileCell`, `FillPicRect` and `FlushView` on game-shaped workloads. The baseline: EGA is slowest at everything, and its `FlushView` takes 25.7 ms for the whole view against CGA's 2.0 and Tandy's 2.9. `VIDEO=cga` and `VIDEO=tandy` make `tests/regress.sh` run in that mode (POOL-CGA.CFG, POOL-TANDY.CFG), each with its own golden record; Tandy uses a Tandy machine. bd7a01e. All nine scenarios pass in both modes, so phases 1 to 5 changed neither mode's screens (loadsave needed goldbox-player 14eda0e). 6127810.

**Game code no longer asks which video mode it is in (step 1).** Every video-mode branch outside the video units moves behind Blit or a new overlaid unit, `VidOps`: Blit gains `FrameBytes`, `MaskBytes`, `ColourCount` and `HasPalette` (and `SetPaletteRegister` does nothing without a palette); `VidOps` holds the cold operations (`ModeName`, `InitRowTables`, `MergePic`, `OverlayPic`, `RecolorPic`, `PutPixelRow`); CbtActs, CharDisp, MapTiles, CharGen and Portrait take mask and frame sizes from Blit. Only Blit, TextRend, DaxIo, GameBoot and VidOps read the mode afterwards. ce0ae5d.

**A video driver record (step 2a).** `Types.TVideoDriver`, in `GDVars.video`, describes the mode: name, colours, palette, and picture layout as shift counts (`cellShift`, `screenShift`, `maskShift`), with `CellFill`. Resident units `VidCga`, `VidEga` and `VidTdy` fill it; GameBoot installs the one POOL.CFG names. `BlitTile`, `FillPicRect`, `OverlayPic` and the size queries read the record instead of branching. `BlitTile` keeps a fast path for a mask byte per picture byte (CGA, Tandy), and `FillPicRect` fills a one-byte cell row as a run and stores EGA's four-byte cells as LongInts. The commit reports speed against step 0 as: tiles -7% on CGA and -4% on EGA and Tandy; the view fill +54% on CGA, +144% on EGA and unchanged on Tandy; fill and flush +24% on CGA and +21% on EGA. Read as speed, the tile blitter is a little slower through the record and the fills are faster. db8ff7b.

**The drivers draw to the screen (step 2b).** The record gains `biosMode`, `ramVideoParas` and entries `Start`, `FlushSpans`, `ShowPic`, `DrawGlyph`, `ClearRect`, `ClearScreen` and `WriteChar`; the per-mode code from Blit's, TextRend's and DaxIo's case arms moves into the drivers. GameBoot sets up every mode the same way: install the driver, keep a system-RAM screen (Tandy's) out of the heap, set the BIOS mode, call `Start`. b9e7517.

**Cold picture routines in an overlaid unit per mode (step 2c).** The record gains `ExpandFrames`, `MirrorFrame`, `RemapColour`, `RecolorFrame`, `PutPixelRow` and `InitRowTables`, implemented in overlaid `PicCga`, `PicEga` and `PicTdy`. Nothing reads the video mode any more, so `GDVars.videoMode` and `Types.TVideoMode` are gone: the driver is the mode. Resident code 3,072 bytes smaller; overlays 3,731 larger, one mode's unit loaded at a time. 07c1ee9.

**TVidPic tests each driver's picture routines (step 4).** Each driver is installed in turn and a one-cell, two-row picture is converted and checked against bytes worked out from the mode's layout: frame and mask sizes, data and mask, mirror, remap, fill and a masked blit (39 checks per mode). `build.sh`'s test runner also looks in `obj` for object files such as SOUNDDRV.OBJ. 9945bc4.

**Ctrl-Y shows the heap that pictures hold (step 5).** `Blit.AllocPic` and `FreePic` count picture memory (`GDVars.picBytes`, peak in `picPeak`), shown by STING Ctrl-Y after the heap line. Measured in EGA at the scenarios' ends, for weighing VGA's layouts. e0b713b.

**A VGA video driver: a byte a pixel, with a colour key.** `VidVga` (resident) and `PicVga` (overlaid) drive BIOS mode 13h, chosen by POOL.CFG's video letter V. Pictures take a byte a pixel (8 bytes a cell row), and a transparent pixel holds `Types.PIC_KEY` ($FF), as Dark Queen of Krynn does; the mask is still kept a bit a pixel, so code that checks or copies masks works unchanged. The 16 colours are DAC entries 0..15. The record gains `keyed` and `SetPalette` (EGA's BIOS palette call moves into `VidEga`; VGA writes the DAC). Blit's tile loop and VidOps' merge and overlay gain keyed paths, `Blit.ClearPic` clears a picture to transparent for CharGen's icons, and `TCellBytes` grows to 8 bytes. A picture too large for one 64 KB heap block continues in `TImgBuf.more`, followed by `AllocPic`, `FreePic`, `ExpandPicFrames`, `BlitTile` and `RemapPic`, with `Blit.FrameBlock` and `FrameCount` for MapTiles; of the game's 809 DAX pictures only SQRPACI's two wilderness tile sheets need it in VGA, and a single frame too large for any block stops with a message. TVidPic checks VGA and a split sheet (58 checks); `tests/regress.sh` runs VGA with `VIDEO=vga`. Heap measured: 156,864 free at boot (EGA 302,408), 84,896 at the end of combat. New feature: SSI's v1.3 had CGA, EGA and Tandy only. 2a8f97c.

**The second wilderness tile set loads when needed, and combat frees it.** SQRPACI block 2 (tile ids 128 and up) is drawn only by the wilderness and the ending, yet GameInit loaded it at boot and kept it all game (37 KB in EGA, 74 KB in VGA). `MapTiles.SecondSheet` loads it the first time a tile from it is drawn or the ending remaps it, and `LoadCombatTileSet` frees it (`FreeSecondSheet`). VGA at the end of combat: 158,672 bytes free with a 134,920 largest block, from 84,896 and 56,280. a745a44.

**Overlays load from EMS when there is room.** GameBoot calls `OvrInitEMS` after `OvrInit`, so the overlays are copied into EMS when there is enough and load from there rather than GAME.OVR; without EMS, or with too little, they load from disk as before. `GDVars.ovrInEms` records which, and Ctrl-Y's buffer line ends "from EMS" or "from disk". Conventional memory is unchanged. `tests/regress.sh` takes `MEMSIZE=N`; the suite passes at 1 MB (disk) in EGA, CGA and Tandy and at 16 MB (EMS) in EGA. 3d10dc2.

**Overlay probation and the load count.** GameBoot turns on overlay probation (`OvrSetRetry`, a third of the buffer), so units a stretch of play keeps calling stay in the buffer, and counts every overlay load through `OvrReadBuf`; Ctrl-Y shows it. #612. 5226426.

**Phase 6 status.** The plan records phase 6's status and what is left. de5c623.

Phase 5's overlay working-set changes are in section 10.

---

## 9. Robustness guards from the source review

A review of every unit (issues #424 to #466) turned up places where damaged data, out-of-range values or paths the shipped game never takes could read or write outside a table. Unless an entry says otherwise, nothing changes in play with the shipped data.

**Wilds.** `BuildWildernessMap` read `wildMap` for the 5x5 cells from the corner with no bound; it now moves the corner onto the 44x36 map first, as `DisplayMapView` does. #466. 4726a68.

**Pathing.** `WalkLine` fails at once for an endpoint outside the 50x25 arena; `IsDirToward` counts any direction above CENTER as CENTER (it read past `dirDX`/`dirDY` and left its result unset for 9..254); `BuildTargetList` stops at 72 creatures; `bestK` and `bestJ` start at 0. #457. 762382c.

**PostCbt.** `DetermineLootExp`'s per-hit-point experience product of two Bytes was computed as an Integer and could wrap negative (200 * 200 gives -25,536); one factor is now a LongInt. #459. 9126e4c.

**GameTime.** `TimeOutEffects` summed minutes in a Word (overflowing at 46 days, or any months or years) and took segments as minutes; the total is a LongInt and segments count ten to the minute. An expiring effect is removed only while its id and duration still match, so a handler that frees one effect and allocates another at the same address cannot have the new one removed (caused under #144). `CheckMemorizeDone` and `CheckScribeDone` pass over a pending spell outside 1..`C_Spell.LAST`. `AdvanceSpellPrep`, `AdvanceSpellPrepBase` and `CampRest` stop at the last of the 8 prep timers. #444. a2a78a7.

**Money comments.** `MakeChange`'s comment now puts the copper-loss point at about 429,581 gp (caused under #130), and `TakeMoneyMenu`'s no longer says the coin list leaks (fixed under #162). #456. 8cd006c.

**Ending.** `PlayFinalAnim` returns if the FINAL picture did not load, instead of reading frame 0 outside the table; `LoadGame` holds `gameDelay` to 9, the top of the speed menus, so `WinGame`'s cycle counts and other delay-scaled waits cannot wrap. #440. 0866afc.

**Intro comments.** `DelayOrKey` and the title-2 loop never read the key, so one key ends the rest of the introduction (v1.3's behaviour); the comments now say so. #451. c1a966c.

**GameInit.** `GameInit2` read ITEMS under `$I-` without `IOResult`, leaving an error pending for the next check and missing a short read; a failed or short read (fewer than 128 records) now stops with "Unable to read ITEMS.". #443. 5551afb.

**HeapErr.** `HeapErrorHandler` now sets its result (0) before anything else; for a zero-size request it returned whatever was in the slot. Turbo Pascal never calls it for zero bytes. #447. 9a3220b.

**GDConsts.** Class usability bits or-ed rather than summed (section 1). #445. 1683b84.

**GDVars.** The 45 readers of `baseItems[0..127]` indexed it with an item's Byte type unchecked; they go through `CharHlp.BaseItem`, which returns an always-zero overflow entry for a type past the table (new `Types.PBaseItemRec`). #446. 6b88e1b.

**Picture caches key on the disk and forget failed loads.** `Portrait.LoadAnimation` cached on (name, picId) though the archive opened is name plus the virtual disk, and recorded the key before the load, so a failed load was cached too; after a disk switch the same PIC id gave the previous disk's picture or nothing. `LoadPortraitBufs` had the same disk-blind key. The key now includes the disk digit and is set only once data is returned; each portrait slot records its disk and reloads when it differs, and a failed slot stays invalid. POR-0134, #408. 3dff605.

**CharGen.** `CreateCharacterMenu`'s header comment brought up to date (aborts free the character and list since #165); `dsStartingAge`'s class axis grows to 0..7 with the DMG's human monk age (21 + 1d4), since creation rolls age for any class up to MONK. #430. 537400e.

**CharHlp.** `CombatAnimateMovingIcon` read `steps[148]` on a 49-cell path; `steps` has a 149th slot left at "no move", and the filling loop stops at 148 steps. #431. 1eebf28.

**Camp.** `CampScribeMenu` refuses ("You can not scribe that spell.") a scroll spell past `spellsKnown` or with a table level outside 1..3 or a casting class outside 0..1, rather than indexing unchecked; `CampFixMenu`'s comment now says a conscious (status OKAY) caster. #427. ca0c18e.

**MenuCore.** `MenuVertical` paged on N and P whether or not Next or Prev was offered, which on a short list made the top negative and dereferenced nil; N and P now page only when offered. #455. bfd8a41.

**TextRend.** `RenderChar` draws nothing for a raw glyph index past the 177-glyph font; `DisplayMessageWindow` splits a word wider than the window and `PrintCharInWindow` stops at `lrCol`; `ClearRect` and `FillRectEga` do nothing unless the rectangle is on the 40x25 screen with its corners in order; `DisplayMessageWindow` requires `lrRow <= 24`. #463. 056a9bd.

**Shop.** `ShopBuyItemSelection` copied up to 40 characters of name into a `String[30]`; the copy now stops short of the price with a blank between. #461. a6d8efa.

**ViewChar.** `UseItemMenu`'s loop also ends when the item list is nil; `UseItemSpell` and `Magic.CastSpellNC` cast nothing for a spell id outside the 67-entry table. #465. 7f4895f.

**C_Keys comments.** `ALT_Q` and `ALT_R` move to the extended scan-code group with `ALT_X` and `ALT_M`; the build was byte-identical. #450. 778d431.

**Portrait.** `LoadAnimation` ends loading at a frame whose header or pixels run past the block or whose height or width is 0 (which would wrap `planeSz` and overrun), keeping the frames before it; a later PIC or FINAL frame is XORed only over the first frame's size. #458. c11fda5.

**Combat slot 0 outside CbtMap.** `CbtMap.CombatSlot` returns 0 for a creature not in the combat arrays; the direct `arenaLoc`/`gridX` indexers in other units now treat that as not on the map: `CbtActs.CombatMoveCreature`, `MoveOpportunityAttacks`, `StingVictoryCheat`, `CharHlp.PrintNameStringAnim`, `FxEngine.PutOutOfPlayWithStatus` and `Combat.MoveMenu`'s Escape undo. #515. a965314.

**Blood drain and bite-hold.** `EffBloodAttach` and `EffBiteHold` attach nothing when the attacker has no target or the target has no combat slot; `CbtActs.BiteAndHold` gets the guard `EffBloodDrain` already had (a strength of 0, or past `arenaCount` or 72, has no victim, and the hold is removed). #530. 7706b6c.

**Hooks start unset.** Writing tests for CharHlp found that `CharHlp.faultHook` was never initialised to nil (globals are not cleared at start-up), so in a test program `RemoveItem` called garbage; CharHlp's initialization now unsets it, and GameIo's unsets `saveSettings` and `showMemory`. In the game all three are set during start-up. e77b594.

---

## 10. Refactor phases 0 to 6 (structure, units, tests, sizes)

The build no longer matches SSI's bytes, so identical bytes prove nothing. `docs/refactor-plan.md` replaces that guarantee with tests (phase 0), then consolidates duplication and improves structure. Sizes quoted are from the build's size report. Phase 6 is in section 8.

### Phase 0: a safety net

**Unit tests (TestKit) and a size report.** `tests/testkit.pas` (Start, Check, CheckEqualsL, CheckEqualsS, Done; failures and a summary to TEST.LOG, exit code 1 on failure); first tests `tests/tstats.pas` (31 checks) and `tests/tareas.pas` (13). `build.sh --test` builds the game, compiles each test program with the game's settings into `obj/tests` and runs it under the same Turbo Pascal in DOSBox-X, failing the build when a test does not compile, finish or pass. Every build reports resident code and data sizes from TPC.OUT and the overlays from FIXMAIN.EXE's stubs (`build/ovlsizes.py`). CI runs `./build.sh --test`; README gained a Tests section. ad2cadc.

**Deterministic saves.** Section 6. 8048f48.

**Behaviour scenarios and `tests/regress.sh`.** Seven scenarios (boot, chargen, loadsave, combat, vault, journal, camp) that goldbox-player's `tools/regress.py` replays against two builds, comparing screen text read from the game's font (the assertion), the frame (a warning) and save files at checkpoints; each boots `START STING NORAND` so dice fall the same way. `tests/regress.sh GOLDEN [CANDIDATE] [SCENARIO...]`; golden builds go in `.golden/<commit>/`; `tests/scenarios/README.md` describes the format. a15842b. Two more scenarios, shop (buying and selling at the arms shop) and areachange (New Phlan to the training hall via NEWECL 11). a19b0ce.

**Tests: logs and boot scenario.** Each test's compiler output goes to `build/logs/tests/<name>.OUT` (8.3 names had made two tests share one log and hidden compile errors), and a test name longer than eight characters is refused; the boot scenario ignores free memory. b88a6d7.

**Tests for ClassCal and DataPat.** TClasCal checks `RecalcBaseSkills`, `AwardWisdomBonus`, `RecalcSaves` and `RecalcThiefSkills`; TDataPat checks the patch table's rules. 41160a7.

**AbilAdj.** The Strength and Dexterity tables (`TranslatedStrength`, `StrToHitAdjust`, `StrDamageAdjust`, `WeightAllowance`, `DexMissileAdjust`, `DexterityArmorAdjustment`) move from CharHlp to a new resident unit using only Types; TAbilAdj tests them. 9bda93c.

**MoneyCal.** Money's arithmetic (`CopperValue`, `CoinValueInGold`, `CoinsOf`, `CreatureGold`, `MakeChange`, `WhoPays`, `ItemBundle`, `ItemValue`, `ItemSalePrice`, `ParseMoneyType`) moves to a new overlaid unit; `MoneyCal.CreatureCopper` replaces `Stats.CoinWorth`. TMoneyCa tests it. Phase 0's unit tests marked done. 124bca6.

**SSI's file formats pinned.** TRecLay checks the sizes of `TCharRecord` (285), `TItemRec` (63) and `TEffectRec` (9) and the offset of all 113 fields, numbers read from the same program built against SSI's v1.3 source; TSaveLay checks SAVGAMx.DAT's parts and 13,137-byte total and zone 0's fields at their GBVM addresses. d7a0f6a. The chargen scenario records the .CHA files; a new `ssiformat` scenario runs with SSI's own v1.3 as the golden build and matches SSI's save files byte for byte once heap pointers, stack leftovers in party names and the (deliberately reloaded) area script are masked. efa574b.

### Phase 1: hygiene

**Every unit lists the units it calls.** 127 qualified calls named a unit not in the caller's uses clause (compiling only because Turbo Pascal accepts `Unit.Name` for any loaded unit); 27 units now list them. `tests/regress.sh` keeps the golden build's results in `GOLDEN/record.json`. e59d379.

**NPC tests.** The npc byte's bit 7 was tested 22 ways; now `CharHlp.IsNpc`, `MayTrade` and `ComesUnderPlayer`. ee892e2.

**`GDVars.stingArg`.** Eight tests of `ParamStr(1) = 'STING'` read one flag GameBoot sets. b271b08.

**`TextRend.ClearBottomLine`.** Resident, replacing MenuCore's overlaid one (which could load an overlay mid-combat) and twelve inline copies. f61f070.

**Named constants.** `NAME_LEN`, `MAX_PARTY`, `LAST_DISK`, `MAP_LAST`, `SPELL_SLOT_LAST`; `View3D.WrapCoords` for the five copies of the map-edge wrap. 9f12bb3.

**Unused locals removed.** 69 locals kept only to match SSI's stack frames (a29b1b8), and later 40 more of any name (af5776e).

**Unused globals removed.** Fifteen GDVars variables nothing used; GameInit clears the position bytes by name; data segment 694 bytes smaller. 29029f3, ace1784.

### Phase 2: shared helpers

**StrUtil.** One `NumStr`, `ZeroPad2` and `PadLeft`/`PadRight` replace six Str wrappers and seven zero-pad copies; resident, using nothing. TStrUtil, 13 checks. 423e76b.

**FileUtil.** `DeleteFile`, `OpenReadOnly`, `ReadRecord` and `WriteRecord` for the game's small files; `SaveLoad.CharFileBase` and `EraseCharFiles` (.cha, .itm, .spc, .mem, .sts). TFileUtl, 10 checks. Also fixes #635 (section 6). 55b640e.

**`CharHlp.LinkEquipped`.** Section 6 (#620). 9a3f33c.

**`RewriteSaveFile` and `SaveDiskMsg`.** Section 6. 35f21e7.

**`Shop.CounterMenu`, `Money.GoBackForIt`, interfaces name only the units they use.** The shop's and temple's counter menus are one routine (Buy is now refused for an extended key, as Heal was); the go-back prompt is one routine (fixes POR-0157, section 3); every unit's interface uses only the units its declarations name (42 units), breaking an interface-uses cycle. 4d84fd9.

**`TextRend.DisplayCentered`.** Ten hand-centred texts. e8df39a.

**`TextRend.ShowMessage` and `ViewChar.SayBelow`.** Fourteen message-window calls and six yellow panel lines; also POR-0158 (section 3). 563481a.

**Money helpers.** `Money.CreatureGold`, `WhoPays`, `PayBy` and `PayGold` replace three pay-here-else-the-pool blocks and a second coin valuation. be0ea4b.

**`CharHlp.FreeItemList` and `ClearTreasure`.** Four item-list freeing loops. af5776e.

**`FxEngine.HasDisease` and `RemoveDiseases`.** The temple's and the paladin's cures; the Cure Disease spell is unchanged. 05c00d9.

**`Party.IsPartyMember`.** Replaces `SaveLoad.InParty`, which in combat counted monsters as party members, and Stats' copy; the usual-spells owner test is the one that changes. #636. d80ea3f.

**Plan updated.** 13888a9.

### Phase 3: structure

**One typed view per shared global.** `GDVars.videoMode` as a `TVideoMode` (f7b088d); `treasureMoney` as a `TMoney` (8cace21); `dsIconAnimation` holding `PImgBuf`s, `TIconPair` gone (32c43ff); one wall-set cache slot type (8687fe1); one animation record, `TMenuAnim` and `TMFrame` gone (4c61f6f); the zones through GDVars' typed pointers, the `Session` unit and nine zone types gone, with `C_Gbvm.MONSTER_HIT_MOD` and `PARTY_HIT_MOD` (35ca447); `gameDir`, the insert-disk and intro flags as Booleans, the menu auto-answer as a `TMenuAuto` (78 bytes smaller), the effect table typed (b8cdce0); the random-item templates read by template and field (a7b29ad); one typed view of the wall graphics, `PWallSlices` (6fe34dd); the spell table split into `castTargetMenu` and `spellFns`, assigned without @ so the compiler checks signatures, and Magic's sounds through `C_Sound` names (62ec8f6). The only absolutes left in src/ are hardware addresses. Plan items marked done: 0f11ab8.

**SSI quirks.** Section 3. f0178a8, b808e70, 74825ad, d9dbbc1; plan 2ab71e9.

**EclVars.** The ECL interpreter's variable and game-memory layer (`LoadEclVars`, `GetEclVar`, `ReadGbvm`, `WriteGbvm`, `WriteGbvmString`, `CombineBytesToWord`, `SkipEclCmd`) moves out of EclMenu into its own overlaid unit; the dispatcher stays in EclVm. 6531a44; plan c03cc49.

**CharDisp.** CharHlp's 20 drawing routines move to a new overlaid unit; resident code 5,968 bytes smaller (73,616 to 67,648). 3ea574d; plan 34581d4.

### Phase 4: hidden parameters

Globals used as hidden parameters become real ones: `tempCr1` and `tempCr2` leave GDVars (`DisplayChar` takes its character, ViewChar keeps a private `tradeTarget`, and `PrintItemString` loses an unused creature parameter in 18 calls) (2e8e105); `castScroll` becomes a var result of `SpellSelection` (06ceaed); `Magic.RemoveDiseaseEffects` takes its target (e321d08); the money routines take the character who pays or is paid (d69e904); the spell-list builders take their character (d1b1cda). The plan records what stays global and why (`usingItem`, the target list). c73a1be.

### Phase 5: working sets, cycles, duplication, testability

Planning: proposed from three surveys (39ac97d), what the ECL can see through EclVars' address map (98f7cb8), approved with GBVM addresses to be named (4084078), outcome and declined items (1826ed1), where the last four combat overlay loads come from (d307eb5), issue numbers for the behaviour items (6dd9ce1).

**Step 0.** The combat, vault and areachange scenarios record the overlay load count (Ctrl-Y) as an ignored checkpoint; `tests/ovlloads.py` prints both builds' counts. aed1509.

**Step 1: overlay working sets.** Code that ordinary play calls is moved so it does not pull in a large overlay:
- the spell and effect handler tables are filled by GameInit (a combat's working set 3,168 bytes smaller; `build/ovlsizes.py --units`) (69e8668);
- `SelectPrevNextChar` moves to the resident Party unit, so stepping through the party no longer loads ViewChar (e4d1594);
- ViewChar leaves the combat turns: `ToggleReadyItem` to FxEngine, `UseItem`, `UseItemSpell` and the spell menus to Magic (15be6f9);
- Magic's item and scroll predicates (`ItemReadable`, `ScrollLegible`, `ScrollSpellAt`, `CastableScroll`, `HasScrollSpells`, `CalcSpellRange`) move to resident CharHlp (a34665b);
- the clock (`AdvanceTime`, `ValidateClock`, `TimeOutEffects`) moves to FxEngine (a462a53);
- monster loading moves from SaveLoad to EclMenu (01c67c5);
- random items get their own overlay, `RandItem` (42be4f3);
- JrnlList, compiled `{$O+}` but never listed as an overlay, is overlaid (resident code 1,792 bytes smaller) (f04e389).

**Step 2: no unit cycles.** `GetIconTileDelta` moves to Pathing (4fad886); CbtMap traces the Lightning Bolt preview through a hook (5d328ce); Ctrl-Y's memory display moves behind a hook, first into Debug (4f7f88a), then, because loading Debug changed the count it shows, into a new resident unit `MemShow` (ca400a0); `RemoveCreature` and `FreeCreature` move to SaveLoad (d8f58b6); `CheckSaveDir` and `SaveDiskMsg` move to SaveMenu (bb6178a); the vault's menu gets its own unit, `VaultMnu` (b6ea833); Guard's message moves to its callers (7f1da48); the counter menu takes its Buy or Heal command as a `TMenuAction` (92ff703).

**Step 3: duplication.** `CharHlp.PrependItemCopy` and `PrependEffectCopy` (dc63384); `AppendItemCopy` for every tail append (d305345); `Border.ClearBox` through `TextRend.ClearRect` (5dd8554); ViewChar's Trade and Drop share `PickCoinType` (134b38c); the disk number through `NumStr` (c4deab8); `AbilAdj.ConSaveBonus` for the two Constitution save handlers (2cb4430); DataArc and `QuickLoadable` open through `FileUtil.OpenReadOnly` (3004456); CbtMap's `DrawCellCreature` (a94779c); `Party.LastCreature`, `PrevCreature` and `NextCreature` (d588be9); CharGen's `PickFromList` (c1aaf22); `Explore.OpenBarrierAhead` for bash, pick and Knock (137cbfe); Camp's `SlotsUsed` and `PutPending`, and Knock through `RemoveSpell` (45b2502); EclVars' GBVM address map by name in C_Gbvm (a6e26f6), one arm for the three wall-set loads (c08e23b); `Types.ARENA_SLOTS` for 72 (bd84a2c); class-level loops and party limits by name (40f1fb1); spell ids by name (b706c18); damage elements by name, `C_Effect.ELEM_*` (3630f36); the full text window's corners by name (fc42b34); `Pathing.TargetArea` and `CbtActs.AreaHitsNonEnemy` (b1b813f); `FxEngine.HoldTarget` (35ab983); `Temple.CureWounds` confirms and heals once (8ecca3a); `TextRend.TickCount` (7ab8d31); CharGen's `DivideAmongClasses` (74d7afc); `CharDisp.OpenMessageWindow` and the combat panel by name (e649344); EclVm's encounter menu's shared arms (94cc86f); `NumStr` where a Str result was used once (PrintHpDebug loses 768 bytes of stack frame) (0ac791f); the journal text units' ranges by name (54ba386); item name parts by name, `C_Item.NAME_*` (b22b64c); `MenuCore.AppendMenuLine` (b9dca03); View3D's 3D view from three parameterised scans (f19a30b); one tile blitter, `BlitTile`, with a clip argument (resident code 1,088 bytes smaller) (d056878); `FlushView` copies the four EGA planes in one loop (dae4f06); CharGen's racial ability limits through `ClassCal.RaceAbilityMin`/`RaceAbilityMax` (2957bbc).

**Step 4: testable units.** The dice move to a resident unit, `Dice` (145 calls in 17 units; the same Random calls in the same order, so NORAND runs roll the same) (#642, 3625a6d); tests for RandItem (0b55295); `CountTargets` and `CalcDistance` move to CbtMap (a934c45); CharHlp no longer draws (`ItemLabel`, and a fault hook) (f9755ec); tests for CharHlp, and its hooks start unset (e77b594); tests for Pathing (24c629e), JrnlList (bc167cb), DataArc's names and `EclTrace.OpName` (db9ad29); the hit-point rules move to ClassCal (6b25f7e); `HpMaximum` uses its parameter's Constitution rather than `curChar`'s (every caller passed `curChar`, so nothing changed), with hit-point tests (7548bfd); EclVars reaches DaxIo and View3D through hooks (a0f553b); tests for EclVars' GBVM address map (a8682d2); the experience share moves to `ClassCal.ExperienceShare` (8b113bb); the clock's carries in a resident unit, `Clock`, with tests (db4930a); the usual-spells store moves to its own unit, `UsualSpl`, with tests (1844bbc).

**Step 5: a leaner GDVars.** Globals nothing reads and three unused constants removed (b1faa82); the script registers become explicit arms of the GBVM map, reading 0 and dropping writes (5b68996); scratch globals become locals, and CombatSt's placement tables private (d75265d); 50 globals used by one unit become private to it (e63f110); `baseItems` becomes one array of 129, its last entry the overflow (d8beeb6); the saved map position as five reads and writes (10f9b84); Magic's and FxEngine's interfaces use only Types (7591936); 24 unneeded forward declarations deleted (dff02d4).

**Step 6: the data segment and the stack.** The script strings move to the heap (data 5,116 bytes smaller) (d2a9b25); the base item table moves to the heap (2,060 smaller) (6c9966a); `spellNames`, `spellLevelNames` and `templeSpells` get string types their entries fit (928 smaller) (0c8d423); smaller stack frames on the combat paths, and a level drain no longer loads Debug when the display is off (5416c34).

### After phase 5

**C_Level.** In the owner's batch, the class-level slot indexes move from `C_Class.LEVEL_*` to a new include unit `C_Level` (CLERIC..MONK), and GDConsts' rule tables (thief skills, Dexterity adjustments, classes by race, class parts, racial ability adjustments, class minimums, racial maximum levels, age categories, alignments by class, saving throws) become typed records readable by index or by field name (`Types.TRule*`); `C_Align` gains short alignment names. 038f32e.

**CbtActs names its item types.** C_Item gains `HAND_AXE`, `CLUB`, `DAGGER`, `DART`, `JAVELIN`, `QUARREL`, `SPEAR`, `BROAD_SWORD`, `LONG_SWORD`, `SHORT_SWORD`, `SLING`, `LEATHER_ARMOR` and `ARROW`, used by CbtActs, CharHlp and FxEngine. #649. 334d3bb.

**CharHlp names its constants.** The bows, the scrolls' base slots, the spell casting classes and fixed caster levels (C_Spell), the attack-roll range, the parts of armour class (`Types.AC_*`), `C_Level.LEVEL_LAST` and the helpless effects get names; CharHlp's movement, encumbrance, Bag of Holding and theft rules become private constants; `AtLevelCap` reads a table (section 2). f8bcdf0.

---

## 11. Tools, CI, tests and regression scenarios

**CI on both forges.** `build.yml` takes its image from the repository variable `CI_IMAGE` (the registry image by digest on forge.schkerke.com, a copy loaded into the runner on forgejo.brazencrows.com); registry credentials fall back to 'none'; the checkout is a plain git fetch of every branch and tag from the same forge instead of `actions/checkout`; build and reproduce skip pull requests from forks. d7abdb5. Three follow-up edits made in Forgejo's web editor remove YAML anchors (Forgejo splits the YAML when parsing jobs, so anchors do not work) and correct the syntax afterwards. 96a0746, 6f89499, c193a47.

**Build ID.** `build.sh` writes `obj/BUILDID.INC` (version and commit) from git; sources that do not include it, such as SSI's tags, build the same bytes. efccdbf.

**Unit tests.** TestKit and `build.sh --test` (ad2cadc, b88a6d7, 9945bc4); the test programs added in the range are TStats, TAreas, TStrUtil, TFileUtl, TClasCal, TDataPat, TAbilAdj, TMoneyCa, TRecLay, TSaveLay, TRandItm, TCharHlp, TPathing, TJrnl, TDataArc, TEclTrc, TEclVars, TClock, TUsualSp and TVidPic. Many later fixes add checks to them (for example TClasCal for #616 and the Wisdom totals, TCharHlp for `TheftChance` and `AtLevelCap`, TEclVars for the string value's 0, TPathing for `RouteStep`).

**Regression scenarios.** `tests/regress.sh` with goldbox-player's `tools/regress.py`: boot, chargen, loadsave, combat, vault, journal and camp (a15842b); shop and areachange (a19b0ce); ssiformat against SSI's own v1.3 (efa574b); overlay-load checkpoints (aed1509); `VIDEO=cga`, `tandy` and `vga` modes (bd7a01e, 6127810, 2a8f97c); `MEMSIZE=N` for EMS (3d10dc2); picture-memory checkpoints (e0b713b). A wilderness scenario loads save G (the owner's party in the central wilderness), takes three steps and records overlay loads, heap and picture memory, passing in all four modes at 1 and 16 MB (f9db514); wildfight walks 32 steps under NORAND to a random encounter and records the fight's start and memory (VGA has 199,312 bytes free there) (abbd4a6). Scenarios whose screens change by design record the changed screens apart (078b01f, d184cc3), and the boot scenario strips the build's version, commit, free memory and data version (ee892e2, b88a6d7, e747259).

**Benchmark.** `bench/vidbench.sh` (bd7a01e).

**Overlay and size tools.** `build/ovlsizes.py` (and `--units`), `tests/ovlloads.py`.

---

## 12. Documentation

**`docs/refactor-plan.md` tracked.** `docs/` had been ignored as the disassembly project's notes; it now holds the repository's own, starting with the refactor plan (ground rules, constraints, phases 0 to 4). 21771b7. The plan is updated as each phase lands: 13888a9, 0f11ab8, 2ab71e9, c03cc49, ace1784, 34581d4, c73a1be (phases 1 to 4); 39ac97d, 98f7cb8, 4084078, 1826ed1, d307eb5, 6dd9ce1 (phase 5); 8f60a9f, de5c623 (phase 6, proposed from two surveys and its status). Code commits also mark their items done.

**README.** Rewritten in the owner's batch: a short description, a note that each version (v1.1, v1.2 and v1.3) reproduces its release byte for byte, an AI usage section, build requirements (Turbo Pascal 5.0 for v1.1 and v1.2, Turbo Pascal 6.0 for v1.3, DOSBox or DOSBox-X), and how the per-disk data files are aggregated into merged files at start-up (about 49 seconds at 3,000 cycles, logged to DATABLD.LOG). 038f32e. The Tests section was added in ad2cadc, and the regression README lists goldbox-player's newer steps (efa574b).

**Comments.** The comment fixes from the source review (Money, Intro, C_Keys, CharGen, Camp, GDVars) are in section 9.
