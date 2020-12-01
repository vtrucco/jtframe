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
    Date: 1-12-2020 */

// SDRAM access multiplexer, 2 -> 1

module jtframe_ram_2slots #(parameter
    SDRAMW = 22,
    SLOT0_DW = 8, SLOT1_DW = 8, SLOT2_DW = 8,
    SLOT0_AW = 8, SLOT1_AW = 8, SLOT2_AW = 8,
    parameter [SDRAMW-1:0] SLOT0_OFFSET = 0,
    parameter [SDRAMW-1:0] SLOT1_OFFSET = 0
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

    // Slot 0 accepts 16-bit writes
    input               slot0_wen,
    input  [SLOT0_DW-1:0] slot0_din,
    input  [1:0]        slot0_wrmask,

    // SDRAM controller interface
    input               sdram_ack,
    output  reg         sdram_rd,
    output  reg         sdram_wr,
    output  reg [SDRAMW-1:0] sdram_addr,
    input               data_rdy,
    input       [31:0]  data_read,
    output  reg [15:0]  data_write,  // only 16-bit writes
    output  reg [ 1:0]  sdram_wrmask // each bit is active low
);

localparam SW=2;

wire [SW-1:0] req, slot_ok;
reg  [SW-1:0] data_sel, slot_we;
wire          req_rnw; // slot 0
reg           wait_cycle;
wire [SW-1:0] active = ~data_sel & req;

wire [SDRAMW-1:0] slot0_addr_req,
                  slot1_addr_req;

wire [SDRAMW-1:0] offset0 = SLOT0_OFFSET,
                  offset1 = SLOT1_OFFSET;

assign slot0_ok = slot_ok[0];
assign slot1_ok = slot_ok[1];

jtframe_ram_rq #(.AW(SLOT0_AW),.DW(SLOT0_DW)) u_slot0(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .addr      ( slot0_addr             ),
    .addr_ok   ( slot0_cs               ),
    .offset    ( offset0                ),
    .wrdata    ( slot0_din              ),
    .wrin      ( slot0_wen              ),
    .req_rnw   ( req_rnw                ),
    .sdram_addr( slot0_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot0_dout             ),
    .req       ( req[0]                 ),
    .data_ok   ( slot_ok[0]             ),
    .we        ( slot_we[0]             )
);

jtframe_romrq #(.AW(SLOT1_AW),.DW(SLOT1_DW)) u_slot1(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
    .offset    ( offset1                ),
    .addr      ( slot1_addr             ),
    .addr_ok   ( slot1_cs               ),
    .sdram_addr( slot1_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot1_dout             ),
    .req       ( req[1]                 ),
    .data_ok   ( slot_ok[1]             ),
    .we        ( slot_we[1]             )
);

always @(posedge clk)
if( rst ) begin
    sdram_addr <= {SDRAMW{1'd0}};
    sdram_rd   <= 0;
    sdram_wr   <= 0;
    data_sel   <= {SW{1'd0}};
    slot_we    <= {SW{1'd0}};
end else begin
    if( sdram_ack ) begin
        sdram_rd   <= 0;
        sdram_wr   <= 0;
        wait_cycle <= 0;
    end

    // accept a new request
    slot_we <= data_sel;
    if( !data_sel || (data_rdy&&!wait_cycle) ) begin
        sdram_rd     <= |active;
        wait_cycle   <= |active;
        data_sel     <= {SW{1'd0}};
        sdram_wrmask <= 2'b11;
        if( active[0] ) begin
            sdram_addr  <= slot0_addr_req;
            data_write  <= slot0_din;
            sdram_wrmask<= slot0_wrmask;
            sdram_rd    <= !req_rnw;
            sdram_wr    <= req_rnw;
            data_sel[0] <= 1;
        end else if( active[1]) begin
            sdram_addr  <= slot1_addr_req;
            sdram_rd    <= 1;
            sdram_wr    <= 0;
            data_sel[1] <= 1;
        end
    end
end

endmodule
