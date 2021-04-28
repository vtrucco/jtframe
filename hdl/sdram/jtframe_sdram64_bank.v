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

    output              ack,
    output              dst,    // data starts
    output              dok,    // data ok
    output              rdy,

    output              dbusy,
    output              dqm_busy,   // DQM lines are used
    input               all_dbusy,
    input               all_dqm,

    output              post_act, // cycles banned for activate (tRRD)
    input               all_act,

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
           ACT     = PRE_ACT+1,
           PRE_RD  = PRE_ACT + (HF ? 3:2),
           READ    = PRE_RD+1,
           DST     = READ + 2,
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
reg  [STW-1:0] st, next_st, rot_st;
reg  [    1:0] last_act;

reg            adv, do_prech, do_act, do_read;

// SDRAM pins
assign ack      = st[READ],
       dst      = st[DST],
       dbusy    = |{st[RDY-3:READ], do_read},
       post_act = |last_act,
       dok      = |st[RDY:DST],
       rdy      = st[RDY],
       dqm_busy = |{st[RDY-2:READ]},
       addr_row = AW==22 ? addr[AW-1:AW-ROW] : addr[AW-2:AW-1-ROW];

always @(*) begin
    adv=0;
    rot_st  = { st[STW-2:0], st[STW-1] };
    next_st = st;
    if( st[IDLE] && rd && bg ) begin
        if(do_prech) next_st = rot_st;
        if(do_act  ) next_st = 1<<ACT;
        if(do_read ) next_st = 1<<READ;
    end
    if( ( st[PRE_RD]  && bg && !all_dqm            ) ||
        ( st[PRE_ACT] && bg && !all_dqm && !all_act) ||
        ( !st[IDLE] && !st[PRE_ACT] && !st[PRE_RD] ) )
          next_st = rot_st;
end

always @(*) begin
    do_prech = 0;
    do_act   = 0;
    do_read  = 0;
    br       = 0;
    if( (st[IDLE] || st[PRE_ACT] || st[PRE_RD]) && rd ) begin
        br = 1;
        if( st[PRE_RD] & all_dbusy ) br = 0; // Do not try to request
        if( !prechd ) begin // not precharge, there is an address in the row
            if( bg ) begin
                do_prech = row != addr_row; // not a good address
                do_read  = ~do_prech & ~all_dbusy & ~all_dqm; // good address
            end
        end else if(bg) begin
            do_act = ~all_act & ~all_dqm;
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
             (do_act ? addr_row : 13'd0);
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prechd   <= 1;
        row      <= 0;
        st       <= 1; // IDLE
        last_act <= 0;
    end else begin
        st       <= next_st;
        last_act <= { do_act, last_act[1] };

        if( do_act ) begin
            row     <= addr_row;
            prechd  <= 0;
        end

        if( do_prech ) prechd <= 1;
    end
end

endmodule
