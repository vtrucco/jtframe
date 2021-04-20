#!/bin/bash

iverilog test.v ../../hdl/sdram/jtframe_romrq.v  -o sim -Wtimescale \
    -s test && sim -lxt
