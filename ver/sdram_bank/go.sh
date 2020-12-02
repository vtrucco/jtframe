#!/bin/bash
# Define MAX_THROUGHPUT for max throughput test, inputs will force the SDRAM controller to its maximum
# but only reads are tested
# if left undefined, writes, reads and refresh are tested

DUMP=-DDUMP

while [ $# -gt 0 ]; do
    case $1 in
        -nodump) DUMP=;;
        -h|-help) cat << EOF
Usage:
    -nodump:    disable waveform dumping
EOF
        exit 1;;
    *)  echo "Unexpected argument $1"
        exit 1;;
    esac
    shift
done

make || exit $?

iverilog test.v ../../hdl/sdram/jtframe_sdram_bank*.v ../../hdl/ver/mt48lc16m16a2.v \
    -o sim -DJTFRAME_SDRAM_BANKS -DSIMULATION -DPERIOD=7.5 $DUMP && sim -lxt
