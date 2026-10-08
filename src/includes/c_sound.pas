{ Sound: the sound-effect ids and the soundMode values. }
unit C_Sound;

interface

const
  DOWNED = 1;
  RANGED_START = 2;
  { weapon hit or blocked-movement bump }
  IMPACT = 3;
  MISS = 5;
  STEP = 6;
  { The Tandy SN76489 chip, chosen by a T in the sound line of POOL.CFG. }
  MODE_TANDY = 0;
  { The PC speaker, chosen by a P. }
  MODE_SPEAKER = 1;
  { Sound is off, for any other letter or once Ctrl-S turns it off; SoundCommand then does nothing. }
  MODE_DISABLED = 2;
  ECL_CUE = 7;
  RANGED_END = 8;
  TITLE_THEME = 9;
  BATTLE_STING = 10;

implementation

end.
