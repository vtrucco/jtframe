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
    Date: 10-5-2021 */

module jtframe_inputs(
    input             rst,
    input             clk,

    input             dip_flip,

    output reg        soft_rst,
    output reg        game_pause,

    input      [15:0] board_joy1,
    input      [15:0] board_joy2,
    input      [15:0] board_joy3,
    input      [15:0] board_joy4,
    input       [3:0] board_coin,
    input       [3:0] board_start,

    input       [9:0] key_joy1,
    input       [9:0] key_joy2,
    input       [9:0] key_joy3,
    input       [3:0] key_start,
    input       [3:0] key_coin,
    input             key_service,
    input             key_test,

    input             key_pause,
    input             osd_pause,
    input             key_reset,
    input             rot_control,

    output reg [9:0]  game_joy1,
    output reg [9:0]  game_joy2,
    output reg [9:0]  game_joy3,
    output reg [9:0]  game_joy4,
    output reg [3:0]  game_coin,
    output reg [3:0]  game_start,
    output reg        game_service,
    output            game_test,
    input             lock, // disable joystick inputs

    // For simulation only
    input             downloading,
    input             LVBL
);

parameter BUTTONS    = 2,
          ACTIVE_LOW = 1;

reg  [15:0] joy1_sync, joy2_sync, joy3_sync, joy4_sync;
wire [ 3:0] joy4way1p, joy4way2p, joy4way3p, joy4way4p;

`ifdef JTFRAME_SUPPORT_4WAY
    wire en4way = core_mod[1];
`else
    wire en4way = 0;
`endif

always @(posedge clk) begin
    joy1_sync <= { board_joy1[15:4], joy4way1p[3:0] };
    joy2_sync <= { board_joy2[15:4], joy4way2p[3:0] };
    joy3_sync <= { board_joy3[15:4], joy4way3p[3:0] };
    joy4_sync <= { board_joy4[15:4], joy4way4p[3:0] };
end

jtframe_4wayjoy u_4way_1p(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .enable     ( en4way            ),
    .joy8way    ( board_joy1[3:0]   ),
    .joy4way    ( joy4way1p         )
);

jtframe_4wayjoy u_4way_2p(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .enable     ( en4way            ),
    .joy8way    ( board_joy2[3:0]   ),
    .joy4way    ( joy4way2p         )
);

jtframe_4wayjoy u_4way_3p(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .enable     ( en4way            ),
    .joy8way    ( board_joy3[3:0]   ),
    .joy4way    ( joy4way3p         )
);

jtframe_4wayjoy u_4way_4p(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .enable     ( en4way            ),
    .joy8way    ( board_joy4[3:0]   ),
    .joy4way    ( joy4way4p         )
);

localparam START_BIT  = 6+(BUTTONS-2);
localparam COIN_BIT   = 7+(BUTTONS-2);
localparam PAUSE_BIT  = 8+(BUTTONS-2);

reg last_pause, last_osd_pause, last_joypause, last_reset;
wire joy_pause = joy1_sync[PAUSE_BIT] | joy2_sync[PAUSE_BIT];

function [9:0] apply_rotation;
    input [9:0] joy_in;
    input       rot;
    input       flip;
    begin
    apply_rotation = {10{ACTIVE_LOW[0]}} ^
        (!rot ? joy_in :
        flip ?
         { joy_in[9:4], joy_in[1], joy_in[0], joy_in[2], joy_in[3] } :
         { joy_in[9:4], joy_in[0], joy_in[1], joy_in[3], joy_in[2] });
    end
endfunction

`ifdef SIM_INPUTS
    reg [15:0] sim_inputs[0:16383];
    integer frame_cnt;
    initial begin : read_sim_inputs
        integer c;
        for( c=0; c<16384; c=c+1 ) sim_inputs[c] = 8'h0;
        $display("INFO: input simulation enabled");
        $readmemh( "sim_inputs.hex", sim_inputs );
    end
    always @(negedge LVBL, posedge rst) begin
        if( rst )
            frame_cnt <= 0;
        else frame_cnt <= frame_cnt+1;
    end
    assign game_test = sim_inputs[frame_cnt][10];
`else
    assign game_test = key_test;
`endif

always @(posedge clk) begin
    if(rst ) begin
        game_pause   <= 0;
        game_service <= 1'b0 ^ ACTIVE_LOW[0];
        soft_rst     <= 0;
    end else begin
        last_pause     <= key_pause;
        last_osd_pause <= osd_pause;
        last_reset     <= key_reset;
        last_joypause  <= joy_pause; // joy is active low!

        // joystick, coin, start and service inputs are inverted
        // as indicated in the instance parameter

        `ifdef SIM_INPUTS
        game_coin  <= {4{ACTIVE_LOW[0]}} ^ { 2'b0, sim_inputs[frame_cnt][1:0] };
        game_start <= {4{ACTIVE_LOW[0]}} ^ { 2'b0, sim_inputs[frame_cnt][3:2] };
        game_joy1 <= {10{ACTIVE_LOW[0]}} ^ { 4'd0, sim_inputs[frame_cnt][9:4]};
        `else
        game_joy1 <= apply_rotation(joy1_sync | key_joy1, rot_control, ~dip_flip );
        game_coin      <= {4{ACTIVE_LOW[0]}} ^
            ({  joy4_sync[COIN_BIT],joy3_sync[COIN_BIT],
                joy2_sync[COIN_BIT],joy1_sync[COIN_BIT]} | key_coin | board_coin );

        game_start     <= {4{ACTIVE_LOW[0]}} ^
            ({  joy4_sync[START_BIT],joy3_sync[START_BIT],
                joy2_sync[START_BIT],joy1_sync[START_BIT]} | key_start | board_start );
        `endif
        game_joy2 <= apply_rotation(joy2_sync | key_joy2, rot_control, ~dip_flip );
        game_joy3 <= apply_rotation(joy3_sync | key_joy3, rot_control, ~dip_flip );
        game_joy4 <= apply_rotation(joy4_sync           , rot_control, ~dip_flip );


        soft_rst <= key_reset && !last_reset;

        // state variables:
        `ifndef DIP_PAUSE // Forces pause during simulation
        if( downloading )
            game_pause<=0;
        else begin// toggle
            if( (key_pause && !last_pause) || (joy_pause && !last_joypause) )
                game_pause   <= ~game_pause;
            if (last_osd_pause ^ osd_pause) game_pause <= osd_pause;
        end
        `else
        game_pause <= 1'b1;
        `endif
        game_service <= key_service ^ ACTIVE_LOW[0];

        // Disable inputs for locked cores
        if( lock ) begin
            game_joy1    <= {10{ACTIVE_LOW[0]}};
            game_joy2    <= {10{ACTIVE_LOW[0]}};
            game_joy3    <= {10{ACTIVE_LOW[0]}};
            game_joy4    <= {10{ACTIVE_LOW[0]}};
            game_start   <= {4{ACTIVE_LOW[0]}};
            game_coin    <= {4{ACTIVE_LOW[0]}};
            game_pause   <= 0;
            game_service <= ACTIVE_LOW[0];
        end
    end
end

endmodule