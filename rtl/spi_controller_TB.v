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


// register map
`define shifter_read_reg                24'hEC0001
`define shifter_read_and_shift_reg      24'hEC0101
`define shifter_write_and_shift_reg     24'hEC0201
`define select_reg                      24'hEC0301
`define control_reg                     24'hEC0401
`define crc_source_reg                  24'hEC0501
`define crc_hi_reg                      24'hEC0601
`define crc_lo_reg                      24'hEC0701

module spi_controller_TB();

    // inputs to DUT
    reg [15:0]data_drive;
    reg [23:0]address;
    reg cck;
    reg cckq;
    reg cdac;
    reg cpu_clk;
    reg r_w;
    reg _rst;
    reg _as;
    reg _ds;
    reg [31:0] miso;
    reg [31:0] mosi_data;
        
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
        .cdac(cdac), 
        ._reset(_rst),
        ._as(_as),
        ._ds(_ds),
        .r_w(r_w),
        .xrdy(xrdy),
        .adr_h(address[23:18]),
        .adr_l(address[11:8]),
        .data(data[7:0]),
        .miso(miso[31]),
        .mosi(mosi),
        .sclk(sclk),
        ._cs(_cs)
    );
    
    // CCK and CCKQ clocks
    initial begin
        cck = 1'b0;
        cckq = 1'b0;
        cpu_clk = 1'b1;
		forever begin
		  #70; 
		  cck  = 1;
		  cpu_clk  = 0;
		  #70;
		  cckq = 1;
		  cpu_clk  = 1;
		  #70
		  cck  = 0;
		  cpu_clk  = 0;
		  #70;
		  cckq = 0;
		  cpu_clk  = 1;   
        end
    end
    
    // CDAC
    initial begin
        cdac = 1'b1;
        #35;
        forever begin
            cdac = ~cdac;
            #70;
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
    _ds = 1;
    r_w = 1;
    
    #200;
    _rst = 1;
    #300;
    
    $display ("Testbench begin");
    
    //read 4 bytes @ turbo speed
    miso = 32'hdeadbeef;   
    write68k(`control_reg, 'b10);        
    write68k(`select_reg,  'b0001);                     // assert CS          
    write68k(`shifter_write_and_shift_reg, 'hff);       // we need to write first to shift in first byte    
    read68k(`shifter_read_and_shift_reg, d[31:24]);
    read68k(`shifter_read_and_shift_reg, d[23:16]);
    read68k(`shifter_read_and_shift_reg, d[15:8]);
    read68k(`shifter_read_reg,           d[7:0]);            
    write68k(`select_reg, 'b0000);                      // de-assert CS           
    if(d != 32'hdeadbeef) $display ("TURBO mode read failed");

    
    //read 4 bytes @ slowest speed
    miso = 32'habba1234; 
    write68k(`control_reg, 'b00);        
    write68k(`select_reg,  'b0001);                     // assert CS          
    write68k(`shifter_write_and_shift_reg, 'hff);       // we need to write first to shift in first byte    
    read68k(`shifter_read_and_shift_reg, d[31:24]);
    read68k(`shifter_read_and_shift_reg, d[23:16]);
    read68k(`shifter_read_and_shift_reg, d[15:8]);
    read68k(`shifter_read_reg,           d[7:0]);            
    write68k(`select_reg, 'b0000);                      // de-assert CS     
    if(d != 32'habba1234) $display ("DIV32 mode read failed");
    
    //write 4 bytes @ slowest speed
    write68k(`select_reg,  'b0001);                     // assert CS   
    write68k(`shifter_write_and_shift_reg, 'h12);    
    write68k(`shifter_write_and_shift_reg, 'h34);    
    write68k(`shifter_write_and_shift_reg, 'h56);    
    write68k(`shifter_write_and_shift_reg, 'h78);    
    write68k(`select_reg, 'b0000);                      // de-assert CS       
    if(mosi_data != 32'h12345678) $display ("DIV32 mode write failed");
      
    //write 4 bytes @ turbo speed
    write68k(`control_reg, 'b10);     
    write68k(`select_reg,  'b0001);                     // assert CS   
    write68k(`shifter_write_and_shift_reg, 'h9a);    
    write68k(`shifter_write_and_shift_reg, 'hbc);    
    write68k(`shifter_write_and_shift_reg, 'hde);    
    write68k(`shifter_write_and_shift_reg, 'hf0);    
    write68k(`select_reg, 'b0000);                      // de-assert CS       
    if(mosi_data != 32'h9abcdef0) $display ("TURBO mode write failed");
    
    //CRC test when writing
    write68k(`select_reg,  'b0001);                     // assert CS   
    write68k(`crc_source_reg, 'b0);                     // reset CRC and set source as MOSI    
    repeat (512) write68k(`shifter_write_and_shift_reg, 'hff);  // write 512 bytes    
    //read68k(`shifter_read_reg, d[7:0]);                 // dummy read to make sure all data is shifted out
    read68k(`crc_hi_reg, d[15:8]);                      // read CRC
    read68k(`crc_lo_reg, d[7:0]);                       // read CRC
    write68k(`select_reg, 'b0000);                      // de-assert CS     
    if(d[15:0] != 16'h7fa1) $display ("CRC calculation during write failed");   
    
    $display ("Testbench end"); 
    
    #200;       
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
            #20;
            _ds = 0;
            _as = 0;
            
            wait_negedge_clk();                 // S3

            #35;                                    
            while(xrdy == 0)
            begin
                wait_posedge_clk();             // wait
                wait_negedge_clk();             // wait                   
                #35;
            end
            
            wait_posedge_clk();                 // S4
                        
            wait_negedge_clk();                 // S5
                        
            wait_posedge_clk();                 // S6            
            data_to_read = data;       
                        
            wait_negedge_clk();                 // S7    
            _as = 1;
            _ds = 1;       
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
                        
            wait_negedge_clk();                 // S1
            address[23:0] = address_to_write[23:0];            
                
            wait_posedge_clk();                 // S2            
            r_w = 0; 
            #20;
            _as = 0; 
                                   
            wait_negedge_clk();                 // S3
            data_drive = data_to_write[15:0];

            #35;                                    
            while(xrdy == 0)
            begin
                wait_posedge_clk();             // wait
                #20;
                _ds = 0;
                wait_negedge_clk();             // wait                   
                #35;
            end
            
            wait_posedge_clk();                 // S4
            #20;
            _ds = 0;
                
            wait_negedge_clk();                 // S5
                        
            wait_posedge_clk();                 // S6             
                        
            wait_negedge_clk();                 // S7 
            _as = 1;
            _ds = 1;                      
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
