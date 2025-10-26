# a500-sd-plus-controller
This is a dual micro-SD card plus Ethernet controller for the Amiga 500.
The controller piggybacks on the odd CIA (CIA A) chip on the Amiga 500 motherboard.

## Dual micro-SD card interface
The micro-SD cards are operated in the SPI mode.
The controller can read and writeup to 550KB/s from and to the micro-SD card on a standard 7MHz 68000 CPU.
The primary channel is intended for internal use. This micro-SD card in this slot functions as a fixed harddisk.
The secondary channel is intended to connect to an extension cable to hold an external, removable (hot-swappable) micro-SD card. 
For this purpose, proper measures are taken to control signal integrity over the extension cable. The controller can also handle any current surges that can occur during hot swapping without loading the Amiga power rail too much.

# Ethernet controller
The Ethernet controller is a Microchip ENC28J60 device.
This device supports a 10Mbit half-duples or full-duplex connection.
The interface is built in a slightly non-standard way to maximum immunity for external interference.






