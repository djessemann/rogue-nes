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
    ; Decrease hunger every turn
    lda player_hunger
    beq @starving               ; Already at 0

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

; ------------------------------------------------------------
; status_update
; Decrement status effect timers each turn.
; Called once per player turn.
; ------------------------------------------------------------
.proc status_update
    ; --- Confusion timer ---
    lda confuse_timer
    beq @check_blind
    dec confuse_timer
    bne @check_blind
    ; Timer just hit 0 — clear confusion
    lda player_status
    and #<~STATUS_CONFUSED
    sta player_status
    lda #<str_unconfused
    sta ptr_lo
    lda #>str_unconfused
    sta ptr_hi
    jsr msg_show

@check_blind:
    lda blind_timer
    beq @done
    dec blind_timer
    bne @done
    ; Timer just hit 0 — clear blindness and restore vision
    lda player_status
    and #<~STATUS_BLIND
    sta player_status
    lda #<str_unblinded
    sta ptr_lo
    lda #>str_unblinded
    sta ptr_hi
    jsr msg_show
    ; Restore fog visibility
    jsr update_fog
    lda #$01
    sta screen_flip

@done:
    rts
.endproc
