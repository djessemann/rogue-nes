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

; Per-level background colors (NES row 0 darks, 13 entries)
; Cycles through all dark hues, one per dungeon level
level_bg_colors:
    .byte $0F               ; Level 0: black (classic)
    .byte $02               ; Level 1: dark indigo
    .byte $06               ; Level 2: dark red
    .byte $09               ; Level 3: dark green
    .byte $03               ; Level 4: dark purple
    .byte $07               ; Level 5: dark brown
    .byte $0C               ; Level 6: dark cyan
    .byte $05               ; Level 7: dark crimson
    .byte $08               ; Level 8: dark olive
    .byte $01               ; Level 9: dark navy
    .byte $04               ; Level 10: dark magenta
    .byte $0A               ; Level 11: dark forest
    .byte $00               ; Level 12: dark gray

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
