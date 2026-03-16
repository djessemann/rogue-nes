; ============================================================
; HUD — Compact status bar on one row
; Str, Def, XP details shown on pause screen
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; hud_draw
; Draw the full HUD (called once on screen init).
; Row 0: HP:12/12 Lv:1 Fl:1 Gold:0
; Row 1: (empty)
; Layout: 0123456789012345678901234567890
;         HP: 12/ 12 Lv:1 Fl:1 Gold:  0
; ------------------------------------------------------------
.proc hud_draw
    ; "HP:" at pos 0
    lda #<str_hp
    sta ptr_lo
    lda #>str_hp
    sta ptr_hi
    lda #$00
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    jsr draw_text

    ; HP current (3 chars at pos 3)
    lda #$03
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda player_hp
    jsr draw_number_3d

    ; "/" at pos 6
    lda #$06
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda #'/'
    jsr vram_write_tile

    ; HP max at pos 7
    lda #$07
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda player_max_hp
    jsr draw_number

    ; "Lv:" at pos 11
    lda #<str_lv
    sta ptr_lo
    lda #>str_lv
    sta ptr_hi
    lda #$0B
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    jsr draw_text

    ; Level value at pos 14
    lda #$0E
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda player_level
    jsr draw_number

    ; "Fl:" at pos 17
    lda #<str_fl
    sta ptr_lo
    lda #>str_fl
    sta ptr_hi
    lda #$11
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    jsr draw_text

    ; Floor number at pos 20
    lda #$14
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda dungeon_level
    clc
    adc #$01
    jsr draw_number

    ; "Gold:" at pos 23
    lda #<str_gold
    sta ptr_lo
    lda #>str_gold
    sta ptr_hi
    lda #$17
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    jsr draw_text

    ; Gold value (3 chars at pos 28)
    lda #$1C
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda player_gold
    jsr draw_number_3d

    rts
.endproc

; ------------------------------------------------------------
; hud_update
; Update only changed HUD values (called after each turn).
; ------------------------------------------------------------
.proc hud_update
    ; HP current
    lda #$03
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda player_hp
    jsr draw_number_3d

    ; HP max
    lda #$07
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda player_max_hp
    jsr draw_number

    ; Level
    lda #$0E
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda player_level
    jsr draw_number

    ; Floor
    lda #$14
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda dungeon_level
    clc
    adc #$01
    jsr draw_number

    ; Gold
    lda #$1C
    sta temp_1
    lda #HUD_ROW_0
    sta temp_2
    lda player_gold
    jsr draw_number_3d

    rts
.endproc
