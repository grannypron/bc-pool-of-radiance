{ Shared constants for POOL.CFG and POOLOPT.CFG (#876). The game and POOLCFG
  both use these values through CfgFile. }
{$I COMPILER.INC}
unit C_OPT;

interface

const
  { the files: POOL.CFG in the game's folder, POOLOPT.CFG in the save folder, and the program that writes them }
  CFG_NAME = 'POOL.CFG';
  OPT_NAME = 'POOLOPT.CFG';
  SETUP_NAME = 'POOLCFG.EXE';
  { the switch START runs the set-up program with, so it says why it came up and leaves to DOS unsaved }
  SETUP_FROM_START = '/START';
  { POOL.CFG's first line, the video: CGA, EGA, Tandy or VGA; START reads any other letter as CGA }
  VIDEO_CGA = 'C';
  VIDEO_EGA = 'E';
  VIDEO_TANDY = 'T';
  VIDEO_VGA = 'V';
  { POOL.CFG's second line, the sound device. S is silent, as SSI's data card and the Curse port have it, and B the
    Sound Blaster (#880); START reads any other letter as silent, N included. }
  SOUND_SILENT = 'S';
  SOUND_NONE = 'N';
  SOUND_SPEAKER = 'P';
  SOUND_TANDY = 'T';
  SOUND_ADLIB = 'A';
  SOUND_BLASTER = 'B';
  { POOL.CFG's fifth line: the full introduction, or (any other letter) the short one }
  INTRO_FULL = 'F';
  INTRO_SHORT = 'N';
  { POOL.CFG's lines: video, sound, data path, save path, introduction }
  CFG_LINES = 5;
  { the most lines after the fifth that a POOL.CFG read keeps, for a write to put back }
  CFG_EXTRA_LINES = 4;
  { the longest file name the game appends to a path (WALLDEF1.DAX), and the folders a file's temporary copy and
    backup are written in beside it (FileUtil.BACKUP_FOLDER, TMP\BAK\, #1084), and so the longest path START takes: a
    path, those folders and that name fit a DOS path of 79 characters }
  LONGEST_NAME = 12;
  WORK_FOLDERS = 8;
{$IFDEF FPC}
  MAX_PATH_TEXT = 255 - LONGEST_NAME - WORK_FOLDERS;
{$ELSE}
  MAX_PATH_TEXT = 79 - LONGEST_NAME - WORK_FOLDERS;
{$ENDIF}
  { the most lines read from POOLOPT.CFG; anything after them is ignored, and dropped when the file is written }
  MAX_LINES = 100;
  { The settings, in the Settings screen's order, the Game page's around the Sound page's (OPT_FIRST_SOUND to
    OPT_LAST_SOUND); the sub-settings follow the setting or heading (CfgFile.Heading) they come under. }
  OPT_SPEED = 1;
  OPT_PORTRAITS_ALL = 2;
  OPT_MONSTERS = 3;
  OPT_PORTRAITS = 4;
  { a stackable item joins its like as it is bought, taken or traded (#1088) }
  OPT_AUTO_JOIN = 5;
  { a character's purse is changed into the fewest coins of the same value whenever it picks coins up (#1179) }
  OPT_CONSOLIDATE = 6;
  { the Journal lists only what the party has found (ON, shown as FOUND) or every item (OFF, shown as ALL) (#1090) }
  OPT_JOURNAL = 7;
  OPT_MUSIC = 8;
  OPT_TITLE_MUSIC = 9;
  OPT_BATTLE_MUSIC = 10;
  OPT_SOUND = 11;
  OPT_FOOTSTEPS = 12;
  OPT_RANGED = 13;
  OPT_MELEE = 14;
  OPT_DEATH = 15;
  OPT_WALL = 16;
  OPT_SPELLS = 17;
  { the first setting under the Quick Mode heading }
  OPT_QUICK = 18;
  OPT_MAGIC = 19;
  { quick mode re-equips the party's weapons and shields (#1127) }
  OPT_GEAR = 20;
  { the aim menu's Next and Prev reach one side only, ENEMIES, or every creature, ALL (#1137) }
  OPT_AIM = 21;
  { a single thrown weapon goes back to its thrower after the fight (#1118) }
  OPT_RETRIEVE = 22;
  OPT_COMPANION = 23;
  OPT_CLUES = 24;
  { the Camp page's settings (OPT_FIRST_CAMP to OPT_LAST_CAMP): Rest memorizes each caster's usual spells when none
    is pending (#1119), and under the Fix heading (#1129) what Fix may use besides the clerics' spells: scrolls,
    potions, and a paladin's weekly cure and daily laying on of hands }
  OPT_AUTO_MEMORIZE = 25;
  OPT_FIX_SCROLLS = 26;
  OPT_FIX_POTIONS = 27;
  OPT_FIX_CURE = 28;
  OPT_FIX_HEAL = 29;
  { the combat log (#841), and how many messages it keeps }
  OPT_COMBAT_LOG = 30;
  OPT_LOG_LINES = 31;
  OPT_COUNT = 31;
  { the Sound page's settings, from the music to the sound effects, and the Camp page's; every other setting is the
    Game page's }
  OPT_FIRST_SOUND = OPT_MUSIC;
  OPT_LAST_SOUND = OPT_SPELLS;
  OPT_FIRST_CAMP = OPT_AUTO_MEMORIZE;
  OPT_LAST_CAMP = OPT_FIX_HEAL;
  { the pages the settings are shown on (CfgFile.SettingPage), in the order the game's Settings screen and POOLCFG
    offer them }
  OPT_PAGE_GAME = 1;
  OPT_PAGE_SOUND = 2;
  OPT_PAGE_CAMP = 3;
  OPT_PAGES = 3;
  { the settings that are ON or OFF }
  OPT_FIRST_FLAG = OPT_PORTRAITS_ALL;
  OPT_LAST_FLAG = OPT_COMBAT_LOG;
  { POOLOPT.CFG's key past the settings: the last version the startup advisory's support part was shown for (#1173),
    which Advisory shows again when this is not the build's own. The later games' paths that came before it (CURSEDATA
    to POOLSSAVE) are gone (#1177): a file that still has them keeps them as lines this version does not know. }
  KEY_ADVISED = OPT_COUNT + 1;
  KEY_COUNT = KEY_ADVISED;
  { the game speed: 0 the fastest, SLOWEST the slowest, and the default }
  SLOWEST = 9;
  SPEED_DEFAULT = 1;
  { Log Lines: the fewest and most messages the combat log keeps, the default, and the Settings screen's step }
  LOG_MIN = 10;
  LOG_MAX = 60;
  LOG_DEFAULT = 50;
  LOG_STEP = 5;

implementation

end.
