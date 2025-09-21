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

`define SPD_DIV66   2'b00       // SPI speed is clk/66
`define SPD_DIV10   2'b01       // SPI speed is clk/10
`define SPD_DIV2    2'b10       // SPI speed is clk/2 (max)

//main shifter
module shifter(
    input clk,                  // system clock
    input rst,                  // system reset
    input start_write,          // start write operation
    input start_read,           // start read operation    
    input [7:0]shift_in,        // parallel data in
    output reg [7:0]shift_out,  // parallel data out    
    input [1:0]speed,           // speed setting
    input crc_reset,            // CRC generator reset
    input crc_source,           // CRC generator input source (0=MOSI, 1=MISO)
    output [15:0]crc_out,       // CRC output
    input miso,                 // SPI MISO
    output mosi,                // SPI MOSI
    output sclk,                // SPI SCLK
    output busy                 // busy status
    );
    
    reg [7:0]shifter;
    reg [15:0]crc16;
    reg [5:0]prescaler;
    reg [5:0]sequencer;
    reg miso_latch;
    reg seq_enable;
      
    // prescaler
    always @(posedge clk)
    begin
        if(start_write || start_read || seq_enable)
            prescaler[5:0] <= 6'b00_0000;
        else
            prescaler[5:0] <= prescaler[5:0] + 1'b1;
    end
    always @(*)
    begin
        if(speed == `SPD_DIV66)
            seq_enable = prescaler[5];
        else if(speed == `SPD_DIV10)
            seq_enable = prescaler[2];
        else
            seq_enable = 1'b1;
    end
                       
    // sequencer
    always @(posedge clk or posedge rst)
    begin
        if(rst) // async reset
            sequencer[4:0] <= 5'b0_0000;
        else if(busy && seq_enable)
            sequencer[4:0] <= sequencer[4:0] + 1'b1;
        else if(start_write || start_read)
            sequencer[4:0] <= 5'b1_0000;
    end
    assign busy        = sequencer[4];
    assign shift       = busy & (seq_enable &  sequencer[0]);
    assign shift_final = busy & (sequencer[3:1] == 3'b111) & shift ;
    assign sample      = busy & (seq_enable & ~sequencer[0]);
            
    // main shifter
    always @(posedge clk or posedge rst)
    begin
        if(rst) // async reset
            shifter[7:0] <= 8'b0000_0000;
        else if(shift && !shift_final)
            shifter[7:0] <= {shifter[6:0],miso_latch};
        else if(start_write)
            shifter[7:0] <= shift_in[7:0];          
        else if(start_read)
            shifter[7:0] <= 8'b1111_1111;          
    end
    
    // shifter parallel out buffer
    always @(posedge clk)
        if(shift_final) 
            shift_out[7:0] <= {shifter[6:0],miso_latch};
            
    // CRC generator
    assign crc16_in = (crc_source) ? (miso_latch ^ crc16[15]) : (shifter[7] ^ crc16[15]);
    always @(posedge clk or posedge rst)
    begin
        if(rst) // async reset
            crc16[15:0] <= 16'b0000_0000_0000_0000;
        else if(shift)
            crc16[15:0] <= { crc16[14:12], (crc16_in^crc16[11]), crc16[10:5], (crc16_in^crc16[4]), crc16[3:0], crc16_in };
        else if(crc_reset)
            crc16[15:0] <= 16'b0000_0000_0000_0000;     
    end
    assign crc_out = crc16;
    
    // MISO 
    always @(posedge clk)
    begin
        if(sample)
            miso_latch <= miso;  
    end
       
    // SCLK
    assign sclk = sequencer[0]; 

    // MOSI
    assign mosi = shifter[7]; 
     
endmodule
