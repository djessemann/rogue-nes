; ============================================================
; Constants — All tunable game parameters
; ============================================================

; --- Map Dimensions ---
MAP_W           = 64            ; Full map width in tiles
MAP_H           = 48            ; Full map height in tiles
MAP_SIZE        = MAP_W * MAP_H ; 3072 bytes
VIEW_W          = 32            ; Viewport width (one screen)
VIEW_H          = 24            ; Viewport height (one screen)

; --- Screen Layout ---
MAP_TOP_ROW     = 3             ; First tile row of dungeon on screen
MAP_ROWS        = VIEW_H       ; Visible map rows on screen
MAP_COLS        = VIEW_W       ; Visible map cols on screen
HUD_ROW_0       = 0             ; Stats bar row 1
HUD_ROW_1       = 1             ; Stats bar row 2
HUD_DIVIDER_0   = 2             ; Top divider
HUD_DIVIDER_1   = 27            ; Bottom divider
MSG_ROW_0       = 28            ; Message line 1 (newest, top)
MSG_ROW_1       = 29            ; Message line 2 (oldest, bottom)

; --- Map Tile Types ---
TILE_WALL       = 0
TILE_FLOOR      = 1
TILE_CORRIDOR   = 2
TILE_DOOR_CLOSED = 3
TILE_DOOR_OPEN  = 4
TILE_STAIRS_UP  = 5
TILE_STAIRS_DOWN = 6

; --- CHR Tile Indices (background pattern table) ---
CHR_BLANK       = $00
CHR_WALL        = $01
CHR_WALL_2      = $02           ; Wall variant
CHR_FLOOR       = $03
CHR_CORRIDOR    = $04
CHR_DOOR_CLOSED = $05
CHR_DOOR_OPEN   = $06
CHR_STAIRS_UP   = $07
CHR_STAIRS_DOWN = $08
CHR_DARKNESS    = $09
CHR_DIVIDER     = $0A
CHR_EXPLORED    = $0B           ; Explored but not visible

; Item symbol tiles
CHR_GOLD        = $0C           ; *
CHR_FOOD        = $0D           ; :
CHR_WEAPON      = $0E           ; )
CHR_ARMOR       = $0F           ; [
CHR_POTION      = $10           ; !
CHR_SCROLL      = $11           ; ?
CHR_RING        = $12           ; =
CHR_WAND        = $13           ; /
CHR_GOBLET      = $14           ; U (special)
CHR_PLAYER      = $15           ; @
CHR_FLASH       = $16           ; Solid white block (hit effect)

; Font starts at $20 (ASCII mapping)
; A-Z = $41-$5A, a-z = $61-$7A, 0-9 = $30-$39
; Space = $20, punctuation mapped to ASCII positions

; --- Controller Buttons ---
BUTTON_A        = %10000000
BUTTON_B        = %01000000
BUTTON_SELECT   = %00100000
BUTTON_START    = %00010000
BUTTON_UP       = %00001000
BUTTON_DOWN     = %00000100
BUTTON_LEFT     = %00000010
BUTTON_RIGHT    = %00000001

; --- Game States ---
STATE_TITLE     = 0
STATE_GAMEPLAY  = 1
STATE_INVENTORY = 2
STATE_DEATH     = 3
STATE_STAIRS    = 4
STATE_WIN       = 5
STATE_PAUSE     = 6

; --- Player Starting Stats ---
START_HP        = 12
START_MAX_HP    = 12
START_STR       = 16
START_DEF       = 15            ; Ring mail (classic AC 5 → ascending 15)
START_GOLD      = 0
START_LEVEL     = 1
START_XP        = 0
START_HUNGER    = $FF           ; ~255 turns (simplified for NES)

; --- Dungeon Generation ---
GRID_ROWS       = 6             ; 6x6 room grid across 64x48 map
GRID_COLS       = 6
CELL_W          = 10            ; Tile width per grid cell (64/6 ~ 10)
CELL_H          = 8             ; Tile height per grid cell (48/6 = 8)
MIN_ROOM_W      = 4
MAX_ROOM_W      = 9
MIN_ROOM_H      = 3
MAX_ROOM_H      = 7
MAX_ROOMS       = 20
MIN_ROOMS       = 10
ROOM_CHANCE     = 192           ; 75% of 256

; --- Fog of War ---
FOG_HIDDEN      = 0             ; Never seen
FOG_EXPLORED    = 1             ; Previously seen (dim)
FOG_VISIBLE     = 2             ; Currently visible

; --- Monsters ---
MAX_MONSTERS    = 10
MONSTER_WAKE_DIST = 5           ; Tiles away to wake up

; Monster types (index into tables)
MON_BAT         = 0
MON_EMU         = 1
MON_HOBGOBLIN   = 2
MON_SNAKE       = 3
MON_ZOMBIE      = 4

; Monster flags
MFLAG_AWAKE     = %00000001
MFLAG_AGGRESSIVE = %00000010    ; Starts awake
MFLAG_ERRATIC   = %00000100    ; Random movement 50%

; --- Items ---
MAX_FLOOR_ITEMS = 16
MAX_INVENTORY   = 23

; Item types
ITEM_GOLD       = 0
ITEM_FOOD       = 1
; (more in Phase 2)

; --- Combat ---
; d20 system parameters
D20_SIDES       = 20

; --- Hunger ---
HUNGER_MAX      = 255           ; Simplified for 8-bit
HUNGER_NORMAL   = 150
HUNGER_HUNGRY   = 50
HUNGER_WEAK     = 10
FOOD_RESTORE    = 100           ; Hunger restored by food

; --- Dungeon ---
MAX_DUNGEON_LEVEL = 13
