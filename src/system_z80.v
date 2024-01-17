// system_z80.v - z80 system with ROM, RAM, Serial
// 05-12-19 E. Brombaugh

`timescale 1ns/1ps
`default_nettype none

module system_z80(
	input clk,					// clock
	input reset,				// reset
	
	input [7:0] gpio_i,			// gpio input
	output reg [7:0] gpio_o,	// gpio output
	
	input RX,					// serial input
	output TX,					// serial output
	
	inout	spi0_mosi,			// SPI core 0
			spi0_miso,
			spi0_sclk,
			spi0_cs0,
	
	output acia_diag,			// serial test bit
	output [3:0] spi_diag,		// spi test bits
	output bus_diag				// diagnostic for bus debug
    );

	// Z80 processor core
	wire wait_n, m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n;
	wire [15:0] A;
	reg [7:0] di;
	wire [7:0] dout;
	tv80s uZ80
	(
		.reset_n(~reset),
		.clk(clk), 
		.wait_n(wait_n), 
		.int_n(1'b1), 
		.nmi_n(1'b1), 
		.busrq_n(1'b1), 
		.di(di),
		.m1_n(m1_n), 
		.mreq_n(mreq_n), 
		.iorq_n(iorq_n), 
		.rd_n(rd_n), 
		.wr_n(wr_n), 
		.rfsh_n(rfsh_n), 
		.halt_n(halt_n), 
		.busak_n(busak_n), 
		.A(A), 
		.dout(dout)
	);
	
	// address decoder
	wire rom_ena;
	wire rom_sel = ((A[15:11] == 5'h00) && (mreq_n == 1'b0) && (iorq_n == 1'b1) && (rom_ena == 1'b1)) ? 1'b1 : 1'b0;
	wire ram0_sel = ((A[15] == 1'b0) && (mreq_n == 1'b0) && (iorq_n == 1'b1) && (rom_sel == 1'b0)) ? 1'b1 : 1'b0;
	wire ram1_sel = ((A[15] == 1'h1) && (mreq_n == 1'b0) && (iorq_n == 1'b1)) ? 1'b1 : 1'b0;
	wire gpio_sel = ((A[7:0] == 8'h00) && (mreq_n == 1'b1) && (iorq_n == 1'b0)) ? 1'b1 : 1'b0;
	wire ctrl_sel = ((A[7:0] == 8'h01) && (mreq_n == 1'b1) && (iorq_n == 1'b0)) ? 1'b1 : 1'b0;
	wire acia_sel = ((A[7:1] == 7'h01) && (mreq_n == 1'b1) && (iorq_n == 1'b0)) ? 1'b1 : 1'b0;
	wire wb_sel   = ((A[7:4] == 4'h1) && (mreq_n == 1'b1) && (iorq_n == 1'b0)) ? 1'b1 : 1'b0;
	
	// 2kB Starup ROM @ 0000-07ff when rom_ena asserted @ reset
	reg [7:0] rom_mem[2047:0];
	reg [7:0] rom_do;
	initial
		$readmemh("rom.hex",rom_mem);
	always @(posedge clk)
		rom_do <= rom_mem[A[10:0]];

`ifdef USE_BRAM
	// 2kB RAM @ 0800-0fff
	reg [7:0] ram_mem[2047:0];
	reg [7:0] ram_do;
	always @(posedge clk)
		if((ram0_sel == 1'b1) && (wr_n == 1'b0))
			ram_mem[A[10:0]] <= dout;
	always @(posedge clk)
		ram0_do <= ram_mem[A[10:0]];
	
	wire [7:0] ram1_do = 8'h00;
`else	
	// 32kB RAM @ 0000-7FFF, 0000-07ff disabled when rom_ena asserts
	wire [7:0] ram0_do;
	ram_32kb uram0(
		.clk(clk),
		.sel(ram0_sel),
		.we(~wr_n),
		.addr(A[14:0]),
		.din(dout),
		.dout(ram0_do)
	);
	
	// 32kB RAM @ 8000-FFFF
	wire [7:0] ram1_do;
	ram_32kb uram1(
		.clk(clk),
		.sel(ram1_sel),
		.we(~wr_n),
		.addr(A[14:0]),
		.din(dout),
		.dout(ram1_do)
	);
	
	// generate 1 wait state for RAM reads
	wire ram_sel = (ram0_sel | ram1_sel);
	reg ram_dly;
	always @(posedge clk)
		ram_dly <= ram_sel;
	wire ram_rdy = ~(ram_sel & ~ram_dly);
`endif

	// GPIO @ IO 00
	always @(posedge clk)
		if((gpio_sel == 1'b1) && (wr_n == 1'b0))
			gpio_o <= dout;
	wire [7:0] gpio_do = gpio_i;
	
	// System control reg @ IO 01
	reg [7:0] ctrl_do;
	always @(posedge clk)
		if(reset == 1'b1)
			ctrl_do <= 8'h01;
		else if((ctrl_sel == 1'b1) && (wr_n == 1'b0))
			ctrl_do <= dout;
	assign rom_ena = ctrl_do[0];
		
	// ACIA @ IO 02/03
	wire [7:0] acia_do;
	wire acia_irq;
	acia uacia(
		.clk(clk),				// system clock
		.rst(reset),			// system reset
		.cs(acia_sel),			// chip select
		.we(~wr_n),				// write enable
		.rs(A[0]),				// address
		.rx(RX),				// serial receive
		.din(dout),				// data bus input
		.dout(acia_do),			// data bus output
		.tx(TX),				// serial transmit
		.diag(acia_diag),		// diagnostic
		.irq(acia_irq)			// interrupt request
	);

	// SPI port
	wire [7:0] wb_do;
	wire wb_irq, wb_rdy;
// uncomment this to use hard SPI IP core
//`define HARD_SPI
`ifdef HARD_SPI
	// Wishbone bus master and SB SPI IP cores 0 @ IO 10-1F
	system_bus usysbus(
		.clk(clk),				// system clock
		.rst(reset),			// system reset
		.cs(wb_sel),			// chip select
		.we(~wr_n),			// write enable
		.addr(A[3:0]),			// address
		.din(dout),				// data bus input
		.dout(wb_do),			// data bus output
		.rdy(wb_rdy),			// processor stall
		.irq(wb_irq),			// interrupt request
		.spi0_mosi(spi0_mosi),	// spi core 0 mosi
		.spi0_miso(spi0_miso),	// spi core 0 miso
		.spi0_sclk(spi0_sclk),	// spi core 0 sclk
		.spi0_cs0(spi0_cs0),	// spi core 0 cs
		.diag(spi_diag)			// spi diag bits
	);
`else
	// Stand-alone soft SPI implementation
	soft_spi uut(
		.clk(clk),				// system clock
		.rst(reset),			// system reset
		.cs(wb_sel),			// chip select
		.we(~wr_n),				// write enable
		.addr(A[0]),			// address
		.din(dout),				// data bus input
		.dout(wb_do),			// data bus output
		.rdy(wb_rdy),			// processor stall
		.irq(wb_irq),			// interrupt request
		.spi0_mosi(spi0_mosi),	// spi core 0 mosi
		.spi0_miso(spi0_miso),	// spi core 0 miso
		.spi0_sclk(spi0_sclk),	// spi core 0 sclk
		.spi0_cs0(spi0_cs0),	// spi core 0 cs
		.diag(spi_diag)			// spi diag bits
	);
`endif

	// diagnosic for wishbone bus activity
	assign bus_diag = wb_sel;
	
	// generate wait
	assign wait_n = ram_rdy & wb_rdy;

	// data mux
	always @(*)
		casez({wb_sel,acia_sel,ctrl_sel,gpio_sel,ram1_sel,ram0_sel,rom_sel})
			7'b0000001: di = rom_do;
			7'b000001z: di = ram0_do;
			7'b00001zz: di = ram1_do;
			7'b0001zzz: di = gpio_do;
			7'b001zzzz: di = ctrl_do;
			7'b01zzzzz: di = acia_do;
			7'b1zzzzzz: di = wb_do;
			default: di = rom_do;
		endcase
endmodule
