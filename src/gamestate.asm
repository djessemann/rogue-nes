; ============================================================
; Game State Machine
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; state_dispatch
; Route to current state's handler.
; Each state checks state_initialized:
;   0 = run init, set to 1
;   1 = run update
; ------------------------------------------------------------
.proc state_dispatch
    lda game_state

    cmp #STATE_TITLE
    beq @title
    cmp #STATE_GAMEPLAY
    beq @gameplay
    cmp #STATE_INVENTORY
    beq @inventory
    cmp #STATE_DEATH
    beq @death
    cmp #STATE_STAIRS
    beq @stairs
    cmp #STATE_WIN
    beq @win
    cmp #STATE_PAUSE
    beq @pause
    rts

@title:
    jmp state_title
@gameplay:
    jmp state_gameplay
@inventory:
    jmp state_inventory
@death:
    jmp state_death
@stairs:
    jmp state_stairs
@win:
    jmp state_win
@pause:
    jmp state_pause
.endproc

; ============================================================
; TITLE STATE
; ============================================================
.proc state_title
    lda state_initialized
    beq @do_init
    jmp @update
@do_init:

    ; --- Init ---
    ; Disable NMI and rendering for safe PPU access
    lda #$00
    sta $2000                   ; Disable NMI first
    sta $2001                   ; Disable rendering
    sta ppu_ctrl                ; Update shadow
    sta ppu_mask                ; Update shadow
    sta vram_buf_len            ; Clear VRAM buffer

    jsr clear_nametable
    jsr clear_oam_sprites       ; Clear all sprites offscreen

    ; Load palette
    lda #<palette_title
    sta ptr_lo
    lda #>palette_title
    sta ptr_hi
    jsr load_palettes

    ; --- Draw "ROGUE" / "6502" as blocky square tiles ($80) ---
    ; Donkey-Kong style: each row is stamped from title_block_meta
    ; (PPU addr hi, addr lo, length) + title_block_data (see strings.asm).
    ldx #0                      ; meta index (3 bytes per row)
    ldy #0                      ; running index into title_block_data
@block_row:
    lda $2002                   ; Reset PPU latch
    lda title_block_meta, x     ; PPU address high
    sta $2006
    inx
    lda title_block_meta, x     ; PPU address low
    sta $2006
    inx
    lda title_block_meta, x     ; Row length
    sta temp_1
    inx
@block_col:
    lda title_block_data, y
    sta $2007
    iny
    dec temp_1
    bne @block_col
    cpx #(TITLE_BLOCK_ROWS * 3)
    bne @block_row

    ; --- Draw "PRESS START" as background text ---
    lda #<str_press_start
    sta ptr_lo
    lda #>str_press_start
    sta ptr_hi
    lda #10                     ; X position (centered)
    sta temp_1
    lda #20                     ; Y position (below the title)
    sta temp_2
    jsr ppu_draw_text

    ; Enable rendering (BG only, no sprites needed)
    lda #%10000000              ; NMI on, BG pat 0
    sta ppu_ctrl
    lda #%00001110              ; Show BG, no clipping
    sta ppu_mask
    lda #$00
    sta ppu_scroll_x
    sta ppu_scroll_y
    lda ppu_ctrl
    sta $2000                   ; Re-enable NMI last

    lda #$01
    sta state_initialized
    rts

@update:
    ; Blink "PRESS START" every 32 frames
    lda frame_counter
    and #$20                    ; Toggle every 32 frames
    beq @press_visible
    ; Hide: clear row 20 via VRAM buffer
    lda #$00
    sta temp_1
    lda #20
    sta temp_2
    jsr clear_msg_row
    jmp @check_start
@press_visible:
    ; Show "PRESS START"
    lda #<str_press_start
    sta ptr_lo
    lda #>str_press_start
    sta ptr_hi
    lda #10
    sta temp_1
    lda #20
    sta temp_2
    jsr draw_text

@check_start:
    ; Wait for Start button
    lda buttons_new
    and #BUTTON_START
    beq @done

    ; Seed RNG from frame counter
    lda frame_counter
    sta rng_seed_lo
    eor #$A5
    sta rng_seed_hi

    ; Clear sprites before entering gameplay
    jsr clear_oam_sprites

    ; Start new game
    jsr game_init
    lda #STATE_GAMEPLAY
    sta game_state
    lda #$00
    sta state_initialized
@done:
    rts
.endproc

; ============================================================
; GAMEPLAY STATE
; ============================================================
.proc state_gameplay
    lda state_initialized
    beq @init
    jmp @update
@init:

    ; --- Init ---
    ; Disable NMI and rendering for safe PPU access
    lda #$00
    sta $2000                   ; Disable NMI first
    sta $2001                   ; Disable rendering
    sta ppu_ctrl                ; Update shadow
    sta ppu_mask                ; Update shadow
    sta vram_buf_len            ; Clear VRAM buffer

    jsr clear_nametable

    ; Load dungeon palette
    lda #<palette_dungeon
    sta ptr_lo
    lda #>palette_dungeon
    sta ptr_hi
    jsr load_palettes
    jsr set_level_bg_color

    ; Generate dungeon
    jsr dungeon_generate

    ; Set camera to player's starting viewport
    lda player_x
    cmp #VIEW_W
    bcc @cam_x_zero
    lda #VIEW_W
    sta camera_x
    jmp @cam_x_set
@cam_x_zero:
    lda #$00
    sta camera_x
@cam_x_set:

    lda player_y
    cmp #VIEW_H
    bcc @cam_y_zero
    lda #VIEW_H
    sta camera_y
    jmp @cam_y_set
@cam_y_zero:
    lda #$00
    sta camera_y
@cam_y_set:

    ; Initialize fog — reveal starting room
    lda #$FF
    sta player_prev_room
    sta player_current_room
    jsr find_player_room
    bcc @no_start_room
    ldx player_current_room
    jsr fog_reveal_room
    lda player_current_room
    sta player_prev_room
@no_start_room:

    ; Draw viewport (direct PPU writes, rendering is off)
    jsr map_draw_viewport

    ; Draw HUD
    jsr hud_draw

    ; Show welcome or descent message
    lda dungeon_level
    beq @welcome_msg
    ; Descending to deeper level
    lda #<str_descend
    sta ptr_lo
    lda #>str_descend
    sta ptr_hi
    jmp @show_msg
@welcome_msg:
    lda #<str_welcome
    sta ptr_lo
    lda #>str_welcome
    sta ptr_hi
@show_msg:
    jsr msg_show

    ; Enable rendering (NMI will flush VRAM buffer)
    lda #%10000000
    sta ppu_ctrl
    lda #%00001110
    sta ppu_mask
    lda #$00
    sta ppu_scroll_x
    sta ppu_scroll_y
    lda ppu_ctrl
    sta $2000                   ; Re-enable NMI last

    lda #$01
    sta state_initialized
    rts

@update:
    ; Flush deferred HUD update from previous frame
    lda hud_dirty
    beq @no_hud_refresh
    lda #$00
    sta hud_dirty
    jsr hud_update
@no_hud_refresh:

    ; Check for pause
    lda buttons_new
    and #BUTTON_START
    beq @no_pause
    lda #STATE_PAUSE
    sta game_state
    lda #$00
    sta state_initialized
    rts
@no_pause:

    ; Process player input (turn-based: only act on new presses)
    jsr player_input

    ; Handle screen flip if player moved to a new viewport
    lda screen_flip
    beq @no_flip
    jsr do_screen_flip
    lda #$00
    sta screen_flip
@no_flip:

    ; If player acted (turn_taken != 0), run monster turns
    lda turn_taken
    beq @no_turn
    inc turn_counter
    lda #$00
    sta msg_turn_priority       ; Reset message priority for new turn
    jsr monsters_update
    jsr hunger_update
    jsr status_update

    ; Check for player death
    lda player_hp
    beq @player_died

    ; Defer HUD update to next frame (avoids VRAM buffer overflow)
    lda #$01
    sta hud_dirty
@no_turn:

    ; Flush deferred message to VRAM (single write per frame)
    jsr msg_flush

    ; Process per-tile flash effect (runs every frame, not just on turns)
    jsr flash_update

    rts

@player_died:
    lda #SFX_GAME_OVER
    jsr sfx_play
    lda #STATE_DEATH
    sta game_state
    lda #$00
    sta state_initialized
    rts
.endproc

; ============================================================
; INVENTORY STATE (placeholder for Phase 2)
; ============================================================
.proc state_inventory
    lda state_initialized
    bne @update

    ; --- Init (simple placeholder) ---
    lda #$01
    sta state_initialized
    rts

@update:
    ; B or Start to close
    lda buttons_new
    and #BUTTON_B
    bne @close
    lda buttons_new
    and #BUTTON_START
    bne @close
    rts

@close:
    lda #STATE_GAMEPLAY
    sta game_state
    lda #$01                    ; Don't re-init gameplay (already drawn)
    sta state_initialized
    rts
.endproc

; ============================================================
; PAUSE STATE — Black screen with detailed stats
; ============================================================
.proc state_pause
    lda state_initialized
    beq @init
    jmp @update

@init:
    ; --- Init ---
    ; Disable NMI and rendering for safe PPU access
    lda #$00
    sta $2000
    sta $2001
    sta ppu_ctrl
    sta ppu_mask
    sta vram_buf_len

    jsr clear_nametable

    ; Load palette (dark theme)
    lda #<palette_title
    sta ptr_lo
    lda #>palette_title
    sta ptr_hi
    jsr load_palettes

    ; --- Draw pause screen using direct PPU writes ---

    ; "- PAUSED -" centered on row 2
    lda #<str_pause
    sta ptr_lo
    lda #>str_pause
    sta ptr_hi
    lda #11
    sta temp_1
    lda #2
    sta temp_2
    jsr ppu_draw_text

    ; --- Compact stats: rows 4-6 ---

    ; Row 4: "HP: 12/12   Str: 16"
    lda #<str_hp
    sta ptr_lo
    lda #>str_hp
    sta ptr_hi
    lda #2
    sta temp_1
    lda #4
    sta temp_2
    jsr ppu_draw_text
    lda #5
    sta temp_1
    lda #4
    sta temp_2
    lda player_hp
    jsr ppu_draw_number
    lda #'/'
    sta $2007
    lda player_max_hp
    jsr ppu_draw_number_continue

    lda #<str_str
    sta ptr_lo
    lda #>str_str
    sta ptr_hi
    lda #16
    sta temp_1
    lda #4
    sta temp_2
    jsr ppu_draw_text
    ; Compute effective Atk: weapon_power + enchant + str bonus
    lda player_str
    sta temp_4                  ; Accumulator for effective atk
    ldx equipped_weapon
    cpx #$FF
    beq @no_wpn_str
    ldy inv_sub, x
    lda weapon_power, y
    clc
    adc inv_mod, x              ; + enchantment
    clc
    adc temp_4
    sta temp_4
    jmp @wpn_str_done
@no_wpn_str:
    lda #DEFAULT_WEAPON_POWER
    clc
    adc temp_4
    sta temp_4
@wpn_str_done:
    lda #20
    sta temp_1
    lda #4
    sta temp_2
    lda temp_4
    jsr ppu_draw_number

    ; Row 5: "Def: ##     Lv: #"
    lda #<str_def
    sta ptr_lo
    lda #>str_def
    sta ptr_hi
    lda #2
    sta temp_1
    lda #5
    sta temp_2
    jsr ppu_draw_text
    ; Compute effective Def: armor_defense + enchant + def bonus
    lda player_def
    sta temp_4                  ; Base: def bonus from levels
    ldx equipped_armor
    cpx #$FF
    beq @no_arm_def
    ldy inv_sub, x
    lda armor_defense, y
    clc
    adc inv_mod, x              ; + enchantment
    clc
    adc temp_4                  ; + def bonus
    sta temp_4
@no_arm_def:
    lda #6
    sta temp_1
    lda #5
    sta temp_2
    lda temp_4
    jsr ppu_draw_number

    lda #<str_lv
    sta ptr_lo
    lda #>str_lv
    sta ptr_hi
    lda #16
    sta temp_1
    lda #5
    sta temp_2
    jsr ppu_draw_text
    lda #19
    sta temp_1
    lda #5
    sta temp_2
    lda player_level
    jsr ppu_draw_number

    ; Row 6: "Gold: 0     Floor: 1"
    lda #<str_gold
    sta ptr_lo
    lda #>str_gold
    sta ptr_hi
    lda #2
    sta temp_1
    lda #6
    sta temp_2
    jsr ppu_draw_text
    lda #7
    sta temp_1
    lda #6
    sta temp_2
    lda player_gold
    jsr ppu_draw_number

    lda #<str_fl
    sta ptr_lo
    lda #>str_fl
    sta ptr_hi
    lda #16
    sta temp_1
    lda #6
    sta temp_2
    jsr ppu_draw_text
    lda #19
    sta temp_1
    lda #6
    sta temp_2
    lda dungeon_level
    clc
    adc #$01
    jsr ppu_draw_number

    ; --- Equipment: rows 8-9 ---
    ; Weapon label
    lda #<str_pause_weapon
    sta ptr_lo
    lda #>str_pause_weapon
    sta ptr_hi
    lda #2
    sta temp_1
    lda #8
    sta temp_2
    jsr ppu_draw_text

    ; Equipped weapon name
    lda equipped_weapon
    cmp #$FF
    beq @no_weapon_equipped
    tax
    ldy inv_sub, x
    lda weapon_name_lo, y
    sta ptr_lo
    lda weapon_name_hi, y
    sta ptr_hi
    jmp @draw_weapon_name
@no_weapon_equipped:
    lda #<str_none
    sta ptr_lo
    lda #>str_none
    sta ptr_hi
@draw_weapon_name:
    lda #10
    sta temp_1
    lda #8
    sta temp_2
    jsr ppu_draw_text

    ; Armor label
    lda #<str_pause_armor
    sta ptr_lo
    lda #>str_pause_armor
    sta ptr_hi
    lda #2
    sta temp_1
    lda #9
    sta temp_2
    jsr ppu_draw_text

    ; Equipped armor name
    lda equipped_armor
    cmp #$FF
    beq @no_armor_equipped
    tax
    ldy inv_sub, x
    lda armor_name_lo, y
    sta ptr_lo
    lda armor_name_hi, y
    sta ptr_hi
    jmp @draw_armor_name
@no_armor_equipped:
    lda #<str_none
    sta ptr_lo
    lda #>str_none
    sta ptr_hi
@draw_armor_name:
    lda #10
    sta temp_1
    lda #9
    sta temp_2
    jsr ppu_draw_text

    ; --- Inventory header: row 11 ---
    lda #<str_inv_header
    sta ptr_lo
    lda #>str_inv_header
    sta ptr_hi
    lda #2
    sta temp_1
    lda #11
    sta temp_2
    jsr ppu_draw_text

    ; --- Inventory list: rows 12-21 (up to 10 items) ---
    jsr pause_draw_inventory

    ; "Press START to resume" at row 27
    lda #<str_pause_resume
    sta ptr_lo
    lda #>str_pause_resume
    sta ptr_hi
    lda #5
    sta temp_1
    lda #27
    sta temp_2
    jsr ppu_draw_text

    ; Initialize inventory cursor
    lda #$00
    sta inv_cursor
    sta inv_scroll

    ; Draw cursor indicator if inventory not empty
    lda inventory_count
    beq @no_cursor
    ; Draw ">" at row 12 (first inventory row), col 1
    lda $2002
    lda #$21                    ; Row 12 = $2000 + 12*32 = $2180
    sta $2006
    lda #$81                    ; col 1 = $81
    sta $2006
    lda #'>'
    sta $2007
@no_cursor:

    ; Set attribute bytes so column 2-3 area uses palette 1 (dark gray)
    ; for the equipped "E" indicator on inventory rows 12-21
    lda $2002                   ; Reset PPU latch
    ; Attribute row 3 (tile rows 12-15): $23D8
    lda #$23
    sta $2006
    lda #$D8
    sta $2006
    lda #$44                    ; Top-right + bottom-right = palette 1
    sta $2007
    ; Attribute row 4 (tile rows 16-19): $23E0
    lda $2002
    lda #$23
    sta $2006
    lda #$E0
    sta $2006
    lda #$44
    sta $2007
    ; Attribute row 5 (tile rows 20-23): $23E8
    lda $2002
    lda #$23
    sta $2006
    lda #$E8
    sta $2006
    lda #$04                    ; Top-right only = palette 1
    sta $2007

    ; Enable rendering
    lda #%10000000
    sta ppu_ctrl
    lda #%00001110
    sta ppu_mask
    lda #$00
    sta ppu_scroll_x
    sta ppu_scroll_y
    lda ppu_ctrl
    sta $2000

    lda #$01
    sta state_initialized
    rts

@update:
    ; Check START to resume
    lda buttons_new
    and #BUTTON_START
    beq @no_start
    jmp @resume
@no_start:

    ; Check inventory navigation (only if inventory not empty)
    lda inventory_count
    bne @has_inv
    jmp @done
@has_inv:

    ; UP: move cursor up
    lda buttons_new
    and #BUTTON_UP
    beq @check_down
    lda inv_cursor
    bne @can_go_up
    jmp @done                   ; Already at top
@can_go_up:
    ; Erase old cursor
    lda inv_cursor
    clc
    adc #12                     ; Row = cursor + 12
    sta temp_2
    lda #1
    sta temp_1
    lda #$20                    ; Space (erase)
    jsr pause_write_char
    dec inv_cursor
    ; Draw new cursor
    lda inv_cursor
    clc
    adc #12
    sta temp_2
    lda #1
    sta temp_1
    lda #'>'
    jsr pause_write_char
    jmp @done

@check_down:
    lda buttons_new
    and #BUTTON_DOWN
    beq @check_a
    lda inv_cursor
    clc
    adc #$01
    cmp inventory_count
    bcc @not_bottom
    jmp @done                   ; At bottom
@not_bottom:
    cmp #10
    bcc @not_max
    jmp @done                   ; Max visible
@not_max:
    ; Erase old cursor
    lda inv_cursor
    clc
    adc #12
    sta temp_2
    lda #1
    sta temp_1
    lda #$20
    jsr pause_write_char
    inc inv_cursor
    ; Draw new cursor
    lda inv_cursor
    clc
    adc #12
    sta temp_2
    lda #1
    sta temp_1
    lda #'>'
    jsr pause_write_char
    jmp @done

@check_a:
    ; A: use/equip selected item
    lda buttons_new
    and #BUTTON_A
    beq @check_b
    ldx inv_cursor
    jsr item_use
    bcc @equipped               ; Not consumed (equipped) — redraw
    ; Item consumed — remove from inventory
    ldx inv_cursor
    jsr item_remove
    ; Adjust cursor if needed
    lda inv_cursor
    cmp inventory_count
    bcc @cursor_ok
    lda inventory_count
    beq @cursor_zero
    sec
    sbc #$01
@cursor_zero:
    sta inv_cursor
@cursor_ok:
@equipped:
    ; Redraw pause screen (after equip, consume, or drop)
    lda #$00
    sta state_initialized
    jmp @done

@check_b:
    ; B: drop selected item
    lda buttons_new
    and #BUTTON_B
    bne @do_drop
    jmp @done
@do_drop:
    ldx inv_cursor
    jsr item_remove
    ; Show drop message
    lda #<str_item_dropped
    sta ptr_lo
    lda #>str_item_dropped
    sta ptr_hi
    jsr msg_show
    ; Adjust cursor
    lda inv_cursor
    cmp inventory_count
    bcc @drop_ok
    lda inventory_count
    beq @drop_zero
    sec
    sbc #$01
@drop_zero:
    sta inv_cursor
@drop_ok:
    ; Redraw pause screen
    lda #$00
    sta state_initialized
    jmp @done

@resume:
    ; Return to gameplay — redraw existing dungeon (don't regenerate)
    lda #STATE_GAMEPLAY
    sta game_state
    lda #$01
    sta state_initialized       ; Already initialized, skip to @update
    ; Disable rendering so we can reload palette safely
    lda #$00
    sta $2000
    sta $2001
    sta ppu_ctrl
    sta ppu_mask
    ; Clear attribute table bytes set by pause screen inventory
    lda $2002
    lda #$23
    sta $2006
    lda #$D8
    sta $2006
    lda #$00
    sta $2007
    lda $2002
    lda #$23
    sta $2006
    lda #$E0
    sta $2006
    lda #$00
    sta $2007
    lda $2002
    lda #$23
    sta $2006
    lda #$E8
    sta $2006
    lda #$00
    sta $2007

    ; Reload dungeon palette (pause screen used title palette)
    lda #<palette_dungeon
    sta ptr_lo
    lda #>palette_dungeon
    sta ptr_hi
    jsr load_palettes
    jsr set_level_bg_color
    jsr do_screen_flip          ; Redraw viewport, HUD, re-enable rendering
@done:
    rts
.endproc

; ------------------------------------------------------------
; pause_write_char
; Queue a single character write to VRAM buffer on pause screen.
; Input: A = character, temp_1 = col, temp_2 = row
; Clobbers: X
; ------------------------------------------------------------
.proc pause_write_char
    jsr vram_write_tile
    rts
.endproc

; ------------------------------------------------------------
; pause_draw_inventory
; Draw inventory items on the pause screen (rows 12-21).
; Uses direct PPU writes (rendering must be off).
; ------------------------------------------------------------
.proc pause_draw_inventory
    lda inventory_count
    bne @has_items

    ; Empty inventory
    lda #<str_inv_empty
    sta ptr_lo
    lda #>str_inv_empty
    sta ptr_hi
    lda #5
    sta temp_1
    lda #12
    sta temp_2
    jsr ppu_draw_text
    rts

@has_items:
    ; Draw up to 10 items starting from row 12
    ldx #$00                    ; Inventory index
    lda #12
    sta temp_3                  ; Current row

@item_loop:
    cpx inventory_count
    bne @not_end
    jmp @inv_done
@not_end:
    lda temp_3
    cmp #22                     ; Max row 21 (10 items)
    bne @not_full_screen
    jmp @inv_done
@not_full_screen:

    stx temp_mon_idx            ; Save inventory index

    ; Get item name pointer based on category + subtype
    lda inv_cat, x
    cmp #ITEM_WEAPON
    beq @draw_weapon
    cmp #ITEM_ARMOR
    beq @draw_armor
    cmp #ITEM_POTION
    beq @draw_potion
    cmp #ITEM_WAND
    beq @draw_wand
    jmp @next_item              ; Gold/food shouldn't be in inventory

@draw_weapon:
    ldy inv_sub, x
    lda weapon_name_lo, y
    sta ptr_lo
    lda weapon_name_hi, y
    sta ptr_hi
    jmp @do_draw

@draw_armor:
    ldy inv_sub, x
    lda armor_name_lo, y
    sta ptr_lo
    lda armor_name_hi, y
    sta ptr_hi
    jmp @do_draw

@draw_potion:
    ldy inv_sub, x
    lda potion_name_lo, y
    sta ptr_lo
    lda potion_name_hi, y
    sta ptr_hi
    jmp @do_draw

@draw_wand:
    ldy inv_sub, x
    lda wand_name_lo, y
    sta ptr_lo
    lda wand_name_hi, y
    sta ptr_hi

@do_draw:
    lda #5
    sta temp_1
    lda temp_3
    sta temp_2
    jsr ppu_draw_text

    ; Draw equipped indicator "E" at column 3 if this item is equipped
    ldx temp_mon_idx
    cpx equipped_weapon
    beq @draw_equip
    cpx equipped_armor
    beq @draw_equip
    jmp @next_item
@draw_equip:
    lda $2002                   ; Reset PPU latch
    lda #3                      ; Column 3
    sta temp_1
    lda temp_3                  ; Current row
    sta temp_2
    jsr ppu_set_addr
    lda #'E'
    sta $2007

@next_item:
    ldx temp_mon_idx
    inx
    inc temp_3
    jmp @item_loop

@inv_done:
    rts
.endproc

; ============================================================
; DEATH STATE
; ============================================================
.proc state_death
    lda state_initialized
    beq @init
    jmp @update
@init:
    ; --- Init ---
    ; Disable NMI and rendering for safe PPU access
    lda #$00
    sta $2000                   ; Disable NMI first
    sta $2001                   ; Disable rendering
    sta ppu_ctrl                ; Update shadow
    sta ppu_mask                ; Update shadow
    sta vram_buf_len            ; Clear VRAM buffer

    jsr clear_nametable

    ; Load palette
    lda #<palette_title
    sta ptr_lo
    lda #>palette_title
    sta ptr_hi
    jsr load_palettes

    ; Red theme (all text uses BG palette 2) + framed panel
    lda #$AA                    ; every attribute quad = palette 2 (red)
    jsr fill_attr
    lda #3
    sta temp_1                  ; left col
    lda #6
    sta temp_2                  ; top row
    lda #26
    sta temp_3                  ; width
    lda #15
    sta temp_4                  ; height
    jsr draw_box

    ; Draw "YOU DIED" centered
    lda #<str_you_died
    sta ptr_lo
    lda #>str_you_died
    sta ptr_hi
    lda #12
    sta temp_1
    lda #10
    sta temp_2
    jsr draw_text

    ; Draw "PRESS START"
    lda #<str_press_start
    sta ptr_lo
    lda #>str_press_start
    sta ptr_hi
    lda #10
    sta temp_1
    lda #18
    sta temp_2
    jsr draw_text

    ; Draw floor reached (14 chars at col 8, ends col 21, colon at 21)
    lda #<str_floor_reached
    sta ptr_lo
    lda #>str_floor_reached
    sta ptr_hi
    lda #8
    sta temp_1
    lda #13
    sta temp_2
    jsr draw_text

    lda #24                     ; Number at col 24 (after colon + space)
    sta temp_1
    lda #13
    sta temp_2
    lda dungeon_level
    clc
    adc #$01
    jsr draw_number

    ; Draw gold collected (15 chars at col 7, ends col 21, colon at 21)
    lda #<str_gold_label
    sta ptr_lo
    lda #>str_gold_label
    sta ptr_hi
    lda #7
    sta temp_1
    lda #15
    sta temp_2
    jsr draw_text

    lda #24
    sta temp_1
    lda #15
    sta temp_2
    lda player_gold
    jsr draw_number_3d

    ; Enable rendering (NMI will flush VRAM buffer)
    lda #%10000000
    sta ppu_ctrl
    lda #%00001110
    sta ppu_mask
    lda #$00
    sta ppu_scroll_x
    sta ppu_scroll_y
    lda ppu_ctrl
    sta $2000                   ; Re-enable NMI last

    lda #$01
    sta state_initialized
    rts

@update:
    lda buttons_new
    and #BUTTON_START
    beq @done
    ; Return to title
    lda #STATE_TITLE
    sta game_state
    lda #$00
    sta state_initialized
@done:
    rts
.endproc

; ============================================================
; STAIRS STATE — transition between floors
; ============================================================
.proc state_stairs
    lda state_initialized
    bne @update

    ; --- Init ---
    ; Increment or decrement dungeon level based on stairs direction
    lda stairs_direction
    beq @going_down
    ; Going up
    dec dungeon_level
    ; Check for win (ascending past level 0 with goblet)
    lda dungeon_level
    bpl @level_ok
    ; Would go above level 0 — win condition (Phase 3)
    lda #$00
    sta dungeon_level
    lda #STATE_WIN
    sta game_state
    lda #$00
    sta state_initialized
    rts

@going_down:
    lda #SFX_STAIRS
    jsr sfx_play
    inc dungeon_level
    lda dungeon_level
    cmp #MAX_DUNGEON_LEVEL
    bcc @level_ok
    dec dungeon_level           ; Can't go deeper than max

@level_ok:
    ; Transition to gameplay with new level
    lda #STATE_GAMEPLAY
    sta game_state
    lda #$00
    sta state_initialized
    rts

@update:
    rts
.endproc

; ============================================================
; WIN STATE (placeholder for Phase 3)
; ============================================================
.proc state_win
    lda state_initialized
    beq @init
    jmp @update
@init:

    ; Disable NMI and rendering for safe PPU access
    lda #$00
    sta $2000                   ; Disable NMI first
    sta $2001                   ; Disable rendering
    sta ppu_ctrl                ; Update shadow
    sta ppu_mask                ; Update shadow
    sta vram_buf_len            ; Clear VRAM buffer

    jsr clear_nametable

    lda #<palette_title
    sta ptr_lo
    lda #>palette_title
    sta ptr_hi
    jsr load_palettes

    ; Green theme (all text uses BG palette 3) + framed panel
    lda #$FF                    ; every attribute quad = palette 3 (green)
    jsr fill_attr
    lda #3
    sta temp_1
    lda #6
    sta temp_2
    lda #26
    sta temp_3
    lda #15
    sta temp_4
    jsr draw_box

    ; Title
    lda #<str_you_win
    sta ptr_lo
    lda #>str_you_win
    sta ptr_hi
    lda #12
    sta temp_1
    lda #9
    sta temp_2
    jsr draw_text

    ; Floor reached
    lda #<str_floor_reached
    sta ptr_lo
    lda #>str_floor_reached
    sta ptr_hi
    lda #8
    sta temp_1
    lda #12
    sta temp_2
    jsr draw_text
    lda #24
    sta temp_1
    lda #12
    sta temp_2
    lda dungeon_level
    clc
    adc #$01
    jsr draw_number

    ; Gold collected
    lda #<str_gold_label
    sta ptr_lo
    lda #>str_gold_label
    sta ptr_hi
    lda #7
    sta temp_1
    lda #14
    sta temp_2
    jsr draw_text
    lda #24
    sta temp_1
    lda #14
    sta temp_2
    lda player_gold
    jsr draw_number_3d

    ; Prompt
    lda #<str_press_start
    sta ptr_lo
    lda #>str_press_start
    sta ptr_hi
    lda #10
    sta temp_1
    lda #17
    sta temp_2
    jsr draw_text

    ; Enable rendering (NMI will flush VRAM buffer)
    lda #%10000000
    sta ppu_ctrl
    lda #%00001110
    sta ppu_mask
    lda #$00
    sta ppu_scroll_x
    sta ppu_scroll_y
    lda ppu_ctrl
    sta $2000                   ; Re-enable NMI last

    lda #$01
    sta state_initialized
    rts

@update:
    lda buttons_new
    and #BUTTON_START
    beq @done
    lda #STATE_TITLE
    sta game_state
    lda #$00
    sta state_initialized
@done:
    rts
.endproc

; ============================================================
; game_init — Set up a new game
; ============================================================
.proc game_init
    ; Player stats
    lda #START_HP
    sta player_hp
    sta player_max_hp
    lda #START_STR
    sta player_str
    lda #START_DEF
    sta player_def
    lda #START_AGI
    sta player_agi
    lda #START_GOLD
    sta player_gold
    lda #START_LEVEL
    sta player_level
    lda #START_XP
    sta player_xp
    lda #START_HUNGER
    sta player_hunger
    lda #$00
    sta dungeon_level
    sta turn_taken
    sta turn_counter
    sta player_status
    sta confuse_timer
    sta blind_timer
    sta flash_timer
    sta msg_turn_priority
    sta msg_new_priority
    sta msg_dirty

    ; Give player starting equipment: Mace + Leather Armor
    lda #$00
    sta inventory_count

    ; Slot 0: Mace (+1)
    lda #ITEM_WEAPON
    sta inv_cat
    lda #WEAPON_MACE
    sta inv_sub
    lda #$01                    ; +1 enchantment
    sta inv_mod

    ; Slot 1: Leather Armor (+0)
    lda #ITEM_ARMOR
    sta inv_cat + 1
    lda #ARMOR_LEATHER
    sta inv_sub + 1
    lda #$00
    sta inv_mod + 1

    lda #$02
    sta inventory_count

    ; Auto-equip starting gear
    lda #$00
    sta equipped_weapon         ; Inventory slot 0 = Mace
    lda #$01
    sta equipped_armor          ; Inventory slot 1 = Leather Armor

    ; Clear message buffers so old messages don't persist
    ldy #31
    lda #$00
@clear_msg:
    sta msg_buf, y
    dey
    bpl @clear_msg

    rts
.endproc

; ============================================================
; do_screen_flip — Full viewport redraw for screen transitions
; Disables rendering, redraws viewport + HUD, re-enables.
; ============================================================
.proc do_screen_flip
    ; Disable NMI and rendering for safe PPU access
    lda #$00
    sta $2000                   ; Disable NMI first
    sta $2001                   ; Disable rendering
    sta ppu_ctrl                ; Update shadow
    sta ppu_mask                ; Update shadow
    sta vram_buf_len            ; Clear any pending VRAM writes
    sta flash_timer             ; Cancel any active flash (full redraw handles it)

    ; Redraw the entire viewport from new camera position
    jsr map_draw_viewport

    ; Redraw HUD
    jsr hud_draw

    ; Re-enable rendering
    lda #%10000000              ; NMI on, BG pattern table 0
    sta ppu_ctrl
    lda #%00001110              ; Show BG, no clipping
    sta ppu_mask
    lda #$00
    sta ppu_scroll_x
    sta ppu_scroll_y
    lda ppu_ctrl
    sta $2000                   ; Re-enable NMI last

    rts
.endproc

; ============================================================
; flash_update — Per-tile hit flash effect
; Draws a solid white tile at flash position for N frames,
; then restores the original tile/entity underneath.
; Called every frame from gameplay update.
; ============================================================
.proc flash_update
    lda flash_timer
    beq @done                   ; No active flash

    dec flash_timer
    bne @draw_flash

    ; --- Flash expired: restore original tile ---
    lda flash_x
    sta temp_1
    lda flash_y
    sta temp_2
    jsr map_restore_tile        ; Restore floor/item underneath

    ; Check if player is at flash position
    lda flash_x
    cmp player_x
    bne @check_monster
    lda flash_y
    cmp player_y
    bne @check_monster
    ; Redraw player @
    lda flash_x
    sta temp_1
    lda flash_y
    sta temp_2
    lda #CHR_PLAYER
    jsr map_update_entity
    rts

@check_monster:
    ; If it was a kill, floor is already restored — done
    lda flash_is_kill
    bne @done

    ; Non-kill hit: find the living monster at flash position and redraw it
    ldx #$00
@mon_loop:
    cpx monster_count
    beq @done
    lda mon_hp, x
    beq @mon_next               ; Skip dead
    lda mon_x, x
    cmp flash_x
    bne @mon_next
    lda mon_y, x
    cmp flash_y
    bne @mon_next
    ; Found the monster — redraw its CHR tile
    lda mon_x, x
    sta temp_1
    lda mon_y, x
    sta temp_2
    lda mon_type, x
    tay
    lda mon_chr_tile, y
    jsr map_update_entity
    rts

@mon_next:
    inx
    jmp @mon_loop

@draw_flash:
    ; Flash still active — draw solid white tile at position
    lda flash_x
    sta temp_1
    lda flash_y
    sta temp_2
    lda #CHR_FLASH
    jsr map_update_entity

@done:
    rts
.endproc
