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
    Date: 30-11-2020 */


// Macros used
// JTFRAME_SDRAM_BWAIT      0-15    adds extra wait cycles in between requests
// JTFRAME_SDRAM_MUXLATCH           enables an extra latch stage to the SDRAM core
//                                  If HF parameter is set, the extra stage is always added
//                                  as it doesn't impact latency in that case.
// JTFRAME_SDRAM_REPACK             enables an extra latch stage to the game core

`ifndef JTFRAME_SDRAM_BWAIT
`define JTFRAME_SDRAM_BWAIT 0
`endif

module jtframe_sdram_bank_mux #(
    parameter AW=22,
              HF=1      // 1 for HF operation (idle cycles), 0 for LF operation
                        // HF operation starts at 66.6MHz (1/15ns)
) (
    input               rst,
    input               clk,

    // Bank 0: allows R/W
    input      [AW-1:0] ba0_addr,
    input               ba0_rd,
    input               ba0_wr,
    input      [  15:0] ba0_din,
    input      [   1:0] ba0_din_m,  // write mask
    output reg          ba0_rdy,
    output              ba0_ack,

    // Bank 1: Read only
    input      [AW-1:0] ba1_addr,
    input               ba1_rd,
    output reg          ba1_rdy,
    output              ba1_ack,

    // Bank 2: Read only
    input      [AW-1:0] ba2_addr,
    input               ba2_rd,
    output reg          ba2_rdy,
    output              ba2_ack,

    // Bank 3: Read only
    input      [AW-1:0] ba3_addr,
    input               ba3_rd,
    output reg          ba3_rdy,
    output              ba3_ack,

    // ROM downloading
    input               prog_en,
    input      [AW-1:0] prog_addr,
    input      [   1:0] prog_ba,     // bank
    input               prog_rd,
    input               prog_wr,
    input      [  15:0] prog_din,
    input      [   1:0] prog_din_m,  // write mask
    output              prog_rdy,

    // Signals to SDRAM controller
    output     [AW-1:0] ctl_addr,
    output              ctl_rd,
    output              ctl_wr,
    output         reg  ctl_rfsh_en,   // ok to refresh
    output     [   1:0] ctl_ba_rq,
    input               ctl_ack,
    input               ctl_rdy,
    input      [   1:0] ctl_ba_rdy,
    output     [  15:0] ctl_din,
    output     [   1:0] ctl_din_m,  // write mask
    input      [  31:0] ctl_dout,

    // Common signals
    input               rfsh_en,   // ok to refresh
    output reg [  31:0] dout
);

localparam       RQW=AW+2+2, FFW=RQW*3;
localparam [4:0] BWAIT    = `JTFRAME_SDRAM_BWAIT;
localparam       BWAIT_EN = BWAIT != 5'd0;

// Adds an extra cycle of latency. Use if needed to meet timing constraints
`ifdef JTFRAME_SDRAM_MUXLATCH
localparam MUXLATCH = 1;
`else
localparam MUXLATCH = HF;
`endif

reg  [RQW-1:0] mux_data;
reg  [ AW-1:0] fifo_addr;
reg  [    2:0] ba_sel;
reg            fifo_rd, fifo_wr;
reg  [    1:0] fifo_ba;
wire           ba0_rq;
reg  [    3:0] queue;
reg  [    7:0] lfsr;
reg  [    4:0] bwait;

assign ba0_rq  = ba0_rd | ba0_wr;
assign prog_rdy= prog_en & ctl_ack;

assign ba0_ack = ctl_ack && ctl_ba_rq==2'd0;
assign ba1_ack = ctl_ack && ctl_ba_rq==2'd1;
assign ba2_ack = ctl_ack && ctl_ba_rq==2'd2;
assign ba3_ack = ctl_ack && ctl_ba_rq==2'd3;


// Multiplexer to select programming or regular inputs
assign ctl_addr    = prog_en ? prog_addr : fifo_addr;
assign ctl_rd      = prog_en ? prog_rd   : fifo_rd;
assign ctl_wr      = prog_en ? prog_wr   : fifo_wr;
assign ctl_ba_rq   = prog_en ? prog_ba   : fifo_ba;
assign ctl_din     = prog_en ? prog_din  : ba0_din;
assign ctl_din_m   = prog_en ? prog_din_m: ba0_din_m;

generate
    if( MUXLATCH ) begin
        reg post_ack;

        always @(posedge clk, posedge rst) begin
            if( rst ) begin
                { fifo_addr, fifo_rd, fifo_wr, fifo_ba } <= {RQW{1'b0}};
                post_ack <= 0;
                bwait    <= 5'd0;
            end else begin
                post_ack <= ctl_ack;
                if( post_ack || (!fifo_rd && !fifo_wr) )
                    { fifo_addr, fifo_rd, fifo_wr, fifo_ba } <= mux_data;
                if( (ctl_rdy || ctl_ack || bwait!=5'd0) && BWAIT_EN )
                    bwait <= bwait<BWAIT ? bwait + 5'd1 : 5'd0;
            end
        end
    end else begin
        always @(mux_data) { fifo_addr, fifo_rd, fifo_wr, fifo_ba } = mux_data;
    end
endgenerate

`ifdef JTFRAME_SDRAM_REPACK
always @(posedge clk, posedge rst ) begin
    if( rst )begin
        ba0_rdy <= 0;
        ba1_rdy <= 0;
        ba2_rdy <= 0;
        ba3_rdy <= 0;
        dout    <= 32'd0;
    end else begin
        ba0_rdy <= ctl_rdy && ctl_ba_rdy==2'd0;
        ba1_rdy <= ctl_rdy && ctl_ba_rdy==2'd1;
        ba2_rdy <= ctl_rdy && ctl_ba_rdy==2'd2;
        ba3_rdy <= ctl_rdy && ctl_ba_rdy==2'd3;
        dout    <= ctl_dout;
    end
end
`else
always @(*) begin
    ba0_rdy = ctl_rdy && ctl_ba_rdy==2'd0;
    ba1_rdy = ctl_rdy && ctl_ba_rdy==2'd1;
    ba2_rdy = ctl_rdy && ctl_ba_rdy==2'd2;
    ba3_rdy = ctl_rdy && ctl_ba_rdy==2'd3;
    dout    = ctl_dout;
end
`endif

// Produce one refresh cycle after each programming write
always @(posedge clk, posedge rst ) begin
    if( rst )
        ctl_rfsh_en <= 0;
    else begin
        if( prog_en )
            ctl_rfsh_en <= 1;
        else
            ctl_rfsh_en <= rfsh_en;
    end
end

always @(*) begin
    ba_sel[2] = 1;
    case( lfsr[7:6] )
        2'd0: if( ba0_rq && !queue[0] ) ba_sel=3'd0;
        2'd1: if( ba1_rd && !queue[1] ) ba_sel=3'd1;
        2'd2: if( ba2_rd && !queue[2] ) ba_sel=3'd2;
        2'd3: if( ba3_rd && !queue[3] ) ba_sel=3'd3;
    endcase // lfsr[7:6]
    if( ba_sel[2] ) begin
        case( lfsr[7:6] )
            2'd1: if( ba0_rq && !queue[0] ) ba_sel=3'd0;
            2'd2: if( ba1_rd && !queue[1] ) ba_sel=3'd1;
            2'd3: if( ba2_rd && !queue[2] ) ba_sel=3'd2;
            2'd0: if( ba3_rd && !queue[3] ) ba_sel=3'd3;
        endcase // lfsr[7:6]
    end
    if( ba_sel[2] ) begin
        case( lfsr[7:6] )
            2'd2: if( ba0_rq && !queue[0] ) ba_sel=3'd0;
            2'd3: if( ba1_rd && !queue[1] ) ba_sel=3'd1;
            2'd0: if( ba2_rd && !queue[2] ) ba_sel=3'd2;
            2'd1: if( ba3_rd && !queue[3] ) ba_sel=3'd3;
        endcase // lfsr[7:6]
    end
    if( ba_sel[2] ) begin
        case( lfsr[7:6] )
            2'd3: if( ba0_rq && !queue[0] ) ba_sel=3'd0;
            2'd0: if( ba1_rd && !queue[1] ) ba_sel=3'd1;
            2'd1: if( ba2_rd && !queue[2] ) ba_sel=3'd2;
            2'd2: if( ba3_rd && !queue[3] ) ba_sel=3'd3;
        endcase
    end
    // mux selector
    /*
    if( lfsr[7] ) begin
        if( ba0_rq && !queue[0] )
            ba_sel = 3'd0;
        else if( ba1_rd && !queue[1] )
            ba_sel = 3'd1;
        else if( ba2_rd && !queue[2] )
            ba_sel = 3'd2;
        else if( ba3_rd && !queue[3] )
            ba_sel = 3'd3;
        else
            ba_sel = 3'd4;
    end else begin
        if( ba3_rd && !queue[3] )
            ba_sel = 3'd3;
        else if( ba2_rd && !queue[2] )
            ba_sel = 3'd2;
        else if( ba1_rd && !queue[1] )
            ba_sel = 3'd1;
        else if( ba0_rq && !queue[0] )
            ba_sel = 3'd0;
        else
            ba_sel = 3'd4;
    end*/
    // mux output
    mux_data[1:0] = ba_sel;
    case( ba_sel )
        3'd0: mux_data[RQW-1:2] = { ba0_addr, ba0_rd, ba0_wr };
        3'd1: mux_data[RQW-1:2] = { ba1_addr, 2'b10 };
        3'd2: mux_data[RQW-1:2] = { ba2_addr, 2'b10 };
        3'd3: mux_data[RQW-1:2] = { ba3_addr, 2'b10 };
        default: mux_data[RQW-1:2] = {RQW-2{1'd0}};
    endcase
    if( BWAIT_EN && bwait!=5'd0 ) mux_data = {RQW-2{1'd0}};
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        queue <= 4'd0;
        lfsr  <= ~8'd0;
    end else begin
        if( prog_en ) begin
            queue <= 4'd0;
        end else begin
            if( ctl_ack ) begin
                queue[ ctl_ba_rq ] <= 1;
                lfsr <= { lfsr[6:0], ^{lfsr[7],lfsr[5:3]} };
            end
            if( ctl_rdy ) begin
                queue[ ctl_ba_rdy] <= 0;
            end
        end
    end
end

endmodule
