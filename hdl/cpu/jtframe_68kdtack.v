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
    input       bus_legit,
    input       BUSn,   // BUSn = ASn | (LDSn & UDSn)

    output reg  DTACKn
);

parameter CENCNT=6,  // denominator
          CENSTEP=1; // numerator
localparam CW=$clog2(CENCNT+CENSTEP-1)+6+1;

reg [CW-1:0] cencnt=0;
reg wait1, halt;
wire over = cencnt>=CENCNT-1;

initial begin
    if( CENCNT<3 ) begin
        $display("Error: CENCNT must be 3 or more, otherwise recovery won't work (%m)");
        $finish;
    end
end

always @(posedge clk, posedge rst) begin : dtack_gen
    if( rst ) begin
        DTACKn <= 1'b1;
        wait1  <= 1;
        halt   <= 0;
    end else begin
        if( BUSn ) begin // DSn is needed for read-modify-write cycles
            DTACKn <= 1;
            wait1  <= 1;
            halt   <= 0;
        end else if( !BUSn ) begin
            if( cpu_cen  ) wait1 <= 0;
            if( !wait1 ) begin
                if( !bus_cs || (bus_cs && !bus_busy) ) begin
                    DTACKn <= 0;
                    halt <= 0;
                end else begin
                    halt <= !bus_legit;
                end
            end
        end
    end
end

always @(posedge clk) begin
    cencnt  <= (over && !cpu_cen && !halt) ? (cencnt+CENSTEP-CENCNT) : (cencnt+CENSTEP);
    if( halt ) begin
        cpu_cen  <= 0;
        cpu_cenb <= 0;
    end else begin
        cpu_cen <= over ? ~cpu_cen : 0;
        cpu_cenb<= cpu_cen;
    end
end

endmodule