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
  { Move mode's wide view (#1186), across the whole top of the screen in place of the map and party boxes: its last
    column, 13 tiles of 24 pixels, the last of them clipped to two of its three cells; the cells across, 1 to 38 on the
    screen; and the scanlines down, five tiles. Centred on its seventh tile (WILD_WIDE_LAST div 2), it puts the party's
    three cells at view cells 18 to 20, half a cell from the middle. }
  WILD_WIDE_LAST = 12;
  WILD_WIDE_CELLS = 38;
  WILD_WIDE_ROWS = 120;
  { the view buffer everything else draws into (GameInit), 168 scanlines by 21 cells }
  VIEW_ROWS = 168;
  VIEW_CELLS = 21;

implementation

end.
