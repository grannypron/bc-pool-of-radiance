{ The merged data archives DataBld builds from the per-disk ones: the family count, the archive version and the
  reserved block ids. goldbox-re-tools' mergedax holds the same values. }
unit C_Data;

interface

const
  { data families, each merged into one archive (DataArc's family table) }
  FAMILIES = 14;
  { the script family's place in that table }
  FAMILY_ECL = 1;
  { the archive layout and the data patches DataBld applies; an archive holding another version is not used }
  VERSION = 2;
  { Reserved block ids, the last three blocks of a merged archive. The sources block lists, per per-disk archive read,
    its disk, file size and CRC-32; the remap block holds the collisions as triples (disk, original id, merged id); the
    version block holds VERSION and the CRC-32 of every byte of the file before that block's data. }
  SOURCES_BLOCK = 253;
  REMAP_BLOCK = 254;
  VERSION_BLOCK = 255;
  { the sources block's bytes per per-disk archive: disk, then file size and CRC-32 (4 bytes each, low byte first) }
  SOURCE_RECORD = 9;

implementation

end.
