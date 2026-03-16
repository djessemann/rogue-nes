; ============================================================
; Dungeon Generation — 6x6 room grid with corridors
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; dungeon_generate
; Generate a new dungeon level into the map buffer.
; Places rooms, corridors, stairs, monsters, and items.
; Clobbers: A, X, Y, all temps
; ------------------------------------------------------------
.proc dungeon_generate
    ; Clear map to walls (3072 bytes via pointer loop)
    lda #<dungeon_map
    sta ptr_lo
    lda #>dungeon_map
    sta ptr_hi
    ldy #$00
    lda #TILE_WALL
@clear:
    sta (ptr_lo), y
    iny
    bne @clear
    inc ptr_hi
    ldx ptr_hi
    cpx #>(dungeon_map + MAP_SIZE)
    bne @clear
    ; Check low byte boundary too (3072 = $C00, so low wraps to $00)
    ; dungeon_map is at $6000, end is at $6C00
    ; ptr_hi reaches $6C when done — the cpx above handles it

    ; Clear fog map to FOG_HIDDEN
    lda #<fog_map
    sta ptr_lo
    lda #>fog_map
    sta ptr_hi
    ldy #$00
    lda #FOG_HIDDEN
@clear_fog:
    sta (ptr_lo), y
    iny
    bne @clear_fog
    inc ptr_hi
    ldx ptr_hi
    cpx #>(fog_map + MAP_SIZE)
    bne @clear_fog

    ; Clear room count
    lda #$00
    sta room_count

    ; Clear monster/item counts
    sta monster_count
    sta floor_item_count

    ; --- Generate rooms in 6x6 grid ---
    lda #$00
    sta temp_grid_y             ; Grid row (0-5)
@grid_row:
    lda temp_grid_y
    cmp #GRID_ROWS
    beq @rooms_done

    lda #$00
    sta temp_grid_x             ; Grid column (0-2)
@grid_col:
    lda temp_grid_x
    cmp #GRID_COLS
    beq @next_row

    ; Decide if this cell gets a room (75% chance)
    jsr rng_next
    cmp #ROOM_CHANCE
    bcs @skip_room

    ; Room count check
    lda room_count
    cmp #MAX_ROOMS
    beq @skip_room

    jsr generate_room
    jmp @next_col

@skip_room:
@next_col:
    inc temp_grid_x
    jmp @grid_col

@next_row:
    inc temp_grid_y
    jmp @grid_row

@rooms_done:
    ; Ensure minimum room count
    lda room_count
    cmp #MIN_ROOMS
    bcs @enough_rooms
    ; Force-generate rooms in empty cells
    jsr force_more_rooms

@enough_rooms:
    ; --- Connect rooms with corridors ---
    jsr connect_rooms

    ; --- Place stairs ---
    jsr place_stairs

    ; --- Place player in starting room ---
    jsr place_player

    ; --- Spawn monsters ---
    jsr spawn_monsters

    ; --- Spawn items (gold, food) --- DISABLED for testing
    ; jsr spawn_items

    rts
.endproc

; ------------------------------------------------------------
; generate_room
; Create a room in grid cell (temp_grid_x, temp_grid_y).
; Stores room data in room_x/y/w/h arrays.
; ------------------------------------------------------------
.proc generate_room
    ldx room_count

    ; Calculate cell origin in map coords and store directly in room arrays
    ; Cell X = grid_x * CELL_W + 1
    lda temp_grid_x
    asl a                       ; * 2
    sta temp_1
    asl a                       ; * 4
    asl a                       ; * 8
    clc
    adc temp_1                  ; * 10
    clc
    adc #$01                    ; 1-tile border
    sta room_x, x              ; Store cell X origin in room_x (safe from rng_range)

    ; Cell Y = grid_y * CELL_H
    lda temp_grid_y
    asl a                       ; * 2
    asl a                       ; * 4
    asl a                       ; * 8
    sta room_y, x              ; Store cell Y origin in room_y (safe from rng_range)

    ; Random room size within cell (rng_range clobbers temp_1)
    lda #MAX_ROOM_W
    sec
    sbc #MIN_ROOM_W
    clc
    adc #$01                    ; Range
    jsr rng_range
    clc
    adc #MIN_ROOM_W
    sta room_w, x               ; Width

    lda #MAX_ROOM_H
    sec
    sbc #MIN_ROOM_H
    clc
    adc #$01
    jsr rng_range
    clc
    adc #MIN_ROOM_H
    sta room_h, x               ; Height

    ; Random offset within cell (ensure room fits)
    ; Max offset X = CELL_W - room_w
    lda #CELL_W
    sec
    sbc room_w, x
    beq @no_offset_x
    jsr rng_range
@no_offset_x:
    clc
    adc room_x, x              ; Add offset to cell origin
    sta room_x, x               ; Room X in map coords

    ; Max offset Y = CELL_H - room_h
    lda #CELL_H
    sec
    sbc room_h, x
    beq @no_offset_y
    jsr rng_range
@no_offset_y:
    clc
    adc room_y, x              ; Add offset to cell origin
    sta room_y, x               ; Room Y in map coords

    ; Clamp to full map bounds
    lda room_x, x
    clc
    adc room_w, x
    cmp #MAP_W
    bcc @x_ok
    lda #MAP_W
    sec
    sbc room_x, x
    sec
    sbc #$01
    sta room_w, x
@x_ok:
    lda room_y, x
    clc
    adc room_h, x
    cmp #MAP_H
    bcc @y_ok
    lda #MAP_H
    sec
    sbc room_y, x
    sec
    sbc #$01
    sta room_h, x
@y_ok:

    ; Carve room into map (floor tiles)
    jsr carve_room

    inc room_count
    rts
.endproc

; ------------------------------------------------------------
; carve_room
; Write floor tiles for room at index X into dungeon_map.
; Input: X = room index
; ------------------------------------------------------------
.proc carve_room
    ; Room bounds
    lda room_y, x
    sta temp_3                  ; Current row
    clc
    adc room_h, x
    sta temp_4                  ; End row (exclusive)

@row_loop:
    lda temp_3
    cmp temp_4
    beq @done

    ; Calculate map offset for start of this row: row * 32 + room_x
    lda temp_3
    jsr calc_row_offset         ; Returns offset in ptr_lo/ptr_hi

    lda room_x, x
    clc
    adc ptr_lo
    sta ptr_lo
    bcc @no_carry
    inc ptr_hi
@no_carry:

    ; Write floor tiles for this row
    ldy #$00
    lda room_w, x
    sta temp_1                  ; Width counter
@col_loop:
    cpy temp_1
    beq @next_row
    lda #TILE_FLOOR
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
; calc_row_offset
; Calculate byte offset into dungeon_map for a given row.
; Input: A = row number (0-23)
; Output: ptr_lo/ptr_hi = address of dungeon_map + row * 32
; Preserves: X
; ------------------------------------------------------------
.proc calc_row_offset
    ; row * 64 = row << 6
    sta ptr_hi
    lda #$00
    sta ptr_lo

    ; Multiply by 64: shift left 6 times
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

    ; Add base address of dungeon_map
    lda ptr_lo
    clc
    adc #<dungeon_map
    sta ptr_lo
    lda ptr_hi
    adc #>dungeon_map
    sta ptr_hi
    rts
.endproc

; ------------------------------------------------------------
; connect_rooms
; Connect adjacent rooms with L-shaped corridors.
; For each pair of rooms in adjacent grid cells, dig a corridor.
; ------------------------------------------------------------
.proc connect_rooms
    ; Simple approach: connect room i to room i+1 for all rooms
    ldx #$00
@loop:
    inx
    cpx room_count
    beq @done

    ; Connect room X-1 to room X
    dex
    stx temp_connect_a
    inx
    stx temp_connect_b

    jsr dig_corridor

    ldx temp_connect_b          ; Restore X (dig_corridor clobbers it)
    jmp @loop
@done:
    ; Also connect first and last for loop connectivity if > 3 rooms
    lda room_count
    cmp #$04
    bcc @no_loop
    lda #$00
    sta temp_connect_a
    lda room_count
    sec
    sbc #$01
    sta temp_connect_b
    jsr dig_corridor
@no_loop:
    rts
.endproc

; ------------------------------------------------------------
; dig_corridor
; Dig an L-shaped corridor between two rooms.
; Input: temp_connect_a = room index A, temp_connect_b = room index B
; ------------------------------------------------------------
.proc dig_corridor
    ; Get center of room A
    ldx temp_connect_a
    lda room_x, x
    clc
    lda room_w, x
    lsr a
    clc
    adc room_x, x
    sta temp_cor_x1             ; Center X of room A

    lda room_h, x
    lsr a
    clc
    adc room_y, x
    sta temp_cor_y1             ; Center Y of room A

    ; Get center of room B
    ldx temp_connect_b
    lda room_w, x
    lsr a
    clc
    adc room_x, x
    sta temp_cor_x2             ; Center X of room B

    lda room_h, x
    lsr a
    clc
    adc room_y, x
    sta temp_cor_y2             ; Center Y of room B

    ; Dig horizontal from x1 to x2 at y1
    lda temp_cor_x1
    sta temp_dig_x
    lda temp_cor_y1
    sta temp_dig_y
@horiz:
    jsr dig_tile
    lda temp_dig_x
    cmp temp_cor_x2
    beq @vert
    bcc @move_right
    dec temp_dig_x
    jmp @horiz
@move_right:
    inc temp_dig_x
    jmp @horiz

@vert:
    ; Dig vertical from y1 to y2 at x2
    lda temp_cor_y1
    sta temp_dig_y
@vert_loop:
    jsr dig_tile
    lda temp_dig_y
    cmp temp_cor_y2
    beq @done
    bcc @move_down
    dec temp_dig_y
    jmp @vert_loop
@move_down:
    inc temp_dig_y
    jmp @vert_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; dig_tile
; Set a map tile to corridor if it's currently a wall.
; Input: temp_dig_x, temp_dig_y
; ------------------------------------------------------------
.proc dig_tile
    ; Bounds check against full map dimensions
    lda temp_dig_x
    cmp #MAP_W
    bcs @skip
    lda temp_dig_y
    cmp #MAP_H
    bcs @skip

    ; Calculate offset
    lda temp_dig_y
    jsr calc_row_offset

    ldy temp_dig_x
    lda (ptr_lo), y
    cmp #TILE_WALL
    bne @skip                   ; Don't overwrite floor/door/stairs
    lda #TILE_CORRIDOR
    sta (ptr_lo), y
@skip:
    rts
.endproc

; ------------------------------------------------------------
; place_stairs
; Place stairs up in room 0, stairs down in last room.
; ------------------------------------------------------------
.proc place_stairs
    ; Stairs up in room 0 (except on level 0)
    lda dungeon_level
    beq @no_stairs_up

    ldx #$00
    lda room_y, x
    clc
    adc #$01
    jsr calc_row_offset
    ldy room_x
    iny                         ; 1 tile into room
    lda #TILE_STAIRS_UP
    sta (ptr_lo), y

@no_stairs_up:
    ; Stairs down in last room (except on last level)
    lda dungeon_level
    cmp #MAX_DUNGEON_LEVEL
    bcs @no_stairs_down

    ldx room_count
    dex                         ; Last room index
    lda room_y, x
    clc
    adc #$01
    jsr calc_row_offset
    lda room_x, x
    clc
    adc #$01
    tay
    lda #TILE_STAIRS_DOWN
    sta (ptr_lo), y

@no_stairs_down:
    rts
.endproc

; ------------------------------------------------------------
; place_player
; Place player @ in room 0 center.
; ------------------------------------------------------------
.proc place_player
    ldx #$00
    lda room_w, x
    lsr a
    clc
    adc room_x, x
    sta player_x

    lda room_h, x
    lsr a
    clc
    adc room_y, x
    sta player_y
    rts
.endproc

; ------------------------------------------------------------
; force_more_rooms
; Ensure minimum room count by filling empty grid cells.
; ------------------------------------------------------------
.proc force_more_rooms
    lda #$00
    sta temp_grid_y
@row:
    lda temp_grid_y
    cmp #GRID_ROWS
    beq @done

    lda #$00
    sta temp_grid_x
@col:
    lda temp_grid_x
    cmp #GRID_COLS
    beq @next_row

    ; Check if we have enough rooms
    lda room_count
    cmp #MIN_ROOMS
    bcs @done

    ; Check if this cell already has a room (simplistic: just add more)
    jsr generate_room

@next_col:
    inc temp_grid_x
    jmp @col
@next_row:
    inc temp_grid_y
    jmp @row
@done:
    rts
.endproc

; ------------------------------------------------------------
; spawn_monsters
; Place initial monsters in rooms (skip room 0 = player start).
; ------------------------------------------------------------
.proc spawn_monsters
    ldx #$01                    ; Start from room 1
@room_loop:
    cpx room_count
    beq @done

    stx temp_room_idx

    ; 60% chance of monster per room
    jsr rng_next
    cmp #153                    ; ~60% of 256
    bcs @skip

    ; Don't exceed max
    lda monster_count
    cmp #MAX_MONSTERS
    beq @done

    ; Pick monster type based on dungeon level
    jsr pick_monster_type       ; Returns type in A

    ; Place in room center
    ldx temp_room_idx
    stx temp_1                  ; Save room index for position calc

    ldx monster_count

    ; Store monster type
    sta mon_type, x

    ; Position: center of room
    ldy temp_1                  ; Room index
    lda room_w, y
    lsr a
    clc
    adc room_x, y
    sta mon_x, x

    lda room_h, y
    lsr a
    clc
    adc room_y, y
    sta mon_y, x

    ; HP from type table
    stx temp_2                  ; Save monster index
    ldy mon_type, x
    lda mon_base_hp, y
    sta temp_3
    ; Roll HP dice: base_hp is max of 1d(base_hp)
    lda temp_3
    jsr rng_range
    clc
    adc #$01                    ; 1 to base_hp
    ldx temp_2
    sta mon_hp, x

    ; Set flags based on type
    ldy mon_type, x
    lda mon_base_flags, y
    sta mon_flags, x

    ; State: sleeping unless aggressive
    lda #$00
    sta mon_state, x
    lda mon_flags, x
    and #MFLAG_AGGRESSIVE
    beq @not_mean
    lda #MFLAG_AWAKE
    ora mon_flags, x
    sta mon_flags, x
@not_mean:

    inc monster_count

@skip:
    ldx temp_room_idx
    inx
    jmp @room_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; pick_monster_type
; Return a monster type appropriate for current dungeon level.
; Output: A = monster type index
; ------------------------------------------------------------
.proc pick_monster_type
    ; Simple: weight toward harder monsters on deeper levels
    ; Phase 1: 5 monster types (0-4)
    lda #$05
    jsr rng_range               ; 0-4
    rts
.endproc

; ------------------------------------------------------------
; spawn_items
; Place gold and food in rooms.
; ------------------------------------------------------------
.proc spawn_items
    ldx #$00                    ; Room index
@room_loop:
    cpx room_count
    bne @not_done_1
    jmp @done
@not_done_1:
    stx temp_room_idx

    ; 50% chance of gold per room
    jsr rng_next
    cmp #128
    bcs @no_gold

    lda floor_item_count
    cmp #MAX_FLOOR_ITEMS
    bne @not_full
    jmp @done
@not_full:

    ldx floor_item_count
    lda #ITEM_GOLD
    sta fi_type, x

    ; Random position in room
    ldy temp_room_idx
    lda room_w, y
    sec
    sbc #$02                    ; Avoid walls
    jsr rng_range
    clc
    adc #$01
    clc
    ldy temp_room_idx
    adc room_x, y
    ldx floor_item_count
    sta fi_x, x

    ldy temp_room_idx
    lda room_h, y
    sec
    sbc #$02
    jsr rng_range
    clc
    adc #$01
    clc
    ldy temp_room_idx
    adc room_y, y
    ldx floor_item_count
    sta fi_y, x

    ; Random gold amount (5-25)
    lda #21
    jsr rng_range
    clc
    adc #$05
    ldx floor_item_count
    sta fi_mod, x

    inc floor_item_count

@no_gold:
    ; 15% chance of food per room
    jsr rng_next
    cmp #38                     ; ~15% of 256
    bcs @no_food

    lda floor_item_count
    cmp #MAX_FLOOR_ITEMS
    beq @done

    ldx floor_item_count
    lda #ITEM_FOOD
    sta fi_type, x

    ldy temp_room_idx
    lda room_w, y
    sec
    sbc #$02
    jsr rng_range
    clc
    adc #$01
    clc
    ldy temp_room_idx
    adc room_x, y
    ldx floor_item_count
    sta fi_x, x

    ldy temp_room_idx
    lda room_h, y
    sec
    sbc #$02
    jsr rng_range
    clc
    adc #$01
    clc
    ldy temp_room_idx
    adc room_y, y
    ldx floor_item_count
    sta fi_y, x

    lda #$00                    ; Food has no modifier
    ldx floor_item_count
    sta fi_mod, x

    inc floor_item_count

@no_food:
    ldx temp_room_idx
    inx
    jmp @room_loop

@done:
    rts
.endproc

