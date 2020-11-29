#!/bin/bash
# Define MAX_THROUGHPUT for max throughput test, inputs will force the SDRAM controller to its maximum
# but only reads are tested
# if left undefined, writes, reads and refresh are tested

make || exit $?

iverilog test.v ../../hdl/sdram/jtframe_sdram_bank_core.v ../../hdl/ver/mt48lc16m16a2.v \
    -o sim -DJTFRAME_SDRAM_BANKS -DSIMULATION -DMAX_THROUGHPUT -DPERIOD=7.5 && sim -lxt
