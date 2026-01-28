# Rogue NES

An NES port of the classic roguelike dungeon crawler Rogue, playable on any NES emulator with controller support.

## Features

- **Procedural dungeons**: Randomly generated rooms connected by corridors
- **Classic Rogue mechanics**: D20-based combat, experience levels, hunger system
- **Item collection**: Gold, potions, food, weapons, and more
- **Monster AI**: Enemies chase and attack the player
- **Stats system**: HP, strength, defense, level progression

## Controls

| Button | Action |
|--------|--------|
| D-Pad | Move player |
| A | Wait/Pass turn |
| Start | Start game / Menu |

## Building

Requires the [cc65](https://cc65.github.io/) 6502 C compiler toolchain.

```bash
# Install cc65 (Ubuntu/Debian)
sudo apt-get install cc65

# Or build from source
git clone https://github.com/cc65/cc65.git
cd cc65 && make

# Build the ROM
make
```

The output is `rogue.nes`, a standard iNES format ROM.

## Playing

Load `rogue.nes` in any NES emulator:
- [FCEUX](http://fceux.com/)
- [Mesen](https://www.mesen.ca/)
- [Nestopia](http://nestopia.sourceforge.net/)

## Technical Details

- **Mapper**: NROM-256 (Mapper 0)
- **PRG-ROM**: 32KB
- **CHR-ROM**: 8KB
- **Mirroring**: Vertical

## Project Structure

```
rogue-nes/
├── src/
│   ├── main.c      # Game logic in C
│   ├── crt0.s      # NES startup code
│   └── chr.s       # Graphics tile data
├── include/
│   ├── nes.h       # NES hardware definitions
│   └── rogue.h     # Game definitions
├── cfg/
│   └── nrom.cfg    # Linker configuration
├── Makefile
└── rogue.nes       # Built ROM
```

## Game Mechanics

Based on the original Rogue:
- Start with 12 HP, 16 strength, 10 defense
- Gain 2-9 HP per level up with full restore
- Combat uses d20 + level + bonuses vs armor
- Hunger decreases each turn (faster on deeper levels)
- Food restores 400 hunger and 25% HP

See [GAME_MECHANICS.md](GAME_MECHANICS.md) for complete details.

## License

This is a fan project for educational purposes.
