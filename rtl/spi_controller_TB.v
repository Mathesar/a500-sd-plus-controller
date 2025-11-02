`timescale 1ns / 1ps

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


// address
`define controller_address              24'hBFEB00


`define CMD_NOP         'h00
`define CMD_CTRL_REG    'h20
`define CMD_SELECT_REG  'h40
`define CMD_CRC_SRC     'h60
`define CMD_SPI_READ    'h80
`define CMD_SPI_WRITE   'ha0
`define CMD_CRC_READ    'hc0

module spi_controller_TB();

    // inputs to DUT
    reg [15:0]data_drive;
    reg [23:0]address;
    reg cpu_clk;
    reg clk;
    reg e;
    reg r_w;
    reg _rst;
    reg _as;    
    reg [31:0] miso;
    reg [31:0] mosi_data;
        
    // outputs from DUT
    wire [15:0]data;                    // inout   
    wire mosi;
    wire sclk;
    wire [3:0]_ss;
         
    // data bus
    assign data = data_drive;
    
    // address decoder
    wire _cs;
    assign _cs = ~((address[23:12]==12'hBFE) & ~_as);
    
    //variables
    reg [31:0]d;
 
    spi_controller dut (
        .clk        ( clk ), 
        ._reset     ( _rst ),
        .r_w        ( r_w ),
        ._cs        ( _cs ),
        .e          ( e ),
        .rs         ( address[11:8] ),
        .data       ( data[7:0] ),
        .miso       ( miso[31] ),
        .mosi       ( mosi ),
        .sclk       ( sclk ),
        ._ss        ( _ss )
    );
    
    // cpu clock (~7MHz)
    initial begin
        cpu_clk = 1'b1;
		forever begin
		  #70
		  cpu_clk  = 0;
		  #70;
		  cpu_clk  = 1;   
        end
    end
    
    // shifter master clock (16MHz)
    initial begin
        clk = 1;
        forever begin
            clk = ~clk;
            #31.25;
        end    
    end
        
    // miso shifter
    initial begin
        forever begin
            @(negedge sclk)
                miso = {miso[30:0],miso[31]};
        end
    end
    
    // mosi shifter
    initial begin
        forever begin
            @(posedge sclk)
                mosi_data = {mosi_data[30:0],mosi};
        end
    end
        
    initial begin
    _rst = 0;    
    _as = 1;
    e = 0;
    r_w = 1;
    
    #200;
    _rst = 1;
    #600;
    
    $display ("Testbench begin");
    
    // reset procedure
    write68k(`controller_address, `CMD_NOP);    // escape from SPI or CRC read modes, 
                                                // after this instruction we are in write or idle mode
    read68k (`controller_address,  d[7:0]);     // escape from write mode
    
       
    
    //read 4 bytes @ turbo speed
    miso = 32'hdeadbeef;   
    
    write68k(`controller_address, `CMD_CTRL_REG + 2'b10);       // turbo speed     
    write68k(`controller_address, `CMD_SELECT_REG + 'b0001);    // assert CS                             
    
    write68k(`controller_address, `CMD_SPI_READ);  
    read68k (`controller_address, d[31:24]);                    // throw away first byte     
    read68k (`controller_address, d[31:24]);
    read68k (`controller_address, d[23:16]);
    read68k (`controller_address, d[15:8]);    
    write68k(`controller_address, `CMD_NOP);                    // read last byte via write mode  
    write68k(`controller_address, `CMD_SPI_WRITE);
    read68k (`controller_address, d[7:0]);            
    
    write68k(`controller_address, `CMD_SELECT_REG);                      
    
    if(d != 32'hdeadbeef) $display ("TURBO mode read failed");

    
    //read 4 bytes @ slowest speed
    miso = 32'habba1234; 
    write68k(`controller_address, `CMD_CTRL_REG + 2'b00);       // slowest speed     
    write68k(`controller_address, `CMD_SELECT_REG + 'b0001);    // assert CS                                 
    read_spi_single_byte( d[31:24] );  
    read_spi_single_byte( d[23:16] );  
    read_spi_single_byte( d[15:8] );  
    read_spi_single_byte( d[7:0] );      
    write68k(`controller_address, `CMD_SELECT_REG);                     
    if(d != 32'habba1234) $display ("SLOWEST mode read failed");
    
    
    
    //write 4 bytes @ slowest speed
    write68k(`controller_address, `CMD_SELECT_REG + 'b0001);    // assert CS   
    write_spi_single_byte('h12);    
    write_spi_single_byte('h34);    
    write_spi_single_byte('h56);    
    write_spi_single_byte('h78);    
    write68k(`controller_address, `CMD_SELECT_REG);        
    if(mosi_data != 32'h12345678) $display ("SLOWEST mode write failed");
      
    
      
    //write 4 bytes @ turbo speed
    write68k(`controller_address, `CMD_CTRL_REG + 2'b10);       // turbo speed        
    write68k(`controller_address, `CMD_SELECT_REG + 'b0001);    // assert CS        
    write68k(`controller_address, `CMD_SPI_WRITE);
    write68k(`controller_address, 'h9a);    
    write68k(`controller_address, 'hbc);    
    write68k(`controller_address, 'hde);    
    write68k(`controller_address, 'hf0); 
    read68k(`controller_address, d[7:0]);   
    write68k(`controller_address, `CMD_SELECT_REG);             // de-assert CS       
    if(mosi_data != 32'h9abcdef0) $display ("TURBO mode write failed");
    
    
    
    //CRC test when writing
    write68k(`controller_address, `CMD_SELECT_REG + 'b0001);    // assert CS       
    write68k(`controller_address, `CMD_CRC_SRC);                // reset CRC and set source as MOSI    
    
    write68k(`controller_address, `CMD_SPI_WRITE);
    repeat (512) write68k(`controller_address, 'hff);           // write 512 bytes    
    read68k(`controller_address, d[7:0]);   

    write68k(`controller_address, `CMD_CRC_READ);   
    read68k(`controller_address, d[15:8]);                      // read CRC
    read68k(`controller_address, d[7:0]);                       // read CRC
    write68k(`controller_address, `CMD_SELECT_REG); 
      
    if(d[15:0] != 16'h7fa1) $display ("CRC calculation during write failed");   
    
    $display ("Testbench end"); 
    
    
    
    
    #200;       
    $finish;
    
    end
    
    
    // read a single byte
    task read_spi_single_byte (
        output integer data
        );
        begin : read
            integer busy;
            
            write68k(`controller_address, `CMD_SPI_WRITE);
            write68k(`controller_address, 8'hff);
            read68k (`controller_address, data); 
            
            // wait while busy
            read68k (`controller_address, busy); 
            while(busy & 'h80)
            begin
                read68k (`controller_address, busy); 
            end
            
            // read data
            write68k(`controller_address, `CMD_SPI_WRITE);
            read68k (`controller_address, data);      
        end        
    endtask
    
    // write a single byte
    task write_spi_single_byte (
        input integer data
        );
        begin : write
            integer busy;
            
            // write byte
            write68k(`controller_address, `CMD_SPI_WRITE);
            write68k(`controller_address, data);
            read68k (`controller_address, busy);    
            
            // wait while busy
            read68k (`controller_address, busy); 
            while(busy & 'h80)
            begin
                read68k (`controller_address, busy); 
            end
        end        
    endtask
    
    // simplified MC68000 peripheral read cycle
    task read68k (
        input integer address_to_read,
        output integer data_to_read
        );        
		begin
            wait_posedge_clk();                 // S0
            r_w = 1;
            data_drive = 16'bz;
            
            wait_negedge_clk();                 // S1
            address[23:0] = address_to_read[23:0]; 
                
            wait_posedge_clk();                 // S2
            #20;
            _as = 0;
            
            wait_negedge_clk();                 // S3
            
            wait_posedge_clk();                 // S4
            
             wait_negedge_clk();                 // wait 
            wait_posedge_clk();                 // wait                  
            wait_negedge_clk();                 // wait 
            wait_posedge_clk();                 // wait                  
            wait_negedge_clk();                 // wait 
            wait_posedge_clk();                 // wait                  
            wait_negedge_clk();                 // wait 
            e = 1;
            wait_posedge_clk();                 // wait                  
            wait_negedge_clk();                 // wait             
            wait_posedge_clk();                 // wait                  
            wait_negedge_clk();                 // wait 
            wait_posedge_clk();                 // wait             
                        
            wait_negedge_clk();                 // S5
                        
            wait_posedge_clk();                 // S6            
            data_to_read = data;       
                        
            wait_negedge_clk();                 // S7    
            _as = 1;
            e = 0;
        end
	endtask
	
    // simplified MC68000 peripheral write cycle
    task write68k (
        input integer address_to_write,
        input integer data_to_write
        );        
		begin
            wait_posedge_clk();                 // S0
            r_w = 1;
                              
            wait_negedge_clk();                 // S1
            address[23:0] = address_to_write[23:0];            
                
            wait_posedge_clk();                 // S2            
            r_w = 0; 
            #20;
            _as = 0; 
                                   
            wait_negedge_clk();                 // S3
            data_drive = data_to_write[15:0];

            wait_posedge_clk();                 // S4
                                    
            wait_negedge_clk();                 // wait 
            wait_posedge_clk();                 // wait                  
            wait_negedge_clk();                 // wait 
            wait_posedge_clk();                 // wait                  
            wait_negedge_clk();                 // wait 
            wait_posedge_clk();                 // wait                  
            wait_negedge_clk();                 // wait 
            e = 1;
            wait_posedge_clk();                 // wait                  
            wait_negedge_clk();                 // wait             
            wait_posedge_clk();                 // wait                  
            wait_negedge_clk();                 // wait 
            wait_posedge_clk();                 // wait                  
                                        
            wait_negedge_clk();                 // S5
                        
            wait_posedge_clk();                 // S6             
                        
            wait_negedge_clk();                 // S7 
            _as = 1;
            e = 0;
                   
        end
	endtask

	task wait_posedge_clk ();
        begin
            @(posedge cpu_clk);
            #0.1;
        end 
	endtask
	
	task wait_negedge_clk ();
        begin
            @(negedge cpu_clk);
            #0.1;
        end 
	endtask
	


endmodule
