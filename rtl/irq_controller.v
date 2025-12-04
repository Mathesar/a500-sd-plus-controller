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

module irq_controller
	#(
	parameter	REG_ADDR = 4'hd		// interrupt controller address
	)
	(
    input       clk,                // clock
    input       _reset,             // reset
    input       r_w,                // read / _write
    input       _cs,                // chip select
    input       e,                  // E clock
    input       [3:0]rs,            // register address    
    inout       [7:0]data,          // data bus
	output reg  irq_enable          // interrupt enable
    );
    
    reg  select_latch;
    wire [7:0]data_synced;
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////
     
    assign reg_decode = (rs[3:0]==REG_ADDR) ? 1'b1 : 1'b0;

    //////////////////////////////////////////////////////////////////////////////////////////////////////
                        
    // synchronize asynchronous input signals to shifter clock
    sync_cia_bus SYNC_BUS (
        .clk                ( clk ),
        ._reset             ( _reset ),
        .rst                ( rst ),
        .reg_decode         ( reg_decode ), 
        .reg_decode_synced  ( reg_decode_synced ),
        .r_w                ( r_w ),
        .r_w_synced         ( r_w_synced ),
        ._cs                ( _cs ),
        ._cs_synced         ( _cs_synced ),
        .e                  ( e ),
        .e_synced           ( e_synced ),
        .data               ( data ),
        .data_synced        ( data_synced )
    );
       
    //////////////////////////////////////////////////////////////////////////////////////////////////////

    // detect start of access cycle
    assign select = e_synced & ~_cs_synced;
    always @(posedge clk or posedge rst)
    begin
        if(rst)
            select_latch <= 1'b0; // async reset
        else
            select_latch <= select;
    end
    assign cycle = ~r_w_synced & reg_decode_synced & select & ~select_latch;
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////

    always @(posedge clk or posedge rst)
    begin
        if(rst) 
            irq_enable <= 1'b0; // async reset
        else if(cycle)
            irq_enable <= ( data_synced[5] ) ? data_synced[7] : irq_enable;    
    end     
    
endmodule
