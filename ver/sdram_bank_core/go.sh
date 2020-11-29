#!/bin/bash

make || exit $?

iverilog test.v ../../hdl/sdram/jtframe_sdram_bank_core.v ../../hdl/ver/mt48lc16m16a2.v \
    -o sim -DJTFRAME_SDRAM_BANKS -DSIMULATION && sim -lxt
