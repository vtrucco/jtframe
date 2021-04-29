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
    Date: 28-2-2019 */

// The best use case is with addr_ok going down and up for each addr change
// but it works too with addr_ok permanently high as long as addr input is
// not changed until the data_ok signal is produced. If the requester cannot
// guarantee that, it should toggle addr_ok for each request

// LATCH LATENCY Timing Requirements
//    0     1    medium
//    1     2    easy

module jtframe_romrq #(parameter
    SDRAMW= 22,  // SDRAM width
    AW    = 18,
    DW    =  8,
    LATCH =  0   // dout is latched
)(
    input               rst,
    input               clk,

    input               clr, // clears the cache
    input [SDRAMW-1:0]  offset,

    // <-> SDRAM
    input [15:0]        din,
    input               din_ok,
    input               dst,
    input               we,
    output reg          req,
    output [SDRAMW-1:0] sdram_addr,

    // <-> Consumer
    input [AW-1:0]      addr,
    input               addr_ok,    // signals that value in addr is valid
    output              data_ok,    // strobe that signals that data is ready
    output reg [DW-1:0] dout
);

reg [AW-1:0] addr_req;

reg [AW-1:0] cached_addr0;
reg [AW-1:0] cached_addr1;
reg [31:0]   cached_data0;
reg [31:0]   cached_data1;
reg [1:0]    good;
reg          hit0, hit1, data_ok;
wire [AW-1:0] shifted;

assign sdram_addr = offset + { {SDRAMW-AW{1'b0}}, addr_req>>(DW==8?1:0)};

always @(*) begin
    case(DW)
        8:  addr_req = {addr[AW-1:2],2'b0};
        16: addr_req = {addr[AW-1:1],1'b0};
        32: addr_req = addr;
    endcase
    // It is important to leave === for simulations, instead of ==
    // It shouldn't have any implication for synthesis
    hit0 = addr_req === cached_addr0 && good[0] && !clr;
    hit1 = addr_req === cached_addr1 && good[1] && !clr;
    req = (clr || ( !(hit0 || hit1) && !we)) && addr_ok;
end

// reg [1:0] ok_sr;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        good         <= 'd0;
        cached_data0 <= 'd0;
        cached_data1 <= 'd0;
        cached_addr0 <= 'd0;
        cached_addr1 <= 'd0;
        data_ok      <= 0;
    end else begin
        if( clr ) good <= 2'b00;
        if( we ) begin
            if( dst ) begin
                cached_data1 <= cached_data0;
                cached_addr1 <= cached_addr0;
                cached_data0[31:16] <= din;
                cached_addr0 <= addr_req;
                good <= { good[0], 1'b1 };
            end
            if( din_ok ) begin
                cached_data0[31:16] <= din;
                cached_data0[15: 0] <= cached_data0[31:16];
                if( !LATCH[0] ) data_ok <= 1;
            end
        end
        else data_ok <= addr_ok && ( hit0 || hit1 );
    end
end

// data_mux selects one of two cache registers
// but if we are getting fresh data, it selects directly the new data
// this saves one clock cycle at the expense of more LUTs
wire [31:0] data_mux = hit0 ? cached_data0 : cached_data1;

generate
    if( LATCH==0 ) begin : data_latch
        if(DW==8) begin
            always @(*)
            case( addr[1:0] )
                2'd0: dout = data_mux[ 7: 0];
                2'd1: dout = data_mux[15: 8];
                2'd2: dout = data_mux[23:16];
                2'd3: dout = data_mux[31:24];
            endcase
        end else if(DW==16) begin
            always @(*)
            case( addr[0] )
                    1'd0: dout = data_mux[15:0];
                    1'd1: dout = data_mux[31:16];
            endcase
        end else always @(*) dout = data_mux;
    end else begin : no_data_latch
        if(DW==8) begin
            always @(posedge clk)
            case( addr[1:0] )
                2'd0: dout <= data_mux[ 7: 0];
                2'd1: dout <= data_mux[15: 8];
                2'd2: dout <= data_mux[23:16];
                2'd3: dout <= data_mux[31:24];
            endcase
        end else if(DW==16) begin
            always @(posedge clk)
            case( addr[0] )
                    1'd0: dout <= data_mux[15:0];
                    1'd1: dout <= data_mux[31:16];
            endcase
        end else always @(posedge clk) dout <= data_mux;
    end
endgenerate

`ifdef JTFRAME_SDRAM_STATS
jtframe_romrq_stats u_stats(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .req    ( req       ),
    .we     ( we        ),
    .din_ok ( din_ok    ),
    .data_ok( data_ok   )
);
`endif

`ifdef SIMULATION
`ifndef JTFRAME_SIM_ROMRQ_NOCHECK
reg [AW-1:0] last_addr;
reg          waiting, last_req;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        waiting <= 0;
        last_req <= 0;
    end else begin
        last_req <= req;
        if( req && !last_req ) begin
            if( waiting ) begin
                $display("ERROR: %m new request without finishing the previous");
                $finish;
            end
            last_addr <= addr;
            waiting <= 1;
        end
        if( din_ok ) waiting <= 0;
        if( waiting && !addr_ok ) begin
            $display("ERROR: %m data request interrupted");
            $finish;
        end
        if( addr != last_addr && addr_ok) begin
            if( waiting ) begin
                $display("ERROR: %m address changed");
                $finish;
            end else waiting <= !hit0 && !hit1;
        end
    end
end
`endif
`endif

endmodule // jtframe_romrq

`ifdef JTFRAME_SDRAM_STATS
////////////////////////////////////////////////////////////////
module jtframe_romrq_stats(
    input clk,
    input rst,
    input req,
    input we,
    input din_ok,
    input data_ok
);

// latency data
integer cur, longest, shortest, total, acc_cnt;
reg cnt_en, last_req, first;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cur      <= 0;
        longest  <= 0;
        shortest <= 10000;
        cnt_en   <= 0;
        last_req <= 0;
        acc_cnt  <= 0;
        total    <= 0;
        first    <= 1;
    end else begin
        last_req <= req;
        if(req && !last_req) begin
            cur <= 1;
            cnt_en <= 1;
            acc_cnt <= acc_cnt+1;
        end
        if( cnt_en ) begin
            cur <= cur+1;
            if( (we && din_ok) || data_ok ) begin
                if( !first ) begin
                    if(cur>longest) longest <= cur;
                    if(cur<shortest) shortest <= cur;
                    total <= total + cur;
                end
                first  <= 0;
                cnt_en <= 0;
            end
        end
    end
end

initial begin
    forever begin
        /* verilator lint_off STMTDLY */
        #16_666_667;
        /* verilator lint_on STMTDLY */
        if( !first )
            $display("Latency %m %2d - %2d - %2d",
                shortest, total/acc_cnt, longest );
    end
end

endmodule
`endif