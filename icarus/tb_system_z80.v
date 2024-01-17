// tb_system_z80.v - testbench for system z80 core
// 05-12-19 E. Brombaugh

`timescale 1ns/1ps
`default_nettype none

module tb_system_z80;
    reg clk;
    reg reset;
	wire [7:0] gpio_o;
	reg [7:0] gpio_i;
	reg RX;
    wire TX;
    wire spi0_mosi, spi0_miso, spi0_sclk, spi0_cs0;
	
    // clock source
    always
        #50 clk = ~clk;
    
    // reset
    initial
    begin
`ifdef icarus
  		$dumpfile("tb_system_z80.vcd");
		$dumpvars;
`endif
        
        // init regs
        clk = 1'b0;
        reset = 1'b1;
        RX = 1'b1;
		gpio_i = 8'b00;
        
        // release reset
        #200
        reset = 1'b0;
        
`ifdef icarus
        // stop after 1 sec
		#10000000 $finish;
`endif
    end
    
    // Unit under test
    system_z80 uut(
        .clk(clk),              // 4.028MHz dot clock
        .reset(reset),          // Low-true reset
        .gpio_o(gpio_o),        // gpio output
        .gpio_i(gpio_i),        // gpio input
        .RX(RX),                // serial input
        .TX(TX),                // serial output
		.spi0_mosi(spi0_mosi),	// SPI core 0
		.spi0_miso(spi0_miso),
		.spi0_sclk(spi0_sclk),
		.spi0_cs0(spi0_cs0)
    );
endmodule
