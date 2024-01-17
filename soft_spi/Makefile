# Makefile for Icarus Verilog simulation
# 05-12-2019 E. Brombaugh

# sources
SOURCES = 	tb_soft_spi.v ../src/soft_spi.v
        
# top level
TOP = tb_soft_spi
			
# Executables
TOOLS = /opt/openfpga/fpga-toolchain/
VLOG = $(TOOLS)/bin/iverilog
WAVE = $(TOOLS)/bin/gtkwave
TECH_LIB = /opt/openfpga/fpga-toolchain//share/yosys/ice40/cells_sim.v

# targets
all: $(TOP).vcd

wave: $(TOP).vcd $(TOP).gtkw
	$(WAVE) $(TOP).gtkw
	
$(TOP).vcd: $(TOP)
	./$(TOP)

$(TOP): $(SOURCES) $(HEX)
	$(VLOG) -D icarus -DNO_ICE40_DEFAULT_ASSIGNMENTS -DSIMULATE -l $(TECH_LIB) -o $(TOP) $(SOURCES)
	
clean:
	rm -rf a.out *.obj $(RPT) $(TOP) $(TOP).vcd $(HEX)
	
