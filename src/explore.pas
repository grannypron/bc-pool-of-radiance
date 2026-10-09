{ Dungeon and wilderness movement, door opening and the map menu. }
{$O+,F+}
unit Explore;

interface

uses Types, Crt, C_Area, C_Time, C_Msg, GDConsts, GDVars, SoundDrv, Camp, ViewChar, View3D,
  MapTiles, C_Ecl, C_Keys, C_Class, C_Status, C_Gbvm, C_Dir, C_Sound, C_Spell;

procedure ResolveMovement;

function MapMainMenu: Char;

implementation


var
  animData: Types.TAnimRec absolute GDVars.animData;

{ ChangeBarrierImpassable: clear the facing's two BARRIER bits (barriers plane), making it barrier type 0; the wall
  nibbles are untouched. }
procedure ChangeBarrierImpassable(x, y: ShortInt; facing: Byte);
begin
  case facing of
    C_Dir.WEST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $3F;
    C_Dir.SOUTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $CF;
    C_Dir.EAST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $F3;
    C_Dir.NORTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $FC;
  end;
end;

{ ChangeBarrierPassable: set the facing's two BARRIER bits to 01 (type 1, open); coordinates outside 0..15 are
  ignored. }
procedure ChangeBarrierPassable(x, y: ShortInt; facing: Byte);
begin
  if (x < 0) or (x > 15) or (y < 0) or (y > 15) then Exit;
  case facing of
    C_Dir.WEST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $3F or $40;
    C_Dir.SOUTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $CF or $10;
    C_Dir.EAST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $F3 or $4;
    C_Dir.NORTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $FC or $1;
  end;
end;

{ Return True if any party member has a level in the requested class. }
function PartyHasClass(idx: ShortInt): Boolean;
var
  p: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not found) do begin
    if p^.classLevels[idx] > 0 then found := True;
    p := p^.nextCharAddr;
  end;
  PartyHasClass := found;
end;

{ BashDoor: party members try in list order, on the AD&D Strength open-doors table, until one succeeds. BARRIER type 3
  (barred door) uses the locked/barred/magically-held column: 18/91 to 25 roll, and each member below 18/91 clears
  doorOpen[0] so Bash is not offered again at this door (later members still try this time). Otherwise the normal column
  covers Strength 3 to 18/00. Success opens the barrier from both sides. Note: Strength 19 and above has no case in the
  normal column and never succeeds. }
function BashDoor: Boolean;
var
  p: Types.PCharRecord;
  success: Boolean;
begin
  success := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not success) do begin
    with p^ do begin
      if View3D.GetBarrierType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing) = 3 then begin
        case strCur of
          18: case strExc of
                 91..99: if FxEngine.RollDice(1, 6) = 1 then success := True;
                 100: if FxEngine.RollDice(1, 6) <= 2 then success := True;
               else
                 GDVars.doorOpen[0] := 0;
               end;
          19, 20: if FxEngine.RollDice(1, 6) <= 3 then success := True;
          21, 22: if FxEngine.RollDice(1, 6) <= 4 then success := True;
          23: if FxEngine.RollDice(1, 6) <= 5 then success := True;
          24: if FxEngine.RollDice(1, 8) <= 7 then success := True;
          25: success := True;
        else
          GDVars.doorOpen[0] := 0;
        end;
      end else
        case strCur of
          3..7: if FxEngine.RollDice(1, 6) = 1 then success := True;
          8..15: if FxEngine.RollDice(1, 6) <= 2 then success := True;
          16..17: if FxEngine.RollDice(1, 6) <= 3 then success := True;
          18: case strExc of
                 0..50: if FxEngine.RollDice(1, 6) <= 3 then success := True;
                 51..99: if FxEngine.RollDice(1, 6) <= 4 then success := True;
                 100: if FxEngine.RollDice(1, 6) <= 5 then success := True;
               end;
        end;
    end;
    p := p^.nextCharAddr;
  end;
  if success then begin
    Explore.ChangeBarrierPassable(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
    Explore.ChangeBarrierPassable(GDVars.gMapX + GDConsts.dirDX[GDVars.gFacing],
                                   GDVars.gMapY + GDConsts.dirDY[GDVars.gFacing], (GDVars.gFacing + 4) mod 8);
  end;
  BashDoor := success;
end;

{ PickLock: each party member in turn rolls d100 against Open Locks (thiefSkills[2]); the roll counts only for an Okay
  character. One attempt per door: doorOpen[1] is cleared whatever the result. Success opens the barrier from both
  sides. }
function PickLock: Boolean;
var
  p: Types.PCharRecord;
  success: Boolean;
begin
  success := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not success) do begin
    with p^ do
      if (FxEngine.RollDice(1, 100) <= thiefSkills[2]) and (status = C_Status.OKAY) then
        success := True;
    p := p^.nextCharAddr;
  end;
  GDVars.doorOpen[1] := 0;
  if success then begin
    Explore.ChangeBarrierPassable(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
    Explore.ChangeBarrierPassable(GDVars.gMapX + GDConsts.dirDX[GDVars.gFacing],
                                   GDVars.gMapY + GDConsts.dirDY[GDVars.gFacing], (GDVars.gFacing + 4) mod 8);
  end;
  PickLock := success;
end;

{ Return the first memorizedSpells index (0..20) holding spellId, or 255 when none does. }
function FindMemorizedSpell(spellId: Byte; creature: Types.PCharRecord): Byte;
var
  i: Byte;
begin
  i := 0;
  { High(memorizedSpells) }
  while (i <= 20) and (creature^.memorizedSpells[i] <> spellId) do
    Inc(i);
  if i <= 20 then
    FindMemorizedSpell := i
  else
    FindMemorizedSpell := 255;
end;

{ Return the first party member with spellId memorized, or nil. }
function FindCharWithSpell(spellId: Byte): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  p := GDVars.creatureList;
  while (p <> nil) and (Explore.FindMemorizedSpell(spellId, p) = 255) do
    p := p^.nextCharAddr;
  FindCharWithSpell := p;
end;

{ PartyCastsKnock: the first party member with Knock (C_Spell.KNOCK) memorized uses it, clearing that slot; False when
  nobody has it. }
function PartyCastsKnock: Boolean;
var
  p: Types.PCharRecord;
begin
  p := Explore.FindCharWithSpell(C_Spell.KNOCK);
  if p <> nil then begin
    p^.memorizedSpells[Explore.FindMemorizedSpell(C_Spell.KNOCK, p)] := 0;
    PartyCastsKnock := True;
  end else
    PartyCastsKnock := False;
end;

{ MoveForward: clear C_Gbvm.LEAVE_MAP, then, unless the barrier ahead is type 0, compute the next square without moving
  there. A step off the 16x16 map puts gMapX/gMapY on that edge and sets C_Gbvm.LEAVE_MAP to 1. }
procedure MoveForward;
var
  nx: Integer;
  ny: Integer;
  f: Integer;
begin
  nx := GDVars.gMapX;
  ny := GDVars.gMapY;
  f := GDVars.gFacing;
  GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 0;
  if View3D.GetBarrierType(nx, ny, f) <> 0 then begin
    Inc(nx, GDConsts.dirDX[f]);
    Inc(ny, GDConsts.dirDY[f]);
    if nx > 15 then begin
      GDVars.gMapX := 15;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if nx < 0 then begin
      GDVars.gMapX := 0;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if ny > 15 then begin
      GDVars.gMapY := 15;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
    if ny < 0 then begin
      GDVars.gMapY := 0;
      GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 1;
    end;
  end;
end;

{ MovePartyForward3D: play the step sound, step with 16x16 edge wrap, refresh wallAhead and eventAtCell, reset the door
  flags and advance the clock one minute, or one turn when Search (C_Gbvm.SEARCH_FLAGS bit 0) is on. }
procedure MovePartyForward3D;
begin
  SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
  Inc(GDVars.gMapX, GDConsts.dirDX[GDVars.gFacing]);
  Inc(GDVars.gMapY, GDConsts.dirDY[GDVars.gFacing]);
  if GDVars.gMapX < 0 then GDVars.gMapX := 15;
  if GDVars.gMapX > 15 then GDVars.gMapX := 0;
  if GDVars.gMapY < 0 then GDVars.gMapY := 15;
  if GDVars.gMapY > 15 then GDVars.gMapY := 0;
  GDVars.wallAhead := View3D.GetWallType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  GDVars.eventAtCell := View3D.GetMapEvent(GDVars.gMapX, GDVars.gMapY);
  if GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1 > 0 then
    GameTime.AdvanceTime(1, C_Time.TURNS)
  else
    GameTime.AdvanceTime(1, C_Time.MINUTES);
end;

{ MovePartyWilderness: clamped step on the 36x44 wilderness map (x 0..15 within the region's 16-column window at
  wildColOfs, y 0..35). Impassable terrain glyphs block; river glyphs block with a message until
  zone0^.yarashPyramidLeft is nonzero. A step advances the clock 12 hours. }
procedure MovePartyWilderness;
var
  col: ShortInt;
  nx: ShortInt;
  ny: ShortInt;
begin
  nx := GDVars.zone0^.partyX.value + GDConsts.dirDX[GDVars.gFacing];
  ny := GDVars.zone0^.partyY.value + GDConsts.dirDY[GDVars.gFacing];
  if nx < 0 then nx := 0;
  if nx > 15 then nx := 15;
  if ny < 0 then ny := 0;
  { High(wildMap) on the first dimension }
  if ny > 35 then ny := 35;
  col := nx + GDConsts.wildColOfs[GDVars.gLocType];
  case GDConsts.wildMap[ny, col] of
    78, 126..128, 130..132, 168..172, 174..179, 188, 221..222,
    225..233, 245: ;
    102..108, 114:
      if GDVars.zone0^.yarashPyramidLeft = 0 then
        TextRend.PrintAndPause('The river''s stench drives you back.', Yellow)
      else begin
        GDVars.zone0^.partyX.value := nx;
        GDVars.zone0^.partyY.value := ny;
        GameTime.AdvanceTime(12, C_Time.HOURS);
      end;
  else begin
    GDVars.zone0^.partyX.value := nx;
    GDVars.zone0^.partyY.value := ny;
    GameTime.AdvanceTime(12, C_Time.HOURS);
  end;
  end;
end;

{ MapMainMenu: the 3D / wilderness command loop. Returns the key that ended it: 'E' (Encamp), 'L' (Look: sets
  C_Gbvm.SEARCH_FLAGS bit 1, advances the clock one turn and points eclIp at the search script entry), or an arrow scan
  code: in 3D 'H' after MoveForward, in the wilderness 'H', 'M', 'P' or 'K' after setting the facing. }
function MapMainMenu: Char;
var
  done: Boolean;
  c: Char;
  ext: Boolean;
  unusedMenuText: String[40];
  viewDone: Boolean;
  unusedPtr: Pointer;
begin
  GDVars.zone1^[C_Gbvm.MOVE_LOCKED] := 0;
  case GDVars.gLocType of
    C_Area.LOC_3D_MAP: begin
         done := False;
         repeat
           c := MenuCore.MenuHorizontal('', GDConsts.menu3D, LightMagenta, LightGreen, White, True, False,
                                        ext);
           if not ext then begin
             case c of
               'A': if GDVars.zone0^.noAutomap = 0 then begin
                      GDVars.automapOn := GDVars.automapOn = False;
                      View3D.Display3DMapView(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                    end else
                      TextRend.PrintAndPause('Not Here', Yellow);
               'C': if GDVars.curChar^.status = C_Status.OKAY then Camp.NoncombatCastMenu;
               'V': ViewChar.ViewCharMenu(viewDone);
               'E': done := True;
               'S': GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] xor 1;
               'L': begin
                      GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] or 2;
                      GameTime.AdvanceTime(1, C_Time.TURNS);
                      GDVars.eclIp := GDVars.scriptEntryAddrs[C_Ecl.ENTRY_SEARCH];
                      done := True;
                    end;
             end;
           end else begin
             case c of
               { up arrow: step forward }
               C_Keys.UP: begin
                         Explore.MoveForward;
                         done := True;
                       end;
               { down arrow: turn around }
               C_Keys.DOWN: begin
                           GDVars.gFacing := (GDVars.gFacing + 4) mod 8;
                           GDVars.wallAhead := View3D.GetWallType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                           View3D.Display3DMapView(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                         end;
               { left arrow: turn left }
               C_Keys.LEFT: begin
                           GDVars.gFacing := (GDVars.gFacing + 6) mod 8;
                           SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
                           GDVars.wallAhead := View3D.GetWallType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                           View3D.Display3DMapView(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                         end;
               { right arrow: turn right }
               C_Keys.RIGHT: begin
                            GDVars.gFacing := (GDVars.gFacing + 2) mod 8;
                            SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
                            GDVars.wallAhead := View3D.GetWallType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                            View3D.Display3DMapView(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                          end;
             else begin
               ViewChar.SelectPrevNextChar(c);
               CharHlp.DisplayParty(GDVars.curChar);
             end;
             end;
           end;
           CharHlp.PrintMiscInfo;
         until done;
       end;
    C_Area.LOC_WILD_WEST..C_Area.LOC_WILD_EAST: begin
        if GDVars.locTypePrev < C_Area.LOC_WILD_WEST then begin
          MapTiles.LoadIconAnim('ICON', 0, 9);
          MapTiles.LoadIconAnim('ICON', 1, 10);
          MapTiles.LoadIconAnim('ICON', 2, 11);
          CharHlp.DisplayWildernessInterface;
        end;
        done := False;
        repeat
          c := MenuCore.MenuHorizontal('', GDConsts.menuWild, LightMagenta, LightGreen, White, True, False,
                                       ext);
          if not ext then begin
            case c of
              'C': Camp.NoncombatCastMenu;
              'V': ViewChar.ViewCharMenu(viewDone);
              'E': done := True;
              'S': GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] xor 1;
              'L': begin
                     GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] or 2;
                     GameTime.AdvanceTime(1, C_Time.TURNS);
                     GDVars.eclIp := GDVars.scriptEntryAddrs[C_Ecl.ENTRY_SEARCH];
                     done := True;
                   end;
            end;
          end else begin
            done := True;
            case c of
              { up arrow }
              C_Keys.UP: GDVars.gFacing := C_Dir.NORTH;
              { right arrow }
              C_Keys.RIGHT: GDVars.gFacing := C_Dir.EAST;
              { down arrow }
              C_Keys.DOWN: GDVars.gFacing := C_Dir.SOUTH;
              { left arrow }
              C_Keys.LEFT: GDVars.gFacing := C_Dir.WEST;
            else begin
              ViewChar.SelectPrevNextChar(c);
              CharHlp.DisplayParty(GDVars.curChar);
              done := False;
            end;
            end;
          end;
          CharHlp.PrintMiscInfo;
        until done;
      end;
  end;
  GDVars.locTypePrev := GDVars.gLocType;
  if GDVars.bottomMsgCleared = 0 then begin
    Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    GDVars.bottomMsgCleared := 1;
  end;
  MapMainMenu := c;
end;

{ ResolveMovement: while C_Gbvm.MOVE_LOCKED is 255 movement is refused and the flag is reset to 0 instead. On a 3D map
  BARRIER type 1 steps forward and type 0 or an unopened door plays the impact sound. Types 2 and 3 run the 'Locked.'
  door menu assembled from the door flags: Bash, Pick (party has a thief), Knock (type 2: someone has Knock memorized;
  type 3: party has a mage) and Exit; a bare ' Exit' walls the door off. On a type 3 door Pick only clears doorOpen[1].
  A wilderness map takes a MovePartyWilderness step. The portrait and animation buffers are always freed on the way
  out. }
procedure ResolveMovement;
var
  moved: Boolean;
  unusedExtendedKey: Boolean;
  menuStr: String[40];
  c2: Char;
begin
  moved := False;
  case GDVars.gLocType of
    C_Area.LOC_3D_MAP: if GDVars.zone1^[C_Gbvm.MOVE_LOCKED] < 255 then begin
         case View3D.GetBarrierType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing) of
           1: moved := True;
           2: begin
                menuStr[0] := #0;
                if GDVars.doorOpen[0] <> 0 then
                  menuStr := 'Bash';
                if (GDVars.doorOpen[1] <> 0) and Explore.PartyHasClass(C_Class.LEVEL_THIEF) then
                  menuStr := menuStr + ' Pick';
                if (GDVars.doorOpen[2] <> 0) and (Explore.FindCharWithSpell(C_Spell.KNOCK) <> nil)
                then
                  menuStr := menuStr + ' Knock';
                menuStr := menuStr + ' Exit';
                if menuStr = ' Exit' then
                  Explore.ChangeBarrierImpassable(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing)
                else begin
                  c2 := MenuCore.MenuHorizontal('Locked. ', menuStr, LightMagenta, LightGreen,
                                                White, False, False, unusedExtendedKey);
                  case c2 of
                    'B': moved := Explore.BashDoor;
                    'P': moved := Explore.PickLock;
                    'K': moved := Explore.PartyCastsKnock;
                  end;
                end;
              end;
           3: begin
                menuStr[0] := #0;
                if GDVars.doorOpen[0] <> 0 then
                  menuStr := 'Bash';
                if (GDVars.doorOpen[1] <> 0) and Explore.PartyHasClass(C_Class.LEVEL_THIEF) then
                  menuStr := menuStr + ' Pick';
                if (GDVars.doorOpen[2] <> 0) and Explore.PartyHasClass(C_Class.LEVEL_MAGE) then
                  menuStr := menuStr + ' Knock';
                menuStr := menuStr + ' Exit';
                if menuStr = ' Exit' then
                  Explore.ChangeBarrierImpassable(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing)
                else begin
                  c2 := MenuCore.MenuHorizontal('Locked. ', menuStr, LightMagenta, LightGreen,
                                                White, False, False, unusedExtendedKey);
                  case c2 of
                    'B': moved := Explore.BashDoor;
                    'P': GDVars.doorOpen[1] := 0;
                    'K': moved := Explore.PartyCastsKnock;
                  end;
                end;
              end;
         end;
         if moved then
           Explore.MovePartyForward3D
         else
           SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.IMPACT]);
         CharHlp.PrintMiscInfo;
       end else
         GDVars.zone1^[C_Gbvm.MOVE_LOCKED] := 0;
    C_Area.LOC_WILD_WEST..C_Area.LOC_WILD_EAST: if GDVars.zone1^[C_Gbvm.MOVE_LOCKED] < 255 then begin
            Explore.MovePartyWilderness;
            CharHlp.PrintMiscInfo;
          end else
            GDVars.zone1^[C_Gbvm.MOVE_LOCKED] := 0;
  end;
  Portrait.FreeAnimation(animData);
  Blit.FreePic(GDVars.dsPortraitCache[1].pic);
  Blit.FreePic(GDVars.dsPortraitCache[2].pic);
  GDVars.dsPortraitCache[1].pictureId := 255;
  GDVars.dsPortraitCache[2].pictureId := 255;
end;

begin
end.
