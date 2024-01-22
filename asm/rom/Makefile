# Makefile for z80asm to verilog hex
# 05-12-19 E. Brombaugh

# assy source files
SRC =	rom.asm
INC =	../common/acia.asm ../common/spi.asm

# compiler output
OBJ = rom

# build tools & options
ASM = z80asm
HEXDUMP = hexdump
HEXDUMP_ARGS = -v -e '1/1 "%02x " "\n"'

# Targets
all: $(OBJ).hex

$(OBJ).hex: $(OBJ)
	$(HEXDUMP) $(HEXDUMP_ARGS) $< > $@

$(OBJ): $(SRC) $(INC)
	$(ASM) -o $(OBJ) -l$(OBJ).lst $(SRC)

clean:
	-rm -f *.o $(OBJ) $(OBJ).hex $(OBJ).map $(OBJ).lst

