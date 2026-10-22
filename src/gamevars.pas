{ Global variables: every variable in the data segment, in link order. A new section starts wherever the data needs a
  word boundary. }
{$I COMPILER.INC}
unit GameVars;

interface

uses Types, Dos, C_EFFECT, C_GBVM, C_SPELL{$IFDEF FPC}, Host{$ENDIF};

var
  { The video driver GameBoot installed for the video mode (Types.TVideoDriver). }
  video: Types.TVideoDriver;
  { the sound driver GameBoot installed }
  sound: Types.TSoundDriver;
  { Timed effects. }
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
  { Interface state, one of the IFC_ constants of C_IFC and Ending }
  ifcState: Byte;
  { nonzero suppresses Combat's Continue Battle prompt }
  suppressContinuePrompt: Byte;
  { zero disables ViewChar's disk-3 portrait branch }
  portraitsOn: Byte;
  { zero skips the close-up load when inEncMenu is nonzero }
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
  { the Companion Tools setting: nonzero lets F6 open the Tools screen outside combat (phase 8) }
  companionOn: Byte;
  { GameInit clears it; GameIo toggles it on STING Ctrl-D; nonzero enables PrintHpDebug }
  stingHpFlag: Byte;
  { Started as START STING: the debug keys and cheats are on. GameBoot sets it before anything reads a key. }
  stingArg: Boolean;
  { STING Ctrl-L (#612): the script trace log is open; each opcode's mnemonic goes to debugFile (debug.txt), and Ctrl-Z
    writes the creatures' effects there }
  debugTraceEnabled: Boolean;
  { overlay loads since the program started, counted by GameBoot's OvrReadBuf hook (#612) }
  ovrLoads: LongInt;
  { the overlays load from EMS (GameBoot's OvrInitEMS succeeded) rather than from GAME.OVR on disk }
  ovrInEms: Boolean;
  { set when GameIo has written over the bottom line (the STING Ctrl-Y pop-up); MenuCore.HorizontalMenu redraws its
    menu line and clears it }
  bottomLineTaken: Boolean;
  { main-menu load handoff; EclVm skips reload, EclMenu clears it }
  loadedSave: Byte;
  { Party location type, previous (as below) }
  locTypePrev: Byte;
  { Party location type, current }
  gLocType: Byte;
  partyDefeated: Boolean;
  { Delay in printing message to message window }
  msgDelayFlag: Byte;

var
  { Video registers, pages and modes; view and icon buffers, dirty spans and row tables }
  { Register record handed to Dos.Intr (Host.Intr natively) for BIOS video calls; every unit calling the BIOS uses this
    one record. }
  interruptRegisters: Registers;
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
  viewImageBufferPtr: Types.PImgBuf;
  { Backdrop buffer that Blit.BlitTileClipped fills with the destination bytes it is about to cover (when the save flag
    is set), so CharHlp can restore the background afterwards. }
  iconImageBufferPtr: Types.PImgBuf;
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

var
  { Sound mode }
  { Active sound device; GameBoot maps POOL.CFG line 2: 'T' = 0, 'P' = 1, else 2. }
  soundMode: Byte;
  { Disks, directories and the DAX buffer }
  { current resource disk; saved by SaveLoad }
  virtualDisk: Byte;
  { Save directory from line 4 of POOL.CFG. }
  saveDirectory: String[255];
  { POOL.CFG line 3, the game directory; gameDir[1] is its drive letter }
  gameDir: String;
  { Flag for suppressing insert disk prompt }
  suppressingInsertDiskFlag: Boolean;
  { Set by SaveLoad once a save completes; HeapErr and the Exit to DOS loop use it to tell whether a save succeeded. }
  recentSaved: Byte;
  { ITEMS catalogue }
  { Party pointers }
  { Current creature. }
  curChar: Types.PCharRecord;
  { Pointer to linked list of creatures }
  creatureList: Types.PCharRecord;
  { The current character before a script step, LOAD CHARACTER or a script switch; the scripts' EXIT and PROGRAM and
    EclVm.NewEclDone make it current again. SaveLoad.RemoveCreature moves it off the record it frees. }
  savedChar: Types.PCharRecord;
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
  symbolSetPtrs: array[0..4] of Types.PImgBuf;
  { Pointer to current 8x8 symbol image buffer }
  current8x8SymbolPtr2: Types.PImgBuf;
  { 2D map tile set image buffer 1 }
  mapTilePtr: Types.PImgBuf;
  { Icon images }
  { Animation images for creature, death and cursor icons. }
  iconAnimation: array[0..25, 0..1] of Types.PImgBuf;
  { Combat arena }
  { next registration slot, inclusive scan limit }
  arenaCount: Byte;
  { icon location and size per slot }
  arenaLoc: array[1..Types.ARENA_SLOTS] of Types.TArenaLoc;
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
  { effect ID, cleared when immune }
  pendingEffectId: Byte;
  { damage before hit-point subtraction }
  pendingDamage: Byte;
  { C_EFFECT.ELEM_*: 1 fire, 2 cold, 4 electricity, 8 magic, 16 acid }
  elementMask: Byte;
  { current attack *or* current movement times 2 }
  currentAttackCurrent: Byte;
  { spell being cast }
  currentSpellBeing: Byte;
  { dice count of the current damage roll; Burning Hands, which rolls none, sets it to 1. The fire protections and the
    mummy's fire vulnerability work per die. }
  gDamageDice: Byte;
  { 1 while calculating movement }
  currentCreatureCalculatingFlag: Byte;
  { Effect lock. }
  effectLock: Byte;
  { the spell affects multiple targets }
  gMultiTarget: Byte;
  { redraw the inventory menu }
  redrawInventoryMenuFlag: Byte;
  { the attack roll as effects modify it; signed, as penalties can take it below 0 }
  gAttackRoll: ShortInt;
  { an effect (Blink, Displacement, an avoided missile) forced the attack to miss }
  gAttackAvoided: Boolean;
  { current morale }
  currentMorale: Byte;
  { creature this one is interacting with }
  otherCreatureCurrentPtr: Types.PCharRecord;

var
  { Effect dispatch }
  { effect handlers, indexed by effect id }
  effectFns: array[C_EFFECT.BLESS..C_EFFECT.RECENT_CURE] of Types.TEffectHandler;
  { 3D view }
  { four 256-byte GEO planes; View3D/Explore views }
  map3d: Types.PGeoMap;
  { View3D band colors; MapView recomputes them from the ECL color selectors after a script changes them (picRegionW) }
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
  wallSetCache: array[1..3] of Types.TWallSetCacheSlot;
  { the picture animation showing (PIC or SPRIT) }
  animData: Types.TAnimRec;
  { HEAD and BODY image caches. }
  portraitCache: array[1..2] of Types.TPortSlot;
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
  spellFns: array[1..C_SPELL.TABLE_LAST] of Types.TSpellProc;
  { Number of targeted creatures }
  spellTargetCount: Byte;
  { Selected target creatures. }
  targetCreaturePtr: array[1..Types.ARENA_SLOTS] of Types.PCharRecord;
  { Remembered noncombat spell target, initially the caster. }
  castTarget: Types.PCharRecord;
  { Pointer to linked list of Stinking Clouds }
  stinkHead: Types.PStinkRec;
  usingItem: Boolean;

var
  { Rest and healing }
  { Suppress the window border. }
  suppressDrawingBorderFlag: Byte;

var
  { Wilderness animation }
  { Party icon frame, 0..5: parity selects the icon frame, div 2 the icon animation. }
  wildAnimFrame: Byte;

var
  { Combat round }
  { Combat round counter, 0-indexed }
  roundCounter: Byte;
  { Potential-target creature indices. }
  potentialTargetCreature: array[1..Types.ARENA_SLOTS] of Byte;
  { quick combat magic; toggled by Alt-M }
  quickMagic: Boolean;
  { The combat moving-icon sheet: CombatSt allocates it, CharHlp copies icon facings in and draws from it, Combat frees
    it }
  moveIconSheet: Types.PImgBuf;
  { ECL color selectors }
  { Script-controlled wall color; script writes request a view redraw. }
  wallColorSel: Byte;
  { Script-controlled ceiling and floor color; writes request a view redraw. }
  ceilFloorColorSel: Byte;
  { ECL interpreter }
  { Top ECL return-stack node. }
  eclStackTopPtr: Types.PEclRet;
  { Previous ECL return-stack node. }
  eclStackSecondPtr: Types.PEclRet;
  { Current ECL opcode }
  curOpcode: Byte;
  { ECL variables and strings }
  { Decoded ECL variable types. }
  gbvmType: array[1..64] of Byte;
  { High bytes of decoded ECL variables. }
  gbvmUpperByte: array[1..64] of Byte;
  { Low bytes of decoded ECL variables. }
  gbvmLowerByte: array[1..64] of Byte;
  { Receives the aim result for the bronze-dragon breath attack. }
  breathAim: Boolean;
  { Script string buffers, on the heap; GameInit2 allocates and clears them. }
  gbStrings: Types.PGbStrings;
  { ECL monster and post-combat state }
  { With dumpCr6B00, ECL LOAD CHARACTER with bit 7 removes the creature; set when a script writes 0 to
    C_GBVM.CHAR_ENABLED (EclVars.SpecialWriteZ1) }
  dumpCr6C00: Boolean;
  { With dumpCr6C00, ECL LOAD CHARACTER with bit 7 removes the creature; set when a script writes 0 to C_GBVM.CHAR_DUMP
    (EclVars.SpecialWriteZ1) }
  dumpCr6B00: Boolean;
  duelFlag: Boolean;

var
  { ECL flags }
  { ECL script ID }
  eclScriptId: Byte;
  { Backup of the search-mode bit (C_GBVM.SEARCH_FLAGS bit 0) }
  searchModeFlag: Byte;
  { ECL 3D CLEAR BOX executed flag }
  ecl3dClearFlag: Byte;
  protNewLine: Byte;
  { ECL currently displaying graphics flag }
  eclGraphics: Boolean;
  { ECL displaying monster sprite flag }
  sprShown: Boolean;
  { Set when a script changes a view color selector; MapView then applies them }
  picRegionW: Boolean;
  { Currently in ECL opcode 29 ENCOUNTER MENU flag. It stays the last variable: the initialization clears from video
    through it. }
  inEncMenu: Byte;

implementation

{ Every variable here starts at zero, as the game and the tests take them to. Turbo Pascal clears no variable: each
  starts with whatever its memory held, which another program run before may have dirtied (#826). Its variables lie in
  one block in the order declared, video first and inEncMenu last, so one FillChar clears them all. Free Pascal clears
  its variables itself. }
begin
{$IFNDEF FPC}
  FillChar(video, Ofs(inEncMenu) - Ofs(video) + SizeOf(inEncMenu), 0);
{$ENDIF}
end.
