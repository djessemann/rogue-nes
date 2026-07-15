; ============================================================
; Monster Data Tables
; 9 monster types: B E H S Z C T W G
; ============================================================
.segment "RODATA"

; Monster CHR tiles (which letter to display)
mon_chr_tile:
    .byte 'B', 'E', 'H', 'S', 'Z', 'C', 'T', 'W', 'G'

; Base HP (flat value, JRPG-style)
mon_base_hp:
    ;     B    E    H    S    Z    C    T    W    G
    .byte 3,   6,   8,   5,   14,  20,  28,  18,  40

; Attack power (flat value)
mon_atk:
    ;     B    E    H    S    Z    C    T    W    G
    .byte 2,   4,   4,   3,   5,   8,   11,  7,   14

; Defense (reduces player damage)
mon_def:
    ;     B    E    H    S    Z    C    T    W    G
    .byte 0,   1,   2,   0,   3,   4,   5,   3,   7

; Evasion (subtracted from hit chance; higher = harder to hit)
mon_evasion:
    ;     B    E    H    S    Z    C    T    W    G
    .byte 30,  5,   5,   20,  0,   10,  5,   20,  10

; XP reward
mon_xp:
    ;     B    E    H    S    Z    C    T    W    G
    .byte 1,   2,   3,   2,   6,   15,  50,  55,  100

; Base flags
mon_base_flags:
    .byte MFLAG_ERRATIC                     ; Bat: erratic, not aggressive
    .byte MFLAG_AGGRESSIVE                   ; Emu: mean
    .byte MFLAG_AGGRESSIVE                   ; Hobgoblin: mean
    .byte MFLAG_AGGRESSIVE                   ; Snake: mean
    .byte MFLAG_AGGRESSIVE                   ; Zombie: mean
    .byte MFLAG_AGGRESSIVE                   ; Centaur: mean
    .byte MFLAG_AGGRESSIVE                   ; Troll: mean
    .byte MFLAG_AGGRESSIVE                   ; Wraith: mean
    .byte MFLAG_AGGRESSIVE                   ; Griffin: mean

; Item CHR tiles for floor item rendering (indexed by item category)
item_chr_tile:
    .byte CHR_GOLD              ; ITEM_GOLD = 0
    .byte CHR_FOOD              ; ITEM_FOOD = 1
    .byte CHR_WEAPON            ; ITEM_WEAPON = 2
    .byte CHR_ARMOR             ; ITEM_ARMOR = 3
    .byte CHR_POTION            ; ITEM_POTION = 4
    .byte CHR_SCROLL            ; ITEM_SCROLL = 5
    .byte CHR_WAND              ; ITEM_WAND = 6
