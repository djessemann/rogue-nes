; ============================================================
; PPU Utility Routines
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; load_palettes
; Copy 32 bytes of palette data to PPU $3F00.
; Must be called with rendering disabled.
; Expects palette data address in ptr_lo/ptr_hi.
; ------------------------------------------------------------
.proc load_palettes
    lda $2002                   ; Reset PPU address latch
    lda #$3F
    sta $2006
    lda #$00
    sta $2006                   ; PPU address = $3F00

    ldy #$00
@loop:
    lda (ptr_lo), y
    sta $2007
    iny
    cpy #$20                    ; 32 bytes = 4 BG + 4 sprite palettes
    bne @loop

    ; Reset PPU address and scroll
    lda #$00
    sta $2006
    sta $2006
    sta $2005
    sta $2005
    rts
.endproc

; ------------------------------------------------------------
; set_level_bg_color
; Override the universal background color ($3F00) based on
; dungeon_level. Must be called after load_palettes with
; rendering disabled.
; ------------------------------------------------------------
.proc set_level_bg_color
    ; Calculate level mod 13 for table index
    lda dungeon_level
@mod_loop:
    cmp #13
    bcc @got_index
    sec
    sbc #13
    jmp @mod_loop
@got_index:
    tax

    ; Write background color to PPU $3F00
    lda $2002                   ; Reset PPU latch
    lda #$3F
    sta $2006
    lda #$00
    sta $2006
    lda level_bg_colors, x
    sta $2007

    ; Write wall inner color to PPU $3F02 (BG0 color 2)
    lda $2002
    lda #$3F
    sta $2006
    lda #$02
    sta $2006
    lda level_wall_inner_colors, x
    sta $2007

    ; Write wall border color to PPU $3F03 (BG0 color 3)
    lda $2002
    lda #$3F
    sta $2006
    lda #$03
    sta $2006
    lda level_wall_colors, x
    sta $2007

    ; Reset PPU address and scroll
    lda #$00
    sta $2006
    sta $2006
    sta $2005
    sta $2005
    rts
.endproc

; ------------------------------------------------------------
; clear_nametable
; Fill nametable 0 ($2000-$23FF) with tile $00 and zero attributes.
; Must be called with rendering disabled.
; ------------------------------------------------------------
.proc clear_nametable
    lda $2002                   ; Reset PPU address latch
    lda #$20
    sta $2006
    lda #$00
    sta $2006                   ; PPU address = $2000

    ; Write 1024 bytes of $00 (960 tiles + 64 attribute bytes)
    lda #$00
    ldx #$04                    ; 4 x 256 = 1024
    ldy #$00
@loop:
    sta $2007
    iny
    bne @loop
    dex
    bne @loop
    rts
.endproc

; ------------------------------------------------------------
; ppu_set_rc — Point PPUADDR at nametable-0 tile (row, col).
; Input: A = row (0-29), addr_temp_lo = col (0-31)
; For NT0, low byte = ((row & 7) << 5) + col always fits one byte,
; high byte = $20 + (row >> 3).  Must be called with rendering off.
; Clobbers A. Resets the $2005/$2006 latch via $2002.
; ------------------------------------------------------------
.proc ppu_set_rc
    pha                         ; save row
    lsr a
    lsr a
    lsr a                       ; A = row >> 3
    clc
    adc #$20                    ; high byte
    bit $2002                   ; reset address latch
    sta $2006
    pla                         ; A = row
    and #$07
    asl a
    asl a
    asl a
    asl a
    asl a                       ; (row & 7) << 5
    clc
    adc addr_temp_lo            ; + col
    sta $2006
    rts
.endproc

; ------------------------------------------------------------
; fill_attr — Fill attribute table 0 ($23C0-$23FF) with A.
; $00 = palette 0, $55 = pal 1, $AA = pal 2, $FF = pal 3.
; Must be called with rendering disabled.
; ------------------------------------------------------------
.proc fill_attr
    pha
    bit $2002
    lda #$23
    sta $2006
    lda #$C0
    sta $2006
    pla
    ldx #64
@l:
    sta $2007
    dex
    bne @l
    rts
.endproc

; ------------------------------------------------------------
; draw_box — Draw a single-line frame border.
; Input: temp_1 = left col, temp_2 = top row,
;        temp_3 = width (>=2), temp_4 = height (>=2)
; Interior tiles are left untouched. Rendering must be off.
; Clobbers A/X, temp regs ptr_hi and addr_temp_lo/hi (scratch).
; ------------------------------------------------------------
.proc draw_box
    ; --- Top edge ---
    lda temp_1
    sta addr_temp_lo            ; col = left
    lda temp_2                  ; row = top
    jsr ppu_set_rc
    lda #CHR_BOX_TL
    sta $2007
    ldx temp_3
    dex
    dex                         ; width - 2 interior
    lda #CHR_BOX_H
@top:
    sta $2007
    dex
    bne @top
    lda #CHR_BOX_TR
    sta $2007

    ; --- Bottom edge ---
    lda temp_1
    sta addr_temp_lo
    lda temp_2
    clc
    adc temp_4
    sec
    sbc #$01                    ; row = top + height - 1
    jsr ppu_set_rc
    lda #CHR_BOX_BL
    sta $2007
    ldx temp_3
    dex
    dex
    lda #CHR_BOX_H
@bot:
    sta $2007
    dex
    bne @bot
    lda #CHR_BOX_BR
    sta $2007

    ; --- Side edges: rows top+1 .. top+height-2 ---
    lda temp_4
    sec
    sbc #$02
    sta addr_temp_hi            ; counter = height - 2
    lda temp_2
    clc
    adc #$01
    sta ptr_hi                  ; current row
@side:
    lda addr_temp_hi
    beq @done
    ; left edge (col = left)
    lda temp_1
    sta addr_temp_lo
    lda ptr_hi
    jsr ppu_set_rc
    lda #CHR_BOX_V
    sta $2007
    ; right edge (col = left + width - 1)
    lda temp_1
    clc
    adc temp_3
    sec
    sbc #$01
    sta addr_temp_lo
    lda ptr_hi
    jsr ppu_set_rc
    lda #CHR_BOX_V
    sta $2007
    inc ptr_hi
    dec addr_temp_hi
    jmp @side
@done:
    rts
.endproc

; ------------------------------------------------------------
; draw_text
; Buffer a null-terminated ASCII string into VRAM buffer.
; ASCII codes map directly to CHR tile indices.
;
; Input: ptr_lo/ptr_hi = string address
;        temp_1 = nametable tile X (0-31)
;        temp_2 = nametable tile Y (0-29)
; Clobbers: A, X, Y, temp_3, temp_4
; ------------------------------------------------------------
.proc draw_text
    ; Calculate nametable address: $2000 + (Y * 32) + X
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20                    ; Base nametable at $2000
    sta temp_4                  ; temp_4 = address high byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a                       ; A = (Y & 7) * 32
    clc
    adc temp_1                  ; A = low byte + X offset
    sta temp_3                  ; temp_3 = address low byte
    bcc @no_carry
    inc temp_4
@no_carry:

    ; First pass: count string length
    ldy #$00
@count:
    lda (ptr_lo), y
    beq @counted
    iny
    jmp @count
@counted:
    sty temp_1                  ; temp_1 = string length (reuse)

    ; Overflow guard: check if buffer has room for 3 + length bytes
    tya
    clc
    adc #$03                    ; 3 header bytes + string length
    clc
    adc vram_buf_len
    bcs @overflow               ; carry = would exceed 255

    ; Write VRAM buffer entry: [addr_hi, addr_lo, length, data...]
    ldx vram_buf_len
    lda temp_4
    sta vram_buf, x
    inx
    lda temp_3
    sta vram_buf, x
    inx
    lda temp_1
    sta vram_buf, x
    inx

    ; Copy string bytes (tile indices = ASCII values)
    ldy #$00
@copy:
    cpy temp_1
    beq @done
    lda (ptr_lo), y
    sta vram_buf, x
    inx
    iny
    jmp @copy
@done:
    stx vram_buf_len
@overflow:
    rts
.endproc

; ------------------------------------------------------------
; draw_number
; Draw a 1-2 digit decimal number to VRAM buffer.
;
; Input: A = number (0-99)
;        temp_1 = nametable tile X
;        temp_2 = nametable tile Y
; Clobbers: A, X, Y, temp_3, temp_4
; ------------------------------------------------------------
.proc draw_number
    sta temp_3                  ; Save number

    ; Overflow guard: max 5 bytes (3 header + 2 digits)
    lda vram_buf_len
    clc
    adc #$05
    bcs @overflow_early         ; carry = would exceed 255

    ; Calculate nametable address
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_4                  ; High byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_1
    pha                         ; Save low byte

    ; Single or two digits?
    lda temp_3
    cmp #10
    bcs @two_digits

    ; --- Single digit ---
    ldx vram_buf_len
    lda temp_4
    sta vram_buf, x
    inx
    pla
    sta vram_buf, x
    inx
    lda #$01
    sta vram_buf, x
    inx
    lda temp_3
    clc
    adc #$30                    ; ASCII '0'
    sta vram_buf, x
    inx
    stx vram_buf_len
    rts

@two_digits:
    ldy #$00                    ; Tens counter
    lda temp_3
@div10:
    cmp #10
    bcc @div_done
    sec
    sbc #10
    iny
    jmp @div10
@div_done:
    sta temp_3                  ; Ones digit

    ldx vram_buf_len
    lda temp_4
    sta vram_buf, x
    inx
    pla
    sta vram_buf, x
    inx
    lda #$02
    sta vram_buf, x
    inx
    tya
    clc
    adc #$30                    ; Tens tile
    sta vram_buf, x
    inx
    lda temp_3
    clc
    adc #$30                    ; Ones tile
    sta vram_buf, x
    inx
    stx vram_buf_len
@overflow_early:
    rts
.endproc

; ------------------------------------------------------------
; draw_number_3d
; Draw a 1-3 digit decimal number to VRAM buffer.
; Always writes 3 characters (space-padded on left).
;
; Input: A = number low byte, temp_3 = number high byte (for >255)
;        For now, supports 0-255 only (high byte ignored).
;        temp_1 = nametable tile X
;        temp_2 = nametable tile Y
; Clobbers: A, X, Y, temp_3, temp_4
; ------------------------------------------------------------
.proc draw_number_3d
    sta temp_3                  ; Save number

    ; Overflow guard: 6 bytes (3 header + 3 digits)
    lda vram_buf_len
    clc
    adc #$06
    bcs @overflow_early         ; carry = would exceed 255

    ; Calculate nametable address
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_4                  ; High byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_1

    ; Write 3-char VRAM buffer entry
    ldx vram_buf_len
    pha
    lda temp_4
    sta vram_buf, x
    inx
    pla
    sta vram_buf, x
    inx
    lda #$03
    sta vram_buf, x
    inx

    ; Divide by 100
    ldy #$00                    ; Hundreds counter
    lda temp_3
@div100:
    cmp #100
    bcc @div100_done
    sec
    sbc #100
    iny
    jmp @div100
@div100_done:
    sta temp_3                  ; Remainder

    ; Hundreds digit (or space if 0)
    cpy #$00
    bne @write_hundreds
    lda #$20                    ; Space
    sta vram_buf, x
    inx
    jmp @do_tens
@write_hundreds:
    tya
    clc
    adc #$30
    sta vram_buf, x
    inx

@do_tens:
    ; Divide remainder by 10
    ldy #$00
    lda temp_3
@div10:
    cmp #10
    bcc @div10_done
    sec
    sbc #10
    iny
    jmp @div10
@div10_done:
    sta temp_3                  ; Ones digit

    tya
    clc
    adc #$30
    sta vram_buf, x
    inx

    lda temp_3
    clc
    adc #$30
    sta vram_buf, x
    inx

    stx vram_buf_len
@overflow_early:
    rts
.endproc

; ------------------------------------------------------------
; vram_write_tile
; Queue a single tile write to the VRAM buffer.
;
; Input: A = tile index
;        temp_1 = nametable tile X (0-31)
;        temp_2 = nametable tile Y (0-29)
; Clobbers: X, temp_3, temp_4
; ------------------------------------------------------------
.proc vram_write_tile
    ; Overflow guard: 4 bytes (3 header + 1 tile)
    pha                         ; Save tile
    lda vram_buf_len
    clc
    adc #$04
    pla                         ; Restore tile (A = tile again)
    bcs @overflow               ; carry from adc = would exceed 255
    pha                         ; Re-save tile for later

    ; Calculate nametable address: $2000 + (Y * 32) + X
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_4                  ; High byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_1
    sta temp_3                  ; Low byte
    bcc @no_carry
    inc temp_4
@no_carry:

    ldx vram_buf_len
    lda temp_4
    sta vram_buf, x
    inx
    lda temp_3
    sta vram_buf, x
    inx
    lda #$01                    ; Length = 1
    sta vram_buf, x
    inx
    pla                         ; Tile index
    sta vram_buf, x
    inx
    stx vram_buf_len
@overflow:
    rts
.endproc

; ------------------------------------------------------------
; clear_oam_sprites
; Set all 64 sprite Y positions to $FF (offscreen/hidden).
; ------------------------------------------------------------
.proc clear_oam_sprites
    lda #$FF
    ldx #$00
@loop:
    sta oam_buf, x
    inx
    inx
    inx
    inx
    bne @loop
    rts
.endproc

; ============================================================
; Direct PPU routines (use only when rendering is OFF)
; ============================================================

; ------------------------------------------------------------
; ppu_set_addr
; Set PPU address for tile at (temp_1, temp_2).
; Input: temp_1 = X (0-31), temp_2 = Y (0-29)
; ------------------------------------------------------------
.proc ppu_set_addr
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta $2006                   ; High byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_1
    sta $2006                   ; Low byte
    rts
.endproc

; ------------------------------------------------------------
; ppu_draw_text
; Draw null-terminated string directly to PPU (rendering off).
; Input: ptr_lo/ptr_hi = string, temp_1 = X, temp_2 = Y
; Clobbers: A, Y, temp_1-4
; ------------------------------------------------------------
.proc ppu_draw_text
    lda $2002                   ; Reset PPU latch
    jsr ppu_set_addr

    ldy #$00
@loop:
    lda (ptr_lo), y
    beq @done
    sta $2007
    iny
    jmp @loop
@done:
    rts
.endproc

; ------------------------------------------------------------
; ppu_draw_number
; Draw a 1-3 digit number directly to PPU (rendering off).
; Input: A = number (0-255), temp_1 = X, temp_2 = Y
; Clobbers: A, X, Y, temp_1-4
; ------------------------------------------------------------
.proc ppu_draw_number
    sta temp_3                  ; Save number

    lda $2002                   ; Reset PPU latch
    jsr ppu_set_addr

    jmp ppu_write_3digits       ; Share digit-writing code
.endproc

; ------------------------------------------------------------
; ppu_draw_number_continue
; Write a compact number to PPU at the current address
; (no latch reset, no address set — continues from last write).
; No leading spaces — writes only significant digits (1-3 chars).
; Input: A = number (0-255)
; Clobbers: A, X, Y, temp_3
; ------------------------------------------------------------
.proc ppu_draw_number_continue
    sta temp_3
    ldx #$00                    ; X=1 if we've written any digit

    ; Hundreds digit (skip if zero)
    ldy #$00
    lda temp_3
@div100:
    cmp #100
    bcc @div100_done
    sec
    sbc #100
    iny
    jmp @div100
@div100_done:
    sta temp_3
    cpy #$00
    beq @do_tens
    tya
    clc
    adc #$30
    sta $2007
    ldx #$01                    ; Wrote hundreds

@do_tens:
    ldy #$00
    lda temp_3
@div10:
    cmp #10
    bcc @div10_done
    sec
    sbc #10
    iny
    jmp @div10
@div10_done:
    sta temp_3

    ; Tens digit: write if nonzero OR if we wrote hundreds
    tya
    bne @write_tens
    cpx #$00
    beq @ones                   ; Skip leading zero tens
@write_tens:
    clc
    adc #$30
    sta $2007

@ones:
    lda temp_3
    clc
    adc #$30
    sta $2007

    rts
.endproc

; Shared digit-writing code for ppu_draw_number variants
.proc ppu_write_3digits
    ; Divide by 100
    ldy #$00
    lda temp_3
@div100:
    cmp #100
    bcc @div100_done
    sec
    sbc #100
    iny
    jmp @div100
@div100_done:
    sta temp_3

    ; Hundreds digit (or space)
    cpy #$00
    bne @write_hundreds
    lda #$20                    ; Space
    sta $2007
    jmp @do_tens
@write_hundreds:
    tya
    clc
    adc #$30
    sta $2007

@do_tens:
    ldy #$00
    lda temp_3
@div10:
    cmp #10
    bcc @div10_done
    sec
    sbc #10
    iny
    jmp @div10
@div10_done:
    sta temp_3

    ; Tens digit
    tya
    clc
    adc #$30
    sta $2007

    ; Ones digit
    lda temp_3
    clc
    adc #$30
    sta $2007

    rts
.endproc
