; use "cheatzip" script to assemble and send to MiSTer

; The LED will blink if the cheat bits 7:0 are enabled
; CPSx work RAM offset = 30'0000h

; Register use
; SA = frame counter
; SB = LED

    ; enable interrupt
    load sa,0   ; SA = frame counter, modulo 60
    load sb,0
BEGIN:
    output s0,0x40

    ; Detect blanking
    input s0,0x80
    and   s0,0x20;   test for blanking
    jump z,inblank
    jump notblank
inblank:
    fetch s1,0
    test s1,0x20
    jump z,notblank
    store s0,0  ; stores last LVBL
    call ISR ; do blank procedure
    jump BEGIN
notblank:
    store s0,0
    jump BEGIN

ISR:
    input sf,0x10
    test sf,0xff
    jump z,.nothing

    compare sa,0
    jump nz,PARSE_FLAGS
    ; invert LED signal
    add sb,1
    jump PARSE_FLAGS
.nothing:
    load sb,0      ; turn off LED
    jump CLOSE_FRAME

PARSE_FLAGS:
    input sf,0x10
    and   sf,7      ; bits 2:0
    jump Z,CLOSE_FRAME
    ; P1 weapon selection
    ; FF07C6=weapon  -> (7C6/2+30'0000) = 3003e3
    load  s0,0xe3
    load  s1,0x03
    load  s2,0x30
    load  s3,0
    load  s4,sf
    sub   s4,1  ; weapon code starts from 0
    load  s5,1
    call  WRITE_SDRAM

CLOSE_FRAME:
    output sb,6     ; LED
    ; Frame counter
    add sa,1
    compare sa,59'd
    jump nz,.else
    load sa,0
.else:
    return
    ;returni ENABLE

    ; SDRAM address in s2-s0
    ; SDRAM data out in s4-s3
    ; SDRAM data mask in s5
    ; Modifies sf
WRITE_SDRAM:
    output s5, 5
    output s4, 4
    output s3, 3
    output s2, 2
    output s1, 1
    output s0, 0
    output s1, 0xC0   ; s1 value doesn't matter
.loop:
    input  sf, 0x80
    compare sf, 0xC0
    return z
    jump .loop

default_jump fatal_error
fatal_error:
    jump fatal_error

    address 3FF    ; interrupt vector
    jump ISR