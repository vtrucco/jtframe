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

// Simple scan doubler
//                       Min      Max
// clock/pxl_cen ratio    4     96/6=16
//
// CRT-like output:
//  -simple blending of neighbouring pixels

module jtframe_scan2x #(parameter COLORW=4, HLEN=256)(
    input       rst_n,
    input       clk,
    input       pxl_cen,
    input       pxl2_cen,
    input       [COLORW*3-1:0]    base_pxl,
    input       HS,

    output  reg [COLORW*3-1:0]    x2_pxl,
    output  reg x2_HS
);

localparam AW=HLEN<=256 ? 8 : (HLEN<=512 ? 9:10 );
localparam DW=COLORW*3;

reg  [DW-1:0] mem0[0:HLEN-1];
reg  [DW-1:0] mem1[0:HLEN-1];
reg  [DW-1:0] preout;
reg  [AW-1:0] wraddr, rdaddr, hscnt0, hscnt1;
reg  [   3:0] cen_cnt, div_cnt; // supports up to 96MHz for a 6 MHz pixel clock
reg           oddline, scanline;
reg           last_HS, last_HS_base;
reg           waitHS;

wire          HS_posedge     =  HS && !last_HS;
wire          HSbase_posedge =  HS && !last_HS_base;
wire          HS_negedge     = !HS &&  last_HS;
wire          half_time      =  cen_cnt > {1'b0,div_cnt[3:1]};
wire [DW-1:0] next           =  oddline ? mem0[rdaddr] : mem1[rdaddr];

function [COLORW-1:0] ave;
    input [COLORW-1:0] a;
    input [COLORW-1:0] b;
    ave = {1'b0, a[COLORW-1:1] } + { 1'b0, b[COLORW-1:1] };
endfunction

function [DW-1:0] blend;
    input [DW-1:0] a;
    input [DW-1:0] b;
    blend = {
        ave(a[COLORW*3-1:COLORW*2],b[COLORW*3-1:COLORW*2]),
        ave(a[COLORW*2-1:COLORW],b[COLORW*2-1:COLORW]),
        ave(a[COLORW-1:0],b[COLORW-1:0]) };
endfunction

always @(posedge clk) if(pxl_cen)   last_HS_base <= HS;
always @(posedge clk) if(pxl2_cen) last_HS <= HS;

// Derive pxl4_cen
always @(posedge clk) begin
    cen_cnt <= pxl2_cen ? 4'd0 : cen_cnt+4'd1;
    if( pxl2_cen ) div_cnt <= cen_cnt;
end

always@(posedge clk or negedge rst_n)
    if( !rst_n )
        waitHS  <= 1'b1;
    else begin
        if(HS_posedge ) waitHS  <= 1'b0;
    end

reg alt_pxl; // this is needed in case pxl2_cen and pxl_cen are not aligned.

always@(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        preout <= {DW{1'b0}};
    end else begin
        if( half_time )
            preout <= next;
        else if(cen_cnt==4'd0)
            preout <= blend( rdaddr=={AW{1'b0}} ? {DW{1'b0}} : preout,
                             next);
    end
end

// scan lines are black
always @(posedge clk) begin
    x2_pxl <= scanline ? blend( {DW{1'b0}}, preout) : preout;
end

always@(posedge clk or negedge rst_n)
    if( !rst_n ) begin
        wraddr  <= {AW{1'b0}};
        rdaddr  <= {AW{1'b0}};
        oddline <= 1'b0;
        alt_pxl <= 1'b0;
    end else if(pxl2_cen) begin
        if( !waitHS ) begin
            rdaddr   <= rdaddr < (HLEN-1'b1) ? (rdaddr+1'b1) : 0;
            alt_pxl <= ~alt_pxl;
            if( alt_pxl ) begin
                if( HSbase_posedge ) oddline <= ~oddline;
                wraddr <= HSbase_posedge ? 0 : (wraddr+1);
                if( oddline )
                    mem1[wraddr] <= base_pxl;
                else
                    mem0[wraddr] <= base_pxl;
            end 
        end
    end

always @(posedge clk or negedge rst_n)
    if( !rst_n ) begin
        x2_HS    <= 0;
        scanline <= 0;
    end else begin
        if( HS_posedge ) hscnt1 <= wraddr;
        if( HS_negedge ) hscnt0 <= wraddr;
        if( rdaddr == hscnt0 ) x2_HS <= 0;
        if( rdaddr == hscnt1 ) begin
            x2_HS    <= 1;
            if(!x2_HS) scanline <= ~scanline;
        end
    end

endmodule // jtframe_scan2x