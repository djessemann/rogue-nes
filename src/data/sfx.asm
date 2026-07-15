; ============================================================
; SFX Data — Sound effect byte streams
; Format: <count> <reg> <val> [...] <delay> ... $FF
; Register offsets are from $4000 (e.g. $08 = $4008 triangle)
; ============================================================
.segment "RODATA"

; --- Pointer tables ---
sfx_table_lo:
    .byte <sfx_data_footstep
    .byte <sfx_data_item_pickup
    .byte <sfx_data_player_hit
    .byte <sfx_data_monster_hit
    .byte <sfx_data_monster_dead
    .byte <sfx_data_stairs
    .byte <sfx_data_game_over

sfx_table_hi:
    .byte >sfx_data_footstep
    .byte >sfx_data_item_pickup
    .byte >sfx_data_player_hit
    .byte >sfx_data_monster_hit
    .byte >sfx_data_monster_dead
    .byte >sfx_data_stairs
    .byte >sfx_data_game_over

; ============================================================
; SFX 0: Footstep — Triangle channel quick blip
; Short tap at ~440Hz (A4), 3 frames on
; A4 period = $0FD
; ============================================================
sfx_data_footstep:
    ; Triangle on: linear counter = max, timer = A4
    .byte 3                     ; 3 register writes
    .byte $08, %11111111        ; $4008: linear counter max (triangle on)
    .byte $0A, $FD              ; $400A: timer low = $FD
    .byte $0B, $00              ; $400B: timer high = 0, reload length
    .byte 3                     ; Hold for 3 frames
    ; Triangle off
    .byte 1                     ; 1 register write
    .byte $08, %10000000        ; $4008: halt (triangle off)
    .byte 1                     ; 1 frame
    .byte $FF                   ; End

; ============================================================
; SFX 1: Item Pickup — Pulse 1 ascending arpeggio C5-E5-G5-C6
; 50% duty, volume 10, 3 frames per note
; C5=$0D5, E5=$0A9, G5=$08E, C6=$06A
; ============================================================
sfx_data_item_pickup:
    ; Note 1: C5
    .byte 3
    .byte $00, %10111010        ; $4000: duty 10, halt, const vol, vol=10
    .byte $02, $D5              ; $4002: timer low C5
    .byte $03, $00              ; $4003: timer high + length reload
    .byte 3                     ; 3 frames
    ; Note 2: E5
    .byte 2
    .byte $02, $A9              ; $4002: timer low E5
    .byte $03, $00              ; $4003: reload
    .byte 3
    ; Note 3: G5
    .byte 2
    .byte $02, $8E              ; $4002: timer low G5
    .byte $03, $00
    .byte 3
    ; Note 4: C6
    .byte 2
    .byte $02, $6A              ; $4002: timer low C6
    .byte $03, $00
    .byte 4
    ; Fade out
    .byte 1
    .byte $00, %10110100        ; vol=4
    .byte 3
    .byte $FF                   ; End

; ============================================================
; SFX 2: Player Hits Enemy — Noise crack + pulse accent
; Noise period 2 (bright), pulse at E5 then drop to C5
; ============================================================
sfx_data_player_hit:
    ; Noise burst + pulse accent
    .byte 5
    .byte $0C, %00111100        ; $400C: noise vol=12
    .byte $0E, %00000010        ; $400E: noise period 2 (bright)
    .byte $0F, %00001000        ; $400F: noise length reload
    .byte $00, %00111000        ; $4000: pulse duty 00, vol=8
    .byte $02, $A9              ; $4002: pulse E5
    .byte 2                     ; 2 frames
    ; Drop pitch, fade noise
    .byte 3
    .byte $0C, %00110100        ; noise vol=4
    .byte $02, $D5              ; pulse drop to C5
    .byte $00, %00110100        ; pulse vol=4
    .byte 3                     ; 3 frames
    ; Silence
    .byte 2
    .byte $0C, %00110000        ; noise vol=0
    .byte $00, %00110000        ; pulse vol=0
    .byte 1
    .byte $FF                   ; End

; ============================================================
; SFX 3: Monster Hits Player — Low noise thud, volume decay
; Noise period 6 (low rumble)
; ============================================================
sfx_data_monster_hit:
    ; Thud start
    .byte 3
    .byte $0C, %00111111        ; $400C: noise vol=15
    .byte $0E, %00000110        ; $400E: noise period 6 (low)
    .byte $0F, %00001000        ; $400F: length reload
    .byte 3                     ; 3 frames
    ; Decay
    .byte 1
    .byte $0C, %00111000        ; vol=8
    .byte 3
    ; Fade
    .byte 1
    .byte $0C, %00110011        ; vol=3
    .byte 3
    ; Silence
    .byte 1
    .byte $0C, %00110000        ; vol=0
    .byte 1
    .byte $FF                   ; End

; ============================================================
; SFX 4: Monster Defeated — Pulse 1 descending sweep
; G5 → E5 → C5 → G4 → E4, fading volume
; G5=$08E, E5=$0A9, C5=$0D5, G4=$11C, E4=$152
; ============================================================
sfx_data_monster_dead:
    ; G5
    .byte 3
    .byte $00, %00111100        ; duty 00, vol=12
    .byte $02, $8E              ; G5
    .byte $03, $00
    .byte 3
    ; E5
    .byte 2
    .byte $02, $A9              ; E5
    .byte $03, $00
    .byte 3
    ; C5
    .byte 2
    .byte $02, $D5              ; C5
    .byte $03, $00
    .byte 3
    ; G4, vol=8
    .byte 3
    .byte $00, %00111000        ; vol=8
    .byte $02, $1C              ; G4 low byte
    .byte $03, $01              ; G4 high byte = 1
    .byte 3
    ; E4, vol=4
    .byte 3
    .byte $00, %00110100        ; vol=4
    .byte $02, $52              ; E4 low byte
    .byte $03, $01              ; E4 high byte = 1
    .byte 4
    .byte $FF                   ; End

; ============================================================
; SFX 5: Descend Stairs — 4 triangle taps descending
; A4=$0FD, G4=$11C, F4=$13F, E4=$152
; 3 frames on, 4 frames gap between taps
; ============================================================
sfx_data_stairs:
    ; Tap 1: A4
    .byte 3
    .byte $08, %11111111        ; triangle on
    .byte $0A, $FD              ; A4 low
    .byte $0B, $00              ; A4 high
    .byte 3
    .byte 1
    .byte $08, %10000000        ; triangle off
    .byte 4                     ; gap
    ; Tap 2: G4
    .byte 3
    .byte $08, %11111111
    .byte $0A, $1C              ; G4 low
    .byte $0B, $01              ; G4 high
    .byte 3
    .byte 1
    .byte $08, %10000000
    .byte 4
    ; Tap 3: F4
    .byte 3
    .byte $08, %11111111
    .byte $0A, $3F              ; F4 low
    .byte $0B, $01
    .byte 3
    .byte 1
    .byte $08, %10000000
    .byte 4
    ; Tap 4: E4
    .byte 3
    .byte $08, %11111111
    .byte $0A, $52              ; E4 low
    .byte $0B, $01
    .byte 3
    .byte 1
    .byte $08, %10000000
    .byte 1
    .byte $FF                   ; End

; ============================================================
; SFX 6: Game Over — Pulse 1 slow descending 4 notes
; E5=$0A9, C5=$0D5, A4=$0FD (as pulse ~$17E), E4=$152 (as pulse ~$2A4)
; 50% duty (mellow), 8 frames per note, fading
; Using pulse-friendly periods: E5=$0A9, C5=$0D5, A4=$17E, E4=$2A2
; ============================================================
sfx_data_game_over:
    ; E5
    .byte 3
    .byte $00, %10111100        ; duty 10 (50%), vol=12
    .byte $02, $A9              ; E5
    .byte $03, $00
    .byte 8
    ; C5
    .byte 2
    .byte $02, $D5              ; C5
    .byte $03, $00
    .byte 8
    ; A4, vol=8
    .byte 3
    .byte $00, %10111000        ; vol=8
    .byte $02, $7E              ; A4 low
    .byte $03, $01              ; A4 high
    .byte 10
    ; E4, vol=4
    .byte 3
    .byte $00, %10110100        ; vol=4
    .byte $02, $A2              ; E4 low (half freq of E5)
    .byte $03, $02              ; E4 high
    .byte 12
    ; Fade out
    .byte 1
    .byte $00, %10110000        ; vol=0
    .byte 1
    .byte $FF                   ; End
