//============================================================================
//  JTFRAME by Jose Tejada Gomez. Twitter: @topapate
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

// This code comes from the DB9 team. I have only refactored it and renmed a couple of things.
// cfg bits
//
// 2 enables db9
// 1 enables db15
// 0 enbles 2-player support

module jtframe_db9joy(
    input              rst,
    input              clk,
    input              cen,
    input              scan,

    input       [ 5:0] din,
    output             split,
    output             mdsel,

    output reg  [11:0] joy0,
    output reg  [11:0] joy1,
    output reg         sample,
    output reg         hooked
);

reg  [ 3:0] cnt;
reg  [11:0] joy_scan;
wire [11:0] joy_sorted;
wire [ 5:0] not_din;
reg         last_split, last_but, md6;

assign { split, mdsel } = scan ? { cnt[3], /*cnt[0]*/ 1'b1 } : 2'b11;
assign not_din = ~din;

assign joy_sorted = {joy_scan[8],joy_scan[7],joy_scan[11:9],joy_scan[5:4],joy_scan[6],joy_scan[3:0]};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        joy0     <= 12'd0;
        joy1     <= 12'd0;
        joy_scan <= 12'h0;
        cnt      <= 4'd0;
        last_but <= 0;
        hooked   <= 1;
        sample   <= 0;
        md6      <= 0;
    end else begin
        if( !scan ) begin
            cnt <= 4'd0;
        end else begin
            last_split <= split;
            sample       <= 0;

            if( split != last_split ) begin
                joy_scan <= 12'h0;
                md6      <= 0;
                if( split ) begin
                    joy0 <= joy_sorted;
                    last_but <= joy0[4];
                    if( last_but && !joy0[4] ) hooked <= 1;
                end else begin
                    //joy1 <= joy_sorted;
                    sample <= 1;
                end
            end

            if( cen ) begin
                cnt <= cnt+1'd1;
                if( !mdsel ) begin
                    md6 <= 0;
                    if( din[3:2]==2'b0 )
                        md6 <= 1;
                    else if( din[1:0]==2'b0 )
                        joy_scan[7:6]  <= not_din[5:4];
                end else begin
                    if( md6 )
                        joy_scan[11:8] <= not_din[3:0];
                    else
                        joy_scan[ 5:0] <= not_din[5:0];
                end
            end
        end
    end
end

endmodule