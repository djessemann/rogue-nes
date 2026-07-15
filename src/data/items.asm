; ============================================================
; Item Data Tables — Weapons, Armor, Potions, Scrolls, Wands
; ============================================================
.segment "RODATA"

; --- Weapon Stats (indexed by weapon subtype) ---
; Attack power (flat value, JRPG-style)
weapon_power:
    .byte 6, 7, 10, 15, 12     ; Mace:6, ShortSwd:7, LongSwd:10, 2HSwd:15, WarHammer:12

; --- Armor Stats (indexed by armor subtype) ---
; Defense value (flat, JRPG-style)
armor_defense:
    .byte 4, 6, 8, 10, 12      ; Leather:4, RingMail:6, ScaleMail:8, ChainMail:10, PlateMail:12

; --- Weapon name pointers ---
weapon_name_lo:
    .byte <str_wpn_mace, <str_wpn_short_sword, <str_wpn_long_sword
    .byte <str_wpn_two_hand_sword, <str_wpn_war_hammer
weapon_name_hi:
    .byte >str_wpn_mace, >str_wpn_short_sword, >str_wpn_long_sword
    .byte >str_wpn_two_hand_sword, >str_wpn_war_hammer

; --- Armor name pointers ---
armor_name_lo:
    .byte <str_arm_leather, <str_arm_ring_mail, <str_arm_scale_mail
    .byte <str_arm_chain_mail, <str_arm_plate_mail
armor_name_hi:
    .byte >str_arm_leather, >str_arm_ring_mail, >str_arm_scale_mail
    .byte >str_arm_chain_mail, >str_arm_plate_mail

; --- Potion name pointers ---
potion_name_lo:
    .byte <str_pot_healing, <str_pot_extra_healing, <str_pot_strength
    .byte <str_pot_poison, <str_pot_confusion, <str_pot_blindness
potion_name_hi:
    .byte >str_pot_healing, >str_pot_extra_healing, >str_pot_strength
    .byte >str_pot_poison, >str_pot_confusion, >str_pot_blindness

; --- Wand name pointers ---
wand_name_lo:
    .byte <str_wnd_teleport, <str_wnd_slow, <str_wnd_fire, <str_wnd_lightning
wand_name_hi:
    .byte >str_wnd_teleport, >str_wnd_slow, >str_wnd_fire, >str_wnd_lightning

; --- Item name strings ---
str_wpn_mace:           .byte "Mace", $00
str_wpn_short_sword:    .byte "Short Sword", $00
str_wpn_long_sword:     .byte "Long Sword", $00
str_wpn_two_hand_sword: .byte "Two-Hand Sword", $00
str_wpn_war_hammer:     .byte "War Hammer", $00

str_arm_leather:        .byte "Leather Armor", $00
str_arm_ring_mail:      .byte "Ring Mail", $00
str_arm_scale_mail:     .byte "Scale Mail", $00
str_arm_chain_mail:     .byte "Chain Mail", $00
str_arm_plate_mail:     .byte "Plate Mail", $00

str_pot_healing:        .byte "Healing", $00
str_pot_extra_healing:  .byte "Extra Healing", $00
str_pot_strength:       .byte "Strength", $00
str_pot_poison:         .byte "Poison", $00
str_pot_confusion:      .byte "Confusion", $00
str_pot_blindness:      .byte "Blindness", $00

str_wnd_teleport:       .byte "Teleport Away", $00
str_wnd_slow:           .byte "Slow Monster", $00
str_wnd_fire:           .byte "Fire", $00
str_wnd_lightning:      .byte "Lightning", $00
