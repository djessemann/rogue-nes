/*
 * NES hardware definitions for Rogue
 */

#ifndef _NES_H
#define _NES_H

/* PPU registers */
#define PPU_CTRL        (*(volatile unsigned char*)0x2000)
#define PPU_MASK        (*(volatile unsigned char*)0x2001)
#define PPU_STATUS      (*(volatile unsigned char*)0x2002)
#define OAM_ADDR        (*(volatile unsigned char*)0x2003)
#define OAM_DATA        (*(volatile unsigned char*)0x2004)
#define PPU_SCROLL      (*(volatile unsigned char*)0x2005)
#define PPU_ADDR        (*(volatile unsigned char*)0x2006)
#define PPU_DATA        (*(volatile unsigned char*)0x2007)

/* APU and I/O registers */
#define APU_DMC_FREQ    (*(volatile unsigned char*)0x4010)
#define APU_STATUS      (*(volatile unsigned char*)0x4015)
#define OAM_DMA         (*(volatile unsigned char*)0x4014)
#define JOYPAD1         (*(volatile unsigned char*)0x4016)
#define JOYPAD2         (*(volatile unsigned char*)0x4017)

/* Controller button masks */
#define BTN_A           0x80
#define BTN_B           0x40
#define BTN_SELECT      0x20
#define BTN_START       0x10
#define BTN_UP          0x08
#define BTN_DOWN        0x04
#define BTN_LEFT        0x02
#define BTN_RIGHT       0x01

/* PPU control flags */
#define PPU_CTRL_NMI    0x80
#define PPU_CTRL_SPR8x16 0x20
#define PPU_CTRL_BG_1000 0x10
#define PPU_CTRL_SPR_1000 0x08
#define PPU_CTRL_VRAM_INC32 0x04

/* PPU mask flags */
#define PPU_MASK_BG     0x08
#define PPU_MASK_SPR    0x10
#define PPU_MASK_BG_LEFT 0x02
#define PPU_MASK_SPR_LEFT 0x04

/* Nametable addresses */
#define NAMETABLE_0     0x2000
#define NAMETABLE_1     0x2400
#define NAMETABLE_2     0x2800
#define NAMETABLE_3     0x2C00

/* Attribute table addresses */
#define ATTR_TABLE_0    0x23C0
#define ATTR_TABLE_1    0x27C0

/* Palette addresses */
#define PALETTE_BG      0x3F00
#define PALETTE_SPR     0x3F10

/* Screen dimensions */
#define SCREEN_WIDTH    32
#define SCREEN_HEIGHT   30

/* Wait for vblank */
void __fastcall__ ppu_wait_vblank(void);

/* Set PPU address for writes */
void __fastcall__ ppu_set_addr(unsigned int addr);

/* Write data to PPU */
void __fastcall__ ppu_write(unsigned char data);

#endif /* _NES_H */
