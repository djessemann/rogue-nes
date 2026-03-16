; ============================================================
; Reset Handler — Standard NES boot sequence
; ============================================================
.segment "CODE"

.proc reset
    sei                         ; Disable IRQs
    cld                         ; Clear decimal mode
    ldx #$40
    stx $4017                   ; Disable APU frame IRQ
    ldx #$FF
    txs                         ; Initialize stack pointer to $01FF
    inx                         ; X = $00
    stx $2000                   ; Disable NMI
    stx $2001                   ; Disable rendering
    stx $4010                   ; Disable DMC IRQs

    ; --- Wait for first vblank ---
@vblank1:
    bit $2002
    bpl @vblank1

    ; --- Clear all RAM ($0000-$07FF) ---
    lda #$00
    ldx #$00
@clear_ram:
    sta $0000, x
    sta $0100, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne @clear_ram

    ; --- Hide all sprites (Y position = $FF = off-screen) ---
    lda #$FF
    ldx #$00
@clear_oam:
    sta oam_buf, x
    inx
    bne @clear_oam

    ; --- Wait for second vblank (PPU is now fully warmed up) ---
@vblank2:
    bit $2002
    bpl @vblank2

    ; --- Initialize MMC1 mapper ---
    ; Reset shift register
    lda #$80
    sta $8000

    ; Write Control register ($8000): %01100
    ; bit0=0 (horiz mirror), bit1-2=11 (PRG fix $C000), bit3=0 (CHR 8KB), bit4=0
    lda #%01100
    sta $8000                   ; bit 0
    lsr a
    sta $8000                   ; bit 1
    lsr a
    sta $8000                   ; bit 2
    lsr a
    sta $8000                   ; bit 3
    lsr a
    sta $8000                   ; bit 4 (commit)

    ; Write PRG bank register ($E000): $00 = bank 0, WRAM enabled (bit4=0)
    lda #$00
    sta $E000
    lsr a
    sta $E000
    lsr a
    sta $E000
    lsr a
    sta $E000
    lsr a
    sta $E000

    ; --- Clear WRAM ($6000-$7FFF) ---
    lda #$00
    sta ptr_lo
    lda #$60
    sta ptr_hi
    lda #$00
    tay
@clear_wram:
    sta (ptr_lo), y
    iny
    bne @clear_wram
    inc ptr_hi
    lda ptr_hi
    cmp #$80                    ; Stop at $8000
    bne @clear_wram_cont
    jmp @wram_done
@clear_wram_cont:
    lda #$00
    jmp @clear_wram
@wram_done:

    ; PPU is ready — jump to main game initialization
    jmp main
.endproc
