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
    Date: 14-3-2020 */
    
`timescale 1ns/1ps

// 8x8 tiles

module jtframe_credits(
    input              rst,
    input              clk,

);

parameter MSGW=10;

// Character font
reg [7:0] char_mem[0:763]; // 96 8x8 characters
reg [7:0] char_msg[0:(2**MSGW)-1];

initial begin
    

endmodule