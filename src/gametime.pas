{ Resting, spell preparation and game-clock advancement, including expiration of timed effects. }
{$O+,F+}
unit GameTime;

interface

uses Types, C_Time, C_Msg, GDConsts, GDVars, Crt, TextRend, CharHlp, MenuCore, Magic, C_Keys, C_Ifc, C_Gbvm, C_Spell;

procedure AdvanceTime(amount: Byte; tUnit: ShortInt);

function CampRest(interactive: Boolean): Boolean;

implementation

{ Age every timed effect (duration > 0 minutes) of each creature by count units of tUnit (ten segments to the minute),
  in steps of at most 10 minutes, removing those that run out. Outside camp every creature is visited; in camp only
  those GDVars.effFlags marks as still holding timed effects. Each step first ages the effects and notes the expiring
  ones, then removes those still in the list, since a removal's handler can remove (and free) another effect. }
procedure TimeOutEffects(count: Byte; tUnit: ShortInt);
const
  { expiring effects one creature can lose in one step; any more expire in the next step }
  MAX_EXPIRING = 32;
var
  u: ShortInt;
  i: Byte;
  k: Byte;
  step: Byte;
  total: LongInt;
  cur: Types.PCharRecord;
  found: Boolean;
  e: Types.PEffectRec;
  expiring: array[1..MAX_EXPIRING] of Types.PEffectRec;
  expiringId: array[1..MAX_EXPIRING] of Byte;
  expiringDuration: array[1..MAX_EXPIRING] of Word;
  nExpiring: Byte;
  again: Boolean;

  { Whether eff is still in cur's effect list: an earlier removal's handler may have removed and freed it (Slow
    Poison's end removes the poison's damage effect). }
  function InList(eff: Types.PEffectRec): Boolean;
  var
    p: Types.PEffectRec;
  begin
    p := Types.PEffectRec(cur^.effectsAddr);
    while (p <> nil) and (p <> eff) do
      p := p^.next;
    InList := p <> nil;
  end;

begin
  if GDVars.ifcState <> C_Ifc.CAMPING then
    FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1)
  else begin
    found := False;
    i := 1;
    repeat
      if GDVars.effFlags[i] <> 0 then found := True;
      Inc(i);
    until found or (i > GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
    if not found then Exit;
  end;
  total := count;
  u := tUnit;
  if u = C_Time.SEGMENTS then
    total := total div GDConsts.unitScale[C_Time.SEGMENTS];
  while u > 1 do begin
    total := GDConsts.unitScale[Pred(u)] * total;
    u := Pred(u);
  end;
  while total > 0 do begin
    if total > 10 then step := 10 else step := total;
    i := 1;
    cur := GDVars.creatureList;
    while cur <> nil do begin
      if (i > SizeOf(GDVars.effFlags)) or (GDVars.effFlags[i] <> 0) then begin
        again := False;
        { age the timed effects, and note those that run out in this step; 0 is permanent }
        nExpiring := 0;
        e := Types.PEffectRec(cur^.effectsAddr);
        while e <> nil do begin
          if e^.duration > 0 then
            if step < e^.duration then begin
              Dec(e^.duration, step);
              again := True;
            end else if nExpiring < MAX_EXPIRING then begin
              Inc(nExpiring);
              expiring[nExpiring] := e;
              expiringId[nExpiring] := e^.id;
              expiringDuration[nExpiring] := e^.duration;
            end else
              again := True;
          e := e^.next;
        end;
        { then remove them, skipping any an earlier removal has already taken away; a node a handler allocated since
          can reuse a freed one's address, so the id and duration must still match }
        for k := 1 to nExpiring do
          if InList(expiring[k]) and (expiring[k]^.id = expiringId[k]) and
              (expiring[k]^.duration = expiringDuration[k]) then
            FxEngine.RemoveEffect(cur, expiring[k]^.id, expiring[k]);
        { a removal's handler can add effects too: the creature is visited again while any timed effect is left }
        e := Types.PEffectRec(cur^.effectsAddr);
        while (e <> nil) and not again do begin
          if e^.duration > 0 then again := True;
          e := e^.next;
        end;
        if i <= SizeOf(GDVars.effFlags) then
          if again then GDVars.effFlags[i] := 1 else GDVars.effFlags[i] := 0;
      end;
      Inc(i);
      cur := cur^.nextCharAddr;
    end;
    if total > 10 then Dec(total, 10) else total := 0;
  end;
end;

{ Carry each clock component that has reached its GDConsts.unitScale limit into the next one (one carry per component
  per call); the year has no limit. When ageOnYear is set, every creature in GDVars.creatureList ages by one as the
  months carry into a new year. }
procedure ValidateClock(var clock: Types.TClock; ageOnYear: Boolean);
var
  i: ShortInt;
  cur: Types.PCharRecord;
begin
  for i := 0 to C_Time.MONTHS do
    if clock[i] >= GDConsts.unitScale[i] then begin
      Inc(clock[Succ(i)]);
      clock[i] := clock[i] - GDConsts.unitScale[i];
      if (i = C_Time.MONTHS) and ageOnYear then begin
        cur := GDVars.creatureList;
        while cur <> nil do begin
          Inc(cur^.age);
          cur := cur^.nextCharAddr;
        end;
      end;
    end;
end;

{ Normalize the rest timer: carry components and fold any months into days (30 each), capping the days at 99 }
procedure ValidateRestTime;
begin
  GameTime.ValidateClock(GDVars.dsRestingTimeGbvm, False);
  if GDVars.dsRestingTimeGbvm[C_Time.MONTHS] > 0 then begin
    Inc(GDVars.dsRestingTimeGbvm[C_Time.DAYS],
        GDConsts.unitScale[C_Time.DAYS] * GDVars.dsRestingTimeGbvm[C_Time.MONTHS]);
    GDVars.dsRestingTimeGbvm[C_Time.MONTHS] := 0;
    if GDVars.dsRestingTimeGbvm[C_Time.DAYS] > 99 then GDVars.dsRestingTimeGbvm[C_Time.DAYS] := 99;
  end;
end;

{ Read the game clock from the GBVM clock words, bump component tUnit amount times (validating after each bump), write
  it back, then time out effects by the same duration }
procedure AdvanceTime(amount: Byte; tUnit: ShortInt);
var
  clock: Types.TClock;
  i: ShortInt;
  j: Byte;
begin
  for i := 0 to 6 do
    clock[i] := GDVars.zone0^.words[C_Gbvm.CLOCK + i];
  for j := 1 to amount do begin
    Inc(clock[tUnit]);
    GameTime.ValidateClock(clock, True);
  end;
  for i := 0 to 6 do
    GDVars.zone0^.words[C_Gbvm.CLOCK + i] := clock[i];
  GameTime.TimeOutEffects(amount, tUnit);
end;

{ Subtract a duration from the rest timer, borrowing from higher components. If no higher component can supply the
  borrow, clear the timer. }
procedure DecrementRestTime(count: Byte; tUnit: ShortInt);
var
  j: ShortInt;
  k: ShortInt;
begin
  if (GDVars.dsRestingTimeGbvm[C_Time.DAYS] <> 0) or (GDVars.dsRestingTimeGbvm[C_Time.HOURS] <> 0) or
      (GDVars.dsRestingTimeGbvm[C_Time.TURNS] <> 0) or (GDVars.dsRestingTimeGbvm[C_Time.MINUTES] <> 0)
  then begin
    while count > GDVars.dsRestingTimeGbvm[tUnit] do begin
      j := Succ(tUnit);
      while (GDVars.dsRestingTimeGbvm[j] = 0) and (j < C_Time.MONTHS) do
        j := Succ(j);
      if j = C_Time.MONTHS then begin
        FillChar(GDVars.dsRestingTimeGbvm, SizeOf(GDVars.dsRestingTimeGbvm), 0);
        count := 0;
      end else
        for k := j downto Succ(tUnit) do begin
          Dec(GDVars.dsRestingTimeGbvm[k]);
          Inc(GDVars.dsRestingTimeGbvm[Pred(k)], GDConsts.unitScale[Pred(k)]);
        end;
    end;
    Dec(GDVars.dsRestingTimeGbvm[tUnit], count);
    GameTime.ValidateRestTime;
  end;
end;

{ v as a two-digit string, with a leading zero below 10 }
function TwoDigitStr(v: Byte): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := CharHlp.ByteToString(v);
  if v < 10 then s := '0' + s;
  TwoDigitStr := Copy(s, 1, 2);
end;

{ Display the rest timer as days, hours and minutes. Highlight component hl (2 minutes, 3 hours, 4 days); 0 leaves all
  components unhighlighted. }
procedure DisplayRestTime(hl: ShortInt);
var
  i: ShortInt;
  colors: array[0..6] of Word;
  x: Byte;
begin
  for i := 0 to 6 do
    colors[i] := LightGreen;
  colors[hl] := White;
  TextRend.DisplayString(1, 17, LightGreen, 'Rest Time:');
  x := 11;
  for i := C_Time.DAYS downto C_Time.HOURS do begin
    TextRend.DisplayString(x + 1, 17, colors[i], GameTime.TwoDigitStr(GDVars.dsRestingTimeGbvm[i]));
    TextRend.DisplayString(x + 1 + 2, 17, LightGreen, ':');
    Inc(x, 3);
  end;
  TextRend.DisplayString(x + 1, 17, colors[C_Time.TURNS],
                         GameTime.TwoDigitStr(10 * GDVars.dsRestingTimeGbvm[C_Time.TURNS] +
                           GDVars.dsRestingTimeGbvm[C_Time.MINUTES]));
end;

{ Rest-duration menu; returns True when the player picks Rest. Arrow keys: up = Inc, down = Dec, left/right = cycle the
  highlighted column (sel 2 = Mins, 3 = Hours, 4 = Days); Enter = the highlighted option. Inc/Dec on the Mins column
  steps by 5 minutes }
function CampRestMenu: Boolean;
var
  ext: Boolean;
  ch: Char;
  sel: ShortInt;
begin
  CampRestMenu := False;
  sel := C_Time.TURNS;
  repeat
    GameTime.DisplayRestTime(sel);
    MenuCore.arrowsToCaller := True;
    ch := MenuCore.MenuHorizontal('', 'Rest   daYs Hours Mins   Inc Dec   Exit', LightMagenta, LightGreen,
                                  White, True, False, ext);
    if ext then
      case ch of
        { up arrow    -> 'I'nc }
        C_Keys.UP: ch := 'I';
        { down arrow -> 'D'ec }
        C_Keys.DOWN: ch := 'D';
        { left arrow }
        C_Keys.LEFT: begin
                    Inc(sel);
                    if sel > C_Time.DAYS then sel := C_Time.TURNS;
                    ch := #88;
                  end;
        { right arrow }
        C_Keys.RIGHT: begin
                     Dec(sel);
                     if sel < C_Time.TURNS then sel := C_Time.DAYS;
                     ch := #88;
                   end;
      else
        ch := #88;
      end;
    case ch of
      'R': CampRestMenu := True;
      'Y': sel := C_Time.DAYS;
      'H': sel := C_Time.HOURS;
      'M': sel := C_Time.TURNS;
      'I': begin
             if sel = C_Time.TURNS then
               Inc(GDVars.dsRestingTimeGbvm[C_Time.MINUTES], 5)
             else
               Inc(GDVars.dsRestingTimeGbvm[sel]);
             GameTime.ValidateRestTime;
           end;
      'D': begin
             if sel = C_Time.TURNS then
               GameTime.DecrementRestTime(5, C_Time.MINUTES)
             else
               GameTime.DecrementRestTime(1, sel);
             GameTime.ValidateRestTime;
           end;
    end;
  until ch in [C_Keys.NONE, 'E', 'R'];
end;

{ Every 288 five-minute ticks (24 h) of rest, restore 1 hp to every creature in GDVars.creatureList. The "Healed" banner
  prints unconditionally; the party pane redraws only if anyone actually healed }
procedure CheckRestingHeal;
var
  healed: Boolean;
  cur: Types.PCharRecord;
begin
  Inc(GDVars.healTicks);
  if GDVars.healTicks >= 288 then begin
    healed := False;
    cur := GDVars.creatureList;
    while cur <> nil do begin
      if FxEngine.RestoreHitPoints(cur, 1, False) then healed := True;
      cur := cur^.nextCharAddr;
    end;
    GameTime.DisplayRestTime(0);
    TextRend.DisplayString(1, 19, LightGreen, 'The Whole Party Is Healed');
    if healed then CharHlp.DisplayParty(GDVars.curChar);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
    GDVars.healTicks := 0;
  end;
end;

{ Scan the 21 memorized-spell slots; bit 7 set = still memorizing. With done already True, return the first pending
  spell's level; otherwise clear the bit (spell finished), announce it and set done, so the scan goes on to return the
  next pending spell's level. Returns 0 when nothing (more) is pending. A slot whose spell id is outside 1..C_Spell.LAST
  is passed over. }
function CheckMemorizeDone(creature: Types.PCharRecord; var done: Boolean): Byte;
var
  lvl: Byte;
  i: Byte;
begin
  lvl := 0;
  i := 0;
  { 20 = High(memorizedSpells) }
  while (i <= 20) and (lvl = 0) do begin
    if (creature^.memorizedSpells[i] > $7F) and
        (creature^.memorizedSpells[i] and C_Spell.ID_MASK in [1..C_Spell.LAST]) then
      if done then
        lvl := GDConsts.spellTable[creature^.memorizedSpells[i] and C_Spell.ID_MASK].level
      else begin
        Dec(creature^.memorizedSpells[i], C_Spell.PENDING_FLAG);
        GameTime.DisplayRestTime(0);
        Magic.PrintCastSpellMsg(creature, 'has memorized', creature^.memorizedSpells[i]);
        done := True;
      end;
    Inc(i);
  end;
  CheckMemorizeDone := lvl;
end;

{ The scribing counterpart of CheckMemorizeDone over the readable items' scroll spells queued for scribing (id > $80, in
  TItemRec's spells[1..3]). Finishing one marks it known, removes it with Magic.RemoveSpellFromScroll and announces it;
  a scroll freed with its last spell is left and the scan goes on with the next item. A spell id outside 1..C_Spell.LAST
  is passed over. }
function CheckScribeDone(creature: Types.PCharRecord; var done: Boolean): Byte;
var
  j: Byte;
  sp: Byte;
  lvl: Byte;
  item: Types.PItemRec;
  nxt: Types.PItemRec;
  held: Types.PItemRec;
begin
  lvl := 0;
  item := creature^.itemsAddr;
  while (item <> nil) and (lvl = 0) do begin
    nxt := item^.next;
    j := 1;
    if Magic.ItemReadable(item) then
      { 3 = High(TItemRec.spells) }
      while (j <= 3) and (lvl = 0) do begin
        if (item^.spells[j] > $80) and (item^.spells[j] and C_Spell.ID_MASK <= C_Spell.LAST) then
          if done then
            lvl := GDConsts.spellTable[item^.spells[j] and C_Spell.ID_MASK].level
          else begin
            sp := item^.spells[j] and C_Spell.ID_MASK;
            creature^.spellsKnown[sp] := 1;
            Magic.RemoveSpellFromScroll(creature, item, sp);
            GameTime.DisplayRestTime(0);
            Magic.PrintCastSpellMsg(creature, 'has scribed', sp);
            done := True;
            held := creature^.itemsAddr;
            while (held <> nil) and (held <> item) do
              held := held^.next;
            { the scroll is gone }
            if held = nil then
              j := 3;
          end;
        Inc(j);
      end;
    item := nxt;
  end;
  CheckScribeDone := lvl;
end;

{ Per rest tick: count each party slot's prep timer down (a zero timer wraps to 255); when it reaches zero with the base
  time expired (spellPrepTime = 0), finish the pending scribe or memorization and reload the timer with 3 ticks per
  level of the next pending spell (15 min/level) }
procedure AdvanceSpellPrep;
var
  i: Byte;
  lvl: Byte;
  cur: Types.PCharRecord;
  done: Boolean;
begin
  i := 1;
  cur := GDVars.creatureList;
  { the walk stops at the last prepTimers slot }
  while (cur <> nil) and (i <= SizeOf(GDVars.prepTimers)) do begin
    Dec(GDVars.prepTimers[i]);
    if (GDVars.prepTimers[i] = 0) and (cur^.spellPrepTime = 0) then begin
      done := False;
      lvl := GameTime.CheckScribeDone(cur, done);
      if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
      GDVars.prepTimers[i] := lvl * 3;
    end;
    cur := cur^.nextCharAddr;
    Inc(i);
  end;
end;

{ Once per 12 ticks (1 hour) count down each character's base prep time (spellPrepTime, the hours before spell
  preparation starts in earnest). On the hour it expires, seed prepTimers from the level of the next pending scribe
  (else memorization). done = True makes the helpers only look the level up, completing nothing; the finishing is
  AdvanceSpellPrep's, which passes False. }
procedure AdvanceSpellPrepBase(var tick: Byte);
var
  i: Byte;
  lvl: Byte;
  cur: Types.PCharRecord;
  done: Boolean;
begin
  Inc(tick);
  if tick >= 12 then begin
    tick := 0;
    i := 1;
    cur := GDVars.creatureList;
    while cur <> nil do begin
      if ShortInt(cur^.spellPrepTime) > 0 then begin
        Dec(cur^.spellPrepTime);
        if cur^.spellPrepTime = 0 then begin
          done := True;
          lvl := GameTime.CheckScribeDone(cur, done);
          if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
          if i <= SizeOf(GDVars.prepTimers) then
            GDVars.prepTimers[i] := lvl * 3;
        end;
      end;
      cur := cur^.nextCharAddr;
      Inc(i);
    end;
  end;
end;

{ Let the player set the rest duration (CampRestMenu) when interactive, else rest for the duration already in
  dsRestingTimeGbvm. Rest in five-minute ticks, advancing the clock, healing and spell preparation. A keypress offers
  to stop. Returns True when a scripted random interruption ends the rest. }
function CampRest(interactive: Boolean): Boolean;
var
  cur: Types.PCharRecord;
  dead1: Pointer;
  dead2: Byte;
  i: Byte;
  tick: Byte;
  cnt: Byte;
  stop: Boolean;
  dead3: Boolean;
begin
  CampRest := False;
  dead3 := False;
  i := 1;
  cur := GDVars.creatureList;
  while (cur <> nil) and (i <= SizeOf(GDVars.prepTimers)) do begin
    GDVars.prepTimers[i] := 0;
    Inc(i);
    cur := cur^.nextCharAddr;
  end;
  FillChar(GDVars.effFlags, SizeOf(GDVars.effFlags), 1);
  tick := 0;
  cnt := 0;
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  GameTime.DisplayRestTime(0);
  GDVars.dsSuppressDrawingBorderFlag := 1;
  if interactive then
    stop := not GameTime.CampRestMenu
  else
    stop := False;
  while (not stop) and
      ((GDVars.dsRestingTimeGbvm[C_Time.DAYS] > 0) or (GDVars.dsRestingTimeGbvm[C_Time.HOURS] > 0) or
       (GDVars.dsRestingTimeGbvm[C_Time.TURNS] > 0) or (GDVars.dsRestingTimeGbvm[C_Time.MINUTES] > 0))
  do begin
    if KeyPressed then begin
      GameTime.DisplayRestTime(0);
      if MenuCore.YesNoMenu('Stop Resting? ', LightMagenta, LightGreen, White) = 'Y' then
        stop := True
      else
        MenuCore.ClearBottomLine;
    end;
    if not stop then begin
      GameTime.DecrementRestTime(5, C_Time.MINUTES);
      Inc(cnt);
      if cnt >= 5 then begin
        GameTime.DisplayRestTime(0);
        cnt := 0;
      end;
      GameTime.AdvanceTime(5, C_Time.MINUTES);
      GameTime.CheckRestingHeal;
      GameTime.AdvanceSpellPrep;
      GameTime.AdvanceSpellPrepBase(tick);
      { When the area sets a safe-rest period, roll for an interruption each time it runs out }
      if GDVars.zone1^[C_Gbvm.REST_SAFE_TIME] > 0 then begin
        Inc(GDVars.restTicks);
        if GDVars.restTicks >= GDVars.zone1^[C_Gbvm.REST_SAFE_TIME] then begin
          GDVars.restTicks := 0;
          if FxEngine.RollDice(1, 100) <= GDVars.zone1^[C_Gbvm.REST_INTERRUPT_PCT] then begin
            CharHlp.ClearMessageWindow;
            GameTime.DisplayRestTime(0);
            TextRend.DisplayString(1, 19, White, 'The Party is rudely interrupted!');
            stop := True;
            CampRest := True;
            TextRend.PauseOnly;
          end;
        end;
      end;
    end;
  end;
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  GDVars.dsSuppressDrawingBorderFlag := 0;
end;

end.
