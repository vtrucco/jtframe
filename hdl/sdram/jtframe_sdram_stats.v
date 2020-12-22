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
    Date: 22-12-2020 */

module jtframe_sdram_stats #(
    parameter AW=22)(
    input               rst,
    input               clk,
    // SDRAM interface
    // SDRAM_A[12:11] and SDRAM_DQML/H are controlled in a way
    // that can be joined together thru an OR operation at a
    // higher level. This makes it possible to short the pins
    // of the SDRAM, as done in the MiSTer 128MB module
    input       [12:0]  sdram_a,        // SDRAM Address bus 13 Bits
    input       [ 1:0]  sdram_ba,       // SDRAM Bank Address
    input               sdram_nwe,      // SDRAM Write Enable
    input               sdram_ncas,     // SDRAM Column Address Strobe
    input               sdram_nras,     // SDRAM Row Address Strobe
    input               sdram_ncs       // SDRAM Chip Select
);

//                             /CS /RAS /CAS /WE
localparam CMD_LOAD_MODE   = 4'b0___0____0____0, // 0
           CMD_REFRESH     = 4'b0___0____0____1, // 1
           CMD_PRECHARGE   = 4'b0___0____1____0, // 2
           CMD_ACTIVE      = 4'b0___0____1____1, // 3
           CMD_WRITE       = 4'b0___1____0____0, // 4
           CMD_READ        = 4'b0___1____0____1, // 5
           CMD_STOP        = 4'b0___1____1____0, // 6 Burst terminate
           CMD_NOP         = 4'b0___1____1____1, // 7
           CMD_INHIBIT     = 4'b1___0____0____0; // 8

wire [3:0] cmd;

reg [12:0] last_row0, last_row1, last_row2, last_row3;

integer access0, access1, access2, access3,
        same_row0, same_row1, same_row2, same_row3;

assign cmd = {sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe };

jtframe_sdram_stats_bank #(0) u_bank0(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sdram_a    ( sdram_a   ),
    .sdram_ba   ( sdram_ba  ),
    .cmd        ( cmd       )
);

jtframe_sdram_stats_bank #(1) u_bank1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sdram_a    ( sdram_a   ),
    .sdram_ba   ( sdram_ba  ),
    .cmd        ( cmd       )
);

jtframe_sdram_stats_bank #(2) u_bank2(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sdram_a    ( sdram_a   ),
    .sdram_ba   ( sdram_ba  ),
    .cmd        ( cmd       )
);

jtframe_sdram_stats_bank #(3) u_bank3(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sdram_a    ( sdram_a   ),
    .sdram_ba   ( sdram_ba  ),
    .cmd        ( cmd       )
);

endmodule

module jtframe_sdram_stats_bank(
    input               rst,
    input               clk,
    input  [12:0]       sdram_a,
    input  [ 1:0]       sdram_ba,
    input  [ 3:0]       cmd,
    output     integer  count,
    output     integer  longest,
    output     integer  samerow
);

parameter BA=0;

integer cur;
reg [12:0] row;

wire act = cmd==4'd3 && sdram_ba==BA;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        count <= 0;
        longest <= 0;
        samerow <= 0;
        cur <= 0;
    end else begin
        if( act ) begin
            if( sdram_a == row ) begin
                cur <= cur + 1;
                samerow <= samerow + 1;
            end else begin
                cur <= 1;
                if( cur > longest ) longest <= cur;
                row <= sdram_a;
            end
            count <= count+1;
        end
    end
end

endmodule