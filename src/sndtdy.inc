; ---------------------------------------------------------------------------
; The Tandy SN76489's part of the sequencer (phase 7 of docs/refactor-plan.md):
; its note table, voice blocks, song table and streams (three tone voices and a
; noise voice), the tick that writes the chip, and the entry that loads a tune.
; sounddrv.asm includes it.
; ---------------------------------------------------------------------------

; Tandy SN76489 periods with nominal note names starting at A2.
; Each 10-bit period is shifted left by six; tick_tandy shifts it back before output.
snA2    equ 0FFC0h   ; A2  n=1023
snAS2   equ 0F140h   ; A#2 n=965
snB2    equ 0E3C0h   ; B2  n=911
snC3    equ 0D700h   ; C3  n=860
snCS3   equ 0CB40h   ; C#3 n=813
snD3    equ 0BF80h   ; D3  n=766
snDS3   equ 0B4C0h   ; D#3 n=723
snE3    equ 0AA80h   ; E3  n=682
snF3    equ 0A100h   ; F3  n=644
snFS3   equ 9800h    ; F#3 n=608
snG3    equ 8F80h    ; G3  n=574
snGS3   equ 8740h    ; G#3 n=541

tandyBlocks     VOICE   <>
                VOICE   <>
                VOICE   <>
tandyVoice3     VOICE   <>              ; Fourth Tandy voice.

; Four unused Tandy voice blocks.
tandySpare      VOICE   <>
                VOICE   <>
                VOICE   <>
                VOICE   <>

tandyFreq       dw      snA2, snAS2, snB2, snC3, snCS3, snD3
                dw      snDS3, snE3, snF3, snFS3, snG3, snGS3

; Tandy rows include tone and noise streams.
songTableB      dw      silentB,     silentB,     silentB,     silentB      ; tune  0
                dw      tuneB01_v0,  tuneB01_v1,  tuneB01_v2,  silentB      ; tune  1
                dw      silentB,     silentB,     silentB,     tuneB02_v3   ; tune  2
                dw      tuneB03_v0,  tuneB03_v1,  tuneB03_v2,  silentB      ; tune  3
                dw      tuneB04_v0,  silentB,     tuneB04_v2,  tuneB04_v3   ; tune  4
                dw      tuneB05_v0,  silentB,     silentB,     silentB      ; tune  5
                dw      silentB,     silentB,     tuneB06_v2,  tuneB06_v3   ; tune  6
                dw      tuneB07_v0,  tuneB07_v1,  silentB,     silentB      ; tune  7
                dw      silentB,     silentB,     silentB,     tuneB08_v3   ; tune  8
                dw      silentB,     silentB,     silentB,     tuneB09_v3   ; tune  9
                dw      silentB,     silentB,     tuneB10_v2,  tuneB10_v3   ; tune 10
                dw      tuneB11_v0,  tuneB11_v1,  tuneB11_v2,  silentB      ; tune 11
                dw      silentB,     silentB,     tuneB12_v2,  tuneB12_v3   ; tune 12
                dw      tuneB13_v0,  silentB,     tuneB13_v2,  tuneB13_v3   ; tune 13
                dw      silentB,     silentB,     tuneB14_v2,  tuneB14_v3   ; tune 14
                dw      silentB,     silentB,     tuneB15_v2,  tuneB15_v3   ; tune 15
                dw      silentB,     silentB,     tuneB16_v2,  tuneB16_v3   ; tune 16
                dw      silentB,     silentB,     tuneB17_v2,  silentB      ; tune 17
                dw      tuneB18_v0,  silentB,     tuneB18_v2,  tuneB18_v3   ; tune 18
                dw      tuneB19_v0,  silentB,     silentB,     silentB      ; tune 19
                dw      tuneB20_v0,  silentB,     silentB,     silentB      ; tune 20
                dw      tuneB21_v0,  silentB,     silentB,     silentB      ; tune 21
                dw      tuneB22_v0,  silentB,     silentB,     silentB      ; tune 22
                dw      tuneB23_v0,  silentB,     silentB,     silentB      ; tune 23
                dw      tuneB24_v0,  silentB,     silentB,     silentB      ; tune 24
                dw      tuneB25_v0,  silentB,     silentB,     silentB      ; tune 25
                dw      tuneB26_v0,  silentB,     silentB,     silentB      ; tune 26
                dw      tuneB27_v0,  silentB,     silentB,     silentB      ; tune 27
                dw      tuneB28_v0,  silentB,     silentB,     silentB      ; tune 28
SONG_ROWS_B     equ     ($ - songTableB) / 8

tuneB10_v2:
        SSET    vfPeriod,        0BB8h
        SWAIT   28
        SSET    vfPeriod,        3E80h
        SSET    vfPeriodAdd,     0FFE7h
        SWAIT   400
        SWAIT   0
tuneB10_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0EA60h
        SWAIT   28
        SSET    vfLevel,         0C350h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   400
        SSET    vfLevel,         0
        SWAIT   0
tuneB12_v2:
        SSET    vfPeriod,        0BB8h
        SWAIT   18
        SSET    vfPeriod,        3E80h
        SSET    vfPeriodAdd,     0FFE7h
        SWAIT   100
        SWAIT   0
tuneB12_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0EA60h
        SWAIT   18
        SSET    vfLevel,         0C350h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   100
        SSET    vfLevel,         0
        SWAIT   0
tuneB13_v2:
        SSET    vfPeriod,        2328h
        SSET    vfPeriodAdd,     0FFE7h
        SWAIT   25
        SWAIT   0
tuneB13_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0D6D8h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   25
        SSET    vfLevel,         0
        SWAIT   0
tuneB13_v0:
        SSET    vfPeriod,        0FA0h
        SSET    vfLevel,         9C40h
        SSET    vfLevelAdd,      0FF9Ch
        SSET    vfPeriodAdd,     0FF9Ch
        SWAIT   25
        SSET    vfLevel,         0
        SWAIT   0
tuneB18_v2:
        SSET    vfPeriod,        2710h
        SSET    vfPeriodAdd,     0FFE7h
        SWAIT   55
        SWAIT   0
tuneB18_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   55
        SSET    vfLevel,         0
        SWAIT   0
tuneB18_v0:
        SSET    vfPeriod,        1B58h
        SRET                            ; no SCALL to return to: the voice ends
tuneB16_v2:
        SSET    vfPeriod,        1F40h
        SWAIT   40
        SWAIT   0
tuneB16_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLoopCounterA,  4
tuneB16_v3_loop:
        SSET    vfLevel,         0D6D8h
        SWAIT   5
        SSET    vfLevel,         1
        SWAIT   5
        SLOOP   vfLoopCounterA, tuneB16_v3_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB17_v2:
        SSET    vfLoopCounterA,  20
tuneB17_v2_loop:
        SSET    vfPeriod,        1770h
        SSET    vfLevel,         0C350h
        SWAIT   1
        SSET    vfPeriod,        1388h
        SSET    vfLevel,         1
        SWAIT   1
        SSET    vfPeriod,        7530h
        SSET    vfLevel,         0C350h
        SWAIT   1
        SLOOP   vfLoopCounterA, tuneB17_v2_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB14_v2:
        SSET    vfPeriod,        0FA0h
        SWAIT   28
        SWAIT   0
tuneB14_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0C350h
        SWAIT   28
        SSET    vfLevel,         0
        SWAIT   0
tuneB15_v2:
        SSET    vfPeriod,        2710h
        SWAIT   5
        SSET    vfPeriod,        0FA0h
        SSET    vfPeriodAdd,     64h
        SWAIT   100
        SWAIT   0
tuneB15_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0EA60h
        SWAIT   5
        SSET    vfLevel,         0C350h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   100
        SSET    vfLevel,         0
        SWAIT   0
tuneB08_v3:
        SSET    vfPeriod,        100h
        SSET    vfLevel,         7530h
        SSET    vfLevelAdd,      3E8h
        SWAIT   20
        SSET    vfLevelAdd,      0FC18h
        SWAIT   40
        SSET    vfLevel,         0
        SWAIT   0
tuneB09_v3:
        SSET    vfPeriod,        180h
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0F254h
        SWAIT   16
        SSET    vfLevel,         0
        SWAIT   0
tuneB07_v1:
        SWAIT   4
tuneB07_v0:
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FF9Ch
        SSET    vfPeriod,        0FDE8h
        SSET    vfLoopCounterA,  30
tuneB07_v0_loop:
        SSET    vfPeriodAdd,     0FD8Ah
        SWAIT   12
        SSET    vfPeriodAdd,     276h
        SWAIT   8
        SLOOP   vfLoopCounterA, tuneB07_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB06_v2:
        SSET    vfPeriod,        7D0h
        SSET    vfPeriodAdd,     5Ah
        SWAIT   20
        SWAIT   0
tuneB06_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0F830h
        SWAIT   20
        SSET    vfLevel,         0
        SWAIT   0
tuneB05_v0:
        SSET    vfPeriod,        9C2h
        SSET    vfLevel,         7530h
        SSET    vfLoopCounterA,  12
tuneB05_v0_loop:
        SSET    vfPeriodAdd,     0FFF7h
        SWAIT   12
        SSET    vfPeriodAdd,     9
        SWAIT   8
        SLOOP   vfLoopCounterA, tuneB05_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB03_v2:
        SWAIT   20
tuneB03_v1:
        SWAIT   20
tuneB03_v0:
        SSET    vfPeriod,        98E3h
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FF38h
        SSET    vfPeriodAdd,     0FF4Eh
        SWAIT   200
        SSET    vfLevel,         0
        SWAIT   0
tuneB04_v0:
        SSET    vfLevel,         2710h
        SSET    vfLevelAdd,      1F4h
        SSET    vfPeriod,        0FA00h
        SSET    vfPeriodAdd,     0FF10h
        SWAIT   80
        SSET    vfLevelAdd,      0
        SSET    vfLoopCounterA,  44
tuneB04_v0_loop:
        SSET    vfPeriodAdd,     0FB50h
        SWAIT   2
        SSET    vfPeriodAdd,     4D8h
        SWAIT   2
        SLOOP   vfLoopCounterA, tuneB04_v0_loop
        SSET    vfLevelAdd,      0FE61h
        SSET    vfPeriodAdd,     3Ch
        SWAIT   120
        SSET    vfLevel,         0
        SWAIT   0
tuneB04_v2:
        SSET    vfPeriod,        1130h
        SSET    vfPeriodAdd,     0Bh
        SWAIT   188
        SSET    vfPeriodAdd,     0FFF5h
        SWAIT   188
        SWAIT   0
tuneB04_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         61A8h
        SSET    vfLevelAdd,      9Fh
        SWAIT   188
        SSET    vfLevelAdd,      0FF61h
        SWAIT   188
        SSET    vfLevel,         0
        SWAIT   0
tuneB02_v3:
        SSET    vfLevelAdd,      960h
        SSET    vfPeriod,        100h
        SWAIT   25
        SSET    vfLevelAdd,      0F6A0h
        SWAIT   25
        SSET    vfLevel,         0
        SWAIT   0
silentB:
        SSET    vfLevel,         0
        SWAIT   0
tuneB01_v0:
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FF15h
        SSET    vfPeriod,        1FE0h
        SSET    vfLoopCounterA,  6
tuneB01_v0_loop:
        SSET    vfPeriodAdd,     1Eh
        SWAIT   16
        SSET    vfPeriodAdd,     0FFE2h
        SWAIT   16
        SLOOP   vfLoopCounterA, tuneB01_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB01_v1:
        SSET    vfLevel,         0C350h
        SSET    vfLevelAdd,      0FF38h
        SSET    vfPeriod,        4010h
        SSET    vfLoopCounterA,  10
tuneB01_v1_loop:
        SSET    vfPeriodAdd,     42h
        SWAIT   8
        SSET    vfPeriodAdd,     0FFBEh
        SWAIT   8
        SLOOP   vfLoopCounterA, tuneB01_v1_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB01_v2:
        SSET    vfLevel,         0FDE8h
        SSET    vfLevelAdd,      0FED4h
        SSET    vfPeriod,        36B0h
        SSET    vfLoopCounterA,  8
tuneB01_v2_loop:
        SSET    vfPeriodAdd,     52h
        SWAIT   12
        SSET    vfPeriodAdd,     0FFB2h
        SWAIT   12
        SLOOP   vfLoopCounterA, tuneB01_v2_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB11_v0:
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FB50h
        SSET    vfPeriod,        34D0h
        SWAIT   30
        SSET    vfLevel,         0
        SWAIT   0
tuneB11_v1:
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FB50h
        SSET    vfPeriod,        8020h
        SWAIT   30
        SSET    vfLevel,         0
        SWAIT   0
tuneB11_v2:
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FB50h
        SSET    vfPeriod,        1770h
        SWAIT   10
        SSET    vfLevel,         0
        SWAIT   0
tuneB20_v0:
        SCALL   musicSetupB             ; the voices' setup, as the other tunes take it
        SWAIT   0
tuneB19_v0:
        SSET    vfPeriod,        1F40h
        SSET    vfLevel,         7530h
        SSET    vfPeriodAdd,     14h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   16
        SSET    vfLevel,         0
        SWAIT   0

; ---------------------------------------------------------------------------
; MUSIC.  Tunes 21-28 are eight pieces, the same score for both devices: the
; title theme, the battle opening and six more.  Each starts by calling its
; device's setup, which arranges voices 0-2 (transpose, envelope, LFO, release
; lead) and sets tempo 6, then plays chords across those voices from its
; voice-0 stream, and ends.
; ---------------------------------------------------------------------------

tuneB21_v0:
        SCALL   musicSetupB
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
        SNOTE   0,  6, NT_A+4*OCT,   1, 4
        SNOTE   1,  6, NT_F+5*OCT,   0, 4
        SNOTE   0,  6, NT_A+4*OCT,   1, 4
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   1, 12, NT_D+5*OCT,   0, 16
        SNOTE   0, 12, NT_G+4*OCT,   1, 16
        SNOTE   1,  6, NT_G+5*OCT,   0, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   1,  6, NT_G+5*OCT,   0, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0, 14, NT_G+4*OCT,   0, 24
        SNOTE   1, 14, NT_D+5*OCT,   1, 24
        SNOTE   2, 12, NT_GS+6*OCT,  1, 16
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2, 17, NT_DS+7*OCT,  0, 48
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+4*OCT,  0, 4
        SNOTE   1,  6, NT_C+5*OCT,   1, 4
        SNOTE   1,  6, NT_C+5*OCT,   0, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0, 15, NT_GS+4*OCT,  0, 32
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
        SNOTE   0,  6, NT_GS+4*OCT,  0, 4
        SNOTE   1,  6, NT_C+5*OCT,   1, 4
        SNOTE   1,  6, NT_C+5*OCT,   0, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   2, 17, NT_GS+6*OCT,  0, 48
        SNOTE   1, 12, NT_C+5*OCT,   0, 16
        SNOTE   0, 12, NT_GS+4*OCT,  1, 16
        SNOTE   0,  6, NT_GS+4*OCT,  0, 4
        SNOTE   1,  6, NT_C+5*OCT,   1, 4
        SNOTE   1,  6, NT_C+5*OCT,   0, 4
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   1, 15, NT_C+5*OCT,   0, 32
        SNOTE   0, 15, NT_GS+4*OCT,  0, 32
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
        SNOTE   0,  6, NT_G+4*OCT,   0, 4
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   1,  6, NT_G+5*OCT,   0, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0, 14, NT_G+4*OCT,   0, 24
        SNOTE   1, 14, NT_G+5*OCT,   1, 24
        SNOTE   2,  9, NT_D+7*OCT,   1, 8
        SNOTE   2,  9, NT_B+6*OCT,   1, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 12, REST,         1, 16
        SNOTE   0,  6, NT_G+4*OCT,   0, 4
        SNOTE   1,  6, NT_G+5*OCT,   1, 4
        SNOTE   1,  6, NT_G+5*OCT,   0, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0, 14, NT_G+4*OCT,   0, 24
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
tuneB22_v0:
        SCALL   musicSetupB
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
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  6, NT_F+5*OCT,   1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  6, NT_F+5*OCT,   1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  6, NT_F+5*OCT,   1, 4
        SNOTE   0,  6, NT_GS+5*OCT,  1, 4
        SNOTE   0,  6, NT_AS+5*OCT,  1, 4
        SNOTE   0,  6, NT_C+6*OCT,   1, 4
        SNOTE   0,  6, NT_D+6*OCT,   1, 4
        SNOTE   0,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  6, NT_F+6*OCT,   1, 4
        SNOTE   2, 17, NT_D+6*OCT,   0, 48
        SNOTE   1, 17, NT_C+6*OCT,   0, 48
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
        SNOTE   1, 14, NT_C+6*OCT,   0, 24
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   1, 14, NT_C+6*OCT,   0, 24
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  6, NT_D+5*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   0,  6, NT_DS+5*OCT,  1, 4
        SNOTE   0,  6, NT_F+5*OCT,   1, 4
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
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   0,  6, NT_G+4*OCT,   1, 4
        SNOTE   0,  6, NT_F+4*OCT,   1, 4
        SNOTE   2, 11, NT_D+6*OCT,   0, 12
        SNOTE   1, 11, NT_C+6*OCT,   0, 12
        SNOTE   0,  6, NT_GS+4*OCT,  1, 4
        SNOTE   0,  6, NT_AS+4*OCT,  1, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  6, NT_D+5*OCT,   0, 4
        SNOTE   2,  6, NT_D+6*OCT,   0, 4
        SNOTE   1,  6, NT_C+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   0,  6, NT_DS+5*OCT,  1, 4
        SNOTE   0,  6, NT_F+5*OCT,   1, 4
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
tuneB23_v0:
        SCALL   musicSetupB
        SNOTE   2, 12, NT_C+6*OCT,   0, 16
        SNOTE   0, 11, NT_C+4*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_DS+6*OCT,  1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 11, NT_C+4*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_C+4*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_C+4*OCT,   0, 12
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   2,  9, NT_F+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+5*OCT,   1, 4
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
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
        SNOTE   0, 11, NT_G+4*OCT,   0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_G+4*OCT,   0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 11, NT_G+4*OCT,   0, 12
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   0, 11, NT_G+4*OCT,   0, 12
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   2, 12, NT_GS+6*OCT,  0, 16
        SNOTE   0, 11, NT_GS+4*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+5*OCT,  1, 4
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2, 17, NT_DS+7*OCT,  0, 48
        SNOTE   0, 11, NT_GS+4*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+5*OCT,  1, 4
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_GS+4*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+5*OCT,  1, 4
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0,  9, NT_CS+4*OCT,  0, 8
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   0,  9, NT_F+4*OCT,   0, 8
        SNOTE   1,  9, NT_GS+5*OCT,  0, 8
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_CS+7*OCT,  1, 8
        SNOTE   2, 12, NT_DS+7*OCT,  0, 16
        SNOTE   0, 11, NT_GS+4*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+5*OCT,  1, 4
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   2, 17, NT_GS+6*OCT,  0, 48
        SNOTE   0, 11, NT_GS+4*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+5*OCT,  1, 4
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_GS+4*OCT,  0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+5*OCT,  1, 4
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0,  9, NT_CS+4*OCT,  0, 8
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   0,  9, NT_F+4*OCT,   0, 8
        SNOTE   1,  9, NT_GS+5*OCT,  0, 8
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_CS+7*OCT,  1, 8
        SNOTE   0, 11, NT_GS+4*OCT,  0, 12
        SNOTE   2,  9, NT_DS+7*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   2,  9, NT_C+7*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_GS+5*OCT,  1, 4
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_GS+6*OCT,  1, 8
        SNOTE   0,  9, NT_CS+4*OCT,  0, 8
        SNOTE   1,  9, NT_F+5*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   0,  9, NT_F+4*OCT,   0, 8
        SNOTE   1,  9, NT_GS+5*OCT,  0, 8
        SNOTE   2,  9, NT_DS+7*OCT,  1, 8
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_CS+7*OCT,  1, 8
        SNOTE   0, 11, NT_G+4*OCT,   0, 12
        SNOTE   2,  9, NT_DS+7*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   2,  9, NT_C+7*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_GS+6*OCT,  1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 11, NT_G+4*OCT,   0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_G+4*OCT,   0, 12
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   1,  9, NT_DS+6*OCT,  0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   1, 8
        SNOTE   0, 11, NT_G+4*OCT,   0, 12
        SNOTE   2,  9, NT_D+7*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   2,  9, NT_B+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   0, 11, NT_G+4*OCT,   0, 12
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   0, 11, NT_G+4*OCT,   0, 12
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   1,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_G+5*OCT,   1, 4
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SWAIT   0
tuneB24_v0:
        SCALL   musicSetupB
        SNOTE   0, 11, NT_C+4*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+5*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0, 11, NT_C+4*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+5*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0,  9, NT_F+4*OCT,   0, 8
        SNOTE   1,  9, NT_GS+5*OCT,  0, 8
        SNOTE   2,  9, NT_C+6*OCT,   1, 8
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_F+6*OCT,   1, 8
        SNOTE   0,  9, NT_C+5*OCT,   0, 8
        SNOTE   1,  9, NT_F+6*OCT,   0, 8
        SNOTE   2,  9, NT_GS+6*OCT,  1, 8
        SNOTE   0, 11, NT_C+4*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+5*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0, 11, NT_C+4*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+5*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0,  9, NT_F+4*OCT,   0, 8
        SNOTE   1,  9, NT_GS+5*OCT,  0, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   0,  9, NT_C+5*OCT,   0, 8
        SNOTE   1,  9, NT_F+6*OCT,   0, 8
        SNOTE   2,  9, NT_GS+7*OCT,  1, 8
        SNOTE   0, 11, NT_C+4*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+5*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0, 11, NT_C+4*OCT,   0, 12
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1,  9, NT_DS+5*OCT,  1, 8
        SNOTE   1,  9, NT_G+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   0,  6, NT_C+5*OCT,   0, 4
        SNOTE   2,  6, NT_DS+6*OCT,  1, 4
        SNOTE   0,  9, NT_C+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   0,  9, NT_F+4*OCT,   0, 8
        SNOTE   1,  9, NT_A+5*OCT,   0, 8
        SNOTE   2,  9, NT_C+7*OCT,   1, 8
        SNOTE   0,  9, NT_A+4*OCT,   0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_F+7*OCT,   1, 8
        SNOTE   0,  9, NT_C+5*OCT,   0, 8
        SNOTE   1,  9, NT_F+6*OCT,   0, 8
        SNOTE   2,  9, NT_GS+7*OCT,  1, 8
        SNOTE   1, 17, NT_C+6*OCT,   0, 48
        SNOTE   2, 17, NT_GS+7*OCT,  0, 48
        SNOTE   0, 12, NT_GS+4*OCT,  1, 16
        SNOTE   0,  9, NT_GS+4*OCT,  1, 8
        SNOTE   0, 12, NT_GS+4*OCT,  1, 16
        SNOTE   0,  9, NT_GS+4*OCT,  1, 8
        SNOTE   0, 12, NT_GS+4*OCT,  1, 16
        SWAIT   0
tuneB25_v0:
        SCALL   musicSetupB
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_DS+6*OCT,  1, 8
        SNOTE   0, 12, NT_GS+4*OCT,  0, 16
        SNOTE   2, 11, NT_E+6*OCT,   0, 12
        SNOTE   1, 11, NT_CS+6*OCT,  1, 12
        SNOTE   2,  6, NT_FS+6*OCT,  1, 4
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  0, 8
        SNOTE   2,  9, NT_GS+6*OCT,  1, 8
        SNOTE   1, 15, NT_C+6*OCT,   0, 32
        SNOTE   2, 15, NT_DS+6*OCT,  0, 32
        SNOTE   0, 12, NT_GS+4*OCT,  1, 16
        SNOTE   0,  9, NT_GS+4*OCT,  1, 8
        SNOTE   0, 12, NT_GS+4*OCT,  1, 16
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
        SNOTE   1,  9, NT_C+6*OCT,   0, 8
        SNOTE   2,  9, NT_DS+6*OCT,  1, 8
        SNOTE   0, 12, NT_GS+4*OCT,  0, 16
        SNOTE   2, 11, NT_E+6*OCT,   0, 12
        SNOTE   1, 11, NT_CS+6*OCT,  1, 12
        SNOTE   2,  6, NT_FS+6*OCT,  1, 4
        SNOTE   0,  9, NT_GS+4*OCT,  0, 8
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
        SNOTE   0, 14, NT_G+4*OCT,   0, 24
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
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
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
tuneB26_v0:
        SCALL   musicSetupB
        SNOTE   2, 11, NT_B+5*OCT,   0, 12
        SNOTE   0, 11, NT_E+4*OCT,   0, 12
        SNOTE   1, 11, NT_G+5*OCT,   0, 12
        SNOTE   0,  9, REST,         1, 8
        SNOTE   0,  9, NT_B+4*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_E+6*OCT,   0, 4
        SNOTE   1,  6, NT_B+5*OCT,   1, 4
        SNOTE   2,  9, NT_G+6*OCT,   0, 8
        SNOTE   0,  9, NT_E+5*OCT,   0, 8
        SNOTE   1,  9, NT_E+6*OCT,   1, 8
        SNOTE   2,  9, NT_FS+6*OCT,  0, 8
        SNOTE   0,  9, NT_FS+4*OCT,  0, 8
        SNOTE   1,  9, NT_DS+6*OCT,  1, 8
        SNOTE   2,  9, NT_E+6*OCT,   0, 8
        SNOTE   0,  9, NT_B+4*OCT,   0, 8
        SNOTE   1,  9, NT_CS+6*OCT,  1, 8
        SNOTE   2,  9, NT_FS+6*OCT,  0, 8
        SNOTE   0,  9, NT_FS+5*OCT,  0, 8
        SNOTE   1,  9, NT_DS+6*OCT,  1, 8
        SNOTE   2, 11, NT_G+6*OCT,   0, 12
        SNOTE   1, 11, NT_D+6*OCT,   0, 12
        SNOTE   0,  9, NT_G+4*OCT,   0, 8
        SNOTE   0,  9, REST,         1, 8
        SNOTE   0,  9, NT_D+5*OCT,   0, 8
        SNOTE   0,  6, REST,         1, 4
        SNOTE   2,  6, NT_FS+6*OCT,  0, 4
        SNOTE   1,  6, NT_D+6*OCT,   1, 4
        SNOTE   2,  9, NT_E+6*OCT,   0, 8
        SNOTE   0,  9, NT_G+5*OCT,   0, 8
        SNOTE   1,  9, NT_D+6*OCT,   1, 8
        SNOTE   2,  9, NT_D+6*OCT,   0, 8
        SNOTE   0,  9, NT_A+4*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   2,  9, NT_C+6*OCT,   0, 8
        SNOTE   0,  9, NT_E+5*OCT,   0, 8
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
        SNOTE   1, 12, NT_D+6*OCT,   0, 16
        SNOTE   0, 12, NT_G+4*OCT,   0, 16
        SNOTE   2,  9, NT_B+6*OCT,   1, 8
        SNOTE   2,  9, NT_G+6*OCT,   1, 8
        SNOTE   2,  9, NT_A+6*OCT,   1, 8
        SNOTE   0, 12, NT_C+4*OCT,   0, 16
        SNOTE   1, 12, NT_E+6*OCT,   0, 16
        SNOTE   2, 11, NT_B+6*OCT,   1, 12
        SNOTE   2,  6, NT_B+6*OCT,   1, 4
        SNOTE   2,  9, NT_B+6*OCT,   1, 8
        SNOTE   1, 12, NT_D+6*OCT,   0, 16
        SNOTE   0, 12, NT_G+4*OCT,   0, 16
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
tuneB27_v0:
        SCALL   musicSetupB
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
        SNOTE   0, 12, NT_G+4*OCT,   0, 16
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
        SNOTE   0, 12, NT_G+4*OCT,   0, 16
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
tuneB28_v0:
        SCALL   musicSetupB
        SNOTE   0, 14, NT_D+5*OCT,   0, 24
        SNOTE   1, 14, NT_AS+5*OCT,  0, 24
        SNOTE   2, 11, NT_A+6*OCT,   1, 12
        SNOTE   2,  6, NT_F+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   1, 12, NT_B+5*OCT,   0, 16
        SNOTE   0, 12, NT_D+4*OCT,   1, 16
        SNOTE   0,  9, NT_D+4*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   0, 12, NT_D+4*OCT,   0, 16
        SNOTE   1, 12, NT_B+5*OCT,   1, 16
        SNOTE   0,  9, NT_D+4*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   0, 14, NT_D+5*OCT,   0, 24
        SNOTE   1, 14, NT_AS+5*OCT,  0, 24
        SNOTE   2, 11, NT_A+6*OCT,   1, 12
        SNOTE   2,  6, NT_F+6*OCT,   1, 4
        SNOTE   2,  9, NT_D+6*OCT,   1, 8
        SNOTE   2, 17, NT_G+6*OCT,   0, 48
        SNOTE   1, 12, NT_B+5*OCT,   0, 16
        SNOTE   0, 12, NT_D+4*OCT,   1, 16
        SNOTE   0,  9, NT_D+4*OCT,   0, 8
        SNOTE   1,  9, NT_B+5*OCT,   1, 8
        SNOTE   0, 12, NT_D+4*OCT,   0, 16
        SNOTE   1, 12, NT_B+5*OCT,   1, 16
        SNOTE   0,  9, NT_D+4*OCT,   0, 8
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
        SNOTE   0, 12, NT_G+4*OCT,   0, 16
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
musicSetupB:
        SCLEAR  1
        SSET    vfReleaseLead,   0Ch
        SSET    vfTranspose,     0FFD3h
        SSET    vfEnvBase,       musicSetupB_env_v1
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      28h
        SSET    vfLfoRate,       12Ch
        SCLEAR  2
        SSET    vfReleaseLead,   7
        SSET    vfTranspose,     0FFD3h
        SSET    vfEnvBase,       musicSetupB_env_v2
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      16h
        SSET    vfLfoRate,       78h
        SCLEAR  0
        SSET    vfReleaseLead,   7
        SSET    vfTranspose,     0FFD3h
        SSET    vfEnvBase,       musicSetupB_env_v0
        SSET    vfLfoTable,      lfoZero
        SSET    vfLfoWrap,       200h
        SSET    vfLfoDepth,      0C8h
        SSET    vfLfoRate,       10h
        SSET    vfTempo,         6
        SRET
musicSetupB_env_v2:
        SENV    0C350h,          ENV_SETLEVEL
        SENV    9C4h,            4
        SENV    0F830h,          6
        SENV    0,               0
        SENV    0BB80h,          ENV_SETLEVEL
        SENV    0E0C0h,          6
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
musicSetupB_env_v1:
        SENV    9C40h,           ENV_SETLEVEL
        SENV    9C4h,            8
        SENV    0F448h,          5
        SENV    0,               0
        SENV    0AFC8h,          ENV_SETLEVEL
        SENV    0F060h,          11
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
musicSetupB_env_v0:
        SENV    0DEA8h,          ENV_SETLEVEL
        SENV    0FA24h,          6
        SENV    0,               0
        SENV    0,               0
        SENV    0BB80h,          ENV_SETLEVEL
        SENV    0E0C0h,          6
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0

; Step the four Tandy voices, then write all four to the SN76489.  DL walks the
; latch bytes 80h, 0A0h, 0C0h, 0E0h -- voice 0 to voice 2 are tone, and 0E0h is
; the noise voice, which takes no second period byte.
tick_tandy:
        mov     bx, ds:[curTune]
        cmp     bx, 0
        jz      tandy_off
        mov     ds:[voiceLeft], 4
        mov     si, offset tandyFreq
        mov     ds:[freqBase], si
        mov     si, offset tandyBlocks
        mov     ds:[voiceBase], si
tandy_loop1:
        cmp     [si].vfDuration, 0
        jz      tandy_skip1
        call    voice_step
tandy_skip1:
        add     si, SIZE VOICE
        dec     ds:[voiceLeft]
        jnz     tandy_loop1
        mov     al, ds:[outputOn]
        cmp     al, 0
        jz      tandy_off
        mov     ds:[voiceLeft], 4
        mov     si, offset tandyBlocks
        mov     dl, 80h
tandy_loop2:
        mov     ax, [si].vfOutPeriod
        shr     ax, 1                   ; AX arrives as the period shifted left 6.
        shr     ax, 1                   ;   Two shifts of AX and four of AL leave the
        shr     al, 1                   ;   low 4 period bits in AL and the high 6 in
        shr     al, 1                   ;   AH -- the chip's two bytes, in order.
        shr     al, 1
        shr     al, 1
        xor     al, dl
        PORT_OUT 0C0h
        cmp     dl, 0E0h
        jz      tandy_noatt
        mov     al, ah
        PORT_OUT 0C0h
tandy_noatt:
        mov     ax, 0FFFFh              ; the chip attenuates, so invert the level
        sub     ax, [si].vfLevel
        shr     ah, 1                   ; keep the top 4 bits of the inverted level
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        mov     al, ah
        xor     al, dl
        add     al, 10h                 ; latch + 10h selects attenuation
        PORT_OUT 0C0h
        add     dl, 20h
        add     si, SIZE VOICE
        dec     ds:[voiceLeft]
        jnz     tandy_loop2
        ret
tandy_off:
        mov     al, 09Fh
        PORT_OUT 0C0h
        mov     al, 0BFh
        PORT_OUT 0C0h
        mov     al, 0DFh
        PORT_OUT 0C0h
        mov     al, 0FFh
        PORT_OUT 0C0h
        ret

ProgramTandyVoices:
        push    bp
        mov     bp, sp
        push    ax
        push    bx
        push    di
        push    si
        push    ds
        mov     si, CODE
        mov     ds, si
        mov     si, [bp+6]
        cmp     si, SONG_ROWS_B
        jb      vwb_tune
        xor     si, si
vwb_tune:
        mov     ds:[curTune], si
        add     si, si
        add     si, si
        add     si, si
        mov     ds:[seqBusy], 1
        mov     ds:[voiceLeft], 4
        mov     di, offset tandyBlocks
vwb_loop:
        mov     ax, songTableB[si]
        cmp     ax, 0
        jz      vwb_next
        mov     bx, SIZE VOICE - 2
vwb_clr:
        mov     word ptr [bx+di], 0
        sub     bx, 2
        jge     vwb_clr
        mov     [di].vfStream, ax
        mov     bl, 4
        sub     bl, ds:[voiceLeft]
        sub     bh, bh
        mov     ax, ds:[curTune]
        mov     voiceTune[bx], al
        mov     [di].vfDuration, 1
vwb_next:
        add     di, SIZE VOICE
        add     si, 2
        dec     ds:[voiceLeft]
        jnz     vwb_loop
        mov     ds:[seqBusy], 0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf    2
