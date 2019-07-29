#!/bin/bash

iverilog -d SIMULATION test.v ../../hdl/mister/sys/osd.sv -g2005-sv -o sim && sim -lxt