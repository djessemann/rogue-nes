; ============================================================
; Player System — Movement, input handling
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; player_input
; Process player input for one turn.
; Sets turn_taken = 1 if the player performed an action.
; ------------------------------------------------------------
.proc player_input
    lda #$00
    sta turn_taken

    ; Check directional input (new presses only for turn-based)
    lda buttons_new
    sta temp_move               ; Save for diagonal check

    ; Calculate desired dx, dy
    lda #$00
    sta move_dx
    sta move_dy

    ; Check UP
    lda temp_move
    and #BUTTON_UP
    beq @no_up
    dec move_dy                 ; dy = -1
@no_up:

    ; Check DOWN
    lda temp_move
    and #BUTTON_DOWN
    beq @no_down
    inc move_dy                 ; dy = +1
@no_down:

    ; Check LEFT
    lda temp_move
    and #BUTTON_LEFT
    beq @no_left
    dec move_dx                 ; dx = -1
@no_left:

    ; Check RIGHT
    lda temp_move
    and #BUTTON_RIGHT
    beq @no_right
    inc move_dx                 ; dx = +1
@no_right:

    ; If no direction, check other buttons
    lda move_dx
    ora move_dy
    bne @has_direction
    jmp @check_buttons
@has_direction:

    ; --- Attempt movement ---
    ; Calculate target position
    lda player_x
    clc
    adc move_dx
    sta target_x

    lda player_y
    clc
    adc move_dy
    sta target_y

    ; Bounds check against full map (64x48)
    lda target_x
    cmp #MAP_W
    bcs @blocked                ; >= 64 (or wrapped negative)
    lda target_y
    cmp #MAP_H
    bcs @blocked                ; >= 48 (or wrapped negative)

    ; Check if target has a monster (bump attack)
    jsr check_monster_at_target
    bcc @no_monster
    ; Monster found — attack it (X = monster index)
    stx temp_mon_idx
    jsr player_attack_monster
    lda #$01
    sta turn_taken
    rts

@no_monster:
    ; Check if target tile is passable
    lda target_y
    jsr calc_row_offset
    ldy target_x
    lda (ptr_lo), y
    cmp #TILE_WALL
    beq @blocked
    cmp #TILE_DOOR_CLOSED
    beq @open_door

    ; --- Move player ---
    ; Save old position for fog update (reuse move_dx/move_dy — done with them)
    lda player_x
    sta move_dx                 ; Old X
    lda player_y
    sta move_dy                 ; Old Y

    ; Erase old position
    lda player_x
    sta temp_1
    lda player_y
    sta temp_2
    jsr map_restore_tile

    ; Update position
    lda target_x
    sta player_x
    lda target_y
    sta player_y

    ; Check for screen flip (updates camera if player left viewport)
    jsr check_screen_flip

    ; Update fog of war (may set screen_flip for room transitions)
    jsr update_fog

    ; Draw player AFTER fog update so corridor fog doesn't overwrite @
    lda player_x
    sta temp_1
    lda player_y
    sta temp_2
    lda #CHR_PLAYER
    jsr map_update_entity

    ; Check for items at new position
    jsr check_pickup

    lda #$01
    sta turn_taken
    rts

@open_door:
    ; Change door to open
    lda target_y
    jsr calc_row_offset
    ldy target_x
    lda #TILE_DOOR_OPEN
    sta (ptr_lo), y

    ; Update tile on screen
    lda target_x
    sta temp_1
    lda target_y
    sta temp_2
    lda #CHR_DOOR_OPEN
    jsr map_update_entity

    lda #$01
    sta turn_taken
    rts

@blocked:
    rts

@check_buttons:
    ; B button = wait one turn
    lda buttons_new
    and #BUTTON_B
    beq @no_wait
    lda #$01
    sta turn_taken
    rts
@no_wait:

    ; A button = pick up / use stairs
    lda buttons_new
    and #BUTTON_A
    beq @no_action

    ; Check if on stairs
    lda player_y
    jsr calc_row_offset
    ldy player_x
    lda (ptr_lo), y
    cmp #TILE_STAIRS_DOWN
    beq @go_down
    cmp #TILE_STAIRS_UP
    beq @go_up

    ; Check for item pickup
    jsr check_pickup
    rts

@go_down:
    lda #$00                    ; Direction = down
    sta stairs_direction
    lda #STATE_STAIRS
    sta game_state
    lda #$00
    sta state_initialized
    rts

@go_up:
    lda #$01                    ; Direction = up
    sta stairs_direction
    lda #STATE_STAIRS
    sta game_state
    lda #$00
    sta state_initialized
    rts

@no_action:
    rts
.endproc

; ------------------------------------------------------------
; check_screen_flip
; Check if player has moved outside the current viewport.
; If so, update camera_x/camera_y and set screen_flip = 1.
; The gamestate handler will then do a full screen redraw.
; ------------------------------------------------------------
.proc check_screen_flip
    ; --- Check horizontal ---
    lda player_x
    cmp camera_x
    bcs @check_right            ; player_x >= camera_x, not off left

    ; Player moved left of viewport
    lda camera_x
    sec
    sbc #VIEW_W
    bcs @set_cam_x              ; Result >= 0
    lda #$00                    ; Clamp to 0
@set_cam_x:
    sta camera_x
    lda #$01
    sta screen_flip
    jmp @check_y

@check_right:
    ; Check if player_x >= camera_x + VIEW_W
    lda camera_x
    clc
    adc #VIEW_W
    sta temp_1                  ; camera_x + VIEW_W
    lda player_x
    cmp temp_1
    bcc @check_y                ; Still within viewport

    ; Player moved right of viewport
    lda temp_1
    cmp #MAP_W
    bcs @check_y                ; Can't scroll past map edge
    sta camera_x
    lda #$01
    sta screen_flip

@check_y:
    ; --- Check vertical ---
    lda player_y
    cmp camera_y
    bcs @check_down             ; player_y >= camera_y, not off top

    ; Player moved above viewport
    lda camera_y
    sec
    sbc #VIEW_H
    bcs @set_cam_y
    lda #$00
@set_cam_y:
    sta camera_y
    lda #$01
    sta screen_flip
    rts

@check_down:
    ; Check if player_y >= camera_y + VIEW_H
    lda camera_y
    clc
    adc #VIEW_H
    sta temp_1
    lda player_y
    cmp temp_1
    bcc @done                   ; Still within viewport

    ; Player moved below viewport
    lda temp_1
    cmp #MAP_H
    bcs @done                   ; Can't scroll past map edge
    sta camera_y
    lda #$01
    sta screen_flip

@done:
    rts
.endproc

; ------------------------------------------------------------
; update_fog
; Update fog of war after player moves.
; Uses move_dx/move_dy as saved old position.
; Handles room transitions and corridor visibility.
; ------------------------------------------------------------
.proc update_fog
    ; Find which room player is now in
    jsr find_player_room
    bcc @in_corridor

    ; --- Player is in a room ---
    lda player_current_room
    cmp player_prev_room
    beq @same_room              ; Same room, nothing to change

    ; Different room — downgrade old room if valid
    ldx player_prev_room
    cpx #$FF
    beq @no_downgrade
    jsr fog_downgrade_room
@no_downgrade:

    ; Reveal new room
    ldx player_current_room
    jsr fog_reveal_room

    ; Update prev room tracker
    lda player_current_room
    sta player_prev_room

    ; Trigger full screen redraw to show revealed room
    lda #$01
    sta screen_flip

@same_room:
    rts

@in_corridor:
    ; Downgrade old visible area (old position saved in move_dx/move_dy)
    lda move_dx
    sta temp_1                  ; Old X
    lda move_dy
    sta temp_2                  ; Old Y
    jsr fog_clear_visible

    ; Reveal around current position
    jsr fog_reveal_around

    ; If was in a room, downgrade it and trigger redraw
    ldx player_prev_room
    cpx #$FF
    beq @no_room_downgrade
    jsr fog_downgrade_room
    lda #$FF
    sta player_prev_room
    ; Full redraw needed since we left a room
    lda #$01
    sta screen_flip
    rts
@no_room_downgrade:

    ; Queue VRAM writes for newly revealed corridor tiles (3x3 area)
    jsr fog_draw_around_vram
    rts
.endproc

; ------------------------------------------------------------
; check_monster_at_target
; Check if there's a monster at (target_x, target_y).
; Output: carry set if found, X = monster index
;         carry clear if not found
; ------------------------------------------------------------
.proc check_monster_at_target
    ldx #$00
@loop:
    cpx monster_count
    beq @not_found

    ; Skip dead monsters
    lda mon_hp, x
    beq @next

    lda mon_x, x
    cmp target_x
    bne @next
    lda mon_y, x
    cmp target_y
    bne @next

    ; Found living monster at target
    sec
    rts

@next:
    inx
    jmp @loop

@not_found:
    clc
    rts
.endproc

; ------------------------------------------------------------
; check_pickup
; Check if player is standing on a floor item and pick it up.
; ------------------------------------------------------------
.proc check_pickup
    ldx #$00
@loop:
    cpx floor_item_count
    beq @done

    lda fi_x, x
    cmp player_x
    bne @next
    lda fi_y, x
    cmp player_y
    bne @next

    ; Found item — handle by type
    lda fi_type, x
    cmp #ITEM_GOLD
    beq @pickup_gold
    cmp #ITEM_FOOD
    beq @pickup_food
    jmp @next                   ; Unknown type, skip

@pickup_gold:
    ; Add gold to player total
    lda fi_mod, x               ; Gold amount
    clc
    adc player_gold
    bcc @gold_ok
    lda #$FF                    ; Cap at 255
@gold_ok:
    sta player_gold

    ; Show message
    lda #<str_found_gold
    sta ptr_lo
    lda #>str_found_gold
    sta ptr_hi
    jsr msg_show

    jmp @remove_item

@pickup_food:
    ; Restore hunger
    lda player_hunger
    clc
    adc #FOOD_RESTORE
    bcc @hunger_ok
    lda #$FF
@hunger_ok:
    sta player_hunger

    ; Heal 25% of max HP
    lda player_max_hp
    lsr a
    lsr a                       ; / 4 = 25%
    clc
    adc player_hp
    cmp player_max_hp
    bcc @hp_ok
    lda player_max_hp
@hp_ok:
    sta player_hp

    lda #<str_ate_food
    sta ptr_lo
    lda #>str_ate_food
    sta ptr_hi
    jsr msg_show

    jmp @remove_item

@remove_item:
    ; Remove item by shifting array
    jsr remove_floor_item       ; X = index to remove
    rts

@next:
    inx
    jmp @loop
@done:
    rts
.endproc

; ------------------------------------------------------------
; remove_floor_item
; Remove floor item at index X by shifting remaining items down.
; Input: X = index to remove
; ------------------------------------------------------------
.proc remove_floor_item
    ; Shift items from X+1..count-1 down by 1
@shift:
    inx
    cpx floor_item_count
    beq @done

    lda fi_x, x
    sta fi_x - 1, x
    lda fi_y, x
    sta fi_y - 1, x
    lda fi_type, x
    sta fi_type - 1, x
    lda fi_mod, x
    sta fi_mod - 1, x

    jmp @shift

@done:
    dec floor_item_count
    rts
.endproc
