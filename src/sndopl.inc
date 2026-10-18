; ---------------------------------------------------------------------------
; The AdLib's (OPL2's) part of the sequencer (phase 7 of docs/refactor-plan.md).
; It plays the Tandy arrangements: the Tandy voice blocks, note table, song table
; and tune loader (sndtdy.inc) step as they do for the SN76489, and tick_opl turns
; each voice into FM.  The three tone voices play on OPL channels 0 to 2.  The noise
; voice plays the rhythm section's snare drum, the OPL's own noise, held keyed and
; its level set each tick like the tones'; channel 7's pitch colours it.  A register is written only when its value
; changes, since every OPL write waits on the chip.  sounddrv.asm includes it.
;
; Pitch: an SN76489 tone of period n sounds at 3579545 / (32 n) Hz, and an OPL2
; note at fnum * 49716 / 2^(20 - block) Hz, so fnum = 9 * 2^(18 - block) / n.  The
; lowest block whose fnum fits in 10 bits keeps the most precision.
; Level: the SN76489 attenuates in 2 dB steps, the OPL's total level in 0.75 dB
; steps; oplAtt maps one to the other, and the SN76489's silent step to the OPL's.
; ---------------------------------------------------------------------------
OPL_ADDR        equ     388h            ; the OPL2's address and status port
OPL_NOISE       equ     3               ; the Tandy noise voice, played on the snare drum
OPL_SILENT      equ     63              ; the carrier's total level that sounds nothing
OPL_KEY_ON      equ     20h             ; in a channel's B0h register

; Per voice: the OPL channel its pitch goes to, and the operator whose level it sets
; (a channel's carrier; for the noise voice the snare drum's operator, 14h).  The
; operator 3 below is the channel's modulator (for the noise, the unused hi-hat's).
oplChan         db      0, 1, 2, 7
oplCarrier      db      3, 4, 5, 14h
OPL_RHYTHM      equ     0BDh            ; rhythm mode, and the drums' keys
RHYTHM_SNARE    equ     28h             ;   rhythm mode on, the snare keyed
; The last B0h:A0h pair (key on, block, fnum) and carrier level written per channel;
; 0FFFFh and 0FFh force the next write.
oplFreq         dw      4 dup(0FFFFh)
oplLevel        db      4 dup(0FFh)
oplRhythm       db      0FFh            ; the last rhythm register written
; SN76489 attenuation step (0 loud .. 15 off) -> OPL carrier total level.
oplAtt          db      0, 3, 5, 8, 11, 13, 16, 19, 21, 24, 27, 29, 32, 35, 37, OPL_SILENT
; 9 * 2^(18 - block) for blocks 0 to 7: fnum is this divided by the SN76489 period.
oplNum          dd      2359296, 1179648, 589824, 294912, 147456, 73728, 36864, 18432
; The snare's pitch (channel 7) for SN76489 noise rates 0 to 2 (N/512, N/1024,
; N/2048), as B7h:A7h pairs with no key bit, since the rhythm register keys the
; drums: fnum 600 in blocks 5, 4 and 3.  Rate 3 follows tone voice 2.
oplNoise        dw      1658h, 1258h, 0E58h

; The patch, as (register, value) pairs for channel 0's operators and channel; OplReset
; adds each voice's operator offsets.  Tone channels: a sustained FM voice with
; some feedback, square-ish.  The snare takes the carrier's half: sustained, fast
; attack and release, silent until a tick sets its level.
oplPatch        db      20h, 21h        ; modulator: sustained, multiple 1
                db      23h, 21h        ; carrier: sustained, multiple 1
                db      40h, 1Ah        ; modulator level: some harmonics
                db      43h, OPL_SILENT ; carrier level: silent until a tick sets it
                db      60h, 0F0h       ; attack fast, no decay
                db      63h, 0F0h
                db      80h, 00Fh       ; sustain at full level, release fast
                db      83h, 00Fh
                db      0E0h, 0         ; sine waves
                db      0E3h, 0
OPL_PATCH_PAIRS equ     ($ - oplPatch) / 2
oplToneFb       db      0Ah             ; C0h: feedback 5, FM

; Write value AH to OPL register AL, then wait as the chip needs: 6 status reads
; after the address, 35 after the data.  The trace build records the address and
; the value as writes to ports 88h and 89h instead.  Keeps every register.
opl_write:
IFDEF TRACE
        push    ax
        push    ax
        mov     ah, 88h                 ; AL is the register
        call    trace_out
        pop     ax
        mov     al, ah
        mov     ah, 89h
        call    trace_out
        pop     ax
        ret
ELSE
        push    ax
        push    cx
        push    dx
        mov     dx, OPL_ADDR
        out     dx, al
        mov     cx, 6
ow_wait1:
        in      al, dx
        loop    ow_wait1
        inc     dx
        mov     al, ah
        out     dx, al
        dec     dx
        mov     cx, 35
ow_wait2:
        in      al, dx
        loop    ow_wait2
        pop     dx
        pop     cx
        pop     ax
        ret
ENDIF

; Channel DI's carrier level to AL, if it differs.  Keeps every register.
opl_level:
        cmp     al, ds:oplLevel[di]
        jz      ol_done
        mov     ds:oplLevel[di], al
        push    ax
        mov     ah, al
        mov     al, ds:oplCarrier[di]
        add     al, 40h
        call    opl_write
        pop     ax
ol_done:
        ret

; Voice DI's B0h:A0h pair to AX, on its channel (oplChan), if it differs.  Keeps every
; register.
opl_freq:
        push    bx
        mov     bx, di
        add     bx, bx
        cmp     ax, ds:oplFreq[bx]
        jz      of_done
        mov     ds:oplFreq[bx], ax
        push    ax
        push    cx
        mov     cx, ax
        mov     al, ds:oplChan[di]
        add     al, 0A0h
        mov     ah, cl                  ; fnum's low byte
        call    opl_write
        mov     al, ds:oplChan[di]
        add     al, 0B0h
        mov     ah, ch                  ; key on, block, fnum's high bits
        call    opl_write
        pop     cx
        pop     ax
of_done:
        pop     bx
        ret

; The B0h:A0h pair for SN76489 period AX (10 bits; 0 is 1024), with the key on.
; Clobbers BX, CX and DX.
opl_pitch:
        or      ax, ax
        jnz     op_have
        mov     ax, 1024
op_have:
        mov     bx, ax                  ; the divisor
        xor     cx, cx                  ; the block
op_block:
        push    bx
        mov     bx, cx
        add     bx, bx
        add     bx, bx
        mov     ax, word ptr ds:oplNum[bx]
        mov     dx, word ptr ds:oplNum[bx+2]
        pop     bx
        cmp     dx, bx                  ; a quotient past 16 bits is past 10 too
        jae     op_next
        div     bx
        cmp     ax, 1023
        jbe     op_found
op_next:
        inc     cx
        cmp     cx, 8
        jb      op_block
        mov     ax, 1023                ; above the OPL's range: its top note
        mov     cx, 7
op_found:
        shl     cl, 1
        shl     cl, 1
        or      ah, cl                  ; block in bits 2..4 beside fnum's high bits
        or      ah, OPL_KEY_ON
        ret

; Step the four Tandy voices as tick_tandy does, then set each OPL channel's level
; and pitch from them; silent while no tune is loaded or output is off.
tick_opl:
        push    cx
        push    di
        mov     bx, ds:[curTune]
        cmp     bx, 0
        jnz     opl_tune
        jmp     opl_off
opl_tune:
        mov     ds:[voiceLeft], 4
        mov     si, offset tandyFreq
        mov     ds:[freqBase], si
        mov     si, offset tandyBlocks
        mov     ds:[voiceBase], si
opl_step:
        cmp     [si].vfDuration, 0
        jz      opl_stepped
        call    voice_step
opl_stepped:
        add     si, SIZE VOICE
        dec     ds:[voiceLeft]
        jnz     opl_step
        cmp     ds:[outputOn], 0
        jz      opl_off
        cmp     ds:[oplRhythm], RHYTHM_SNARE    ; the snare keyed, after a reset or a silence
        jz      opl_keyed
        mov     ds:[oplRhythm], RHYTHM_SNARE
        mov     ax, (RHYTHM_SNARE SHL 8) OR OPL_RHYTHM
        call    opl_write
opl_keyed:
        mov     si, offset tandyBlocks
        xor     di, di
opl_voice:
        mov     ax, 0FFFFh              ; the SN76489's attenuation, as tick_tandy takes it
        sub     ax, [si].vfLevel
        mov     cl, 4
        shr     ah, cl
        mov     bl, ah
        xor     bh, bh
        mov     al, ds:oplAtt[bx]
        call    opl_level
        mov     ax, [si].vfOutPeriod
        cmp     di, OPL_NOISE
        jz      opl_noisy
        mov     cl, 6
        shr     ax, cl                  ; the 10-bit period
        call    opl_pitch
        jmp     short opl_pitched
opl_noisy:
        shr     ax, 1                   ; the noise control, as tick_tandy finds it:
        shr     ax, 1                   ;   rate in its low two bits
        mov     cl, 4
        shr     al, cl
        and     al, 3
        cmp     al, 3
        jnz     opl_rate
        mov     ax, ds:oplFreq[2 * 2]   ; rate 3 follows tone voice 2,
        and     ah, NOT OPL_KEY_ON      ;   without its key: the rhythm register keys the snare
        jmp     short opl_pitched
opl_rate:
        mov     bl, al
        xor     bh, bh
        add     bx, bx
        mov     ax, ds:oplNoise[bx]
opl_pitched:
        call    opl_freq
        add     si, SIZE VOICE
        inc     di
        cmp     di, 4
        jb      opl_voice
        pop     di
        pop     cx
        ret
opl_off:
        xor     di, di
        mov     al, OPL_SILENT
opl_quiet:
        call    opl_level
        inc     di
        cmp     di, 4
        jb      opl_quiet
        pop     di
        pop     cx
        ret

; Pascal procedure OplWrite(reg, value: Word): one OPL register, with the waits.
OplWrite:
        push    bp
        mov     bp, sp
        push    ax
        mov     al, [bp+8]
        mov     ah, [bp+6]
        call    opl_write
        pop     ax
        pop     bp
        retf    4

; Pascal procedure OplReset: every OPL register cleared, waveform select on, the patch
; on channels 0 to 2 and the snare, all silent; the first tick keys them.
OplReset:
        push    ax
        push    bx
        push    cx
        push    si
        push    di
        push    ds
        mov     ax, CODE
        mov     ds, ax
        mov     al, 1                   ; registers 01h..0F5h to 0
        xor     ah, ah
or_clear:
        call    opl_write
        inc     al
        cmp     al, 0F6h
        jb      or_clear
        mov     ax, 2001h               ; 01h: waveform select on
        call    opl_write
        xor     di, di
or_chan:
        mov     bl, ds:oplCarrier[di]
        sub     bl, 3                   ; the channel's modulator offset
        mov     si, offset oplPatch
        mov     cx, OPL_PATCH_PAIRS
or_pair:
        mov     al, [si]
        add     al, bl
        mov     ah, [si+1]
        call    opl_write
        add     si, 2
        loop    or_pair
        mov     al, ds:oplChan[di]
        add     al, 0C0h
        mov     ah, ds:[oplToneFb]
        call    opl_write
        mov     ds:oplLevel[di], OPL_SILENT
        mov     bx, di
        add     bx, bx
        mov     ds:oplFreq[bx], 0FFFFh
        inc     di
        cmp     di, 4
        jb      or_chan
        mov     ds:[oplRhythm], 0       ; cleared: the first tick turns rhythm mode on
        pop     ds
        pop     di
        pop     si
        pop     cx
        pop     bx
        pop     ax
        retf

; Every voice silent and keyed off, the snare too, at the timer's removal.  Keeps every
; register.
opl_silence:
        push    ax
        push    di
        xor     di, di
os_chan:
        mov     ah, OPL_SILENT
        mov     al, ds:oplCarrier[di]
        add     al, 40h
        call    opl_write
        mov     ds:oplLevel[di], OPL_SILENT
        mov     al, ds:oplChan[di]
        add     al, 0B0h
        xor     ah, ah
        call    opl_write
        push    bx
        mov     bx, di
        add     bx, bx
        mov     ds:oplFreq[bx], 0FFFFh
        pop     bx
        inc     di
        cmp     di, 4
        jb      os_chan
        mov     ax, (20h SHL 8) OR OPL_RHYTHM   ; rhythm mode on, the snare's key off
        call    opl_write
        mov     ds:[oplRhythm], 20h     ; the next tick keys it again
        pop     di
        pop     ax
        ret
