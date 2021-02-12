#!/bin/bash

iverilog test.v ../../hdl/mister/jtframe_db*.v -o sim && sim -lxt

