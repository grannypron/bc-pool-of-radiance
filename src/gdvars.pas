{ Global variables: every variable in the data segment, in link order. A new section starts wherever the data needs a
  word boundary. }
unit GDVars;

interface

uses Types, Dos, C_Effect, C_Gbvm;
  
var
  { The video driver GameBoot installed for the video mode (Types.TVideoDriver). }
  video: Types.TVideoDriver;
  { Timed effects. }
  { Creatures whose timed effects need processing, by list ordinal. }
  effFlags: array[1..Types.ARENA_SLOTS] of Byte;
  { Play session }
  { GameBoot writes 0/1, Intro tests zero }
  fullIntro: Boolean;
  { word bank }
  zone0: Types.PZone0State;
  { GBVM zone 1, indexed directly by GBVM address (the zone-1 GBVM_ constants) }
  { word bank }
  zone1: Types.PZone1;
  { word bank }
  zone2: Types.PZone2;
  { script bytes }
  zone3: Types.PZone3;
  { game speed, 0 = fastest 9 = slowest; a setting in POOLOPT.CFG, and SaveLoad writes it to the GBVM gameSpeed word }
  gameDelay: Byte;
  { Five GBVM addresses loaded from the ECL entry header. [1] runs before movement and after on-load; [2] search/Look;
    [3] pre-camp; [4] camp interruption; [5] on-load }
  { ECL entry GBVM addresses }
  scriptEntryAddrs: array[1..5] of Word;
  { ECL instruction pointer into zone3 }
  eclIp: Word;
  { Interface state, one of the IFC_ constants of C_Ifc and Ending }
  ifcState: Byte;
  { nonzero suppresses Combat's Continue Battle prompt }
  suppressContinuePrompt: Byte;
  { zero disables ViewChar's disk-3 portrait branch }
  portraitsOn: Byte;
  { zero skips the close-up load when GameDat5.inEncMenu is nonzero }
  monsterPics: Byte;
  { zero makes SoundDrv.PlayMusic do nothing }
  musicOn: Byte;
  { the Sound setting: zero starts the game with sound off (soundMode disabled); GameIo.SetSound keeps it in step }
  soundOn: Byte;
  { nonzero: PostCbt and SaveLoad.LoadChar take the party's characters off Quick after each fight and on loading }
  quickEnds: Byte;
  { the Quick Mode Magic setting: CombatSt starts every fight with quickMagic set from it; Alt-M then turns quickMagic
    over for that fight only }
  quickMagicOn: Byte;
  { GameInit clears it; GameIo toggles it on STING Ctrl-D; nonzero enables PrintHpDebug }
  stingHpFlag: Byte;
  { Started as START STING: the debug keys and cheats are on. GameBoot sets it before anything reads a key. }
  stingArg: Boolean;
  { STING Ctrl-L (#612): the script trace log is open; each opcode's mnemonic goes to debugFile (debug.txt), and Ctrl-Z
    writes the creatures' effects there }
  debugTraceEnabled: Boolean;
  debugFile: Text;
  { overlay loads since the program started, counted by GameBoot's OvrReadBuf hook (#612) }
  ovrLoads: LongInt;
  { heap bytes held by pictures (Blit.AllocPic less FreePic), and the most they have reached; STING Ctrl-Y shows them }
  picBytes: LongInt;
  picPeak: LongInt;
  { set when GameIo has written over the bottom line (the STING Ctrl-Y pop-up); MenuCore.HorizontalMenu redraws its
    menu line and clears it }
  bottomLineTaken: Boolean;
  { main-menu load handoff; EclVm skips reload, EclMenu clears it }
  loadedSave: Byte;
  { Party location type, previous (as below) }
  locTypePrev: Byte;
  { Party location type, current }
  gLocType: Byte;
  { Uninterrupted resting time when disturbable }
  restTicks: Word;
  { Portrait head ID. }
  dsCurrentPortraitHead: Byte;
  { Portrait body ID. }
  dsCurrentPortraitHead2: Byte;
  partyDefeated: Boolean;
  { Delay in printing message to message window }
  msgDelayFlag: Byte;

var
  { Video registers, pages and modes; view and icon buffers, dirty spans and row tables }
  { Register record handed to Dos.Intr for BIOS video calls; every unit calling the BIOS uses this one record. }
  dsInterruptRegisters: Registers;
  { Other EGA page number (always 0) }
  pageNum: Byte;
  { Currently displayed EGA page number (always 0) }
  pageMain: Byte;
  { BIOS mode queried at init, then the mode active before the latest Blit.SetVideoMode call; RestoreVideoMode returns
    to it. }
  savedVideoMode: Byte;
  { BIOS mode queried at init, then the mode most recently requested through Blit.SetVideoMode. }
  curVideoMode: Byte;

var
  { Off-screen 168x168 view buffer that the compositors draw into and Blit.FlushView copies to the screen; GameInit
    allocates it. }
  dsViewImageBufferPtr: Types.PImgBuf;
  { Backdrop buffer that Blit.BlitTileClipped fills with the destination bytes it is about to cover (when the save flag
    is set), so CharHlp can restore the background afterwards. }
  dsIconImageBufferPtr: Types.PImgBuf;
  { Dirty-span tables, one slot per view scanline (21 character rows x 8 = 168); GameInit initializes all four. }
  { Nonzero when that view scanline holds changes that Blit.FlushView still has to copy to the screen. }
  spanActive: array[0..167] of Byte;
  { Horizontal byte offset in video memory where the dirty span begins; the screen-side counterpart of spanFirstOfs. }
  spanScreenOfs: array[0..167] of Word;
  { Offset of the first dirty byte in the view buffer's image data. Reset to $FFFF when clean so any new span compares
    as earlier. }
  spanFirstOfs: array[0..167] of Word;
  { Offset of the last dirty byte (inclusive) in the view buffer's image data. Reset to 0 when clean so any new span
    compares as later. }
  spanLastOfs: array[0..167] of Word;
  { Video segment for each CGA scanline, precomputed so row writes need no bank arithmetic: even and odd rows interleave
    between the B800 and BA00 banks. }
  cgaRowSeg: array[0..199] of Word;
  { Offset into the EGA video segment for each scanline; rows are 40 bytes apart. }
  fbRowOfs: array[0..199] of Word;
  { Video segment for each Tandy scanline, precomputed like cgaRowSeg. }
  tandyRowSeg: array[0..199] of Word;
  { Nonzero makes Blit.BlitTileClipped clip against the destination bounds; zero trusts the caller to have kept the tile
    inside. GameInit initializes it to 1. }
  clipFlag: Byte;

var
  { Sound mode }
  { Active sound device; GameBoot maps POOL.CFG line 2: 'T' = 0, 'P' = 1, else 2. }
  soundMode: Byte;
  { Copy of soundMode taken at suspend so the configured mode is not lost. }
  soundSaved: Byte;
  { Nonzero: SoundDrv.SoundCommand waits a fixed delay after each command, then silences the voices and removes its
    timer. Zero leaves the timer driver resident for persistent playback. }
  soundAutoStop: Word;
  { Disks, directories and the DAX buffer }
  { current resource disk; saved by SaveLoad }
  virtualDisk: Byte;
  { disk saved by DaxIo.PushState for PopState }
  prevVirtualDisk: Byte;
  { Save directory from line 4 of POOL.CFG. }
  dsSaveDirectory: String[255];
  { POOL.CFG line 3, the game directory; gameDir[1] is its drive letter }
  gameDir: String;
  { Flag for suppressing insert disk prompt }
  dsSuppressingInsertDiskFlag: Boolean;
  { Set by SaveLoad once a save completes; HeapErr and the Exit to DOS loop use it to tell whether a save succeeded. }
  recentSaved: Byte;
  { ITEMS catalogue }
  { Base item types, indexed by TItemRec.itemType, on the heap; GameInit2 allocates and clears them before reading
    ITEMS. The last entry, Types.BASE_ITEM_OVERFLOW, stays zero: it keeps the ITEMS read's request for 129 records in
    bounds (the shipped ITEMS holds 128), and CharHlp.BaseItem gives it for an item type past the table. }
  baseItems: Types.PBaseItems;
  { Party pointers }
  { Current creature. }
  curChar: Types.PCharRecord;
  { Pointer to linked list of creatures }
  creatureList: Types.PCharRecord;
  { last missile item added to the treasure list in combat }
  lastMissileItem: Types.PItemRec;
  { Font and text cursor }
  { Pointer to font. Each entry in the font table is 8 bytes }
  gameFont: Types.PFontArr;
  { Text cursor shared by TextRend's message window and slow-text output }
  { Current char column. (Equivalent of WhereX.) }
  curCol: Byte;
  { Current char row. (Equivalent of WhereY.) }
  curRow: Byte;
  { Symbol sets and map tile sets }
  { the five 8x8 symbol-set images, by set id 0..4: Sym8x8.Load8x8Set loads an 8X8D picture into a slot and Put8x8Sym
    draws from it }
  dsSymbolSetPtrs: array[0..4] of Types.PImgBuf;
  { Pointer to current 8x8 symbol image buffer }
  dsCurrent8x8SymbolPtr2: Types.PImgBuf;
  { 2D map tile set image buffer 1 }
  ds2dMapTilePtr: Types.PImgBuf;
  { 2D map tile set image buffer 2; bit 7 of a tile id selects it }
  ds2dMapTilePtr2: Types.PImgBuf;
  { Icon images }
  { Animation images for creature, death and cursor icons. }
  dsIconAnimation: array[0..25, 0..1] of Types.PImgBuf;
  { Combat arena }
  { next registration slot, inclusive scan limit }
  arenaCount: Byte;
  { icon location and size per slot }
  arenaLoc: array[1..Types.ARENA_SLOTS] of Types.TArenaLoc;
  { view-relative X deltas }
  gridX: array[1..Types.ARENA_SLOTS] of ShortInt;
  { view-relative Y deltas }
  gridY: array[1..Types.ARENA_SLOTS] of ShortInt;
  { creature per slot }
  creatureArr: array[1..Types.ARENA_SLOTS] of Types.PCharRecord;
  { corpses on the arena }
  downed: array[1..8] of Types.TDownedRec;
  { append and scan limit; cleared entries leave holes }
  downedCount: Byte;
  { allocated combat viewport, borrowed by renderers }
  arenaPtr: Types.PArena;
  { Pathing's potential-target count }
  targetCount: Byte;
  { sorted by distance and facing }
  targetList: Types.TTargetList;

var
  { Treasure }
  { copper through jewelry }
  treasureMoney: Types.TMoney;
  { consumers use PItemRec views }
  treasureItems: Types.PItemRec;
  { Combatants per side }
  { combat ends when a side is empty }
  teamCount: array[0..1] of Byte;
  { Effect resolution }
  { modified saving-throw roll; signed, so a penalty can take it below 0 }
  gSaveRoll: Integer;
  { effect ID, cleared when immune }
  pendingEffectId: Byte;
  { damage before hit-point subtraction }
  pendingDamage: Byte;
  { C_Effect.ELEM_*: 1 fire, 2 cold, 4 electricity, 8 magic, 16 acid }
  elementMask: Byte;
  { current attack *or* current movement times 2 }
  dsCurrentAttackCurrent: Byte;
  { spell being cast }
  dsCurrentSpellBeing: Byte;
  { dice count of the current damage roll }
  gDamageDice: Byte;
  { 1 while calculating movement }
  dsCurrentCreatureCalculatingFlag: Byte;
  { suppress targeting }
  dsCurrentSuppressTargetingFlag: Byte;
  { Effect lock. }
  effectLock: Byte;
  { the spell affects multiple targets }
  gMultiTarget: Byte;
  { redraw the inventory menu }
  dsRedrawInventoryMenuFlag: Byte;
  { signed -- EffHndlr assigns -1, FxEngine guards >= 0 }
  gAttackRoll: ShortInt;
  hitsMade: array[1..2] of Byte;
  { current morale }
  dsCurrentMorale: Byte;
  { creature this one is interacting with }
  dsOtherCreatureCurrentPtr: Types.PCharRecord;
  { saving throw type, 0..4 }
  gSaveType: Byte;

var
  { Effect dispatch }
  { effect handlers, indexed by effect id }
  effectFns: array[C_Effect.BLESS..C_Effect.RECENT_CURE] of Types.TEffectHandler;
  { 3D view }
  { the wall types' symbol slices, by wall type 1..15 (View3D.LoadWallSet fills a slot's five) }
  wallGfx: Types.PWallSlices;
  { four 256-byte GEO planes; View3D/Explore views }
  map3d: Types.PGeoMap;
  { Sky and ceiling color after palette mapping. }
  dsColorSkyCeiling: Byte;
  { View3D band colors; MapView recomputes them from the ECL color selectors after a script changes them
    (GameDat5.picRegionW) }
  { 3D-view color register A (ceiling/horizon band) }
  dsWallColorA: Byte;
  { 3D-view color register B (mid band) }
  dsWallColorB: Byte;
  { 3D-view color register C (floor/wall band) }
  dsWallColorC: Byte;
  { Map position, wall cache, animation and portrait cache }
  { automap shown in place of the 3D view }
  automapOn: Boolean;
  { Current map column; signed for edge and wrap checks. }
  gMapX: ShortInt;
  { Current map row. }
  gMapY: ShortInt;
  { Current party facing direction. }
  gFacing: Byte;
  { Wall at the current square in the facing direction. }
  wallAhead: Byte;
  { Event byte at the party's square; bit 7 is a flag, not a wall }
  eventAtCell: Byte;
  dsWallSetCache: array[1..3] of Types.TWallSetCacheSlot;
  { the picture animation showing (PIC or SPRIT) }
  animData: Types.TAnimRec;
  { HEAD and BODY image caches. }
  dsPortraitCache: array[1..2] of Types.TPortSlot;
  { Picture archive and menu state }
  { Archive of the cached picture: name and virtual-disk digit, as LoadAnimation opens it. }
  picArcName: String[8];
  { picture id loaded from picArcName; 255 invalidates the pair }
  picArcId: Byte;
  { Zero-based position of the first visible list entry. }
  vertTop: Integer;
  { Current horizontal menu choice, starting at 1. }
  horizChoice: Byte;

var
  { Spell casting and targeting }
  { the cast-target menu: Magic.NoncombatCastTargetMenu, or CbtActs.CombatCastTargetMenu in combat }
  castTargetMenu: Types.TCastUI;
  { Spell handlers indexed by spell ID. }
  spellFns: array[1..67] of Types.TSpellProc;
  { Number of targeted creatures }
  spellTargetCount: Byte;
  { Selected target creatures. }
  dsTargetCreaturePtr: array[1..Types.ARENA_SLOTS] of Types.PCharRecord;
  { Remembered noncombat spell target, initially the caster. }
  castTarget: Types.PCharRecord;
  { combat arena column, 0..49 }
  gTargetX: ShortInt;
  { combat arena row, 0..24 }
  gTargetY: ShortInt;
  { Pointer to linked list of Stinking Clouds }
  stinkHead: Types.PStinkRec;
  usingItem: Boolean;

var
  { Rest and healing }
  { Remaining rest time as a seven-word GBVM clock; TClock-typed so it passes to Clock.ValidateClock as a var
    parameter }
  dsRestingTimeGbvm: Types.TClock;
  { Time rested today, in five-minute ticks. }
  healTicks: Word;
  { Suppress the window border. }
  dsSuppressDrawingBorderFlag: Byte;

var
  { Wilderness animation }
  { Party icon frame, 0..5: parity selects the icon frame, div 2 the icon animation. }
  dsWildAnimFrame: Byte;

var
  { Door-opening flags }
  { Door-opening flags: bash, pick and knock. }
  doorOpen: array[0..2] of Byte;

var
  { Combat round }
  { Combat round counter, 0-indexed }
  roundCounter: Byte;
  { Potential-target creature indices. }
  dsPotentialTargetCreature: array[1..Types.ARENA_SLOTS] of Byte;
  { Hostile creatures' hit points, percent remaining }
  hostileHpPct: Byte;
  { quick combat magic; toggled by Alt-M }
  quickMagic: Boolean;
  { Done flag for the acting creature's attacks; combat menus also return their extended-key flag here }
  doneRoundFlag: Boolean;
  { The combat moving-icon sheet: CombatSt allocates it, CharHlp copies icon facings in and draws from it, Combat frees
    it }
  dsMoveIconSheet: Types.PImgBuf;
  { ECL colour selectors }
  { Script-controlled wall color; script writes request a view redraw. }
  wallColorSel: Byte;
  { Script-controlled ceiling and floor color; writes request a view redraw. }
  ceilFloorColorSel: Byte;
  { ECL interpreter }
  { Top ECL return-stack node. }
  dsEclStackTopPtr: Types.PEclRet;
  { Previous ECL return-stack node. }
  dsEclStackSecondPtr: Types.PEclRet;
  { eq, ne, lt, gt, le, ge; cleared together by FillChar }
  cmpFlags: array[0..5] of Boolean;
  { Current ECL opcode }
  curOpcode: Byte;
  { Current icon animation slot. }
  gIconAnim: Byte;
  { ECL variables and strings }
  { Decoded ECL variable types. }
  dsGbvmType: array[1..64] of Byte;
  { High bytes of decoded ECL variables. }
  dsGbvmUpperByte: array[1..64] of Byte;
  { Low bytes of decoded ECL variables. }
  dsGbvmLowerByte: array[1..64] of Byte;
  { Receives the aim result for the bronze-dragon breath attack. }
  breathAim: Boolean;
  { Script string buffers, on the heap; GameInit2 allocates and clears them. }
  gbStrings: Types.PGbStrings;
  { ECL monster and post-combat state }
  { Monster display flags used by the ECL VM; EclVm and EclMenu clear both together }
  dsMonsterFlags: Types.TMonFlags;
  { Sound effect selected by a script write (EclVars.WriteGbvm) }
  sndEffect: Word;
  { Dump the creature at ECL LOAD CHARACTER; set when a script writes 0 to its trigger word (EclMenu.SpecialWriteZ1) }
  dumpCr6C00: Boolean;
  { Dump the creature at ECL LOAD CHARACTER; set when a script writes 0 to its trigger word (EclMenu.SpecialWriteZ1) }
  dumpCr6B00: Boolean;
  duelFlag: Boolean;

var
  { ECL flags }
  { ECL script ID }
  eclScriptId: Byte;
  { Backup of the search-mode bit (C_Gbvm.SEARCH_FLAGS bit 0) }
  dsSearchModeFlag: Byte;
  { ECL 3D CLEAR BOX executed flag }
  dsEcl3dClearFlag: Byte;
  protNewLine: Byte;
  { ECL currently displaying graphics flag }
  eclGraphics: Boolean;
  { picture-drawn flag: gates ECL animation }
  picDrawn: Boolean;
  { Set when EclProtection moves its text into the 3D box (after a CLEAR BOX); EclExit then redraws the borders and
    clears it }
  protTextShown: Byte;
  { ECL displaying monster sprite flag }
  sprShown: Boolean;
  { 0 when an ECL script has written a message to the bottom text window; Explore.MapMainMenu clears that window on its
    way out and sets it back to 1 }
  bottomMsgCleared: Byte;
  { Set when a script changes a view colour selector; MapView then applies them }
  picRegionW: Boolean;
  { ECL write moved party flag }
  movedParty: Boolean;
  { Redraw sky/ceiling in 3D view flag }
  redrawSky: Boolean;
  { Currently in ECL opcode 29 ENCOUNTER MENU flag }
  inEncMenu: Byte;

implementation

end.
