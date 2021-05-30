/*  This file is part of JT_FRAME.
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
    Date: 25-9-2019 */

module jtframe_cheat #(parameter
        AW=22,
parameter [AW-1:0] CHEAT_ADDR==0,
          [  15:0] CHEAT_VAL==0,
          [   1:0] CHEAT_MASK==2,
          [   5:0] FRAME_CNT=6'd59
)(
    input   rst,
    input   clk_rom,

    input   LVBL,
    input   enable,

    // From/to game
    input  [AW-1:0] game_addr,
    input           game_rd,
    input           game_wr,
    input  [ 15:0]  game_din,
    input  [  1:0]  game_din_m,
    output          game_rdy,

    // From/to SDRAM bank 0
    output [AW-1:0] ba0_addr,
    output          ba0_rd,
    output          ba0_wr,
    output [ 15:0]  ba0_din,
    output [  1:0]  ba0_din_m,

    input           ba0_rdy
);

wire clk = clk_rom;

reg       last_LVBL, pending, lock, wrcheat;
reg [5:0] frame_cnt;

assign ba0_addr  = lock ? CHEAT_ADDR : game_addr;
assign ba0_rd    = lock ? 1'b0 : game_rd;
assign ba0_wr    = lock ? wrcheat : game_wr;
assign ba0_din   = lock ? CHEAT_VAL : game_din;
assign ba0_din_m = lock ? CHEAT_MASK : game_din_m;
assign game_rdy  = lock ? 1'b0 : ba0_rdy;

always @(posedge clk, rst) begin
    if(rst) begin
       last_LVBL <= 0;
       lock      <= 0;
       pending   <= 0;
       wrcheat   <= 0;
       frame_cnt <= 0;
    end else begin
        last_LVBL <= LVBL;

        if( !LVBL && last_LVBL ) begin
            pending   <= enable && frame_cnt==0;
            frame_cnt <= frame_cnt==FRAME_CNT ? 6'd0 : frame_cnt + 1'd1;
        end

        if( pending && ba0_rdy ) begin
            lock    <= 1;
            wrcheat <= 1;
            pending <= 0;
        end

        if( lock && ba0_ack ) begin
            wrcheat <= 0;
        end

        if( lock && ba0_rdy ) lock <= 0;

    end
end

endmodule
