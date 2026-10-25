{ The party's location types with the LOC_ prefix: a 3-D map or one of the three wildernesses. }
{$I COMPILER.INC}
unit C_AREA;

interface

const
  LOC_3D_MAP = 1;
  { Western Wilderness }
  LOC_WILD_WEST = 2;
  { Central Wilderness }
  LOC_WILD_CENTRAL = 3;
  { Eastern Wilderness }
  LOC_WILD_EAST = 4;
  { The wilderness map (GameDefs.wildMap): its last column and row, as it is 44 columns wide and 36 rows tall; each
    wilderness is a 16-column window of it, columns 0..WILD_REGION_LAST_COL from GameDefs.wildColOfs. }
  WILD_LAST_COL = 43;
  WILD_LAST_ROW = 35;
  WILD_REGION_LAST_COL = 15;
  { the last column and row of the 5x5 wilderness view }
  WILD_VIEW_LAST = 4;

implementation

end.
