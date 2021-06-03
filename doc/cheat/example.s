; Assemble with: opbasm example.s -m 1024 -x -6
; Convert to 8-bit hex dump with: pico2hex example.hex
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

    ; enable interrupt
    load sa,0   ; SA = frame counter, modulo 60
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
    ; interrupt routine
    input sf,0x10
    test  sf,1      ; bit 0
    jump Z,TEST_FLAG1
    ; FF02E8=09 Infinite Credits
    load  s0,0xe8
    load  s1,0x02
    load  s2,0xff
    load  s3,0x09
    load  s4,0
    load  s5,2
    call  WRITE_SDRAM

TEST_FLAG1:
    input sf,0x10
    test  sf,2      ; bit 1
    jump Z,TEST_FLAG2
    ; FF02E8=09 Infinite Lives
    load  s0,0xf2
    load  s1,0xf5
    load  s2,0xff
    load  s3,0x09
    load  s4,0
    load  s5,2
    call  WRITE_SDRAM

TEST_FLAG2:
    input sf,0x10
    test  sf,2      ; bit 1
    jump Z,TEST_FLAG3
    ; FF877A=FF once per second Invincibility
    compare sa,0
    jump nz,TEST_FLAG3
    load  s0,0xf2
    load  s1,0xf5
    load  s2,0xff
    load  s3,0x09
    load  s4,0
    load  s5,2
    call  WRITE_SDRAM

TEST_FLAG3:

    ; Frame counter
    add sa,1
    compare sa,60'd
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