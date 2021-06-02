# SDRAM Timing

SDRAM clock can be shifted with respect to the internal clock (clk_rom in the diagram).

![SDRAM clock forwarded](doc/sdram_adv.png)

![SDRAM clock forwarded](doc/sdram_dly.png)

# IOCTL Indexes

For I/O (SDRAM download, etc.) the following indexes are used

 Purpose          | MiST   | MiSTer
------------------|--------|--------
 Main ROM         |   0    |    0
 JTFRAME options  |   1    |    1
 NVRAM            | 255    |    2
 Cheat ROM        |  16    |   16
 DIP switches     |  N/A   |  254
 Cheat switches   |  N/A   |  255
