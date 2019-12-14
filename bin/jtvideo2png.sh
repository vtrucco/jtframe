#!/bin/bash

W=256

CONVERT_OPTIONS="-resize 300%x300%"
MODULES=$JTGNG/modules

while [ $# -gt 0 ]; do
    case "$1" in
        -w) shift; W=$1;;
        *) echo "Unknown argument $1"; exit 1;;
    esac
    shift
done


rm -f video*.raw
$MODULES/jtframe/bin/bin2raw
for i in video*.raw; do
    filename=$(basename $i .raw).jpg
    if [ -e $filename ]; then
        rm $i       # delete the raw file
        continue    # do not overwrite
    fi
    filelen=$(stat -c%s $i)
    # File height is calculated from the file size directly
    H=$((filelen/W/4))
    convert $CONVERT_OPTIONS -size ${W}x${H} \
        -depth 8 RGBA:$i $filename && rm $i
done
