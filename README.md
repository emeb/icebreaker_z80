# icebreaker_z80
A soft Z80 system running on an icebreaker FPGA board

## What it's made of
* A soft Z80 CPU core
* 2kB of ROM (mapped to addr 0 at reset, can be unmapped)
* 64kB of SRAM
* A simple ACIA serial interface
* A GPIO port
* A control port of unmapping ROM
* A SPI port for talking to the ice40 configuration flash

## Prerequisites
You'll need the YosysHQ OSS CAD Suite for the ice40 installed, as well as the Z80asm
assembler, make and other usual build tools.

## Building and installing
```
cd icestorm
make
make flash
```

## Running
After flashing connect a 115200 8-N-1 serial terminal emulator to the icebreaker's
FTDI serial port (usually found at /dev/ttyUSB1 on a Linux system). Push the uButton
on the icebreaker board to generate a soft reset which will restart the Z80 system
and run the low-level monitor program in ROM.
