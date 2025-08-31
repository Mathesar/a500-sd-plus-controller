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


module spi_controller_TB();

    // inputs to DUT
    reg [15:0]data_drive;
    reg [23:0]address;
    reg cck;
    reg cckq;
    reg clk;
    reg r_w;
    reg _rst;
    reg _as;
    reg _ds;
    reg [31:0] miso;
    
    
    // outputs from DUT
    wire [15:0]data;                    // inout   
    wire xrdy;   
    wire mosi;
    wire sclk;
    wire [3:0]_cs;
    
     
    // data bus
    assign data = data_drive;
    
    //variables
    reg [31:0]d;

    spi_controller dut (
        .cck(cck), 
        .cckq(cckq), 
        ._reset(_rst),
        ._as(_as),
        ._ds(_ds),
        .r_w(r_w),
        .xrdy(xrdy),
        .adr(address[23:17]),
        .data(data[7:0]),
        .miso(miso[31]),
        .mosi(mosi),
        .sclk(sclk),
        ._cs(_cs)
    );
    
    // clocks
    initial begin
        cck = 1'b0;
        cckq = 1'b0;
        clk = 1'b1;
		forever begin
		  #70 
		  cck  = 1;
		  clk  = 0;
		  #70;
		  cckq = 1;
		  clk  = 1;
		  #70
		  cck  = 0;
		  clk  = 0;
		  #70;
		  cckq = 0;
		  clk  = 1;   
        end
    end
    
    // miso shifter
    initial begin
        forever begin
            @(negedge sclk)
                miso = {miso[30:0],miso[31]};
        end
    end
       
    
    initial begin
    _rst = 0;    
    _as = 1;
    _ds = 1;
    r_w = 1;
    
    #200;
    _rst = 1;
    #300;
    
    //read 4 bytes @ turbo speed
    miso = 32'hdeadbeef;   
    write68k(24'hEE0000, 'b10_0001);    // assert CS          
    write68k(24'hEC0000, 'hff);         // we need to write first to shift in first byte    
    read68k(24'hEE0000, d[31:24]);
    read68k(24'hEE0000, d[23:16]);
    read68k(24'hEE0000, d[15:8]);
    read68k(24'hEC0000, d[7:0]);            
    write68k(24'hEE0000, 'b10_0000); // de-assert CS           
    if(d != 32'hdeadbeef) $display ("DIV32 mode read failed");

    
    //read 4 bytes @ slowest speed
    miso = 32'habba1234; 
    write68k(24'hEE0000, 'b00_0001);    // assert CS              
    write68k(24'hEC0000, 'hff);         // we need to write first to shift in first byte    
    read68k(24'hEE0000, d[31:24]);
    read68k(24'hEE0000, d[23:16]);
    read68k(24'hEE0000, d[15:8]);
    read68k(24'hEC0000, d[7:0]);            
    write68k(24'hEE0000, 'b00_0000);    // de-assert CS           
    if(d != 32'habba1234) $display ("turbo mode read failed");

    
    //write 4 bytes @ slowest speed
    write68k(24'hEE0000, 'b00_0001);    // assert CS 
    write68k(24'hEC0000, 'h12);    
    write68k(24'hEC0000, 'h34);    
    write68k(24'hEC0000, 'h56);    
    write68k(24'hEC0000, 'h78);    
    write68k(24'hEE0000, 'b00_0000);    // de-assert CS     
    
    
    $finish;
    
    end

    // simplified MC68000 read cycle
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
            _ds = 0;
            _as = 0;
            
            
            wait_negedge_clk();                 // S3
                        
            wait_posedge_clk();                 // S4
            
            while(xrdy == 0)
            begin
                wait_negedge_clk();             // wait                       
                wait_posedge_clk();             // wait
            end
            
            
            wait_negedge_clk();                 // S5
                        
            wait_posedge_clk();                 // S6            
            data_to_read = data;       
            _as = 1;
            _ds = 1;
            
            wait_negedge_clk();                 // S7           
        end
	endtask
	
    // simplified MC68000 write cycle
    task write68k (
        input integer address_to_write,
        input integer data_to_write
        );        
		begin
            wait_posedge_clk();                 // S0
            r_w = 1;
            data_drive = data_to_write[15:0];
            
            wait_negedge_clk();                 // S1
            address[23:0] = address_to_write[23:0];            
                
            wait_posedge_clk();                 // S2            
            _as = 0; 
            r_w = 0;           
                        
            wait_negedge_clk();                 // S3
            _ds = 0;
                        
            wait_posedge_clk();                 // S4
            
            while(xrdy == 0)
            begin
                wait_negedge_clk();             // wait                       
                wait_posedge_clk();             // wait
            end
            
            
            wait_negedge_clk();                 // S5
                        
            wait_posedge_clk();                 // S6             
            _as = 1;
            _ds = 1;
            
            wait_negedge_clk();                 // S7           
        end
	endtask

	task wait_posedge_clk ();
        begin
            @(posedge clk);
            #0.1;
        end 
	endtask
	
	task wait_negedge_clk ();
        begin
            @(negedge clk);
            #0.1;
        end 
	endtask
	


endmodule
