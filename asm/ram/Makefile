# Makefile for z80asm to verilog bin
# 05-12-19 E. Brombaugh

# assy source files
SRC =	ram.asm
INC =	../common/acia.asm ../common/soft_spi.asm

# compiler output
OBJ = ram

# build tools & options
ASM = z80asm
TOOLS = /opt/openfpga/fpga-toolchain
ICEPROG = $(TOOLS)/bin/iceprog

# Targets
all: $(OBJ).bin

$(OBJ).bin: $(SRC) $(INC)
	$(ASM) -o $(OBJ).bin -l$(OBJ).lst $(SRC)

flash: $(OBJ).bin
	$(ICEPROG) -o 655360 $<

clean:
	-rm -f *.o $(OBJ).bin $(OBJ).map $(OBJ).lst

