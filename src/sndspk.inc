; ---------------------------------------------------------------------------
; The PC speaker's part of the sequencer (phase 7 of docs/refactor-plan.md): its
; note table, voice blocks, song table and streams, the tick that drives PIT
; channel 2, and the entry that loads a tune.  sounddrv.asm includes it.
; ---------------------------------------------------------------------------

; PC-speaker divisors for PIT channel 2, starting at C1.
; Nominal frequencies below assume a 1193182 Hz PIT input.
spkC    equ 8E84h    ; C1    32.704 Hz
spkCS   equ 8684h    ; C#1   34.649 Hz
spkD    equ 7EF7h    ; D1    36.710 Hz
spkDS   equ 77D7h    ; D#1   38.892 Hz
spkE    equ 714Fh    ; E1    41.134 Hz; 2.9 cents flat
spkF    equ 6AC4h    ; F1    43.655 Hz
spkFS   equ 64C6h    ; F#1   46.251 Hz
spkG    equ 5F1Eh    ; G1    49.001 Hz
spkGS   equ 59C7h    ; G#1   51.916 Hz
spkA    equ 54BDh    ; A1    55.003 Hz
spkAS   equ 4FFCh    ; A#1   58.272 Hz
spkB    equ 4B7Eh    ; B1    61.740 Hz

; Four PC-speaker voices, cleared when a tune starts.
spkrBlocks      VOICE   <>
                VOICE   <>
                VOICE   <>
                VOICE   <>

; Four unused voice blocks reserved after the active voices.
spkrSpare       VOICE   <>
                VOICE   <>
                VOICE   <>
                VOICE   <>

spkrFreq        dw      spkC, spkCS, spkD, spkDS, spkE, spkF
                dw      spkFS, spkG, spkGS, spkA, spkAS, spkB

spkrVoice       dw      0               ; the block currently driving PIT channel 2

; Speaker rows use voice 0; tunes 20-28 also configure other blocks from their setup streams.
songTableA      dw      silentA,     silentA,     silentA,     silentA      ; tune  0
                dw      tuneA01_v0,  silentA,     silentA,     silentA      ; tune  1
                dw      tuneA02_v0,  silentA,     silentA,     silentA      ; tune  2
                dw      tuneA03_v0,  silentA,     silentA,     silentA      ; tune  3
                dw      tuneA04_v0,  silentA,     silentA,     silentA      ; tune  4
                dw      tuneA05_v0,  silentA,     silentA,     silentA      ; tune  5
                dw      tuneA06_v0,  silentA,     silentA,     silentA      ; tune  6
                dw      tuneA07_v0,  silentA,     silentA,     silentA      ; tune  7
                dw      tuneA08_v0,  silentA,     silentA,     silentA      ; tune  8
                dw      tuneA09_v0,  silentA,     silentA,     silentA      ; tune  9
                dw      tuneA10_v0,  silentA,     silentA,     silentA      ; tune 10
                dw      tuneA11_v0,  silentA,     silentA,     silentA      ; tune 11
                dw      tuneA12_v0,  silentA,     silentA,     silentA      ; tune 12
                dw      tuneA13_v0,  silentA,     silentA,     silentA      ; tune 13
                dw      tuneA14_v0,  silentA,     silentA,     silentA      ; tune 14
                dw      tuneA15_v0,  silentA,     silentA,     silentA      ; tune 15
                dw      tuneA16_v0,  silentA,     silentA,     silentA      ; tune 16
                dw      tuneA17_v0,  silentA,     silentA,     silentA      ; tune 17
                dw      tuneA18_v0,  silentA,     silentA,     silentA      ; tune 18
                dw      tuneA19_v0,  silentA,     silentA,     silentA      ; tune 19
                dw      tuneA20_v0,  0,           0,           0            ; tune 20
                dw      tuneA21_v0,  0,           0,           0            ; tune 21
                dw      tuneA22_v0,  0,           0,           0            ; tune 22
                dw      tuneA23_v0,  0,           0,           0            ; tune 23
                dw      tuneA24_v0,  0,           0,           0            ; tune 24
                dw      tuneA25_v0,  0,           0,           0            ; tune 25
                dw      tuneA26_v0,  0,           0,           0            ; tune 26
                dw      tuneA27_v0,  0,           0,           0            ; tune 27
                dw      tuneA28_v0,  0,           0,           0            ; tune 28
SONG_ROWS_A     equ     ($ - songTableA) / 8

tuneA10_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        7530h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      2710h
        SSET    vfLfoRate,       10h
        SWAIT   28
        SSET    vfLevel,         0
        SWAIT   12
        SSET    vfLevel,         3
        SSET    vfPeriod,        1004h
        SSET    vfLfoDepth,      898h
        SSET    vfPeriodAdd,     10h
        SWAIT   300
        SSET    vfLevel,         0
        SWAIT   0
tuneA12_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        2710h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      2328h
        SSET    vfLfoRate,       10h
        SWAIT   25
        SSET    vfLevel,         0
        SWAIT   2
        SSET    vfLevel,         3
        SSET    vfPeriod,        1388h
        SSET    vfLfoDepth,      0FA0h
        SSET    vfPeriodAdd,     12Ch
        SWAIT   80
        SSET    vfLevel,         0
        SWAIT   0
tuneA13_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        0BB8h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      44Ch
        SSET    vfLfoRate,       10h
        SWAIT   2
        SSET    vfLevel,         0
        SWAIT   1
        SSET    vfLevel,         3
        SSET    vfPeriod,        834h
        SSET    vfLfoDepth,      1F4h
        SSET    vfPeriodAdd,     0FF9Ch
        SWAIT   30
        SSET    vfLevel,         0
        SWAIT   0
tuneA18_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        1F40h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      44Ch
        SSET    vfLfoRate,       10h
        SWAIT   2
        SSET    vfLevel,         0
        SWAIT   1
        SSET    vfLevel,         3
        SSET    vfPeriod,        17D4h
        SSET    vfLfoDepth,      1F4h
        SSET    vfPeriodAdd,     0FF9Ch
        SWAIT   80
        SSET    vfLevel,         0
        SWAIT   0
tuneA16_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      3E8h
        SSET    vfLfoRate,       10h
        SSET    vfPeriodAdd,     0FFCEh
        SSET    vfLoopCounterA,  4
tuneA16_v0_loop:
        SSET    vfPeriod,        2710h
        SWAIT   4
        SSET    vfPeriod,        4E20h
        SSET    vfLevel,         0
        SWAIT   4
        SSET    vfLevel,         3
        SWAIT   4
        SLOOP   vfLoopCounterA, tuneA16_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA17_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      3E8h
        SSET    vfLfoRate,       10h
        SSET    vfPeriodAdd,     0FFCEh
        SSET    vfLoopCounterA,  20
tuneA17_v0_loop:
        SSET    vfPeriod,        1388h
        SWAIT   1
        SSET    vfLevel,         0
        SWAIT   1
        SSET    vfLevel,         3
        SSET    vfPeriod,        7530h
        SWAIT   1
        SLOOP   vfLoopCounterA, tuneA17_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA14_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        2710h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      1F4h
        SSET    vfLfoRate,       10h
        SSET    vfPeriodAdd,     0FFCEh
        SWAIT   28
        SSET    vfLevel,         0
        SWAIT   0
tuneA15_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        4E20h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      2710h
        SSET    vfLfoRate,       10h
        SWAIT   5
        SSET    vfLevel,         0
        SWAIT   1
        SSET    vfLevel,         3
        SSET    vfPeriod,        834h
        SSET    vfLfoDepth,      898h
        SSET    vfPeriodAdd,     64h
        SWAIT   100
        SSET    vfLevel,         0
        SWAIT   0
tuneA08_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        0FA0h
        SWAIT   5
        SSET    vfPeriod,        3E8h
        SWAIT   4
        SSET    vfLevel,         0
        SWAIT   0
tuneA09_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        36B0h
        SSET    vfPeriodAdd,     0C8h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      1770h
        SSET    vfLfoRate,       7Bh
        SWAIT   8
        SSET    vfLevel,         0
        SWAIT   0
tuneA07_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        3FB4h
        SSET    vfLoopCounterA,  30
tuneA07_v0_loop:
        SSET    vfPeriodAdd,     0FE3Ch
        SWAIT   12
        SSET    vfPeriodAdd,     277h
        SWAIT   8
        SLOOP   vfLoopCounterA, tuneA07_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA02_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      640h
        SSET    vfLfoRate,       19Bh
        SSET    vfPeriod,        10CCh
        SSET    vfPeriodAdd,     0Ah
        SWAIT   30
        SSET    vfLfoDepth,      384h
        SSET    vfPeriod,        514h
        SSET    vfPeriodAdd,     50h
        SWAIT   5
        SSET    vfLevel,         0
        SWAIT   0
tuneA05_v0:
        SSET    vfLevel,         3
        SSET    vfLoopCounterA,  5
        SSET    vfPeriod,        1838h
tuneA05_v0_loopOuter:
        SSET    vfPeriodAdd,     0
        SWAIT   6
        SSET    vfLoopCounterB,  12
tuneA05_v0_loopInner:
        SSET    vfPeriodAdd,     0FC5Eh
        SWAIT   1
        SSET    vfPeriodAdd,     384h
        SWAIT   1
        SLOOP   vfLoopCounterB, tuneA05_v0_loopInner
        SLOOP   vfLoopCounterA, tuneA05_v0_loopOuter
        SSET    vfLevel,         0
        SWAIT   0
tuneA03_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        197Bh
        SSET    vfLoopCounterA,  10
tuneA03_v0_loop:
        SSET    vfPeriodAdd,     0FFD3h
        SWAIT   20
        SSET    vfPeriodAdd,     1F4h
        SWAIT   1
        SLOOP   vfLoopCounterA, tuneA03_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA04_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      2710h
        SSET    vfLfoRate,       10h
        SSET    vfPeriod,        2EE0h
        SSET    vfLoopCounterA,  44
tuneA04_v0_loop:
        SSET    vfPeriodAdd,     0F1F0h
        SWAIT   2
        SSET    vfPeriodAdd,     0E88h
        SWAIT   2
        SLOOP   vfLoopCounterA, tuneA04_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA06_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      0A28h
        SSET    vfLfoRate,       10h
        SSET    vfPeriod,        1770h
        SSET    vfPeriodAdd,     0FF60h
        SWAIT   30
        SSET    vfPeriodAdd,     46h
        SWAIT   35
        SSET    vfLevel,         0
        SWAIT   0
silentA:
        SSET    vfLevel,         0
        SWAIT   0
tuneA01_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        1388h
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      1F4h
        SSET    vfLfoRate,       4Eh
        SSET    vfLoopCounterA,  40
tuneA01_v0_loop:
        SSET    vfPeriodAdd,     0
        SWAIT   2
        SSET    vfPeriodAdd,     0FDADh
        SWAIT   1
        SSET    vfPeriodAdd,     0
        SWAIT   2
        SSET    vfPeriodAdd,     1F4h
        SWAIT   1
        SLOOP   vfLoopCounterA, tuneA01_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA11_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      3E8h
        SSET    vfLfoRate,       100h
        SSET    vfPeriod,        0CE4h
        SSET    vfPeriodAdd,     0FFECh
        SWAIT   30
        SSET    vfLevel,         0
        SWAIT   0
tuneA20_v0:
        SCALL   tuneA20_setup
        SWAIT   0
tuneA20_setup:
        SCLEAR  1
        SSET    vfTranspose,     0FFE8h
        SSET    vfEnvBase,       tuneA20_env_v1
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      28h
        SSET    vfLfoRate,       12Ch
        SCLEAR  2
        SSET    vfTranspose,     0FFE8h
        SSET    vfReleaseLead,   5
        SSET    vfEnvBase,       tuneA20_env_v2
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      14h
        SSET    vfLfoRate,       78h
        SCLEAR  0
        SSET    vfTranspose,     0FFE8h
        SSET    vfEnvBase,       tuneA20_env_v0
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      78h
        SSET    vfLfoRate,       0E4h
        SCLEAR  3
        SSET    vfTranspose,     0FFE8h
        SSET    vfEnvBase,       tuneA20_env_v3
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      78h
        SSET    vfLfoRate,       0E4h
        SSET    vfTempo,         1
        SRET
tuneA20_env_v2:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
tuneA20_env_v1:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               16
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               30
        SENV    0,               0
tuneA20_env_v0:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               8
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               30
        SENV    0,               0
tuneA20_env_v3:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               20
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               30
        SENV    0,               0
tuneA19_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        0FA0h
        SSET    vfPeriodAdd,     14h
        SWAIT   16
        SSET    vfLevel,         0
        SWAIT   0

tuneA21_v0:
        SCALL   musicSetupA
        SNOTE   2, 12, NT_C+6*OCT,   1, 16
        SNOTE   2,  9, NT_DS+6*OCT,  1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   1, 17, NT_DS+5*OCT,  0, 48
        SNOTE   0, 17, NT_C+4*OCT,   0, 48
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   2,  9, NT_F+6*OCT,   1, 8
        SNOTE   2,  9, NT_DS+6*OCT,  1, 8
        SNOTE   2, 12, NT_F+6*OCT,   1, 16
        SNOTE   2,  9, NT_D+6*OCT,   1, 8
        SNOTE   2, 17, NT_AS+6*OCT,  0, 48
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   1,  6, NT_D+5*OCT,   0, 4
        SNOTE   0,  6, NT_AS+3*OCT,  1, 4
        SNOTE   1,  6, NT_D+5*OCT,   0, 4
        SNOTE   0,  6, NT_AS+3*OCT,  1, 4
        SNOTE   0, 15, NT_AS+3*OCT,  0, 32
        SNOTE   1, 15, NT_D+5*OCT,   0, 32
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  9, NT_D+7*OCT,   1, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2,  9, NT_AS+6*OCT,  0, 8
        SNOTE   1,  6, NT_F+5*OCT,   0, 4
        SNOTE   0,  6, NT_AS+3*OCT,  1, 4
        SNOTE   1,  6, NT_F+5*OCT,   0, 4
        SNOTE   0,  6, NT_AS+3*OCT,  1, 4
        SNOTE   0, 12, NT_A+3*OCT,   0, 16
        SNOTE   1, 12, NT_F+5*OCT,   0, 16
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2,  9, NT_A+6*OCT,   1, 8
        SNOTE   2,  9, NT_F+6*OCT,   0, 8
        SNOTE   1,  6, NT_F+5*OCT,   0, 4
        SNOTE   0,  6, NT_A+3*OCT,   1, 4
        SNOTE   1,  6, NT_F+5*OCT,   0, 4
        SNOTE   0,  6, NT_A+3*OCT,   1, 4
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   1, 12, NT_D+5*OCT,   0, 16
        SNOTE   0, 12, NT_G+3*OCT,   1, 16
        SNOTE   1,  6, NT_G+5*OCT,   0, 4
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   1,  6, NT_G+5*OCT,   0, 4
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0, 14, NT_G+3*OCT,   0, 24
        SNOTE   1, 14, NT_D+5*OCT,   1, 24
        SNOTE   2, 12, NT_GS+6*OCT,  1, 16
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2, 17, NT_DS+7*OCT,  0, 48
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+3*OCT,  0, 4
        SNOTE   1,  6, NT_C+5*OCT,   1, 4
        SNOTE   1,  6, NT_C+5*OCT,   0, 4
        SNOTE   0,  6, NT_GS+3*OCT,  1, 4
        SNOTE   0, 15, NT_GS+3*OCT,  0, 32
        SNOTE   1, 15, NT_C+5*OCT,   0, 32
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   2,  9, NT_CS+7*OCT,  0, 8
        SNOTE   1,  6, NT_F+5*OCT,   0, 4
        SNOTE   0,  6, NT_CS+4*OCT,  1, 4
        SNOTE   1,  6, NT_F+5*OCT,   0, 4
        SNOTE   0,  6, NT_CS+4*OCT,  1, 4
        SNOTE   2, 12, NT_DS+7*OCT,  0, 16
        SNOTE   0, 12, NT_CS+4*OCT,  0, 16
        SNOTE   1, 12, NT_F+5*OCT,   1, 16
        SNOTE   2,  9, NT_C+7*OCT,   0, 8
        SNOTE   0,  6, NT_GS+3*OCT,  0, 4
        SNOTE   1,  6, NT_C+5*OCT,   1, 4
        SNOTE   1,  6, NT_C+5*OCT,   0, 4
        SNOTE   0,  6, NT_GS+3*OCT,  1, 4
        SNOTE   2, 17, NT_GS+6*OCT,  0, 48
        SNOTE   1, 12, NT_C+5*OCT,   0, 16
        SNOTE   0, 12, NT_GS+3*OCT,  1, 16
        SNOTE   0,  6, NT_GS+3*OCT,  0, 4
        SNOTE   1,  6, NT_C+5*OCT,   1, 4
        SNOTE   1,  6, NT_C+5*OCT,   0, 4
        SNOTE   0,  6, NT_GS+3*OCT,  1, 4
        SNOTE   1, 15, NT_C+5*OCT,   0, 32
        SNOTE   0, 15, NT_GS+3*OCT,  0, 32
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   2,  9, NT_CS+7*OCT,  0, 8
        SNOTE   1,  6, NT_F+5*OCT,   0, 4
        SNOTE   0,  6, NT_CS+4*OCT,  1, 4
        SNOTE   1,  6, NT_F+5*OCT,   0, 4
        SNOTE   0,  6, NT_CS+4*OCT,  1, 4
        SNOTE   1, 12, NT_DS+5*OCT,  0, 16
        SNOTE   0, 12, NT_GS+4*OCT,  0, 16
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2,  9, NT_GS+6*OCT,  0, 8
        SNOTE   0,  6, NT_GS+4*OCT,  0, 4
        SNOTE   1,  6, NT_DS+5*OCT,  1, 4
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   1, 12, NT_F+5*OCT,   0, 16
        SNOTE   0, 12, NT_CS+4*OCT,  0, 16
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   2,  9, NT_CS+7*OCT,  0, 8
        SNOTE   0,  6, NT_CS+4*OCT,  0, 4
        SNOTE   1,  6, NT_F+5*OCT,   1, 4
        SNOTE   1,  6, NT_F+5*OCT,   0, 4
        SNOTE   0,  6, NT_CS+4*OCT,  1, 4
        SNOTE   1, 12, NT_DS+5*OCT,  0, 16
        SNOTE   0, 12, NT_GS+4*OCT,  0, 16
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2,  9, NT_GS+6*OCT,  1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 12, REST,         1, 16
        SNOTE   0,  6, NT_G+3*OCT,   0, 4
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   1,  6, NT_G+5*OCT,   0, 4
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0, 14, NT_G+3*OCT,   0, 24
        SNOTE   1, 14, NT_G+5*OCT,   1, 24
        SNOTE   2,  9, NT_D+7*OCT,   1, 8
        SNOTE   2,  9, NT_B+6*OCT,   1, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 12, REST,         1, 16
        SNOTE   0,  6, NT_G+3*OCT,   0, 4
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   1,  6, NT_G+5*OCT,   0, 4
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0, 14, NT_G+3*OCT,   0, 24
        SNOTE   1, 14, NT_G+5*OCT,   1, 24
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   0,  9, REST,         1, 8
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   2,  6, NT_DS+6*OCT,  0, 4
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   1,  9, NT_DS+5*OCT,  0, 8
        SNOTE   0,  9, NT_C+4*OCT,   1, 8
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   0,  9, REST,         1, 8
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   2,  6, NT_DS+6*OCT,  0, 4
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   1,  9, NT_DS+5*OCT,  0, 8
        SNOTE   0,  9, NT_C+4*OCT,   1, 8
        SNOTE   2,  9, NT_C+6*OCT,   1, 8
        SNOTE   2,  9, NT_F+6*OCT,   0, 8
        SNOTE   1,  6, NT_C+5*OCT,   0, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   0, 4
        SNOTE   1,  6, NT_C+5*OCT,   1, 4
        SNOTE   2,  9, NT_GS+6*OCT,  0, 8
        SNOTE   0,  9, NT_F+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+5*OCT,   1, 8
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   0,  9, REST,         1, 8
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   2,  6, NT_DS+6*OCT,  0, 4
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   1,  9, NT_DS+5*OCT,  0, 8
        SNOTE   0,  9, NT_C+4*OCT,   1, 8
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   0,  9, REST,         1, 8
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   2,  6, NT_DS+6*OCT,  0, 4
        SNOTE   1,  6, NT_DS+5*OCT,  0, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   1,  9, NT_DS+5*OCT,  0, 8
        SNOTE   0,  9, NT_C+4*OCT,   1, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2,  9, NT_F+7*OCT,   0, 8
        SNOTE   1,  6, NT_C+5*OCT,   0, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   0, 4
        SNOTE   1,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  9, NT_F+4*OCT,   0, 8
        SNOTE   2,  9, NT_GS+7*OCT,  0, 8
        SNOTE   1,  9, NT_C+5*OCT,   1, 8
        SWAIT   0
tuneA22_v0:
        SCALL   musicSetupA
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   1, 4
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   1, 4
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   1, 4
        SNOTE   0,  6, NT_GS+3*OCT,  1, 4
        SNOTE   0,  6, NT_AS+3*OCT,  1, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   0,  6, NT_D+4*OCT,   1, 4
        SNOTE   0,  6, NT_DS+4*OCT,  1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  6, NT_D+5*OCT,   1, 4
        SNOTE   0,  6, NT_DS+5*OCT,  1, 4
        SNOTE   0,  6, NT_F+5*OCT,   1, 4
        SNOTE   2, 17, NT_D+6*OCT,   0, 48
        SNOTE   1, 17, NT_C+6*OCT,   0, 48
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   1, 4
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   1, 4
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   1, 4
        SNOTE   0,  6, NT_GS+3*OCT,  1, 4
        SNOTE   0,  6, NT_AS+3*OCT,  1, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   0,  6, NT_D+4*OCT,   1, 4
        SNOTE   0,  6, NT_DS+4*OCT,  1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   2, 17, NT_D+6*OCT,   0, 48
        SNOTE   1, 17, NT_B+5*OCT,   0, 48
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  6, NT_D+5*OCT,   1, 4
        SNOTE   0,  6, NT_DS+5*OCT,  1, 4
        SNOTE   0,  6, NT_F+5*OCT,   1, 4
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   1, 11, NT_C+6*OCT,   0, 12
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   1, 4
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   1, 4
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   1, 11, NT_C+6*OCT,   0, 12
        SNOTE   0,  6, NT_GS+3*OCT,  1, 4
        SNOTE   0,  6, NT_AS+3*OCT,  1, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   0,  6, NT_D+4*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   0,  6, NT_DS+4*OCT,  1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   1, 11, NT_B+5*OCT,   0, 12
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   0, 8
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   1, 11, NT_B+5*OCT,   0, 12
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  6, NT_D+5*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   0, 8
        SNOTE   0,  6, NT_DS+5*OCT,  1, 4
        SNOTE   0,  6, NT_F+5*OCT,   1, 4
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   1, 11, NT_C+6*OCT,   0, 12
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   1, 4
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   0,  6, NT_G+3*OCT,   1, 4
        SNOTE   0,  6, NT_F+3*OCT,   1, 4
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   1, 11, NT_C+6*OCT,   0, 12
        SNOTE   0,  6, NT_GS+3*OCT,  1, 4
        SNOTE   0,  6, NT_AS+3*OCT,  1, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   0,  6, NT_D+4*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   0,  6, NT_DS+4*OCT,  1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   1, 11, NT_B+5*OCT,   0, 12
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   0, 8
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   1, 11, NT_B+5*OCT,   0, 12
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  6, NT_D+5*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   0, 8
        SNOTE   0,  6, NT_DS+5*OCT,  1, 4
        SNOTE   0,  6, NT_F+5*OCT,   1, 4
        SWAIT   0
tuneA23_v0:
        SCALL   musicSetupA
        SNOTE   2, 12, NT_C+6*OCT,   0, 16
        SNOTE   0, 11, NT_C+3*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   0,  9, NT_C+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_DS+6*OCT,  1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 11, NT_C+3*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   0,  9, NT_C+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_C+3*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   0,  9, NT_C+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_C+3*OCT,   0, 12
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   2,  9, NT_F+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+4*OCT,   1, 4
        SNOTE   0,  9, NT_C+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_DS+6*OCT,  1, 8
        SNOTE   2, 12, NT_F+6*OCT,   0, 16
        SNOTE   0, 11, NT_AS+3*OCT,  0, 12
        SNOTE   1,  9, NT_D+5*OCT,   1, 8
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  9, NT_AS+3*OCT,  0, 8
        SNOTE   1,  9, NT_AS+5*OCT,  0, 8
        SNOTE   2,  9, NT_D+6*OCT,   1, 8
        SNOTE   2, 17, NT_AS+6*OCT,  0, 48
        SNOTE   0, 11, NT_AS+3*OCT,  0, 12
        SNOTE   1,  9, NT_D+5*OCT,   1, 8
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  9, NT_AS+3*OCT,  0, 8
        SNOTE   1,  9, NT_AS+5*OCT,  1, 8
        SNOTE   0, 11, NT_AS+3*OCT,  0, 12
        SNOTE   1,  9, NT_D+5*OCT,   1, 8
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  9, NT_AS+3*OCT,  0, 8
        SNOTE   1,  9, NT_AS+5*OCT,  1, 8
        SNOTE   0, 11, NT_AS+3*OCT,  0, 12
        SNOTE   2,  9, NT_D+7*OCT,   0, 8
        SNOTE   1,  9, NT_D+5*OCT,   1, 8
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   2,  9, NT_C+7*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  9, NT_AS+3*OCT,  0, 8
        SNOTE   1,  9, NT_AS+5*OCT,  0, 8
        SNOTE   2,  9, NT_AS+6*OCT,  1, 8
        SNOTE   0, 11, NT_A+3*OCT,   0, 12
        SNOTE   2,  9, NT_C+7*OCT,   0, 8
        SNOTE   1,  9, NT_A+5*OCT,   1, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_A+4*OCT,   1, 4
        SNOTE   0,  9, NT_A+3*OCT,   0, 8
        SNOTE   1,  9, NT_A+5*OCT,   0, 8
        SNOTE   2,  9, NT_F+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 11, NT_G+3*OCT,   0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_G+3*OCT,   0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 11, NT_G+3*OCT,   0, 12
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   0, 11, NT_G+3*OCT,   0, 12
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   2, 12, NT_GS+6*OCT,  0, 16
        SNOTE   0, 11, NT_GS+3*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2, 17, NT_DS+7*OCT,  0, 48
        SNOTE   0, 11, NT_GS+3*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_GS+3*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0,  9, NT_CS+3*OCT,  0, 8
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   0,  9, NT_F+3*OCT,   0, 8
        SNOTE   1,  9, NT_GS+5*OCT,  0, 8
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_CS+7*OCT,  1, 8
        SNOTE   2, 12, NT_DS+7*OCT,  0, 16
        SNOTE   0, 11, NT_GS+3*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2, 17, NT_GS+6*OCT,  0, 48
        SNOTE   0, 11, NT_GS+3*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_GS+3*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0,  9, NT_CS+3*OCT,  0, 8
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   0,  9, NT_F+3*OCT,   0, 8
        SNOTE   1,  9, NT_GS+5*OCT,  0, 8
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_CS+7*OCT,  1, 8
        SNOTE   0, 11, NT_GS+3*OCT,  0, 12
        SNOTE   2,  9, NT_DS+7*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   2,  9, NT_C+7*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_GS+6*OCT,  1, 8
        SNOTE   0,  9, NT_CS+3*OCT,  0, 8
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   0,  9, NT_F+3*OCT,   0, 8
        SNOTE   1,  9, NT_GS+5*OCT,  0, 8
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_CS+7*OCT,  1, 8
        SNOTE   0, 11, NT_G+3*OCT,   0, 12
        SNOTE   2,  9, NT_DS+7*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   2,  9, NT_C+7*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_GS+6*OCT,  1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 11, NT_G+3*OCT,   0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_G+3*OCT,   0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_G+3*OCT,   0, 12
        SNOTE   2,  9, NT_D+7*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   2,  9, NT_B+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 11, NT_G+3*OCT,   0, 12
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   0, 11, NT_G+3*OCT,   0, 12
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SWAIT   0
tuneA24_v0:
        SCALL   musicSetupA
        SNOTE   0, 11, NT_C+3*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+4*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0, 11, NT_C+3*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+4*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0,  9, NT_F+3*OCT,   0, 8
        SNOTE   1,  9, NT_GS+5*OCT,  0, 8
        SNOTE   2,  9, NT_C+6*OCT,   1, 8
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_F+6*OCT,   1, 8
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_F+6*OCT,   0, 8
        SNOTE   2,  9, NT_GS+6*OCT,  1, 8
        SNOTE   0, 11, NT_C+3*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+4*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0, 11, NT_C+3*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+4*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0,  9, NT_F+3*OCT,   0, 8
        SNOTE   1,  9, NT_GS+5*OCT,  0, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_F+6*OCT,   0, 8
        SNOTE   2,  9, NT_GS+7*OCT,  1, 8
        SNOTE   0, 11, NT_C+3*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+4*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0, 11, NT_C+3*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+4*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0,  9, NT_F+3*OCT,   0, 8
        SNOTE   1,  9, NT_A+5*OCT,   0, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   0,  9, NT_A+3*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_F+6*OCT,   0, 8
        SNOTE   2,  9, NT_GS+7*OCT,  1, 8
        SNOTE   1, 17, NT_C+6*OCT,   0, 48
        SNOTE   2, 17, NT_GS+7*OCT,  0, 48
        SNOTE   0, 12, NT_GS+3*OCT,  1, 16
        SNOTE   0,  9, NT_GS+3*OCT,  1, 8
        SNOTE   0, 12, NT_GS+3*OCT,  1, 16
        SNOTE   0,  9, NT_GS+3*OCT,  1, 8
        SNOTE   0, 12, NT_GS+3*OCT,  1, 16
        SWAIT   0
tuneA25_v0:
        SCALL   musicSetupA
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_DS+6*OCT,  1, 8
        SNOTE   0, 12, NT_GS+3*OCT,  0, 16
        SNOTE   2, 11, NT_E+6*OCT,   0, 12
        SNOTE   1, 11, NT_CS+6*OCT,  1, 12
        SNOTE   2,  6, NT_FS+6*OCT,  1, 4
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_GS+6*OCT,  1, 8
        SNOTE   1, 15, NT_C+6*OCT,   0, 32
        SNOTE   2, 15, NT_DS+6*OCT,  0, 32
        SNOTE   0, 12, NT_GS+3*OCT,  1, 16
        SNOTE   0,  9, NT_GS+3*OCT,  1, 8
        SNOTE   0, 12, NT_GS+3*OCT,  1, 16
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_DS+6*OCT,  1, 8
        SNOTE   0, 12, NT_GS+3*OCT,  0, 16
        SNOTE   2, 11, NT_E+6*OCT,   0, 12
        SNOTE   1, 11, NT_CS+6*OCT,  1, 12
        SNOTE   2,  6, NT_FS+6*OCT,  1, 4
        SNOTE   0,  9, NT_GS+3*OCT,  0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_GS+6*OCT,  1, 8
        SNOTE   1, 14, NT_DS+6*OCT,  0, 24
        SNOTE   0, 11, NT_B+3*OCT,   0, 12
        SNOTE   2,  9, NT_FS+6*OCT,  1, 8
        SNOTE   2,  9, NT_B+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_CS+4*OCT,  1, 4
        SNOTE   2,  9, NT_B+6*OCT,   0, 8
        SNOTE   0,  9, NT_DS+4*OCT,  1, 8
        SNOTE   0, 14, NT_E+4*OCT,   0, 24
        SNOTE   1, 14, NT_B+5*OCT,   0, 24
        SNOTE   2, 11, NT_GS+6*OCT,  1, 12
        SNOTE   2,  6, NT_FS+6*OCT,  1, 4
        SNOTE   2,  9, NT_E+6*OCT,   1, 8
        SNOTE   0, 14, NT_C+4*OCT,   0, 24
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   1,  9, NT_E+6*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   2,  9, NT_FS+6*OCT,  1, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_E+6*OCT,   1, 8
        SNOTE   0, 14, NT_B+3*OCT,   0, 24
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   2,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+5*OCT,   0, 8
        SNOTE   2,  9, NT_G+5*OCT,   1, 8
        SNOTE   1, 15, NT_CS+6*OCT,  0, 32
        SNOTE   2, 15, NT_E+6*OCT,   0, 32
        SNOTE   0, 12, NT_A+3*OCT,   1, 16
        SNOTE   0,  9, NT_A+3*OCT,   1, 8
        SNOTE   0, 12, NT_A+3*OCT,   1, 16
        SNOTE   0,  9, NT_A+3*OCT,   0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_E+6*OCT,   1, 8
        SNOTE   0, 12, NT_A+3*OCT,   0, 16
        SNOTE   2, 11, NT_F+6*OCT,   0, 12
        SNOTE   1, 11, NT_D+6*OCT,   1, 12
        SNOTE   2,  6, NT_G+6*OCT,   1, 4
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   0,  9, NT_A+3*OCT,   1, 8
        SNOTE   1, 15, NT_CS+6*OCT,  0, 32
        SNOTE   2, 15, NT_E+6*OCT,   0, 32
        SNOTE   0, 12, NT_A+3*OCT,   1, 16
        SNOTE   0,  9, NT_A+3*OCT,   1, 8
        SNOTE   0, 12, NT_A+3*OCT,   1, 16
        SNOTE   0,  9, NT_A+3*OCT,   0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_E+6*OCT,   1, 8
        SNOTE   1, 11, NT_D+6*OCT,   0, 12
        SNOTE   2, 11, NT_F+6*OCT,   0, 12
        SNOTE   0,  9, NT_D+4*OCT,   1, 8
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_G+6*OCT,   1, 4
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   0,  9, NT_AS+3*OCT,  1, 8
        SNOTE   2, 15, NT_E+6*OCT,   0, 32
        SNOTE   1, 15, NT_CS+6*OCT,  0, 32
        SNOTE   0, 12, NT_A+3*OCT,   1, 16
        SNOTE   0,  9, NT_A+3*OCT,   1, 8
        SNOTE   0, 12, NT_A+3*OCT,   1, 16
        SNOTE   0,  9, NT_A+3*OCT,   0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_E+6*OCT,   1, 8
        SNOTE   0, 14, NT_G+3*OCT,   0, 24
        SNOTE   1, 11, NT_D+6*OCT,   0, 12
        SNOTE   2,  9, NT_FS+6*OCT,  1, 8
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   1,  9, NT_A+5*OCT,   0, 8
        SNOTE   2,  9, NT_FS+6*OCT,  1, 8
        SNOTE   1, 14, NT_CS+6*OCT,  0, 24
        SNOTE   2, 14, NT_E+6*OCT,   0, 24
        SNOTE   0, 12, NT_A+3*OCT,   1, 16
        SNOTE   0,  9, NT_A+3*OCT,   1, 8
        SNOTE   1, 11, NT_D+6*OCT,   0, 12
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   2,  9, NT_FS+6*OCT,  1, 8
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   0,  9, NT_D+4*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   1,  9, NT_A+5*OCT,   0, 8
        SNOTE   2,  9, NT_FS+6*OCT,  0, 8
        SNOTE   0,  9, NT_G+4*OCT,   1, 8
        SNOTE   2, 17, NT_E+6*OCT,   0, 48
        SNOTE   1, 12, NT_B+5*OCT,   0, 16
        SNOTE   0,  9, NT_B+3*OCT,   1, 8
        SNOTE   0,  9, NT_FS+4*OCT,  1, 8
        SNOTE   0,  9, NT_B+4*OCT,   1, 8
        SNOTE   1, 12, NT_A+5*OCT,   0, 16
        SNOTE   0,  9, NT_B+3*OCT,   1, 8
        SNOTE   0,  9, NT_FS+4*OCT,  1, 8
        SNOTE   0,  9, NT_B+4*OCT,   1, 8
        SNOTE   2, 17, NT_DS+6*OCT,  0, 48
        SNOTE   1, 12, NT_G+5*OCT,   0, 16
        SNOTE   0,  9, NT_B+3*OCT,   1, 8
        SNOTE   0,  9, NT_FS+4*OCT,  1, 8
        SNOTE   0,  9, NT_B+4*OCT,   1, 8
        SNOTE   1, 12, NT_FS+5*OCT,  0, 16
        SNOTE   0,  9, NT_B+3*OCT,   1, 8
        SNOTE   0,  9, NT_FS+4*OCT,  1, 8
        SNOTE   0,  9, NT_B+4*OCT,   1, 8
        SWAIT   0
tuneA26_v0:
        SCALL   musicSetupA
        SNOTE   2, 11, NT_B+5*OCT,   0, 12
        SNOTE   0, 11, NT_E+3*OCT,   0, 12
        SNOTE   1, 11, NT_G+5*OCT,   0, 12
        SNOTE   0,  9, REST,         1, 8
        SNOTE   0,  9, NT_B+3*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_E+6*OCT,   0, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   0,  9, NT_E+4*OCT,   0, 8
        SNOTE   1,  9, NT_E+6*OCT,   1, 8
        SNOTE   2,  9, NT_FS+6*OCT,  0, 8
        SNOTE   0,  9, NT_FS+3*OCT,  0, 8
        SNOTE   1,  9, NT_DS+6*OCT,  1, 8
        SNOTE   2,  9, NT_E+6*OCT,   0, 8
        SNOTE   0,  9, NT_B+3*OCT,   0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  1, 8
        SNOTE   2,  9, NT_FS+6*OCT,  0, 8
        SNOTE   0,  9, NT_FS+4*OCT,  0, 8
        SNOTE   1,  9, NT_DS+6*OCT,  1, 8
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1, 11, NT_D+6*OCT,   0, 12
        SNOTE   0,  9, NT_G+3*OCT,   0, 8
        SNOTE   0,  9, REST,         1, 8
        SNOTE   0,  9, NT_D+4*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_FS+6*OCT,  0, 4
        SNOTE   1,  6, NT_D+6*OCT,   1, 4
        SNOTE   2,  9, NT_E+6*OCT,   0, 8
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_D+6*OCT,   1, 8
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  9, NT_A+3*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   2,  9, NT_C+6*OCT,   0, 8
        SNOTE   0,  9, NT_E+4*OCT,   0, 8
        SNOTE   1,  9, NT_A+5*OCT,   1, 8
        SNOTE   2,  9, NT_A+5*OCT,   0, 8
        SNOTE   0,  9, NT_A+4*OCT,   0, 8
        SNOTE   1,  9, NT_FS+5*OCT,  1, 8
        SNOTE   2, 11, NT_B+5*OCT,   0, 12
        SNOTE   1, 11, NT_G+5*OCT,   0, 12
        SNOTE   0,  9, NT_B+3*OCT,   0, 8
        SNOTE   0,  9, REST,         1, 8
        SNOTE   0,  9, NT_B+4*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_E+6*OCT,   0, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   0,  9, NT_B+3*OCT,   0, 8
        SNOTE   1,  9, NT_E+6*OCT,   1, 8
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_FS+6*OCT,  1, 8
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   0,  9, NT_C+5*OCT,   0, 8
        SNOTE   1,  9, NT_E+6*OCT,   1, 8
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_FS+6*OCT,  1, 8
        SNOTE   2, 17, NT_B+6*OCT,   0, 48
        SNOTE   1, 14, NT_E+6*OCT,   0, 24
        SNOTE   0, 11, NT_B+3*OCT,   1, 12
        SNOTE   0,  6, NT_B+4*OCT,   1, 4
        SNOTE   0,  9, NT_B+3*OCT,   1, 8
        SNOTE   1, 14, NT_DS+6*OCT,  0, 24
        SNOTE   0, 11, NT_B+3*OCT,   1, 12
        SNOTE   0,  6, NT_B+4*OCT,   1, 4
        SNOTE   0,  9, NT_B+3*OCT,   1, 8
        SNOTE   0, 12, NT_C+4*OCT,   0, 16
        SNOTE   1, 12, NT_E+6*OCT,   0, 16
        SNOTE   2, 11, NT_B+6*OCT,   1, 12
        SNOTE   2,  6, NT_B+6*OCT,   1, 4
        SNOTE   2,  9, NT_B+6*OCT,   1, 8
        SNOTE   0, 12, NT_G+3*OCT,   0, 16
        SNOTE   1, 12, NT_D+6*OCT,   0, 16
        SNOTE   2,  9, NT_B+6*OCT,   1, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   2,  9, NT_A+6*OCT,   1, 8
        SNOTE   0, 12, NT_C+4*OCT,   0, 16
        SNOTE   1, 12, NT_E+6*OCT,   0, 16
        SNOTE   2, 11, NT_B+6*OCT,   1, 12
        SNOTE   2,  6, NT_B+6*OCT,   1, 4
        SNOTE   2,  9, NT_B+6*OCT,   1, 8
        SNOTE   0, 12, NT_G+3*OCT,   0, 16
        SNOTE   1, 12, NT_D+6*OCT,   0, 16
        SNOTE   2,  9, NT_B+6*OCT,   1, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   2,  9, NT_A+6*OCT,   1, 8
        SNOTE   0, 12, NT_C+4*OCT,   0, 16
        SNOTE   1, 12, NT_E+6*OCT,   0, 16
        SNOTE   2, 11, NT_B+6*OCT,   1, 12
        SNOTE   2,  6, NT_A+6*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0, 12, NT_C+4*OCT,   0, 16
        SNOTE   1, 12, NT_E+6*OCT,   0, 16
        SNOTE   2,  9, NT_A+6*OCT,   1, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   2,  9, NT_E+6*OCT,   1, 8
        SNOTE   0, 17, NT_B+3*OCT,   0, 48
        SNOTE   2, 17, NT_FS+6*OCT,  0, 48
        SNOTE   1,  6, NT_DS+6*OCT,  1, 4
        SNOTE   1,  6, NT_DS+4*OCT,  1, 4
        SNOTE   1,  6, NT_FS+4*OCT,  1, 4
        SNOTE   1,  6, NT_A+4*OCT,   1, 4
        SNOTE   1,  6, NT_B+4*OCT,   1, 4
        SNOTE   1,  6, NT_DS+5*OCT,  1, 4
        SNOTE   1,  6, NT_FS+5*OCT,  1, 4
        SNOTE   1,  6, NT_A+5*OCT,   1, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   1,  6, NT_DS+6*OCT,  1, 4
        SNOTE   1,  6, NT_FS+6*OCT,  1, 4
        SNOTE   1,  6, NT_A+6*OCT,   1, 4
        SWAIT   0
tuneA27_v0:
        SCALL   musicSetupA
        SNOTE   2, 14, NT_B+6*OCT,   0, 24
        SNOTE   1, 14, NT_G+6*OCT,   0, 24
        SNOTE   0, 11, NT_B+4*OCT,   1, 12
        SNOTE   0,  6, NT_E+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+5*OCT,   1, 8
        SNOTE   2, 14, NT_B+6*OCT,   0, 24
        SNOTE   1, 14, NT_A+6*OCT,   0, 24
        SNOTE   0,  9, NT_FS+5*OCT,  1, 8
        SNOTE   0,  9, NT_E+5*OCT,   1, 8
        SNOTE   0,  9, NT_FS+5*OCT,  1, 8
        SNOTE   2, 14, NT_B+6*OCT,   0, 24
        SNOTE   1, 14, NT_G+6*OCT,   0, 24
        SNOTE   0, 11, NT_G+5*OCT,   1, 12
        SNOTE   0,  6, NT_B+4*OCT,   1, 4
        SNOTE   0,  9, NT_E+5*OCT,   1, 8
        SNOTE   2, 14, NT_C+7*OCT,   0, 24
        SNOTE   1, 14, NT_A+6*OCT,   0, 24
        SNOTE   0,  9, NT_D+5*OCT,   1, 8
        SNOTE   0,  9, NT_C+5*OCT,   1, 8
        SNOTE   0,  9, NT_A+4*OCT,   1, 8
        SNOTE   2, 14, NT_B+6*OCT,   0, 24
        SNOTE   1, 14, NT_G+6*OCT,   0, 24
        SNOTE   0, 11, NT_B+4*OCT,   1, 12
        SNOTE   0,  6, NT_E+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+5*OCT,   1, 8
        SNOTE   2, 14, NT_C+7*OCT,   0, 24
        SNOTE   1, 14, NT_G+6*OCT,   0, 24
        SNOTE   0,  9, NT_A+5*OCT,   1, 8
        SNOTE   0,  9, NT_G+5*OCT,   1, 8
        SNOTE   0,  9, NT_A+5*OCT,   1, 8
        SNOTE   0, 17, NT_B+5*OCT,   0, 48
        SNOTE   1, 14, NT_G+6*OCT,   0, 24
        SNOTE   2, 14, NT_B+6*OCT,   1, 24
        SNOTE   2, 14, NT_B+6*OCT,   0, 24
        SNOTE   1, 14, NT_FS+6*OCT,  1, 24
        SNOTE   0, 12, NT_C+4*OCT,   0, 16
        SNOTE   2, 11, NT_B+6*OCT,   0, 12
        SNOTE   1,  6, NT_E+5*OCT,   1, 4
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   1,  6, NT_E+5*OCT,   0, 4
        SNOTE   2,  6, NT_E+7*OCT,   1, 4
        SNOTE   2,  9, NT_B+6*OCT,   0, 8
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   0, 12, NT_G+3*OCT,   0, 16
        SNOTE   2,  9, NT_D+7*OCT,   0, 8
        SNOTE   1,  6, NT_D+5*OCT,   1, 4
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   2,  9, NT_B+6*OCT,   0, 8
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   1,  6, NT_D+5*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   0, 12, NT_C+4*OCT,   0, 16
        SNOTE   2, 11, NT_E+6*OCT,   0, 12
        SNOTE   1,  6, NT_E+5*OCT,   1, 4
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   1,  6, NT_E+5*OCT,   0, 4
        SNOTE   2,  6, NT_G+6*OCT,   1, 4
        SNOTE   2,  9, NT_C+7*OCT,   0, 8
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   0, 12, NT_G+3*OCT,   0, 16
        SNOTE   2,  9, NT_B+6*OCT,   0, 8
        SNOTE   1,  6, NT_D+5*OCT,   1, 4
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   1,  6, NT_D+5*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   1, 12, NT_AS+5*OCT,  0, 16
        SNOTE   2, 11, NT_A+6*OCT,   1, 12
        SNOTE   2,  6, NT_D+7*OCT,   1, 4
        SNOTE   2,  9, NT_A+6*OCT,   1, 8
        SNOTE   1, 12, NT_F+5*OCT,   0, 16
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2,  9, NT_A+6*OCT,   1, 8
        SNOTE   2,  9, NT_F+6*OCT,   1, 8
        SNOTE   1, 12, NT_AS+5*OCT,  0, 16
        SNOTE   2, 11, NT_D+6*OCT,   1, 12
        SNOTE   2,  6, NT_F+6*OCT,   1, 4
        SNOTE   2,  9, NT_AS+6*OCT,  1, 8
        SNOTE   1, 12, NT_F+5*OCT,   0, 16
        SNOTE   2,  9, NT_A+6*OCT,   1, 8
        SNOTE   2,  9, NT_F+6*OCT,   1, 8
        SNOTE   2,  9, NT_C+6*OCT,   1, 8
        SWAIT   0
tuneA28_v0:
        SCALL   musicSetupA
        SNOTE   0, 14, NT_D+4*OCT,   0, 24
        SNOTE   1, 14, NT_AS+5*OCT,  0, 24
        SNOTE   2, 11, NT_A+6*OCT,   1, 12
        SNOTE   2,  6, NT_F+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   1, 12, NT_B+5*OCT,   0, 16
        SNOTE   0, 12, NT_D+3*OCT,   1, 16
        SNOTE   0,  9, NT_D+3*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   0, 12, NT_D+3*OCT,   0, 16
        SNOTE   1, 12, NT_B+5*OCT,   1, 16
        SNOTE   0,  9, NT_D+3*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   0, 14, NT_D+4*OCT,   0, 24
        SNOTE   1, 14, NT_AS+5*OCT,  0, 24
        SNOTE   2, 11, NT_A+6*OCT,   1, 12
        SNOTE   2,  6, NT_F+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   1, 12, NT_B+5*OCT,   0, 16
        SNOTE   0, 12, NT_D+3*OCT,   1, 16
        SNOTE   0,  9, NT_D+3*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   0, 12, NT_D+3*OCT,   0, 16
        SNOTE   1, 12, NT_B+5*OCT,   1, 16
        SNOTE   0,  9, NT_D+3*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   2, 11, NT_A+6*OCT,   0, 12
        SNOTE   1,  9, NT_D+5*OCT,   1, 8
        SNOTE   0, 12, NT_AS+3*OCT,  0, 16
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_F+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_AS+5*OCT,  1, 8
        SNOTE   2, 11, NT_AS+6*OCT,  0, 12
        SNOTE   1,  9, NT_D+5*OCT,   1, 8
        SNOTE   0, 12, NT_G+3*OCT,   0, 16
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_G+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_AS+5*OCT,  1, 8
        SNOTE   2, 11, NT_B+6*OCT,   0, 12
        SNOTE   1,  9, NT_D+5*OCT,   1, 8
        SNOTE   0, 12, NT_G+4*OCT,   0, 16
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_G+6*OCT,   1, 4
        SNOTE   2,  9, NT_F+6*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   2, 11, NT_C+7*OCT,   0, 12
        SNOTE   1,  9, NT_E+5*OCT,   1, 8
        SNOTE   0, 12, NT_C+4*OCT,   0, 16
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_G+6*OCT,   1, 4
        SNOTE   2,  9, NT_F+6*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   2, 11, NT_CS+7*OCT,  0, 12
        SNOTE   1,  9, NT_E+5*OCT,   1, 8
        SNOTE   0, 12, NT_A+3*OCT,   0, 16
        SNOTE   1,  9, NT_A+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_A+6*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  1, 8
        SNOTE   2, 11, NT_D+7*OCT,   0, 12
        SNOTE   1,  9, NT_F+5*OCT,   1, 8
        SNOTE   0, 12, NT_D+4*OCT,   0, 16
        SNOTE   1,  9, NT_A+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_A+6*OCT,   1, 4
        SNOTE   2,  9, NT_F+6*OCT,   0, 8
        SNOTE   1,  9, NT_D+6*OCT,   1, 8
        SNOTE   2,  9, NT_E+7*OCT,   0, 8
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_A+6*OCT,   1, 8
        SNOTE   0, 11, NT_AS+3*OCT,  0, 12
        SNOTE   1,  9, NT_G+6*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   2,  9, NT_G+7*OCT,   0, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   2,  9, NT_GS+7*OCT,  0, 8
        SNOTE   0,  9, NT_AS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 14, NT_A+3*OCT,   0, 24
        SNOTE   1, 11, NT_CS+6*OCT,  0, 12
        SNOTE   2, 11, NT_A+7*OCT,   1, 12
        SNOTE   2,  6, NT_A+6*OCT,   0, 4
        SNOTE   1,  6, NT_CS+6*OCT,  1, 4
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  1, 8
        SNOTE   0, 14, NT_AS+3*OCT,  0, 24
        SNOTE   1, 11, NT_D+6*OCT,   0, 12
        SNOTE   2, 11, NT_A+7*OCT,   1, 12
        SNOTE   2,  6, NT_A+6*OCT,   0, 4
        SNOTE   1,  6, NT_D+6*OCT,   1, 4
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   1,  9, NT_D+6*OCT,   1, 8
        SNOTE   0, 11, NT_A+3*OCT,   0, 12
        SNOTE   1, 11, NT_CS+6*OCT,  0, 12
        SNOTE   2, 11, NT_A+7*OCT,   1, 12
        SNOTE   2,  6, NT_A+6*OCT,   0, 4
        SNOTE   0,  6, NT_B+3*OCT,   0, 4
        SNOTE   1,  6, NT_CS+6*OCT,  1, 4
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   0,  9, NT_CS+4*OCT,  1, 8
        SNOTE   2,  9, NT_D+7*OCT,   0, 8
        SNOTE   1,  9, NT_F+6*OCT,   0, 8
        SNOTE   0,  9, NT_D+4*OCT,   1, 8
        SNOTE   0, 11, NT_AS+3*OCT,  0, 12
        SNOTE   1,  9, NT_E+6*OCT,   0, 8
        SNOTE   2,  9, NT_E+7*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  9, NT_AS+3*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+7*OCT,   1, 8
        SNOTE   0, 14, NT_A+3*OCT,   0, 24
        SNOTE   1, 11, NT_CS+6*OCT,  0, 12
        SNOTE   2, 11, NT_A+7*OCT,   1, 12
        SNOTE   2,  6, NT_A+6*OCT,   0, 4
        SNOTE   1,  6, NT_CS+6*OCT,  1, 4
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  1, 8
        SNOTE   0, 14, NT_AS+3*OCT,  0, 24
        SNOTE   1, 11, NT_D+6*OCT,   0, 12
        SNOTE   2, 11, NT_A+7*OCT,   1, 12
        SNOTE   2,  6, NT_A+6*OCT,   0, 4
        SNOTE   1,  6, NT_D+6*OCT,   1, 4
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   1,  9, NT_D+6*OCT,   1, 8
        SNOTE   2, 11, NT_A+7*OCT,   0, 12
        SNOTE   0, 11, NT_A+3*OCT,   0, 12
        SNOTE   1, 11, NT_CS+6*OCT,  1, 12
        SNOTE   2,  6, NT_A+6*OCT,   0, 4
        SNOTE   0,  6, NT_B+3*OCT,   0, 4
        SNOTE   1,  6, NT_CS+6*OCT,  1, 4
        SNOTE   2,  9, NT_A+6*OCT,   0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   0,  9, NT_CS+4*OCT,  1, 8
        SNOTE   0,  9, NT_D+4*OCT,   0, 8
        SNOTE   2,  9, NT_D+7*OCT,   0, 8
        SNOTE   1,  9, NT_F+6*OCT,   1, 8
        SWAIT   0
musicSetupA:
        SCLEAR  1
        SSET    vfTranspose,     0FFE8h
        SSET    vfEnvBase,       musicSetupA_env_v1
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      28h
        SSET    vfLfoRate,       12Ch
        SCLEAR  2
        SSET    vfTranspose,     0FFE8h
        SSET    vfReleaseLead,   5
        SSET    vfEnvBase,       musicSetupA_env_v2
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      14h
        SSET    vfLfoRate,       78h
        SCLEAR  0
        SSET    vfTranspose,     0FFE8h
        SSET    vfEnvBase,       musicSetupA_env_v0
        SSET    vfLfoTable,      lfoZero
        SSET    vfLfoWrap,       200h
        SSET    vfLfoDepth,      78h
        SSET    vfLfoRate,       80h
        SSET    vfTempo,         6
        SRET
musicSetupA_env_v2:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               0
        SENV    0,               0
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
musicSetupA_env_v1:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               16
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
musicSetupA_env_v0:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               8
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0

; Step the four speaker voices, then drive PIT channel 2 from the first of them
; that came out of voice_step with a level and a duration left.  One channel, so
; once spkrVoice is set the rest of the pass cannot claim it.
tick_spkr:
        mov     bx, ds:[curTune]
        cmp     bx, 0
        jz      spkr_set
        mov     ds:[spkrVoice], 0
        mov     ds:[voiceLeft], 4
        mov     si, offset spkrFreq
        mov     ds:[freqBase], si
        mov     si, offset spkrBlocks
        mov     ds:[voiceBase], si
spkr_loop:
        cmp     [si].vfDuration, 0
        jz      spkr_next
        call    voice_step
        cmp     ds:[spkrVoice], 0
        jnz     spkr_next
        cmp     [si].vfLevel, 0
        jz      spkr_next
        cmp     [si].vfDuration, 0
        jz      spkr_next
        mov     ds:[spkrVoice], si
spkr_next:
        add     si, SIZE VOICE
        dec     ds:[voiceLeft]
        jnz     spkr_loop
        mov     bl, ds:[outputOn]
        cmp     bl, 0
        jz      spkr_set
        mov     bx, ds:[spkrVoice]
        cmp     bx, 0
        jz      spkr_set
        mov     si, bx
        mov     ax, [si].vfOutPeriod
        PORT_OUT 42h
        mov     al, ah
        PORT_OUT 42h
        mov     bx, [si].vfLevel
        and     bl, 3                   ; the low two bits are the 61h gate bits
spkr_set:
        PORT_IN 61h
        and     al, 0FCh
        or      al, bl
        PORT_OUT 61h
        ret

; Pascal procedure ProgramSpeakerVoices(tuneId: Word): the speaker's tune, by program_voices.
ProgramSpeakerVoices:
        push    bp
        mov     bp, sp
        push    ax
        push    bx
        push    cx
        push    di
        push    si
        push    ds
        mov     bx, offset songTableA
        mov     cx, SONG_ROWS_A
        mov     di, offset spkrBlocks
        jmp     program_voices
