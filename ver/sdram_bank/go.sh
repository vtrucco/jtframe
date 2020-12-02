#!/bin/bash

DUMP=-DDUMP
SIMTIME=

while [ $# -gt 0 ]; do
    case $1 in
        -nodump) DUMP=;;
        -time)
            shift
            SIMTIME=-DSIM_TIME=${1}_000_000;;
        -h|-help) cat << EOF
    Tests that correct values are written and read. It also tests that there are no stall conditions.
    All is done in a random test.
Usage:
    -nodump       disable waveform dumping
    -simtime val  simulation time in ms
EOF
        exit 1;;
    *)  echo "Unexpected argument $1"
        exit 1;;
    esac
    shift
done

make || exit $?

iverilog test.v ../../hdl/sdram/jtframe_sdram_bank*.v ../../hdl/ver/mt48lc16m16a2.v \
    -o sim -DJTFRAME_SDRAM_BANKS -DSIMULATION -DPERIOD=7.5 $DUMP $SIMTIME && sim -lxt
