#!/usr/bin/awk -f
# invocation example
# target must come before the name of the file
# gawk -f jtmacro.sh  target=mister macros
BEGIN { 
    FS="|" 
    dump=0
}
/[ \t]*#/ {
    next
}
/\[.*\]/ { 
    sub(/^\[/,"")
    sub(/\]$/,"")
    dump=0
    for( i=1; i<=NF; i++ )
        if ($i == "all" || $i == target ) {
            dump=1
        }
    next
    }
# Convert only lines that start with a letter
/^[a-zA-Z]/{
    if(dump) {
        printf "set_global_assignment -name VERILOG_MACRO \"%s\"\n",$0
    }
    next
}
/[^ \t]/{
    print "ERROR: cannot process line " $0
    exit
}
END {
    # Adds a blanks line
    print 
}