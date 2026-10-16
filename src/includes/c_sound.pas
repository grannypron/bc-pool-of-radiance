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
  { Lightning Bolt's cast }
  LIGHTNING = 4;
  { Fireball's cast: the same sound as the scripts' cue }
  FIREBALL = 7;
  { index into soundIds.commands: any other spell's cast }
  CAST = 3;
  { The title theme, a SoundDrv.PlayMusic tune. }
  MUSIC_TITLE = 21;
  { The battle music, a SoundDrv.PlayMusic tune. }
  MUSIC_BATTLE = 22;

implementation

end.
