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
    output              ba0_rdy,

    // Bank 1: Read only
    input      [AW-1:0] ba1_addr,
    input               ba1_rd,
    output              ba1_rdy,

    // Bank 2: Read only
    input      [AW-1:0] ba2_addr,
    input               ba2_rd,
    output              ba2_rdy,

    // Bank 3: Read only
    input      [AW-1:0] ba3_addr,
    input               ba3_rd,
    output              ba3_rdy,

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
    output              ctl_rfsh_en,   // ok to refresh
    output     [   1:0] ctl_ba_rq,
    input               ctl_ack,
    input               ctl_rdy,
    input      [   1:0] ctl_ba_rdy,
    output     [  15:0] ctl_din,
    output     [   1:0] ctl_din_m,  // write mask
    input      [  31:0] ctl_dout,

    // Common signals
    input               rfsh_en,   // ok to refresh
    output     [  31:0] dout
);

localparam RQW=AW+2+2, FFW=RQW*4;

reg  [    3:0] queued;
wire [RQW-1:0] fifo_out, fifo_top;
reg  [FFW-1:0] fifo;
reg            push_ok, shift_ok;
wire [ AW-1:0] reg_addr;
wire           reg_rd, reg_wr;
wire [    1:0] reg_ba;

assign dout    = ctl_dout;

assign ba0_rdy = ctl_rdy && ctl_ba_rdy==2'd0;
assign ba1_rdy = ctl_rdy && ctl_ba_rdy==2'd1;
assign ba2_rdy = ctl_rdy && ctl_ba_rdy==2'd2;
assign ba3_rdy = ctl_rdy && ctl_ba_rdy==2'd3;

// FIFO
assign fifo_out = fifo[RQW-1:0];
assign fifo_top = fifo[FFW-1:FFW-RQW];
assign { reg_addr, reg_rd, reg_wr, reg_ba } = fifo_out;

// Multiplexer to select programming or regular inputs
assign ctl_rfsh_en = prog_en | rfsh_en;
assign ctl_addr    = prog_en ? prog_addr : reg_addr;
assign ctl_rd      = prog_en ? prog_rd   : reg_rd;
assign ctl_wr      = prog_en ? prog_wr   : reg_wr;
assign ctl_ba_rq   = prog_en ? prog_ba   : reg_ba;
assign ctl_din     = prog_en ? prog_din  : ba0_din;
assign ctl_din_m   = prog_en ? prog_din_m: ba0_din_m;

always @(*) begin
    if( prog_en ) begin
        shift_ok = 0;
        push_ok  = 0;
    end else begin
        shift_ok = fifo_out[3:2]==2'd0 || ctl_ack;
        push_ok  = fifo_top[3:2]==2'd0 || shift_ok;
    end
end

task push(input [RQW-1:0] a);
    fifo[FFW-1:FFW-RQW] <= a;
endtask

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        queued <= 4'd0;
        fifo   <= {FFW{1'd0}};
    end else begin
        if( prog_en ) begin
            fifo   <= {FFW{1'd0}};
        end else begin
            if( push_ok ) begin
                if( (ba0_rd || ba0_wr) && !queued[0] )
                    push( { ba0_addr, ba0_rd, ba0_wr, 2'd0 } );
                else
                if( ba1_rd && !queued[1] )
                    push( { ba1_addr, ba1_rd, 1'd0, 2'd1 } );
                else
                if( ba2_rd && !queued[2] )
                    push( { ba2_addr, ba2_rd, 1'd0, 2'd2 } );
                else
                if( ba3_rd && !queued[3] )
                    push( { ba3_addr, ba3_rd, 1'd0, 2'd3 } );
                else
                    push( {RQW{1'd0}} );
            end
            if( shift_ok )
                fifo[FFW-1-RQW:0] <= fifo[FFW-1:RQW];
        end
    end
end

endmodule
