; ============================================================
; Monster System — AI, movement, spawning
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; monsters_update
; Process all monster turns (called after player moves).
; Each awake monster moves toward player or attacks.
; ------------------------------------------------------------
.proc monsters_update
    ldx #$00
@loop:
    cpx monster_count
    beq @done
    stx temp_mon_idx

    ; Skip dead monsters (hp = 0)
    lda mon_hp, x
    beq @next

    ; Check if sleeping
    lda mon_flags, x
    and #MFLAG_AWAKE
    beq @check_wake

    ; Monster is awake — decide action
    jsr monster_act
    jmp @next

@check_wake:
    ; Check distance to player
    jsr calc_monster_dist       ; Returns distance in A
    cmp #MONSTER_WAKE_DIST
    bcs @next                   ; Too far, stay asleep

    ; Wake up!
    ldx temp_mon_idx
    lda mon_flags, x
    ora #MFLAG_AWAKE
    sta mon_flags, x

@next:
    ldx temp_mon_idx
    inx
    jmp @loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; monster_act
; Process one monster's turn.
; Input: temp_mon_idx = monster index
; ------------------------------------------------------------
.proc monster_act
    ldx temp_mon_idx

    ; Check if adjacent to player (can attack)
    lda mon_x, x
    sec
    sbc player_x
    bpl @abs_dx
    eor #$FF
    clc
    adc #$01
@abs_dx:
    sta temp_1                  ; |dx|

    lda mon_y, x
    sec
    sbc player_y
    bpl @abs_dy
    eor #$FF
    clc
    adc #$01
@abs_dy:
    sta temp_2                  ; |dy|

    ; Adjacent if max(|dx|, |dy|) <= 1
    lda temp_1
    cmp #$02
    bcs @move
    lda temp_2
    cmp #$02
    bcs @move

    ; Both dx and dy <= 1 — attack!
    lda temp_1
    ora temp_2
    beq @move                   ; Same tile? shouldn't happen, just move
    jsr monster_attack_player
    rts

@move:
    ; Check for erratic movement
    ldx temp_mon_idx
    lda mon_flags, x
    and #MFLAG_ERRATIC
    beq @chase

    ; 50% chance of random movement
    jsr rng_next
    and #$01
    beq @chase

    ; Random direction
    lda #$08                    ; 8 directions
    jsr rng_range
    tax
    lda dir_dx, x
    sta move_dx
    lda dir_dy, x
    sta move_dy
    jmp @try_move

@chase:
    ; Move toward player (prefer axis with greater distance)
    ldx temp_mon_idx
    lda #$00
    sta move_dx
    sta move_dy

    lda player_x
    cmp mon_x, x
    beq @check_y
    bcc @move_left
    inc move_dx                 ; Move right
    jmp @check_y
@move_left:
    dec move_dx                 ; Move left

@check_y:
    lda player_y
    cmp mon_y, x
    beq @try_move
    bcc @move_up
    inc move_dy                 ; Move down
    jmp @try_move
@move_up:
    dec move_dy                 ; Move up

@try_move:
    ldx temp_mon_idx

    ; Calculate target
    lda mon_x, x
    clc
    adc move_dx
    sta target_x

    lda mon_y, x
    clc
    adc move_dy
    sta target_y

    ; Bounds check
    lda target_x
    cmp #MAP_COLS
    bcs @cant_move
    lda target_y
    cmp #MAP_ROWS
    bcs @cant_move

    ; Check passability
    lda target_y
    jsr calc_row_offset
    ldy target_x
    lda (ptr_lo), y
    cmp #TILE_WALL
    beq @cant_move
    cmp #TILE_DOOR_CLOSED
    beq @cant_move

    ; Check for other monsters at target
    jsr check_monster_collision
    bcs @cant_move

    ; Check if target is player position (shouldn't move onto player)
    lda target_x
    cmp player_x
    bne @not_player
    lda target_y
    cmp player_y
    beq @cant_move              ; Can't walk onto player
@not_player:

    ; Erase old position (only if visible to player)
    ldx temp_mon_idx
    lda mon_y, x
    jsr fog_calc_offset
    ldx temp_mon_idx
    ldy mon_x, x
    lda (ptr_lo), y
    cmp #FOG_VISIBLE
    bne @skip_erase
    lda mon_x, x
    sta temp_1
    lda mon_y, x
    sta temp_2
    jsr map_restore_tile
@skip_erase:

    ; Update position
    ldx temp_mon_idx
    lda target_x
    sta mon_x, x
    lda target_y
    sta mon_y, x

    ; Draw new position (only if visible to player)
    lda mon_y, x
    jsr fog_calc_offset
    ldx temp_mon_idx
    ldy mon_x, x
    lda (ptr_lo), y
    cmp #FOG_VISIBLE
    bne @skip_draw
    lda mon_x, x
    sta temp_1
    lda mon_y, x
    sta temp_2
    lda mon_type, x
    tay
    lda mon_chr_tile, y
    jsr map_update_entity
@skip_draw:

@cant_move:
    rts
.endproc

; ------------------------------------------------------------
; calc_monster_dist
; Calculate Chebyshev distance from monster to player.
; Input: temp_mon_idx
; Output: A = max(|dx|, |dy|)
; ------------------------------------------------------------
.proc calc_monster_dist
    ldx temp_mon_idx

    lda mon_x, x
    sec
    sbc player_x
    bpl @abs_dx
    eor #$FF
    clc
    adc #$01
@abs_dx:
    sta temp_1

    lda mon_y, x
    sec
    sbc player_y
    bpl @abs_dy
    eor #$FF
    clc
    adc #$01
@abs_dy:

    ; Return max(|dx|, |dy|)
    cmp temp_1
    bcs @dy_bigger
    lda temp_1                  ; dx is bigger
@dy_bigger:
    rts
.endproc

; ------------------------------------------------------------
; check_monster_collision
; Check if another monster is at (target_x, target_y).
; Output: carry set if blocked, carry clear if free
; ------------------------------------------------------------
.proc check_monster_collision
    ldx #$00
@loop:
    cpx monster_count
    beq @free

    ; Skip self
    cpx temp_mon_idx
    beq @next

    ; Skip dead
    lda mon_hp, x
    beq @next

    lda mon_x, x
    cmp target_x
    bne @next
    lda mon_y, x
    cmp target_y
    bne @next

    sec                         ; Blocked
    rts

@next:
    inx
    jmp @loop

@free:
    clc
    rts
.endproc

; ============================================================
; Direction tables for 8-directional movement
; ============================================================
.segment "RODATA"

dir_dx:
    .byte $00, $01, $01, $01, $00, $FF, $FF, $FF  ; N, NE, E, SE, S, SW, W, NW
dir_dy:
    .byte $FF, $FF, $00, $01, $01, $01, $00, $FF
