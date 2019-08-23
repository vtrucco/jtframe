#!/bin/bash

iverilog -DSIMULATION -DDUMP test.v ../../hdl/mister/sys/osd.sv -g2005-sv -o sim && sim -lxt

echo "Converting the video output to video.png"
octave << 'EOF'
load video_dump.m
imwrite(video_dump,"video.png")
exit
EOF

