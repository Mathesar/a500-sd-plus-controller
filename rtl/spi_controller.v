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
    input       [23:17]adr,         // address
    inout       [7:0]data,          // data bus
    input       miso,               // SPI MISO
    output      mosi,               // SPI MOSI
    output      sclk,               // SPI SCLK
    output      [3:0]_cs            // SPI CHIP SELECTS
    );
    
    wire [7:0]data_out;
    reg  [1:0]rst_sync;
    reg  command_done;
    reg  [5:0]ctrl_reg;
    reg  [7:0]data_out_latch;
    
    // generate 7M cpu clock
    assign clk7 = cck ~^ cckq;
    
    // reset synchronizer
    always @(posedge clk7 or negedge _reset)
    begin
        if (!_reset)
            rst_sync[1:0] <= 2'b11; //async preset
        else
            rst_sync[1:0] <= {rst_sync[0],1'b0};
    end
    assign rst = rst_sync[1];
            
    // address decoder, device occupies 256K address block
    localparam device_base = `DEVICE_BASE;
    assign base_decode = ((device_base[23:18] == adr[23:18]) && !_as) ? 1'b1 : 1'b0;
    
    //command accepted signal
    always @(posedge clk7 or posedge _as)
    begin
        if( _as )
            command_done <= 1'b0; // async clear
        else if (rst)
            command_done <= 1'b0; // reset
        else if( base_decode && !_ds && !busy )
            command_done <= 1'b1;
    end
    
    // wait state control
    assign xrdy = ~( base_decode & busy & ~command_done);
    
    // control signals
    assign enable_data_out = base_decode & r_w & command_done;
    assign command_strobe  = base_decode & ~_ds & ~busy & ~command_done;
    assign start_write     = command_strobe & ~adr[17] & ~r_w; 
    assign start_read      = command_strobe &  adr[17] &  r_w; 
    assign latch_data_out  = command_strobe &             r_w;
    assign write_ctrl_reg  = command_strobe &  adr[17] & ~r_w;
       
    // ctrl register
    always @(posedge clk7)
    begin
        if( rst )
            ctrl_reg[5:0] <= 6'b0; // reset
        if( write_ctrl_reg )
            ctrl_reg[5:0] <= data[5:0];
    end
        
    // shifter
    shifter SHIFT (
        .clk         (clk7),             
        .rst         (rst),              
        .start_write (start_write),      
        .start_read  (start_read),       
        .data_in     (data),    
        .data_out    (data_out),  
        .speed       (ctrl_reg[5:4]),
        .miso        (miso),             
        .mosi        (mosi),       
        .sclk        (sclk),            
        .busy        (busy)            
    );
    
    // data out latch
    always @(posedge clk7)
    begin
        if( latch_data_out )
            data_out_latch[7:0] <= data_out[7:0];
    end
    
    // data bus tri-state control
    assign data = ( enable_data_out ) ? data_out_latch[7:0] : 8'bz;
    
    // spi chip selects
    assign _cs[3:0] = ~ctrl_reg[3:0];
      
endmodule
