#!/bin/bash

iverilog test.v ../../hdl/video/jtframe_{vtimer,scan2x}.v ../../hdl/clocking/jtframe_cen48.v \
    -o sim -s test -D SIMULATION -D SIMULATION_VTIMER && sim -lxt

