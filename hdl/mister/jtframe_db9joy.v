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

parameter CNTW=6;

localparam [CNTW-1:0] IGNORE=8;

reg  [CNTW-1:0] cnt;
reg  [11:0] joy_scan;
wire [11:0] joy_sorted;
wire [ 5:0] not_din;
reg         last_split, last_but, md6, md3;
reg  [ 3:0] joy1_en;
reg         con;        // connected
wire        ignore;

assign { split, mdsel } = scan ? { cnt[CNTW-1], cnt[0] } : 2'b11;
assign not_din = ~din;
assign ignore  = !cnt[CNTW-1] && cnt[CNTW-2:1] <= IGNORE;

assign joy_sorted = {   joy_scan[8],    // mode
                        joy_scan[7],    // start
                        joy_scan[11:9],
                        joy_scan[5:4],  // buttons B, C
                        joy_scan[6],    // button A
                        joy_scan[3:0]   // direction
                    };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        joy0     <= 12'd0;
        joy1     <= 12'd0;
        joy1_en  <= 4'd0;
        joy_scan <= 12'h0;
        cnt      <= {CNTW{1'b0}};
        last_but <= 0;
        hooked   <= 1;
        sample   <= 0;
        md6      <= 0;
        md3      <= 0;
        con      <= 0;
    end else begin
        last_split <= cnt[CNTW-1];
        if( !scan ) begin
            cnt        <= {CNTW{1'b0}};
            md3        <= 0;
            md6        <= 0;
            joy_scan  <= 12'h0;
        end else begin
            sample       <= 0;

            if( cnt[CNTW-1] != last_split ) begin
                joy_scan <= 12'h0;
                md3      <= 0;
                md6      <= 0;
                con      <= 0;
                if( split ) begin
                    joy0 <= joy_sorted;
                    last_but <= joy0[4];
                    if( last_but && !joy0[4] ) hooked <= 1;
                end else begin
                    if( !con )  begin
                        // detects that the controller was disconnected
                        // this is useful when the splitter is removed
                        // and the gamepad gets connected singlely again
                        joy1_en <= 4'd0;
                        joy1    <= 12'h0;
                    end else begin
                        // 2nd controller detection
                        if( joy_sorted != joy0 )
                            joy1_en <= { joy1_en[2:0], 1'b1 };
                        else if( !joy1_en[3] )
                            joy1_en <= 4'd0;

                        if( joy1_en[3] )
                            joy1 <= joy_sorted;
                    end
                    sample <= 1;
                end
            end

            if( cen ) begin
                cnt <= cnt+1'd1;
                if( !ignore ) begin
                    if( !mdsel ) begin
                        md3 <= 0;
                        md6 <= 0;
                        if( din[3:2]==2'b0 )
                            md6 <= 1;
                        else if( din[1:0]==2'b0 ) begin
                            joy_scan[7:6] <= not_din[5:4];
                            md3 <= 1;
                            con <= 1; // controller detected
                        end
                    end else begin
                        if( md6 )
                            joy_scan[11:8] <= not_din[3:0];
                        if( md3 )
                            joy_scan[ 5:0] <= not_din[5:0];
                    end
                end
            end
        end
    end
end

endmodule