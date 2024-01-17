# Makefile for Icarus Verilog simulation
# 05-12-2019 E. Brombaugh

# sources
SOURCES = 	tb_system_z80.v ../src/system_z80.v ../src/ram_32kb.v \
			../src/acia.v ../src/acia_rx.v ../src/acia_tx.v \
			../src/system_bus.v ../src/wishbone.v \
			../tv80/tv80s.v ../tv80/tv80_alu.v  ../tv80/tv80_core.v  \
			../tv80/tv80_mcode.v ../tv80/tv80_reg.v
        
# top level
TOP = tb_system_z80
			
# preparing the machine code
HEX =	rom.hex

# Executables
TOOLS = /opt/openfpga/fpga-toolchain/
VLOG = $(TOOLS)/bin/iverilog
WAVE = $(TOOLS)/bin/gtkwave
TECH_LIB = /opt/openfpga/fpga-toolchain//share/yosys/ice40/cells_sim.v

# targets
all: $(TOP).vcd

$(HEX):
	$(MAKE) -C ../asm/
	cp ../asm/$(HEX) .
			
wave: $(TOP).vcd $(TOP).gtkw
	$(WAVE) $(TOP).gtkw
	
$(TOP).vcd: $(TOP)
	./$(TOP)

$(TOP): $(SOURCES) $(HEX)
	$(VLOG) -D icarus -DNO_ICE40_DEFAULT_ASSIGNMENTS -DSIMULATE -l $(TECH_LIB) -o $(TOP) $(SOURCES)
	
clean:
	rm -rf a.out *.obj $(RPT) $(TOP) $(TOP).vcd $(HEX)
	
