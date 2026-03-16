; ============================================================
; Color Palette Data
; ============================================================
.segment "RODATA"

; Title screen palette
palette_title:
    ; Background palettes
    .byte $0F, $30, $10, $28    ; BG0: Black, White, Gray, Yellow/Gold
    .byte $0F, $30, $16, $06    ; BG1: Black, White, Red, Dark Red
    .byte $0F, $30, $1A, $0A    ; BG2: Black, White, Green, Dark Green
    .byte $0F, $30, $12, $02    ; BG3: Black, White, Blue, Dark Blue
    ; Sprite palettes
    .byte $0F, $17, $27, $28    ; SPR0: Title letters (Brown, Orange, Gold)
    .byte $0F, $30, $10, $00    ; SPR1
    .byte $0F, $30, $10, $00    ; SPR2
    .byte $0F, $30, $10, $00    ; SPR3

; Dungeon gameplay palette
palette_dungeon:
    ; Background palettes
    .byte $0F, $30, $10, $00    ; BG0: Dungeon (Black, White, Gray, Dark Gray)
    .byte $0F, $16, $27, $28    ; BG1: Warm monsters (Black, Red, Orange, Yellow)
    .byte $0F, $1A, $2C, $12    ; BG2: Cool monsters (Black, Green, Cyan, Blue)
    .byte $0F, $24, $30, $28    ; BG3: Items/UI (Black, Purple, White, Yellow)
    ; Sprite palettes
    .byte $0F, $30, $10, $00    ; SPR0: Cursor
    .byte $0F, $30, $10, $00    ; SPR1
    .byte $0F, $30, $10, $00    ; SPR2
    .byte $0F, $30, $10, $00    ; SPR3
