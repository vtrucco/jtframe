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
    Date: 22-2-2019 */

module jtframe_mist_clocks(
    input   clk_ext,    // 27MHz for MiST, 50MHz for Neptuno

    // PLL outputs
    output  clk96,
    output  clk48,
    output  clk24,
    output  clk6,
    output  pll_locked,

    // System clocks
    output  clk_sys,
    output  clk_rom,
    output  SDRAM_CLK
);

`ifndef JTFRAME_PLL
    `define JTFRAME_PLL jtframe_pll0
`endif

wire pll0_lock, pll1_lock, clk27;

assign pll_locked = pll0_lock & pll1_lock;

`ifdef NEPTUNO
    pll_neptuno u_pllneptuno(
        .inclk0 ( clk_ext   ),
        .c0     ( clk27     ),
        .locked ( pll0_lock )
    );
`else
    assign clk27 = clk_ext;
    assign pll0_lock = 1;
`endif

// clk_rom is always 48MHz
// clk96, clk24 and clk6 inputs to the core can be enabled via macros
`ifdef JTFRAME_SDRAM96
    jtframe_pll96 u_pll_game (
        .inclk0 ( clk27       ),
        .c0     ( clk48       ), // 48 MHz
        .c1     ( clk96       ), // 96 MHz
        .c2     ( SDRAM_CLK   ), // 96 MHz shifted
        .c3     ( clk24       ),
        .c4     ( clk6        ),
        .locked ( pll1_lock   )
    );
    assign clk_rom = clk96;
    assign clk_sys = clk96;
`else
    `JTFRAME_PLL u_pll_game (
        .inclk0 ( clk27       ),
        .c0     ( clk96       ),
        .c1     ( clk48       ), // 48 MHz
        .c2     ( SDRAM_CLK   ),
        .c3     ( clk24       ),
        .c4     ( clk6        ),
        .locked ( pll1_lock   )
    );
    assign clk_rom = clk48;
    `ifdef JTFRAME_CLK96
        assign clk_sys   = clk96; // it is possible to use clk48 instead but
            // video mixer doesn't work well in HQ mode
    `else
        assign clk_sys   = clk_rom;
    `endif
`endif

endmodule