; PC-speaker, Tandy SN76489 and AdLib (OPL2) timer sequencer, linked into SoundDrv
; by SOUNDDRV.OBJ.  This file is the core: the voice stepping, the stream
; interpreter, envelopes and LFO, the timer interrupt and the Pascal far entries
; that install and remove INT 8 and control the output gate.  Each device's part --
; note table, voice blocks, song table, streams, tick and tune loader -- is an
; include: sndspk.inc, sndtdy.inc, and sndopl.inc for the AdLib, which plays the
; Tandy's arrangements.  The interrupt runs the configured device's tick through
; tickProc, which SetSoundDevice sets.  Four voices of the device are stepped; the
; speaker uses the first active voice.  The displaced BIOS handler runs every
; thirteenth tick.

CODE    SEGMENT BYTE PUBLIC 'CODE'
        ASSUME  CS:CODE, DS:CODE
        PUBLIC  InstallSoundTimer, UninstallSoundTimer
        PUBLIC  ProgramSpeakerVoices, ProgramTandyVoices, SetSoundOutputEnabled
        PUBLIC  SoundTimerTicks, SoundTimerHooked, SetSoundDevice, SoundVoiceTune
        PUBLIC  OplWrite, OplReset
IFDEF TRACE
        PUBLIC  TraceTick, SetTraceBuffer, TraceCount
        JUMPS                           ; the recorder's calls put some short jumps out of reach
ENDIF

; ---------------------------------------------------------------------------
; Port I/O while the sequencer ticks.  The game's build (SOUNDDRV.OBJ) assembles
; plain OUT and IN.  The trace build (TASM /dTRACE, SNDTRACE.OBJ, for the tests)
; records each write -- the port's low byte and the value -- in the buffer
; SetTraceBuffer gives, touches no hardware, and reads port 61h as 0.
; ---------------------------------------------------------------------------
PORT_OUT MACRO port
IFDEF TRACE
        push    ax
        mov     ah, port
        call    trace_out
        pop     ax
ELSE
        out     port, al
ENDIF
ENDM

PORT_IN MACRO port
IFDEF TRACE
        mov     al, 0
ELSE
        in      al, port
ENDIF
ENDM

; ---------------------------------------------------------------------------
; Voice state. SSET writes fields by offset; voice_step advances them
; on each timer interrupt.
; ---------------------------------------------------------------------------
VOICE   STRUC
vfDuration      dw      0       ; ticks until the sequencer next steps this voice
vfStream        dw      0       ; stream pointer; 0 = the voice is idle
vfPeriod        dw      0       ; pitch accumulator
vfPeriodAdd     dw      0       ; added to vfPeriod each tick -- a pitch slide
vfOutPeriod     dw      0       ; vfPeriod plus the LFO; this is what the chip gets
vfLevel         dw      0       ; output level
vfLevelAdd      dw      0       ; added to vfLevel each tick
vfTempo         dw      0       ; low byte scales duration; 0 or 1 leaves it unchanged
vfReleaseLead   dw      0       ; ticks before a note ends at which its release starts
vfTranspose     dw      0       ; added to a note's pitch before the octave reduction
vfGateLen       dw      0       ; when it expires the envelope restarts at its 5th pair
vfEnvBase       dw      0       ; base of this voice's (value,ticks) envelope list
vfEnvPos        dw      0       ; byte offset into that list
vfEnvWait       dw      0       ; ticks left in the current envelope segment
vfLfoTable      dw      0       ; base pointer into the LFO samples
vfLfoPhase      dw      0       ; LFO phase accumulator
vfLfoRate       dw      0       ; added to vfLfoPhase each tick
vfLfoDepth      dw      0       ; signed multiplier on the waveform sample
vfLfoWrap       dw      0       ; vfLfoPhase wraps here
vfLoopCounterA  dw      0       ; SLOOP counter
vfLoopCounterB  dw      0       ; SLOOP counter for a loop nested inside the first
                dw      3 dup(0)        ; Reserved words, cleared with the voice state.
VOICE   ENDS

; ---------------------------------------------------------------------------
; Driver state.  The ISR and the voice writers reach all of it with DS = CODE.
; ---------------------------------------------------------------------------
DEV_TANDY       equ     0               ; device values, as C_Sound's MODE_TANDY,
DEV_SPEAKER     equ     1               ;   MODE_SPEAKER and MODE_DISABLED
DEV_NONE        equ     2
DEV_ADLIB       equ     3               ;   and MODE_ADLIB

divCount        db      13              ; ticks left before the next BIOS INT 8 chain
seqBusy         db      0               ; nonzero skips ISR sequencing during voice updates
voiceLeft       db      0               ; voices still to visit this pass, 4 down to 1
blockSize       db      SIZE VOICE      ; seq_note multiplies a voice index by it
exitCount       dw      0               ; Ticks until forced shutdown; zero disables the countdown.

; Shutdown message with bit 7 set in every byte. The timer handler
; clears that bit before displaying the first 33 bytes.
exitMsg         db      0D2h,0F5h,0EEh,0ADh,0F4h,0E9h,0EDh,0E5h,0A0h,0A0h,0C5h,0F2h,0F2h,0EFh,0F2h,0A0h
                db      0B2h,0B0h,0B9h,0A0h,0E1h,0F4h,0A0h,0B0h,0C2h,0C1h,0C4h,0BAh,0B0h,0B0h,0B3h,0B8h
                db      08Ah,08Dh

curTune         dw      0               ; tune id loaded; 0 = silent
seqVoice        dw      0               ; the voice block seq_proc is running
voiceBase       dw      0               ; block array of the device being ticked
freqBase        dw      0               ; note table of the device being ticked
seqRet          dw      0               ; the stream pointer SCALL saved -- one level only; 0 = none
voiceTune       db      0,0,0,0         ; tune id per voice; seq_end clears a voice's entry
                                        ;   when that voice runs out of stream
outputOn        db      1               ; zero mutes output while the sequencers keep running
device          db      DEV_NONE        ; the configured device, the only one the ISR ticks
tickProc        dw      tick_none       ; the device's tick, which SetSoundDevice sets from tickTable
tickTable       dw      tick_tandy, tick_spkr, tick_none, tick_opl      ; by device value, DEV_TANDY to DEV_ADLIB

; Duration table: 3:4 pairs double at each step. Notes carry explicit durations,
; so nothing reads this table.
noteLen         db      000h,000h,000h,002h,000h,003h,004h,000h,006h,008h,000h,00Ch,010h,000h,018h,020h
                db      000h,030h,040h

; Sequencer command dispatch for stream bytes 0FAh through 0FFh, in that order.
cmdTable        dw      seq_c_reset, seq_c_ret, seq_c_call
                dw      seq_c_clear, seq_c_loop, seq_c_set

; ---------------------------------------------------------------------------
; LFO WAVEFORMS.  A voice picks one by pointing vfLfoTable at it; voice_step reads
; a byte, scales it by vfLfoDepth and adds the result to the pitch going out.
; ---------------------------------------------------------------------------
; One sine cycle: 256 signed samples, amplitude 7Eh.
lfoSine         db      000h,003h,006h,009h,00Ch,00Fh,012h,015h,018h,01Bh,01Eh,021h,024h,027h,02Ah,02Dh
                db      030h,033h,036h,039h,03Bh,03Eh,041h,043h,046h,049h,04Bh,04Eh,050h,052h,055h,057h
                db      059h,05Bh,05Eh,060h,062h,064h,066h,067h,069h,06Bh,06Ch,06Eh,070h,071h,072h,074h
                db      075h,076h,077h,078h,079h,07Ah,07Bh,07Bh,07Ch,07Dh,07Dh,07Eh,07Eh,07Eh,07Eh,07Eh
                db      07Eh,07Eh,07Eh,07Eh,07Eh,07Eh,07Dh,07Dh,07Ch,07Bh,07Bh,07Ah,079h,078h,077h,076h
                db      075h,074h,072h,071h,070h,06Eh,06Ch,06Bh,069h,067h,066h,064h,062h,060h,05Eh,05Bh
                db      059h,057h,055h,052h,050h,04Eh,04Bh,049h,046h,043h,041h,03Eh,03Bh,039h,036h,033h
                db      030h,02Dh,02Ah,027h,024h,021h,01Eh,01Bh,018h,015h,012h,00Fh,00Ch,009h,006h,003h
                db      000h,0FDh,0FAh,0F7h,0F4h,0F1h,0EEh,0EBh,0E8h,0E5h,0E2h,0DFh,0DCh,0D9h,0D6h,0D3h
                db      0D0h,0CDh,0CAh,0C7h,0C5h,0C2h,0BFh,0BDh,0BAh,0B7h,0B5h,0B2h,0B0h,0AEh,0ABh,0A9h
                db      0A7h,0A5h,0A2h,0A0h,09Eh,09Ch,09Ah,099h,097h,095h,094h,092h,090h,08Fh,08Eh,08Ch
                db      08Bh,08Ah,089h,088h,087h,086h,085h,085h,084h,083h,083h,082h,082h,082h,082h,082h
                db      082h,082h,082h,082h,082h,082h,083h,083h,084h,085h,085h,086h,087h,088h,089h,08Ah
                db      08Bh,08Ch,08Eh,08Fh,090h,092h,094h,095h,097h,099h,09Ah,09Ch,09Eh,0A0h,0A2h,0A5h
                db      0A7h,0A9h,0ABh,0AEh,0B0h,0B2h,0B5h,0B7h,0BAh,0BDh,0BFh,0C2h,0C5h,0C7h,0CAh,0CDh
                db      0D0h,0D3h,0D6h,0D9h,0DCh,0DFh,0E2h,0E5h,0E8h,0EBh,0EEh,0F1h,0F4h,0F7h,0FAh,0FDh

; Zero samples, followed by constant samples; the selected wrap can span both regions.
lfoZero         db      000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h

; Constant samples for a positive pitch offset.
lfoFlat         db      078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h

; Pseudo-random waveform for percussion and sound effects.
lfoNoise        db      029h,023h,0BEh,084h,0E1h,06Ch,0D6h,0AEh,052h,090h,049h,0F1h,0F1h,0BBh,0E9h,0EBh
                db      0B3h,0A6h,0DBh,03Ch,087h,00Ch,03Eh,099h,024h,05Eh,00Dh,01Ch,006h,0B7h,047h,0DEh
                db      0B3h,012h,04Dh,0C8h,043h,0BBh,08Bh,0A6h,01Fh,003h,05Ah,07Dh,009h,038h,025h,01Fh
                db      05Dh,0D4h,0CBh,0FCh,096h,0F5h,045h,03Bh,013h,00Dh,089h,00Ah,01Ch,0DBh,0AEh,032h
                db      020h,09Ah,050h,0EEh,040h,078h,036h,0FDh,012h,049h,032h,0F6h,09Eh,07Dh,049h,0DCh
                db      0ADh,04Fh,014h,0F2h,044h,040h,066h,0D0h,06Bh,0C4h,030h,0B7h,032h,03Bh,0A1h,022h
                db      0F6h,022h,091h,09Dh,0E1h,08Bh,01Fh,0DAh,0B0h,0CAh,099h,002h,0B9h,072h,09Dh,049h
                db      02Ch,080h,07Eh,0C5h,099h,0D5h,0E9h,080h,0B2h,0EAh,0C9h,0CCh,053h,0BFh,067h,0D6h
                db      0BFh,014h,0D6h,07Eh,02Dh,0DCh,08Eh,066h,083h,0EFh,057h,049h,061h,0FFh,069h,08Fh
                db      061h,0CDh,0D1h,01Eh,09Dh,09Ch,016h,072h,072h,0E6h,01Dh,0F0h,084h,04Fh,04Ah,077h
                db      002h,0D7h,0E8h,039h,02Ch,053h,0CBh,0C9h,012h,01Eh,033h,074h,09Eh,00Ch,0F4h,0D5h
                db      0D4h,09Fh,0D4h,0A4h,059h,07Eh,035h,0CFh,032h,022h,0F4h,0CCh,0CFh,0D3h,090h,02Dh
                db      048h,0D3h,08Fh,075h,0E6h,0D9h,01Dh,02Ah,0E5h,0C0h,0F7h,02Bh,078h,081h,087h,044h
                db      00Eh,05Fh,050h,000h,0D4h,061h,08Dh,0BEh,07Bh,005h,015h,007h,03Bh,033h,082h,01Fh
                db      018h,070h,092h,0DAh,064h,054h,0CEh,0B1h,085h,03Eh,069h,015h,0F8h,046h,06Ah,004h
                db      096h,073h,00Eh,0D9h,016h,02Fh,067h,068h,0D4h,0F7h,04Ah,04Ah,0D0h,057h,068h,076h
                db      0FAh,016h,0BBh,011h,0ADh,0AEh,024h,088h,079h,0FEh,052h,0DBh,025h,043h,0E5h,03Ch
                db      0F4h,045h,0D3h,0D8h,028h,0CEh,00Bh,0F5h,0C5h,060h,059h,03Dh,097h,027h,08Ah,059h
                db      076h,02Dh,0D0h,0C2h,0C9h,0CDh,068h,0D4h,049h,06Ah,079h,025h,008h,061h,040h,014h
                db      0B1h,03Bh,06Ah,0A5h,011h,028h,0C1h,08Ch,0D6h,0A9h,00Bh,087h,097h,08Ch,02Fh,0F1h
                db      015h,01Dh,09Ah,095h,0C1h,09Bh,0E1h,0C0h,07Eh,0E9h,0A8h,09Ah,0A7h,086h,0C2h,0B5h
                db      054h,0BFh,09Ah,0E7h,0D9h,023h,0D1h,055h,090h,038h,028h,0D1h,0D9h,06Ch,0A1h,066h
                db      05Eh,04Eh,0E1h,030h,09Ch,0FEh,0D9h,071h,09Fh,0E2h,0A5h,0E2h,00Ch,09Bh,0B4h,047h
                db      065h,038h,02Ah,046h,089h,0A9h,082h,079h,07Ah,076h,078h,0C2h,063h,0B1h,026h,0DFh
                db      0DAh,029h,06Dh,03Eh,062h,0E0h,096h,012h,034h,0BFh,039h,0A6h,03Fh,089h,05Eh,0F1h
                db      06Dh,00Eh,0E3h,06Ch,028h,0A1h,01Eh,020h,01Dh,0CBh,0C2h,003h,03Fh,041h,007h,084h
                db      00Fh,014h,005h,065h,01Bh,028h,061h,0C9h,0C5h,0E7h,02Ch,08Eh,046h,036h,008h,0DCh
                db      0F3h,0A8h,08Dh,0FEh,0BEh,0F2h,0EBh,071h,0FFh,0A0h,0D0h,03Bh,075h,006h,08Ch,07Eh
                db      087h,078h,073h,04Dh,0D0h,0BEh,082h,0BEh,0DBh,0C2h,046h,041h,02Bh,08Ch,0FAh,030h
                db      07Fh,070h,0F0h,0A7h,054h,086h,032h,095h,0AAh,05Bh,068h,013h,00Bh,0E6h,0FCh,0F5h
                db      0CAh,0BEh,07Dh,09Fh,089h,08Ah,041h,01Bh,0FDh,0B8h,04Fh,068h,0F6h,072h,07Bh,014h
                db      099h,0CDh,0D3h,00Dh,0F0h,044h,03Ah,0B4h,0A6h,066h,053h,033h,00Bh,0CBh,0A1h,010h

; ---------------------------------------------------------------------------
; The pitch names and record macros the devices' streams and envelopes are
; written with.
; ---------------------------------------------------------------------------
; Pitches are scale degrees above the active note table's base -- C for the speaker
; table, A for the Tandy one -- not concert pitches.  seq_note adds the voice's
; vfTranspose, then reduces to an octave and a semitone.
NT_C    equ 0
NT_CS   equ 1
NT_D    equ 2
NT_DS   equ 3
NT_E    equ 4
NT_F    equ 5
NT_FS   equ 6
NT_G    equ 7
NT_GS   equ 8
NT_A    equ 9
NT_AS   equ 10
NT_B    equ 11
OCT     equ 12                      ; one octave
REST    equ 7Fh                     ; the pitch that sounds nothing

; One macro per sequencer record, each emitting the record the driver decodes.
SRESET  MACRO                       ;; 0FAh -- clear the voice this stream is on
        db 0FAh
        ENDM
SRET    MACRO                       ;; 0FBh -- back to the stream SCALL came from
        db 0FBh
        ENDM
SCALL   MACRO target                ;; 0FCh -- call a stream; seqRet holds one level
        db 0FCh
        dw target
        ENDM
SCLEAR  MACRO vnum                  ;; 0FDh -- move this stream onto voice vnum of
        db 0FDh                     ;;         the active device and clear it
        dw (vnum) * SIZE VOICE
        ENDM
SLOOP   MACRO field, target         ;; 0FEh -- jump if field is zero or decrements to nonzero
        db 0FEh, field
        dw target
        ENDM
SSET    MACRO field, value          ;; 0FFh -- store a word into a voice field
        db 0FFh, field
        dw value
        ENDM
SWAIT   MACRO ticks                 ;; SSET of vfDuration, which also yields.  Ticks 0
        db 0FFh, 000h               ;;   ends the stream: seq_end sees the zero and
        dw ticks                    ;;   drops the voice
        ENDM
ENV_SETLEVEL equ 0FFFFh             ; in a segment's ticks slot: value is a level to
                                    ;   load, and the next segment runs on the same tick
SENV    MACRO value, ticks          ;; one envelope segment
        dw value, ticks
        ENDM
SNOTE   MACRO vnum, len, pitch, last, dur   ; A note record with explicit duration; len is unused.
        db ((vnum) SHL 5) OR (len), ((last) SHL 7) OR (pitch), dur
        ENDM

; The devices' parts.  Each note table holds one octave: seq_note selects a
; semitone, then shifts its period right by the octave number.  Each song table
; has one row per tune id, four stream pointers per row -- voice 0 to voice 3;
; both voice programmers index by id * 8, and a zero pointer preserves that voice.
        INCLUDE sndspk.inc
        INCLUDE sndtdy.inc
        INCLUDE sndopl.inc

; Saved BIOS timer vector, restored by UninstallSoundTimer.
oldInt8Off      dw      0
oldInt8Seg      dw      0
hooked          db      0               ; nonzero while P_isr owns INT 8
drvTicks        dw      0               ; P_isr's tick count, wrapping; SoundDelay's clock

; ---------------------------------------------------------------------------
; Playback routines.
; ---------------------------------------------------------------------------
; Both entries may be called again in the state they leave: a second hook would
; keep P_isr as the handler to chain, and the BIOS clock would stop for good.
InstallSoundTimer:
        push    ds
        push    es
        mov     ax, CODE
        mov     ds, ax
        cmp     cs:[hooked], 0
        jnz     ist_done
        mov     ax, 3508h               ; DOS get-vector, INT 8
        int     21h
        mov     ax, es                  ; never keep P_isr itself as the handler to chain
        cmp     ax, CODE
        jnz     ist_save
        cmp     bx, offset P_isr
        jz      ist_pit
ist_save:
        mov     cs:[oldInt8Off], bx     ; keep the handler we are displacing
        mov     cs:[oldInt8Seg], es
        push    ds
        mov     dx, CODE
        mov     ds, dx
        mov     dx, offset P_isr
        mov     ax, 2508h               ; DOS set-vector, INT 8
        int     21h
        pop     ds
ist_pit:
        mov     cs:[hooked], 1
        mov     al, 0B6h                ; PIT ch2: lo/hi, mode 3, for the speaker
        out     43h, al
        mov     al, 36h                 ; PIT ch0: lo/hi, mode 3, then its divisor
        out     43h, al
        mov     ax, 13B1h               ; ch0 divisor 5041: 236.7 Hz
        out     40h, al
        mov     al, ah
        out     40h, al
ist_done:
        pop     es
        pop     ds
        retf

UninstallSoundTimer:
        push    ds
        cmp     cs:[hooked], 0
        jz      ust_done
        mov     cs:[hooked], 0
        mov     ax, CODE
        mov     ds, ax
        push    ds
        mov     dx, cs:[oldInt8Off]
        mov     ax, cs:[oldInt8Seg]
        mov     ds, ax
        mov     ax, 2508h               ; put the displaced handler back
        int     21h
        pop     ds
        mov     al, 36h                 ; PIT ch0: lo/hi, mode 3, then divisor 0
        out     43h, al                 ;   (65536), the BIOS's own 18.2 Hz
        xor     ax, ax
        out     40h, al
        out     40h, al
        in      al, 61h                 ; drop the speaker gate and the timer gate
        and     al, 0FCh
        out     61h, al
        cmp     cs:[device], DEV_ADLIB
        jnz     ust_tandy
        call    opl_silence
        jmp     short ust_done
ust_tandy:
        cmp     cs:[device], DEV_TANDY  ; C0h is the SN76489 only on a Tandy
        jnz     ust_done
        mov     al, 09Fh                ; full attenuation on the SN76489's
        out     0C0h, al                ;   three tone voices and its noise voice
        mov     al, 0BFh
        out     0C0h, al
        mov     al, 0DFh
        out     0C0h, al
        mov     al, 0FFh
        out     0C0h, al
ust_done:
        pop     ds
        retf

; The timer ISR.  It runs with interrupts on, so seqBusy and not the interrupt flag
; is what keeps it out of the voice writers.
P_isr:
        sti
        push    ax
        push    bx
        push    dx
        push    ds
        push    si
        mov     ax, CODE
        mov     ds, ax
        inc     cs:[drvTicks]
        cmp     ds:[exitCount], 0
        jz      isr_tick
        dec     ds:[exitCount]
        jnz     isr_tick
        mov     ah, 0Fh                 ; read the video mode, then set it again,
        int     10h                     ;   which clears the screen
        mov     ah, 0
        int     10h
        mov     bl, 7
        mov     ah, 7Fh                 ; strip bit 7 off exitMsg in place
        mov     cx, 33
        mov     bx, CODE
        mov     es, bx
        mov     bx, offset exitMsg
isr_msgclr:
        mov     al, es:[bx]
        and     al, ah
        mov     es:[bx], al
        inc     bx
        loop    isr_msgclr
        mov     bl, 7
        mov     ah, 13h                 ; write string, attribute in BL, move cursor
        mov     al, 1
        mov     bh, 0
        mov     cx, 33
        xor     dx, dx
        mov     bp, CODE
        mov     es, bp
        mov     bp, offset exitMsg
        int     10h
        mov     ah, 4Ch                 ; terminate, exit code 0FFh
        mov     al, 0FFh
        int     21h
isr_tick:
        cmp     ds:[seqBusy], 0
        jnz     isr_div
        mov     ds:[seqBusy], 1
        call    word ptr ds:[tickProc]
        mov     ds:[seqBusy], 0
isr_div:
        dec     ds:[divCount]
        jnz     isr_eoi
        mov     ds:[divCount], 13       ; chain the saved handler every 13th ch0 tick
        pop     si                      ;   the BIOS handler sends its own EOI
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        jmp     dword ptr cs:[oldInt8Off]
isr_eoi:
        mov     al, 20h
        out     20h, al
        pop     si
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        iret

; One tick of one voice: advance the level and pitch slides, fold in the LFO,
; resume the stream if the duration ran out, then advance the envelope.
voice_step:
        push    cx
        push    di
        mov     ax, [si].vfLevelAdd
        add     [si].vfLevel, ax
        mov     ax, [si].vfPeriodAdd
        add     [si].vfPeriod, ax
        sub     dx, dx
        mov     ax, [si].vfLfoPhase
        add     ax, [si].vfLfoRate
        jz      vs_nofreq
        cmp     ax, [si].vfLfoWrap
        jc      vs_store
        sub     ax, [si].vfLfoWrap
vs_store:
        mov     [si].vfLfoPhase, ax
        mov     cl, 4
        sar     ax, cl                  ; phase >> 4 indexes the waveform
        add     ax, [si].vfLfoTable
        mov     di, ax
        mov     ah, [di]                ; the sample goes in AH with AL zero, so the
        mov     al, 0                   ;   signed multiply leaves sample * depth / 256
        imul    [si].vfLfoDepth         ;   in DX, and DX is what the pitch picks up
vs_nofreq:
        add     dx, [si].vfPeriod
        mov     [si].vfOutPeriod, dx
        cmp     [si].vfGateLen, 0
        jz      vs_dur
        dec     [si].vfGateLen
        jnz     vs_dur
        mov     [si].vfEnvPos, 10h      ; the 5th (value,ticks) pair: the release
        mov     [si].vfEnvWait, 1
vs_dur:
        dec     [si].vfDuration
        jnz     vs_rel
        call    seq_proc
vs_rel:
        cmp     [si].vfEnvWait, 0
        jz      vs_done
        dec     [si].vfEnvWait
        jnz     vs_done
vs_relloop:
        mov     bx, [si].vfEnvBase
        add     bx, [si].vfEnvPos
        cmp     word ptr [bx+2], ENV_SETLEVEL
        jnz     vs_relset
        mov     ax, [bx]
        mov     [si].vfLevel, ax
        cmp     ax, 0
        jnz     vs_relskip
        mov     [si].vfLevelAdd, ax     ; a zero level stops the slide with it
vs_relskip:
        add     [si].vfEnvPos, 4
        jmp     vs_relloop
vs_relset:
        mov     ax, [bx]
        mov     [si].vfLevelAdd, ax
        mov     ax, [bx+2]
        mov     [si].vfEnvWait, ax
        add     [si].vfEnvPos, 4
vs_done:
        pop     di
        pop     cx
        ret

; Run this voice's stream until it yields.  DI is the stream cursor throughout.
seq_proc:
        mov     di, [si].vfStream
        cmp     di, 0
        jnz     seq_go
        ret
seq_go:
        mov     ds:[seqVoice], si
seq_loop:
        mov     bl, [di]
        inc     di
        cmp     bl, 0FAh
        jnc     seq_cmd
        jmp     seq_note
seq_cmd:
        sub     bh, bh
        sub     bl, 0FAh
        add     bl, bl
        jmp     cmdTable[bx]
seq_c_loop:                             ; 0FEh  SLOOP
        mov     bl, [di]
        inc     di
        mov     bh, 0
        mov     ax, [di]
        add     di, 2
        cmp     word ptr [bx+si], 0
        jz      seq_c_loop_set
        dec     word ptr [bx+si]
        jz      seq_loop
seq_c_loop_set:
        mov     di, ax
        jmp     seq_loop
seq_c_clear:                            ; 0FDh  SCLEAR
        mov     si, [di]
        add     di, 2
        add     si, ds:[voiceBase]
seq_c_reset:                            ; 0FAh  SRESET -- and SCLEAR's tail
        sub     bx, bx
        mov     [si].vfPeriod, bx
        mov     [si].vfPeriodAdd, bx
        mov     [si].vfOutPeriod, bx
        mov     [si].vfLevel, bx
        mov     [si].vfLevelAdd, bx
        mov     [si].vfReleaseLead, bx
        mov     [si].vfTranspose, bx
        mov     [si].vfEnvBase, bx
        mov     [si].vfEnvPos, bx
        mov     [si].vfEnvWait, bx
        mov     [si].vfLfoTable, bx
        mov     [si].vfLfoPhase, bx
        mov     [si].vfLfoRate, bx
        mov     [si].vfLfoDepth, bx
        mov     [si].vfLfoWrap, bx      ; vfDuration, vfStream, vfTempo, vfGateLen
        jmp     seq_loop                ;   and both loop counters survive a reset
seq_c_set:                              ; 0FFh  SSET
        mov     bl, [di]
        inc     di
        mov     bh, 0
        mov     ax, [di]
        inc     di
        inc     di
        mov     [bx+si], ax
        cmp     bl, 0                   ; field 0 is vfDuration, i.e. SWAIT, and a
        jnz     seq_loop                ;   SWAIT always yields
seq_end:
        mov     si, ds:[seqVoice]
        cmp     [si].vfDuration, 0
        jnz     seq_e_set
        mov     bl, 4                   ; 4 - voiceLeft is this voice's index
        sub     bl, ds:[voiceLeft]
        sub     bh, bh
        mov     voiceTune[bx], 0
        mov     di, 0
seq_e_set:
        mov     [si].vfStream, di
        ret
seq_c_ret:                              ; 0FBh  SRET
        mov     di, ds:[seqRet]
        mov     ds:[seqRet], 0          ; a return is used once
        cmp     di, 0
        jz      seq_r_none
        jmp     seq_loop
seq_r_none:                             ; nothing to return to: end the voice
        mov     si, ds:[seqVoice]       ;   rather than run from a stale pointer
        mov     [si].vfDuration, 0
        jmp     seq_end
seq_c_call:                             ; 0FCh  SCALL
        mov     ax, [di]
        add     di, 2
        mov     ds:[seqRet], di
        mov     di, ax
        jmp     seq_loop

; A note record: voice index and unused low bits, then the last flag and the pitch,
; then the duration.  Records run back to back until one carries the last flag.
seq_note_b:
        mov     bl, [di]
        inc     di
seq_note:
        push    di
        mov     al, bl
        mov     cl, 5
        shr     al, cl                  ; AL = the voice this note is for
        mul     ds:[blockSize]
        add     ax, ds:[voiceBase]
        mov     di, ax                  ; DI = that voice's block
        pop     bx
        push    bx
        mov     ax, [si].vfTempo
        cmp     al, 1
        ja      sn_mul
        xor     ah, ah
        mov     al, [bx+1]
        jmp     short sn_store
sn_mul:
        mul     byte ptr [bx+1]
sn_store:
        mov     [si].vfDuration, ax
        mov     al, [bx]                ; the last flag and the pitch share this byte
        and     ax, 7Fh
        cmp     ax, REST
        jz      sn_tail
        mov     cx, [si].vfDuration
        mov     [di].vfDuration, cx
        sub     cx, [di].vfReleaseLead  ; the release starts that many ticks early;
        jnc     sn_gate                 ;   a lead longer than the note gives no
        xor     cx, cx                  ;   release, as a gate of 0 does
sn_gate:
        mov     [di].vfGateLen, cx
        add     ax, [di].vfTranspose
        mov     [di].vfEnvPos, 0
        mov     [di].vfEnvWait, 1
        mov     cx, 0FFh                ; CL wraps to 0 on the first inc below
sn_oct:
        inc     cl
        sub     ax, OCT
        jnc     sn_oct
        add     ax, OCT                 ; CL = octave, AX = semitone
        mov     bx, ax
        add     bx, bx
        cmp     di, offset tandyVoice3  ; Both branches continue at the next instruction.
        jnz     sn_notspec
sn_notspec:
        add     bx, ds:[freqBase]
        mov     ax, [bx]
        shr     ax, cl
        mov     [di].vfPeriod, ax
        mov     [di].vfOutPeriod, ax
sn_tail:
        pop     di
        mov     al, [di]
        inc     di
        inc     di
        and     al, 80h
        jnz     sn_more
        jmp     seq_note_b
sn_more:
        jmp     seq_end

SetSoundOutputEnabled:
        push    bp
        mov     bp, sp
        push    ax
        push    ds
        mov     ax, CODE
        mov     ds, ax
        mov     ax, [bp+6]
        mov     ds:[outputOn], al
        pop     ds
        pop     ax
        pop     bp
        retf    2

; Pascal functions: the tick count P_isr keeps, in AX (one read, so a tick
; cannot split it), and whether the timer is hooked, in AL.
SoundTimerTicks:
        mov     ax, cs:[drvTicks]
        retf

SoundTimerHooked:
        mov     al, cs:[hooked]
        retf

; Pascal procedure: the device the ISR ticks, a C_Sound mode in the low byte; it
; also picks the device's tick from tickTable.  Leaving the AdLib silences it, and
; leaving the speaker drops its gate, so no note hangs on when a driver moves a
; sound to the other device (an effect on the speaker, then music on the AdLib).
SetSoundDevice:
        push    bp
        mov     bp, sp
        push    ax
        push    bx
        push    ds
        mov     ax, CODE
        mov     ds, ax
        mov     bl, [bp+6]
        xor     bh, bh
        cmp     bx, DEV_ADLIB           ; a value past the table is no device
        jbe     ssd_valid
        mov     bx, DEV_NONE
ssd_valid:
        cmp     bl, ds:[device]
        jz      ssd_set
        cmp     ds:[device], DEV_ADLIB
        jnz     ssd_spkr
        call    opl_silence
        jmp     short ssd_set
ssd_spkr:
        cmp     ds:[device], DEV_SPEAKER
        jnz     ssd_set
        PORT_IN 61h                     ; the speaker and timer gates off
        and     al, 0FCh
        PORT_OUT 61h
ssd_set:
        mov     cs:[device], bl
        add     bx, bx
        mov     bx, cs:tickTable[bx]
        mov     cs:[tickProc], bx
        pop     ds
        pop     bx
        pop     ax
        pop     bp
        retf    2

; No device: nothing to step or write.
tick_none:
        ret

; Pascal function: the tune voice [bp+6] (taken modulo 4) is still playing, in AX.
SoundVoiceTune:
        push    bp
        mov     bp, sp
        push    bx
        mov     bx, [bp+6]
        and     bx, 3
        mov     al, cs:voiceTune[bx]
        xor     ah, ah
        pop     bx
        pop     bp
        retf    2

IFDEF TRACE
; ---------------------------------------------------------------------------
; The trace build's entries, for the sequencer's tests.
; ---------------------------------------------------------------------------
traceOff        dw      0               ; the buffer of words: port in the high byte, value in the low
traceSeg        dw      0
traceCap        dw      0               ; words it holds
traceLen        dw      0               ; words recorded since SetTraceBuffer

; Record AL written to port AH; a full buffer drops the rest.  Keeps every register.
trace_out:
        push    bx
        push    di
        push    es
        mov     bx, cs:[traceLen]
        cmp     bx, cs:[traceCap]
        jae     to_full
        les     di, dword ptr cs:[traceOff]
        add     bx, bx
        mov     es:[di+bx], ax
        inc     cs:[traceLen]
to_full:
        pop     es
        pop     di
        pop     bx
        ret

; Pascal procedure SetTraceBuffer(buf: Pointer; capacity: Word): record into buf, capacity words, from the start.
SetTraceBuffer:
        push    bp
        mov     bp, sp
        push    ax
        mov     ax, [bp+6]
        mov     cs:[traceCap], ax
        mov     ax, [bp+8]
        mov     cs:[traceOff], ax
        mov     ax, [bp+10]
        mov     cs:[traceSeg], ax
        mov     cs:[traceLen], 0
        pop     ax
        pop     bp
        retf    6

; Pascal function TraceCount: Word: the words recorded.
TraceCount:
        mov     ax, cs:[traceLen]
        retf

; Pascal procedure TraceTick: one timer tick's sequencing, as the interrupt runs it, without the BIOS chain.
TraceTick:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        mov     ax, CODE
        mov     ds, ax
        cmp     ds:[seqBusy], 0
        jnz     tt_done
        mov     ds:[seqBusy], 1
        call    word ptr ds:[tickProc]
        mov     ds:[seqBusy], 0
tt_done:
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        retf
ENDIF

CODE    ENDS
        END
