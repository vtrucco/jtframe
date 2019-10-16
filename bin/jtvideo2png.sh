#!/bin/bash

CONVERT_OPTIONS="-resize 300%x300%"
MODULES=$JTGNG/modules

rm -f video*.raw
$MODULES/jtframe/bin/bin2raw
for i in video*.raw; do
    filename=$(basename $i .raw).jpg
    if [ -e $filename ]; then
        rm $i       # delete the raw file
        continue    # do not overwrite
    fi
    convert $CONVERT_OPTIONS -size 256x224 \
        -depth 8 RGBA:$i $filename && rm $i
done
