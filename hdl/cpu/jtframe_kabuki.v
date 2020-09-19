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
      Date: 19-9-2020

*/

// Instantiate with LATCH=1 to latch the output data
// by default the module behaves purely combinational

module jtframe_kabuki(
    input             rst_n,
    input             clk,
    input             m1_n,
    input             rd_n,
    input             mreq_n,
    input      [15:0] addr,
    input      [ 7:0] din,
    // Decode keys
    input      [31:0] swap_key1,
    input      [31:0] swap_key2,
    input      [15:0] addr_key,
    input      [ 7:0] xor_key,
    output reg [ 7:0] dout
);

parameter LATCH=0;

reg [15:0] addr_hit;
reg [ 7:0] dec;

function [7:0] bitswap1(
        input [ 7:0] din,
        input [15:0] key,
        input [ 7:0] hit );
    bitswap1 = {
        hit[ key[14:12] ] ? { din[6], din[7] } : din[7:6],
        hit[ key[10: 8] ] ? { din[4], din[5] } : din[5:4],
        hit[ key[ 6: 4] ] ? { din[2], din[3] } : din[3:2],
        hit[ key[ 2: 0] ] ? { din[0], din[1] } : din[1:0]
    };
endfunction

function [7:0] bitswap2(
        input [ 7:0] din,
        input [15:0] key,
        input [ 7:0] hit );
    bitswap2 = {
        hit[ key[ 2: 0] ] ? { din[6], din[7] } : din[7:6],
        hit[ key[ 6: 4] ] ? { din[4], din[5] } : din[5:4],
        hit[ key[10: 8] ] ? { din[2], din[3] } : din[3:2],
        hit[ key[14:12] ] ? { din[0], din[1] } : din[1:0]
    };
endfunction

always @(*) begin
    addr_hit = m1_n ?
        ( (addr ^ 16'h1fc0) + addr_key + 16'd1 ) : // data
        (addr + addr_key); // OP
    dec = din;
    if( !mreq_n && !rd_n ) begin
        dec = bitswap1( dec, swap_key1[15:0], addr_hit[7:0] );
        dec = { dec[6:0], dec[7] };

        dec = bitswap2( dec, swap_key1[31:16], addr_hit[7:0] );
        dec = dec ^ xor_key;
        dec = { dec[6:0], dec[7] };

        dec = bitswap2( dec, swap_key2[15:0], addr_hit[15:8] );
        dec = { dec[6:0], dec[7] };

        dec = bitswap1( dec, swap_key2[31:16], addr_hit[15:8] );
    end
end

generate
    if( LATCH ) begin : latch_output
        always @(posedge clk, negedge rst_n )
            if( !rst_n )
                dout <= 8'd0;
            else
                dout <= dec;
    end else begin : pass_thru
        always @(dec)
            dout = dec;
    end
endgenerate

endmodule