#!/bin/bash

iverilog test.v ../../hdl/keyboard/jt4701.v -o sim && sim -lxt
