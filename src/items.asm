; ============================================================
; Item Use System — Equip, drink, read, zap
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; item_use
; Use the inventory item at index X.
; Dispatches by item category.
; Input: X = inventory index
; Output: carry set = item consumed (remove from inventory)
;         carry clear = not consumed (equipped, or can't use)
; ------------------------------------------------------------
.proc item_use
    stx temp_mon_idx            ; Save inventory index
    lda inv_cat, x

    cmp #ITEM_WEAPON
    beq @equip_weapon
    cmp #ITEM_ARMOR
    beq @equip_armor
    cmp #ITEM_POTION
    bne @not_potion
    jmp @use_potion
@not_potion:
    cmp #ITEM_WAND
    bne @not_wand
    jmp @use_wand
@not_wand:

    ; Unknown item type — can't use
    clc
    rts

@equip_weapon:
    lda temp_mon_idx
    sta equipped_weapon
    lda #<str_equip_weapon
    sta ptr_lo
    lda #>str_equip_weapon
    sta ptr_hi
    jsr msg_show
    clc                         ; Not consumed (still in inventory)
    rts

@equip_armor:
    lda temp_mon_idx
    sta equipped_armor
    lda #<str_equip_armor
    sta ptr_lo
    lda #>str_equip_armor
    sta ptr_hi
    jsr msg_show
    clc                         ; Not consumed
    rts

@use_potion:
    ldx temp_mon_idx
    lda inv_sub, x
    cmp #POTION_HEALING
    beq @pot_heal
    cmp #POTION_EXTRA_HEALING
    beq @pot_extra_heal
    cmp #POTION_STRENGTH
    beq @pot_str
    cmp #POTION_POISON
    beq @pot_poison
    cmp #POTION_CONFUSION
    beq @pot_confusion
    cmp #POTION_BLINDNESS
    bne @pot_unknown
    jmp @pot_blindness
@pot_unknown:
    ; Unknown potion
    lda #<str_pot_strange
    sta ptr_lo
    lda #>str_pot_strange
    sta ptr_hi
    jsr msg_show
    sec
    rts

@pot_heal:
    ; Heal 25% max HP
    lda player_max_hp
    lsr a
    lsr a                       ; / 4
    clc
    adc player_hp
    cmp player_max_hp
    bcc @heal_ok
    lda player_max_hp
@heal_ok:
    sta player_hp
    lda #<str_pot_heal_msg
    sta ptr_lo
    lda #>str_pot_heal_msg
    sta ptr_hi
    jsr msg_show
    sec
    rts

@pot_extra_heal:
    ; Heal 50% max HP
    lda player_max_hp
    lsr a                       ; / 2
    clc
    adc player_hp
    cmp player_max_hp
    bcc @eheal_ok
    lda player_max_hp
@eheal_ok:
    sta player_hp
    lda #<str_pot_heal_msg
    sta ptr_lo
    lda #>str_pot_heal_msg
    sta ptr_hi
    jsr msg_show
    sec
    rts

@pot_str:
    ; +1 permanent strength
    lda player_str
    cmp #$FF
    bcs @str_max
    inc player_str
@str_max:
    lda #<str_pot_str_msg
    sta ptr_lo
    lda #>str_pot_str_msg
    sta ptr_hi
    jsr msg_show
    sec
    rts

@pot_poison:
    ; -1 strength
    lda player_str
    beq @poison_min
    dec player_str
@poison_min:
    lda #<str_pot_poison_msg
    sta ptr_lo
    lda #>str_pot_poison_msg
    sta ptr_hi
    jsr msg_show
    sec
    rts

@pot_confusion:
    ; Apply confusion for CONFUSE_DURATION turns
    lda player_status
    ora #STATUS_CONFUSED
    sta player_status
    lda #CONFUSE_DURATION
    sta confuse_timer
    lda #<str_confused
    sta ptr_lo
    lda #>str_confused
    sta ptr_hi
    jsr msg_show
    sec
    rts

@pot_blindness:
    ; Apply blindness for BLIND_DURATION turns
    lda player_status
    ora #STATUS_BLIND
    sta player_status
    lda #BLIND_DURATION
    sta blind_timer

    ; Immediately darken current visibility
    ldx player_prev_room
    cpx #$FF
    beq @blind_corridor
    ; In a room — downgrade it
    jsr fog_downgrade_room
    jmp @blind_redraw
@blind_corridor:
    ; In a corridor — clear visible area around player
    lda player_x
    sta temp_1
    lda player_y
    sta temp_2
    jsr fog_clear_visible
@blind_redraw:
    lda #$01
    sta screen_flip

    lda #<str_blinded
    sta ptr_lo
    lda #>str_blinded
    sta ptr_hi
    jsr msg_show
    sec
    rts

@use_wand:
    ; Wands use charges (inv_mod)
    ldx temp_mon_idx
    lda inv_mod, x
    bne @wand_has_charge
    jmp @wand_empty             ; No charges left

@wand_has_charge:
    ; Find nearest awake monster to target
    stx temp_mon_idx            ; Save inventory index
    jsr find_nearest_monster    ; Returns X = monster index or $FF
    cpx #$FF
    bne @wand_has_target

    ; No target found
    lda #<str_wand_no_target
    sta ptr_lo
    lda #>str_wand_no_target
    sta ptr_hi
    jsr msg_show
    clc                         ; Don't consume charge on no target
    rts

@wand_has_target:
    stx temp_3                  ; Save target monster index

    ; Consume one charge
    ldx temp_mon_idx            ; Restore inventory index
    dec inv_mod, x

    ; Dispatch by wand subtype
    lda inv_sub, x
    cmp #WAND_TELEPORT_AWAY
    beq @wand_teleport
    cmp #WAND_SLOW
    beq @wand_slow
    cmp #WAND_FIRE
    beq @wand_fire
    jmp @wand_lightning         ; Must be lightning (or unknown)

@wand_teleport:
    ; Teleport monster to random room
    ldx temp_3                  ; Monster index

    ; Erase old position if visible
    lda mon_y, x
    jsr fog_calc_offset
    ldx temp_3
    ldy mon_x, x
    lda (ptr_lo), y
    cmp #FOG_VISIBLE
    bne @tp_skip_erase
    lda mon_x, x
    sta temp_1
    lda mon_y, x
    sta temp_2
    jsr map_restore_tile
@tp_skip_erase:

    ; Pick random room and move monster to center
    lda room_count
    jsr rng_range
    tax
    lda room_w, x
    lsr a
    clc
    adc room_x, x
    sta temp_1                  ; New X
    lda room_h, x
    lsr a
    clc
    adc room_y, x
    sta temp_2                  ; New Y

    ldx temp_3
    lda temp_1
    sta mon_x, x
    lda temp_2
    sta mon_y, x

    ; Force viewport redraw
    lda #$01
    sta screen_flip

    lda #<str_wand_teleport
    sta ptr_lo
    lda #>str_wand_teleport
    sta ptr_hi
    jsr msg_show
    clc
    rts

@wand_slow:
    ; Apply slow flag to monster
    ldx temp_3
    lda mon_flags, x
    ora #MFLAG_SLOW
    sta mon_flags, x

    lda #<str_wand_slow
    sta ptr_lo
    lda #>str_wand_slow
    sta ptr_hi
    jsr msg_show
    clc
    rts

@wand_fire:
    ; Deal 8 fire damage to target
    lda #$08
    sta temp_1
    ldx temp_3
    stx temp_mon_idx            ; wand_deal_damage uses temp_mon_idx
    jsr wand_deal_damage

    lda #<str_wand_fire
    sta ptr_lo
    lda #>str_wand_fire
    sta ptr_hi
    jsr msg_show
    clc
    rts

@wand_lightning:
    ; Deal 12 lightning damage to target
    lda #$0C
    sta temp_1
    ldx temp_3
    stx temp_mon_idx
    jsr wand_deal_damage

    lda #<str_wand_lightning
    sta ptr_lo
    lda #>str_wand_lightning
    sta ptr_hi
    jsr msg_show
    clc
    rts

@wand_empty:
    lda #<str_wand_empty
    sta ptr_lo
    lda #>str_wand_empty
    sta ptr_hi
    jsr msg_show
    clc
    rts
.endproc

; ------------------------------------------------------------
; item_remove
; Remove inventory item at index X by shifting remaining items.
; Adjusts equipped_weapon/equipped_armor indices if needed.
; Input: X = index to remove
; ------------------------------------------------------------
.proc item_remove
    ; Adjust equipped indices
    cpx equipped_weapon
    bne @check_armor
    lda #$FF
    sta equipped_weapon         ; Unequip removed weapon
    jmp @shift
@check_armor:
    cpx equipped_armor
    bne @check_above_weapon
    lda #$FF
    sta equipped_armor          ; Unequip removed armor
@check_above_weapon:
    ; If removed index < equipped_weapon, decrement equipped_weapon
    lda equipped_weapon
    cmp #$FF
    beq @check_above_armor
    cpx equipped_weapon
    bcs @check_above_armor      ; X >= equipped, no adjust
    dec equipped_weapon
@check_above_armor:
    lda equipped_armor
    cmp #$FF
    beq @shift
    cpx equipped_armor
    bcs @shift
    dec equipped_armor

@shift:
    ; Shift items X+1..count-1 down by 1
    inx
    cpx inventory_count
    beq @done
    lda inv_cat, x
    sta inv_cat - 1, x
    lda inv_sub, x
    sta inv_sub - 1, x
    lda inv_mod, x
    sta inv_mod - 1, x
    jmp @shift

@done:
    dex                         ; Undo last inx
    dec inventory_count
    rts
.endproc

; ------------------------------------------------------------
; teleport_player
; Move player to a random room (different from current).
; ------------------------------------------------------------
.proc teleport_player
    ; Pick random room
    lda room_count
    jsr rng_range               ; 0 to room_count-1
    tax

    ; Place player at center of room
    lda room_x, x
    clc
    adc room_w, x
    lsr a                       ; Center X
    sta player_x
    lda room_y, x
    clc
    adc room_h, x
    lsr a                       ; Center Y
    sta player_y

    ; Set screen flip flag so viewport redraws
    lda #$01
    sta screen_flip
    rts
.endproc

; ------------------------------------------------------------
; find_nearest_monster
; Find the nearest living, awake monster within 8 tiles.
; Output: X = monster index, or $FF if none found
; Clobbers: temp_1, temp_2, temp_4
; ------------------------------------------------------------
.proc find_nearest_monster
    lda #$FF
    sta temp_4                  ; Best monster index ($FF = none)
    lda #$09                    ; Best distance (> 8 = nothing yet)
    sta temp_2

    ldx #$00
@loop:
    cpx monster_count
    beq @done

    ; Skip dead monsters
    lda mon_hp, x
    beq @next

    ; Skip sleeping monsters
    lda mon_flags, x
    and #MFLAG_AWAKE
    beq @next

    ; Calculate distance
    stx temp_mon_idx
    jsr calc_monster_dist       ; Returns distance in A

    ; Check if within range (8 tiles) and closer than best
    cmp #$09
    bcs @next                   ; > 8 tiles, skip
    cmp temp_2
    bcs @next                   ; Not closer than current best

    ; New best
    sta temp_2                  ; Best distance
    ldx temp_mon_idx
    stx temp_4                  ; Best monster index

@next:
    ldx temp_mon_idx
    inx
    jmp @loop

@done:
    ldx temp_4                  ; Return best index (or $FF)
    rts
.endproc

; ------------------------------------------------------------
; wand_deal_damage
; Deal damage from a wand to the monster at temp_mon_idx.
; Input: temp_1 = damage amount, temp_mon_idx = monster index
; Handles death, XP award, flash effect.
; ------------------------------------------------------------
.proc wand_deal_damage
    ldx temp_mon_idx

    ; Apply damage
    lda mon_hp, x
    sec
    sbc temp_1
    bcs @not_dead
    lda #$00
@not_dead:
    sta mon_hp, x

    ; Flash effect at monster position
    lda mon_x, x
    sta flash_x
    lda mon_y, x
    sta flash_y
    lda #$03
    sta flash_timer

    ; Check if killed
    lda mon_hp, x
    bne @alive

    ; Monster killed
    lda #$01
    sta flash_is_kill

    ; Award XP
    ldy mon_type, x
    lda mon_xp, y
    clc
    adc player_xp
    bcc @xp_ok
    lda #$FF
@xp_ok:
    sta player_xp
    jsr check_level_up
    rts

@alive:
    lda #$00
    sta flash_is_kill
    rts
.endproc
