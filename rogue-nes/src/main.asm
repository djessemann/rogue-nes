; ============================================================
; ROGUE NES — Main Entry Point
; A roguelike dungeon crawler for the NES
; ============================================================

; Include constants first (used by all modules)
.include "constants.asm"

; ============================================================
; Zero Page Variables ($0000-$00FF) — Fast access
; ============================================================
.segment "ZEROPAGE"

; --- NMI synchronization ---
nmi_ready:          .res 1      ; Set by NMI, cleared by main loop

; --- Game state ---
game_state:         .res 1      ; Current STATE_* value
state_initialized:  .res 1      ; 0 = needs init, 1 = running
frame_counter:      .res 1      ; Increments every frame
dungeon_level:      .res 1      ; Current floor (0-based)
turn_taken:         .res 1      ; 1 if player acted this frame
turn_counter:       .res 1      ; Increments each player turn
stairs_direction:   .res 1      ; 0 = down, 1 = up

; --- Input ---
buttons:            .res 1      ; Current controller state
buttons_prev:       .res 1      ; Previous frame state
buttons_new:        .res 1      ; Newly pressed this frame

; --- PPU shadow registers ---
ppu_ctrl:           .res 1      ; Shadow of $2000
ppu_mask:           .res 1      ; Shadow of $2001
ppu_scroll_x:       .res 1      ; Horizontal scroll
ppu_scroll_y:       .res 1      ; Vertical scroll

; --- General temps ---
temp_1:             .res 1
temp_2:             .res 1
temp_3:             .res 1
temp_4:             .res 1
ptr_lo:             .res 1      ; 16-bit pointer (low)
ptr_hi:             .res 1      ; 16-bit pointer (high)
addr_temp_lo:       .res 1      ; Secondary pointer
addr_temp_hi:       .res 1

; --- Player ---
player_x:           .res 1      ; Map tile X (0-31)
player_y:           .res 1      ; Map tile Y (0-23)
player_hp:          .res 1      ; Current HP
player_max_hp:      .res 1      ; Maximum HP
player_str:         .res 1      ; Strength
player_def:         .res 1      ; Defense
player_gold:        .res 1      ; Gold (0-255)
player_level:       .res 1      ; Character level
player_xp:          .res 1      ; Experience points
player_hunger:      .res 1      ; Hunger counter
player_status:      .res 1      ; Status effect flags

; --- Movement ---
move_dx:            .res 1      ; Desired X delta (-1, 0, 1)
move_dy:            .res 1      ; Desired Y delta (-1, 0, 1)
target_x:           .res 1      ; Target tile X
target_y:           .res 1      ; Target tile Y
temp_move:          .res 1      ; Saved button state for movement

; --- RNG ---
rng_seed_lo:        .res 1
rng_seed_hi:        .res 1

; --- VRAM buffer ---
vram_buf_len:       .res 1      ; Current length of VRAM buffer

; --- Dungeon generation temps ---
temp_grid_x:        .res 1
temp_grid_y:        .res 1
room_count:         .res 1
temp_connect_a:     .res 1
temp_connect_b:     .res 1
temp_cor_x1:        .res 1
temp_cor_y1:        .res 1
temp_cor_x2:        .res 1
temp_cor_y2:        .res 1
temp_dig_x:         .res 1
temp_dig_y:         .res 1
temp_room_idx:      .res 1

; --- Monster temps ---
temp_mon_idx:       .res 1
monster_count:      .res 1
floor_item_count:   .res 1

; --- Message system ---
msg_new_lo:         .res 1
msg_new_hi:         .res 1
msg_new_priority:   .res 1      ; Priority of next msg_show call
msg_turn_priority:  .res 1      ; Highest priority msg shown this turn
msg_dirty:          .res 1      ; 1 = msg_buf needs VRAM write

; --- Deferred rendering ---
hud_dirty:          .res 1      ; 1 = HUD needs update next frame

; --- Viewport / Camera ---
camera_x:           .res 1      ; Viewport top-left tile X (0 or 32)
camera_y:           .res 1      ; Viewport top-left tile Y (0 or 24)
screen_flip:        .res 1      ; Nonzero = need full screen redraw

; --- Fog of war ---
player_current_room: .res 1     ; Room index player is in ($FF = corridor)
player_prev_room:    .res 1     ; Previous room (for downgrading visibility)

; --- Hit flash (per-tile) ---
flash_timer:         .res 1     ; Frames remaining for flash (0 = off)
flash_x:             .res 1     ; Map X of flash tile
flash_y:             .res 1     ; Map Y of flash tile
flash_is_kill:       .res 1     ; 1 = dead monster (restore floor), 0 = alive (restore entity)

; ============================================================
; OAM Shadow Buffer ($0200-$02FF)
; ============================================================
.segment "OAM"
oam_buf:            .res 256

; ============================================================
; WRAM — Battery-backed RAM ($6000-$7FFF)
; ============================================================
.segment "WRAM"
dungeon_map:        .res MAP_SIZE   ; 3072 bytes (64x48)
fog_map:            .res MAP_SIZE   ; 3072 bytes visibility data

; ============================================================
; BSS — General RAM ($0300-$07FF)
; ============================================================
.segment "BSS"

; --- Room data (9 rooms max) ---
room_x:             .res MAX_ROOMS
room_y:             .res MAX_ROOMS
room_w:             .res MAX_ROOMS
room_h:             .res MAX_ROOMS

; --- Monster data (struct-of-arrays, 10 max) ---
mon_x:              .res MAX_MONSTERS
mon_y:              .res MAX_MONSTERS
mon_type:           .res MAX_MONSTERS
mon_hp:             .res MAX_MONSTERS
mon_flags:          .res MAX_MONSTERS
mon_state:          .res MAX_MONSTERS

; --- Floor items (16 max) ---
fi_x:               .res MAX_FLOOR_ITEMS
fi_y:               .res MAX_FLOOR_ITEMS
fi_type:            .res MAX_FLOOR_ITEMS
fi_mod:             .res MAX_FLOOR_ITEMS

; --- VRAM buffer (shared with NMI) ---
vram_buf:           .res 256

; --- Message buffer ---
msg_buf:            .res 32         ; Most recent message
msg_buf_old:        .res 32         ; Previous message (one older)
msg_build:          .res 32         ; Temp buffer for building dynamic messages
msg_build_pos:      .res 1          ; Current write position in msg_build

; ============================================================
; Code Includes
; ============================================================
.segment "CODE"

; Include all modules
.include "reset.asm"
.include "nmi.asm"
.include "ppu.asm"
.include "input.asm"
.include "rng.asm"
.include "gamestate.asm"
.include "dungeon.asm"
.include "map.asm"
.include "player.asm"
.include "monsters.asm"
.include "combat.asm"
.include "hud.asm"
.include "messages.asm"
.include "hunger.asm"

; Include data
.include "data/palettes.asm"
.include "data/monsters.asm"
.include "data/strings.asm"
.include "data/chr.asm"

; ============================================================
; Main — Game initialization and main loop
; ============================================================
.segment "CODE"

.proc main
    ; PPU init: NMI on, BG pattern table 0, sprite pattern table 1
    lda #%10001000
    sta ppu_ctrl
    sta $2000

    ; Reset scroll
    lda #$00
    sta ppu_scroll_x
    sta ppu_scroll_y

    ; Init game state
    lda #STATE_TITLE
    sta game_state
    lda #$00
    sta state_initialized
    sta vram_buf_len

    ; Init RNG with a non-zero seed
    lda #$42
    sta rng_seed_lo
    lda #$7E
    sta rng_seed_hi

@loop:
    ; Wait for NMI (vblank sync)
    lda #$00
    sta nmi_ready
@wait_nmi:
    lda nmi_ready
    beq @wait_nmi

    ; Tick frame counter
    inc frame_counter

    ; Read controller
    jsr read_controller

    ; Game state dispatch
    jsr state_dispatch

    jmp @loop
.endproc

; ============================================================
; Interrupt Vectors
; ============================================================
.segment "VECTORS"
    .word nmi_handler           ; NMI vector (vblank)
    .word reset                 ; Reset vector
    .word $0000                 ; IRQ vector (unused)

; ============================================================
; iNES Header
; ============================================================
.include "header.asm"
