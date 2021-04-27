// SDRAM is set to burst=2 (64 bits)

module jtframe_sdram64_bank #(
    parameter AW=22,
              HF=1,     // 1 for HF operation (idle cycles), 0 for LF operation
                        // HF operation starts at 66.6MHz (1/15ns)
              SHIFTED=0,
              BANKLEN=1 // 1=16 bits, 2=32 bits, 4=64 bits
)(
    input               rst,
    input               clk,

    // requests
    input      [AW-1:0] addr,
    input               rd,
    input               wr,

    output reg          ack,
    output              dst,    // data starts
    output              dbusy,
    output              rdy,

    // SDRAM interface
    output reg          br, // bus request
    input               bg, // bus grant

    // SDRAM_A[12:11] and SDRAM_DQML/H are controlled in a way
    // that can be joined together thru an OR operation at a
    // higher level. This makes it possible to short the pins
    // of the SDRAM, as done in the MiSTer 128MB module
    output reg  [12:0]  sdram_a,        // SDRAM Address bus 13 Bits
    output reg  [ 3:0]  cmd
);

localparam ROW=13,
           COW= AW==22 ? 9 : 10, // 9 for 32MB SDRAM, 10 for 64MB
           STW= 15-(HF?0:2);

// states
localparam IDLE    = 0,
           // PRECHARGE 1+2(1)
           PRE_ACT = HF ? 3:2,
           PRE_RD  = PRE_ACT + (HF ? 3:2),
           READ    = PRE_RD+1,
           DST     = PRE_RD + 2,
           RDY     = DST + 2 + (BANKLEN==1 ? 1 : (BANKLEN==2? 2 : 4));

//                             /CS /RAS /CAS /WE
localparam CMD_LOAD_MODE   = 4'b0___0____0____0, // 0
           CMD_REFRESH     = 4'b0___0____0____1, // 1
           CMD_PRECHARGE   = 4'b0___0____1____0, // 2
           CMD_ACTIVE      = 4'b0___0____1____1, // 3
           CMD_WRITE       = 4'b0___1____0____0, // 4
           CMD_READ        = 4'b0___1____0____1, // 5
           CMD_STOP        = 4'b0___1____1____0, // 6 Burst terminate
           CMD_NOP         = 4'b0___1____1____1, // 7
           CMD_INHIBIT     = 4'b1___0____0____0; // 8


reg            prechd;
reg  [ROW-1:0] row;
wire [ROW-1:0] addr_row;
reg  [STW-1:0] st, next_st;

reg            adv, do_prech, do_act, do_read;

// SDRAM pins
assign ack   = st[READ],
       dst   = st[DST],
       dbusy = |st[RDY:DST],
       rdy   = st[RDY];
assign addr_row = AW==22 ? addr[AW-1:AW-ROW] : addr[AW-2:AW-1-ROW];

always @(*) begin
    adv=0;
    if( st[IDLE] && rd && br ) adv=1;
    if( (st[PRE_ACT] || st[PRE_RD]) && br ) adv=1;
    if( !st[IDLE] && !st[PRE_ACT] && !st[PRE_RD] ) adv=1;
    next_st = adv ? { st[STW-2:0], st[STW-1] } : st;
end

always @(*) begin
    do_prech = 0;
    do_act   = 0;
    do_read  = 0;
    br       = 0;
    if( (st[IDLE] || st[PRE_ACT] || st[PRE_RD]) && rd ) begin
        br = 1;
        if( !prechd ) begin // not precharge, there is an address in the row
            if( bg ) begin
                do_prech = row != addr_row; // not a good address
                do_read  = ~do_prech; // good address
            end
        end else begin
            do_act = 1;
        end
    end
end

// module outputs
always @(*) begin
    cmd = do_prech ? CMD_PRECHARGE : (
          do_act   ? CMD_ACTIVE    : (
          do_read  ? CMD_READ      : CMD_NOP ));
    sdram_a = do_read ? { 3'b0, // no precharge
                               addr[AW-1], addr[8:0] } :
                        addr_row; // do_act
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prechd   <= 1;
        row      <= 0;
        st       <= 1; // IDLE
    end else begin
        st  <= next_st;
        if( do_act ) begin
            row     <= addr_row;
            prechd  <= 0;
        end
        if( do_prech ) prechd <= 1;
    end
end

endmodule
