## Arduino nano sketches/tools

### Build instructions
-   Assemble with [avra](https://github.com/Ro5bert/avra)
-   flash hexfile with the included avrflash script (linux/macos)

**Note:** You must point the avrflash script to your local arduino ide's version of avrdude and its configuration. Arduino uses a modified version of avrdude that works with the UDPI situation on the nano every. 

## Peripheral libraries
-   USB serial (usart3)
-   Midi serial (usart1)
-   RF24L01 (spi)