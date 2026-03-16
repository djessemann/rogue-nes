; ============================================================
; Map Rendering — Viewport-based dungeon map rendering
; Supports 64x48 map with 32x24 viewport (screen-flip scrolling)
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; map_draw_viewport
; Draw the current viewport (32x24 tiles) from camera_x/camera_y.
; Must be called with rendering disabled.
; Integrates fog of war: hidden=darkness, explored=dim, visible=normal.
; Also draws visible entities (player, monsters, items) on top.
; ------------------------------------------------------------
.proc map_draw_viewport
    lda $2002                   ; Reset PPU address latch

    ; Set PPU address to row 3 (MAP_TOP_ROW) of nametable 0
    ; Row 3 = $2000 + 3 * 32 = $2060
    lda #$20
    sta $2006
    lda #$60
    sta $2006

    ; Draw 24 rows x 32 cols from the viewport
    lda #$00
    sta temp_3                  ; Screen row counter (0..23)

@row_loop:
    lda temp_3
    cmp #VIEW_H
    beq @rows_done

    ; Compute map row = camera_y + screen_row
    lda camera_y
    clc
    adc temp_3
    jsr calc_row_offset         ; ptr_lo/ptr_hi = dungeon_map + map_row * 64

    ; Also compute fog row address
    ; fog_map base = dungeon_map + MAP_SIZE (they're adjacent in WRAM)
    lda ptr_lo
    clc
    adc #<(fog_map - dungeon_map)
    sta addr_temp_lo
    lda ptr_hi
    adc #>(fog_map - dungeon_map)
    sta addr_temp_hi

    ; Draw 32 tiles for this row
    ldy camera_x                ; Start column in map
    ldx #$00                    ; Screen column counter
@col_loop:
    cpx #VIEW_W
    beq @next_row

    ; Check fog state
    lda (addr_temp_lo), y       ; fog_map tile
    cmp #FOG_VISIBLE
    beq @draw_visible
    cmp #FOG_EXPLORED
    beq @draw_explored

    ; FOG_HIDDEN: draw darkness
    lda #CHR_DARKNESS
    sta $2007
    iny
    inx
    jmp @col_loop

@draw_explored:
    ; Show the tile structure (walls/floor visible)
    lda (ptr_lo), y
    jsr tile_to_chr
    sta $2007
    iny
    inx
    jmp @col_loop

@draw_visible:
    ; Visible tile (entities drawn separately afterward)
    lda (ptr_lo), y
    jsr tile_to_chr
    sta $2007
    iny
    inx
    jmp @col_loop

@next_row:
    inc temp_3
    jmp @row_loop

@rows_done:
    ; --- Draw visible entities on top ---
    jsr map_draw_player_direct
    jsr map_draw_monsters_direct
    jsr map_draw_items_direct

    ; --- Draw divider lines ---
    ; Row 2 divider
    lda $2002
    lda #$20
    sta $2006
    lda #$40                    ; Row 2 = $2000 + 2*32 = $2040
    sta $2006
    ldx #$20                    ; 32 tiles
    lda #CHR_DIVIDER
@div1:
    sta $2007
    dex
    bne @div1

    ; Row 27 divider
    lda $2002
    lda #$23
    sta $2006
    lda #$60                    ; Row 27 = $2000 + 27*32 = $2360
    sta $2006
    ldx #$20
    lda #CHR_DIVIDER
@div2:
    sta $2007
    dex
    bne @div2

    rts
.endproc

; ------------------------------------------------------------
; tile_to_chr
; Convert map tile type to CHR tile index for rendering.
; Input: A = tile type (TILE_*)
; Output: A = CHR tile index
; ------------------------------------------------------------
.proc tile_to_chr
    cmp #TILE_WALL
    beq @wall
    cmp #TILE_FLOOR
    beq @floor
    cmp #TILE_CORRIDOR
    beq @corridor
    cmp #TILE_DOOR_CLOSED
    beq @door_closed
    cmp #TILE_DOOR_OPEN
    beq @door_open
    cmp #TILE_STAIRS_UP
    beq @stairs_up
    cmp #TILE_STAIRS_DOWN
    beq @stairs_down
    ; Default: wall
    lda #CHR_WALL
    rts
@wall:
    lda #CHR_WALL
    rts
@floor:
    lda #CHR_FLOOR
    rts
@corridor:
    lda #CHR_CORRIDOR
    rts
@door_closed:
    lda #CHR_DOOR_CLOSED
    rts
@door_open:
    lda #CHR_DOOR_OPEN
    rts
@stairs_up:
    lda #CHR_STAIRS_UP
    rts
@stairs_down:
    lda #CHR_STAIRS_DOWN
    rts
.endproc

; ------------------------------------------------------------
; map_draw_player_direct
; Write player @ tile directly to PPU (rendering must be off).
; Uses camera offset to compute screen position.
; Only draws if player is within current viewport.
; ------------------------------------------------------------
.proc map_draw_player_direct
    ; Check if player is in viewport
    lda player_x
    sec
    sbc camera_x
    bcc @skip                   ; Off-screen left
    cmp #VIEW_W
    bcs @skip                   ; Off-screen right
    sta temp_4                  ; Screen X

    lda player_y
    sec
    sbc camera_y
    bcc @skip
    cmp #VIEW_H
    bcs @skip

    ; Screen Y + MAP_TOP_ROW
    clc
    adc #MAP_TOP_ROW
    sta temp_1
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_3                  ; PPU high byte

    lda temp_1
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_4
    sta temp_4                  ; PPU low byte
    bcc @no_carry
    inc temp_3
@no_carry:

    lda $2002
    lda temp_3
    sta $2006
    lda temp_4
    sta $2006
    lda #CHR_PLAYER
    sta $2007
@skip:
    rts
.endproc

; ------------------------------------------------------------
; map_draw_monsters_direct
; Write monster tiles directly to PPU.
; Only draws monsters within current viewport and on visible tiles.
; ------------------------------------------------------------
.proc map_draw_monsters_direct
    ldx #$00
@loop:
    cpx monster_count
    beq @done

    ; Skip dead monsters (hp = 0)
    lda mon_hp, x
    beq @next

    ; Check if monster is in viewport
    lda mon_x, x
    sec
    sbc camera_x
    bcc @next                   ; Off-screen
    cmp #VIEW_W
    bcs @next
    sta temp_4                  ; Screen X

    lda mon_y, x
    sec
    sbc camera_y
    bcc @next
    cmp #VIEW_H
    bcs @next

    ; Check fog at monster position — only draw if visible
    lda mon_y, x
    jsr fog_calc_offset         ; ptr_lo/ptr_hi = fog row; X preserved
    ldy mon_x, x
    lda (ptr_lo), y
    cmp #FOG_VISIBLE
    bne @next                   ; Not visible, skip drawing

    ; Get monster tile
    lda mon_type, x
    tay
    lda mon_chr_tile, y
    pha                         ; Save CHR tile

    ; Calculate PPU address
    lda mon_y, x
    sec
    sbc camera_y
    clc
    adc #MAP_TOP_ROW
    sta temp_1
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_3

    lda temp_1
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_4
    sta temp_4
    bcc @no_carry
    inc temp_3
@no_carry:

    lda $2002
    lda temp_3
    sta $2006
    lda temp_4
    sta $2006
    pla
    sta $2007

@next:
    inx
    jmp @loop
@done:
    rts
.endproc

; ------------------------------------------------------------
; map_draw_items_direct
; Write floor item tiles directly to PPU.
; Only draws items within viewport and on visible tiles.
; ------------------------------------------------------------
.proc map_draw_items_direct
    ldx #$00
@loop:
    cpx floor_item_count
    beq @done

    ; Check viewport bounds
    lda fi_x, x
    sec
    sbc camera_x
    bcc @next
    cmp #VIEW_W
    bcs @next
    sta temp_4                  ; Screen X

    lda fi_y, x
    sec
    sbc camera_y
    bcc @next
    cmp #VIEW_H
    bcs @next

    ; Check fog at item position — only draw if visible
    lda fi_y, x
    jsr fog_calc_offset         ; ptr_lo/ptr_hi = fog row; X preserved
    ldy fi_x, x
    lda (ptr_lo), y
    cmp #FOG_VISIBLE
    bne @next                   ; Not visible, skip drawing

    lda fi_type, x
    tay
    lda item_chr_tile, y
    pha

    ; PPU address
    lda fi_y, x
    sec
    sbc camera_y
    clc
    adc #MAP_TOP_ROW
    sta temp_1
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_3

    lda temp_1
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_4
    sta temp_4
    bcc @no_carry
    inc temp_3
@no_carry:

    lda $2002
    lda temp_3
    sta $2006
    lda temp_4
    sta $2006
    pla
    sta $2007

@next:
    inx
    jmp @loop
@done:
    rts
.endproc

; ------------------------------------------------------------
; map_update_entity
; Queue a VRAM buffer update for a single tile on the map.
; Applies camera offset; skips if tile is off-screen.
; Input: A = CHR tile to draw
;        temp_1 = map X (0-63)
;        temp_2 = map Y (0-47)
; ------------------------------------------------------------
.proc map_update_entity
    pha                         ; Save tile

    ; Convert map coords to screen coords
    lda temp_1
    sec
    sbc camera_x
    bcc @skip                   ; Off-screen
    cmp #VIEW_W
    bcs @skip
    sta temp_1                  ; Screen X

    lda temp_2
    sec
    sbc camera_y
    bcc @skip
    cmp #VIEW_H
    bcs @skip
    clc
    adc #MAP_TOP_ROW            ; Screen row = viewport row + 3
    sta temp_2

    pla
    jsr vram_write_tile
    rts

@skip:
    pla                         ; Balance stack
    rts
.endproc

; ------------------------------------------------------------
; map_restore_tile
; Restore the map tile at (X, Y) from the dungeon_map buffer.
; Uses camera offset; skips if off-screen.
; Input: temp_1 = map X, temp_2 = map Y
; ------------------------------------------------------------
.proc map_restore_tile
    ; First check if there's a floor item at this position
    jsr check_floor_item_chr
    bcs @write                  ; Carry set = found item, A = item CHR tile

    ; No item — read the base tile from dungeon_map and convert
    lda temp_2
    jsr calc_row_offset
    ldy temp_1
    lda (ptr_lo), y
    jsr tile_to_chr

@write:
    ; Convert to screen coords and write via VRAM buffer
    pha
    lda temp_1
    sec
    sbc camera_x
    bcc @skip
    cmp #VIEW_W
    bcs @skip
    sta temp_1

    lda temp_2
    sec
    sbc camera_y
    bcc @skip
    cmp #VIEW_H
    bcs @skip
    clc
    adc #MAP_TOP_ROW
    sta temp_2

    pla
    jsr vram_write_tile
    rts

@skip:
    pla
    rts
.endproc

; ------------------------------------------------------------
; check_floor_item_chr
; Check if there's a floor item at (temp_1, temp_2).
; Output: A = item CHR tile, carry set if found
;         carry clear if no item
; ------------------------------------------------------------
.proc check_floor_item_chr
    ldx #$00
@loop:
    cpx floor_item_count
    beq @not_found

    lda fi_x, x
    cmp temp_1
    bne @next
    lda fi_y, x
    cmp temp_2
    bne @next

    ; Found item
    lda fi_type, x
    tay
    lda item_chr_tile, y
    sec                         ; Set carry = found
    rts

@next:
    inx
    jmp @loop

@not_found:
    clc                         ; Clear carry = not found
    rts
.endproc

; ------------------------------------------------------------
; fog_calc_offset
; Calculate byte offset into fog_map for a given row.
; Input: A = row number (0-47)
; Output: ptr_lo/ptr_hi = address of fog_map + row * 64
; Preserves: X
; ------------------------------------------------------------
.proc fog_calc_offset
    ; row * 64 = row << 6  (same math as calc_row_offset)
    sta ptr_hi
    lda #$00
    sta ptr_lo

    lda ptr_hi
    asl a
    sta ptr_lo                  ; * 2
    lda #$00
    rol a
    sta ptr_hi

    asl ptr_lo                  ; * 4
    rol ptr_hi
    asl ptr_lo                  ; * 8
    rol ptr_hi
    asl ptr_lo                  ; * 16
    rol ptr_hi
    asl ptr_lo                  ; * 32
    rol ptr_hi
    asl ptr_lo                  ; * 64
    rol ptr_hi

    ; Add base address of fog_map
    lda ptr_lo
    clc
    adc #<fog_map
    sta ptr_lo
    lda ptr_hi
    adc #>fog_map
    sta ptr_hi
    rts
.endproc

; ------------------------------------------------------------
; fog_reveal_room
; Set all tiles in a room to FOG_VISIBLE.
; Input: X = room index
; Preserves: nothing
; ------------------------------------------------------------
.proc fog_reveal_room
    lda room_y, x
    sta temp_3                  ; Current row
    clc
    adc room_h, x
    sta temp_4                  ; End row

    stx temp_room_idx           ; Save room index

@row_loop:
    lda temp_3
    cmp temp_4
    beq @done

    lda temp_3
    jsr fog_calc_offset

    ; Add room_x offset to ptr
    ldx temp_room_idx
    lda room_x, x
    clc
    adc ptr_lo
    sta ptr_lo
    bcc @no_carry
    inc ptr_hi
@no_carry:

    ; Write FOG_VISIBLE for room width
    ldy #$00
    lda room_w, x
    sta temp_1
@col_loop:
    cpy temp_1
    beq @next_row
    lda #FOG_VISIBLE
    sta (ptr_lo), y
    iny
    jmp @col_loop

@next_row:
    inc temp_3
    jmp @row_loop

@done:
    ; Also reveal 1 tile border around the room for walls
    ; (so room edges are visible)
    ldx temp_room_idx
    jsr fog_reveal_room_border
    rts
.endproc

; ------------------------------------------------------------
; fog_reveal_room_border
; Reveal the 1-tile border around a room so walls are visible.
; Input: X = room index
; ------------------------------------------------------------
.proc fog_reveal_room_border
    ; Top row (room_y - 1)
    lda room_y, x
    beq @skip_top               ; Already at map edge
    sec
    sbc #$01
    sta temp_3

    lda temp_3
    jsr fog_calc_offset
    lda room_x, x
    beq @no_left_top
    sec
    sbc #$01
@no_left_top:
    clc
    adc ptr_lo
    sta ptr_lo
    bcc @nc1
    inc ptr_hi
@nc1:
    lda room_w, x
    clc
    adc #$02                    ; Width + 2 for border
    sta temp_1
    ldy #$00
@top_loop:
    cpy temp_1
    beq @skip_top
    lda (ptr_lo), y
    cmp #FOG_VISIBLE
    beq @top_next
    lda #FOG_VISIBLE
    sta (ptr_lo), y
@top_next:
    iny
    jmp @top_loop
@skip_top:

    ; Bottom row (room_y + room_h)
    lda room_y, x
    clc
    adc room_h, x
    cmp #MAP_H
    bcs @skip_bottom
    sta temp_3

    lda temp_3
    jsr fog_calc_offset
    lda room_x, x
    beq @no_left_bot
    sec
    sbc #$01
@no_left_bot:
    clc
    adc ptr_lo
    sta ptr_lo
    bcc @nc2
    inc ptr_hi
@nc2:
    lda room_w, x
    clc
    adc #$02
    sta temp_1
    ldy #$00
@bot_loop:
    cpy temp_1
    beq @skip_bottom
    lda (ptr_lo), y
    cmp #FOG_VISIBLE
    beq @bot_next
    lda #FOG_VISIBLE
    sta (ptr_lo), y
@bot_next:
    iny
    jmp @bot_loop
@skip_bottom:

    ; Left and right columns
    lda room_y, x
    beq @no_dec_y
    sec
    sbc #$01
@no_dec_y:
    sta temp_3                  ; Start row
    lda room_y, x
    clc
    adc room_h, x
    sta temp_4                  ; End row (exclusive, but we want inclusive + border)

@side_loop:
    lda temp_3
    cmp temp_4
    beq @sides_done

    lda temp_3
    jsr fog_calc_offset

    ; Left column (room_x - 1)
    lda room_x, x
    beq @no_left_side
    tay
    dey
    lda #FOG_VISIBLE
    sta (ptr_lo), y
@no_left_side:

    ; Right column (room_x + room_w)
    lda room_x, x
    clc
    adc room_w, x
    cmp #MAP_W
    bcs @no_right_side
    tay
    lda #FOG_VISIBLE
    sta (ptr_lo), y
@no_right_side:

    inc temp_3
    jmp @side_loop

@sides_done:
    rts
.endproc

; ------------------------------------------------------------
; fog_downgrade_room
; Downgrade all FOG_VISIBLE tiles in a room to FOG_EXPLORED.
; Input: X = room index
; ------------------------------------------------------------
.proc fog_downgrade_room
    lda room_y, x
    beq @start_at_zero
    sec
    sbc #$01                    ; Include border
@start_at_zero:
    sta temp_3
    lda room_y, x
    clc
    adc room_h, x
    clc
    adc #$01                    ; Include border
    cmp #MAP_H
    bcc @end_ok
    lda #MAP_H
@end_ok:
    sta temp_4

    stx temp_room_idx

@row_loop:
    lda temp_3
    cmp temp_4
    beq @done

    lda temp_3
    jsr fog_calc_offset

    ; Start column
    ldx temp_room_idx
    lda room_x, x
    beq @start_col_zero
    sec
    sbc #$01
@start_col_zero:
    tay                         ; Y = start column

    ; End column
    lda room_x, x
    clc
    adc room_w, x
    clc
    adc #$01
    cmp #MAP_W
    bcc @end_col_ok
    lda #MAP_W
@end_col_ok:
    sta temp_1                  ; End column

@col_loop:
    cpy temp_1
    beq @next_row
    lda (ptr_lo), y
    cmp #FOG_VISIBLE
    bne @col_next
    lda #FOG_EXPLORED
    sta (ptr_lo), y
@col_next:
    iny
    jmp @col_loop

@next_row:
    inc temp_3
    jmp @row_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; fog_reveal_around
; Reveal tiles in a small radius around the player (for corridors).
; Sets tiles within 1 step to FOG_VISIBLE.
; Input: player_x, player_y used directly
; ------------------------------------------------------------
.proc fog_reveal_around
    ; Reveal a 3x3 area centered on player
    lda player_y
    beq @start_y_zero
    sec
    sbc #$01
@start_y_zero:
    sta temp_3                  ; Start row

    lda player_y
    clc
    adc #$02                    ; End row (exclusive, player_y+2)
    cmp #MAP_H
    bcc @end_y_ok
    lda #MAP_H
@end_y_ok:
    sta temp_4

@row_loop:
    lda temp_3
    cmp temp_4
    beq @done

    lda temp_3
    jsr fog_calc_offset

    ; Start column
    lda player_x
    beq @start_x_zero
    sec
    sbc #$01
@start_x_zero:
    tay

    ; End column
    lda player_x
    clc
    adc #$02
    cmp #MAP_W
    bcc @end_x_ok
    lda #MAP_W
@end_x_ok:
    sta temp_1

@col_loop:
    cpy temp_1
    beq @next_row
    lda #FOG_VISIBLE
    sta (ptr_lo), y
    iny
    jmp @col_loop

@next_row:
    inc temp_3
    jmp @row_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; fog_clear_visible
; Downgrade all FOG_VISIBLE tiles around player's previous
; position to FOG_EXPLORED (for corridor movement).
; Input: temp_1 = old X, temp_2 = old Y
; ------------------------------------------------------------
.proc fog_clear_visible
    lda temp_2
    beq @start_y_zero
    sec
    sbc #$01
@start_y_zero:
    sta temp_3

    lda temp_2
    clc
    adc #$02
    cmp #MAP_H
    bcc @end_y_ok
    lda #MAP_H
@end_y_ok:
    sta temp_4

@row_loop:
    lda temp_3
    cmp temp_4
    beq @done

    lda temp_3
    jsr fog_calc_offset

    lda temp_1
    beq @start_x_zero
    pha
    sec
    sbc #$01
    tay
    pla
    jmp @do_cols
@start_x_zero:
    tay

@do_cols:
    lda temp_1
    clc
    adc #$02
    cmp #MAP_W
    bcc @end_x_ok
    lda #MAP_W
@end_x_ok:
    sta temp_room_idx           ; Reuse as end column

@col_loop:
    cpy temp_room_idx
    beq @next_row
    lda (ptr_lo), y
    cmp #FOG_VISIBLE
    bne @col_next
    lda #FOG_EXPLORED
    sta (ptr_lo), y
@col_next:
    iny
    jmp @col_loop

@next_row:
    inc temp_3
    jmp @row_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; fog_draw_around_vram
; Queue VRAM buffer writes for the 3x3 area around the player.
; Used for corridor fog reveals — draws fog-aware tiles.
; Clobbers: A, X, Y, all temps
; ------------------------------------------------------------
.proc fog_draw_around_vram
    ; Compute row range
    lda player_y
    beq @start_y_zero
    sec
    sbc #$01
@start_y_zero:
    sta addr_temp_lo            ; Current row (using addr_temp as loop vars)

    lda player_y
    clc
    adc #$02
    cmp #MAP_H
    bcc @end_y_ok
    lda #MAP_H
@end_y_ok:
    sta addr_temp_hi            ; End row

@row_loop:
    lda addr_temp_lo
    cmp addr_temp_hi
    beq @done

    ; Compute column range
    lda player_x
    beq @start_x_zero
    sec
    sbc #$01
@start_x_zero:
    sta temp_room_idx           ; Current col

    lda player_x
    clc
    adc #$02
    cmp #MAP_W
    bcc @end_x_ok
    lda #MAP_W
@end_x_ok:
    sta temp_mon_idx            ; End col

@col_loop:
    lda temp_room_idx
    cmp temp_mon_idx
    beq @next_row

    ; --- Check viewport bounds ---
    lda temp_room_idx
    sec
    sbc camera_x
    bcc @next_col               ; Off-screen left
    cmp #VIEW_W
    bcs @next_col               ; Off-screen right
    sta temp_1                  ; Screen X

    lda addr_temp_lo
    sec
    sbc camera_y
    bcc @next_col               ; Off-screen top
    cmp #VIEW_H
    bcs @next_col               ; Off-screen bottom
    clc
    adc #MAP_TOP_ROW
    sta temp_2                  ; Screen Y (with HUD offset)

    ; --- Get fog-aware CHR tile ---
    lda addr_temp_lo
    jsr fog_calc_offset
    ldy temp_room_idx
    lda (ptr_lo), y
    cmp #FOG_HIDDEN
    beq @draw_dark
    cmp #FOG_EXPLORED
    beq @draw_map_tile

    ; FOG_VISIBLE: draw map tile
@draw_map_tile:
    lda addr_temp_lo
    jsr calc_row_offset
    ldy temp_room_idx
    lda (ptr_lo), y
    jsr tile_to_chr
    jmp @write_tile

@draw_dark:
    lda #CHR_DARKNESS

@write_tile:
    ; Save loop counters (vram_write_tile clobbers temp_3/temp_4)
    pha                         ; Save CHR tile
    lda addr_temp_lo
    pha                         ; Save current row
    lda addr_temp_hi
    pha                         ; Save end row

    ; Restore CHR tile into A, temp_1/temp_2 already set
    ; Need to get A back from under two stack values
    ; Stack: end_row, cur_row, chr_tile (top)
    ; We need chr_tile in A
    tsx
    lda $0103, x                ; Read chr_tile from stack (3 deep: +1=end, +2=cur, +3=chr)
    jsr vram_write_tile

    ; Restore loop counters
    pla
    sta addr_temp_hi
    pla
    sta addr_temp_lo
    pla                         ; Discard saved CHR tile

@next_col:
    inc temp_room_idx
    jmp @col_loop

@next_row:
    inc addr_temp_lo
    jmp @row_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; find_player_room
; Find which room the player is currently in.
; Output: X = room index, carry set if found
;         carry clear if not in any room (corridor)
; Sets player_current_room.
; ------------------------------------------------------------
.proc find_player_room
    ldx #$00
@loop:
    cpx room_count
    beq @not_in_room

    ; Check X bounds
    lda player_x
    cmp room_x, x
    bcc @next
    sec
    sbc room_x, x
    cmp room_w, x
    bcs @next

    ; Check Y bounds
    lda player_y
    cmp room_y, x
    bcc @next
    sec
    sbc room_y, x
    cmp room_h, x
    bcs @next

    ; Found room X
    stx player_current_room
    sec
    rts

@next:
    inx
    jmp @loop

@not_in_room:
    lda #$FF
    sta player_current_room
    clc
    rts
.endproc
