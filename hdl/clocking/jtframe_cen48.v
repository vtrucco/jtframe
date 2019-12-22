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
    Date: 6-12-2019 */

// Input clock must be 48 MHz
// Generates various clock enable signals

module jtframe_cen48(
    input   clk,    // 48 MHz
    output  reg cen12,
    output  reg cen8,
    output  reg cen6,
    output  reg cen3,
    output  reg cen3q, // 1/4 advanced with respect to cen3
    output  reg cen1p5,
    // 180 shifted signals
    output  reg cen12b,
    output  reg cen6b,
    output  reg cen3b,
    output  reg cen3qb
);

reg [4:0] cencnt=5'd0;
reg [2:0] cencnt6=3'd0;

always @(posedge clk) begin
    cencnt  <= cencnt+5'd1;
    cencnt6 <= cencnt6==3'd5 ? 3'd0 : (cencnt6+3'd1);
end

always @(negedge clk) begin
    cen12  <= cencnt[1:0] == 2'd0;
    cen12b <= cencnt[1:0] == 2'd2;
    cen8   <= cencnt6     == 3'd0;
    cen6   <= cencnt[2:0] == 3'd0;
    cen6b  <= cencnt[2:0] == 3'd4;
    cen3   <= cencnt[3:0] == 4'd0;
    cen3b  <= cencnt[3:0] == 4'h8;
    cen3q  <= cencnt[3:0] == 4'b1100;
    cen3qb <= cencnt[3:0] == 4'b0100;
    cen1p5 <= cencnt[4:0] == 5'd0;
end

endmodule

// Generates a 3.57 MHz clock enable signal for a 48MHz clock
// Result: 105/1408 = 3,579,545.5 MHz, off by 0.5Hz (0.14ppm) :-)

module jtframe_cen3p57(
    input      clk,       // 48 MHz
    output reg cen_3p57,
    output reg cen_1p78
);

wire [10:0] step=11'd105;
wire [10:0] lim =11'd1408;
wire [10:0] absmax = lim+step;

reg  [10:0] cencnt=11'd0;
reg  [10:0] next;
reg  [10:0] next2;

always @(*) begin
    next  = cencnt+11'd105;
    next2 = next-lim;
end

reg alt=1'b0;

always @(negedge clk) begin
    cen_3p57 <= 1'b0;
    cen_1p78 <= 1'b0;
    if( cencnt >= absmax ) begin
        // something went wrong: restart
        cencnt <= 11'd0;
        alt    <= 1'b0;
    end else
    if( next >= lim ) begin
        cencnt <= next2;
        cen_3p57 <= 1'b1;
        alt    <= ~alt;
        if( alt ) cen_1p78 <= 1'b1;
    end else begin
        cencnt <= next;
    end
end

endmodule
