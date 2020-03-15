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
    Date: 14-3-2020 */
    
`timescale 1ns/1ps

// 8x8 tiles

module jtframe_credits #(
    parameter        MSGW   = 10,
                     COLW   = 4,       // bits per pixel colour component
    parameter [11:0] PAL0   = { 4'hf, 4'h0, 4'h0 },  // Red
    parameter [11:0] PAL1   = { 4'h0, 4'hf, 4'h0 },  // Green
    parameter [11:0] PAL2   = { 4'h0, 4'h0, 4'hf },  // Blue
    parameter [11:0] PAL3   = { 4'hf, 4'hf, 4'hf },  // White
    parameter        BLKPOL = 1'b1
) (
    input               rst,
    input               clk,

    // input image
    input               pxl_cen,    
    input               HB,
    input               VB,
    input [COLW*3-1:0]  rgb_in,
    input               enable,

    // output image
    output reg              HB_out,
    output reg              VB_out,
    output reg [COLW*3-1:0] rgb_out
);

localparam VPOSW = MSGW-2;
reg [7:0] hpos;
reg [VPOSW-1:0 ] vpos;
(*keep*) wire [8:0]      scan_data;
(*keep*) wire [7:0]      font_data;
(*keep*) reg  [MSGW-1:0] scan_addr;
(*keep*) wire [9:0]      font_addr = {scan_data[6:0], vpos[2:0] };

jtframe_ram #(.dw(9), .aw(MSGW),.synfile("msg.hex")) u_msg(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( 9'd0      ),
    .addr   ( scan_addr ),
    .we     ( 1'b0      ),
    .q      ( scan_data )
);

jtframe_ram #(.aw(10),.synfile("font0.hex")) u_font(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( 8'd0      ),
    .addr   ( font_addr ),
    .we     ( 1'b0      ),
    .q      ( font_data )
);

reg  [1:0]      pal;
reg  [2:0]      pxl;

localparam SCROLL_EN = MSGW > 10;

// hb and vb are always active high
(*keep*) wire hb = BLKPOL ? HB : ~HB;
(*keep*) wire vb = BLKPOL ? VB : ~VB;
reg [7:0] pxl_data;

reg last_hb;

always @(posedge clk) begin
    if( rst ) begin
        hpos <= 8'd0;
        vpos <= {VPOSW{1'b0}};
    end else if(pxl_cen) begin
        last_hb <= hb;
        if( hb && !last_hb ) begin
            hpos <= 8'd0;
            if ( vb && !SCROLL_EN )
                vpos <= 0;
            else
                vpos <= vpos+1;
        end else if( !hb && hpos!=8'hff ) begin
            hpos <= hpos + 8'd1;
        end
        if( hpos[2:0]==3'd0 || hb || vb ) begin
            scan_addr <= { vpos[VPOSW-1:3], hpos[7:3] };
        end
        // Draw
        pxl <= { pal, pxl_data[7] };
        if( hpos[2:0]==3'd1) begin
            pal      <= scan_data[8:7];
            pxl_data <= font_data;
        end else 
            pxl_data <= pxl_data << 1;
    end
end

// Merge the new image with the old
reg [COLW*3-1:0] old1, old2;
reg [3:0]        blanks;

localparam R1 = COLW*3-1;
localparam R0 = COLW*2;
localparam G1 = COLW*2-1;
localparam G0 = COLW;
localparam B1 = COLW-1;
localparam B0 = 0;

always @(posedge clk) if(pxl_cen) begin
    old1 <= rgb_in;
    old2 <= old1;
    { blanks, HB_out, VB_out } <= { HB, VB, blanks };
    if( !enable )
        rgb_out <= old2;
    else begin
        if( !pxl[0] /*|| (blanks[1:0]^{2{~BLKPOL[0]}}!=2'b00)*/ ) begin
            rgb_out            <= { 1'b0, old2[R1:R0+1], 1'b0, old2[G1:G0+1], 1'b0, old2[B1:B0+1] };
        end else begin
            case( pxl[2:1] )
                2'd0: rgb_out <= PAL0;
                2'd1: rgb_out <= PAL1;
                2'd2: rgb_out <= PAL2;
                2'd3: rgb_out <= PAL3;
            endcase // pxl[2:1]
        end
    end
end

endmodule