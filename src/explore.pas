{ Dungeon and wilderness movement, door opening and the map menu. }
{$O+,F+}
{$I COMPILER.INC}
unit Explore;

interface

procedure ResolveMovement;

function MapMainMenu: Char;

var
  { Set by F8 on the map menu when there is a quick save to load: MapMainMenu returns, GameLoop returns, and the
    program loads it (SaveLoad.QuickLoad) and runs GameLoop again; the program clears it. }
  quickLoadAsked: Boolean;

implementation

uses Types, Crt, C_AREA, C_TIME, C_MSG, GDConsts, GDVars, SoundDrv, Camp, ViewChar, JrnlView, View3D, MapTiles, C_ECL,
  C_KEYS, C_Level, C_STATUS, C_GBVM, C_DIR, C_Sound, C_SPELL, SaveLoad, Blit, Border, CharHlp, FxEngine,
  MenuCore, Portrait, TextRend, CharDisp, Party, Dice, CompTool;

{ ChangeBarrierImpassable: clear the facing's two BARRIER bits (barriers plane), making it barrier type 0; the wall
  nibbles are untouched, and coordinates outside the map (0..Types.MAP_LAST) are ignored. }
procedure ChangeBarrierImpassable(x, y: ShortInt; facing: Byte);
begin
  if (x < 0) or (x > Types.MAP_LAST) or (y < 0) or (y > Types.MAP_LAST) then Exit;
  case facing of
    C_DIR.WEST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $3F;
    C_DIR.SOUTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $CF;
    C_DIR.EAST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $F3;
    C_DIR.NORTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $FC;
  end;
end;

{ ChangeBarrierPassable: set the facing's two BARRIER bits to 01 (type 1, open); coordinates outside the map
  (0..Types.MAP_LAST) are ignored. }
procedure ChangeBarrierPassable(x, y: ShortInt; facing: Byte);
begin
  if (x < 0) or (x > Types.MAP_LAST) or (y < 0) or (y > Types.MAP_LAST) then Exit;
  case facing of
    C_DIR.WEST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $3F or $40;
    C_DIR.SOUTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $CF or $10;
    C_DIR.EAST: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $F3 or $4;
    C_DIR.NORTH: GDVars.map3d^.barriers[y, x] := GDVars.map3d^.barriers[y, x] and $FC or $1;
  end;
end;

{ Open the barrier the party faces, from both sides: its own cell's side and the facing cell's opposite side. }
procedure OpenBarrierAhead;
begin
  Explore.ChangeBarrierPassable(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
  Explore.ChangeBarrierPassable(GDVars.gMapX + GDConsts.dirDX[GDVars.gFacing],
                                GDVars.gMapY + GDConsts.dirDY[GDVars.gFacing], (GDVars.gFacing + 4) mod 8);
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

{ BashDoor: Okay party members try in list order, on the AD&D Strength open-doors table, until one succeeds. BARRIER
  type 3 (barred door) uses the locked/barred/magically-held column: 18/91 to 25 roll, and each member below 18/91
  clears doorOpen[0] so Bash is not offered again at this door (later members still try this time). Otherwise the normal
  column covers Strength 3 to 25 (19 and above, from a Potion of Giant Strength, on the Players Handbook's odds).
  Strength above 25 counts as 25 and exceptional strength above 100 as 18/00. Success opens the barrier from both
  sides. }
function BashDoor: Boolean;
var
  p: Types.PCharRecord;
  success: Boolean;
begin
  success := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not success) do begin
    { only an Okay member can force the door }
    if p^.status = C_STATUS.OKAY then
    with p^ do begin
      if View3D.GetBarrierType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing) = 3 then begin
        case strCur of
          18: case strExc of
                 91..99: if Dice.RollDice(1, 6) = 1 then success := True;
                 100..255: if Dice.RollDice(1, 6) <= 2 then success := True;
               else
                 GDVars.doorOpen[0] := 0;
               end;
          19, 20: if Dice.RollDice(1, 6) <= 3 then success := True;
          21, 22: if Dice.RollDice(1, 6) <= 4 then success := True;
          23: if Dice.RollDice(1, 6) <= 5 then success := True;
          24: if Dice.RollDice(1, 8) <= 7 then success := True;
          25..255: if Dice.RollDice(1, 10) <= 9 then success := True;
        else
          GDVars.doorOpen[0] := 0;
        end;
      end else
        case strCur of
          3..7: if Dice.RollDice(1, 6) = 1 then success := True;
          8..15: if Dice.RollDice(1, 6) <= 2 then success := True;
          16..17: if Dice.RollDice(1, 6) <= 3 then success := True;
          18: case strExc of
                 0..50: if Dice.RollDice(1, 6) <= 3 then success := True;
                 51..99: if Dice.RollDice(1, 6) <= 4 then success := True;
                 100..255: if Dice.RollDice(1, 6) <= 5 then success := True;
               end;
          19, 20: if Dice.RollDice(1, 8) <= 7 then success := True;
          21: if Dice.RollDice(1, 10) <= 9 then success := True;
          22, 23: if Dice.RollDice(1, 12) <= 11 then success := True;
          24: if Dice.RollDice(1, 20) <= 19 then success := True;
          25..255: if Dice.RollDice(1, 24) <= 23 then success := True;
        end;
    end;
    p := p^.nextCharAddr;
  end;
  if success then
    Explore.OpenBarrierAhead;
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
      if (Dice.RollDice(1, 100) <= thiefSkills[2]) and (status = C_STATUS.OKAY) then
        success := True;
    p := p^.nextCharAddr;
  end;
  GDVars.doorOpen[1] := 0;
  if success then
    Explore.OpenBarrierAhead;
  PickLock := success;
end;

{ Return the first memorizedSpells index (0..20) holding spellId, or 255 when none does. }
function FindMemorizedSpell(spellId: Byte; creature: Types.PCharRecord): Byte;
var
  i: Byte;
begin
  i := 0;
  while (i <= Types.SPELL_SLOT_LAST) and (creature^.memorizedSpells[i] <> spellId) do
    Inc(i);
  if i <= Types.SPELL_SLOT_LAST then
    FindMemorizedSpell := i
  else
    FindMemorizedSpell := 255;
end;

{ Return the first Okay party member with spellId memorized, or nil: a dead, unconscious or otherwise disabled member
  cannot cast. }
function FindCharWithSpell(spellId: Byte): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  p := GDVars.creatureList;
  while (p <> nil) and ((p^.status <> C_STATUS.OKAY) or (Explore.FindMemorizedSpell(spellId, p) = 255)) do
    p := p^.nextCharAddr;
  FindCharWithSpell := p;
end;

{ PartyCastsKnock: the first party member with Knock (C_SPELL.KNOCK) memorized uses it, clearing that slot, and the
  barrier opens from both sides; False when nobody has it. }
function PartyCastsKnock: Boolean;
var
  p: Types.PCharRecord;
begin
  p := Explore.FindCharWithSpell(C_SPELL.KNOCK);
  if p <> nil then begin
    CharHlp.RemoveSpell(p, C_SPELL.KNOCK);
    Explore.OpenBarrierAhead;
    PartyCastsKnock := True;
  end else
    PartyCastsKnock := False;
end;

{ MoveForward: clear C_GBVM.LEAVE_MAP, then, unless the barrier ahead is type 0, compute the next square without moving
  there. A step off the 16x16 map puts gMapX/gMapY on that edge and sets C_GBVM.LEAVE_MAP to 1. }
procedure MoveForward;
var
  nx: Integer;
  ny: Integer;
  f: Integer;
begin
  nx := GDVars.gMapX;
  ny := GDVars.gMapY;
  f := GDVars.gFacing;
  GDVars.zone1^[C_GBVM.LEAVE_MAP] := 0;
  if View3D.GetBarrierType(nx, ny, f) <> 0 then begin
    Inc(nx, GDConsts.dirDX[f]);
    Inc(ny, GDConsts.dirDY[f]);
    if nx > 15 then begin
      GDVars.gMapX := 15;
      GDVars.zone1^[C_GBVM.LEAVE_MAP] := 1;
    end;
    if nx < 0 then begin
      GDVars.gMapX := 0;
      GDVars.zone1^[C_GBVM.LEAVE_MAP] := 1;
    end;
    if ny > 15 then begin
      GDVars.gMapY := 15;
      GDVars.zone1^[C_GBVM.LEAVE_MAP] := 1;
    end;
    if ny < 0 then begin
      GDVars.gMapY := 0;
      GDVars.zone1^[C_GBVM.LEAVE_MAP] := 1;
    end;
  end;
end;

{ MovePartyForward3D: play the step sound, step with 16x16 edge wrap, refresh wallAhead and eventAtCell, reset the door
  flags and advance the clock one minute, or one turn when Search (C_GBVM.SEARCH_FLAGS bit 0) is on. EclVm.GameLoop
  plays the step sound again once the party has moved, as SSI's code does; a driver that sets singleStep (the Sound
  Blaster's) gets GameLoop's alone (POR-0170). }
procedure MovePartyForward3D;
begin
  if not GDVars.sound.singleStep then
    SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
  Inc(GDVars.gMapX, GDConsts.dirDX[GDVars.gFacing]);
  Inc(GDVars.gMapY, GDConsts.dirDY[GDVars.gFacing]);
  View3D.WrapCoords(GDVars.gMapX, GDVars.gMapY);
  GDVars.wallAhead := View3D.GetWallType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  GDVars.eventAtCell := View3D.GetMapEvent(GDVars.gMapX, GDVars.gMapY);
  if GDVars.zone1^[C_GBVM.SEARCH_FLAGS] and 1 > 0 then
    FxEngine.AdvanceTime(1, C_TIME.TURNS)
  else
    FxEngine.AdvanceTime(1, C_TIME.MINUTES);
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
        FxEngine.AdvanceTime(12, C_TIME.HOURS);
      end;
  else begin
    GDVars.zone0^.partyX.value := nx;
    GDVars.zone0^.partyY.value := ny;
    FxEngine.AdvanceTime(12, C_TIME.HOURS);
  end;
  end;
end;

{ F8 on the map menu: when the quick-save slot holds a game, set quickLoadAsked and return True, ending the menu so
  GameLoop can return and the program load it; otherwise say there is none and return False. }
function AskQuickLoad: Boolean;
begin
  AskQuickLoad := SaveLoad.QuickLoadable;
  if SaveLoad.QuickLoadable then
    quickLoadAsked := True
  else begin
    TextRend.DisplayAndPause(Yellow, 'There is no quick save.');
    TextRend.ClearBottomLine;
  end;
end;

{ MapMainMenu: the 3D / wilderness command loop. Returns the key that ended it: 'E' (Encamp), 'L' (Look: sets
  C_GBVM.SEARCH_FLAGS bit 1, advances the clock one turn and points eclIp at the search script entry), an arrow scan
  code (in 3D 'H' after MoveForward, in the wilderness 'H', 'M', 'P' or 'K' after setting the facing), or F8's after
  AskQuickLoad has set quickLoadAsked. F5 quick-saves (SaveLoad.QuickSave) and the menu goes on. }
function MapMainMenu: Char;
var
  done: Boolean;
  c: Char;
  ext: Boolean;
  viewDone: Boolean;
begin
  GDVars.zone1^[C_GBVM.MOVE_LOCKED] := 0;
  case GDVars.gLocType of
    C_AREA.LOC_3D_MAP: begin
         done := False;
         repeat
           MenuCore.arrowsToCaller := True;
           MenuCore.quickKeysToCaller := True;
           c := MenuCore.MenuHorizontal('', GDConsts.menu3D, LightMagenta, LightGreen, White, True, False,
                                        ext);
           if not ext then begin
             case c of
               { STING maps anywhere, as Curse's debug mode does }
               'A': if (GDVars.zone0^.noAutomap = 0) or GDVars.stingArg then begin
                      GDVars.automapOn := GDVars.automapOn = False;
                      View3D.Display3DMapView(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                    end else
                      TextRend.PrintAndPause('Not Here', Yellow);
               'C': if GDVars.curChar^.status = C_STATUS.OKAY then Camp.NoncombatCastMenu;
               'V': ViewChar.ViewCharMenu(viewDone);
               'J': JrnlView.JournalMenu;
               'E': done := True;
               'S': GDVars.zone1^[C_GBVM.SEARCH_FLAGS] := GDVars.zone1^[C_GBVM.SEARCH_FLAGS] xor 1;
               'L': begin
                      GDVars.zone1^[C_GBVM.SEARCH_FLAGS] := GDVars.zone1^[C_GBVM.SEARCH_FLAGS] or 2;
                      FxEngine.AdvanceTime(1, C_TIME.TURNS);
                      GDVars.eclIp := GDVars.scriptEntryAddrs[C_ECL.ENTRY_SEARCH];
                      done := True;
                    end;
             end;
           end else begin
             case c of
               { up arrow: step forward }
               C_KEYS.UP: begin
                         Explore.MoveForward;
                         done := True;
                       end;
               { down arrow: turn around }
               C_KEYS.DOWN: begin
                           GDVars.gFacing := (GDVars.gFacing + 4) mod 8;
                           GDVars.wallAhead := View3D.GetWallType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                           View3D.Display3DMapView(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                         end;
               { left arrow: turn left }
               C_KEYS.LEFT: begin
                           GDVars.gFacing := (GDVars.gFacing + 6) mod 8;
                           SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
                           GDVars.wallAhead := View3D.GetWallType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                           View3D.Display3DMapView(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                         end;
               { right arrow: turn right }
               C_KEYS.RIGHT: begin
                            GDVars.gFacing := (GDVars.gFacing + 2) mod 8;
                            SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
                            GDVars.wallAhead := View3D.GetWallType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                            View3D.Display3DMapView(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
                          end;
               C_KEYS.F5: SaveLoad.QuickSave;
               C_KEYS.F8: done := Explore.AskQuickLoad;
               { the Companion Tools, while the setting is on (phase 8) }
               C_KEYS.F6: if GDVars.companionOn <> 0 then begin
                            CompTool.ToolsMenu;
                            CharDisp.DisplayNoncombatInterface;
                          end;
             else begin
               Party.SelectPrevNextChar(c);
               CharDisp.DisplayParty(GDVars.curChar);
             end;
             end;
           end;
           CharDisp.PrintMiscInfo;
         until done;
       end;
    C_AREA.LOC_WILD_WEST..C_AREA.LOC_WILD_EAST: begin
        if GDVars.locTypePrev < C_AREA.LOC_WILD_WEST then begin
          MapTiles.LoadIconAnim('ICON', 0, 9);
          MapTiles.LoadIconAnim('ICON', 1, 10);
          MapTiles.LoadIconAnim('ICON', 2, 11);
          CharDisp.DisplayWildernessInterface;
        end;
        done := False;
        repeat
          MenuCore.arrowsToCaller := True;
          MenuCore.quickKeysToCaller := True;
          c := MenuCore.MenuHorizontal('', GDConsts.menuWild, LightMagenta, LightGreen, White, True, False,
                                       ext);
          if not ext then begin
            case c of
              'C': Camp.NoncombatCastMenu;
              'V': ViewChar.ViewCharMenu(viewDone);
              'J': JrnlView.JournalMenu;
              'E': done := True;
              'S': GDVars.zone1^[C_GBVM.SEARCH_FLAGS] := GDVars.zone1^[C_GBVM.SEARCH_FLAGS] xor 1;
              'L': begin
                     GDVars.zone1^[C_GBVM.SEARCH_FLAGS] := GDVars.zone1^[C_GBVM.SEARCH_FLAGS] or 2;
                     FxEngine.AdvanceTime(1, C_TIME.TURNS);
                     GDVars.eclIp := GDVars.scriptEntryAddrs[C_ECL.ENTRY_SEARCH];
                     done := True;
                   end;
            end;
          end else begin
            done := True;
            case c of
              { up arrow }
              C_KEYS.UP: GDVars.gFacing := C_DIR.NORTH;
              { right arrow }
              C_KEYS.RIGHT: GDVars.gFacing := C_DIR.EAST;
              { down arrow }
              C_KEYS.DOWN: GDVars.gFacing := C_DIR.SOUTH;
              { left arrow }
              C_KEYS.LEFT: GDVars.gFacing := C_DIR.WEST;
              C_KEYS.F5: begin
                           SaveLoad.QuickSave;
                           done := False;
                         end;
              C_KEYS.F8: done := Explore.AskQuickLoad;
              C_KEYS.F6: begin
                           if GDVars.companionOn <> 0 then begin
                             CompTool.ToolsMenu;
                             CharDisp.DisplayWildernessInterface;
                           end;
                           done := False;
                         end;
            else begin
              Party.SelectPrevNextChar(c);
              CharDisp.DisplayParty(GDVars.curChar);
              done := False;
            end;
            end;
          end;
          CharDisp.PrintMiscInfo;
        until done;
      end;
  end;
  GDVars.locTypePrev := GDVars.gLocType;
  if GDVars.bottomMsgCleared = 0 then begin
    Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
    GDVars.bottomMsgCleared := 1;
  end;
  MapMainMenu := c;
end;

{ ResolveMovement: while C_GBVM.MOVE_LOCKED is 255 movement is refused and the flag is reset to 0 instead. On a 3D map
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
    C_AREA.LOC_3D_MAP: if GDVars.zone1^[C_GBVM.MOVE_LOCKED] < 255 then begin
         case View3D.GetBarrierType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing) of
           1: moved := True;
           2: begin
                menuStr[0] := #0;
                if GDVars.doorOpen[0] <> 0 then
                  menuStr := 'Bash';
                if (GDVars.doorOpen[1] <> 0) and Explore.PartyHasClass(C_Level.THIEF) then
                  menuStr := menuStr + ' Pick';
                if (GDVars.doorOpen[2] <> 0) and (Explore.FindCharWithSpell(C_SPELL.KNOCK) <> nil)
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
                if (GDVars.doorOpen[1] <> 0) and Explore.PartyHasClass(C_Level.THIEF) then
                  menuStr := menuStr + ' Pick';
                if (GDVars.doorOpen[2] <> 0) and Explore.PartyHasClass(C_Level.MAGE) then
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
         CharDisp.PrintMiscInfo;
       end else
         GDVars.zone1^[C_GBVM.MOVE_LOCKED] := 0;
    C_AREA.LOC_WILD_WEST..C_AREA.LOC_WILD_EAST: if GDVars.zone1^[C_GBVM.MOVE_LOCKED] < 255 then begin
            Explore.MovePartyWilderness;
            CharDisp.PrintMiscInfo;
          end else
            GDVars.zone1^[C_GBVM.MOVE_LOCKED] := 0;
  end;
  Portrait.FreeAnimation(GDVars.animData);
  Blit.FreePic(GDVars.portraitCache[1].pic);
  Blit.FreePic(GDVars.portraitCache[2].pic);
  GDVars.portraitCache[1].pictureId := 255;
  GDVars.portraitCache[2].pictureId := 255;
end;

begin
  quickLoadAsked := False;
end.
