//============================================================================
//  JTFRAME by Jose Tejada Gomez. Twitter: @topapate
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public Licen_hsse as published by the Free
//  Software Foundation; either version 2 of the Licen_hsse, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public Licen_hsse for
//  more details.
//
//  You should have received a copy of the GNU General Public Licen_hsse along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module jtframe_db9joy(
    input              rst,
    input              clk,
    input              cen_hs,  // 64us
    input              scan,

    input       [ 5:0] din,
    output reg         split,
    output reg         mdsel,

    output reg  [11:0] joy0,
    output reg  [11:0] joy1,
    output reg         sample,
    output reg         hooked
);

reg  [ 5:0] cnt;
reg  [11:0] raw0, raw1;
wire [ 5:0] not_din;
reg  [ 1:0] md6;
reg  [ 3:0] joy1_en;
reg         con;        // connected
reg         locked;

assign not_din = ~din;

function [11:0] sort;
    input [11:0] raw;
    sort = {    raw[8],    // mode
                raw[7],    // start
                raw[11:9],
                raw[5:4],  // buttons B, C
                raw[6],    // button A
                raw[3:0]   // direction
            };
endfunction

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        joy0     <= 12'd0;
        joy1     <= 12'd0;
        raw0     <= 12'd0;
        raw1     <= 12'd0;
        joy1_en  <= 4'd0;
        cnt      <= 6'd0;
        hooked   <= 1;
        sample   <= 0;
        md6      <= 2'b0;
        con      <= 0;
        locked   <= 0;
    end else begin
        { mdsel, split } <= (!scan || locked) ? 2'b10 : { cnt[2], cnt[1] };
        sample           <= cnt==6'd15 && cen_hs;
        if( !scan ) begin
            cnt    <=  4'd0;
            md6    <=  2'b0;
            locked <=  1'b0;
        end else if(cen_hs) begin
            cnt <= cnt+1'd1;
            if( &cnt ) locked <= 0;
            if( !locked ) begin
                case( cnt[4:1] )
                    4'd0: raw0[11:0] <= 12'd0;
                    4'd1: raw1[11:0] <= 12'd0;

                    4'd2: raw0[ 5:0] <= not_din[5:0];
                    4'd3: raw1[ 5:0] <= not_din[5:0];

                    4'd4: raw0[ 7:6] <= not_din[5:4];
                    4'd5: raw1[ 7:6] <= not_din[5:4];

                    4'd8: md6[0] <= din[3:0]==4'b0;
                    4'd9: md6[1] <= din[3:0]==4'b0;

                    4'ha: if(md6[0]) raw0[11:8] <= not_din[3:0];
                    4'hb: if(md6[1]) raw1[11:8] <= not_din[3:0];
                    4'hf: begin
                        locked <= 1'b1;
                        joy0   <= sort( raw0 );
                        joy1   <= sort( raw1 );
                    end
                endcase
            end
        end
    end
end

endmodule