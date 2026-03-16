; ============================================================
; Random Number Generator — 16-bit Galois LFSR
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; rng_next
; Advance the LFSR and return a pseudo-random byte in A.
; Uses primitive polynomial x^16 + x^15 + x^13 + x^4 + 1
; Mask = $A010 (bits 15, 13, 4) — maximal period of 65535.
; ------------------------------------------------------------
.proc rng_next
    ; If seed is 0, force to 1 (LFSR can't escape 0)
    lda rng_seed_lo
    ora rng_seed_hi
    bne @not_zero
    lda #$01
    sta rng_seed_lo
@not_zero:

    ; Shift right, XOR with taps if carry set
    lsr rng_seed_hi
    ror rng_seed_lo
    bcc @no_tap
    ; XOR with polynomial mask $A010
    lda rng_seed_hi
    eor #$A0
    sta rng_seed_hi
    lda rng_seed_lo
    eor #$10
    sta rng_seed_lo
@no_tap:
    lda rng_seed_lo             ; Return low byte as random value
    rts
.endproc

; ------------------------------------------------------------
; rng_range
; Return a random number in range 0..A-1.
; Input: A = max (exclusive). Must be 1-255.
; Output: A = random value in [0, max)
; Clobbers: temp_1
;
; Uses rejection sampling for uniform distribution.
; Guard: if max <= 1, return 0 immediately (avoids infinite loop).
; ------------------------------------------------------------
.proc rng_range
    cmp #$02
    bcs @normal
    ; max is 0 or 1 — only valid result is 0
    lda #$00
    rts
@normal:
    sta temp_1                  ; Save max
@retry:
    jsr rng_next
    cmp temp_1
    bcs @retry                  ; If >= max, try again (simple rejection)
    rts
.endproc
