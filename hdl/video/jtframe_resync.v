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

module jtframe_resync(
    input         clk,
    input         pxl_cen,
    input         hs_in,
    input         vs_in,
    input         LVBL,
    input         LHBL,
(*keep*)    input  [3:0]  hoffset,
(*keep*)    input  [3:0]  voffset,
    output reg    hs_out,
    output        vs_out
);

parameter HCNT = 10; // max 1024 pixels
parameter HLEN = 8; // length in pixels of the H pulse

reg [HCNT-1:0]   hs_pos, vs_pos,   // relative positions of the original sync pulses
                 hs_cnt, vs_cnt;   // count the position of the original sync pulses
reg              last_LHBL, last_LVBL, last_hsin, last_vsin;
reg [HLEN-1:0]   hs_hold;
wire             hb_edge, hs_edge;
reg [5:0]        hs_rst;

(*keep*) wire [HCNT-1:0]  htrip = hs_pos + { {HCNT-4{hoffset[3]}}, hoffset[3:0]  };
(*keep*) wire [HCNT-1:0]  vtrip = vs_pos + { {HCNT-4{voffset[3]}}, voffset[3:0]  };

assign vs_out  = vs_in;
assign hb_edge = LHBL && !last_LHBL;
assign hs_edge = hs_in && !last_hsin;

always @(posedge clk) if(pxl_cen) begin
    last_LHBL <= LHBL;
    last_hsin <= hs_in;
    if( hs_edge ) hs_pos   <= hs_cnt;        
    hs_cnt <= hb_edge ? {HCNT{1'b0}} : hs_cnt+1;
    if( hs_cnt == htrip ) begin
        hs_out <= 1;
        hs_hold <= {HLEN{1'b1}};
    end else begin
        hs_hold <= hs_hold>>1;
        if( !hs_hold[0] ) hs_out <= 0;
    end
end

`ifdef SIMULATION
initial begin
    hs_cnt = {HCNT{1'b0}};
    vs_cnt = {HCNT{1'b0}};
    hs_out = 0;
    vs_out = 0;
end
`endif

endmodule