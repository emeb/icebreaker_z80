// soft_spi.v - simple 8-bit SPI master for z80
// runs at CLK/2, fixed phase & polarity
// 01-11-24 E. Brombaugh

`default_nettype none

module soft_spi(
	input clk,				// system clock
	input rst,				// system reset
	input cs,				// chip select
	input we,				// write enable
	input addr,				// register select
	input [7:0] din,		// data bus input
	output [7:0] dout,		// data bus output
	output rdy,				// low-true processor stall
	output irq,				// high-true interrupt request
	inout spi0_mosi,		// spi core 0 mosi
	inout spi0_miso,		// spi core 0 miso
	inout spi0_sclk,		// spi core 0 sclk
	inout spi0_cs0,			// spi core 0 cs
	output [3:0] diag		// diagnostics
);
	// state machine for controlling entire process
	reg [7:0] shift_in, shift_out, rxd;
	reg sclk, busy, done;
	reg [2:0] cnt;
	always @(posedge clk)
	begin
		if(rst)
		begin
			// init everything
			shift_in <= 8'h00;
			shift_out <= 8'h00;
			rxd <= 8'h00;
			sclk <= 1'b0;
			busy <= 1'b0;
			done <= 1'b0;
			cnt <= 3'b000;
		end
		else if(!busy & cs & we & addr)
		begin
			// start transaction at write to addr 1 while not busy
			shift_out <= din;
			sclk <= 1'b0;
			busy <= 1'b1;
			cnt <= 3'b000;
		end
		else if(busy == 1'b1)
		begin
			if(sclk == 1'b0)
			begin
				// capture input on rising edge
				shift_in <= {shift_in[6:0],spi0_miso};
				sclk <= 1'b1;
				
				// hold input when done
				if(cnt == 3'b111)
					rxd <= {shift_in[6:0],spi0_miso};
			end
			else
			begin
				// drive output on falling edge
				sclk <= 1'b0;
				cnt <= cnt + 3'b001;
				
				if(cnt == 3'b111)
				begin
					// done
					busy <= 1'b0;
					done <= 1'b1;
					cnt <= 3'b000;
				end
				else
					shift_out <= {shift_out[6:0],1'b0};
			end
		end
		else
			done <= 1'b0;
	end
	
	// rx full flag
	reg rxf;
	always @(posedge clk)
		if(rst)
			rxf <= 1'b0;
		else if(done)
			rxf <= 1'b1;
		else if(cs & !we & addr)
			rxf <= 1'b0;
	
	// CS is independent gp out at addr 0 bit 0
	reg cs0;
	always @(posedge clk)
		if(rst)
			cs0 <= 1'b1;
		else if(cs & we & !addr)
			cs0 <= din[0];
	
	// Read mux
	assign dout = addr ? rxd : {5'b00000,rxf,~busy,cs0};
	assign rdy = 1'b1;
	assign irq = 1'b0;
	
	// spi signals
	assign spi0_cs0 = cs0;
	assign spi0_sclk = sclk;
	assign spi0_mosi = shift_out[7];
		
	// diagnostics
	assign diag = {shift_out[7],spi0_miso,sclk,cs0};
endmodule
