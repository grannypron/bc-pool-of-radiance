{ The demo (#1109): its archive, the blocks in it, and how it starts. scripts/demodax.py builds DEMO.DAX from src/demo
  with the same block numbers. }
{$I COMPILER.INC}
unit C_DEMO;

interface

const
  { the archive, shipped beside RAVFULL.DAX; without it there is no demo }
  ARCHIVE = 'DEMO';
  { the demo's script: the Commodore 64's ECL1E, run in place of an area's script }
  SCRIPT_BLOCK = 1;
  { the four characters the script adds (ADD NPC), the C64's RESTAL, TARRAN, DIANE and WILLIAM D'OR, under ids no
    monster on the game's disks uses; each one's record is its id's block, its items the block ITEMS_OFFSET above }
  FIRST_NPC = 240;
  LAST_NPC = 243;
  ITEMS_OFFSET = 8;
  { the disk whose data the script's area, pictures and monsters are read from: Podol Plaza's }
  DATA_DISK = 1;
  { the start-up menu's wait before the demo starts, in hundredths of a second, and the key it then returns; started
    with DEMO, the first wait is ARG_IDLE_TIME, long enough for the menu to be seen (a scenario's boot waits for it) }
  IDLE_TIME = 3000;
  ARG_IDLE_TIME = 300;
  START_KEY = '!';
  { the demo's text delay (GameVars.gameDelay), as the C64 script sets its game speed }
  SPEED = 2;
  { the random seed the demo starts from, so that its battle plays out the same every time }
  SEED = 1;

implementation

end.
