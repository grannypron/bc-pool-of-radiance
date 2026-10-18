{ The Journal: how many items its list holds, the width its text is wrapped to, and the kinds of item. }
{$I COMPILER.INC}
unit C_Jrnl;

interface

const
  { Items in the Journal's list: the proclamations, the journal entries and the tavern tales }
  JOURNAL_COUNT = 99;
  { The last item each overlaid text unit holds: Journal1 1..PART1_LAST, Journal2 up to PART2_LAST, Journal3 up to
    PART3_LAST, Journal4 the rest to JOURNAL_COUNT }
  PART1_LAST = 28;
  PART2_LAST = 50;
  PART3_LAST = 67;
  { Columns of the Journal pane the text is wrapped to }
  JOURNAL_WIDTH = 27;
  { Kinds of Journal item; KIND_NONE answers for an index outside the list }
  KIND_NONE = 0;
  KIND_PROCLAMATION = 1;
  KIND_ENTRY = 2;
  KIND_TALE = 3;

implementation

end.
