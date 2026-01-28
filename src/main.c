/*
 * Rogue NES - Main game file
 * A roguelike dungeon crawler for the NES
 */

#include "nes.h"
#include "rogue.h"

/* Global variables */
unsigned char game_state;
unsigned char frame_count;
unsigned char pad_state;
unsigned char pad_pressed;
unsigned char pad_last;

Player player;
unsigned char map[MAP_SIZE];
Monster monsters[MAX_MONSTERS];

unsigned int rand_seed;

/* External from crt0.s */
extern unsigned char oam_buffer[256];
extern unsigned char frame_counter;

/* Color palettes */
const unsigned char palette_bg[] = {
    0x0F, 0x00, 0x10, 0x30,  /* Black, dark gray, gray, white */
    0x0F, 0x06, 0x16, 0x27,  /* Browns/golds for items */
    0x0F, 0x01, 0x11, 0x21,  /* Blues for water/magic */
    0x0F, 0x09, 0x19, 0x29   /* Greens for nature */
};

const unsigned char palette_spr[] = {
    0x0F, 0x16, 0x27, 0x30,  /* Player - tan/white */
    0x0F, 0x05, 0x15, 0x25,  /* Monster set 1 - reds */
    0x0F, 0x0C, 0x1C, 0x2C,  /* Monster set 2 - cyans */
    0x0F, 0x0A, 0x1A, 0x2A   /* Monster set 3 - greens */
};

/* Simple XOR-shift random number generator */
unsigned char rand8(void) {
    rand_seed ^= rand_seed << 7;
    rand_seed ^= rand_seed >> 9;
    rand_seed ^= rand_seed << 8;
    return (unsigned char)(rand_seed & 0xFF);
}

void srand(unsigned int seed) {
    rand_seed = seed ? seed : 1;
}

/* Read controller input */
void read_input(void) {
    unsigned char i;

    pad_last = pad_state;
    pad_state = 0;

    /* Strobe the controller */
    JOYPAD1 = 1;
    JOYPAD1 = 0;

    /* Read 8 buttons */
    for (i = 0; i < 8; ++i) {
        pad_state = (pad_state << 1) | (JOYPAD1 & 1);
    }

    /* Get newly pressed buttons */
    pad_pressed = pad_state & ~pad_last;
}

/* Map helper functions */
unsigned char get_tile(unsigned char x, unsigned char y) {
    if (x >= MAP_WIDTH || y >= MAP_HEIGHT) return TILE_EMPTY;
    return map[(unsigned int)y * MAP_WIDTH + x];
}

void set_tile(unsigned char x, unsigned char y, unsigned char tile) {
    if (x < MAP_WIDTH && y < MAP_HEIGHT) {
        map[(unsigned int)y * MAP_WIDTH + x] = tile;
    }
}

unsigned char is_passable(unsigned char tile) {
    switch (tile) {
        case TILE_FLOOR:
        case TILE_CORRIDOR:
        case TILE_DOOR:
        case TILE_STAIRS_DN:
        case TILE_STAIRS_UP:
        case TILE_GOLD:
        case TILE_POTION:
        case TILE_SCROLL:
        case TILE_FOOD:
        case TILE_WEAPON:
        case TILE_ARMOR:
        case TILE_RING:
        case TILE_WAND:
        case TILE_AMULET:
            return 1;
        default:
            return 0;
    }
}

/* Load palettes into PPU */
void load_palettes(void) {
    unsigned char i;

    ppu_set_addr(PALETTE_BG);
    for (i = 0; i < 16; ++i) {
        ppu_write(palette_bg[i]);
    }
    for (i = 0; i < 16; ++i) {
        ppu_write(palette_spr[i]);
    }
}

/* Clear a specific nametable */
void clear_nametable(unsigned int addr) {
    unsigned int i;

    ppu_set_addr(addr);
    for (i = 0; i < 960; ++i) {
        ppu_write(0);
    }
    /* Clear attribute table */
    for (i = 0; i < 64; ++i) {
        ppu_write(0);
    }
}

/* Draw a string to the nametable */
void draw_string(unsigned char x, unsigned char y, const char* str) {
    unsigned int addr = NAMETABLE_0 + (unsigned int)y * 32 + x;
    ppu_set_addr(addr);

    while (*str) {
        /* Map ASCII to our character tiles */
        /* Letters A-Z start at tile 0x41 */
        /* Numbers 0-9 start at tile 0x30 */
        ppu_write(*str);
        ++str;
    }
}

/* Draw a number (0-9999) */
void draw_number(unsigned char x, unsigned char y, unsigned int num) {
    unsigned char digits[5];
    unsigned char i, started;
    unsigned int addr = NAMETABLE_0 + (unsigned int)y * 32 + x;

    digits[0] = (num / 10000) % 10;
    digits[1] = (num / 1000) % 10;
    digits[2] = (num / 100) % 10;
    digits[3] = (num / 10) % 10;
    digits[4] = num % 10;

    ppu_set_addr(addr);
    started = 0;
    for (i = 0; i < 5; ++i) {
        if (digits[i] != 0 || i == 4) started = 1;
        if (started) {
            ppu_write('0' + digits[i]);
        }
    }
}

/* Generate a simple room */
void create_room(unsigned char rx, unsigned char ry, unsigned char rw, unsigned char rh) {
    unsigned char x, y;

    /* Floor */
    for (y = ry + 1; y < ry + rh - 1; ++y) {
        for (x = rx + 1; x < rx + rw - 1; ++x) {
            set_tile(x, y, TILE_FLOOR);
        }
    }

    /* Walls */
    for (x = rx + 1; x < rx + rw - 1; ++x) {
        set_tile(x, ry, TILE_WALL_H);
        set_tile(x, ry + rh - 1, TILE_WALL_H);
    }
    for (y = ry + 1; y < ry + rh - 1; ++y) {
        set_tile(rx, y, TILE_WALL_V);
        set_tile(rx + rw - 1, y, TILE_WALL_V);
    }

    /* Corners */
    set_tile(rx, ry, TILE_CORNER_TL);
    set_tile(rx + rw - 1, ry, TILE_CORNER_TR);
    set_tile(rx, ry + rh - 1, TILE_CORNER_BL);
    set_tile(rx + rw - 1, ry + rh - 1, TILE_CORNER_BR);
}

/* Create a corridor between two points */
void create_corridor(unsigned char x1, unsigned char y1, unsigned char x2, unsigned char y2) {
    unsigned char x, y;

    /* Horizontal first, then vertical */
    if (x1 < x2) {
        for (x = x1; x <= x2; ++x) {
            if (get_tile(x, y1) == TILE_EMPTY) {
                set_tile(x, y1, TILE_CORRIDOR);
            } else if (get_tile(x, y1) == TILE_WALL_H || get_tile(x, y1) == TILE_WALL_V) {
                set_tile(x, y1, TILE_DOOR);
            }
        }
    } else {
        for (x = x2; x <= x1; ++x) {
            if (get_tile(x, y1) == TILE_EMPTY) {
                set_tile(x, y1, TILE_CORRIDOR);
            } else if (get_tile(x, y1) == TILE_WALL_H || get_tile(x, y1) == TILE_WALL_V) {
                set_tile(x, y1, TILE_DOOR);
            }
        }
    }

    if (y1 < y2) {
        for (y = y1; y <= y2; ++y) {
            if (get_tile(x2, y) == TILE_EMPTY) {
                set_tile(x2, y, TILE_CORRIDOR);
            } else if (get_tile(x2, y) == TILE_WALL_H || get_tile(x2, y) == TILE_WALL_V) {
                set_tile(x2, y, TILE_DOOR);
            }
        }
    } else {
        for (y = y2; y <= y1; ++y) {
            if (get_tile(x2, y) == TILE_EMPTY) {
                set_tile(x2, y, TILE_CORRIDOR);
            } else if (get_tile(x2, y) == TILE_WALL_H || get_tile(x2, y) == TILE_WALL_V) {
                set_tile(x2, y, TILE_DOOR);
            }
        }
    }
}

/* Generate a dungeon level */
void generate_dungeon(void) {
    unsigned char i, j;
    Room rooms[6];
    unsigned char num_rooms;
    unsigned char rx, ry, rw, rh;

    /* Clear map */
    for (i = 0; i < MAP_HEIGHT; ++i) {
        for (j = 0; j < MAP_WIDTH; ++j) {
            set_tile(j, i, TILE_EMPTY);
        }
    }

    /* Generate 4-6 rooms in a grid pattern */
    num_rooms = 4 + (rand8() % 3);

    for (i = 0; i < num_rooms && i < 6; ++i) {
        /* Grid-based room placement */
        unsigned char grid_x = i % 3;
        unsigned char grid_y = i / 3;

        rw = 5 + (rand8() % 5);
        rh = 4 + (rand8() % 4);
        rx = 1 + grid_x * 10 + (rand8() % 3);
        ry = 1 + grid_y * 10 + (rand8() % 3);

        /* Clamp to map bounds */
        if (rx + rw >= MAP_WIDTH - 1) rw = MAP_WIDTH - rx - 2;
        if (ry + rh >= MAP_HEIGHT - 1) rh = MAP_HEIGHT - ry - 2;

        if (rw >= 4 && rh >= 4) {
            rooms[i].x = rx;
            rooms[i].y = ry;
            rooms[i].w = rw;
            rooms[i].h = rh;
            create_room(rx, ry, rw, rh);
        }
    }

    /* Connect rooms with corridors */
    for (i = 0; i < num_rooms - 1; ++i) {
        unsigned char cx1 = rooms[i].x + rooms[i].w / 2;
        unsigned char cy1 = rooms[i].y + rooms[i].h / 2;
        unsigned char cx2 = rooms[i+1].x + rooms[i+1].w / 2;
        unsigned char cy2 = rooms[i+1].y + rooms[i+1].h / 2;
        create_corridor(cx1, cy1, cx2, cy2);
    }

    /* Place stairs down in the last room */
    i = num_rooms - 1;
    set_tile(rooms[i].x + rooms[i].w/2, rooms[i].y + rooms[i].h/2, TILE_STAIRS_DN);

    /* Place some items randomly */
    for (i = 0; i < 3 + (rand8() % 4); ++i) {
        unsigned char item_room = rand8() % num_rooms;
        unsigned char ix = rooms[item_room].x + 1 + (rand8() % (rooms[item_room].w - 2));
        unsigned char iy = rooms[item_room].y + 1 + (rand8() % (rooms[item_room].h - 2));

        if (get_tile(ix, iy) == TILE_FLOOR) {
            unsigned char item_type = rand8() % 5;
            switch (item_type) {
                case 0: set_tile(ix, iy, TILE_GOLD); break;
                case 1: set_tile(ix, iy, TILE_POTION); break;
                case 2: set_tile(ix, iy, TILE_SCROLL); break;
                case 3: set_tile(ix, iy, TILE_FOOD); break;
                case 4: set_tile(ix, iy, TILE_WEAPON); break;
            }
        }
    }

    /* Spawn player in first room */
    player.x = rooms[0].x + rooms[0].w / 2;
    player.y = rooms[0].y + rooms[0].h / 2;
}

/* Spawn monsters on the current level */
void spawn_monsters(void) {
    unsigned char i;
    unsigned char num_spawned = 0;
    unsigned char attempts = 0;
    unsigned char target = 2 + (player.dungeon_level / 4);

    if (target > MAX_MONSTERS) target = MAX_MONSTERS;

    /* Clear existing monsters */
    for (i = 0; i < MAX_MONSTERS; ++i) {
        monsters[i].active = 0;
    }

    /* Try to spawn monsters */
    while (num_spawned < target && attempts < 50) {
        unsigned char mx = 1 + (rand8() % (MAP_WIDTH - 2));
        unsigned char my = 1 + (rand8() % (MAP_HEIGHT - 2));

        if (get_tile(mx, my) == TILE_FLOOR) {
            /* Don't spawn on or near player */
            signed char dx = mx - player.x;
            signed char dy = my - player.y;
            if (dx < 0) dx = -dx;
            if (dy < 0) dy = -dy;

            if (dx > 3 || dy > 3) {
                monsters[num_spawned].x = mx;
                monsters[num_spawned].y = my;
                monsters[num_spawned].type = SPR_MONSTER_B + (rand8() % 8);
                monsters[num_spawned].hp = 3 + player.dungeon_level;
                monsters[num_spawned].active = 1;
                ++num_spawned;
            }
        }
        ++attempts;
    }
}

/* Initialize a new game */
void init_game(void) {
    unsigned char i;

    /* Initialize player stats from GAME_MECHANICS.md */
    player.hp = 12;
    player.max_hp = 12;
    player.str = 16;
    player.base_str = 16;
    player.def = 10;
    player.level = 1;
    player.dungeon_level = 1;
    player.xp = 0;
    player.gold = 0;
    player.hunger = 1000;

    /* Seed RNG with frame counter */
    srand(frame_counter | (frame_counter << 8) | 12345);

    /* Generate first dungeon level */
    generate_dungeon();
    spawn_monsters();

    /* Clear OAM */
    for (i = 0; i < 64; ++i) {
        oam_buffer[i * 4] = 0xFF;  /* Y position off-screen */
    }

    game_state = STATE_PLAYING;
}

/* Draw the dungeon map to the nametable */
void draw_map(void) {
    unsigned char x, y;
    unsigned char tile;

    for (y = 0; y < MAP_HEIGHT; ++y) {
        ppu_set_addr(NAMETABLE_0 + (unsigned int)y * 32);
        for (x = 0; x < MAP_WIDTH; ++x) {
            tile = get_tile(x, y);
            ppu_write(tile);
        }
    }
}

/* Draw status bar at bottom of screen */
void draw_status(void) {
    /* HP display */
    draw_string(1, STATUS_Y, "HP");
    draw_number(4, STATUS_Y, player.hp);
    draw_string(7, STATUS_Y, "/");
    draw_number(8, STATUS_Y, player.max_hp);

    /* Level */
    draw_string(14, STATUS_Y, "LV");
    draw_number(17, STATUS_Y, player.level);

    /* Dungeon level */
    draw_string(20, STATUS_Y, "FL");
    draw_number(23, STATUS_Y, player.dungeon_level);

    /* Gold */
    draw_string(1, STATUS_Y + 1, "$");
    draw_number(2, STATUS_Y + 1, player.gold);

    /* XP */
    draw_string(10, STATUS_Y + 1, "XP");
    draw_number(13, STATUS_Y + 1, player.xp);

    /* STR */
    draw_string(20, STATUS_Y + 1, "ST");
    draw_number(23, STATUS_Y + 1, player.str);
}

/* Update player sprite in OAM */
void update_sprites(void) {
    unsigned char i;

    /* Player sprite */
    oam_buffer[0] = (player.y << 3) - 1;  /* Y position (tiles to pixels) */
    oam_buffer[1] = SPR_PLAYER;            /* Tile index */
    oam_buffer[2] = 0x00;                  /* Attributes */
    oam_buffer[3] = player.x << 3;         /* X position */

    /* Monster sprites */
    for (i = 0; i < MAX_MONSTERS; ++i) {
        unsigned char oam_idx = (i + 1) * 4;

        if (monsters[i].active) {
            oam_buffer[oam_idx] = (monsters[i].y << 3) - 1;
            oam_buffer[oam_idx + 1] = monsters[i].type;
            oam_buffer[oam_idx + 2] = 0x01;  /* Palette 1 */
            oam_buffer[oam_idx + 3] = monsters[i].x << 3;
        } else {
            oam_buffer[oam_idx] = 0xFF;  /* Hide inactive monsters */
        }
    }
}

/* Check if a monster is at position */
signed char monster_at(unsigned char x, unsigned char y) {
    unsigned char i;
    for (i = 0; i < MAX_MONSTERS; ++i) {
        if (monsters[i].active && monsters[i].x == x && monsters[i].y == y) {
            return i;
        }
    }
    return -1;
}

/* Combat: player attacks monster */
void attack_monster(unsigned char idx) {
    unsigned char damage;
    unsigned char roll = rand8() % 20;

    /* d20 + level + str_bonus vs monster defense */
    if (roll + player.level >= 10) {
        /* Hit! Calculate damage */
        damage = 1 + (rand8() % 4);  /* 1d4 base damage */
        if (player.str >= 18) damage += 2;
        else if (player.str >= 17) damage += 1;

        if (damage > monsters[idx].hp) {
            monsters[idx].hp = 0;
        } else {
            monsters[idx].hp -= damage;
        }

        /* Check if monster died */
        if (monsters[idx].hp == 0) {
            monsters[idx].active = 0;
            player.xp += 5 + player.dungeon_level;

            /* Check for level up */
            if (player.xp >= 10 * (1 << (player.level - 1))) {
                ++player.level;
                player.max_hp += 2 + (rand8() % 8);
                player.hp = player.max_hp;  /* Full restore */
            }
        }
    }
}

/* Combat: monster attacks player */
void monster_attack(unsigned char idx) {
    unsigned char roll = rand8() % 20;
    unsigned char damage;

    if (roll + 5 >= player.def) {
        damage = 1 + (rand8() % 3);
        if (damage > player.hp) {
            player.hp = 0;
            game_state = STATE_DEAD;
        } else {
            player.hp -= damage;
        }
    }
}

/* Move player and handle collisions */
void move_player(signed char dx, signed char dy) {
    unsigned char new_x = player.x + dx;
    unsigned char new_y = player.y + dy;
    unsigned char tile = get_tile(new_x, new_y);
    signed char mon_idx;

    /* Check for monster */
    mon_idx = monster_at(new_x, new_y);
    if (mon_idx >= 0) {
        attack_monster(mon_idx);
        return;
    }

    /* Check for passable terrain */
    if (is_passable(tile)) {
        player.x = new_x;
        player.y = new_y;

        /* Handle item pickup */
        switch (tile) {
            case TILE_GOLD:
                player.gold += 10 + (rand8() % 20);
                set_tile(new_x, new_y, TILE_FLOOR);
                break;
            case TILE_FOOD:
                player.hunger += 400;
                if (player.hp < player.max_hp) {
                    player.hp += player.max_hp / 4;
                    if (player.hp > player.max_hp) player.hp = player.max_hp;
                }
                set_tile(new_x, new_y, TILE_FLOOR);
                break;
            case TILE_POTION:
                player.hp += 5 + (rand8() % 5);
                if (player.hp > player.max_hp) player.hp = player.max_hp;
                set_tile(new_x, new_y, TILE_FLOOR);
                break;
            case TILE_STAIRS_DN:
                /* Go to next level */
                ++player.dungeon_level;
                generate_dungeon();
                spawn_monsters();
                break;
        }

        /* Decrease hunger */
        if (player.hunger > 0) {
            --player.hunger;
            if (player.dungeon_level >= 20) {
                player.hunger -= 2;  /* Faster hunger on deep levels */
            }
        } else {
            /* Starving - take damage */
            if (rand8() % 10 == 0) {
                if (player.hp > 1) --player.hp;
            }
        }
    }
}

/* Update monster AI */
void update_monsters(void) {
    unsigned char i;
    signed char dx, dy, adx, ady;
    signed char move_x, move_y;
    unsigned char nx, ny;

    for (i = 0; i < MAX_MONSTERS; ++i) {
        if (!monsters[i].active) continue;

        /* Simple AI: move toward player if close */
        dx = player.x - monsters[i].x;
        dy = player.y - monsters[i].y;
        adx = dx < 0 ? -dx : dx;
        ady = dy < 0 ? -dy : dy;

        /* Only act if within range */
        if (adx <= 6 && ady <= 6) {
            /* Adjacent to player? Attack! */
            if (adx <= 1 && ady <= 1) {
                monster_attack(i);
            } else {
                /* Move toward player */
                move_x = 0;
                move_y = 0;

                if (dx > 0) move_x = 1;
                else if (dx < 0) move_x = -1;

                if (dy > 0) move_y = 1;
                else if (dy < 0) move_y = -1;

                /* Try to move (prefer x direction) */
                if (move_x != 0) {
                    nx = monsters[i].x + move_x;
                    if (is_passable(get_tile(nx, monsters[i].y)) &&
                        monster_at(nx, monsters[i].y) < 0) {
                        monsters[i].x = nx;
                        continue;
                    }
                }
                if (move_y != 0) {
                    ny = monsters[i].y + move_y;
                    if (is_passable(get_tile(monsters[i].x, ny)) &&
                        monster_at(monsters[i].x, ny) < 0) {
                        monsters[i].y = ny;
                    }
                }
            }
        }
    }
}

/* Update player based on input */
void update_player(void) {
    if (pad_pressed & BTN_UP)    move_player(0, -1);
    if (pad_pressed & BTN_DOWN)  move_player(0, 1);
    if (pad_pressed & BTN_LEFT)  move_player(-1, 0);
    if (pad_pressed & BTN_RIGHT) move_player(1, 0);

    /* Wait a turn (for healing, etc.) */
    if (pad_pressed & BTN_A) {
        /* Pass turn */
    }

    /* Open inventory (placeholder) */
    if (pad_pressed & BTN_START) {
        /* TODO: inventory screen */
    }
}

/* Main game update */
void update_game(void) {
    read_input();

    switch (game_state) {
        case STATE_TITLE:
            if (pad_pressed & BTN_START) {
                init_game();
            }
            break;

        case STATE_PLAYING:
            if (pad_pressed) {
                update_player();
                update_monsters();
            }
            break;

        case STATE_DEAD:
            if (pad_pressed & BTN_START) {
                game_state = STATE_TITLE;
            }
            break;
    }
}

/* Render the game */
void render_game(void) {
    switch (game_state) {
        case STATE_TITLE:
            /* Simple title screen */
            ppu_set_addr(NAMETABLE_0 + 10 * 32 + 11);
            draw_string(11, 10, "ROGUE");
            draw_string(8, 14, "PRESS START");
            break;

        case STATE_PLAYING:
            draw_map();
            draw_status();
            update_sprites();
            break;

        case STATE_DEAD:
            draw_string(10, 12, "GAME OVER");
            draw_string(8, 14, "PRESS START");
            break;
    }
}

/* Main function */
void main(void) {
    /* Wait for PPU to warm up */
    ppu_wait_vblank();

    /* Disable rendering during setup */
    PPU_CTRL = 0;
    PPU_MASK = 0;

    /* Load palettes */
    load_palettes();

    /* Clear nametable */
    clear_nametable(NAMETABLE_0);

    /* Initialize game state */
    game_state = STATE_TITLE;

    /* Initial render */
    render_game();

    /* Reset scroll */
    ppu_wait_vblank();
    PPU_SCROLL = 0;
    PPU_SCROLL = 0;

    /* Enable rendering */
    PPU_CTRL = PPU_CTRL_NMI | PPU_CTRL_SPR_1000;
    PPU_MASK = PPU_MASK_BG | PPU_MASK_SPR | PPU_MASK_BG_LEFT | PPU_MASK_SPR_LEFT;

    /* Main game loop */
    while (1) {
        ppu_wait_vblank();

        /* Disable rendering for updates */
        PPU_MASK = 0;

        update_game();
        render_game();

        /* Reset scroll and re-enable rendering */
        PPU_SCROLL = 0;
        PPU_SCROLL = 0;
        PPU_MASK = PPU_MASK_BG | PPU_MASK_SPR | PPU_MASK_BG_LEFT | PPU_MASK_SPR_LEFT;

        ++frame_count;
    }
}
