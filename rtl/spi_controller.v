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
    output reg  xrdy,               // external ready
    input       [23:18]adr_h,       // address (base)
    input       [11:8]adr_l,        // address (registers)
    inout       [7:0]data,          // data bus
    input       miso,               // SPI MISO
    output      mosi,               // SPI MOSI
    output      sclk,               // SPI SCLK
    output      [3:0]_cs            // SPI CHIP SELECTS
    );
    
    localparam device_base = `DEVICE_BASE;
    
    reg [7:0]data_out;
    wire [7:0]data_in;
    wire [3:0]register_address;
    wire [7:0]shift_out;
    wire [15:0]crc_out;
    
    reg  reg_enable_ff;
    reg  [1:0]ctrl_reg;
    reg  [3:0]select_reg;
    reg  crc_source_reg;
    
    reg  enable_data_out;
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////

    // base address decoder
    // device occupies 256K address block   
    assign base_decode_async = (device_base[23:18] == adr_h[23:18]) & ~_as;

    //////////////////////////////////////////////////////////////////////////////////////////////////////
        
	// generate shifter clock
`ifdef ALTERA_RESERVED_QIS   	 
 	global CLK_BUF (
        .in             (cck ~^ cckq), 
        .out            (clk)
    ); 
`else
    assign clk = cck ~^ cckq;
`endif
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // data_out multiplexer
    always @(*)
    begin
        if( adr_l[11:9] == 3'h0 )
            data_out = shift_out;
        else if ( adr_l[11:8] == 4'h6 )
            data_out = crc_out[15:8];
        else if ( adr_l[11:8] == 4'h7 )
            data_out = crc_out[7:0];
        else
            data_out = 8'bx;
    end
    
    // reading of registers is asynchronous
    // address and control lines are guaranteed 
    // stable when _ds goes low
    always @(negedge _ds or posedge _as)
    begin
        if(_as)
            enable_data_out <= 1'b0;
        else if(base_decode_async && r_w)
            enable_data_out <= 1'b1;   
    end
        
    // data bus tri-state control
    assign data = (enable_data_out) ? data_out : 8'bz;
   
    //////////////////////////////////////////////////////////////////////////////////////////////////////

    // xrdy signal.
    // When the SPI controller is busy xrdy goes low 
    // so that Gary will introduce waitstates
    always @(negedge _as or negedge busy)
    begin
        if(!busy)
            xrdy <= 1'b1; 
        else if(base_decode_async && busy)
            xrdy <= 1'b0;            
    end
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////
                        
    // synchronize asynchronous input signals to shifter clock
    sync_68k_bus SYNC_68K (
        .clk                ( clk ),
        ._reset_in          ( _reset ),
        .rst_out            ( rst ),
        .base_decode_in     ( base_decode_async ), 
        .base_decode_out    ( base_decode ),
        ._ds_in             ( _ds ),
        ._ds_out            ( _data_strobe ),
        .adr_l_in           ( adr_l[11:8] ),
        .adr_l_out          ( register_address[3:0] ),
        .data_in            ( data ),
        .data_out           ( data_in )
    );
            
    // generate register enable signal
    always @(posedge clk or posedge rst)
    begin
        if(rst)
            reg_enable_ff <= 1'b0;
        else
            reg_enable_ff <= reg_enable;
    end    
    assign reg_enable = ( base_decode && !_data_strobe && !busy &&  !reg_enable_ff) ? 1'b1 : 1'b0;
                
    // decode register addresses to generate control signals
    assign start_read           = reg_enable & (register_address[3:0] == 4'h1);
    assign start_write          = reg_enable & (register_address[3:0] == 4'h2);          
    assign write_select_reg     = reg_enable & (register_address[3:0] == 4'h3); 
    assign write_ctrl_reg       = reg_enable & (register_address[3:0] == 4'h4); 
    assign write_crc_source_reg = reg_enable & (register_address[3:0] == 4'h5); 
       
    // select register
    always @(posedge clk or posedge rst)
    begin
        if(rst)
            select_reg[3:0] <= 4'b0; // async reset
        else if(write_select_reg)
            select_reg[3:0] <= data_in[3:0];
    end

    // ctrl register
    always @(posedge clk or posedge rst)
    begin
        if(rst)
            ctrl_reg[1:0] <= 2'b0; // async reset
        else if(write_ctrl_reg)
            ctrl_reg[1:0] <= data_in[1:0];
    end  
    
    // crc_source register
    always @(posedge clk or posedge rst)
    begin
        if(rst)
            crc_source_reg <= 1'b0; // async reset
        else if(write_crc_source_reg)
            crc_source_reg <= data_in[0];
    end  
                
    // shifter
    shifter SHIFT (
        .clk            ( clk ),             
        .rst            ( rst ),              
        .start_write    ( start_write ),      
        .start_read     ( start_read ),       
        .shift_in       ( data_in ),    
        .shift_out      ( shift_out ),  
        .speed          ( ctrl_reg[1:0] ),
        .crc_reset      ( write_crc_source_reg ),        
        .crc_source     ( crc_source_reg ),       
        .crc_out        ( crc_out ),  
        .miso           ( miso ),             
        .mosi           ( mosi ),       
        .sclk           ( sclk ),            
        .busy           ( busy )            
    );
     
    // spi chip selects
    assign _cs[3:0] = ~select_reg[3:0];
      
endmodule
