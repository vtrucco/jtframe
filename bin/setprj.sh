#!/bin/bash
# Define JTROOT before sourcing this file

if (echo $PATH | grep modules/jtframe/bin -q); then
    unalias jtcore
    PATH=$(echo $PATH | sed 's/:[^:]*jtframe\/bin//g')
    PATH=$(echo $PATH | sed 's/:\.//g')
    unset VER GAME VIDEO HDL OKI
    unset JT12 JT51 CC MRA ROM CORES
fi

export JTROOT=$(pwd)
export JTFRAME=$JTROOT/modules/jtframe
# . path comes before JTFRAME/bin as setprj.sh
# can be in the working directory and in JTFRAME/bin
PATH=$PATH:.:$JTFRAME/bin
#unalias jtcore
alias jtcore="$JTFRAME/bin/jtcore"

# derived variables
if [ -e $JTROOT/cores ]; then
    export CORES=$JTROOT/cores
    # Adds all core names to the auto-completion list of bash
    echo $CORES
    ALLFOLDERS=
    for i in $CORES/*; do
        j=$(basename $i)
        if [[ -d $i && $j != modules ]]; then
            ALLFOLDERS="$ALLFOLDERS $j "
        fi
    done
    complete -W "$ALLFOLDERS" jtcore
    complete -W "$ALLFOLDERS" swcore
    unset ALLFOLDERS
else
    export CORES=$JTROOT
fi

export ROM=$JTROOT/rom
CC=$JTROOT/cc
DOC=$JTROOT/doc
MRA=$ROM/mra
export MODULES=$JTROOT/modules
JT12=$MODULES/jt12
JT51=$MODULES/jt51

