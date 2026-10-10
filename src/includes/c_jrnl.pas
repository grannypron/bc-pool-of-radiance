{ The Journal: how many items its list holds, the width its text is wrapped to, and the kinds of item. }
unit C_Jrnl;

interface

const
  { Items in the Journal's list: the proclamations, the journal entries and the tavern tales }
  JOURNAL_COUNT = 99;
  { Columns of the Journal pane the text is wrapped to }
  JOURNAL_WIDTH = 27;
  { Kinds of Journal item; KIND_NONE answers for an index outside the list }
  KIND_NONE = 0;
  KIND_PROCLAMATION = 1;
  KIND_ENTRY = 2;
  KIND_TALE = 3;

implementation

end.
