; ============================================================
; SFX Engine — Simple fire-and-forget sound effects
; Uses NES APU pulse 1, triangle, and noise channels.
; Data format: <count> <reg> <val> [...] <delay> ... $FF
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; sfx_init
; Enable APU channels and silence everything.
; Called once from reset.
; ------------------------------------------------------------
.proc sfx_init
    ; Enable pulse 1, pulse 2, triangle, noise
    lda #%00001111
    sta $4015

    ; Silence pulse 1
    lda #%00110000              ; Halt, constant volume, vol=0
    sta $4000
    lda #$00
    sta $4001
    sta $4002
    sta $4003

    ; Silence pulse 2
    lda #%00110000
    sta $4004
    lda #$00
    sta $4005
    sta $4006
    sta $4007

    ; Silence triangle
    lda #%10000000              ; Halt linear counter
    sta $4008
    lda #$00
    sta $400A
    sta $400B

    ; Silence noise
    lda #%00110000
    sta $400C
    lda #$00
    sta $400E
    sta $400F

    ; Init state
    lda #SFX_NONE
    sta sfx_id
    sta sfx_request
    lda #$00
    sta sfx_timer

    rts
.endproc

; ------------------------------------------------------------
; sfx_play
; Queue a sound effect to play.
; Input: A = SFX ID (SFX_FOOTSTEP, etc.)
; ------------------------------------------------------------
.proc sfx_play
    sta sfx_request
    rts
.endproc

; ------------------------------------------------------------
; sfx_update
; Advance the SFX engine by one frame. Called from NMI.
; Safe to call from interrupt context (preserves all temps).
; ------------------------------------------------------------
.proc sfx_update
    ; --- Check for new request ---
    lda sfx_request
    cmp #SFX_NONE
    beq @no_request

    ; Start new SFX: look up data pointer
    tax
    lda sfx_table_lo, x
    sta sfx_ptr_lo
    lda sfx_table_hi, x
    sta sfx_ptr_hi
    lda #$01                    ; Process first group immediately
    sta sfx_timer
    stx sfx_id
    lda #SFX_NONE
    sta sfx_request

@no_request:
    ; --- Is anything playing? ---
    lda sfx_id
    cmp #SFX_NONE
    beq @idle

    ; --- Decrement timer ---
    dec sfx_timer
    bne @idle                   ; Still waiting

    ; --- Process next group ---
    ldy #$00
    lda (sfx_ptr_lo), y        ; Read count byte
    cmp #$FF
    beq @sfx_done              ; End of SFX

    sta temp_4                  ; Save count (safe: NMI doesn't use temp_4 elsewhere)
    iny

@reg_loop:
    lda temp_4
    beq @read_delay             ; All pairs processed
    lda (sfx_ptr_lo), y        ; Register offset
    tax
    iny
    lda (sfx_ptr_lo), y        ; Value
    sta $4000, x               ; Write to APU register
    iny
    dec temp_4
    jmp @reg_loop

@read_delay:
    lda (sfx_ptr_lo), y        ; Delay frames
    sta sfx_timer
    iny

    ; Advance pointer by Y bytes consumed
    tya
    clc
    adc sfx_ptr_lo
    sta sfx_ptr_lo
    bcc @no_carry
    inc sfx_ptr_hi
@no_carry:

@idle:
    rts

@sfx_done:
    ; Silence all channels
    lda #%00110000
    sta $4000
    sta $4004
    sta $400C
    lda #%10000000
    sta $4008
    lda #SFX_NONE
    sta sfx_id
    rts
.endproc
