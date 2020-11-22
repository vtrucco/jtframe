#!/bin/bash

iverilog test.v ../../hdl/sound/jtframe_{uprate2_fir,fir2}.v -o sim && sim -lxt
