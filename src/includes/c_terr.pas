{ Combat terrain values. }
{$I COMPILER.INC}
unit C_Terr;

interface

const
  { Combat terrain values. Types 26..29 are decoration; 30 and 31 represent Stinking Cloud and corpses. }
  { The AI avoids it unless the mover is animated, coughing or immune to poison. }
  STINK_CLOUD = 30;
  { Corpse terrain. Save the previous terrain before replacing it; restoration ignores a saved corpse value to avoid
    leaving a second corpse marker. }
  CORPSE = 31;

implementation

end.
