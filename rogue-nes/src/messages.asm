; ============================================================
; Message Log — Single line display at bottom of screen
; Uses priority system: higher priority messages can't be
; overwritten by lower priority ones within the same turn.
; Priority 0 = normal, 1 = combat, 2 = kill/level up
;
; msg_show only updates msg_buf and sets msg_dirty.
; msg_flush does the actual VRAM write (called once per frame).
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; msg_show
; Queue a message for display. Does NOT write to VRAM.
; The actual VRAM write happens in msg_flush (once per frame).
; Input: ptr_lo/ptr_hi = pointer to null-terminated string
; Clobbers: A, Y
; ------------------------------------------------------------
.proc msg_show
    ; Check priority: skip if current turn already has higher priority msg
    lda msg_new_priority
    cmp msg_turn_priority
    bcc @skip                   ; New priority < current, skip

    ; Update turn priority
    sta msg_turn_priority

    ; Copy new message into msg_buf
    ldy #$00
@copy:
    lda (ptr_lo), y
    sta msg_buf, y
    beq @copy_done
    iny
    cpy #31
    bne @copy
    lda #$00
    sta msg_buf, y
@copy_done:

    ; Mark message as needing display
    lda #$01
    sta msg_dirty

@skip:
    lda #$00
    sta msg_new_priority        ; Always reset incoming priority
    rts
.endproc

; ------------------------------------------------------------
; msg_flush
; Write the current msg_buf to VRAM row 28 if msg_dirty is set.
; Called once per frame from the main game loop.
; Clobbers: A, X, Y, temp_1-4
; ------------------------------------------------------------
.proc msg_flush
    lda msg_dirty
    beq @done

    lda #$00
    sta msg_dirty

    ; Clear row 28
    lda #$00
    sta temp_1
    lda #MSG_ROW_0
    sta temp_2
    jsr clear_msg_row

    ; Draw msg_buf on row 28
    lda #<msg_buf
    sta ptr_lo
    lda #>msg_buf
    sta ptr_hi
    lda #$00
    sta temp_1
    lda #MSG_ROW_0
    sta temp_2
    jsr draw_text

@done:
    rts
.endproc

; ------------------------------------------------------------
; msg_show_build
; Display the contents of msg_build buffer as a message.
; Convenience wrapper: points msg_show at msg_build.
; ------------------------------------------------------------
.proc msg_show_build
    lda #<msg_build
    sta ptr_lo
    lda #>msg_build
    sta ptr_hi
    jsr msg_show
    rts
.endproc

; ------------------------------------------------------------
; msg_start
; Reset msg_build buffer position to 0.
; ------------------------------------------------------------
.proc msg_start
    lda #$00
    sta msg_build_pos
    rts
.endproc

; ------------------------------------------------------------
; msg_append
; Append a null-terminated string to msg_build.
; Input: ptr_lo/ptr_hi = string to append
; Preserves: X
; ------------------------------------------------------------
.proc msg_append
    stx temp_3                  ; Save X (often holds mon index)
    ldy #$00
    ldx msg_build_pos
@loop:
    cpx #31                     ; Max 31 chars
    bcs @done
    lda (ptr_lo), y
    beq @done
    sta msg_build, x
    inx
    iny
    jmp @loop
@done:
    lda #$00
    sta msg_build, x            ; Null terminate
    stx msg_build_pos
    ldx temp_3                  ; Restore X
    rts
.endproc

; ------------------------------------------------------------
; msg_append_monster_name
; Append the name of monster type Y to msg_build.
; Input: Y = monster type index (0-4)
; Preserves: X
; ------------------------------------------------------------
.proc msg_append_monster_name
    lda mon_name_lo, y
    sta ptr_lo
    lda mon_name_hi, y
    sta ptr_hi
    jsr msg_append
    rts
.endproc

; ------------------------------------------------------------
; clear_msg_row
; Queue blank tiles for a message row.
; Input: temp_1 = X start, temp_2 = row
; ------------------------------------------------------------
.proc clear_msg_row
    ; Overflow guard: 35 bytes (3 header + 32 spaces)
    lda vram_buf_len
    clc
    adc #35
    bcs @overflow               ; carry = would exceed 255

    ; Write 32 spaces to clear the row
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_4                  ; PPU addr high

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a
    sta temp_3                  ; PPU addr low

    ldx vram_buf_len
    lda temp_4
    sta vram_buf, x
    inx
    lda temp_3
    sta vram_buf, x
    inx
    lda #$20                    ; 32 tiles
    sta vram_buf, x
    inx

    ldy #$20
    lda #$20                    ; Space character
@loop:
    sta vram_buf, x
    inx
    dey
    bne @loop

    stx vram_buf_len
@overflow:
    rts
.endproc
