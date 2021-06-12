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
    Date: 12-6-2021 */

module jtframe_neptuno_joy(
    input   clk,
    input   hs,

    output  joy_clk,
    input   joy_data,
    output  joy_load,
    output  joy_select,

    output [11:0] joy1,
    output [11:0] joy2
);

wire joy1_up, joy1_down, joy1_left, joy1_right, joy1_p6, joy1_p9;
wire joy2_up, joy2_down, joy2_left, joy2_right, joy2_p6, joy2_p9;

wire [11:0] inv1, inv2;

assign joy1 = ~inv1;
assign joy2 = ~inv2;

joydecoder u_serial  (
    .clk          ( clk        ),
    .joy_data     ( joy_data   ),
    .joy_clk      ( joy_clk    ),
    .joy_load     ( joy_load   ),
    .clock_locked ( 1'b1       ),

    .joy1up       ( joy1_up    ),
    .joy1down     ( joy1_down  ),
    .joy1left     ( joy1_left  ),
    .joy1right    ( joy1_right ),
    .joy1fire1    ( joy1_p6    ),
    .joy1fire2    ( joy1_p9    ),

    .joy2up       ( joy2_up    ),
    .joy2down     ( joy2_down  ),
    .joy2left     ( joy2_left  ),
    .joy2right    ( joy2_right ),
    .joy2fire1    ( joy2_p6    ),
    .joy2fire2    ( joy2_p9    )
);

joystick_sega u_sega
(
    .joy0 ({ joy1_p9, joy1_p6, joy1_up, joy1_down, joy1_left, joy1_right }),
    .joy1 ({ joy2_p9, joy2_p6, joy2_up, joy2_down, joy2_left, joy2_right }),

    .player1     ( inv1       ),
    .player2     ( inv2       ),
    .sega_clk    ( hs         ),
    .sega_strobe ( joy_select )
);

endmodule
