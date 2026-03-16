; ============================================================
; Hunger System
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; hunger_update
; Decrease hunger counter each turn. Handle starvation.
; Called once per player turn.
; ------------------------------------------------------------
.proc hunger_update
    ; Decrease hunger every other turn (doubles duration)
    lda player_hunger
    beq @starving               ; Already at 0

    lda turn_counter
    and #$01
    bne @done                   ; Skip odd turns

    lda player_hunger
    sec
    sbc #$01
    sta player_hunger

    ; Check hunger thresholds for messages
    cmp #HUNGER_HUNGRY
    bne @check_weak
    ; Just crossed hungry threshold
    lda #<str_hungry
    sta ptr_lo
    lda #>str_hungry
    sta ptr_hi
    jsr msg_show
    rts

@check_weak:
    lda player_hunger
    cmp #HUNGER_WEAK
    bne @done
    lda #<str_weak
    sta ptr_lo
    lda #>str_weak
    sta ptr_hi
    jsr msg_show
    rts

@starving:
    ; Lose 1 HP per turn when starving
    lda player_hp
    beq @done                   ; Already dead
    dec player_hp

    ; Show starving message (only occasionally to avoid spam)
    lda frame_counter
    and #$0F                    ; Every 16 frames
    bne @done
    lda #<str_starving
    sta ptr_lo
    lda #>str_starving
    sta ptr_hi
    jsr msg_show

@done:
    rts
.endproc
