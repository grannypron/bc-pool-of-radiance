{ Map tiles: the tile-id bits of a tile value, and the icon-animation slots. }
{$I COMPILER.INC}
unit C_TILE;

interface

const
  ID_MASK = $7F;
  { the last icon-animation slot (GameVars.iconAnimation; MapTiles names them) }
  ICON_LAST = 25;

implementation

end.
