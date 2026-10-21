{ The merged data archives DataBld builds from the per-disk ones: the family count, the places of the families the data
  patches touch, the archive version and the reserved block ids. DataBld and DataPat are the only source for these
  values; no tool outside this repository keeps a copy. }
{$I COMPILER.INC}
unit C_Data;

interface

const
  { data families, each merged into one archive (DataArc's family table) }
  FAMILIES = 14;
  { places in that table: scripts, maps, placed items, monsters and monsters' items }
  FAMILY_ECL = 1;
  FAMILY_GEO = 2;
  FAMILY_ITEM = 9;
  FAMILY_MONCHA = 10;
  FAMILY_MONITM = 11;
  { The archive layout and the data patches DataBld applies (DataPat). DaxIo.FamilyUsable rejects an archive holding
    another version, so raising it makes the next start rebuild every family's archive, with the patches as they are
    now. }
  VERSION = 34;
  { Reserved block ids, the last blocks of a merged archive; the remap block is there only when some ids collided. The
    sources block lists, per per-disk archive read, its disk, file size and CRC-32; the remap block holds the
    collisions as triples (disk, original id, merged id); the version block holds VERSION and the CRC-32 of every byte
    of the file before that block's data. }
  SOURCES_BLOCK = 253;
  REMAP_BLOCK = 254;
  VERSION_BLOCK = 255;
  { the most collisions one family may have: DataBld builds no more into a merged archive's remap block, and DaxIo keeps
    that many for every family }
  FAMILY_REMAPS = 16;
  { the sources block's bytes per per-disk archive: disk, then file size and CRC-32 (4 bytes each, low byte first) }
  SOURCE_RECORD = 9;

implementation

end.
