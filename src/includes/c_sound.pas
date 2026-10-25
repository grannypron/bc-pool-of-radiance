{ Sound: the sound-effect ids and the soundMode values. }
{$I COMPILER.INC}
unit C_SOUND;

interface

const
  DOWNED = 1;
  RANGED_START = 2;
  { weapon hit or blocked-movement bump }
  IMPACT = 3;
  MISS = 5;
  STEP = 6;
  { The Tandy SN76489 chip, chosen by a T in the sound line of POOL.CFG; natively T, A and B all choose it (SndDig). }
  MODE_TANDY = 0;
  { The PC speaker, chosen by a P. }
  MODE_SPEAKER = 1;
  { Sound is off, for any other letter or once Ctrl-S turns it off; SoundCommand then does nothing. }
  MODE_DISABLED = 2;
  { An AdLib (OPL2), chosen by an A (or an S, a Sound Blaster's), playing the Tandy arrangements; with no OPL2 found,
    the speaker plays instead. }
  MODE_ADLIB = 3;
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
  { The sound effects the Settings screen turns on and off one kind at a time, as bits of GameVars.soundGroups
    (SoundDrv.SoundEffect); the other effects follow the Sound setting alone (#835). }
  GROUP_FOOTSTEPS = $01;
  { a missile's flight and landing, and a ranged attack's hit or miss }
  GROUP_RANGED = $02;
  { a melee attack's hit or miss }
  GROUP_MELEE = $04;
  { a creature going down }
  GROUP_DEATH = $08;
  { the party walking into a wall }
  GROUP_WALL = $10;
  { a spell's cast, and the flash and damage of its effects (#854) }
  GROUP_SPELL = $20;
  GROUPS_ALL = $3F;
  { The tunes turned on and off one at a time, as bits of GameVars.musicGroups (SoundDrv.PlayMusic). }
  GROUP_TITLE_MUSIC = $01;
  GROUP_BATTLE_MUSIC = $02;
  MUSIC_GROUPS_ALL = $03;

implementation

end.
