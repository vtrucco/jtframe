#!/bin/bash

CMD="parallel --halt now,fail=1 "
PERIODS="10 15.6"

while [ $# -gt 0 ]; do
    case $1 in
        -h|-help)
            echo "Usage: long.sh [-dry-run]"
            exit 0;;
        -dry-run|-dry)
            CMD="$CMD --dry-run";;
        *)
            echo "Unsupported argument: $1"
            exit 1;;
    esac
    shift
done

# 15.6 = 64MHz operation
#  9   =111MHz operation
# bank combinations
$CMD sim.sh -nodump -time 10 -period  ::: $PERIODS ::: -1banks -2banks -3banks -4banks || exit $?

# Special cases
$CMD sim.sh -nodump -time 10 -period  ::: $PERIODS ::: -norefresh -perf || exit $?

#different bank lengths
$CMD sim.sh -nodump -period {5} -time 100 -idle {6} \
-len 0 {1} -len 1 {2} -len 2 {3} -len 3 {4} \
::: 16 32 64 ::: 16 32 64 ::: 16 32 64 ::: 16 32 64 ::: $PERIODS ::: 10 50 90 || exit $?

