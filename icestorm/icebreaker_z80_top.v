// icebreaker_z80_top.v - top level for z80 in up5k on icebreaker board
// 12-29-23 E. Brombaugh

`default_nettype none

module icebreaker_z80_top(
	// 16MHz clock osc
	input CLK,
	
    // serial
    input RX,
    output TX,
	
	// SPI0 port
	inout	FLASH_IO0,
			FLASH_IO1,
			FLASH_IO2,
			FLASH_IO3,
			FLASH_SCK,
			FLASH_SSB,
	
	// LED - via drivers
	output [2:0] LED_RGB,
	output LEDR_N, LEDG_N, LED1, LED2, LED3, LED4, LED5,
	
	// button inputs
	input BTN_N, BTN1, BTN2, BTN3,
	
	// diag port
	output P1A1, P1A2, P1A3, P1A4, P1A7, P1A8, P1A9, P1A10
);
	// Fin=12, Fout=16
	wire clk, pll_lock;
	SB_PLL40_PAD #(
		.DIVR(4'b0000),
		.DIVF(7'b1010100),
		.DIVQ(3'b110),
		.FILTER_RANGE(3'b001),
		.FEEDBACK_PATH("SIMPLE"),
		.DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
		.FDA_FEEDBACK(4'b0000),
		.DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
		.FDA_RELATIVE(4'b0000),
		.SHIFTREG_DIV_MODE(2'b00),
		.PLLOUT_SELECT("GENCLK"),
		.ENABLE_ICEGATE(1'b0)
	)
	pll_inst (
		.PACKAGEPIN(CLK),
		.PLLOUTCORE(clk),
		.PLLOUTGLOBAL(),
		.EXTFEEDBACK(),
		.DYNAMICDELAY(8'h00),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.LATCHINPUTVALUE(),
		.LOCK(pll_lock),
		.SDI(),
		.SDO(),
		.SCLK()
	);
	
	// external reset debounce
	reg [7:0] ercnt;
	reg erst;
	always @(posedge clk)
	begin
		if(BTN_N == 1'b0)
		begin
			ercnt <= 8'h00;
			erst <= 1'b1;
		end
		else
		begin
			if(!&ercnt)
				ercnt <= ercnt + 8'h01;
			else
				erst <= 1'b0;
		end
	end
	
	// reset generator waits > 10us
	reg [7:0] reset_cnt;
	reg reset;    
	always @(posedge clk)
	begin
		if(!pll_lock)
		begin
			reset_cnt <= 8'h00;
			reset <= 1'b1;
		end
		else
		begin
			if(reset_cnt != 8'hff)
			begin
				reset_cnt <= reset_cnt + 8'h01;
				reset <= 1'b1;
			end
			else
				reset <= erst;
		end
	end
    
	// test unit
	wire [7:0] gpio_o;
	wire acia_diag, bus_diag;
	wire [3:0] spi_diag;
	system_z80 uut(
		.clk(clk),
		.reset(reset),
    
		.gpio_o(gpio_o),
		.gpio_i({5'h0,BTN3,BTN2,BTN1}),
    
        .RX(RX),
        .TX(TX),
	
		.spi0_mosi(FLASH_IO0),
		.spi0_miso(FLASH_IO1),
		.spi0_sclk(FLASH_SCK),
		.spi0_cs0(FLASH_SSB),
	
		.acia_diag(acia_diag),
		.spi_diag(spi_diag),
		.bus_diag(bus_diag)
	);
	
	// drive /WP and /HLD
	assign FLASH_IO2 = 1'b1;
	assign FLASH_IO3 = 1'b1;
    	
	// drive LEDs
	assign LED_RGB = ~gpio_o[2:0];
	assign LEDR_N = ~gpio_o[3];
	assign LEDG_N = ~gpio_o[4];
	assign LED1 = gpio_o[3];
	assign LED2 = gpio_o[4];
	assign LED3 = gpio_o[5];
	assign LED4 = gpio_o[6];
	assign LED5 = gpio_o[7];
	
	// diags
	assign P1A1 = spi_diag[0];
	assign P1A2 = spi_diag[1];
	assign P1A3 = spi_diag[2];
	assign P1A4 = spi_diag[3];
	assign P1A7 = gpio_o[4];
	assign P1A8 = gpio_o[5];
	assign P1A9 = gpio_o[6];
	assign P1A10 = bus_diag;
endmodule
