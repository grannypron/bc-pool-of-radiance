{ Classifies event squares for the Companion Tools map without executing their
  area scripts.

  Prepare walks control flow from the script entry points and follows reads of
  GBVM CELL_EVENT to find each event's dispatch address. Scripts may dispatch
  through a masked ON GOTO value or through COMPARE and IF instructions, so the
  analysis also tracks variables derived from the event byte until they are
  overwritten.

  Kind follows an event's code for a bounded distance and reports its strongest
  visible action: area change, shop, temple, training hall, combat, treasure,
  trap, or message. Code with no such action is KIND_NONE. An event whose
  dispatch cannot be found remains KIND_EVENT. }
{$O+,F+}
{$I COMPILER.INC}
unit EvtKind;

interface

const
  KIND_NONE = 0;
  { an event whose kind is not known }
  KIND_EVENT = 1;
  KIND_MESSAGE = 2;
  KIND_TRAP = 3;
  KIND_TREASURE = 4;
  KIND_SERVICE = 5;
  KIND_FIGHT = 6;
  KIND_EXIT = 7;

{ Read the loaded area script's event dispatch, and forget Kind's answers for the last. Call it once the area's script
  is loaded, before Kind. }
procedure Prepare;

{ The kind of a square whose event byte is event; KIND_NONE for 0, and for an event whose code shows nothing. Each
  event's is worked out once after Prepare and then remembered. }
function Kind(event: Byte): Byte;

implementation

uses Types, GameVars, C_ECL, C_GBVM, EclVars;

const
  { the variables a scan follows the event byte into }
  MAX_VARS = 8;
  MAX_DISPATCH = 96;
  { instructions the walk of the whole script queues, and a scan from one read of the event byte }
  MAX_QUEUE = 512;
  MAX_SCAN = 256;
  { instructions followed from an event's address }
  MAX_FOLLOW = 160;
  { a kinds[] entry not yet worked out }
  UNKNOWN = $FF;

type
  TVisited = array[0..(C_GBVM.SCRIPT_LAST - C_GBVM.SCRIPT_FIRST) div 8] of Byte;
  TDispatch = record
    { the event byte masked with mask equals value }
    mask: Byte;
    value: Byte;
    target: Word;
    { a COMPARE's IF = runs one instruction at target: only it is the event's (unless it is a GOTO or GOSUB) }
    single: Boolean;
  end;

var
  dispatchCount: Byte;
  dispatch: array[1..MAX_DISPATCH] of TDispatch;
  queue: array[1..MAX_QUEUE] of Word;
  queueLen: Word;
  visited: ^TVisited;
  { a scan's variables holding the event byte masked with varMasks less varOffsets: bit k of a path's live set is
    vars[k + 1], and one variable can be there twice with two offsets }
  varCount: Byte;
  vars: array[1..MAX_VARS] of Word;
  varMasks: array[1..MAX_VARS] of Byte;
  varOffsets: array[1..MAX_VARS] of Byte;
  { Kind's answer for each event byte since Prepare, or UNKNOWN: the map asks for each square's, and an area's few
    events (the Temple of Bane's eight on 168 squares) each cost KindAt's long walks (#692) }
  kinds: array[Byte] of Byte;

{ Operand i of the instruction last decoded, as an address (a GBVM read) when isAddr. }
function Operand(i: Byte; var isAddr: Boolean): Word;
begin
  isAddr := GameVars.varTypes[i] in [1, 3];
  if GameVars.varTypes[i] in [1, 2, 3] then
    Operand := EclVars.CombineBytesToWord(GameVars.varLo[i], GameVars.varHi[i])
  else
    Operand := GameVars.varLo[i];
end;

{ The first operand and the count of the ON GOTO, ON GOSUB or menu at a, read from the script itself: decoding loads the
  list after them over them. The count is ON GOTO's, ON GOSUB's and the horizontal menu's; one read from a variable is
  not known, so taken as 0. }
procedure ListHead(a: Word; var v: Word; var isAddr: Boolean; var n: Byte);
var
  t: Byte;
begin
  t := GameVars.zone3^[a + 1];
  isAddr := t in [1, 3];
  v := GameVars.zone3^[a + 2];
  Inc(a, 3);
  if t in [1, 2, 3] then begin
    v := EclVars.CombineBytesToWord(Lo(v), GameVars.zone3^[a]);
    Inc(a);
  end;
  n := 0;
  if GameVars.zone3^[a] in [0, 2] then
    n := GameVars.zone3^[a + 1];
end;

{ True when a is inside the script. }
function InScript(a: Word): Boolean;
begin
  InScript := (a >= C_GBVM.SCRIPT_FIRST) and (a <= C_GBVM.SCRIPT_LAST);
end;

{ Decode the instruction at a: its opcode, and the address after it. }
function Decode(a: Word; var next: Word): Byte;
var
  savedIp: Word;
  savedOp: Byte;
begin
  savedIp := GameVars.eclIp;
  savedOp := GameVars.curOpcode;
  GameVars.eclIp := a;
  EclVars.SkipEclCmd;
  Decode := GameVars.curOpcode;
  next := GameVars.eclIp;
  GameVars.eclIp := savedIp;
  GameVars.curOpcode := savedOp;
end;

{ The variable the instruction at a, op, writes (decoded last); 0 for none. }
function WrittenVar(a: Word; op: Byte): Word;
var
  isAddr: Boolean;
  v: Word;
  n: Byte;
begin
  WrittenVar := 0;
  case op of
    C_ECL.SAVE, C_ECL.OP_RANDOM, C_ECL.INPUT_NUMBER, C_ECL.INPUT_STRING: WrittenVar := Operand(2, isAddr);
    C_ECL.DIVIDE, C_ECL.MULTIPLY, C_ECL.GET_TABLE, C_ECL.OP_AND, C_ECL.OP_OR: WrittenVar := Operand(3, isAddr);
    C_ECL.VERTICAL_MENU, C_ECL.HORIZONTAL_MENU: begin
          ListHead(a, v, isAddr, n);
          WrittenVar := v;
        end;
  end;
end;

{ Record that the event byte masked with mask equal to value runs target, once. }
procedure AddDispatch(mask, value: Byte; target: Word; single: Boolean);
var
  i: Byte;
begin
  if not InScript(target) then Exit;
  value := value and mask;
  for i := 1 to dispatchCount do
    if (dispatch[i].mask = mask) and (dispatch[i].value = value) and (dispatch[i].target = target) then Exit;
  if dispatchCount < MAX_DISPATCH then begin
    Inc(dispatchCount);
    dispatch[dispatchCount].mask := mask;
    dispatch[dispatchCount].value := value;
    dispatch[dispatchCount].target := target;
    dispatch[dispatchCount].single := single;
  end;
end;

{ The bit of variable v less offset among the scan's, adding it with mask when new; 0 when it is not one and none is
  added (mask 0, or the table full). }
function VarBit(v: Word; mask, offset: Byte): Byte;
var
  k: Byte;
begin
  VarBit := 0;
  for k := 1 to varCount do
    if (vars[k] = v) and ((mask = 0) or (varOffsets[k] = offset)) then begin
      VarBit := 1 shl (k - 1);
      Exit;
    end;
  if (mask <> 0) and (varCount < MAX_VARS) then begin
    Inc(varCount);
    vars[varCount] := v;
    varMasks[varCount] := mask;
    varOffsets[varCount] := offset;
    VarBit := 1 shl (varCount - 1);
  end;
end;

{ The live set's bits for variable v, whatever its offset. }
function Bits(v: Word; live: Byte): Byte;
var
  k: Byte;
  b: Byte;
begin
  b := 0;
  for k := 1 to varCount do
    if vars[k] = v then
      b := b or (1 shl (k - 1));
  Bits := b and live;
end;

{ True when v is live, with its mask and offset. }
function LiveVar(v: Word; live: Byte; var mask, offset: Byte): Boolean;
var
  k: Byte;
begin
  LiveVar := False;
  for k := 1 to varCount do
    if (vars[k] = v) and (live and (1 shl (k - 1)) <> 0) then begin
      mask := varMasks[k];
      offset := varOffsets[k];
      LiveVar := True;
    end;
end;

{ Follow the script from start, where the variables of live hold the event byte, recording its dispatches: an ON GOTO or
  ON GOSUB on one, its k-th address for event k; a COMPARE of one with a number, then IF =, the instruction after the IF
  for that number. A COMPARE of one with another variable, then IF =, makes that variable hold it too past the IF, and
  an instruction writing one ends its holding it, but for an ADD or SUBTRACT of a number to it in place (the training
  hall counts from 10 and takes 10 off), which moves its offset; a path ends when none holds it, at EXIT, RETURN or
  NEWECL, and at an ON GOTO. }
procedure Scan(start: Word; live: Byte);
var
  todo: array[1..MAX_SCAN] of Word;
  todoLive: array[1..MAX_SCAN] of Byte;
  todoLen: Word;
  head: Word;
  a: Word;
  next: Word;
  afterIf: Word;
  op: Byte;
  isAddr: Boolean;
  isAddr2: Boolean;
  v1: Word;
  v2: Word;
  mask: Byte;
  offset: Byte;
  n: Byte;
  i: Byte;
  w: Word;
  isAddr3: Boolean;
  { the opcode an IF guards, decoded only to find the address past it }
  guarded: Byte;

  procedure Follow(t: Word; l: Byte);
  var
    k: Word;
  begin
    if not InScript(t) or (l = 0) or (todoLen >= MAX_SCAN) then Exit;
    for k := 1 to todoLen do
      if todo[k] = t then Exit;
    Inc(todoLen);
    todo[todoLen] := t;
    todoLive[todoLen] := l;
  end;

begin
  todoLen := 0;
  Follow(start, live);
  head := 1;
  while head <= todoLen do begin
    a := todo[head];
    live := todoLive[head];
    Inc(head);
    op := Decode(a, next);
    case op of
      C_ECL.OP_EXIT, C_ECL.RETURN, C_ECL.NEW_ECL: next := 0;
      C_ECL.OP_GOTO: begin
            Follow(Operand(1, isAddr), live);
            next := 0;
          end;
      C_ECL.ON_GOTO, C_ECL.ON_GOSUB: begin
            ListHead(a, v1, isAddr, n);
            if isAddr and LiveVar(v1, live, mask, offset) then
              for i := 1 to n do
                AddDispatch(mask, i - 1 + offset, Operand(i, isAddr2), False);
            if op = C_ECL.ON_GOTO then
              next := 0;
          end;
      C_ECL.COMPARE: begin
            v1 := Operand(1, isAddr);
            v2 := Operand(2, isAddr2);
            mask := 0;
            if not (isAddr and LiveVar(v1, live, mask, offset)) and isAddr2 and
               LiveVar(v2, live, mask, offset) then begin
              v2 := v1;
              isAddr2 := isAddr;
            end;
            if (mask <> 0) and (Decode(next, afterIf) = C_ECL.IF_EQ) then begin
              if isAddr2 then
                { past the IF, the other variable holds it too }
                Follow(afterIf, live or VarBit(v2, mask, offset))
              else
                AddDispatch(mask, Lo(v2) + offset, afterIf, True);
            end;
          end;
      C_ECL.IF_EQ..C_ECL.IF_GE: begin
            guarded := Decode(next, afterIf);
            Follow(afterIf, live);
          end;
      C_ECL.ADD, C_ECL.SUBTRACT: begin
            { a number added to or taken from a variable in place moves its offset; anything else written ends it }
            v1 := Operand(1, isAddr);
            v2 := Operand(2, isAddr2);
            w := Operand(3, isAddr3);
            if not isAddr and isAddr2 and (v2 = w) and LiveVar(w, live, mask, offset) then begin
              if op = C_ECL.ADD then
                offset := offset - Lo(v1)
              else
                offset := offset + Lo(v1);
              live := (live and not Bits(w, live)) or VarBit(w, mask, offset);
            end else
              live := live and not Bits(w, live);
          end;
    else begin
        w := WrittenVar(a, op);
        if w <> 0 then
          live := live and not Bits(w, live);
      end;
    end;
    if next <> 0 then
      Follow(next, live);
  end;
end;

{ Queue a for the walk, once. }
procedure Push(a: Word);
var
  k: Word;
begin
  if not InScript(a) then Exit;
  k := a - C_GBVM.SCRIPT_FIRST;
  if visited^[k div 8] and (1 shl (k mod 8)) <> 0 then Exit;
  visited^[k div 8] := visited^[k div 8] or (1 shl (k mod 8));
  if queueLen < MAX_QUEUE then begin
    Inc(queueLen);
    queue[queueLen] := a;
  end;
end;

{ Walk the script's control flow from its entry points, scanning on from each instruction that reads the event byte: an
  AND of it into a variable, and a COMPARE of it. }
procedure Prepare;
var
  a: Word;
  next: Word;
  afterIf: Word;
  op: Byte;
  i: Byte;
  isAddr: Boolean;
  isAddr2: Boolean;
  v1: Word;
  v2: Word;
  n: Byte;
  head: Word;
  eventBit: Byte;
  { the opcode an IF guards, decoded only to find the address past it }
  guarded: Byte;
begin
  dispatchCount := 0;
  queueLen := 0;
  FillChar(kinds, SizeOf(kinds), UNKNOWN);
  New(visited);
  FillChar(visited^, SizeOf(TVisited), 0);
  for i := 1 to C_ECL.ENTRY_COUNT do
    Push(GameVars.scriptEntryAddrs[i]);
  head := 1;
  while head <= queueLen do begin
    a := queue[head];
    Inc(head);
    op := Decode(a, next);
    case op of
      C_ECL.OP_EXIT, C_ECL.RETURN, C_ECL.NEW_ECL: { the path ends };
      C_ECL.OP_GOTO: Push(Operand(1, isAddr));
      C_ECL.GOSUB: begin
            Push(Operand(1, isAddr));
            Push(next);
          end;
      C_ECL.ON_GOTO, C_ECL.ON_GOSUB: begin
            ListHead(a, v1, isAddr, n);
            for i := 1 to n do
              Push(Operand(i, isAddr2));
            if op = C_ECL.ON_GOSUB then
              Push(next);
          end;
      C_ECL.IF_EQ..C_ECL.IF_GE: begin
            { the next instruction runs or is skipped }
            Push(next);
            guarded := Decode(next, afterIf);
            Push(afterIf);
          end;
    else begin
        if op in [C_ECL.OP_AND, C_ECL.COMPARE] then begin
          v1 := Operand(1, isAddr);
          v2 := Operand(2, isAddr2);
          if (isAddr and (v1 = C_GBVM.CELL_EVENT)) or (isAddr2 and (v2 = C_GBVM.CELL_EVENT)) then begin
            { a fresh set of variables for each scan }
            varCount := 0;
            eventBit := VarBit(C_GBVM.CELL_EVENT, $FF, 0);
            if op = C_ECL.COMPARE then
              Scan(a, eventBit)
            else begin
              { AND a, b, destination: the event byte and a mask, either way round }
              if v1 = C_GBVM.CELL_EVENT then
                v1 := v2;
              Scan(next, eventBit or VarBit(Operand(3, isAddr), Lo(v1), 0));
            end;
          end;
        end;
        Push(next);
      end;
    end;
  end;
  Dispose(visited);
end;

{ The kind of the code at a: its control flow followed (jumps, calls, both ways past an IF, every ON GOTO address) for
  at most MAX_FOLLOW instructions, each path ending at EXIT, RETURN or NEWECL; with single, the instruction at a alone
  unless it is a GOTO or GOSUB, and when it is an IF, the instruction that IF guards in its place (#953). The strongest
  found wins: an area change, then a shop, temple or training hall (whose
  flag comes before the COMBAT that opens it), a fight, treasure, a trap, a message. }
function KindAt(a: Word; single: Boolean): Byte;
var
  todo: array[1..MAX_FOLLOW] of Word;
  todoLen: Byte;
  head: Byte;
  next: Word;
  afterIf: Word;
  op: Byte;
  isAddr: Boolean;
  isAddr2: Boolean;
  v: Word;
  n: Byte;
  i: Byte;
  sawExit: Boolean;
  sawService: Boolean;
  sawFight: Boolean;
  sawTreasure: Boolean;
  sawTrap: Boolean;
  sawMessage: Boolean;
  { with single, the one instruction that is the code's }
  only: Word;
  { the opcode an IF guards, decoded only to find the address past it }
  guarded: Byte;

  procedure Follow(t: Word);
  var
    k: Byte;
  begin
    if not InScript(t) or (todoLen >= MAX_FOLLOW) then Exit;
    for k := 1 to todoLen do
      if todo[k] = t then Exit;
    Inc(todoLen);
    todo[todoLen] := t;
  end;

begin
  sawExit := False;
  sawService := False;
  sawFight := False;
  sawTreasure := False;
  sawTrap := False;
  sawMessage := False;
  todoLen := 0;
  only := a;
  Follow(a);
  head := 1;
  while head <= todoLen do begin
    a := todo[head];
    Inc(head);
    op := Decode(a, next);
    case op of
      C_ECL.OP_EXIT, C_ECL.RETURN: next := 0;
      C_ECL.NEW_ECL: begin
            sawExit := True;
            next := 0;
          end;
      C_ECL.OP_COMBAT, C_ECL.ENCOUNTER_MENU, C_ECL.LOAD_MONSTER: sawFight := True;
      C_ECL.OP_PROGRAM: sawService := True;
      C_ECL.SAVE: begin
            { a shop's or temple's flag: the COMBAT after it opens the shop }
            v := Operand(2, isAddr);
            if isAddr and ((v = C_GBVM.ENTER_SHOP) or (v = C_GBVM.ENTER_TEMPLE)) then
              sawService := True;
          end;
      C_ECL.TREASURE: sawTreasure := True;
      C_ECL.DAMAGE: sawTrap := True;
      C_ECL.PRINT, C_ECL.PRINT_CLEAR, C_ECL.PRINT_RETURN: sawMessage := True;
      C_ECL.OP_GOTO: begin
            Follow(Operand(1, isAddr));
            next := 0;
          end;
      C_ECL.GOSUB: Follow(Operand(1, isAddr));
      C_ECL.ON_GOTO, C_ECL.ON_GOSUB: begin
            ListHead(a, v, isAddr, n);
            for i := 1 to n do
              Follow(Operand(i, isAddr2));
            if op = C_ECL.ON_GOTO then
              next := 0;
          end;
      C_ECL.IF_EQ..C_ECL.IF_GE:
        if single and (a = only) then
          { the IF's own instruction is the code's; past it is not }
          only := next
        else begin
          guarded := Decode(next, afterIf);
          Follow(afterIf);
        end;
    end;
    if single and (a = only) and not (op in [C_ECL.OP_GOTO, C_ECL.GOSUB]) then
      next := 0;
    if next <> 0 then
      Follow(next);
  end;
  if sawExit then
    KindAt := KIND_EXIT
  else if sawService then
    KindAt := KIND_SERVICE
  else if sawFight then
    KindAt := KIND_FIGHT
  else if sawTreasure then
    KindAt := KIND_TREASURE
  else if sawTrap then
    KindAt := KIND_TRAP
  else if sawMessage then
    KindAt := KIND_MESSAGE
  else
    KindAt := KIND_NONE;
end;

function Kind(event: Byte): Byte;
var
  i: Byte;
  k: Byte;
  t: Byte;
  found: Boolean;
begin
  Kind := KIND_NONE;
  if event = 0 then Exit;
  if kinds[event] <> UNKNOWN then begin
    Kind := kinds[event];
    Exit;
  end;
  { an event no dispatch is found for is one whose kind is not known }
  k := KIND_EVENT;
  found := False;
  for i := 1 to dispatchCount do
    if (event and dispatch[i].mask) = dispatch[i].value then begin
      t := EvtKind.KindAt(dispatch[i].target, dispatch[i].single);
      if not found or (t > k) then
        k := t;
      found := True;
    end;
  kinds[event] := k;
  Kind := k;
end;

end.
