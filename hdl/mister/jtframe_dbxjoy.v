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

module jtframe_dbxjoy(
    input               rst,
    input               clk,
    input               hs,     // horizontal sync

    input        [15:0] usb_joy0,
    input        [15:0] usb_joy1,

    output reg   [15:0] mix_joy0,
    output reg   [15:0] mix_joy1,
    output reg   [ 5:0] raw_joy,

    output reg   [ 1:0] start,
    output reg   [ 1:0] coin,

    output reg          user_osd,
    input        [ 7:0] user_in,
    output reg   [ 7:0] user_out
);

// All joysticks:
// joy[11]  = mode/select
// joy[10]  = start
// joy[3:0] = directions

parameter BUTTONS=2, CNTW=5;

reg            cen;
reg [CNTW-1:0] hs_cnt;
reg     [ 7:0] latch;     // user_in data is latched
reg            last_hs;

wire         neo_hooked, md_hooked, neo_sample, md_sample;
//reg   [ 1:0] scan;

wire  [11:0] neo_joy0, neo_joy1, md_joy0, md_joy1;
reg   [11:0] db_joy0, db_joy1;
wire         joy_clk, loadb, md_split, md_sel;
wire  [ 5:0] md_din   = { latch[6], latch[3], latch[5], latch[7], latch[1], latch[2] };
wire         neo_din  = latch[5];
wire         neo_scan, md_scan;

assign       { neo_scan, md_scan } = 2'b01; //scan;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        hs_cnt <= {CNTW{1'b0}};
        last_hs <= 0;
    end else begin
        last_hs <= hs;
        if( hs && !last_hs ) begin
            cen <= 1;
            hs_cnt <= hs_cnt + 1'd1;
        end else cen <= 0;
    end
end
/*
always @(posedge clk or posedge rst) begin
    if(rst) begin
        //scan <= 2'b1;
        md_scan <= 0;
    end else begin
        //if( md_sample || neo_sample ) scan <= {scan[0], scan[1]};
        if( md_sample ) begin
            md_scan <= 0;
        end else begin
            if( &hs_cnt )
                md_scan <= 1;
        end
    end
end
*/
always @(posedge clk) begin
    latch    <= user_in;
    { db_joy1, db_joy0 } <= neo_hooked ? { neo_joy1, neo_joy0 } : (
                            md_hooked  ? { md_joy1, md_joy0 } : 24'd0 );

    user_osd <= db_joy0[10] & db_joy0[6];
    raw_joy  <= db_joy0[5:0] | db_joy1[5:0];

    mix_joy0 <= { {12-BUTTONS{1'b0}}, db_joy0[BUTTONS+3:0]} | usb_joy0;
    mix_joy1 <= { {12-BUTTONS{1'b0}}, db_joy1[BUTTONS+3:0]} | usb_joy1;

    start    <= { db_joy1[10], db_joy0[10] };

    if( md_hooked && BUTTONS<6 ) begin
        // Try to use one of the free buttons as the coin
        coin <= { |{ db_joy1[11], db_joy1[9:4+BUTTONS] },
                  |{ db_joy0[11], db_joy0[9:4+BUTTONS] } };
    end else begin
        coin <= { db_joy1[11], db_joy0[11] };
    end

    // user port pins
    user_out <= { 3'b111, md_split, 2'b11, /*joy_clk*/1'b1, md_sel /*& loadb*/};
end

jtframe_db9joy u_db9(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen_hs ( cen       ),
    .scan   ( md_scan   ),

    .din    ( md_din    ),
    .split  ( md_split  ),
    .mdsel  ( md_sel    ),

    .hooked ( md_hooked ),
    .sample ( md_sample ),
    .joy0   ( md_joy0   ),
    .joy1   ( md_joy1   )
);

assign neo_hooked = 0;

jtframe_db15joy u_db15(
    .rst     ( rst       ),
    .clk     ( clk       ),
    .cen     ( cen       ),
    .scan    ( neo_scan  ),

    .joy_clk ( joy_clk   ),
    .din     ( neo_din   ),
    .loadb   ( loadb     ),

    //.hooked  ( neo_hooked),
    .hooked(  ),
    .sample  ( neo_sample),
    .joy0    ( neo_joy0  ),
    .joy1    ( neo_joy1  )
);

endmodule