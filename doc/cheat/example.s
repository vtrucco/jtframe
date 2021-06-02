; SDRAM_ADDR0 DSOUT  $0
; SDRAM_ADDR1 DSOUT  $1
; SDRAM_ADDR2 DSOUT  $2
; SDRAM_DOUT0 DSIO   $3
; SDRAM_DOUT1 DSIO   $4
; SDRAM_MASK  DSIO   $5
; SDRAM_DIN0  DSIN   $6
; SDRAM_DIN1  DSIN   $7
; SDRAM_READ  DSOUT  $80
; SDRAM_WRITE DSOUT  $C0
; WATCHDOG    DSOUT  $40
;
; SDRAM_ST    DSIN   $80
; FLAG0       DSIN   $10
; FLAG1       DSIN   $11

    enable interrupt
BEGIN:
    output s0,0x40
    jump BEGIN

ISR:
    ; interrupt routine
    input s0,0x10
    test  s0,1      ; bit 0 enables
    jump Z,TEST_FLAG1
    ; FF02E8=09 Infinite Credits
    load  s1,0xe8
    output s1,0
    load  s1,0x02
    output s1,1
    load  s1,0xff
    output s1,2
    load  s1,0x09
    output s1,3
    load  s1,0x2
    output s1,5
    call  WRITE_SDRAM
TEST_FLAG1:


    returni ENABLE

WRITE_SDRAM:
    output s1, 0xC0   ; s1 value doesn't matter
.loop:
    input  s1, 0x80
    compare s1, 0xC0
    return z
    jump .loop

    address 3FF    ; interrupt vector
    jump ISR