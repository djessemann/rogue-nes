; ============================================================
; Combat System — Attack resolution, damage, XP
; JRPG-style: flat ATK/DEF with accuracy check
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; player_attack_monster
; Player attacks monster at index X.
; Hit check: rng(100) < (BASE_HIT_CHANCE + player_agi - mon_evasion)
; Damage: weapon_power + enchant + player_str - mon_def +/- 1 (min 1)
; Input: X = monster index (also in temp_mon_idx)
; ------------------------------------------------------------
.proc player_attack_monster
    ldx temp_mon_idx

    ; --- Accuracy check ---
    ; Calculate hit threshold: BASE_HIT_CHANCE + player_agi - mon_evasion
    lda #BASE_HIT_CHANCE
    clc
    adc player_agi
    ; Clamp to 255 max before subtraction
    bcc @agi_ok
    lda #$FF
@agi_ok:
    sta temp_2                  ; Save threshold so far
    ldy mon_type, x
    lda temp_2
    sec
    sbc mon_evasion, y
    bcs @eva_ok
    lda #$05                    ; Minimum 5% hit chance
@eva_ok:
    sta temp_2                  ; Final hit threshold

    ; Roll 0-99
    lda #100
    jsr rng_range
    cmp temp_2                  ; Hit if roll < threshold
    bcc @hit
    jmp @miss

@hit:
    ; --- Calculate damage ---
    ; Get weapon power (or default bare-hands)
    lda equipped_weapon
    cmp #$FF
    beq @default_weapon
    tax
    lda inv_sub, x
    tay
    lda weapon_power, y         ; Base weapon power
    clc
    adc inv_mod, x              ; + enchantment modifier
    jmp @add_str
@default_weapon:
    lda #DEFAULT_WEAPON_POWER
@add_str:
    ; Add player strength bonus
    clc
    adc player_str
    sta temp_1                  ; Total attack power

    ; Subtract monster defense
    ldx temp_mon_idx
    ldy mon_type, x
    lda temp_1
    sec
    sbc mon_def, y
    bcs @def_ok
    lda #$00                    ; Underflow
@def_ok:
    sta temp_1                  ; Base damage (before variance)

    ; Add variance: -1, +0, or +1
    lda #$03
    jsr rng_range               ; 0, 1, or 2
    cmp #$00
    beq @var_minus               ; 0 = subtract 1
    cmp #$01
    beq @var_zero                ; 1 = no change
    ; 2 = add 1
    inc temp_1
    jmp @var_done
@var_minus:
    lda temp_1
    beq @var_done                ; Don't go below 0
    dec temp_1
    jmp @var_done
@var_zero:
@var_done:

    ; Enforce minimum 1 damage on a hit
    lda temp_1
    bne @apply_damage
    lda #$01
    sta temp_1

@apply_damage:
    ; Apply damage to monster
    ldx temp_mon_idx
    lda mon_hp, x
    sec
    sbc temp_1
    bcs @not_dead
    lda #$00                    ; Clamp to 0
@not_dead:
    sta mon_hp, x

    ; Set per-tile flash at monster position
    lda mon_x, x
    sta flash_x
    lda mon_y, x
    sta flash_y
    lda #$03
    sta flash_timer

    ; Check if monster died
    lda mon_hp, x
    bne @hit_only

    ; --- Monster killed ---
    lda #SFX_MONSTER_DEAD
    jsr sfx_play
    lda #$01
    sta flash_is_kill           ; Flash will restore floor when done

    ; Award XP
    ldy mon_type, x
    lda mon_xp, y
    clc
    adc player_xp
    bcc @xp_ok
    lda #$FF
@xp_ok:
    sta player_xp

    ; Check for level up
    jsr check_level_up

    ; Build kill message: "Defeated the <name>" (high priority)
    lda #$02
    sta msg_new_priority
    jsr msg_start
    lda #<str_defeated
    sta ptr_lo
    lda #>str_defeated
    sta ptr_hi
    jsr msg_append
    ldx temp_mon_idx
    ldy mon_type, x
    jsr msg_append_monster_name
    jsr msg_show_build
    jmp @done

@hit_only:
    lda #SFX_PLAYER_HIT
    jsr sfx_play
    lda #$00
    sta flash_is_kill           ; Flash will restore monster when done

    ; Build hit message: "You hit the <name>" (normal priority)
    lda #$01
    sta msg_new_priority
    jsr msg_start
    lda #<str_you_hit
    sta ptr_lo
    lda #>str_you_hit
    sta ptr_hi
    jsr msg_append
    ldx temp_mon_idx
    ldy mon_type, x
    jsr msg_append_monster_name
    jsr msg_show_build

@done:
    rts

@miss:
    ; Build miss message: "You miss the <name>" (normal priority)
    lda #$01
    sta msg_new_priority
    jsr msg_start
    lda #<str_you_miss
    sta ptr_lo
    lda #>str_you_miss
    sta ptr_hi
    jsr msg_append
    ldx temp_mon_idx
    ldy mon_type, x
    jsr msg_append_monster_name
    jsr msg_show_build
    rts
.endproc

; ------------------------------------------------------------
; monster_attack_player
; Monster at temp_mon_idx attacks the player.
; Hit check: rng(100) < (90 - player_agi). Damage: mon_atk - player_def +/- 1
; ------------------------------------------------------------
.proc monster_attack_player
    ldx temp_mon_idx

    ; --- Accuracy check: 90 - player_agility ---
    lda #90
    sec
    sbc player_agi
    bcs @agi_ok
    lda #$05                    ; Minimum 5% hit chance
@agi_ok:
    sta temp_2                  ; Hit threshold

    lda #100
    jsr rng_range               ; 0-99
    cmp temp_2
    bcc @mon_hit                ; < threshold = hit
    jmp @mon_miss

@mon_hit:
    ldx temp_mon_idx

    ; --- Calculate damage ---
    ; Get monster attack power
    ldy mon_type, x
    lda mon_atk, y
    sta temp_1                  ; Monster ATK

    ; Calculate player effective defense: armor + enchant + def bonus
    lda player_def              ; Base defense bonus from levels
    sta temp_2
    lda equipped_armor
    cmp #$FF
    beq @calc_dmg               ; No armor, just use player_def
    tax
    lda inv_sub, x
    tay
    lda armor_defense, y        ; Armor base defense
    clc
    adc inv_mod, x              ; + enchantment
    clc
    adc temp_2                  ; + player def bonus
    sta temp_2

@calc_dmg:
    ; Damage = mon_atk - player_defense
    lda temp_1
    sec
    sbc temp_2
    bcs @def_ok
    lda #$00
@def_ok:
    sta temp_1

    ; Add variance: -1, +0, or +1
    lda #$03
    jsr rng_range               ; 0, 1, or 2
    cmp #$00
    beq @var_minus               ; 0 = subtract 1
    cmp #$01
    beq @var_zero                ; 1 = no change
    ; 2 = add 1
    inc temp_1
    jmp @var_done
@var_minus:
    lda temp_1
    beq @var_done                ; Don't go below 0
    dec temp_1
    jmp @var_done
@var_zero:
@var_done:

    ; Enforce minimum 1 damage
    lda temp_1
    bne @apply_hit
    lda #$01
    sta temp_1

@apply_hit:
    ; Monster hit sound
    lda #SFX_MONSTER_HIT
    jsr sfx_play
    ; Apply damage to player
    ldx temp_mon_idx
    lda player_hp
    sec
    sbc temp_1
    bcs @not_dead
    lda #$00
@not_dead:
    sta player_hp

    ; Flash at player position
    lda player_x
    sta flash_x
    lda player_y
    sta flash_y
    lda #$03
    sta flash_timer
    lda #$00
    sta flash_is_kill           ; Not a kill, restore player @ when done

    ; Build message: "The <name> hits you" (normal priority)
    lda #$01
    sta msg_new_priority
    jsr msg_start
    lda #<str_the
    sta ptr_lo
    lda #>str_the
    sta ptr_hi
    jsr msg_append
    ldx temp_mon_idx
    ldy mon_type, x
    jsr msg_append_monster_name
    lda #<str_hits_you
    sta ptr_lo
    lda #>str_hits_you
    sta ptr_hi
    jsr msg_append
    jsr msg_show_build

    rts

@mon_miss:
    ; Build message: "The <name> misses you" (normal priority)
    lda #$01
    sta msg_new_priority
    jsr msg_start
    lda #<str_the
    sta ptr_lo
    lda #>str_the
    sta ptr_hi
    jsr msg_append
    ldx temp_mon_idx
    ldy mon_type, x
    jsr msg_append_monster_name
    lda #<str_misses_you
    sta ptr_lo
    lda #>str_misses_you
    sta ptr_hi
    jsr msg_append
    jsr msg_show_build
    rts
.endproc

; ------------------------------------------------------------
; check_level_up
; Check if player has enough XP to level up.
; XP thresholds: 10, 20, 40, 80, 160...
; ------------------------------------------------------------
.proc check_level_up
    lda player_level
    cmp #12                     ; Max level
    bcs @done

    ; Calculate threshold: 10 * 2^(level-1)
    ; Simplified: use lookup table
    ldx player_level
    dex                         ; 0-based index
    cpx #$08
    bcs @done                   ; Safety check
    lda xp_thresholds, x
    cmp player_xp
    bcs @done                   ; Not enough XP

    ; Level up!
    inc player_level

    ; Increase max HP by 5 (flat, predictable)
    lda player_max_hp
    clc
    adc #$05
    bcc @hp_ok
    lda #$FF
@hp_ok:
    sta player_max_hp

    ; Fully heal
    lda player_max_hp
    sta player_hp

    ; Increase strength bonus by 1 every level
    lda player_str
    cmp #$FF
    bcs @str_ok
    inc player_str
@str_ok:

    ; Increase defense bonus by 1 every even level
    lda player_level
    and #$01                    ; Check if new level is even
    bne @def_ok                 ; Odd level — skip defense bump
    lda player_def
    cmp #$FF
    bcs @def_ok
    inc player_def
@def_ok:

    ; Increase agility by 2 every odd level
    lda player_level
    and #$01                    ; Check if new level is odd
    beq @agi_ok                 ; Even level — skip agility bump
    lda player_agi
    clc
    adc #$02
    bcc @agi_clamp
    lda #$FF
@agi_clamp:
    sta player_agi
@agi_ok:

    ; Show message (high priority)
    lda #$02
    sta msg_new_priority
    lda #<str_level_up
    sta ptr_lo
    lda #>str_level_up
    sta ptr_hi
    jsr msg_show

@done:
    rts
.endproc

; ============================================================
; XP threshold table
; ============================================================
.segment "RODATA"

xp_thresholds:
    .byte 10, 20, 40, 80, 160, 255, 255, 255    ; Levels 2-9+
