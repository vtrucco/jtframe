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
    Date: 12-5-2020 */

module jt4701(
    input               clk,
    input               rst,
    input      [1:0]    x_in,
    input      [1:0]    y_in,
    input               rightn,
    input               leftn,
    input               middlen,
    input               x_rstn,
    input               y_rstn,
    input               csn,        // chip select
    input               uln,        // byte selection
    input               xn_y,       // select x or y for reading
    output reg          cfn,        // counter flag
    output reg          sfn,        // switch flag
    output reg [7:0]    dout
);

reg  [11:0] cntx, cnty;
reg  [ 1:0] last_x, last_y;

reg  [ 1:0] xphase, yphase;
wire [ 1:0] xedge, yedge;
reg  [ 1:0] last_xedge, last_yedge;

wire [ 7:0] upper, lower;

assign      xedge = x_in ^ last_x;
assign      yedge = y_in ^ last_y;

assign      upper = { sfn, leftn, rightn, middlen, xn_y ? cnty[11:8] : cntx[11:8] };
assign      lower = xn_y ? cnty[7:0] : cntx[7:0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cntx   <= 12'd0;
        cnty   <= 12'd0;
        last_x <= 2'b0;
        last_y <= 2'b0;
        cfn    <= 1;
        sfn    <= 1;
    end else begin
        sfn        <= leftn && middlen && rightn;
        cfn        <= !csn || !(last_xedge || last_yedge);

        last_x     <= x_in;
        last_y     <= y_in;
        last_xedge <= xedge;
        last_yedge <= yedge;

        if( xedge[0] ) xphase[0] <= x_in[0] & ~last_x[0];
        if( xedge[1] ) xphase[1] <= x_in[1] & ~last_x[1];
        if( yedge[0] ) yphase[0] <= y_in[0] & ~last_y[0];
        if( yedge[1] ) yphase[1] <= y_in[1] & ~last_y[1];

        if( !x_rstn )
            cntx <= 12'd0;
        else begin
            if( (last_xedge[0] && (xphase[0]!=xphase[1])) ||
                (last_xedge[1] && (xphase[0]==xphase[1])) )
                cntx <= cntx+12'd1;
            else begin
                if( (last_xedge[0] && (xphase[0]==xphase[1])) ||
                    (last_xedge[1] && (xphase[0]!=xphase[1])) )
                    cntx <= cntx-12'd1;
            end
        end

        if( !y_rstn )
            cnty <= 12'd0;
        else begin
            if( (last_yedge[0] && (yphase[0]!=yphase[1])) ||
                (last_yedge[1] && (yphase[0]==yphase[1])) )
                cnty <= cnty+12'd1;
            else begin
                if( (last_yedge[0] && (yphase[0]==yphase[1])) ||
                    (last_yedge[1] && (yphase[0]!=yphase[1])) )
                    cnty <= cnty-12'd1;
            end
        end

        dout <= uln ? upper : lower;
    end
end

endmodule
