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
    parameter        PAGES  = 1,
                     COLW   = 4,       // bits per pixel colour component
    parameter [11:0] PAL0   = { 4'hf, 4'h0, 4'h0 },  // Red
    parameter [11:0] PAL1   = { 4'h0, 4'hf, 4'h0 },  // Green
    parameter [11:0] PAL2   = { 4'h3, 4'h3, 4'hf },  // Blue
    parameter [11:0] PAL3   = { 4'hf, 4'hf, 4'hf },  // White
    parameter        BLKPOL = 1'b1,
    parameter        SPEED  = 3
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

localparam MSGW  = PAGES == 1 ? 10 : 
                   (PAGES == 2 ? 11 :
                   (PAGES > 2 && PAGES <=4 ? 12 :
                   (PAGES > 5 && PAGES <=8 ? 13 : 14 ))); // Support for upto 16 pages
localparam MAXVISIBLE = PAGES*32*8;
localparam VPOSW = MSGW-2;

reg  [7:0] hpos, vrender;
reg  [VPOSW-1:0 ] vpos;
wire [VPOSW-1:0 ] veff = vpos + vrender;
(*keep*) wire [8:0]      scan_data;
(*keep*) wire [7:0]      font_data;
(*keep*) reg  [MSGW-1:0] scan_addr;
(*keep*) wire [9:0]      font_addr = {scan_data[6:0], veff[2:0] };
wire visible = veff < MAXVISIBLE;

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

reg last_hb, last_vb;
reg [3:0] scr_base;

always @(posedge clk) begin
    if( rst ) begin
        hpos     <= 8'd0;
        vpos     <= {VPOSW{1'b0}};
        vrender  <= 8'd0;
        scr_base <= 4'd0;
    end else if(pxl_cen) begin
        last_hb <= hb;
        last_vb <= vb;
        if( hb && !last_hb ) begin
            hpos    <= 8'd0;
            vrender <= vrender + 8'd1;
        end else if( !hb && hpos!=8'hff ) begin
            hpos <= hpos + 8'd1;
        end
        if ( vb ) begin
            vrender  <= 0;
            if( !last_vb && SCROLL_EN ) begin
                if( scr_base == SPEED ) begin
                    vpos <= vpos + 1;
                    scr_base <= 4'd0;
                end else scr_base <= scr_base + 4'd1;
            end
        end
        if( hpos[2:0]==3'd0 || hb || vb ) begin
            scan_addr <= { veff[VPOSW-1:3], hpos[7:3] };
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
wire [COLW*3-1:0] dim = { 1'b0, old2[R1:R0+1], 1'b0, old2[G1:G0+1], 1'b0, old2[B1:B0+1] };

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
        if( !pxl[0] || !visible /*|| (blanks[1:0]^{2{~BLKPOL[0]}}!=2'b00)*/ ) begin
            rgb_out            <= dim;
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