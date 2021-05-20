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
    Date: 20-5-2021 */

module jtframe_68kdtack(
    input       rst,
    input       clk,
    output reg  cpu_cen,
    output reg  cpu_cenb,
    input       bus_cs,
    input       bus_busy,
    input       ASn,

    output reg  DTACKn
);

parameter CENCNT=6, MISSW=7;

localparam [MISSW-1:0] RECSTEP = CENCNT-2;

reg [MISSW-1:0] miss;
reg [$clog2(CENCNT):0] cencnt=0;
reg wait1;

//wire hurry   = ASn===1 && (miss!=0);
wire hurry   = ASn===1 || (ASn===0 && !DTACKn) && (miss!=0);
wire recover = hurry && cencnt==1;

`ifdef SIMULATION
initial begin
    if( CENCNT<3 ) begin
        $display("Error: CENCNT must be 3 or more (%m)");
        $finish;
    end
end
`endif

always @(posedge clk, posedge rst) begin : dtack_gen
    if( rst ) begin
        DTACKn <= 1'b1;
        wait1  <= 1;
        miss   <= 0;
    end else begin
        if( ASn ) begin
            DTACKn <= 1;
            wait1 <= 1;
        end else if( !ASn ) begin
            if( cpu_cen  ) wait1 <= 0;
            if( cpu_cenb ) begin
                if( !wait1 ) begin
                    if( !bus_cs || (bus_cs && !bus_busy) ) DTACKn <= 0;
                end
            end
            if( !wait1 && DTACKn ) miss <= miss + 1'd1;
        end
        if( recover ) miss <= ( miss > RECSTEP ) ? miss - RECSTEP : 0;
    end
end

always @(posedge clk) begin
    cencnt  <= (cencnt==(CENCNT-1) || recover) ? 0 : (cencnt+1'd1);
    cpu_cen <= cencnt==0;
    cpu_cenb<= cencnt==1;
end

endmodule