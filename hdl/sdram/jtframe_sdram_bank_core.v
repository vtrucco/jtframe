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

module jtframe_sdram_bank_core(
    input               rst,
    input               clk,
    input      [  22:0] addr,
    input               rd,
    input               wr,
    input      [   1:0] ba_rq,
    output reg          ack,
    output reg          rdy,
    output reg [   1:0] ba_rdy,
    input      [  15:0] din,
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

localparam ROW=13, COW=10,
           BQL=4,
           READ_BIT = 2, DQLO_BIT=5, DQHI_BIT=6;

localparam CMD_LOAD_MODE   = 4'b0000, // 0
           CMD_AUTOREFRESH = 4'b0001, // 1
           CMD_PRECHARGE   = 4'b0010, // 2
           CMD_ACTIVE      = 4'b0011, // 3
           CMD_WRITE       = 4'b0100, // 4
           CMD_READ        = 4'b0101, // 5
           CMD_STOP        = 4'b0110, // 6 Burst terminate
           CMD_NOP         = 4'b0111, // 7
           CMD_INHIBIT     = 4'b1000; // 8

reg       [7:0] ba0_st, ba1_st, ba2_st, ba3_st, all_st;
reg             activate, read, get_low, get_high, post_act;
reg       [3:0] cmd;
reg      [15:0] dq_pad, dq_ff, dq_ff0;

reg [  COW-1:0] col_fifo[0:1];
reg [      1:0] ba_fifo[0:1];
reg [BQL*2-1:0] ba_queue;

// SDRAM pins
assign {sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe } = cmd;
assign sdram_cke = 1;
assign { sdram_dqmh, sdram_dqml } = sdram_a[12:11]; // This is a limitation in MiSTer's 128MB module
assign sdram_dq = dq_pad;


assign dout = { dq_ff, dq_ff0 };

function [7:0] next;
    input [7:0] cur;
    input [1:0] ba;
    // state shits automatically after READ command has been issued
    // states shifts from 0 bit on ACTIVE cmd
    // states shifts from 2 bit on READ cmd
    next = ((activate && ba_rq==ba) || (read && ba_fifo[0]==ba) || (!cur[0] && !cur[1]) ) ?
           { cur[6:0], cur[7] } :  // advance
           cur; // wait
endfunction

always @(*) begin
    all_st   =  ba0_st | ba1_st | ba2_st | ba3_st;
    activate = !all_st[READ_BIT] && rd;
    read     =  all_st[READ_BIT];
    get_low  =  all_st[DQLO_BIT];
    get_high =  all_st[DQHI_BIT];
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ba0_st   <= 8'd1;
        ba1_st   <= 8'd1;
        ba2_st   <= 8'd1;
        ba3_st   <= 8'd1;
        // SDRAM pins
        cmd      <= CMD_NOP;
        dq_pad   <= 16'hzzzz;
        sdram_a  <= 13'd0;
        sdram_ba <= 2'd0;
        // output signals
        ack      <= 0;
        rdy      <= 0;
        ba_rdy   <= 0;
        dq_ff    <= 16'd0;
        dq_ff0   <= 16'd0;
    end else begin
        ba0_st <= next( ba0_st, 2'd0 );
        ba1_st <= next( ba1_st, 2'd1 );
        ba2_st <= next( ba2_st, 2'd2 );
        ba3_st <= next( ba3_st, 2'd3 );
        ba_queue[ (BQL-1)*2-1: 0 ] <= ba_queue[ BQL*2-1: 2 ];
        // output strobes
        rdy    <= all_st[DQHI_BIT];
        ba_rdy <= ba_queue[1:0];
        // Default transitions
        cmd    <= CMD_NOP;

        if( activate ) begin
            cmd           <= CMD_ACTIVE;
            sdram_ba      <= ba_rq;
            ba_fifo[1]    <= ba_rq;
            ack           <= 1;
            post_act      <= 1;
            { sdram_a, col_fifo[1] } <= addr;
        end
        if( post_act ) begin
            col_fifo[0] <= col_fifo[1];
            ba_fifo[0]  <= ba_fifo[1];
            ack         <= 0;
            post_act    <= 0;
        end
        if( read ) begin
            cmd           <= CMD_READ;
            sdram_a[12:11]<= 2'b00; // DQM signals
            sdram_a[10]   <= 1;     // precharge
            sdram_a[9:0]  <= col_fifo[0];
            sdram_ba      <= ba_fifo[0];
            ba_queue[BQL*2-1:(BQL-1)*2] <= ba_fifo[0];
        end
        if( get_low ) begin
            dq_ff  <= dq_pad;
        end
        if( get_high ) begin
            dq_ff0 <= dq_ff;
            dq_ff  <= dq_pad;
        end
    end
end

endmodule