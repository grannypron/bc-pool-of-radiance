{ The configuration files (#876): POOL.CFG's letters and paths, and POOLOPT.CFG's settings and keys, which the game
  (Options, GameBoot) and the set-up program POOLCFG share through CfgFile. }
{$I COMPILER.INC}
unit C_OPT;

interface

const
  { the files: POOL.CFG in the game's folder, POOLOPT.CFG in the save folder, and the program that writes them }
  CFG_NAME = 'POOL.CFG';
  OPT_NAME = 'POOLOPT.CFG';
  SETUP_NAME = 'POOLCFG.EXE';
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
  { the longest file name the game appends to a path (WALLDEF1.DAX), and so the longest path START takes: a path and
    that name fit a DOS path of 79 characters }
  LONGEST_NAME = 12;
{$IFDEF FPC}
  MAX_PATH_TEXT = 255 - LONGEST_NAME;
{$ELSE}
  MAX_PATH_TEXT = 79 - LONGEST_NAME;
{$ENDIF}
  { the most lines read from POOLOPT.CFG; anything after them is ignored, and dropped when the file is written }
  MAX_LINES = 100;
  { The settings, in the Settings screen's order; the sub-settings follow the setting they come under. }
  OPT_SPEED = 1;
  OPT_PORTRAITS_ALL = 2;
  OPT_MONSTERS = 3;
  OPT_PORTRAITS = 4;
  OPT_MUSIC = 5;
  OPT_TITLE_MUSIC = 6;
  OPT_BATTLE_MUSIC = 7;
  OPT_SOUND = 8;
  OPT_FOOTSTEPS = 9;
  OPT_RANGED = 10;
  OPT_MELEE = 11;
  OPT_DEATH = 12;
  OPT_WALL = 13;
  OPT_SPELLS = 14;
  { the first setting under the Quick Mode heading }
  OPT_QUICK = 15;
  OPT_MAGIC = 16;
  OPT_COMPANION = 17;
  OPT_CLUES = 18;
  { the combat log (#841), and how many messages it keeps }
  OPT_COMBAT_LOG = 19;
  OPT_LOG_LINES = 20;
  OPT_COUNT = 20;
  { the settings that are ON or OFF }
  OPT_FIRST_FLAG = OPT_PORTRAITS_ALL;
  OPT_LAST_FLAG = OPT_COMBAT_LOG;
  { POOLOPT.CFG's keys past the settings: the later games' data and save paths (Curse's, Secret's, then Pools') }
  KEY_PATHS = OPT_COUNT;
  LATER_PATHS = 6;
  KEY_COUNT = KEY_PATHS + LATER_PATHS;
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
