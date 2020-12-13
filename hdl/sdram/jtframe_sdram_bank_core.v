/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 29-11-2020 */


// This controller uses bank interleaving. It can achieve 66% efficiency
// Efficiency is measured as number of clock cycles in which data is being read
// It is possible to get 80% efficiency by issuing ACTIVE commands without
// a NOP in between. But there is a hard limitation in SDRAM clock frequency
// then at ~70MHz. Nonetheless, at 90% efficiency means that 70MHz@90% is
// as good as 96MHz@66%
// This controller, as it is, cannot make it to 90% as it is designed to have
// the NOP in between. That means that when used at 48MHz we are not operating
// at the highest theoretical efficiency
// More than 90% is not possible with only 4 banks and 2-word bursts. With
// longer bursts, it would be possible to keep the SDRAM busy permanently.

// AW      |  Bank size        |  Total size
// 22      |  4 MBx2 = 8MB     |   32 MB
// 23      |  8 MBx2 =16MB     |   64 MB

module jtframe_sdram_bank_core #(parameter AW=22)(
    input               rst,
    input               clk,
    // requests
    input      [AW-1:0] addr,
    input               rd,
    input               wr,
    input               rfsh_en,   // ok to refresh
    input      [   1:0] ba_rq,
    output reg [   1:0] ba_rdy,
    input      [  15:0] din,
    input      [   1:0] din_m,  // write mask

    output reg          ack,
    output reg          rdy,
    output     [  31:0] dout,

    // SDRAM interface
    // SDRAM_A[12:11] and SDRAM_DQML/H are controlled in a way
    // that can be joined together thru an OR operation at a
    // higher level. This makes it possible to short the pins
    // of the SDRAM, as done in the MiSTer 128MB module
    inout       [15:0]  sdram_dq,       // SDRAM Data bus 16 Bits
    output reg  [12:0]  sdram_a,        // SDRAM Address bus 13 Bits
    output              sdram_dqml,     // SDRAM Low-byte Data Mask
    output              sdram_dqmh,     // SDRAM High-byte Data Mask
    output reg  [ 1:0]  sdram_ba,       // SDRAM Bank Address
    output              sdram_nwe,      // SDRAM Write Enable
    output              sdram_ncas,     // SDRAM Column Address Strobe
    output              sdram_nras,     // SDRAM Row Address Strobe
    output              sdram_ncs,      // SDRAM Chip Select
    output              sdram_cke       // SDRAM Clock Enable
);

localparam ROW=13,
           COW= AW==22 ? 9 : 10, // 9 for 32MB SDRAM, 10 for 64MB
           BQL=4,
           READ_BIT = 2, DQLO_BIT=5, DQHI_BIT=6;

localparam CMD_LOAD_MODE   = 4'b0000, // 0
           CMD_REFRESH     = 4'b0001, // 1
           CMD_PRECHARGE   = 4'b0010, // 2
           CMD_ACTIVE      = 4'b0011, // 3
           CMD_WRITE       = 4'b0100, // 4
           CMD_READ        = 4'b0101, // 5
           CMD_STOP        = 4'b0110, // 6 Burst terminate
           CMD_NOP         = 4'b0111, // 7
           CMD_INHIBIT     = 4'b1000; // 8

localparam [13:0] INIT_WAIT = 14'd10_000;

`ifdef MISTER
`define JTFRAME_SDRAM_ADQM
`endif

`ifdef JTFRAME_SDRAM_ADQM
localparam ADQM = 1;
`else
localparam ADQM = 0;
`endif

// initialization signals
reg [13:0] wait_cnt;
reg [ 2:0] init_st;
reg [ 3:0] init_cmd;
reg        init;

reg       [7:0] ba0_st, ba1_st, ba2_st, ba3_st, all_st;
reg             activate, read, get_low, get_high, post_act, wrtng;
reg             hold_bus;
reg       [3:0] cmd;
reg       [1:0] dqm;
reg       [1:0] wrmask;
reg      [15:0] dq_pad, dq_ff, dq_ff0;
reg             rfshing, refresh, end_rfsh;

reg [  COW-1:0] col_fifo[0:1];
reg [      1:0] ba_fifo[0:1];
reg [BQL*2-1:0] ba_queue;

wire      [1:0] req_a12;
wire            dqmbusy;

// SDRAM pins
assign {sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe } = cmd;
assign sdram_cke = 1;
assign sdram_dq = dq_pad;

assign req_a12 = addr[AW-1:AW-2];
assign { sdram_dqmh, sdram_dqml } =  ADQM ? sdram_a[12:11] : dqm; // This is a limitation in MiSTer's 128MB module

assign dout = { dq_ff, dq_ff0 };

// Theoretically, if the SDRAM connection is good, it is enough
// to just skip all_st[3], but this seems to fail more with the
// actual SDRAM
`ifdef JTFRAME_SDRAM_ADQM_SAFE
assign dqmbusy = all_st[5:3]!=3'd0;
`else
assign dqmbusy = all_st[3];
`endif

`ifdef SIMULATION
wire [9:0] col_fifo0 = col_fifo[0];
wire [9:0] col_fifo1 = col_fifo[1];
`endif

function [7:0] next;
    input [7:0] cur;
    input [1:0] ba;
    // state shifts automatically after READ command has been issued
    // state shifts from 0 bit on ACTIVE cmd
    // state shifts from 2 bit on READ cmd
    next = ((activate && ba_rq==ba) || (read && ba_fifo[0]==ba) || (!cur[0] && !cur[2]) ) || rfshing ?
           { cur[6:0], cur[7] } :  // advance
           cur; // wait
endfunction

always @(*) begin
    all_st   =  ba0_st | ba1_st | ba2_st | ba3_st;
    `ifndef JTFRAME_NOHOLDBUS
    hold_bus =  all_st[6:4]==2'd0; // next cycle will be a bus access
    `else
    hold_bus = 0;
    `endif
    activate = ( (!all_st[READ_BIT] && rd ) || (!all_st[6:2] && wr)) && !rfshing;
    case( ba_rq )
        2'd0: if( !ba0_st[0] ) activate = 0;
        2'd1: if( !ba1_st[0] ) activate = 0;
        2'd2: if( !ba2_st[0] ) activate = 0;
        2'd3: if( !ba3_st[0] ) activate = 0;
    endcase
    read     = all_st[READ_BIT] && !rfshing;
    // prevents overwritting A12/A11 with values incompatible with a 16-bit read
    // on MiSTer
    if( dqmbusy && req_a12 != 2'd00 && ADQM ) begin
        activate = 0;
        read     = 0;
    end
    refresh  = all_st[7:1]==7'd0 && rfsh_en && !rd && !wr && !rfshing;
    end_rfsh = rfshing && all_st[7];
    get_low  = all_st[DQLO_BIT] && !rfshing;
    get_high = all_st[DQHI_BIT] && !rfshing;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ba0_st   <= 8'd1;
        ba1_st   <= 8'd1;
        ba2_st   <= 8'd1;
        ba3_st   <= 8'd1;
        rfshing  <= 0;
        wrtng    <= 0;
        // initialization loop
        init     <= 1;
        wait_cnt <= INIT_WAIT; // wait for 100us
        init_st  <= 3'd0;
        init_cmd <= CMD_NOP;
        // SDRAM pins
        cmd      <= CMD_NOP;
        dq_pad   <= 16'hzzzz;
        sdram_a  <= 13'd0;
        sdram_ba <= 2'd0;
        // output signals
        ack      <= 0;
        rdy      <= 0;
        ba_rdy   <= 0;
        ba_queue <= {BQL*2{1'b0}};
        dq_ff    <= 16'd0;
        dq_ff0   <= 16'd0;
    end else if( init ) begin
        if( |wait_cnt ) begin
            wait_cnt <= wait_cnt-14'd1;
            init_cmd <= CMD_NOP;
            cmd      <= init_cmd;
        end else begin
            if(!init_st[2]) init_st <= init_st+3'd1;
            case(init_st)
                3'd0: begin
                    init_cmd   <= CMD_PRECHARGE;
                    sdram_a[10]<= 1; // all banks
                    wait_cnt   <= 14'd2;
                end
                3'd1: begin
                    init_cmd <= CMD_REFRESH;
                    wait_cnt <= 14'd11;
                end
                3'd2: begin
                    init_cmd <= CMD_REFRESH;
                    wait_cnt <= 14'd11;
                end
                3'd3: begin
                    init_cmd <= CMD_LOAD_MODE;
                    sdram_a  <= 13'b00_1_00_010_0_001; // CAS Latency = 2, burst = 2
                    wait_cnt <= 14'd3;
                end
                3'd4: begin
                    init <= 0;
                end
                default: begin
                    cmd  <= init_cmd;
                    init <= 0;
                end
            endcase
        end
    end else begin // Regular operation
        //if(!wrtng) dq_pad <= hold_bus ? 16'd0 : 16'hzzzz;
        if(!wrtng) dq_pad <= 16'hzzzz;
        ba0_st <= next( ba0_st, 2'd0 );
        ba1_st <= next( ba1_st, 2'd1 );
        ba2_st <= next( ba2_st, 2'd2 );
        ba3_st <= next( ba3_st, 2'd3 );
        ba_queue[ (BQL-1)*2-1: 0 ] <= ba_queue[ BQL*2-1: 2 ];
        // Default transitions
        cmd    <= CMD_NOP;

        if( refresh ) begin
            cmd         <= CMD_REFRESH;
            sdram_a[10] <= 1;
            rfshing     <= 1;
        end else if( end_rfsh ) begin
            rfshing  <= 0;
        end
        if( activate ) begin
            cmd           <= CMD_ACTIVE;
            sdram_ba      <= ba_rq;
            ba_fifo[1]    <= ba_rq;
            wrtng         <= wr;
            wrmask        <= din_m;
            ack           <= 1;
            post_act      <= 1;
            { sdram_a, col_fifo[1] } <= addr;
            if( wr ) dq_pad <= din;
        end
        if( post_act ) begin
            col_fifo[0] <= col_fifo[1];
            ba_fifo[0]  <= ba_fifo[1];
            ack         <= 0;
            post_act    <= 0;
        end
        if( read ) begin
            if( ADQM )
                // A12 and A11 used as mask in MiSTer 128MB module
                sdram_a[12:11] <= wrtng ? wrmask : 2'b00;
            else
                dqm            <= wrtng ? wrmask : 2'b00;
            cmd              <= wrtng ? CMD_WRITE : CMD_READ;
            sdram_a[10]      <= 1;     // precharge
            sdram_a[COW-1:0] <= col_fifo[0];
            sdram_ba         <= ba_fifo[0];
            ba_queue[BQL*2-1:(BQL-1)*2] <= ba_fifo[0];
        end
        if( get_low ) begin
            dq_ff  <= sdram_dq;
        end
        if( get_high ) begin
            dq_ff0 <= dq_ff;
            dq_ff  <= sdram_dq;
            // output strobes
            rdy    <= 1;
            ba_rdy <= ba_queue[1:0];
        end
        else rdy <= 0;
    end
end

endmodule