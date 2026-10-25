{ Alignment values. }
{$I COMPILER.INC}
unit C_ALIGN;

interface

const
  { Alignment values (TCharRecord.alignment) in GameDefs.alignNames order: index = law * 3 + morality, with law lawful
    0, neutral 1, chaotic 2 and morality good 0, neutral 1, evil 2. The good values are 0/3/6 and the evil values
    2/5/8. }
  LAWFUL_GOOD = 0;
  LAWFUL_NEUTRAL = 1;
  LAWFUL_EVIL = 2;
  NEUTRAL_GOOD = 3;
  TRUE_NEUTRAL = 4;
  NEUTRAL_EVIL = 5;
  CHAOTIC_GOOD = 6;
  CHAOTIC_NEUTRAL = 7;
  CHAOTIC_EVIL = 8;

  { short names }
  LG = LAWFUL_GOOD;
  LN = LAWFUL_NEUTRAL;
  LE = LAWFUL_EVIL;
  NG = NEUTRAL_GOOD;
  TN = TRUE_NEUTRAL;
  NE = NEUTRAL_EVIL;
  CG = CHAOTIC_GOOD;
  CN = CHAOTIC_NEUTRAL;
  CE = CHAOTIC_EVIL;

  { the evil alignments, as a set for alignment in EVIL_ALIGNMENTS }
  EVIL_ALIGNMENTS = [LAWFUL_EVIL, NEUTRAL_EVIL, CHAOTIC_EVIL];

implementation

end.
