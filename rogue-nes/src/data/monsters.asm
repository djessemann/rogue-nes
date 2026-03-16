; ============================================================
; Monster Data Tables
; Phase 1: 5 monster types
; ============================================================
.segment "RODATA"

; Monster CHR tiles (which letter to display)
; B=Bat, E=Emu, H=Hobgoblin, S=Snake, Z=Zombie
mon_chr_tile:
    .byte 'B', 'E', 'H', 'S', 'Z'

; Base HP (max of 1d<value>) — classic Rogue: Nd8 per skill level
mon_base_hp:
    .byte 8, 8, 8, 8, 16       ; B:1d8, E:1d8, H:1d8, S:1d8, Z:2d8

; Armor class (ascending: roll must meet/exceed to hit)
; Converted from classic Rogue descending AC: ascending = 20 - classic
mon_armor:
    .byte 17, 13, 15, 15, 12   ; B:AC3→17, E:AC7→13, H:AC5→15, S:AC5→15, Z:AC8→12

; XP reward (matches classic Rogue)
mon_xp:
    .byte 1, 2, 3, 2, 6

; Monster level (added to attack rolls) — matches classic skill level
mon_level:
    .byte 1, 1, 1, 1, 2

; Max damage per hit (matches classic Rogue damage dice)
mon_damage:
    .byte 2, 2, 8, 3, 8        ; B:1d2, E:1d2, H:1d8, S:1d3, Z:1d8

; Base flags (aggressive, erratic, etc.)
; Classic Rogue: Bat=flying(not mean), Emu=MEAN, H/S/Z=mean
mon_base_flags:
    .byte MFLAG_ERRATIC                     ; Bat: erratic/flying, not aggressive
    .byte MFLAG_AGGRESSIVE                   ; Emu: mean in classic Rogue
    .byte MFLAG_AGGRESSIVE                   ; Hobgoblin: mean
    .byte MFLAG_AGGRESSIVE                   ; Snake: mean
    .byte MFLAG_AGGRESSIVE                   ; Zombie: mean

; Item CHR tiles for floor item rendering
item_chr_tile:
    .byte CHR_GOLD              ; ITEM_GOLD = 0
    .byte CHR_FOOD              ; ITEM_FOOD = 1
