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
    Date: 29-4-2021 */

module jtframe_sdram64_latch #(parameter LATCH=0, AW=22)(
    input               rst,
    input               clk,
    input      [AW-1:0] ba0_addr,
    input      [AW-1:0] ba1_addr,
    input      [AW-1:0] ba2_addr,
    input      [AW-1:0] ba3_addr,
    output reg [AW-1:0] ba0_addr_l,
    output reg [AW-1:0] ba1_addr_l,
    output reg [AW-1:0] ba2_addr_l,
    output reg [AW-1:0] ba3_addr_l,
    input         [3:0] rd,
    input         [3:0] wr,
    output reg    [3:0] rd_l,
    output reg    [3:0] wr_l
);

generate
    if( LATCH==1 ) begin
        always @(posedge clk, posedge rst) begin
            if( rst ) begin
                ba0_addr_l <= 0;
                ba1_addr_l <= 0;
                ba2_addr_l <= 0;
                ba3_addr_l <= 0;
                wr_l       <= 0;
                rd_l       <= 0;
            end else begin
                ba0_addr_l <= ba0_addr;
                ba1_addr_l <= ba1_addr;
                ba2_addr_l <= ba2_addr;
                ba3_addr_l <= ba3_addr;
                wr_l       <= wr;
                rd_l       <= rd;
            end
        end
    end else begin
        always @(*) begin
                ba0_addr_l = ba0_addr;
                ba1_addr_l = ba1_addr;
                ba2_addr_l = ba2_addr;
                ba3_addr_l = ba3_addr;
                wr_l       = wr;
                rd_l       = rd;
        end
    end
endgenerate

endmodule
