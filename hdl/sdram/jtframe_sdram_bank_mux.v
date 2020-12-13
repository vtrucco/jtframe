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

module jtframe_sdram_bank_mux #(parameter AW=22) (
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

localparam RQW=AW+2+2, FFW=RQW*3;

reg  [    3:0] queued, free;
wire [RQW-1:0] fifo_out, fifo_top;
wire [RQW-1:0] fifo0, fifo1, fifo2;
reg  [FFW-1:0] fifo;
reg            push_ok, shift_ok, top_shift_ok;
wire [ AW-1:0] reg_addr;
wire           reg_rd, reg_wr;
wire [    1:0] reg_ba;

assign fifo2   = fifo[FFW-1:FFW-RQW];
assign fifo1   = fifo[FFW-RQW-1:FFW-RQW*2];
assign fifo0   = fifo[FFW-RQW*2-1:0];

assign prog_rdy= prog_en & ctl_ack;

assign ba0_ack = ctl_ack && fifo_out[1:0]==2'd0;
assign ba1_ack = ctl_ack && fifo_out[1:0]==2'd1;
assign ba2_ack = ctl_ack && fifo_out[1:0]==2'd2;
assign ba3_ack = ctl_ack && fifo_out[1:0]==2'd3;

// FIFO
assign fifo_out = fifo[RQW-1:0];
assign fifo_top = fifo[FFW-1:FFW-RQW];
assign { reg_addr, reg_rd, reg_wr, reg_ba } = fifo_out;

// Multiplexer to select programming or regular inputs
assign ctl_addr    = prog_en ? prog_addr : reg_addr;
assign ctl_rd      = prog_en ? prog_rd   : reg_rd;
assign ctl_wr      = prog_en ? prog_wr   : reg_wr;
assign ctl_ba_rq   = prog_en ? prog_ba   : reg_ba;
assign ctl_din     = prog_en ? prog_din  : ba0_din;
assign ctl_din_m   = prog_en ? prog_din_m: ba0_din_m;

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
    if( prog_en ) begin
        shift_ok = 0;
        push_ok  = 0;
        top_shift_ok = 0;
    end else begin
        shift_ok     = fifo_out[3:2]==2'd0 || ctl_ack;
        top_shift_ok = fifo1[3:2]   ==2'd0;
        push_ok      = fifo_top[3:2]==2'd0 || shift_ok || top_shift_ok;
    end
    free = ~queued;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        queued <= 4'd0;
        fifo   <= {FFW{1'd0}};
    end else begin
        if( prog_en ) begin
            fifo   <= {FFW{1'd0}};
        end else begin
            if( push_ok ) begin
                if( (ba0_rd || ba0_wr) && free[0] ) begin
                    fifo[FFW-1:FFW-RQW] <= { ba0_addr, ba0_rd, ba0_wr, 2'd0 };
                    queued[0] <= 1;
                end else
                if( ba1_rd && free[1] ) begin
                    fifo[FFW-1:FFW-RQW] <= { ba1_addr, ba1_rd, 1'd0, 2'd1 };
                    queued[1] <= 1;
                end else
                if( ba2_rd && free[2] ) begin
                    fifo[FFW-1:FFW-RQW] <= { ba2_addr, ba2_rd, 1'd0, 2'd2 };
                    queued[2] <= 1;
                end else
                if( ba3_rd && free[3] ) begin
                    fifo[FFW-1:FFW-RQW] <= { ba3_addr, ba3_rd, 1'd0, 2'd3 };
                    queued[3] <= 1;
                end else begin
                    fifo[FFW-1:FFW-RQW] <= {RQW{1'd0}};
                end
            end
            if( shift_ok )
                fifo[FFW-1-RQW:0] <= fifo[FFW-1:RQW];
            else if( top_shift_ok )
                fifo[FFW-1-RQW:RQW] <= fifo[FFW-1:RQW*2];
            if( ctl_rdy )
                queued[ ctl_ba_rdy ] <= 0;
        end
    end
end

endmodule
