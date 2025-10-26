# a500-sd-plus-controller
The SPI controller communicates via the unused register of the odd 8520 CIA at address $BFEB01

| **address** | **R/W** | **Name**       |
| ----------- | ------- | -------------- |
| $BFEB01     | R/W     | SPI controller |

All communication with the SPI controller is done via this single register.
The behavior of this register depends on the state the SPI controller is in.

## States
The SPI controller can be in any of the following states:

| **State** | **Read**                           | **Write**              |
| --------- | ---------------------------------- | ---------------------- |
| IDLE      | read busy flag                     | issue command          |
| READ      | read buffer and shift              | return to **IDLE**     |
| WRITE     | read buffer and return to **IDLE** | write buffer and shift |
| CRC       | read crc                           | return to **IDLE**     |


### IDLE state
In this state, commands can be send the the SPI controller.
A command is 1 byte long. 
The following commands are supported:

| **command** | **format**  | **description**                    |
| ----------- | ----------- | ---------------------------------- |
| NOP         | 0b000x_xxxx | does nothing                       |
| CONTROL     | 0b001x_xxDD | write control regiser with 0bDD    |
| SELECT      | 0b010x_xDDD | write select register with 0bDDD   |
| CRC_SOURCE  | 0b011x_xxxD | write crc-source register with 0bD |
| READ        | 0b100x_xxxx | goto READ state                    |
| WRITE       | 0b101x_xxxx | goto WRITE state                   |
| CRC         | 0b110x_xxxx | goto CRC state                     |

When in IDLE mode, a read will return the busy flag in the lowest bit (bit#0), the other bits should masked out and ignored.
When the busy flag is set, the controller is doing an SPI transaction and no data should be read from or written to the buffer.

#### select register
This register controls the chip select signals. 
This register is set to 0x00 after reset.
Writing a '1' to a corresponding bit asserts (sets low) the corresponding chip select signal. Only 1 device at a time should be asserted.

| **Bit:**   | 2        | 1    | 0    |
| ---------- | -------- | ---- | ---- |
| **Device** | Ethernet | SD 1 | SD 0 |

#### control register
This register controls the configuration of the SPI controller.
This register is set to 0x00 after reset.
Currently, only the SPI clock speed can be set.

| **value** | **clock speed** |
| --------- | --------------- |
| $00       | ~ 209 kHz       |
| $01       | ~ 1.19 MHz      |
| $10       | ~ 7.12 MHz      |

#### crc-source register
This register selects MOSI or MISO as the CRC generator input. 
This register is set to 0x00 after reset.
Changing the source (writing to this register) also resets the CRC generator to 0x0000.

| **value** | **source**                  |
| --------- | --------------------------- |
| $0        | MOSI (compute CRC on write) |
| $1        | MISO (compute CRC on read)  |

### READ state
This mode is used to read consecutive bytes from the SPI interface.
Each read cycle return the buffer (which contains the last shifted in data) and starts a new SPI transaction. During this transaction, 1's are shifted out regardless of the buffer contents. When the highest speed is selected, data can be read consecutively without checking the busy flag for maximum throughput.

### WRITE state
This mode is used to write a single byte or consecutive bytes to the SPI interface.
Each write cycle writes the buffer and starts a new SPI transaction. During this transaction. When the highest speed is selected, data can be written consecutively without checking the busy flag for maximum throughput.
A read cycle returns the current buffer contents and also returns to the IDLE state.
This way, single bytes can be read as writing in the READ state will always trigger a new SPI transaction.

### CRC state
This mode is used to read the CRC register. The CRC register is 16bits wide. After entering this state from IDLE using the proper command, code should read 2 bytes after which the controller will automatically return to the IDLE state. The first byte read is the high byte of the CRC register. The second byte read is the low byte of the CRC register.

## Some command sequences

### Init sequence, return to IDLE state from an unknown state
```
READ			// return to IDLE state if in CRC or WRITE state
WRITE 0x00  	// if we were now in READ state, return to IDLE state
				// if we are now in IDLE state, issue NOP command
```

### Read a single byte
```
WRITE 0xA0		// go to WRITE state
WRITE 0xFF		// start an SPI transaction while shifting out 1's
READ 			// return to IDLE
while READ&1;	// loop while busy set
WRITE 0xA0		// go to WRITE state
READ data;		// read data
```

### Write a single byte
```
WRITE 0xA0		// go to WRITE state
WRITE data		// start an SPI transaction while shifting out data
READ 			// return to IDLE
while READ&1;	// loop while busy set
```



