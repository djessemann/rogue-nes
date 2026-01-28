# Makefile for Rogue NES
# Requires cc65 toolchain (ca65, cl65, ld65)

# Toolchain (use CC65_HOME if set, otherwise look in /tmp/cc65-src/bin or PATH)
CC65_BIN ?= /tmp/cc65-src/bin
CC = $(CC65_BIN)/cc65
CA = $(CC65_BIN)/ca65
LD = $(CC65_BIN)/ld65
CL = $(CC65_BIN)/cl65

# cc65 needs to know where its libraries are
export CC65_HOME = /tmp/cc65-src

# Directories
SRC_DIR = src
INC_DIR = include
CFG_DIR = cfg
BUILD_DIR = build

# Target
TARGET = rogue.nes

# Source files
C_SOURCES = $(SRC_DIR)/main.c
ASM_SOURCES = $(SRC_DIR)/crt0.s $(SRC_DIR)/chr.s

# Object files
C_OBJECTS = $(BUILD_DIR)/main.o
ASM_OBJECTS = $(BUILD_DIR)/crt0.o $(BUILD_DIR)/chr.o
OBJECTS = $(C_OBJECTS) $(ASM_OBJECTS)

# Flags
CFLAGS = -t none -Oi --cpu 6502 -I $(INC_DIR)
ASFLAGS = --cpu 6502
LDFLAGS = -C $(CFG_DIR)/nrom.cfg

# Default target
all: $(BUILD_DIR) $(TARGET)

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile C to assembly, then assemble
$(BUILD_DIR)/main.o: $(SRC_DIR)/main.c $(INC_DIR)/nes.h $(INC_DIR)/rogue.h
	$(CC) $(CFLAGS) -o $(BUILD_DIR)/main.s $<
	$(CA) $(ASFLAGS) -o $@ $(BUILD_DIR)/main.s

# Assemble startup code
$(BUILD_DIR)/crt0.o: $(SRC_DIR)/crt0.s
	$(CA) $(ASFLAGS) -o $@ $<

# Assemble CHR data
$(BUILD_DIR)/chr.o: $(SRC_DIR)/chr.s
	$(CA) $(ASFLAGS) -o $@ $<

# Runtime library (use none.lib for standalone code)
RUNTIME = $(CC65_HOME)/lib/none.lib

# Link everything
$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $(OBJECTS) $(RUNTIME)
	@echo "Build complete: $(TARGET)"
	@ls -la $(TARGET)

# Alternative: use cl65 to do everything in one step
simple:
	mkdir -p $(BUILD_DIR)
	$(CL) -t none -Oi --cpu 6502 -I $(INC_DIR) -C $(CFG_DIR)/nrom.cfg \
		-o $(TARGET) $(C_SOURCES) $(ASM_SOURCES)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -f $(TARGET)
	rm -f *.o *.s

# Run in emulator (if fceux is installed)
run: $(TARGET)
	fceux $(TARGET)

# Run in Mesen (if installed)
mesen: $(TARGET)
	mesen $(TARGET)

.PHONY: all clean run mesen simple
