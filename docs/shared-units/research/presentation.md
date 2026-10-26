# Shared presentation: screen, input, sound, platform (analysis, 2026-10-26)

Area: TextRend, MenuCore, Border, Sym8x8, Blit and the video drivers, Portrait, MapTiles, MapView, View3D, BldShow,
Intro, the sound drivers, C_KEYS/C_VIDEO/C_SOUND/C_EGA, key handling, PoR's native layer and its settings stack
(CfgFile, TuiKit, POOLCFG, Options). All five ports were read at origin/main (fetched 2026-10-26) from `git archive`
copies in the scratchpad; no checkout was touched.

Method: each unit's implementation was split into top-level routines. Every routine was compared with the same-named
routine in the other games at four levels: verbatim; unit qualifiers stripped (`=q`); literals and `UPPER_CASE`
constants masked (`=d`, identical except for data); identifiers alpha-renamed (`=n`, same code with different names,
which the fleet's "only routine names are unified" ruling makes common). Where none of those match, the best token
similarity is given (0..1). The full per-routine listing, 462 routine families, is in
`/tmp/claude-1000/-home-brian-repos-pool-of-radiance/76f98367-99ca-4028-b60d-7be679625eb9/scratchpad/shared-presentation-routines.txt`
(first game that has the routine is the reference, with its line count). The TASM files were compared by instruction
shape (mnemonic, registers kept, symbols and numbers masked).

Legend for the tables: **I** identical (any of `== =q =d =n`), **D** identical but for data, **B** same logic with
game-specific branches, **X** diverged, **—** absent. Line counts are whole files at origin/main.

## 0. Headline findings

1. **Five different video architectures over one SSI engine.** PoR has a driver record and all-Pascal drivers. Curse
   has PoR's driver record with SSI's TASM blitters plugged into it. CoK has a smaller, different record and a VGA that
   keeps Tandy-layout pictures. Secret and Pools still have a `case` on the mode byte in Blit and TextRend. The
   mode-independent half (spans, picture load, mask, mirror, fills, font loop, message windows, menus) is the same
   code in all five.
2. **One SSI sound sequencer in four games, plus Pools' TSRs.** PoR, Curse, Secret and CoK run the same timer
   sequencer: 236.7 Hz, chaining the BIOS every 13th tick, stream commands 0FAh..0FFh, and byte-identical LFO and
   random tables. Its tunes are per-game data. PoR and Curse have split it into a core plus device includes; Secret
   has the split without AdLib; CoK's is still one 1,554-line file with SSI's copy-protection countdown
   (`DriverData`). Pools has no sequencer: effects go through the DIGPAK TSR (INT 66h) and music through a `.COM`
   image from MUSIC.DAX.
3. **Only PoR can build natively**, because only PoR's display code is all Pascal. The other four link 1,777 to 6,613
   lines of TASM each (blit.asm, textrend.asm, sounddrv.asm, joystick.asm, Pools' vgaframe.asm). The native build is
   VGA-only, though. So one shared Pascal VGA path (PoR's VidVga/PicVga plus Blit's Pascal blitter) is the only
   display code a game needs to run natively. The DOS builds can keep their assembly.
4. **The native layer is about 85% game-agnostic already.** Host, Crt, NatFile, PortIO, TpCompat, Sdl3Min, SdlSound
   and SndChip name no game. GameDirs was written for "Curse, Secret and Pools need only their own entry". The
   game-specific parts are about 20 string sites (window title, quit box, the `POOLRAD_*` environment variables,
   DataPick's notices, `GameDirs.POOL`), SndDig, and SndSeq's tune image.
5. **Naming drift is the cheapest barrier to sharing.** PoR renamed `GDVars` to `GameVars`, `ReadNumber` to
   `InputUint16`, `ESCAPE` to `ESC` and `PAGE_UP` to `PGUP`, and gave `C_SOUND`'s device numbers different values.
   Curse+ added a background colour to every TextRend call; PoR's TextRend has one colour. Many routines that score
   0.6 to 0.85 here are the same routine under these renames.

Counts over the 462 routine families: 78 identical across every game that has them, 72 near (min ≥ 0.85), 79 same
logic with branches (0.60 to 0.85), 90 diverged (< 0.60), and 143 in one game only. The single-game count includes
the one-line `external` stubs: 37 TASM entries exist only as Pascal declarations.

## 1. What each game drives

### Video

| | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| CGA (mode 4) | yes | yes | yes | **no** | yes |
| EGA (0Dh) | yes | yes | yes | yes | yes |
| Tandy (9) | yes | yes | yes | yes | yes |
| VGA (13h) | yes, ported (16 colours, a byte a pixel, key `PIC_KEY=$FF`) | yes, ported from PoR (#547), same design | **no** (phase 6 "not started") | SSI's own MCGA, **256 colours**, a key colour per picture, palette cycling and presets, RLE delta frames (VgaFrame) | yes, ported (#448), pictures kept in **Tandy nibbles**, widened on the way to the screen |
| How the mode is chosen | `TVideoDriver` (27 fields) in `GameVars.video`; mode byte removed | `TVideoDriver` (30 fields, +BlitCell/BlitCellMasked/BlitClipped/GrabPic → TASM) | `case GDVars.displayMode` | `case GDVars.videoMode` (DISPLAY_EGA/TANDY/MCGA) | `TVideoDriver` (6 entries) plus `displayMode` and `Blit.PicLayout` |
| Mode-specific code | Pascal: VidCga/Ega/Tdy/Vga (resident), PicCga/Ega/Tdy/Vga + VidOps (overlaid) | Pascal drivers + blit.asm (12 entries, 1,623 lines) + textrend.asm (3 glyphs) | blit.asm (9) + textrend.asm (3) | blit.asm (9 + palette on retrace) + textrend.asm (EGA/Tandy/VGA glyph) + vgaframe.asm | Pascal Vid* + blit.asm (9) + textrend.asm (3) |
| Config letter | POOL.CFG line: C/E/T/V | CURSE.CFG: C/E/T/V | BLADES.CFG: C/E/T | POOL4.CFG line 2: E/T/V | KRYNN.CFG: C/E/T/V |
| Native | VGA only, through `Host.screen`/`Host.dac` | — | — | — | — |

### Sound

| | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| Speaker | SndSpk (sequencer) | SndSpk | SndSpk | IBMSND TSR | SndSpk(SPEAKER) |
| Tandy SN76489 | SndTdy | SndTdy | SndTdy | TSR (codes 3/4) | SndTdy |
| AdLib | **SndOpl**: the Tandy arrangements in FM (sndopl.inc), effects on the speaker | SndOpl (ported) | **SndAdl**: SSI's SOUND.DAX loaded driver plays the title music, effects on the speaker | ADLIB TSR + MUSIC.DAX | SndSpk(ADLIB): MIDI.DAX driver for the intro music, effects on the speaker |
| C/MS, Roland | — | — | — | — | SndSpk(CMS/ROLAND), intro music only |
| Sound Blaster | SndSb: SBSFX.DAT samples by single-cycle DMA, OPL music | SndSb (ported) | SndSb, SOUND.DAX music | SND.COM DIGPAK (ZOUNDS.DAX) | SndSb |
| Letters | P T A B, S/else none | P T S(silent) A B | A B T P | digits 1 SB, 2 AdLib, 3/4 Tandy, 5 speaker | C R A B T P |
| `C_SOUND` device values | TANDY 0, SPEAKER 1, DISABLED 2, ADLIB 3 | SPEAKER 0, TANDY 1, OFF 2, ADLIB 3 | TANDY 3, SPEAKER 4, OFF 5 | SB 0, ADLIB 2, TANDY 3, SPK 4, MUTED 5 | CMS 0, ROLAND 1, ADLIB 2, TANDY 3, SPEAKER 4, OFF 5 |
| Title/battle tune ids | 21 / 22 | 29 / 22 | (SOUND.DAX) | (MUSIC.DAX) | (MIDI.DAX) |
| Native | SndDig (Tandy emulated by SndChip, plus SBSFX samples) for T/A/B; speaker for P | — | — | — | — |

The device numbers are not arbitrary: the sequencer uses them to index its tick table (`SetSoundDevice`). PoR's and
Curse's speaker and Tandy values are swapped, and Secret and CoK use SSI's later numbering (3, 4, 5). Pools'
numbering is its STARTUP digits. One shared `C_SOUND` needs one numbering, mapped once at install time.

### Input

| | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| Keyboard | Crt (`ReadGameKey`, 61 lines) | Crt (86) + `PollGameKeys` | Crt + Mouse/Joystick translation | the same | the same |
| Mouse (INT 33h) | — | — | Mouse 176 | Mouse 198 | Mouse 193 |
| Joystick | — | — | Joystick.pas 270 + .asm 113 | 126 + 115 | 253 + 106 |
| Debug switch | `STING` (Ctrl-D/L/Z/Y/C) | `STING` (Ctrl-D trace) | `STING` | `STING` | `Woof` |
| Extras | F1 command keys (KeyHelp), F2 Bestiary, F6 Companion, Alt-Q | F6 Companion, Alt-M/X | Alt-M/X | Alt-M/X | — |

## 2. Unit by unit

### Text and menus

| Unit | PoR | Curse | Secret | Pools | CoK | Class |
|---|---|---|---|---|---|---|
| TextRend.pas / .asm | 389 / — | 492 / 335 | 630 / 315 | 751 / 296 | 566 / 329 | B |
| MenuCore | 752 | 734 | 905 | 1,194 | 820 | B |
| Border | 73 | 247 | 311 | 222 | 288 | D (layouts are game data) |
| Sym8x8 | 64 | 75 | 83 | 151 | 99 | I/D |

- **TextRend.** Identical logic: `PrintSpaces`, `DisplayString` (0.84 to 0.86), `DisplayMessageWindow` (word wrap,
  "(more)", typing delay; 0.80 to 0.95), `PauseOnly` (=d in Curse/Secret/CoK), `GetTicks` (0.80), and
  `TicksBetween`/`TicksSince` (identical in Curse/Secret/Pools/CoK; PoR folded them into `TickCount`). PoR's
  `InputUint16` is Curse's `ReadNumber` (0.90).
  - **Data:** the font archive. PoR, Curse and CoK use `8X8d1`, Secret `8X8d5`, Pools `8X8d0`, all block 201. Pools
    has a 64-glyph font.
  - **API divergence:** PoR has one colour (`DisplayString(col,row,color,s)`); Curse+ take `fg,bg` everywhere
    (`RenderChar`, `DisplayString`, `DisplayMessageWindow`, `ReadString`, `DisplayAndPause`, `PrintAndPause`). The
    shared core takes Curse+'s signatures, and PoR passes `bg=0`.
  - **Mode branches:** Secret and Pools (`displayMode`/`videoMode`) and CoK (`ResetEgaGc`, `SetupEga*Page`,
    `FillRectEga` are still here) keep EGA page and GC code in TextRend. PoR and Curse moved it into VidEga.
  - **Mouse:** Secret, Pools and CoK hide and show the cursor around text (14 to 19 sites). A `HideCursor`/
    `ShowCursor` hook that does nothing without a mouse covers it.
  - **PoR-only:** `DelayOrKey`, `FlashBottomLine`, `ClearBottomLine` and `ShowMessage`/`DisplayCentered`
    (Curse/Secret have these two), all port additions and shareable. **Pools-only:** `DisplayLoading`,
    `ClearStatusLine`, `NumToStr`, `RightAlignString`, `FillRect`.
- **MenuCore.** `FindListMember`, `ListCount` and `AllocStringList` are identical in all five; `FreeStringList` is
  0.74 to 0.90; `YesNoMenu` is =n in Curse/CoK.
  - `MenuVertical` (276 to 378 lines): PoR/Curse 0.86, CoK 0.77, Secret/Pools 0.66. `MenuHorizontal` (PoR's
    `HorizontalMenu`, 214 lines): Curse 0.77, CoK 0.46, Secret 0.36, Pools 0.25.
  - The differences are mouse hit-testing (Secret 38, Pools 62, CoK 57 sites), joystick, hotkey rules, and PoR's
    paging (`PageRows`, `DrawMore`, `AppendMenuLine`) and F1 help. Pools' menu keeps slot tables (`AppendSlot`,
    `ResetMenuSlots`).
  - Hook: an input source that yields keys, mouse clicks on a row, or "no change". The menu loop is otherwise one.
- **Border.** PoR draws one generic frame: `DrawBorder(rect, corner)` from symbol 276 + corner×3, plus `DrawWindow`.
  Curse+ draw each screen's frame (`DrawWindowFrame`, `DrawCombatFrame`, `DrawMemorizeFrame`, …) by walking glyph
  tables (`GDConsts.borderGlyphs`, outer base 286, inner 276). The routines are the same walker over different
  tables: frame bodies score 0.24 to 0.82 only because the tables differ. Shared: one `DrawFrame(const frame:
  TFrameDef)`; per game: the frame definitions (data) and the symbol bases.
- **Sym8x8.** `Put8x8Sym` 0.88 to 0.98, `Load8x8Set` 0.64 to 0.79 (the archive naming), `PrimeSym8x8` identical.
  Pools adds `DrawBorderRun`. Shared, with the symbol-set file name as a parameter.

### Pictures and drivers

| Unit | PoR | Curse | Secret | Pools | CoK | Class |
|---|---|---|---|---|---|---|
| Blit.pas / blit.asm | 708 / — | 771 / 1,623 | 984 / 994 | 1,337 / 1,174 | 1,010 / 985 | B (Pascal half), X (asm) |
| VidCga/Ega/Tdy/Vga | 161/253/120/166 | 159/297/169/160 | — | — | 113/177/122/142 | I/B (PoR↔Curse), X (CoK) |
| VidOps | 262 | 109 | — | — | — | I (moved routines) |
| PicCga/Ega/Tdy/Vga | 158/169/133/110 | 186/189/144/147 | — | — | — | I/B |
| ModeInit | — | 21 | 18 | 16 | 11 | I |
| VgaFrame .pas/.asm | — | — | — | 62 / 89 | — | Pools only |

- **Identical across all that have them:** `ComputeMask`, `MirrorBits`, `MirrorPairs` and `MirrorNibbles` (in PoR's
  VidOps and the others' Blit, verbatim or =n), `SrcNibble`, `RestoreVideoMode`, `GrabPic`, `SetPaletteRegister`
  (PoR/Curse).
- **PoR↔Curse drivers:** `Start`, `CellFill`, `SetPalette` and `RecolorFrame` are identical; `FlushSpans`, `ShowPic`,
  `ClearRect` and `WriteChar` are 0.93 to 0.98. Curse's Pic* units are PoR's, with `ExpandChunk` renamed
  `ExpandFrames`.
- **Same logic with branches:** `LoadPic` (0.73 to 0.88, Pools 0.40: 1 byte a pixel DAX payloads), `AllocPic`,
  `FreePic`, `FillPicRect` (Curse 0.90, Secret/CoK 0.62), `RemapPic` (Curse 0.83; Secret/Pools/CoK 0.39 because
  their remap is still per-mode inline).
- **Diverged:**
  - PoR's 153-line Pascal `BlitTile` against the others' 9 to 12 TASM leaves. Same job, different language.
  - Pools' `PreparePic`, `PicBlockFits`, palette on retrace, `SetDacPalette`, `CopyIconTile`, `BuildIconFrames` (the
    256-colour engine).
  - CoK's VGA: `PutNibbles`/`GetNibbles`, nibble pictures. Its `TVideoDriver` has 6 entries against PoR's 27.
- **TASM by instruction shape:** blit.asm Curse/Secret 0.55, CoK against the rest 0.14 to 0.27, Pools against the
  rest 0.17 to 0.27. textrend.asm 0.64 to 0.85 (glyph loops, the same SSI routine three times). Each game's asm is its
  own SSI vintage.
- **Transparency:** PoR/Curse fix the key at `$FF` (16-colour art). Pools keys each picture with its own colour, and
  its comment notes SSI's bug that the scratch image's key is 0. A shared VGA path needs the key per picture to serve
  Pools' 256-colour art. PoR's refactor-plan chose a byte a pixel with a key "so the driver carries to later games with
  256-colour art"; that choice holds, but the key must become a field.

### Map, view, portraits

| Unit | PoR | Curse | Secret | Pools | CoK | Class |
|---|---|---|---|---|---|---|
| Portrait | 312 | 427 | 374 | 389 | 365 | B (Pools X) |
| MapTiles | 208 | 160 | 158 | 152 | 166 | B |
| MapView | 143 | 95 | 67 | 43 | 102 | B/D |
| View3D | 473 | 484 | 485 | 540 | 586 | B |
| MapCurs / MapWin | — | 61 | — | 42 | 45 | B |

- **View3D:** `SetView3DColors` and `Valid3DCoords` are =n in all; `DrawWallSlice` 0.93 to 0.98; `DrawAutoMap` 0.90
  to 0.99; `LoadWallSet` 0.78 to 0.85 (Pools 0.52); `Load3DMap` 0.72 to 0.90; `GetBarrierType`/`GetWallType` 0.73 to
  0.78.
  - `Display3DMapView`: PoR/Curse/Secret 0.57 to 0.78, but Pools and CoK 0.16 to 0.21. Same walk, reconstructed with
    unrolled and reordered loops (CoK's is 221 lines against Curse's 126); it reads as the same algorithm and is to be
    proved by test, not by diff.
  - `DrawBackdrop` differs per game (sky and ground art, Pools' `LoadBackdrop`). Hook.
  - Data: `AUTOMAP_ARROW_SYM`, `AUTOMAP_WALL_SYM`, `GBVM_BORDER_WALL` (`$4BC9` in CoK), the wall-set rules (slots
    1..3, block limit 25).
- **MapTiles:** `DrawIconAnimSprite` 0.90 to 0.95, `Copy2DTile` 0.77 to 0.90, `LoadIconAnim` 0.48 to 0.57, and
  `Load24x24Set` 0.45 to 0.48 (layout branches per mode). PoR-only: `SecondSheet`/`FreeSecondSheet`/`LoadWildIcons`
  (the wilderness tile sheet that VGA splits).
- **MapView:** one `DisplayMapView` (PoR/Curse/CoK 0.33 to 0.38, Pools 0.12) for the overhead area map. PoR adds the
  wilderness view (`DisplayWildMapView`, `PartyCell`, `CenteredCorner`).
- **Portrait:**
  - Shared: `DisplayImageBuf` (0.74 to 0.90), `Show3DSprite` (0.81 to 0.94), `FreeAnimation`, `DisplayBigPic`
    (0.78 to 0.86), `DisplayPortraitHead`/`Body` (identical Curse/Secret/CoK).
  - `LoadAnimation` (PoR 130 lines) is 0.67 to 0.76; Pools 0.28, which is VGA frames and palette.
  - Pools-only: `SelectPicturePalettePreset`, `CyclePaletteRange`. PoR-only: merged player portraits
    (`MergedPortraits`, `PlayerPortraitCount`); Curse has its own `LoadPlayerPortrait`.

### Port-added screens

| Unit | PoR | Curse | Secret | Pools | CoK | Class |
|---|---|---|---|---|---|---|
| BldShow (data-build progress) | 658 | 678 | 710 | 478 | 737 | **I**: 11 routines identical, 6 near; Pools diverged (0.32 to 0.85) |
| Intro | 137 | 103 | 150 | 91 | 154 | X: sequence and credits are game content; `DelayOrKey`/`FinishIntroduction` shareable |
| Options (Settings screen) | 486 | 739 | 525 | 582 | — | B: `SettingRow` =q, `DrawSetting` 0.75 to 0.79, `OptionsMenu` 0.54 to 0.83 |
| CfgFile / TuiKit / POOLCFG / LineEdit / KeyHelp | 761 / 766 / 1,199 / 58 / 120 | — | — | (STARTUP 431, CONTROL 182) | — | PoR only |

BldShow is the clearest win: `MulDiv`, `ShowFrame`, `FamilyPlace`, `Recount`, `StartPhase`, `Active`, `Writing`,
`Checking`, `Advance`, `EndFamily` and `Step` are verbatim in PoR, Curse, Secret and CoK. `SetCell`, `SetCells` and
`StartFamily` differ only in data (=d).

Options: PoR moved file I/O into CfgFile (KEY=VALUE, with `CURSEDATA`/`SECRETDATA`/`POOLSDATA` keys already there).
Curse, Secret and Pools still read and write inline (`LoadOptions` 0.21 to 0.24 against PoR) into CURSEOPT.CFG,
BLADEOPT.CFG and POOL4OPT.CFG, the same KEY=VALUE format. CoK has no Settings screen.

### Sound

| Unit | PoR | Curse | Secret | Pools | CoK | Class |
|---|---|---|---|---|---|---|
| SoundDrv.pas | 328 | 218 | 132 | 59 | 125 | B |
| sounddrv.asm (core) | 794 | 746 | 849 | 78 (TSR shim) | 1,554 (monolithic) | I by design; CoK unsplit |
| sndspk.inc / sndtdy.inc | 1,738 / 1,736 | 1,748 / 1,784 | 3,594 / 451 | — | (inside sounddrv.asm) | D: tunes |
| sndopl.inc / SndOpl | 354 / 86 | 377 / 85 | — | — | — | I (port) |
| SndSb | 304 | 394 | 370 | — | 402 | I/B |
| SndSpk / SndTdy / SndNone | 30/30/29 | 29/29/35 | 29/29/38 | — | 31/29/38 | I (`Play` =n in all) |
| SndAdl / SndLoad | — | — | 30 / 130 | — | — / 119 + .asm 143 | per-game loaded-driver glue |
| MusDrv / Music | — | — | — | 91 / 107 | — | Pools only |

- SoundDrv's `InstallSoundTimer`, `UninstallSoundTimer` and `SetSoundDevice` are identical in PoR, Curse, Secret and
  CoK; `ProgramSpeakerVoices`/`ProgramTandyVoices` and `SetVoiceByte` are =n. `SoundCommand` is 0.41 to 0.43 against
  PoR: PoR's has groups (footsteps, ranged, melee, death, wall, spell), autostop and suspend, and these are settings
  features Curse partly has (`TuneAllowed`, `ApplyMusicSettings` identical).
- SndSb: `DspWrite`, `DspReset`, `Crosses`, `PlaceBlock` and `StopSample` are identical in four games, `PlayEffect`
  0.97. PoR replaced `ParseBlaster` with `ReadBlaster` (0.19) and `LoadEffects` reads through SfxFile (0.20).
- The asm core: PoR/Curse/Secret 0.56 to 0.58 by instruction shape, with the same command table and the same LFO and
  random tables byte for byte (also in CoK). The low score is the TRACE macros and PoR's tickProc dispatch. One
  sequencer, per-game streams.

## 3. PoR's native layer

| File | Lines | Game-specific content | Shared as is? |
|---|---|---|---|
| host.pas | 177 | none (VGA memory, DAC, INT 10h, BIOS ticks and keyboard) | yes |
| crt.pas | 97 | none | yes |
| natfile.pas | 133 | none (DOS-style names on case-sensitive file systems) | yes |
| portio.pas | 32 | none | yes |
| tpcompat.pas | 28 | none (MemAvail/MaxAvail) | yes |
| sdl3min.pas | 208 | none | yes |
| sdlhost.pas | 482 | window title, quit box text, `POOLRAD_SHOT`/`POOLRAD_KEYS`, error prefix (6 sites) | with an identity record |
| sdlsound.pas | 85 | none | yes |
| sndchip.pas | 294 | none (speaker, SN76489, one sample) | yes |
| sndseq.pas | 626 | uses SNDIMAGE.INC built from PoR's .inc by tools/snd2pas.py | yes, with a per-game image; CoK needs its asm split first |
| snddig.pas | 140 | SBSFX.DAT effect map (SfxFile), GameVars | per-game table |
| gamedirs.pas | 711 | the `POOL: TStoreGame` const (store paths, GOG id, GEO1.DAX) | yes plus one const per game |
| datapick.pas | 337 | "Pool of Radiance", "GEO1.DAX" in about 10 notices, `GameDirs.POOL` | with the identity record |
| biosfont.inc | 133 | none | yes |

The rest of PoR's native support is 157 `{$IFDEF FPC}` sites in 47 units, most of them in GameBoot, POOLCFG,
DiskRec, CfgFile and CbtLog: folders, EMS, overlays and the setup run. In display code it is only `absolute` over the
banks, `vgaMem` over `Host.screen`, the DAC write, and the `uses Host` in TextRend and Blit. Pascal code with
`Mem[]`/`Port[]` (EGA, CGA, Tandy) is simply not linked natively.

**What each other game lacks for a native build:**

| Need | Curse | Secret | Pools | CoK |
|---|---|---|---|---|
| A Pascal VGA path (drivers, blitter, glyph) | VGA blitters are TASM (`BlitCellVga*`); take PoR's Pascal VGA drivers and `BlitTile` | no VGA: adopt PoR's VidVga/PicVga and the driver record (phase 6) | 256-colour VGA in TASM + vgaframe.asm: the per-picture key, palette, RLE decoder in Pascal | VGA through Tandy asm blitters: switch to the keyed byte-a-pixel VGA, or port the Tandy leaves |
| A Pascal sound sequencer | SndSeq + Curse image | SndSeq + Secret image | none: needs native DIGPAK effects (SndChip.PlaySample) and a MUSIC.DAX player, or silence | split the asm first, then SndSeq + image; drop `DriverData` |
| Card music | none natively (no OPL emulator yet): SndDig plays the Tandy arrangement, as PoR does | SOUND.DAX is x86 driver code: natively Tandy or speaker only | MUSIC.DAX the same | MIDI.DAX the same |
| Mouse | — | INT 33h: Host needs a mouse (SDL events) or "no mouse" | the same | the same |
| Joystick | — | joystick.asm: report "none" natively | the same | the same |
| Other asm | — | coreinp.asm (FillWord = zero fill → FillChar) | keyboard.asm (ZeroFill → FillChar), VACE.EXE intro/ending (native: skip, or show stills) | sndload.asm |
| Setup | first-run questions in GameBoot | the same | STARTUP.EXE/CONTROL.EXE | the same as Curse |

## 4. Proposal

### 4.1 The shared presentation core (one copy, `goldbox/` units)

Resident unless marked overlaid, as now:

1. **`Video` contract (Types or a new `VidTypes`).** PoR's `TVideoDriver` is the base, with Curse's
   `BlitCell`/`BlitCellMasked`/`BlitClipped`/`GrabPic` added as optional entries. When they are nil, Blit uses the
   Pascal `BlitTile`. New fields: `keyColour` per picture (in `TPic`, not the driver) and `paletteSize` (16 or 256).
   One driver unit per mode: VidCga, VidEga, VidTdy, VidVga. A game's DOS build may override an entry with its own
   TASM leaf, which keeps SSI's speed and its blit.asm. The record gives that hook for free.
2. **Blit** (mode-independent): span bookkeeping, `LoadPic`/`AllocPic`/`FreePic`/`FillPicRect`/`ShowPic`/
   `FlushView`, and the Pascal `BlitTile`. **VidOps** (overlaid): `ComputeMask`, `Mirror*`, `ExpandPicFrames`,
   `MergePic`, `OverlayPic`, `RecolorPic`. **Pic\*** per layout (overlaid). This is PoR plus Curse today, about 2,100
   Pascal lines.
3. **TextRend** with Curse+'s `fg,bg` signatures, the font loop, `DisplayMessageWindow`, `ReadString`/`ReadNumber`,
   ticks, `DelayOrKey`, `FlashBottomLine`, and a `CursorHide/Show` hook for mouse games.
4. **MenuCore:** one `MenuVertical`/`MenuHorizontal` with PoR's paging and an input source (keyboard, plus optional
   mouse/joystick row hits); `YesNoMenu`; the string lists.
5. **Border:** a table-driven `DrawFrame(TFrameDef)` plus PoR's generic `DrawWindow`. **Sym8x8.**
6. **View3D core:** `DrawWallSlice`, `DrawAutoMap`, `GetWallType`/`GetBarrierType`/`GetMapEvent`, `LoadWallSet`,
   `Load3DMap`, `Display3DMapView` (after a test proves CoK's and Pools' unrolled walks equal), and a `DrawBackdrop`
   hook. **MapTiles** and **MapView** core with the wilderness sheet optional. **Portrait** core (`LoadAnimation`,
   `DisplayImageBuf`, `Show3DSprite`, big pictures) with a palette hook for Pools.
7. **BldShow:** take it verbatim now, since it is already identical in four games.
8. **Sound:**
   - `SoundDrv` (Pascal front: groups, suspend, autostop, music settings) over one `sounddrv.asm` core with a
     `tickProc`.
   - `TSoundDriver` (PoR's, plus Curse's `Stop`).
   - SndSpk, SndTdy, SndNone, SndOpl (+ sndopl.inc) and SndSb (with SfxFile).
   - The per-game parts are only the tune includes (`sndspk.inc`, `sndtdy.inc`) and the effect map.
9. **Input:** `ReadGameKey`/`ReadAnyKey`/`DiscardPendingKeys`/`SetSound` in GameIo's core with a game hook for the
   debug keys. Mouse and Joystick units (Secret's: Pools and CoK are 0.86 to 0.99 of it), linked only by games that
   offer them.
10. **Settings:** CfgFile (KEY=VALUE options plus the legacy `.CFG` reader, driven by a per-game layout), Options' page
    engine, TuiKit, LineEdit, and the setup program (POOLCFG generalised: "GBCFG" with the game's name). It replaces
    the first-run questions in Curse, Secret and CoK and Pools' STARTUP, and keeps writing each game's own `.CFG`
    lines so SSI's START/CONTROL still read them.

### 4.2 The native layer, common to all five

- Move `src/native` to the shared tree unchanged except for one **`TGameIdent`** record that the per-game layer
  supplies: title, short name for the executable and environment variables (`POOLRAD_*` becomes `<SHORT>_*`), data
  marker file, `TStoreGame`, and the quit-box text. SdlHost and DataPick read it instead of literals. About 20 edits.
- **SndSeq** is shared. `tools/snd2pas.py` (PoR) builds each game's SNDIMAGE.INC from that game's includes. The trace
  test (`TSndSeq`, CRC per tune) runs per game against its own TASM trace build. **SndDig** becomes shared, with the
  effect table per game.
- **Host** gains an INT 33h mouse (SDL mouse events mapped to the 320×200 grid; `GetMouse`/`SetMouse`/cursor shape)
  for Secret, Pools and CoK. Natively the joystick reports none at first.
- Each game's native display is the shared Pascal VGA path. Its TASM is not linked natively, the same way PoR's EGA,
  CGA and Tandy drivers are excluded today. Natively the setup's video letter is ignored, as PoR does.
- **Pools** natively needs two new pieces, both larger than anything above:
  - Effects: DIGPAK's ZOUNDS.DAX samples played through `SndChip.PlaySample`.
  - Music: either a MUSIC.DAX player (an OPL emulator plus the driver's format: a real project) or the Tandy/speaker
    fallback.
  - VACE's intro and ending are an external program and stay out of a native build.

### 4.3 The per-game layer

Two units per game, `GameLook` (constants and tables) and `GameHooks` (procedure variables set at start), plus the
game's data:

| Parameter | PoR | Curse | Secret | Pools | CoK |
|---|---|---|---|---|---|
| Font archive / block | 8X8d1 / 201 | 8X8d1 / 201 | 8X8d5 / 201 | 8X8d0 / 201 (64 glyphs) | 8X8d1 / 201 |
| Border symbol bases | 276 (+corner×3) | outer 286, inner 276 | (tables) | (runs) | (tables) |
| Frame definitions | generic windows | `borderGlyphs` and 12 frames | 9 frames | 5 | 9 |
| Config file / line order / letters | POOL.CFG | CURSE.CFG | BLADES.CFG | POOL4.CFG (sound first, digits) | KRYNN.CFG |
| Options file | POOLOPT.CFG | CURSEOPT.CFG | BLADEOPT.CFG | POOL4OPT.CFG | (none yet) |
| Modes offered | CETV | CETV | CET | ETV (256) | CETV |
| Sound letters → driver | P T A B | P T S A B | A B T P | 1..5 | C R A B T P |
| Tune ids (title, battle) and groups | 21, 22, 6 groups | 29, 22, 4 groups | — | — | — |
| Tune streams | sndspk/tdy.inc | own | own | (TSR) | own |
| Debug switch | STING | STING | STING | STING | Woof |
| Mouse / joystick | no / no | no / no | yes / yes | yes / yes | yes / yes |
| Automap symbols, wall limits, `GBVM_BORDER_WALL` | per game | | | | |
| Hooks | wilderness view and second sheet, merged portraits | player portrait | — | backdrop, palette presets and cycling, VGA frames | — |
| Intro/credits | sequence + strings | | | (VACE) | |
| Identity (native) | Pool of Radiance, GEO1.DAX, store paths | its own | its own | its own | its own |

### 4.4 Order of work (cheapest first)

1. **Unify names** across the ports, all mechanical:
   - routines: `InputUint16`/`ReadNumber`, `TickCount`/`TicksSince`, `HorizontalMenu`/`MenuHorizontal`;
   - `C_KEYS` names (`ESC`/`ESCAPE`, `PGUP`/`PAGE_UP`), with PoR's longer key set as the superset;
   - one `C_SOUND` device numbering;
   - `GameVars`/`GDVars`.

   The cleanup spec's rule that routine names are unified across games argues for this anyway.
2. **BldShow**, the SndSpk/SndTdy/SndNone/SndSb/SndOpl drivers, Mouse, Joystick.pas, and the mask/mirror routines:
   identical today, so moving them is cheap.
3. **TextRend fg/bg** in PoR, then the shared TextRend and MenuCore with the input-source and cursor hooks.
4. **Video phase 6 in Secret** (PoR/Curse's record), CoK's record grown to PoR's and its VGA moved to keyed bytes, and
   Pools onto the record with the per-picture key and a palette hook.
5. **Sound:** split CoK's sounddrv.asm into a core plus includes, drop `DriverData`, and put the trace test in every
   game.
6. **Native for Curse** (only VGA blitters and the identity), then Secret and CoK, and Pools last.

### 4.5 Risks

- **DOS memory and residency.** TextRend, Border, Blit, the Vid\* drivers, SoundDrv and its drivers are resident in
  every game (by `{$O}` lists in FixMain). A shared core that carries every game's options (mouse hooks, paging,
  per-picture key, 256-colour palette) grows resident code. Curse has 22,222 data bytes free and Secret 21,860;
  PoR's VGA has 134 KB of heap free at the wilderness, its tightest spot measured. Keep optional features in overlaid
  units (MenuCore, Options and VidOps already are), use procedure variables rather than `case`, and gate
  per-game features by linking, not by flags.
- **Speed.** The TASM blitters are SSI's hot path on an 8088. PoR's Pascal `BlitTile` is fine for PoR, but replacing
  Secret's or CoK's asm on DOS should be measured, which is why the driver record keeps an asm override per entry.
- **Data layouts.** `TVideoDriver`/`TSoundDriver` live in GDVars (DGROUP), so growing them moves storage. These ports
  are not byte-gated, but saves are: none of this unit set writes save files except Curse's map notes and the
  Companion sidecars, and the `.CFG`/`OPT.CFG` formats must stay readable by each game's SSI START (the legacy
  lines) and by older builds (KEY=VALUE ignores unknown keys).
- **Device numbering** feeds the sequencer's tick table index and is also stored in `soundMode`. Remap at install
  only. `soundMode` is not stored in saves in the PoR line (a saved game no longer changes the settings): check this
  in Secret and CoK before renumbering.
- **CoK's VGA design** differs from PoR/Curse's (nibbles against keyed bytes). Moving it to keyed bytes costs heap
  (PoR measured ~240 KB of pictures in combat against Tandy's half) on a game with less headroom. Measure first.
- **Pools** is the outlier: 256-colour art, no CGA, external drivers and VACE. Its presentation shares the text, menu,
  view and BldShow cores, but its picture and sound back ends are their own until the per-picture key and a native
  DIGPAK/music path exist.
- **The byte-matched disassembly trees are not touched by any of this.** The cleanup spec's rules (no `{$IFDEF}`, no
  `.inc`, no asm where Pascal makes the bytes) govern those trees, while the ports already use `.inc` and `{$IFDEF
  FPC}`. The shared core lives in the ports' world only.

## 5. PoR-only presentation features shareable later

- KeyHelp (F1 command keys, table-driven).
- MenuCore paging and "(more)".
- `DelayOrKey`, `FlashBottomLine`.
- The POOLCFG setup program with TuiKit and LineEdit.
- CfgFile's validated `.CFG` reader with notes, and `NativeSaveFolder`.
- The Options pages for paths and system.
- The wilderness second tile sheet (VGA).
- Merged player portraits.
- The sound groups and autostop.
- The whole native layer.

Curse already has the video and sound drivers, AdLib and Sound Blaster, and the Settings screen and Companion line.
Secret has the sound drivers and Sound Blaster. CoK has the video drivers, VGA and Ctrl-S for every device. Pools has
the Settings screen and the combat log (LogView/LogWrap, shared with PoR's CbtLog family).
