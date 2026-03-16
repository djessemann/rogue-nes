.PHONY: all clean

# cc65 toolchain location (override with: make CA65=/path/to/ca65 LD65=/path/to/ld65)
CA65 ?= /tmp/cc65-build/bin/ca65
LD65 ?= /tmp/cc65-build/bin/ld65

ASM_FILES := $(wildcard src/*.asm) $(wildcard src/data/*.asm)

all: rogue-nes.nes

rogue-nes.nes: $(ASM_FILES) nes.cfg
	$(CA65) -I src -o main.o src/main.asm
	$(LD65) -C nes.cfg -o rogue-nes.nes main.o
	@rm -f main.o
	@echo "Build complete: rogue-nes.nes"

clean:
	rm -f *.o *.nes
