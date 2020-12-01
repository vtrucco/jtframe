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

// 2 slots for SDRAM read-only access
// slot 0 --> maximum priority
// slot 1 --> minimum priority
// Each slot can be used for 8, 16 or 32 bit access
// Small 4 byte cache used for each slot

module jtframe_rom_2slots #(parameter
    SLOT0_DW = 8, SLOT1_DW = 8,
    SLOT0_AW = 8, SLOT1_AW = 8,

    parameter [21:0] SLOT0_OFFSET = 22'h0,
    parameter [21:0] SLOT1_OFFSET = 22'h0
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr,
    input  [SLOT1_AW-1:0] slot1_addr,

    //  output data
    output [SLOT0_DW-1:0] slot0_dout,
    output [SLOT1_DW-1:0] slot1_dout,

    input               slot0_cs,
    input               slot1_cs,

    output              slot0_ok,
    output              slot1_ok,
    // SDRAM controller interface
    input               sdram_ack,
    output  reg         sdram_req,
    output  reg [21:0]  sdram_addr,
    input               data_rdy,
    input       [31:0]  data_read
);


reg  [ 3:0] ready_cnt;
reg  [ 3:0] rd_state_last;
wire [ 1:0] req, ok;

reg  [ 1:0] data_sel;
wire [21:0] slot0_addr_req,
            slot1_addr_req;

assign slot0_ok = ok[0];
assign slot1_ok = ok[1];

wire [21:0] offset0 = SLOT0_OFFSET,
            offset1 = SLOT1_OFFSET;

jtframe_romrq #(.AW(SLOT0_AW),.DW(SLOT0_DW)) u_slot0(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset0                ),
    .addr      ( slot0_addr             ),
    .addr_ok   ( slot0_cs               ),
    .sdram_addr( slot0_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot0_dout             ),
    .req       ( req[0]                 ),
    .data_ok   ( ok[0]                  ),
    .we        ( data_sel[0]            )
);

jtframe_romrq #(.AW(SLOT1_AW),.DW(SLOT1_DW)) u_slot1(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset1                ),
    .addr      ( slot1_addr             ),
    .addr_ok   ( slot1_cs               ),
    .sdram_addr( slot1_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot1_dout             ),
    .req       ( req[1]                 ),
    .data_ok   ( ok[1]                  ),
    .we        ( data_sel[1]            )
);

wire [1:0] active = ~data_sel & req;

always @(posedge clk, posedge rst)
if( rst ) begin
    sdram_addr <= 22'd0;
    sdram_req  <=  1'b0;
    data_sel   <=  2'd0;
end else begin
    if( sdram_ack ) sdram_req <= 1'b0;
    // accept a new request
    if( data_sel==2'd0 || data_rdy ) begin
        sdram_req <= |active;
        data_sel  <= 2'd0;
        case( 1'b1 )
            active[0]: begin
                sdram_addr <= slot0_addr_req;
                data_sel[0] <= 1'b1;
            end
            active[1]: begin
                sdram_addr <= slot1_addr_req;
                data_sel[1] <= 1'b1;
            end
        endcase
    end
end

endmodule