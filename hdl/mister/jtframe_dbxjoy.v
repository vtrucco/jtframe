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

    input        [15:0] joystick_0_USB,
    input        [15:0] joystick_1_USB,

    output reg   [15:0] joystick_0,
    output reg   [15:0] joystick_1,
    output reg   [ 5:0] joy_raw,

    output reg          USER_OSD,
    input        [ 7:0] USER_IN,
    output       [ 7:0] USER_OUT
);

reg          cen;
reg   [ 3:0] cen_cnt;

wire         neo_hooked, md_hooked, neo_sample, md_sample;
reg   [ 1:0] scan;

wire  [11:0] neo_joy0, neo_joy1, md_joy0, md_joy1;
reg   [11:0] db_joy0, db_joy1;
wire         joy_clk, loadb, md_split, md_sel;
wire  [ 5:0] md_din   = {USER_IN[6],USER_IN[3],USER_IN[5],USER_IN[7],USER_IN[1],USER_IN[2]};
wire         neo_din  = USER_IN[5];
wire         neo_scan, md_scan;

assign       USER_OUT = {3'b111,md_split,3'b111,md_sel} | {6'b111111,joy_clk,loadb};
assign       { neo_scan, md_scan } = scan;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        cen_cnt <= 4'd0;
    end else begin
        cen_cnt <= cen_cnt + 1'd1;
        cen     <= &cen_cnt;
    end
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        scan <= 2'b1;
    end else begin
        if( md_sample || neo_sample ) scan <= {scan[0], scan[1]};
    end
end

always @(posedge clk) begin
    { db_joy1, db_joy0 } <= neo_hooked ? { neo_joy1, neo_joy0 } : (
                            md_hooked  ? { md_joy1, md_joy0 } : 24'0 );

    USER_OSD   <= db_joy0[10] & db_joy0[6];
    joy_raw    <= db_joy0[5:0] | db_joy1[5:0];

    joystick_0 <= {7'd0, db_joy0[11]|(db_joy0[10]&db_joy0[5]),db_joy0[9],db_joy0[10],db_joy0[5:0]} | joystick_0_USB;
    joystick_1 <= {7'd0, db_joy1[11]|(db_joy1[10]&db_joy1[5]),db_joy1[10],db_joy1[9],db_joy1[5:0]} | joystick_1_USB;
end

jtframe_db9joy u_db9(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .scan   ( md_scan   ),

    .din    ( md_din    ),
    .split  ( md_split  ),
    .mdsel  ( md_sel    ),

    .hooked ( md_hooked ),
    .sample ( md_sample ),
    .joy0   ( md_joy0   ),
    .joy1   ( md_joy1   )
);

jtframe_db15joy u_db15(
    .rst     ( rst       ),
    .clk     ( clk       ),
    .cen     ( cen       ),
    .scan    ( neo_scan  ),

    .joy_clk ( joy_clk   ),
    .din     ( neo_din   ),
    .loadb   ( loadb     ),

    .hooked  ( neo_hooked),
    .sample  ( neo_sample),
    .joy0    ( neo_joy0  ),
    .joy1    ( neo_joy1  )
);

endmodule