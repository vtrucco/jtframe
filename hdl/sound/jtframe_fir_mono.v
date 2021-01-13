/* This file is part of JTFRAME.


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
    Date: 12-1-2021

*/

// Generic FIR filter for mono signals
// Max 255 coefficients

// Parameters
// KMAX = number of coefficients (8 bit value)
// COEFFS = hex file with filter coefficients

module jtframe_fir_mono(
    input             rst,
    input             clk,
    input             sample,
    input      signed [15:0] din,
    output reg signed [15:0] dout
);

parameter [7:0] KMAX = 8'd68;
parameter     COEFFS = "filter.hex";

reg signed [15:0] ram[0:511];   // dual port RAM
                                // the first half contains the coefficients
                                // the second half, contains the signal
reg        [ 7:0] pt_wr, pt_rd, cnt;
reg               st;
reg signed [35:0] acc;
reg signed [15:0] coeff;
reg signed [31:0] p;

function signed [35:0] ext;
    input signed [31:0] p;
    ext = { {4{p[31]}}, p };
endfunction

function [7:0] loop_inc;
    input [7:0] s;
    loop_inc = s == KMAX-8'd1 ? 8'd0 : s+8'd1;
endfunction

function signed [15:0] sat;
    input [35:0] a;
    sat = a[35:30] == {6{a[29]}} ? a[29:14] : { a[35], {15{~a[35]}} };
endfunction

always@(posedge clk, posedge rst) begin
    if( rst ) begin
        dout  <= 16'd0;
        pt_rd <= 8'd0;
        pt_wr <= 8'd0;
        cnt   <= 8'd0;
        acc   <= 36'd0;
        p     <= 32'd0;
        coeff <= 16'd0;
    end else begin
        if( sample ) begin
            pt_rd <= pt_wr;
            cnt   <= 0;
            ram[ { 2'd1, pt_wr } ] <= din;
            pt_wr <= loop_inc( pt_wr );
            acc   <= 36'd0;
            p     <= 32'd0;
            st    <= 0;
        end else begin
            if( cnt < KMAX ) begin
                st <= ~st;
                if( st == 0 ) begin
                    coeff <= ram[ {1'd0, cnt } ];
                end else begin
                    p     <= ram[ {1'd1, pt_rd } ] * coeff;
                    acc   <= acc + ext(p);
                    cnt   <= cnt+7'd1;
                    pt_rd <= loop_inc( pt_rd );
                end
            end else begin
                dout <= sat(acc);
            end
        end
    end
end

`ifdef SIMULATION
    integer aux;
`endif


initial begin
`ifdef SIMULATION
    for( aux=0;aux<512; aux=aux+1 ) begin
        ram[aux] = 16'd0;
    end
`endif
    $readmemh( COEFFS, ram );
end

endmodule

