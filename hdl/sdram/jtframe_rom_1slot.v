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
    Date: 11-1-2021 */

// 1 slots for SDRAM read-only access
// Each slot can be used for 8, 16 or 32 bit access
// Small 4 byte cache used for each slot

module jtframe_rom_1slot #(parameter
    SDRAMW       = 22,
    SLOT0_DW     = 8,
    SLOT0_AW     = 8,
    SLOT0_REPACK = 0,
    LATCH0       = 0
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr,

    //  output data
    output [SLOT0_DW-1:0] slot0_dout,

    input               slot0_cs,
    output              slot0_ok,
    // SDRAM controller interface
    input               sdram_ack,
    output              sdram_req,
    output [SDRAMW-1:0] sdram_addr,
    input               data_rdy,
    input       [31:0]  data_read
);

reg slot0_sel;

always @(posedge clk, posedge rst ) begin
    if( rst )
        slot0_sel <= 0;
    else begin
        if( sdram_ack )
            slot0_sel <= 1;
        else if( data_rdy )
            slot0_sel <= 0;
    end
end

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT0_AW),.DW(SLOT0_DW),.REPACK(SLOT0_REPACK),.LATCH(LATCH0)) u_slot0(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( {SLOT0_AW{1'b0}}       ), // no need for offset when there is only one module
    .addr      ( slot0_addr             ),
    .addr_ok   ( slot0_cs               ),
    .sdram_addr( sdram_addr             ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot0_dout             ),
    .req       ( sdram_req              ),
    .data_ok   ( slot0_ok               ),
    .we        ( slot0_sel              )
);

endmodule