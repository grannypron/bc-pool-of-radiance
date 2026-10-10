{ The fixes DataBld makes to the shipped data as it builds the merged archives, each to a known fault in one block of a
  per-disk archive and named by its POR id in the bug catalogue. A fix is one part, or a run of parts with the same POR
  id and block, made together or not at all. A part replaces origLen bytes at offset in the decoded block with newLen
  bytes, so a fix may lengthen a block (a script that gains code at its end). It is made only when the block is size
  bytes long and holds the original bytes there; offsets and sizes are those of the block as the fixes before it in
  this table leave it. A part's bytes are the next origLen + newLen bytes of patchBytes, the original first. Changing
  the fixes means raising C_Data.VERSION. }
unit DataPat;

interface

uses C_Data;

const
  { the parts of all the fixes, and their bytes together }
  PART_COUNT = 1;
  BYTE_COUNT = 174;

type
  { One part of a fix: the family's per-disk archive of disk, block id, which is size bytes long before this part;
    origLen bytes at offset there are replaced with newLen bytes. por is the fix's POR id. }
  TPatchPart = record
    por: Word;
    family: Byte;
    disk: Byte;
    id: Byte;
    size: Word;
    offset: Word;
    origLen: Byte;
    newLen: Byte;
  end;

const
  parts: array[1..PART_COUNT] of TPatchPart = (
    { POR-0038: Kovel Mansion's weapons-pile ambush (script $AAB9-$AB0F): 0..7 thieves killed give 5 1st-level
      thieves, 8..12 give c-7 6th-level and 12-c 1st-level as before, 13..16 give 5 6th-level and 17 gives 4, where
      the shipped script took the 1st-level count below zero or left it stale }
    (por: 38; family: C_Data.FAMILY_ECL; disk: 3; id: 14; size: 7332; offset: 4539; origLen: 87; newLen: 87));
  patchBytes: array[0..BYTE_COUNT - 1] of Byte = (
    { POR-0038, original }
    $04, $00, $05, $01, $45, $4A, $01, $79, $6E,      { $AAB9 ADD $05, [$4A45], [$6E79] }
    $03, $01, $79, $6E, $00, $15,                     { $AAC2 COMPARE [$6E79], $15 }
    $1B,                                              { $AAC8 IF >= }
    $01, $01, $EE, $AA,                               { $AAC9 GOTO LAAEE }
    $03, $01, $79, $6E, $00, $0C,                     { $AACD COMPARE [$6E79], $0C }
    $1A,                                              { $AAD3 IF <= }
    $01, $01, $04, $AB,                               { $AAD4 GOTO LAB04 }
    $05, $00, $0C, $01, $79, $6E, $01, $7A, $6E,      { $AAD8 SUBTRACT $0C, [$6E79], [$6E7A] }
    $05, $01, $7A, $6E, $00, $05, $01, $7B, $6E,      { $AAE1 SUBTRACT [$6E7A], $05, [$6E7B] }
    $01, $01, $10, $AB,                               { $AAEA GOTO LAB10 }
    $05, $00, $15, $01, $79, $6E, $01, $7A, $6E,      { $AAEE SUBTRACT $15, [$6E79], [$6E7A] }
    $05, $01, $7A, $6E, $00, $05, $01, $7A, $6E,      { $AAF7 SUBTRACT [$6E7A], $05, [$6E7A] }
    $01, $01, $10, $AB,                               { $AB00 GOTO LAB10 }
    $09, $00, $05, $01, $7B, $6E,                     { $AB04 SAVE $05, [$6E7B] }
    $09, $00, $00, $01, $7A, $6E,                     { $AB0A SAVE $00, [$6E7A] }
    { fixed }
    $09, $02, $05, $00, $01, $7B, $6E,                { $AAB9 SAVE $0005, [$6E7B] }
    $09, $02, $00, $00, $01, $7A, $6E,                { $AAC0 SAVE $0000, [$6E7A] }
    $03, $01, $45, $4A, $00, $07,                     { $AAC7 COMPARE [$4A45], $07 }
    $1A,                                              { $AACD IF <= }
    $01, $01, $10, $AB,                               { $AACE GOTO LAB10 }
    $05, $00, $07, $01, $45, $4A, $01, $7A, $6E,      { $AAD2 SUBTRACT $07, [$4A45], [$6E7A] }
    $05, $01, $7A, $6E, $00, $05, $01, $7B, $6E,      { $AADB SUBTRACT [$6E7A], $05, [$6E7B] }
    $03, $01, $45, $4A, $00, $0C,                     { $AAE4 COMPARE [$4A45], $0C }
    $1A,                                              { $AAEA IF <= }
    $01, $01, $10, $AB,                               { $AAEB GOTO LAB10 }
    $09, $02, $00, $00, $01, $7B, $6E,                { $AAEF SAVE $0000, [$6E7B] }
    $05, $01, $45, $4A, $00, $15, $01, $7A, $6E,      { $AAF6 SUBTRACT [$4A45], $15, [$6E7A] }
    $03, $01, $7A, $6E, $00, $05,                     { $AAFF COMPARE [$6E7A], $05 }
    $1A,                                              { $AB05 IF <= }
    $01, $01, $10, $AB,                               { $AB06 GOTO LAB10 }
    $09, $00, $05, $01, $7A, $6E);                    { $AB0A SAVE $05, [$6E7A] }

implementation

end.
