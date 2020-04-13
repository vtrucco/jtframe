/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-10-2019 */

`timescale 1ns/1ps

module jtframe_dip(
    input              clk,
    input      [31:0]  status,
    input      [ 6:0]  core_mod,
    input              game_pause,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    output reg [ 7:0]  hdmi_arx,
    output reg [ 7:0]  hdmi_ary,
    output reg [ 1:0]  rotate,
    output             rot_control,
    output reg         en_mixing,
    output     [ 2:0]  scanlines,

    output reg         enable_fm,
    output reg         enable_psg,

    inout              dip_test,
    // non standard:
    output reg         dip_pause,
    inout              dip_flip,    // this might be set by the core
    output reg [ 1:0]  dip_fxlevel
);

// "T0,RST;", // 15
// "O1,Pause,OFF,ON;",
// "-;",
// "F,rom;",
// "O2,Aspect Ratio,Original,Wide;",
// "OD,Original screen,No,Yes;",
// "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
// "O6,Test mode,OFF,ON;",
// "O7,PSG,ON,OFF;",
// "O8,FM ,ON,OFF;",
// "O3,Screen filter,ON,OFF;",
// "OAB,FX volume, high, very high, very low, low;",
// core-specific settings should start at letter G (i.e. 16)

`ifdef JTFRAME_OSD_FLIP
assign dip_flip    = status[1];
`endif

`ifdef JTFRAME_OSD_TEST
    `ifdef SIMULATION
        `ifdef DIP_TEST
            dip_test = 1'b0;
        `else
            dip_test = 1'b1;
        `endif
    `else
        assign dip_test = ~status[10];
    `endif
`endif

wire   widescreen  = status[11];    // only MiSTer
assign scanlines   = status[5:3];

`ifdef VERTICAL_SCREEN
    // core_mod[0] = 0 horizontal game
    //             = 1 vertical game
    // status[13]  = 0 Rotate screen
    //             = 1 no rotation  
    `ifdef MISTER
    wire   tate   = ~status[2] & core_mod[0]; // 1 if screen is vertical (tate in Japanese)
    assign rot_control = 1'b0;
    `else
    wire   tate   = 1'b1 & core_mod[0];      // MiST is always vertical
    assign rot_control = status[2];
    `endif
    wire   swap_ar = ~tate | ~core_mod[0];
`else
    wire   tate   = 1'b0;
    assign rot_control = 1'b0;
    wire   swap_ar = 1'b1;
`endif

// all signals that are not direct re-wirings are latched
always @(posedge clk) begin
    rotate      <= { dip_flip, tate && !rot_control };
    dip_fxlevel <= 2'b10 ^ status[7:6];
    en_mixing   <= ~status[3];
    enable_fm   <= ~status[9];
    enable_psg  <= ~status[8];
    // only for MiSTer
    hdmi_arx    <= widescreen ? 8'd16 : swap_ar ? 8'd4 : 8'd3;
    hdmi_ary    <= widescreen ? 8'd9  : swap_ar ? 8'd3 : 8'd4;

    `ifdef SIMULATION
        `ifdef DIP_PAUSE
            dip_pause <= 1'b0; // use to simulate pause screen
        `else
            dip_pause <= 1'b1; // avoid having the main CPU halted in simulation
        `endif
    `else
        dip_pause <= 
            `ifndef JTFRAME_OSD_NOCREDITS
            (~status[15]) | // Control pause via OSD too
            `endif
            game_pause; // all dips are active low
    `endif
end

endmodule