; ============================================================
; String Data — All game text
; ============================================================
.segment "RODATA"

str_title:
    .byte "ROGUE NES", $00

str_subtitle:
    .byte "A ROGUELIKE ADVENTURE", $00

str_press_start:
    .byte "PRESS START", $00

str_welcome:
    .byte "Welcome to the dungeon!", $00

str_descend:
    .byte "You descend deeper...", $00

str_you_died:
    .byte "YOU DIED", $00

str_you_win:
    .byte "YOU WIN!", $00

str_hp:
    .byte "HP:", $00

str_str:
    .byte "Str:", $00

str_fl:
    .byte "Fl:", $00

str_def:
    .byte "Def:", $00

str_exp:
    .byte "Exp:", $00

str_gold:
    .byte "Gold:", $00

str_lv:
    .byte "Lv:", $00

str_floor_reached:
    .byte "FLOOR REACHED:", $00

str_gold_label:
    .byte "GOLD COLLECTED:", $00

str_found_gold:
    .byte "You found gold!", $00

str_ate_food:
    .byte "You ate some food.", $00

str_level_up:
    .byte "Welcome to level up!", $00

str_hungry:
    .byte "You are getting hungry.", $00

str_weak:
    .byte "You feel weak!", $00

str_starving:
    .byte "You are starving!", $00

; --- Pause screen strings ---
str_pause:
    .byte "- PAUSED -", $00

str_pause_hp:
    .byte "Hit Points:", $00

str_pause_str:
    .byte "Strength:", $00

str_pause_def:
    .byte "Defense:", $00

str_pause_lvl:
    .byte "Level:", $00

str_pause_xp:
    .byte "Experience:", $00

str_pause_gold:
    .byte "Gold:", $00

str_pause_floor:
    .byte "Floor:", $00

str_pause_weapon:
    .byte "Weapon: +1 Mace", $00

str_pause_armor:
    .byte "Armor:  Ring Mail", $00

str_pause_resume:
    .byte "Press START to resume", $00

; --- Combat message fragments (classic Rogue style) ---
str_you_hit:
    .byte "You hit the ", $00

str_you_miss:
    .byte "You miss the ", $00

str_defeated:
    .byte "Defeated the ", $00

str_the:
    .byte "The ", $00

str_hits_you:
    .byte " hits you", $00

str_misses_you:
    .byte " misses you", $00

; --- Monster names (classic Rogue) ---
str_mon_bat:
    .byte "bat", $00
str_mon_emu:
    .byte "emu", $00
str_mon_hobgoblin:
    .byte "hobgoblin", $00
str_mon_snake:
    .byte "snake", $00
str_mon_zombie:
    .byte "zombie", $00

; Monster name pointer table (low/high bytes, indexed by mon_type)
mon_name_lo:
    .byte <str_mon_bat, <str_mon_emu, <str_mon_hobgoblin, <str_mon_snake, <str_mon_zombie
mon_name_hi:
    .byte >str_mon_bat, >str_mon_emu, >str_mon_hobgoblin, >str_mon_snake, >str_mon_zombie

; ============================================================
; Block-letter title font (Donkey Kong style)
;
; Instead of hand-drawing each letter from many bespoke tiles,
; the title is now "tiled" from a SINGLE existing in-game tile
; (the dungeon wall block, CHR_WALL) repeated on a grid — exactly
; how the Donkey Kong title screen builds its giant letters from
; one repeated block. draw_block_word reads these bitmaps and
; stamps the wall tile wherever a bit is set.
;
; Each glyph is 4 cells wide x 5 cells tall. Each row is stored
; as one byte; only the low 4 bits are used (bit3 = leftmost
; column ... bit0 = rightmost). A set bit = place the block tile.
; ============================================================
BLOCK_GLYPH_H = 5               ; rows per glyph

; Glyph indices (offsets into block_font, in units of glyphs)
GLYPH_R = 0
GLYPH_O = 1
GLYPH_G = 2
GLYPH_U = 3
GLYPH_E = 4
GLYPH_6 = 5
GLYPH_5 = 6
GLYPH_0 = 7
GLYPH_2 = 8

block_font:
    ; R
    .byte %1110, %1001, %1110, %1010, %1001
    ; O
    .byte %0110, %1001, %1001, %1001, %0110
    ; G
    .byte %0111, %1000, %1011, %1001, %0111
    ; U
    .byte %1001, %1001, %1001, %1001, %0110
    ; E
    .byte %1111, %1000, %1110, %1000, %1111
    ; 6
    .byte %0111, %1000, %1110, %1001, %0110
    ; 5
    .byte %1111, %1000, %1110, %0001, %1110
    ; 0
    .byte %0110, %1001, %1011, %1101, %0110
    ; 2
    .byte %1110, %0001, %0110, %1000, %1111

; Word = list of glyph indices, terminated by $FF
word_rogue:
    .byte GLYPH_R, GLYPH_O, GLYPH_G, GLYPH_U, GLYPH_E, $FF
word_6502:
    .byte GLYPH_6, GLYPH_5, GLYPH_0, GLYPH_2, $FF
