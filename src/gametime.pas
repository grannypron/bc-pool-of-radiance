{ Resting, spell preparation and game-clock advancement, including expiration of timed effects. }
{$O+,F+}
unit GameTime;

interface

function CampRest(interactive: Boolean): Boolean;

implementation

uses Types, C_Time, C_Msg, GDConsts, GDVars, Crt, TextRend, CharHlp, MenuCore, Magic, C_Keys, C_Gbvm, C_Spell,
  FxEngine, StrUtil, CharDisp;

{ Normalize the rest timer: carry components and fold any months into days (30 each), capping the days at 99 }
procedure ValidateRestTime;
begin
  FxEngine.ValidateClock(GDVars.dsRestingTimeGbvm, False);
  if GDVars.dsRestingTimeGbvm[C_Time.MONTHS] > 0 then begin
    Inc(GDVars.dsRestingTimeGbvm[C_Time.DAYS],
        GDConsts.unitScale[C_Time.DAYS] * GDVars.dsRestingTimeGbvm[C_Time.MONTHS]);
    GDVars.dsRestingTimeGbvm[C_Time.MONTHS] := 0;
    if GDVars.dsRestingTimeGbvm[C_Time.DAYS] > 99 then GDVars.dsRestingTimeGbvm[C_Time.DAYS] := 99;
  end;
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
    TextRend.DisplayString(x + 1, 17, colors[i], StrUtil.ZeroPad2(GDVars.dsRestingTimeGbvm[i]));
    TextRend.DisplayString(x + 1 + 2, 17, LightGreen, ':');
    Inc(x, 3);
  end;
  TextRend.DisplayString(x + 1, 17, colors[C_Time.TURNS],
                         StrUtil.ZeroPad2(10 * GDVars.dsRestingTimeGbvm[C_Time.TURNS] +
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
    if healed then CharDisp.DisplayParty(GDVars.curChar);
    TextRend.PauseOnly;
    CharDisp.ClearMessageWindow;
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
  while (i <= Types.SPELL_SLOT_LAST) and (lvl = 0) do begin
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
    if CharHlp.ItemReadable(item) then
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
        TextRend.ClearBottomLine;
    end;
    if not stop then begin
      GameTime.DecrementRestTime(5, C_Time.MINUTES);
      Inc(cnt);
      if cnt >= 5 then begin
        GameTime.DisplayRestTime(0);
        cnt := 0;
      end;
      FxEngine.AdvanceTime(5, C_Time.MINUTES);
      GameTime.CheckRestingHeal;
      GameTime.AdvanceSpellPrep;
      GameTime.AdvanceSpellPrepBase(tick);
      { When the area sets a safe-rest period, roll for an interruption each time it runs out }
      if GDVars.zone1^[C_Gbvm.REST_SAFE_TIME] > 0 then begin
        Inc(GDVars.restTicks);
        if GDVars.restTicks >= GDVars.zone1^[C_Gbvm.REST_SAFE_TIME] then begin
          GDVars.restTicks := 0;
          if FxEngine.RollDice(1, 100) <= GDVars.zone1^[C_Gbvm.REST_INTERRUPT_PCT] then begin
            CharDisp.ClearMessageWindow;
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
