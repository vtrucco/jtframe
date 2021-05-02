/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 29-4-2021 */

// SDRAM is set to burst=2 (64 bits)

module jtframe_sdram64_bank #(
    parameter AW=22,
              HF=1,     // 1 for HF operation (idle cycles), 0 for LF operation
                        // HF operation starts at 66.6MHz (1/15ns)
              SHIFTED      =0,
              AUTOPRECH    =0,
              PRECHARGE_ALL=0,
              BALEN        =64, // 16, 32 or 64 bits
              BURSTLEN     =64,
              READONLY     =0   // set to 1 if ALL BANKS can only read
                                // this will make dbusy64 match dbusy
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
    input               set_prech,

    output              dbusy,      // DQ bus busy (read values only)
    output              dbusy64,    // DQ bus busy (the full four clock cycles)
    output              dqm_busy,   // DQM lines are used
    input               all_dbusy,
    input               all_dbusy64,
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
           COW= AW==22 ? 9 : 10; // 9 for 32MB SDRAM, 10 for 64MB

// states
localparam IDLE    = 0,
           // AUTOPRECH 1+2(1)
           PRE_ACT = HF ? 3:2,
           ACT     = PRE_ACT+1,
           PRE_RD  = PRE_ACT + (HF ? 3:2),
           READ    = PRE_RD+1,
           DST     = READ + (SHIFTED ? 1 : 2) ,
           DTICKS  = BURSTLEN==64 ? 4 : (BURSTLEN==32?2:1),
           STW= 9+DTICKS-(HF?0:2) -((AUTOPRECH||!READONLY) ? 0 : (BURSTLEN-BALEN)),
           BUSY    = DST+(DTICKS-1),
           RDY     = DST + (BALEN==16 ? 0 : (BALEN==32? 1 : 3));

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
/*
`ifdef SIMULATION
initial begin
    $display("%m\n\tREAD=%2d\n\tDST=%2d\n\tRDY=%2d\n\tSTW=%2d",READ,DST,RDY,STW);
end
`endif
*/
reg            actd, prechd;
reg  [ROW-1:0] row;
wire [ROW-1:0] addr_row;
reg  [STW-1:0] st, next_st, rot_st;
reg  [    1:0] last_act;
wire           rd_wr;

reg            adv, do_prech, do_act, do_read;

// state phases
reg            in_busy, in_busy64;

// SDRAM pins
assign ack      = st[READ],
       dst      = st[DST] | (st[READ] & wr),
       dbusy    = |{in_busy, do_read},
       dbusy64  = READONLY ? dbusy : |{in_busy64, do_read},
       post_act = |last_act,
       dok      = |st[RDY:DST],
       rdy      = st[RDY] | (st[READ] & wr),
       dqm_busy = |{st[RDY-2:READ]},
       addr_row = AW==22 ? addr[AW-1:AW-ROW] : addr[AW-2:AW-1-ROW],
       rd_wr    = rd | wr;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        in_busy   <= 0; // |st[ (BALEN==16? READ+1 : RDY-2):READ]
        in_busy64 <= 0; // |{st[BUSY:READ], do_read},
    end else begin
        if(next_st[READ]) in_busy <= 1;
        else if( st[(BALEN==16? READ+1 : RDY-2)] || next_st[READ-1:0]!=0 ) in_busy<=0;

        if(next_st[READ]) in_busy64 <= 1;
        else if( st[BUSY] || next_st[READ-1:0]!=0 ) in_busy64<=0;

    end
end

always @(*) begin
    adv=0;
    rot_st  = { st[STW-2:0], st[STW-1] };
    next_st = st;
    if( st[IDLE] && rd_wr && bg ) begin
        if(do_prech) next_st = rot_st;
        if(do_act  ) next_st = 1<<ACT;
        if(do_read ) next_st = 1<<READ;
    end
    if( ( st[PRE_RD]  && bg && !all_dqm            ) ||
        ( st[PRE_ACT] && bg && !all_dqm && !all_act) ||
        ( !st[IDLE] && !st[PRE_ACT] && !st[PRE_RD] ) )
          next_st = rot_st;
    if( st[READ] && wr && !AUTOPRECH)
        next_st <= 1; // writes finish earlier
end

always @(*) begin
    do_prech = 0;
    do_act   = 0;
    do_read  = 0;
    br       = 0;
    if( (st[IDLE] || st[PRE_ACT] || st[PRE_RD]) && rd_wr ) begin
        br = 1;
        if( st[PRE_RD] & ((all_dbusy&rd) | (all_dbusy64&wr)) ) br = 0; // Do not try to request
        if( !prechd || !actd ) begin // not precharge (address in the row) or not activated
            if( bg ) begin
                do_prech = !actd || row != addr_row; // not a good address
                do_read  = actd & ~do_prech & ~all_dbusy & (~all_dbusy64 | rd) & ~all_dqm; // good address
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
          do_read  ? (rd ? CMD_READ : CMD_WRITE ) : CMD_NOP ));
    sdram_a = do_read ? { 2'b0,
                          AUTOPRECH,
                          addr[AW-1], addr[8:0] } :
             (do_act ? addr_row : {2'b0, PRECHARGE_ALL, 10'd0});
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prechd   <= 0;
        actd     <= 0;
        row      <= 0;
        st       <= 1; // IDLE
        last_act <= 0;
    end else begin
        st       <= next_st;
        last_act <= { do_act, last_act[1] };

        if( do_act ) begin
            row     <= addr_row;
            prechd  <= 0;
            actd    <= 1;
        end

        if( do_prech || set_prech || (do_read && AUTOPRECH)) begin
            prechd <= 1;
            actd   <= 1;
        end
    end
end

endmodule
