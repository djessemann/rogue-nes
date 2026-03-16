; ============================================================
; Combat System — Attack resolution, damage, XP
; Classic Rogue d20 system with named monster messages
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; player_attack_monster
; Player attacks monster at index X.
; Uses d20 system from game mechanics.
; Input: X = monster index (also in temp_mon_idx)
; ------------------------------------------------------------
.proc player_attack_monster
    ldx temp_mon_idx

    ; Roll d20
    lda #D20_SIDES
    jsr rng_range               ; 0-19
    clc
    adc #$01                    ; 1-20

    ; Add player level
    clc
    adc player_level

    ; Add weapon bonus (start with +1 mace)
    clc
    adc #$01                    ; TODO: read from equipped weapon

    ; Compare against monster armor
    ldx temp_mon_idx
    ldy mon_type, x
    cmp mon_armor, y
    bcs @hit                    ; Roll >= armor = hit
    jmp @miss
@hit:

    ; --- HIT ---
    ; Calculate damage: 1d8 + 1 (enchanted +1 mace, classic Rogue)
    lda #$08
    jsr rng_range               ; 0-7
    clc
    adc #$01                    ; 1-8

    ; Add mace enchantment bonus (+1,+1 in classic Rogue)
    clc
    adc #$01                    ; +1 damage bonus

    ; Apply damage
    ldx temp_mon_idx
    sta temp_1                  ; Damage amount
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
; ------------------------------------------------------------
.proc monster_attack_player
    ldx temp_mon_idx

    ; Roll d20
    lda #D20_SIDES
    jsr rng_range
    clc
    adc #$01                    ; 1-20

    ; Add monster level
    ldy mon_type, x
    clc
    adc mon_level, y

    ; Compare against player defense
    cmp player_def
    bcc @miss

    ; --- HIT ---
    ; Look up monster damage
    ldx temp_mon_idx
    ldy mon_type, x
    lda mon_damage, y           ; Max damage for this type
    jsr rng_range               ; 0 to max-1
    clc
    adc #$01                    ; 1 to max

    ; Apply damage to player
    sta temp_1
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

@miss:
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

    ; Increase max HP by 2-9
    lda #$08
    jsr rng_range               ; 0-7
    clc
    adc #$02                    ; 2-9
    clc
    adc player_max_hp
    bcc @hp_ok
    lda #$FF
@hp_ok:
    sta player_max_hp

    ; Fully heal
    lda player_max_hp
    sta player_hp

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
