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


// CIA bus synchronizer
module sync_cia_bus (
    input       clk,                // destination clock
    input       _reset_in,          // reset
    output      rst_out,
    input       reg_decode_in,      // register address strobe
    output      reg_decode_out,
    input       _cs_in,             // chip select
    output      _cs_out,
    input       e_in,               // E clock
    output      e_out,
    input       [7:0]data_in,       // databus
    output      [7:0]data_out      
    );
    
    genvar i;		 
    reg [1:0]rst_ff;
    
    // reset signal
    always @(posedge clk or negedge _reset_in)
    begin
        if(!_reset_in)
            rst_ff[1:0] <= 2'b11; // async assert
        else 
            rst_ff[1:0] <= { rst_ff[0], 1'b0 }; // sync de-assert
    end
    
    // generate local reset
    `ifdef ALTERA_RESERVED_QIS   	 
        global CLK_BUF (
            .in             (rst_ff[1]), 
            .out            (rst_out)
        ); 
    `else
        assign rst_out = rst_ff[1];
    `endif
    
    // register decode
    sync SYNC_RS ( clk, reg_decode_in, reg_decode_out );
    
    // chip select
    sync SYNC_CS ( clk, _cs_in, _cs_out );

    // E clock
    sync SYNC_E ( clk, e_in, e_out );
	
    // data bus
    generate
        for (i = 0; i <= 7; i = i + 1) 
        begin : gen_data
            sync SYNC_DATA (clk, data_in[i], data_out[i]); 
        end
	endgenerate	

endmodule


// synchronizer
module sync (
    input       clk,            // clock to synchronize to
    input       in,             // asynchronous input
    output      out             // synchronized output
    );
    
    reg [1:0]ff;
    
    always @(posedge clk)
        ff[1:0] <= {ff[0], in};
        
    assign out = ff[1];
    
endmodule
