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

wire [11:0] cntx, cnty;
wire        xflagn, yflagn;

wire [ 7:0] upper, lower;

assign      upper = { sfn, leftn, rightn, middlen, xn_y ? cnty[11:8] : cntx[11:8] };
assign      lower = xn_y ? cnty[7:0] : cntx[7:0];

jt4701_axis u_axisx(
    .clk        ( clk       ),
    .rstn       ( x_rstn    ),
    .sigin      ( x_in      ),
    .flag_clrn  ( csn       ),
    .flagn      ( xflagn    ),
    .axis       ( cntx      )
);

jt4701_axis u_axisy(
    .clk        ( clk       ),
    .rstn       ( y_rstn    ),
    .sigin      ( y_in      ),
    .flag_clrn  ( csn       ),
    .flagn      ( yflagn    ),
    .axis       ( cnty      )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cfn  <= 1;
        sfn  <= 1;
        dout <= 8'd0;
    end else begin
        sfn  <= leftn && middlen && rightn;
        cfn  <= xflagn && yflagn;
        dout <= uln ? upper : lower;
    end
end

endmodule

module jt4701_axis(
    input               clk,
    input               rstn,   // synchronous
    input      [1:0]    sigin,
    input               flag_clrn,
    output reg          flagn,
    output reg [11:0]   axis
);

wire [1:0] xedge;
reg  [1:0] last_in, locked, last_xedge;
reg        dir;

assign     xedge = sigin ^ last_in;

`ifdef SIMULATION
initial begin
    axis    = 12'd0;
    last_in = 2'b0;
    flagn   = 1;
    locked  = 2'b00;
    dir     = 0;
end
`endif

always @(posedge clk) begin
    if( !rstn ) begin
        axis   <= 12'd0;
        last_in<= 2'b0;
        flagn  <= 1;
        locked <= 2'b00;
        dir    <= 0;
    end else begin
        flagn      <= !flag_clrn || !(xedge!=2'b00 && locked[0]!=locked[1]);
        last_in    <= sigin;

        if( locked[0]==locked[1] ) begin
            dir <= (sigin[0] & ~last_in[0] & sigin[1]) | (~sigin[0] & last_in[0] & ~sigin[1]);
        end

        if( xedge != 2'b00 ) begin
            if( locked[0] != locked[1] )
                axis   <=  dir ? axis-12'd1 : axis+12'd1;
            locked <= { locked, xedge[0] };
        end 
    end
end

endmodule
