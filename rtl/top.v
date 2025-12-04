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

// SPI controller address, we use the unused CIA register
`define SPI_CONTROLLER_ADDRESS 4'hb

// interrupt controller address, we use some unused bits of the CIA ICR register
`define IRQ_CONTROLLER_ADDRESS 4'hd

module top(
    // CIA piggyback interface
    input       clk,                // clock
    input       _reset,             // reset
    input       r_w,                // read / _write
    input       _cs_mb,             // chip select from motherboard
    output      _cs_cia,            // chip select to CIA
    input       e,                  // E clock
    output      int_req,            // interrupt request
    input       [3:0]rs,            // register address    
    inout       [7:0]data,          // data bus
	output		dir,				// bus buffer direction
    
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
	output		sd_led,             // on-board activity LED
	output      hdd_led             // external activity LED
    );
    
    wire [3:0]_ss;
 
    // reset pass through
    assign _eth_reset = _reset;
    
    // CIA chipselect control
    wire spi_reg_selected = (rs[3:0] == `SPI_CONTROLLER_ADDRESS) ? 1'b1 : 1'b0;
    assign _cs_cia = _cs_mb | spi_reg_selected;
        
    // SPI controller
    spi_controller 
	#( 
		.REG_ADDR	( `SPI_CONTROLLER_ADDRESS ) 
	) 
	SPI
 	(
        .clk        ( clk ), 
        ._reset     ( _reset ),
        .r_w        ( r_w ),
        ._cs        ( _cs_mb ),
        .e          ( e ),
        .rs         ( rs[3:0] ),
        .data       ( data[7:0] ),
		.ext_oe 	( ext_oe ),
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
	 
	// LEDs
	assign sd_led  = ~(_sd_ss[0] & _sd_ss[1]);
	assign hdd_led = ~(_sd_ss[0] & _sd_ss[1]);

	// bus buffer direction
	assign dir = ~ext_oe;
    
    // Interrupt controller
    irq_controller 
	#( 
		.REG_ADDR	( `IRQ_CONTROLLER_ADDRESS ) 
	) 
	IRQ
 	(
        .clk        ( clk ), 
        ._reset     ( _reset ),
        .r_w        ( r_w ),
        ._cs        ( _cs_mb ),
        .e          ( e ),
        .rs         ( rs[3:0] ),
        .data       ( data[7:0] ),
		.irq_enable ( irq_enable )
    );
    
    // interrupt pass-through
    assign int_req = ~_eth_int & irq_enable;


endmodule