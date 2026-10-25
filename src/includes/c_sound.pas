{ Sound: the sound-effect ids, the soundMode values, the music and the Settings screen's groups, the timer driver's
  clock and ports, and the Sound Blaster's recorded effects. }
{$I COMPILER.INC}
unit C_SOUND;

interface

const
  { Indexes into GameDefs.soundIds.combat. }
  { a creature going down }
  DOWNED = 1;
  { a missile's flight }
  RANGED_START = 2;
  { weapon hit or blocked-movement bump }
  IMPACT = 3;
  { Lightning Bolt's cast }
  LIGHTNING = 4;
  { a missed attack }
  MISS = 5;
  { a footstep }
  STEP = 6;
  { the scripts' sound cue }
  ECL_CUE = 7;
  { Fireball's cast: the same sound as the scripts' cue }
  FIREBALL = 7;
  { a missile's landing }
  RANGED_END = 8;
  { Index into GameDefs.soundIds.commands: any other spell's cast. }
  CAST = 3;

  { The Tandy SN76489 chip, chosen by a T in the sound line of POOL.CFG; natively T, A and B all choose it (SndDig). }
  MODE_TANDY = 0;
  { The PC speaker, chosen by a P. }
  MODE_SPEAKER = 1;
  { Sound is off, for any other letter or once Ctrl-S turns it off; SoundCommand then does nothing. }
  MODE_DISABLED = 2;
  { An AdLib (OPL2), chosen by an A (or a B, a Sound Blaster's), playing the Tandy arrangements; with no OPL2 found,
    the speaker plays instead. }
  MODE_ADLIB = 3;

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

  { The PIT's input clock, in Hz. }
  PIT_HZ = 1193182;
  { PIT channel 0's divisor while the timer driver has it, 236.7 ticks a second: sounddrv.asm's 13B1h, which must
    match. }
  TIMER_DIVISOR = 5041;
  { The ports the sequencer writes: PIT channel 2 (the speaker's pitch), the speaker's gates, the Tandy's SN76489. }
  PORT_PIT2 = $42;
  PORT_GATE = $61;
  PORT_TANDY = $C0;

  { The tunes SBSFX.DAT may hold a recording for: the effects, which end where the music starts. }
  SFX_LAST = MUSIC_TITLE - 1;
  { A recording's format: unsigned 8-bit PCM, or 4-bit Creative ADPCM led by its reference byte. }
  SFX_PCM8 = 0;
  SFX_ADPCM4 = 1;

implementation

end.
