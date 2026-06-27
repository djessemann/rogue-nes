# ROGUE 6502

A roguelike dungeon crawler for the **Nintendo Entertainment System**, written
from scratch in 6502 assembly for the cc65 toolchain.

![Title screen](docs/title-screen.png)

## ▶ Download

**[⬇ Download `rogue-nes.nes`](https://github.com/djessemann/rogue-nes/raw/main/rogue-nes.nes)**

Load the ROM in any NES emulator (FCEUX, Mesen, Nestopia, etc.) or flash it to
real hardware via an everdrive-style cartridge.

## Controls

| Button | Action |
| --- | --- |
| D-Pad | Move / attack into a monster |
| Start | Begin game / pause |
| Select | (reserved) |

## Building from source

Requires the [cc65](https://cc65.github.io/) toolchain (`ca65` + `ld65`):

```sh
make CA65=ca65 LD65=ld65
```

This assembles `src/main.asm` and links it into `rogue-nes.nes`.

## Title screen

The title is built **Donkey-Kong style** — the giant `ROGUE` / `6502` letters
are not bespoke artwork but are *tiled from a single existing in-game tile*, the
dungeon wall block. The whole title is, quite literally, made of dungeon bricks.
