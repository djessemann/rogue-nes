/*
 * Rogue NES - Game definitions
 */

#ifndef _ROGUE_H
#define _ROGUE_H

/* Map dimensions - visible area */
#define MAP_WIDTH       32
#define MAP_HEIGHT      24
#define MAP_SIZE        (MAP_WIDTH * MAP_HEIGHT)

/* Status bar takes bottom 6 rows */
#define STATUS_Y        24

/* Tile types for the dungeon */
#define TILE_EMPTY      0x00
#define TILE_FLOOR      0x01
#define TILE_WALL_H     0x02
#define TILE_WALL_V     0x03
#define TILE_CORNER_TL  0x04
#define TILE_CORNER_TR  0x05
#define TILE_CORNER_BL  0x06
#define TILE_CORNER_BR  0x07
#define TILE_DOOR       0x08
#define TILE_CORRIDOR   0x09
#define TILE_STAIRS_DN  0x0A
#define TILE_STAIRS_UP  0x0B
#define TILE_GOLD       0x0C
#define TILE_POTION     0x0D
#define TILE_SCROLL     0x0E
#define TILE_FOOD       0x0F
#define TILE_WEAPON     0x10
#define TILE_ARMOR      0x11
#define TILE_RING       0x12
#define TILE_WAND       0x13
#define TILE_AMULET     0x14

/* Entity/sprite indices */
#define SPR_PLAYER      0x20
#define SPR_MONSTER_A   0x21  /* Aquator */
#define SPR_MONSTER_B   0x22  /* Bat */
#define SPR_MONSTER_C   0x23  /* Centaur */
#define SPR_MONSTER_E   0x24  /* Emu */
#define SPR_MONSTER_H   0x25  /* Hobgoblin */
#define SPR_MONSTER_I   0x26  /* Ice Monster */
#define SPR_MONSTER_K   0x27  /* Kestrel */
#define SPR_MONSTER_O   0x28  /* Orc */
#define SPR_MONSTER_R   0x29  /* Rattlesnake */
#define SPR_MONSTER_S   0x2A  /* Snake */
#define SPR_MONSTER_T   0x2B  /* Troll */
#define SPR_MONSTER_V   0x2C  /* Vampire */
#define SPR_MONSTER_W   0x2D  /* Wraith */
#define SPR_MONSTER_Y   0x2E  /* Yeti */
#define SPR_MONSTER_Z   0x2F  /* Zombie */

/* Game states */
#define STATE_TITLE     0
#define STATE_PLAYING   1
#define STATE_INVENTORY 2
#define STATE_DEAD      3
#define STATE_WIN       4

/* Max entities on screen */
#define MAX_MONSTERS    8

/* Player stats structure */
typedef struct {
    unsigned char x;
    unsigned char y;
    unsigned char hp;
    unsigned char max_hp;
    unsigned char str;
    unsigned char base_str;
    unsigned char def;
    unsigned char level;
    unsigned char dungeon_level;
    unsigned int  xp;
    unsigned int  gold;
    unsigned int  hunger;
} Player;

/* Monster structure */
typedef struct {
    unsigned char x;
    unsigned char y;
    unsigned char type;
    unsigned char hp;
    unsigned char active;
} Monster;

/* Room structure for dungeon generation */
typedef struct {
    unsigned char x;
    unsigned char y;
    unsigned char w;
    unsigned char h;
    unsigned char connected;
} Room;

/* Global game state */
extern unsigned char game_state;
extern unsigned char frame_count;
extern unsigned char pad_state;
extern unsigned char pad_pressed;
extern unsigned char pad_last;

/* Player instance */
extern Player player;

/* Map data */
extern unsigned char map[MAP_SIZE];

/* Monster data */
extern Monster monsters[MAX_MONSTERS];

/* Random number generation */
extern unsigned int rand_seed;
unsigned char rand8(void);
void srand(unsigned int seed);

/* Game functions */
void init_game(void);
void update_game(void);
void render_game(void);
void generate_dungeon(void);
void spawn_player(void);
void spawn_monsters(void);
void update_player(void);
void update_monsters(void);
void move_player(signed char dx, signed char dy);
void draw_map(void);
void draw_status(void);
void read_input(void);

/* Map helper functions */
unsigned char get_tile(unsigned char x, unsigned char y);
void set_tile(unsigned char x, unsigned char y, unsigned char tile);
unsigned char is_passable(unsigned char tile);

/* Combat */
void attack_monster(unsigned char idx);
void monster_attack(unsigned char idx);

#endif /* _ROGUE_H */
