`timescale 1ns / 1ps


module shifter_TB();

    //inputs
    reg clk;
    reg rst;
    reg start_write;
    reg start_read;
    reg [7:0]data_in;
    reg miso;
    reg [1:0]speed;
    integer data;
    
    // outputs    
    wire [7:0]data_out;
    wire mosi;
    wire sclk;
    wire busy;
    
    // DUT
    shifter dut (
        .clk         (clk),             
        .rst         (rst),              
        .start_write (start_write),      
        .start_read  (start_read),       
        .data_in     (data_in),    
        .data_out    (data_out),  
        .speed       (speed),
        .miso        (miso),             
        .mosi        (mosi),       
        .sclk        (sclk),            
        .busy        (busy)            
    );
    
    // clock
    initial begin
        clk = 1'b0;
        //#9.9;
		forever #10 clk = ~clk;   
    end
    
    
    initial begin
    rst = 1;
    start_write = 0;
    start_read = 0;
    data_in = 0;
    miso = 0;
    speed = 2'b10;
    
    
    
    // 2. Apply reset to the design
    repeat (2) @ (posedge clk);
    rst <= 0;
    repeat (2) @ (posedge clk);
    #0.1;

  
    
    // start writing
    write(8'h81);
    write(8'h55);
    
    //start reading
    read(8'h81,data);
    read(8'hc3,data);
    
    #200;
    
    $finish;
    
    end
    
    // write data to the SPI slave
    task write (
        input integer data
        );        
		begin
		    start_write = 1;
            data_in = data;
            @(posedge clk);#0.1;  	
            start_write = 0;
            while(busy) @(posedge clk);
            #0.1;
        end
	endtask

    // read data from the SPI slave
    task read (
        input integer slave_data,
        output integer data
        );        
		begin
            miso = slave_data[7];
		  
		    start_read = 1;
            @(posedge clk);
            #0.1;            	
            start_read = 0;
            while(busy) 
            begin
                @(negedge sclk);
                slave_data[7:0] = {slave_data[6:0],1'b0};
                miso = slave_data[7];
            end
            data = data_out;
            @(posedge clk);
            #0.1;
        end
	endtask


endmodule
