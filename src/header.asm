; ============================================================
; iNES Header (16 bytes)
; SxROM (MMC1): 32KB PRG-ROM + 8KB CHR-ROM + 8KB WRAM
; Horizontal mirroring (controlled by mapper)
; ============================================================
.segment "HEADER"
    .byte "NES", $1A            ; iNES magic number
    .byte $02                   ; 2 x 16KB PRG-ROM banks = 32KB
    .byte $01                   ; 1 x 8KB CHR-ROM bank = 8KB
    .byte %00010010             ; Flags 6: mapper 1 low nibble, battery WRAM
    .byte %00000000             ; Flags 7: mapper 1 high nibble = 0
    .byte $01                   ; Flags 8: 8KB PRG-RAM
    .byte $00                   ; Flags 9: TV system (NTSC)
    .byte $00                   ; Flags 10: unused
    .byte $00, $00, $00, $00, $00  ; Padding to 16 bytes
