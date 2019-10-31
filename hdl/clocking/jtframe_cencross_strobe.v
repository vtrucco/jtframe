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
    Date: 31-10-2019 */

// Converts an input strobe (stin) defined in some clock gating domain
// to a strobe in the specified cen input domain

module jtframe_cencross_strobe(
    (* direct_enable *) input       cen,
    input       clk,
    input       stin,
    output      stout
);

reg last, st_latch, clr;

always @(posedge clk) begin 
    last <= stin;
    if( stin && !last) st_latch <= 1'b1;
    if( clr ) st_latch <= 1'b0;
end

assign stout = cen & (st_latch | stin);

always @(posedge clk) if(cen) begin
    clr <= stout;
end

endmodule