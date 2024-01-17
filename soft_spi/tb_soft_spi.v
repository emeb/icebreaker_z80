// tb_soft_spi.v - testbench for system z80 core
// 01-11-24 E. Brombaugh

`timescale 1ns/1ps
`default_nettype none

module tb_soft_spi;
    reg clk;
    reg reset;
	reg cs;
	reg we;
	reg addr;
	reg [7:0] din;
	wire [7:0] dout;
	wire irq, rdy;
    wire spi0_mosi, spi0_miso, spi0_sclk, spi0_cs0;
	wire [3:0] spi_diag;
	
    // clock source
    always
        #50 clk = ~clk;
	
	assign spi0_miso = spi0_mosi;
    
    // reset
    initial
    begin
`ifdef icarus
  		$dumpfile("tb_soft_spi.vcd");
		$dumpvars;
`endif
        
        // init regs
        clk = 1'b0;
        reset = 1'b1;
        cs = 1'b0;
		we = 1'b0;
		addr = 1'b0;
		din = 8'h00;
		
        // release reset
        #200
        reset = 1'b0;
		
		// lower cs0
		#500
		cs = 1'b1;
		we = 1'b1;
		#100
		cs = 1'b0;
		we = 1'b0;
		
		// send AA
		#100
		din = 8'hAA;
		addr = 1'b1;
		cs = 1'b1;
		we = 1'b1;
		#100
		cs = 1'b0;
		we = 1'b0;
		
		// read status
		#400
		addr = 1'b0;
		cs = 1'b1;
		#100
		cs = 1'b0;
	
		// read data
		#2000
		addr = 1'b1;
		cs = 1'b1;
		#100
		cs = 1'b0;
		
		// raise cs0
		#500
		addr = 1'b0;
		din = 8'h01;
		cs = 1'b1;
		we = 1'b1;
		#100
		cs = 1'b0;
		we = 1'b0;

`ifdef icarus
        // stop after 1 sec
		#10000000 $finish;
`endif
    end
    
    // Unit under test
	soft_spi uut(
		.clk(clk),				// system clock
		.rst(reset),			// system reset
		.cs(cs),				// chip select
		.we(we),				// write enable
		.addr(addr),			// address
		.din(din),				// data bus input
		.dout(dout),			// data bus output
		.rdy(rdy),				// processor stall
		.irq(irq),				// interrupt request
		.spi0_mosi(spi0_mosi),	// spi core 0 mosi
		.spi0_miso(spi0_miso),	// spi core 0 miso
		.spi0_sclk(spi0_sclk),	// spi core 0 sclk
		.spi0_cs0(spi0_cs0),	// spi core 0 cs
		.diag(spi_diag)			// spi diag bits
	);
endmodule
