// Copyright 2025 Dennis van Weeren
//
// This code is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
//
// This code is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

// device base address
`define  DEVICE_BASE        24'hEC0000

module spi_controller(
    input       cck,                // color clock
    input       cckq,               // quadrature clock
    input       _reset,             // reset
    input       _as,                // address strobe
    input       _ds,                // data strobe
    input       r_w,                // read / _write
    output      xrdy,               // external ready
    input       [23:18]adr_h,       // address (base)
    input       [11:8]adr_l,        // address (registers)
    inout       [7:0]data,          // data bus
    input       miso,               // SPI MISO
    output      mosi,               // SPI MOSI
    output      sclk,               // SPI SCLK
    output      [3:0]_cs            // SPI CHIP SELECTS
    );
    
    wire [7:0]data_out;
    reg  [1:0]rst_sync;
    reg  command_done;
    reg  [1:0]ctrl_reg;
    reg  [3:0]select_reg;
    reg  crc_source;
    reg  [7:0]data_out_latch;
    
    wire [15:0]crc_out;
    
	// generate 7M cpu clock
`ifdef ALTERA_RESERVED_QIS   	 
 	global CLK_BUF (
        .in             (cck ~^ cckq), 
        .out            (clk7)
    ); 
`else
    assign clk7 = cck ~^ cckq;
`endif
    
    // reset synchronizer
    always @(posedge clk7 or negedge _reset)
    begin
        if (!_reset)
            rst_sync[1:0] <= 2'b11; //async preset
        else
            rst_sync[1:0] <= {rst_sync[0],1'b0};
    end

    // reset buffer
`ifdef ALTERA_RESERVED_QIS 	 
	 global RST_BUF (
        .in             (rst_sync[1]),
        .out            (rst)
	 ); 
`else
	 assign rst = rst_sync[1];
`endif
            
    // address decoder, device occupies 256K address block
    localparam device_base = `DEVICE_BASE;
    assign base_decode = ((device_base[23:18] == adr_h[23:18]) && !_as) ? 1'b1 : 1'b0;
    
    //command accepted signal
    always @(posedge clk7 or posedge _as)
    begin
        if(_as)
            command_done <= 1'b0; // async clear
        else if(base_decode && !_ds && !busy)
            command_done <= 1'b1;
    end
    
    // wait state control
    assign xrdy = ~(base_decode & busy & ~command_done);
    
    // control signals
    assign enable_data_out      = base_decode & r_w & command_done;
    assign command_strobe       = base_decode & ~_ds & ~busy & ~command_done;
    assign latch_data_out       = command_strobe &  (adr_l[11:9] == 3'h0); 
    assign start_read           = command_strobe &  (adr_l[11:8] == 4'h1);
    assign start_write          = command_strobe &  (adr_l[11:8] == 4'h2);      
    assign write_select_reg     = command_strobe &  (adr_l[11:8] == 4'h3); 
    assign write_ctrl_reg       = command_strobe &  (adr_l[11:8] == 4'h4); 
    assign write_crc_source_reg = command_strobe &  (adr_l[11:8] == 4'h5); 
    assign latch_crc_hi         = command_strobe &  (adr_l[11:8] == 4'h6); 
    assign latch_crc_lo         = command_strobe &  (adr_l[11:8] == 4'h7); 
       
    // select register
    always @(posedge clk7 or posedge rst)
    begin
        if(rst)
            select_reg[3:0] <= 4'b0; // async reset
        else if(write_select_reg)
            select_reg[3:0] <= data[3:0];
    end

    // ctrl register
    always @(posedge clk7 or posedge rst)
    begin
        if(rst)
            ctrl_reg[1:0] <= 2'b0; // async reset
        else if(write_ctrl_reg)
            ctrl_reg[1:0] <= data[1:0];
    end  
    
    // crc_source register
    always @(posedge clk7 or posedge rst)
    begin
        if(rst)
            crc_source <= 1'b0; // async reset
        else if(write_crc_source_reg)
            crc_source <= data[0];
    end  
            
    // shifter
    shifter SHIFT (
        .clk            (clk7),             
        .rst            (rst),              
        .start_write    (start_write),      
        .start_read     (start_read),       
        .data_in        (data),    
        .data_out       (data_out),  
        .speed          (ctrl_reg[1:0]),
        .crc_reset      (write_crc_source_reg),        
        .crc_source     (crc_source),       
        .crc_out        (crc_out),  
        .miso           (miso),             
        .mosi           (mosi),       
        .sclk           (sclk),            
        .busy           (busy)            
    );
    
    // data out latch
    always @(posedge clk7)
    begin
        if(latch_data_out)
            data_out_latch[7:0] <= data_out[7:0];
        else if(latch_crc_hi)
            data_out_latch[7:0] <= crc_out[15:8];
        else if(latch_crc_lo)
            data_out_latch[7:0] <= crc_out[7:0];
    end
    
    // data bus tri-state control
    assign data = (enable_data_out) ? data_out_latch[7:0] : 8'bz;
    
    // spi chip selects
    assign _cs[3:0] = ~select_reg[3:0];
      
endmodule
