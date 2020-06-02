/*  This file is part of JTFRAME.
      JTFRAME program is free software: you can redistribute it and/or modify
      it under the terms of the GNU General Public License as published by
      the Free Software Foundation, either version 3 of the License, or
      (at your option) any later version.

      JTFRAME program is distributed in the hope that it will be useful,
      but WITHOUT ANY WARRANTY; without even the implied warranty of
      MERCHANTABILITY or FITNESS FOR addr PARTICULAR PURPOSE.  See the
      GNU General Public License for more details.

      You should have received a copy of the GNU General Public License
      along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

      Author: Jose Tejada Gomez. Twitter: @topapate
      Version: 1.0
      Date: 2-6-2020

*/

// Instantiates the m6801 core with some
// of the logic needed to become a 63701 MCU
// such as the one used in Double Dragon or Bubble Bobble

module jtframe_6801mcu #(
    parameter ROMW=12
)(
    input              clk,
    input              rst,
    input              cen,
    output             wrn,
    output             vma,
    output      [15:0] addr,
    output      [ 7:0] dout,
    input              halt,
    output             halted,
    input              irq,
    input              nmi,
    // Ports
    input      [ 7:0]  p1_in,
    output     [ 7:0]  p1_out,
    // external RAM
    input              ext_cs,
    input              ext_dout,
    // ROM interface
    output [ROMW-1:0]  rom_addr,
    input      [ 7:0]  rom_data,
    output reg         rom_cs,
    input              rom_ok
);

wire        intram_we;
reg  [ 7:0] port_map[0:31];
reg  [ 7:0] din;
wire [ 7:0] ram_dout,
            p1_datadir, p2_datadir, p3_datadir, p4_datadir;
reg         port_cs, ram_cs;
wire        wait_cen;

assign rom_addr  = addr[ROMW-1:0];
assign intram_we = ram_cs & ~wrn;
assign p1_datadir= port_map[0];
assign p2_datadir= port_map[1];
assign p3_datadir= port_map[4];
assign p4_datadir= port_map[5];

// Address decoder
always @(*) begin
    rom_cs    = vma && (&addr[15:ROMW]); // ROM is always at the top
    ram_cs    = vma && addr>=16'h40 && addr<16'h140;
    port_cs   = vma && addr<16'h28;
end

integer aux;

// Ports
always @(posedge clk ) begin
    if( !rst ) begin
        port_map[0] <= 8'd0; // P1 data direction
    end else begin
        if(port_cs) port_map[addr[4:0]] <= dout;
        else begin
            // copy only input bits to ports according
            // to the associated data direction register
            for( aux=0; aux<8; aux=aux+1 )
                if( !p1_datadir[aux] ) port_map[2][aux] <= p1_in[aux];
        end
    end
end

// Input multiplexer
wire [7:0] shared_dout;

always @(*) begin
    case(1'b1)
        default: din = rom_data;
        ram_cs:  din = ram_dout;
        ext_cs:  din = ext_dout;
        port_cs: din = port_map[addr[4:0]];
    endcase
end

jtframe_ram #(.aw(8)) u_intram(
    .clk    ( clk         ),
    .cen    ( cen         ),
    .data   ( dout        ),
    .addr   ( addr[7:0]   ),
    .we     ( intram_we   ),
    .q      ( ram_dout    )
);


jtframe_gatecen #(.ROMW(ROMW)) u_gatecen(
    .clk        ( clk       ),
    .rst        ( rst       ),
    .cen        ( cen       ),
    .rom_addr   ( rom_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .wait_cen   ( wait_cen  )
);

m6801 u_mcu(   
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( wait_cen      ),
    .rw         ( wrn           ),
    .vma        ( vma           ),
    .address    ( addr          ),
    .data_in    ( din           ),
    .data_out   ( dout          ), 
    .halt       ( halt          ),
    .halted     ( halted        ),
    .irq        ( irq           ),
    .nmi        ( nmi           ),
    // Timer interrupts
    .irq_icf    ( 1'b0          ),
    .irq_ocf    ( 1'b0          ),
    .irq_tof    ( 1'b0          ),
    .irq_sci    ( 1'b0          )
);

endmodule