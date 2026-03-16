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

    ; --- Draw "ROGUE" as background tiles (2x2 per letter) ---
    ; Row 10 (top halves): PPU $2149 = row 10, col 9
    lda $2002                   ; Reset PPU latch
    lda #$21
    sta $2006
    lda #$49
    sta $2006
    ; R-TL, R-TR, space, O-TL, O-TR, space, G-TL, G-TR, space, U-TL, U-TR, space, E-TL, E-TR
    lda #$80
    sta $2007
    lda #$81
    sta $2007
    lda #$20                    ; space between letters
    sta $2007
    lda #$84
    sta $2007
    lda #$85
    sta $2007
    lda #$20
    sta $2007
    lda #$88
    sta $2007
    lda #$89
    sta $2007
    lda #$20
    sta $2007
    lda #$8C
    sta $2007
    lda #$8D
    sta $2007
    lda #$20
    sta $2007
    lda #$90
    sta $2007
    lda #$91
    sta $2007

    ; Row 11 (bottom halves): PPU $2169 = row 11, col 9
    lda #$21
    sta $2006
    lda #$69
    sta $2006
    lda #$82
    sta $2007
    lda #$83
    sta $2007
    lda #$20
    sta $2007
    lda #$86
    sta $2007
    lda #$87
    sta $2007
    lda #$20
    sta $2007
    lda #$8A
    sta $2007
    lda #$8B
    sta $2007
    lda #$20
    sta $2007
    lda #$8E
    sta $2007
    lda #$8F
    sta $2007
    lda #$20
    sta $2007
    lda #$92
    sta $2007
    lda #$93
    sta $2007

    ; --- Draw "PRESS START" as background text ---
    lda #<str_press_start
    sta ptr_lo
    lda #>str_press_start
    sta ptr_hi
    lda #10                     ; X position (centered)
    sta temp_1
    lda #16                     ; Y position (below the title)
    sta temp_2
    jsr draw_text

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
    ; Hide: clear row 16 via VRAM buffer
    lda #$00
    sta temp_1
    lda #16
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
    lda #16
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
    bne @update

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

    ; Welcome message
    lda #<str_welcome
    sta ptr_lo
    lda #>str_welcome
    sta ptr_hi
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

    ; "- PAUSED -" centered on row 3
    lda #<str_pause
    sta ptr_lo
    lda #>str_pause
    sta ptr_hi
    lda #11
    sta temp_1
    lda #3
    sta temp_2
    jsr ppu_draw_text

    ; --- Stats block starting at row 7 ---

    ; "Hit Points:  12/12"
    lda #<str_pause_hp
    sta ptr_lo
    lda #>str_pause_hp
    sta ptr_hi
    lda #4
    sta temp_1
    lda #7
    sta temp_2
    jsr ppu_draw_text
    lda #16
    sta temp_1
    lda #7
    sta temp_2
    lda player_hp
    jsr ppu_draw_number
    ; "/" — PPU address auto-incremented to pos 19, just write directly
    lda #'/'
    sta $2007
    ; Max HP — PPU address now at 20, write 3 chars directly
    lda player_max_hp
    jsr ppu_draw_number_continue

    ; "Strength:  16"
    lda #<str_pause_str
    sta ptr_lo
    lda #>str_pause_str
    sta ptr_hi
    lda #4
    sta temp_1
    lda #9
    sta temp_2
    jsr ppu_draw_text
    lda #16
    sta temp_1
    lda #9
    sta temp_2
    lda player_str
    jsr ppu_draw_number

    ; "Defense:  15"
    lda #<str_pause_def
    sta ptr_lo
    lda #>str_pause_def
    sta ptr_hi
    lda #4
    sta temp_1
    lda #11
    sta temp_2
    jsr ppu_draw_text
    lda #16
    sta temp_1
    lda #11
    sta temp_2
    lda player_def
    jsr ppu_draw_number

    ; "Level:  1"
    lda #<str_pause_lvl
    sta ptr_lo
    lda #>str_pause_lvl
    sta ptr_hi
    lda #4
    sta temp_1
    lda #13
    sta temp_2
    jsr ppu_draw_text
    lda #16
    sta temp_1
    lda #13
    sta temp_2
    lda player_level
    jsr ppu_draw_number

    ; "Experience:  0"
    lda #<str_pause_xp
    sta ptr_lo
    lda #>str_pause_xp
    sta ptr_hi
    lda #4
    sta temp_1
    lda #15
    sta temp_2
    jsr ppu_draw_text
    lda #16
    sta temp_1
    lda #15
    sta temp_2
    lda player_xp
    jsr ppu_draw_number

    ; "Gold:  0"
    lda #<str_pause_gold
    sta ptr_lo
    lda #>str_pause_gold
    sta ptr_hi
    lda #4
    sta temp_1
    lda #17
    sta temp_2
    jsr ppu_draw_text
    lda #16
    sta temp_1
    lda #17
    sta temp_2
    lda player_gold
    jsr ppu_draw_number

    ; "Floor:  1"
    lda #<str_pause_floor
    sta ptr_lo
    lda #>str_pause_floor
    sta ptr_hi
    lda #4
    sta temp_1
    lda #19
    sta temp_2
    jsr ppu_draw_text
    lda #16
    sta temp_1
    lda #19
    sta temp_2
    lda dungeon_level
    clc
    adc #$01
    jsr ppu_draw_number

    ; --- Equipment block at row 22 ---

    ; "Weapon: +1 Mace"
    lda #<str_pause_weapon
    sta ptr_lo
    lda #>str_pause_weapon
    sta ptr_hi
    lda #4
    sta temp_1
    lda #22
    sta temp_2
    jsr ppu_draw_text

    ; "Armor:  Ring Mail"
    lda #<str_pause_armor
    sta ptr_lo
    lda #>str_pause_armor
    sta ptr_hi
    lda #4
    sta temp_1
    lda #23
    sta temp_2
    jsr ppu_draw_text

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
    lda buttons_new
    and #BUTTON_START
    beq @done
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
    ; Reload dungeon palette (pause screen used title palette)
    lda #<palette_dungeon
    sta ptr_lo
    lda #>palette_dungeon
    sta ptr_hi
    jsr load_palettes
    jsr do_screen_flip          ; Redraw viewport, HUD, re-enable rendering
@done:
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

    ; Draw floor reached
    lda #<str_floor_reached
    sta ptr_lo
    lda #>str_floor_reached
    sta ptr_hi
    lda #8
    sta temp_1
    lda #13
    sta temp_2
    jsr draw_text

    lda #23                     ; X after "FLOOR: "
    sta temp_1
    lda #13
    sta temp_2
    lda dungeon_level
    clc
    adc #$01
    jsr draw_number

    ; Draw gold collected
    lda #<str_gold_label
    sta ptr_lo
    lda #>str_gold_label
    sta ptr_hi
    lda #9
    sta temp_1
    lda #15
    sta temp_2
    jsr draw_text

    lda #23
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
    bne @update

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

    lda #<str_you_win
    sta ptr_lo
    lda #>str_you_win
    sta ptr_hi
    lda #12
    sta temp_1
    lda #12
    sta temp_2
    jsr draw_text

    lda #<str_press_start
    sta ptr_lo
    lda #>str_press_start
    sta ptr_hi
    lda #10
    sta temp_1
    lda #18
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
    sta flash_timer
    sta msg_turn_priority
    sta msg_new_priority
    sta msg_dirty

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
