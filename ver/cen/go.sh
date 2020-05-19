#!/bin/bash

iverilog test.v ../../hdl/clocking/jtframe_{cen48,frac_cen}.v -o sim && sim -lxt
