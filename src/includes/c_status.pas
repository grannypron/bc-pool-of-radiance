{ Creature status values (TCharRecord.status). }
unit C_Status;

interface

const
  { Creature status values. Conditions such as sleep and paralysis are tracked as effects. }
  OKAY = 0;
  ANIMATED = 1;
  { temporarily gone }
  TEMPGONE = 2;
  { fled combat }
  RUNNING = 3;
  UNCONSCIOUS = 4;
  DYING = 5;
  DEAD = 6;
  { petrified }
  STONED = 7;
  GONE = 8;

implementation

end.
