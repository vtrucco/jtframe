#!/bin/bash

DUMP=-DDUMP
EXTRA=

while [ $# -gt 0 ]; do
    case $1 in
        -nodump) DUMP=;;
        -mister) EXTRA="$EXTRA -DMISTER";;
        -mist) ;;
        -time)
            shift
            EXTRA="$EXTRA -DSIM_TIME=${1}_000_000";;
        -period)
            shift
            EXTRA="$EXTRA -DPERIOD=$1";;
        -readonly)
            EXTRA="$EXTRA -DWRITE_ENABLE=0";;
        -norefresh)
            EXTRA="$EXTRA -DNOREFRESH";;
        -write)
            shift
            EXTRA="$EXTRA -DWRITE_CHANCE=$1";;
        -idle)
            shift
            EXTRA="$EXTRA -DIDLE=$1";;
        -h|-help) cat << EOF
    Tests that correct values are written and read. It also tests that there are no stall conditions.
    All is done in a random test.
Usage:
    -nodump       disables waveform dumping
    -time val     simulation time in ms (5ms by default)
    -period       defines clock period (default 10.416ns = 96MHz)
    -readonly     disables write requests
    -norefresh    disables refresh
    -write        chance of a write in the writing bank. Integer between 0 and 100
    -idle         defines % of time idle for each bank requester. Use an integer between 0 and 100.
    -mister       enables MiSTer simulation, with special constraint on DQM signals
    -mist         enables free use of DQM signals (default)
EOF
        exit 1;;
    *)  echo "Unexpected argument $1"
        exit 1;;
    esac
    shift
done

make || exit $?

echo "$EXTRA"
iverilog test.v ../../hdl/sdram/jtframe_sdram_bank*.v ../../hdl/ver/mt48lc16m16a2.v \
    -o sim -DJTFRAME_SDRAM_BANKS -DSIMULATION -DPERIOD=7.5 $DUMP $EXTRA && sim -lxt
