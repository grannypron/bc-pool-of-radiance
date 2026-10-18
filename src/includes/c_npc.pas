{ TCharRecord.npc values. }
{$I COMPILER.INC}
unit C_Npc;

interface

const
  { TCharRecord.npc packing: bit 7 marks a creature outside the party; bits 0..6 hold morale }
  { bit 7: not a party member }
  FLAG = $80;
  { bits 0..6, only where used AS a mask }
  MORALE_MASK = $7F;
  { Animated NPC or mirror-duel clone; prior morale is not restored. }
  ANIMATED_NPC = $B2;
  { Animated party member or charm marker; removal resets it to zero. }
  ANIMATED_PC = $B3;

implementation

end.
