# a500-sd-plus-controller
This is an SPI controller for that Amiga 500 that supports 2 SD-cards plus 2 additional devices.

- [a500-sd-plus-controller](#a500-sd-plus-controller)
  * [Registers](#registers)
    + [shifter-read](#shifter-read)
    + [shifter-write-and-shift](#shifter-write-and-shift)
    + [shifter-read-and-shift](#shifter-read-and-shift)
    + [select](#select)
    + [control](#control)
  * [Wait states](#wait-states)

## Registers
The SPI controller sits in the upper portion of the ZORRO-II IO space
It occupies a 256K block at address $EC0000..$EFFFFF.\
The controller has the following registers:

| **address** | **R/W** | **Name**               |
| ----------- | ------- | ---------------------- |
| $EC0001     | R       | shifter-read            |
| $EC0101     | R       | shifter-read-and-shift  |
| $EC0201     | W       | shifter-write-and-shift |
| $EC0301     | W       | select                 |
| $EC0401     | W       | control                |

### shifter-read
This register returns the current content the SPI shift register. 
This register is read-only.

For example, to read a single byte from an SPI device:
1. Write 0xff to the `shifter-write-and-shift` register. 
This will cause the shifter to shift in the first byte while MOSI is forced high. Although many devices ignore any incoming data on MOSI during a read operation, some device require MOSI to be set high during a read operation.
2. Read the data that was shifted into the shift register from the `shifter-read` register.

### shifter-write-and-shift
This register writes data to the SPI shift register. This register is write-only.
Upon writing to this register, data is loaded into the shift register and then shifted out of the MOSI pin. Data is shifted out MSB first. At the same time, data from the MISO pin is shifted into the shift register. 
To write one or more bytes to an SPI device, software can simply write one or more bytes successively to the shifter-write-and-shift register.

### shifter-read-and-shift
This register provides an alternate way of reading the contents of the SPI shift register.
This register is read-only. Upon reading this register, the current contents of the shift register are returned as normal. However, at the same time a next shift sequence is started whereby new data from the MISO pin is shifted into the shift register. The MOSI is forced high during this shift sequence.
The shifter-read-and-shift register allows reading large chunks of data from the SD-card or any other SPI device with minimal overhead. 

For example, to read 512 bytes of data:
1. Write 0xff to the shifter-write-and-shift register. 
This will cause the shifter to shift in the first byte while MOSI is forced high.
2. Read the shifter-read-and-shift register 511 times.
3. Finally, read the last byte using the shifter-read register. This is needed to prevent reading 1 byte too many as reading from the shifter-read-and-shift register will always trigger a next shift sequence.

### select
This register controls the chip select signals. This register is write-only.
This register is set to 0x00 after reset.
Writing a '1' to a corresponding bit asserts (sets low) the corresponding chip select signal. Only 1 device at a time should be asserted.

| **Bit:**   | 3     | 2     | 1    | 0    |
| ---------- | ----- | ----- | ---- | ---- |
| **Device** | EXT 2 | EXT 0 | SD 1 | SD 0 |

### control
This register controls the configuration of the SPI controller.
This register is set to 0x00 after reset.
Currently, only the SPI clock speed can be set.

| **value** | **clock speed** |
| --------- | --------------- |
| $00       | ~ 223 kHz       |
| $01       | ~ 890 kHz       |
| $10       | ~ 7.12 MHz      |

## Wait states
The registers of the SPI controller can only be accessed when the shifter is not shifting ("busy"). There is no provision to check by software whether the shifter is busy or not. Instead, the controller will insert wait states when attempting to access any register while the shifter is busy. 

This helps throughput on basic 68000 systems, especially on the highest SPI clock speed. Software can use the MOVEP instruction to read or write 4 bytes successively without the overhead of checking whether the shifter is busy. 



