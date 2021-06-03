# Cheat Engine

The cheat engine consists of a Picoblaze compatible CPU that has full access
to SDRAM bank zero. This tiny CPU can be used to implement the MAME cheats,
as well as it can be used to perform other functions, like high-score
extraction and help in debugging the system during development.

The cheat engine comes with a cost in FPGA space usage and synthesis time, so
it is disabled by default. It is enabled by defining the macro **JTFRAME_CHEAT**.

## Port Map

Port   | I/O    |  Usage
-------|--------|-------------------------
2,1,0  | I/O    | SDRAM address (24 bits)
4,3    | O      | data to SDRAM
5      | O      | SDRAM write data mask, only bits 1,0. Active low
7,6    | I      | data read from SDRAM
0x40   | O      | Resets the watchdog
0x80   | O      | Starts SDRAM read
0x80   | I      | Reads peripheral status (bits 7:6)
0xC0   | O      | Starts SDRAM write

The peripheral status bits are read from port 0x80:

Bit   |  Meaning
------|--------------
7     | Bus ownership, when high the Picoblaze is controlling the SDRAM
6     | high if a PicoBlaze started SDRAM transaction has not finished
5     | Low during vertical blanking
4:0   | Reserved
