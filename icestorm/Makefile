# Makefile for icestorm tools + yosys + nextpnr
# Modified from examples in icestorm distribution
# 05-13-19 E. Brombaugh

# src directory
VPATH = ../src

SRC =	icebreaker_z80_top.v ../src/system_z80.v ../src/ram_32kb.v \
		../src/acia.v ../src/acia_rx.v ../src/acia_tx.v ../src/soft_spi.v \
		../src/system_bus.v ../src/wishbone.v \
		../tv80/tv80s.v ../tv80/tv80_alu.v  ../tv80/tv80_core.v  \
		../tv80/tv80_mcode.v ../tv80/tv80_reg.v

# preparing the machine code
FAKE_HEX =	rom.hex
REAL_HEX =  code.hex

# project stuff
PROJ = icebreaker_z80_top
PIN_DEF = icebreaker_z80_top.pcf
SDC = icebreaker_z80_top.sdc
DEVICE = up5k
PKG = sg48

TOOLS = /opt/openfpga/fpga-toolchain
YOSYS = $(TOOLS)/bin/yosys
YOSYS_SYNTH_ARGS = -dsp -relut -dffe_min_ce_use 4
NEXTPNR = $(TOOLS)/bin/nextpnr-ice40
NEXTPNR_ARGS = --pre-pack $(SDC) --placer heap
ICEPACK = $(TOOLS)/bin/icepack
ICETIME = $(TOOLS)/bin/icetime
ICEPROG = $(TOOLS)/bin/iceprog
ICEBRAM = $(TOOLS)/bin/icebram
CDCPROG = cdc_prog
VERILATOR = verilator
TECH_LIB = $(TOOLS)/share/yosys/ice40/cells_sim.v

all: $(PROJ).bin

$(FAKE_HEX):
	$(ICEBRAM) -g 8 2048 > $(FAKE_HEX)

%.json: $(SRC) $(FAKE_HEX)
	$(YOSYS) -p 'synth_ice40 $(YOSYS_SYNTH_ARGS) -top $(PROJ) -json $@' $(SRC)

%.asc: %.json $(PIN_DEF) 
	$(NEXTPNR) $(NEXTPNR_ARGS) --$(DEVICE) --package $(PKG) --json $< --pcf $(PIN_DEF) --asc $@

$(REAL_HEX):
	$(MAKE) -C ../asm/
	cp ../asm/$(FAKE_HEX) ./$(REAL_HEX)
		
%.bin: %.asc $(REAL_HEX)
	$(ICEBRAM) $(FAKE_HEX) $(REAL_HEX) < $< > temp.asc
	$(ICEPACK) temp.asc $@

%.rpt: %.asc
	$(ICETIME) -d $(DEVICE) -mtr $@ $<

recode:
	rm -f $(REAL_HEX) $(PROJ).bin
	$(MAKE) flash
    
prog: $(PROJ).bin
	$(ICEPROG) -S $<

flash: $(PROJ).bin
	$(ICEPROG) $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo $(ICEPROG) -S -IB $<
	
lint: $(SRC)
	$(VERILATOR) --lint-only -Wall --top-module $(PROJ) $(TECH_LIB) $(SRC)

clean:
	rm -f *.json *.asc *.rpt *.bin *.hex
	$(MAKE) clean -C ../asm/

.SECONDARY:
.PHONY: all prog clean
