;
; NES startup code for cc65 with none.lib
; Handles reset, NMI, and initialization
;

.import _main
.import __RAM_START__, __RAM_SIZE__
.import __DATA_LOAD__, __DATA_RUN__, __DATA_SIZE__
.import __BSS_LOAD__, __BSS_SIZE__
.import __STACKSIZE__

; Required by none.lib runtime
.importzp sp
.export __STARTUP__ : absolute = 1

.segment "ZEROPAGE"

; Runtime variables
nmi_ready:      .res 1
ptr1:           .res 2
ptr2:           .res 2
tmp1:           .res 1
tmp2:           .res 1

.segment "BSS"

; OAM buffer (must be page-aligned at $0200 via linker config)
.export _oam_buffer
_oam_buffer:    .res 256

; Frame counter
.export _frame_counter
_frame_counter: .res 1

.segment "HEADER"

; iNES header
.byte "NES", $1A     ; Magic number
.byte 2              ; 2x 16KB PRG-ROM = 32KB
.byte 1              ; 1x 8KB CHR-ROM
.byte $01            ; Mapper 0, vertical mirroring
.byte $00            ; Mapper 0 (high nibble)
.byte $00            ; No PRG-RAM
.byte $00            ; NTSC
.byte $00, $00, $00, $00, $00, $00  ; Padding

.segment "STARTUP"

; Reset handler
.proc reset
    sei                 ; Disable interrupts
    cld                 ; Clear decimal mode
    ldx #$40
    stx $4017           ; Disable APU frame IRQ
    ldx #$FF
    txs                 ; Set up stack
    inx                 ; X = 0
    stx $2000           ; Disable NMI
    stx $2001           ; Disable rendering
    stx $4010           ; Disable DMC IRQs

    ; First wait for vblank
:   bit $2002
    bpl :-

    ; Clear RAM ($0000-$07FF)
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

    ; Hide all sprites (set Y to $FF)
    lda #$FF
    ldx #$00
@clear_oam:
    sta $0200, x
    inx
    inx
    inx
    inx
    bne @clear_oam

    ; Second wait for vblank (PPU is ready after this)
:   bit $2002
    bpl :-

    ; Initialize cc65 runtime stack pointer
    lda #<(__RAM_START__ + __RAM_SIZE__)
    sta sp
    lda #>(__RAM_START__ + __RAM_SIZE__)
    sta sp+1

    ; Copy DATA segment from ROM to RAM
    lda #<__DATA_LOAD__
    sta ptr1
    lda #>__DATA_LOAD__
    sta ptr1+1
    lda #<__DATA_RUN__
    sta ptr2
    lda #>__DATA_RUN__
    sta ptr2+1

    ; Copy DATA segment from ROM to RAM (forward copy)
    ldy #0
    ldx #>__DATA_SIZE__     ; Number of complete pages
    beq @copy_remaining     ; Skip if no complete pages
@copy_page:
    lda (ptr1), y
    sta (ptr2), y
    iny
    bne @copy_page
    inc ptr1+1
    inc ptr2+1
    dex
    bne @copy_page
@copy_remaining:
    ldx #<__DATA_SIZE__     ; Remaining bytes
    beq @data_done
@copy_byte:
    lda (ptr1), y
    sta (ptr2), y
    iny
    dex
    bne @copy_byte
@data_done:

    ; Jump to C main
    jmp _main
.endproc

; NMI handler (called during vblank)
.proc nmi
    pha
    txa
    pha
    tya
    pha

    ; Sprite DMA
    lda #$00
    sta $2003
    lda #$02            ; OAM buffer at $0200
    sta $4014

    ; Increment frame counter
    inc _frame_counter

    ; Signal that NMI happened
    lda #1
    sta nmi_ready

    pla
    tay
    pla
    tax
    pla
    rti
.endproc

; IRQ handler (unused)
.proc irq
    rti
.endproc

; PPU helper functions for C code
.segment "CODE"

.export _ppu_wait_vblank
.proc _ppu_wait_vblank
    ; Use $2002 polling - works whether NMI is enabled or not
    lda $2002           ; Clear vblank flag first
@wait:
    lda $2002           ; Read PPU status
    bpl @wait           ; Loop until bit 7 (vblank) is set
    rts
.endproc

.export _ppu_set_addr
.proc _ppu_set_addr
    ; Address in A (low) and X (high)
    stx $2006
    sta $2006
    rts
.endproc

.export _ppu_write
.proc _ppu_write
    sta $2007
    rts
.endproc

.segment "VECTORS"
.word nmi
.word reset
.word irq
