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

; --- Item pickup messages ---
str_picked_up:
    .byte "You picked up an item.", $00

str_pickup_weapon:
    .byte "You found a weapon!", $00

str_pickup_armor:
    .byte "You found some armor!", $00

str_pickup_potion:
    .byte "You found a potion!", $00

str_pickup_wand:
    .byte "You found a wand!", $00

str_inv_full:
    .byte "Inventory is full!", $00

; --- Inventory display strings ---
str_inv_header:
    .byte "-- Inventory --", $00

str_inv_empty:
    .byte "(empty)", $00

; --- Item use messages ---
str_equip_weapon:
    .byte "You wield the weapon.", $00

str_equip_armor:
    .byte "You put on the armor.", $00

str_pot_heal_msg:
    .byte "You feel better!", $00

str_pot_str_msg:
    .byte "You feel stronger!", $00

str_pot_poison_msg:
    .byte "You feel weaker!", $00

str_pot_strange:
    .byte "You feel strange.", $00

str_wand_zap:
    .byte "The wand crackles!", $00

str_wand_empty:
    .byte "The wand is empty.", $00

str_wand_teleport:
    .byte "It vanishes!", $00

str_wand_slow:
    .byte "It slows down!", $00

str_wand_fire:
    .byte "A fireball hits!", $00

str_wand_lightning:
    .byte "Lightning strikes!", $00

str_wand_no_target:
    .byte "Nothing to target.", $00

; --- Status effect messages ---
str_confused:
    .byte "You feel confused!", $00

str_unconfused:
    .byte "You feel less confused.", $00

str_blinded:
    .byte "You can't see!", $00

str_unblinded:
    .byte "You can see again!", $00

str_item_dropped:
    .byte "You drop the item.", $00

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
    .byte "Weapon:", $00

str_pause_armor:
    .byte "Armor:", $00

str_none:
    .byte "None", $00

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
; Title screen — "ROGUE" / "6502" as blocky square tiles
; Donkey-Kong style: every block is the single solid tile $80.
; 3x5 block font, 1 blank column between glyphs.
;   ROGUE : rows 6-10, start col 6  (19 tiles wide)
;   6502  : rows 12-16, start col 8 (15 tiles wide)
;
; title_block_meta: 3 bytes per row = PPU addr hi, addr lo, length.
; ============================================================
TITLE_BLOCK_ROWS = 10

title_block_meta:
    .byte $20,$C6,19   ; ROGUE row 0
    .byte $20,$E6,19   ; ROGUE row 1
    .byte $21,$06,19   ; ROGUE row 2
    .byte $21,$26,19   ; ROGUE row 3
    .byte $21,$46,19   ; ROGUE row 4
    .byte $21,$88,15   ; 6502 row 0
    .byte $21,$A8,15   ; 6502 row 1
    .byte $21,$C8,15   ; 6502 row 2
    .byte $21,$E8,15   ; 6502 row 3
    .byte $22,$08,15   ; 6502 row 4

title_block_data:
    ; --- ROGUE (5 rows x 19) ---
    .byte $80,$80,$80,$00,$80,$80,$80,$00,$80,$80,$80,$00,$80,$00,$80,$00,$80,$80,$80
    .byte $80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$00,$00,$80,$00,$80,$00,$80,$00,$00
    .byte $80,$80,$80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$80,$80,$80
    .byte $80,$80,$00,$00,$80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$00
    .byte $80,$00,$80,$00,$80,$80,$80,$00,$80,$80,$80,$00,$80,$80,$80,$00,$80,$80,$80
    ; --- 6502 (5 rows x 15) ---
    .byte $80,$80,$80,$00,$80,$80,$80,$00,$80,$80,$80,$00,$80,$80,$80
    .byte $80,$00,$00,$00,$80,$00,$00,$00,$80,$00,$80,$00,$00,$00,$80
    .byte $80,$80,$80,$00,$80,$80,$80,$00,$80,$00,$80,$00,$80,$80,$80
    .byte $80,$00,$80,$00,$00,$00,$80,$00,$80,$00,$80,$00,$80,$00,$00
    .byte $80,$80,$80,$00,$80,$80,$80,$00,$80,$80,$80,$00,$80,$80,$80

; ============================================================
; Title screen OAM data — "ROGUE" in large sprites
; 20 entries: Y-1, tile, attributes, X
; Centered: total width = 5*16 + 4*8 = 112, x_start = (256-112)/2 = 72
; Y position: y=80 (upper third)
; ============================================================
title_oam_data:
    ; R (x=72): tiles $01-$04
    .byte  79, $01, $00,  72    ; R top-left
    .byte  79, $02, $00,  80    ; R top-right
    .byte  87, $03, $00,  72    ; R bottom-left
    .byte  87, $04, $00,  80    ; R bottom-right
    ; O (x=96): tiles $05-$08
    .byte  79, $05, $00,  96    ; O top-left
    .byte  79, $06, $00, 104    ; O top-right
    .byte  87, $07, $00,  96    ; O bottom-left
    .byte  87, $08, $00, 104    ; O bottom-right
    ; G (x=120): tiles $09-$0C
    .byte  79, $09, $00, 120    ; G top-left
    .byte  79, $0A, $00, 128    ; G top-right
    .byte  87, $0B, $00, 120    ; G bottom-left
    .byte  87, $0C, $00, 128    ; G bottom-right
    ; U (x=144): tiles $0D-$10
    .byte  79, $0D, $00, 144    ; U top-left
    .byte  79, $0E, $00, 152    ; U top-right
    .byte  87, $0F, $00, 144    ; U bottom-left
    .byte  87, $10, $00, 152    ; U bottom-right
    ; E (x=168): tiles $11-$14
    .byte  79, $11, $00, 168    ; E top-left
    .byte  79, $12, $00, 176    ; E top-right
    .byte  87, $13, $00, 168    ; E bottom-left
    .byte  87, $14, $00, 176    ; E bottom-right
