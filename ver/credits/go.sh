#!/bin/bash

iverilog test.v ../../hdl/video/jtframe_credits.v ../../hdl/ram/jtframe_ram.v -o sim && sim -lxt