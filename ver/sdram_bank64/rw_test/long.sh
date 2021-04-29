#!/bin/bash

CMD="parallel --halt now,fail=1 "
PERIODS="10 15.6"
TIME=500

while [ $# -gt 0 ]; do
    case $1 in
        -h|-help)
            echo "Usage: long.sh [-dry-run]"
            exit 0;;
        -dry-run|-dry)
            CMD="$CMD --dry-run";;
        -time)
            shift
            TIME=$1;;
        *)
            echo "Unsupported argument: $1"
            exit 1;;
    esac
    shift
done

# Special cases
$CMD sim.sh -nodump -time 25 -period  ::: $PERIODS ::: -norefresh -perf || exit $?

#different bank lengths
$CMD sim.sh -nodump -period {5} -time $TIME -idle {6} \
-len 0 {1} -len 1 {2} -len 2 {3} -len 3 {4} \
::: 16 32 64 ::: 16 32 64 ::: 16 32 64 ::: 16 32 64 ::: $PERIODS ::: 10 50 90 || exit $?
