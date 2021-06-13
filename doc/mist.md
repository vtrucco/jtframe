# MiST Derivatives

The MiST firmware was derived from Minimig, but it has served as the basis for other systems:

* SiDi, shares the same MCU and binary firmware
* NeptUNO, comes from Multicore, which seems to be influenced by MiST

## NeptUNO

This system has a primitive I/O and disk management:

* Only direct PS2 and DB9 inputs connected to the FPGA
* The RBF must be renamed to .NP1
* The ROM file must be called like the core file, with the .DAT extension
* ARC files are not allowed, a syntax subset seems supported in the form of INI files

The system has a 2MB SRAM module too, which JTFRAME does not support.