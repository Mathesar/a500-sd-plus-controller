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

module spi_controller
	#(
	parameter	REG_ADDR = 4'hb		// register address
	)
	(
    input       clk,                // clock
    input       _reset,             // reset
    input       r_w,                // read / _write
    input       _cs,                // chip select
    input       e,                  // E clock
    input       [3:0]rs,            // register address    
    inout       [7:0]data,          // data bus
	output      ext_oe,				// external driver output enable
    input       miso,               // SPI MISO
    output      mosi,               // SPI MOSI
    output      sclk,               // SPI SCLK
    output      [3:0]_ss            // SPI SLAVE SELECTS
    );
   
    reg  [7:0]data_out;
    reg  [7:0]next_data_out;
    reg  [1:0]ctrl_reg;
    reg  [1:0]next_ctrl_reg;
    reg  [3:0]select_reg;
    reg  [3:0]next_select_reg;
    reg  crc_source_reg;
    reg  next_crc_source_reg;
    reg  [2:0]state;
    reg  [2:0]next_state;
    
    wire [7:0]data_synced;
    wire [7:0]shift_out;
    wire [15:0]crc_out;
        
    reg  start_read;
    reg  start_write; 
    reg  crc_reset;
    wire select,cycle;
    reg  select_latch;
  
    reg  enable_data_out_internal;
    reg  enable_data_out_external;
    
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
    assign select = (reg_decode_synced) & e_synced & ~_cs_synced;
    always @(posedge clk or posedge rst)
    begin
        if(rst)
            select_latch <= 1'b0; // async reset
        else
            select_latch <= select;
    end
    assign cycle = select & ~select_latch;
    
    // states    
    localparam IDLE=0, READ=1, WRITE=2, CRC1=3, CRC2=4;
    
    // main state machine sequential part
    always @(posedge clk or posedge rst)
    begin
        if(rst) // async reset
        begin
            state <= IDLE;
            ctrl_reg <= 2'b00;
            select_reg <= 4'b00;
            crc_source_reg <= 1'b0;
            data_out <= 8'b0;
            
        end
        else if(cycle)
        begin
            state <= next_state; 
            ctrl_reg <= next_ctrl_reg;  
            select_reg <= next_select_reg;   
            crc_source_reg <= next_crc_source_reg; 
            data_out <= next_data_out;
        end
    end
    
    // main state machine combinatorial part
    always @(*)
    begin
        // defaults
        next_state = state;
        next_ctrl_reg = ctrl_reg;
        next_select_reg = select_reg;
        next_crc_source_reg = crc_source_reg;
        next_data_out = data_out;
        start_read = 0;
        start_write = 0;
        crc_reset = 0;
        
        // states
        case(state)
        
            // idle mode
            IDLE:
            begin
                if(!r_w)
                begin
                    // write issues a command
                    case(data_synced[7:5])
                        
                        // command: write control register
                        'd1:    
                        begin
                            next_ctrl_reg = data_synced[1:0];
                        end
                        
                        // command: write select register
                        'd2:    
                        begin
                            next_select_reg = data_synced[3:0];
                        end
                        
                        // command: select CRC source and reset CRC generator
                        'd3:    
                        begin
                            next_crc_source_reg = data_synced[0];
                            crc_reset = cycle;
                        end
                        
                        // command: go to SPI read mode
                        'd4:    
                        begin
                            next_state = READ;
                        end
                        
                        // command: go to SPI write mode
                        'd5:    
                        begin
                            next_state = WRITE;
                        end
                        
                        // command: go to CRC read mode
                        'd6:    
                        begin
                            next_state = CRC1;
                        end
                    
                    endcase                    
                end
                else                
                begin
                    // read returns shifter busy flag                
                    next_data_out = {busy, 7'bx};
                end
            end
            
            // consecutive read mode
            READ:
            begin
                if(r_w)
                begin
                    // read returns SPI data and starts a shift action
                    next_data_out = shift_out;
                    start_read = cycle;
                    
                end
                else
                begin
                    // write returns to idle
                    next_state = IDLE;
                end
            end
            
            // consecutive write mode or single byte read mode
            WRITE:
            begin
                if(r_w)
                begin
                    // read returns SPI data and returns to idle
                    next_data_out = shift_out;
                    next_state = IDLE;
                end
                else
                begin
                    // write starts a shift action
                    start_write = cycle;
                end
            end
            
            // CRC read mode
            CRC1:
            begin
                if(r_w)
                begin
                    // read returns CRC high byte
                    next_data_out = crc_out[15:8];
                    next_state = CRC2;
                end
                else
                begin
                    // write returns to idle
                    next_state = IDLE;
                end
            end
            
            // CRC read mode            
            CRC2:
            begin
                // read returns CRC low byte
                next_data_out = crc_out[7:0];
                next_state = IDLE;
            end
                
            // we are not in Kansas anymore          
            default:
            begin
                next_state = IDLE;
            end         
               
        endcase
    end
                 
    // shifter
    shifter SHIFT (
        .clk            ( clk ),             
        .rst            ( rst ),              
        .start_write    ( start_write ),      
        .start_read     ( start_read ),       
        .shift_in       ( data_synced ),    
        .shift_out      ( shift_out ),  
        .speed          ( ctrl_reg[1:0] ),
        .crc_reset      ( crc_reset ),        
        .crc_source     ( crc_source_reg ),       
        .crc_out        ( crc_out ),  
        .miso           ( miso ),             
        .mosi           ( mosi ),       
        .sclk           ( sclk ),            
        .busy           ( busy )            
    );
     
    // spi chip selects
    assign _ss[3:0] = ~select_reg[3:0];
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////

    // assert external output enable first to avoid drivers clashing
    always @(posedge clk or posedge _cs)
    begin
        if(_cs) // async reset
        begin
            enable_data_out_internal <= 1'b0;
            enable_data_out_external <= 1'b0;
        end
        else if( reg_decode_synced && r_w_synced && !_cs_synced)
        begin
            enable_data_out_external <= 1'b1;
            enable_data_out_internal <= enable_data_out_external; 
        end  
    end
        
    // data bus tri-state control
    assign data = (enable_data_out_internal) ? data_out : 8'bz;
    
    // external output enable
    assign ext_oe = enable_data_out_external;
      
endmodule
