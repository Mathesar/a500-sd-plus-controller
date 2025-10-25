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

module top(
    // CIA piggyback interface
    input       clk,                // clock
    input       _reset,             // reset
    input       r_w,                // read / _write
    input       _cs_mb,             // chip select from motherboard
    output      _cs_cia,            // chip select to CIA
    input       e,                  // E clock
    output      int,                // interrupt output
    input       [3:0]rs,            // register address    
    inout       [7:0]data,          // data bus
    
    // Ethernet controller
    input       eth_miso,           // Ethernet MISO
    output      eth_mosi,           // Ethernet MOSI
    output      eth_sclk,           // Ethernet SCLK
    output      _eth_ss,            // Ethernet SLAVE SELECTS
    input       _eth_int,           // Ethernet interrupt
    output      _eth_reset,         // Ethernet reset
    
    // SD cards
    input       [1:0]sd_miso,       // SD MISO
    output      [1:0]sd_mosi,       // SD MOSI
    output      [1:0]sd_sclk,       // SD SCLK
    output      [1:0]_sd_ss,        // SD SLAVE SELECTS
	 output		 sd_led,
	 output      hdd_led
    );
    
    wire [3:0]_ss;
        
    // interrupt pass through
    assign int = ~_eth_int;
    
    // reset
    assign _eth_reset = _reset;
    
    // CIA chipselect control
    wire spi_reg_selected = (rs[3:0] == 4'hb) ? 1'b1 : 1'b0;
    assign _cs_cia = _cs_mb | spi_reg_selected;
        
    // SPI controller
    spi_controller dut (
        .clk        ( clk ), 
        ._reset     ( _reset ),
        .r_w        ( r_w ),
        ._cs        ( _cs_mb ),
        .e          ( e ),
        .rs         ( rs[3:0] ),
        .data       ( data[7:0] ),
        .miso       ( miso ),
        .mosi       ( mosi ),
        .sclk       ( sclk ),
        ._ss        ( _ss )
    );
    
    // distribute MOSI, SCLK and _SS;
    assign eth_mosi   = mosi;
    assign sd_mosi[0] = mosi;
    assign sd_mosi[1] = mosi;
    
    assign eth_sclk   = sclk;
    assign sd_sclk[0] = sclk;
    assign sd_sclk[1] = sclk;
    
    assign _sd_ss[0]  = _ss[0];
    assign _sd_ss[1]  = _ss[1];
    assign _eth_ss    = _ss[2];
    
    // MISO mux
    assign miso = ( _sd_ss[0] | sd_miso[0] ) & ( _sd_ss[1] | sd_miso[1] ) & (_eth_ss | eth_miso );


endmodule