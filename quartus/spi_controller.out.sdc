## Generated SDC file "spi_controller.out.sdc"

## Copyright (C) 2020  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and any partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details, at
## https://fpgasoftware.intel.com/eula.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 20.1.1 Build 720 11/11/2020 SJ Lite Edition"

## DATE    "Tue Oct 28 19:09:06 2025"

##
## DEVICE  "5M160ZE64I5"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {CLOCK} -period 62.000 -waveform { 0.000 31.000 } [get_ports {clk}]
create_clock -name {E-CLK} -period 1400.000 -waveform { 0.000 700.000 } [get_ports {e}]


#**************************************************************
# Create Generated Clock
#**************************************************************



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************



#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {CLOCK}] -group [get_clocks {E-CLK}] 


#**************************************************************
# Set False Path
#**************************************************************

set_false_path -from [get_ports {data[0] data[1] data[2] data[3] data[4] data[5] data[6] data[7]}] 
set_false_path -to [get_ports {data[0] data[1] data[2] data[3] data[4] data[5] data[6] data[7]}]
set_false_path -from [get_ports {_cs_mb _eth_int _reset eth_miso r_w rs[0] rs[1] rs[2] rs[3] sd_miso[0] sd_miso[1]}] 
set_false_path -to [get_ports {_eth_ss _sd_ss[0] _sd_ss[1] dir eth_mosi eth_sclk hdd_led sd_led int_req sd_mosi[0] sd_mosi[1] sd_sclk[0] sd_sclk[1]}]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

