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
    Date: 22-11-2020

*/

module jtframe_fir2(
    input             rst,
    input             clk,
    input             sample,
    input      signed [15:0] l_in,
    input      signed [15:0] r_in,
    output reg signed [15:0] l_out,
    output reg signed [15:0] r_out
);

localparam [6:0] KMAX = 7'd68;

reg signed [15:0] ram[0:511];   // dual port RAM
reg [6:0] pt_wr, pt_rd, cnt;
reg       st;
reg signed [35:0] acc_l, acc_r;
reg signed [15:0] coeff;
reg signed [31:0] p_l, p_r;

function signed [35:0] ext;
    input signed [31:0] p;
    ext = { {4{p[31]}}, p };
endfunction

function [6:0] loop_inc;
    input [6:0] s;
    loop_inc = s == KMAX ? 7'd0 : s+7'd1;
endfunction

function signed [15:0] sat;
    input [35:0] a;
    sat = a[35:30] == {6{a[29]}} ? a[29:14] : { a[35], {15{~a[35]}} };
endfunction

always@(posedge clk, posedge rst) begin
    if( rst ) begin
        l_out <= 16'd0;
        r_out <= 16'd0;
        pt_rd <= 7'd0;
        pt_wr <= 7'd0;
        cnt   <= 7'd0;
    end else begin
        if( sample ) begin
            pt_rd <= pt_wr;
            cnt   <= KMAX;
            ram[ { 2'd1, pt_wr } ] <= l_in;
            ram[ { 2'd2, pt_wr } ] <= r_in;
            pt_wr <= loop_inc( pt_wr );
            acc_l <= 36'd0;
            acc_r <= 36'd0;
            p_l   <= 32'd0;
            p_r   <= 32'd0;
            st    <= 0;
        end else begin
            if( cnt != 7'd0 ) begin
                st <= ~st;
                if( st == 0 ) begin
                    coeff <= ram[ {2'd0, cnt } ];
                end else begin
                    p_l <= ram[ {2'd1, pt_rd } ] * coeff;
                    p_r <= ram[ {2'd2, pt_rd } ] * coeff;
                    acc_l <= acc_l + ext(p_l);
                    acc_r <= acc_r + ext(p_r);
                    cnt <= cnt-7'd1;
                    pt_rd <= loop_inc( pt_rd );
                end
            end else begin
                l_out <= sat(acc_l);
                r_out <= sat(acc_r);
            end
        end
    end
end

initial begin
ram[ {2'd0, 7'd0} ] = -15;
ram[ {2'd0, 7'd1} ] = -25;
ram[ {2'd0, 7'd2} ] = -25;
ram[ {2'd0, 7'd3} ] = -10;
ram[ {2'd0, 7'd4} ] = 15;
ram[ {2'd0, 7'd5} ] = 42;
ram[ {2'd0, 7'd6} ] = 53;
ram[ {2'd0, 7'd7} ] = 36;
ram[ {2'd0, 7'd8} ] = -11;
ram[ {2'd0, 7'd9} ] = -73;
ram[ {2'd0, 7'd10} ] = -114;
ram[ {2'd0, 7'd11} ] = -101;
ram[ {2'd0, 7'd12} ] = -19;
ram[ {2'd0, 7'd13} ] = 105;
ram[ {2'd0, 7'd14} ] = 209;
ram[ {2'd0, 7'd15} ] = 224;
ram[ {2'd0, 7'd16} ] = 108;
ram[ {2'd0, 7'd17} ] = -109;
ram[ {2'd0, 7'd18} ] = -331;
ram[ {2'd0, 7'd19} ] = -426;
ram[ {2'd0, 7'd20} ] = -300;
ram[ {2'd0, 7'd21} ] = 40;
ram[ {2'd0, 7'd22} ] = 461;
ram[ {2'd0, 7'd23} ] = 741;
ram[ {2'd0, 7'd24} ] = 675;
ram[ {2'd0, 7'd25} ] = 189;
ram[ {2'd0, 7'd26} ] = -578;
ram[ {2'd0, 7'd27} ] = -1283;
ram[ {2'd0, 7'd28} ] = -1496;
ram[ {2'd0, 7'd29} ] = -876;
ram[ {2'd0, 7'd30} ] = 660;
ram[ {2'd0, 7'd31} ] = 2848;
ram[ {2'd0, 7'd32} ] = 5139;
ram[ {2'd0, 7'd33} ] = 6873;
ram[ {2'd0, 7'd34} ] = 7518;
ram[ {2'd0, 7'd35} ] = 6873;
ram[ {2'd0, 7'd36} ] = 5139;
ram[ {2'd0, 7'd37} ] = 2848;
ram[ {2'd0, 7'd38} ] = 660;
ram[ {2'd0, 7'd39} ] = -876;
ram[ {2'd0, 7'd40} ] = -1496;
ram[ {2'd0, 7'd41} ] = -1283;
ram[ {2'd0, 7'd42} ] = -578;
ram[ {2'd0, 7'd43} ] = 189;
ram[ {2'd0, 7'd44} ] = 675;
ram[ {2'd0, 7'd45} ] = 741;
ram[ {2'd0, 7'd46} ] = 461;
ram[ {2'd0, 7'd47} ] = 40;
ram[ {2'd0, 7'd48} ] = -300;
ram[ {2'd0, 7'd49} ] = -426;
ram[ {2'd0, 7'd50} ] = -331;
ram[ {2'd0, 7'd51} ] = -109;
ram[ {2'd0, 7'd52} ] = 108;
ram[ {2'd0, 7'd53} ] = 224;
ram[ {2'd0, 7'd54} ] = 209;
ram[ {2'd0, 7'd55} ] = 105;
ram[ {2'd0, 7'd56} ] = -19;
ram[ {2'd0, 7'd57} ] = -101;
ram[ {2'd0, 7'd58} ] = -114;
ram[ {2'd0, 7'd59} ] = -73;
ram[ {2'd0, 7'd60} ] = -11;
ram[ {2'd0, 7'd61} ] = 36;
ram[ {2'd0, 7'd62} ] = 53;
ram[ {2'd0, 7'd63} ] = 42;
ram[ {2'd0, 7'd64} ] = 15;
ram[ {2'd0, 7'd65} ] = -10;
ram[ {2'd0, 7'd66} ] = -25;
ram[ {2'd0, 7'd67} ] = -25;
ram[ {2'd0, 7'd68} ] = -15;
end
endmodule

