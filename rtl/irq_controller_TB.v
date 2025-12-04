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
`define controller_address              24'hBFED00

module irq_controller_TB();

    // inputs to DUT
    reg [15:0]data_drive;
    reg [23:0]address;
    reg cpu_clk;
    reg clk;
    reg e;
    reg r_w;
    reg _rst;
    reg _as;    
            
    // outputs from DUT
    wire [15:0]data;                    // inout   
    wire irq_enable;
         
    // data bus
    assign data = data_drive;
    
    // address decoder
    wire _cs;
    assign _cs = ~((address[23:12]==12'hBFE) & ~_as);
    
    //variables
    reg [31:0]d;
 
    irq_controller dut (
        .clk        ( clk ), 
        ._reset     ( _rst ),
        .r_w        ( r_w ),
        ._cs        ( _cs ),
        .e          ( e ),
        .rs         ( address[11:8] ),
        .data       ( data[7:0] ),
        .irq_enable ( irq_enable )
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
    write68k(`controller_address, 8'b1010_0000);    // enable  IRQ
    if( irq_enable != 1'b1 )
        $display ("irq not enabled ERROR");
    
    write68k(`controller_address, 8'b0010_0000);    // disable IRQ
    if( irq_enable != 1'b0 )
        $display ("irq not disabled ERROR");
        
    write68k(`controller_address, 8'b1000_0000);    // do nothing
    if( irq_enable != 1'b0 )
        $display ("irq not disabled ERROR");
        
    write68k(`controller_address, 8'b0000_0000);    // do nothing
    if( irq_enable != 1'b0 )
        $display ("irq not disabled ERROR");
        
    $display ("Testbench end"); 
        
    #200;       
    $finish;
    
    end
       
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
