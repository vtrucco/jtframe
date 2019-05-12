/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

`timescale 1ns/1ps

module jtgng_mist_base(
    input           rst,
    output          clk_sys,
    input           clk_rom,
    input           clk_vga,
    input           pxl_cen,
    output          SDRAM_CLK,      // SDRAM Clock

    // Base video
    input           en_mixing,
    input   [1:0]   osd_rotate,
    input   [3:0]   game_r,
    input   [3:0]   game_g,
    input   [3:0]   game_b,
    input           LHBL,
    input           LVBL,    
    input   [5:0]   board_r,
    input   [5:0]   board_g,
    input   [5:0]   board_b,
    input           board_hsync,
    input           board_vsync,
    input           hs,
    input           vs,
    // VGA
    input       [1:0]   CLOCK_27,
    output  reg [5:0]   VGA_R,
    output  reg [5:0]   VGA_G,
    output  reg [5:0]   VGA_B,
    output  reg         VGA_HS,
    output  reg         VGA_VS,
    // SPI interface to arm io controller
    output          SPI_DO,
    input           SPI_DI,
    input           SPI_SCK,
    input           SPI_SS2,
    input           SPI_SS3,
    input           SPI_SS4,
    input           CONF_DATA0,
    // control
    output [31:0]   status,
    output [31:0]   joystick1,
    output [31:0]   joystick2,
    output          ps2_kbd_clk,
    output          ps2_kbd_data,
    // Sound
    input           clk_dac,
    input   [15:0]  snd,
    output          snd_pwm,
    // ROM load from SPI
    output [21:0]   ioctl_addr,
    output [ 7:0]   ioctl_data,
    output          ioctl_wr,
    output          downloading
);

parameter CONF_STR="CORE";
parameter CONF_STR_LEN=4;
parameter SIGNED_SND=1'b0;

wire ypbpr;
wire scandoubler_disable;

`ifndef SIMULATION
`ifndef NOSOUND
wire [15:0] snd_in = {snd[15]^SIGNED_SND, snd[14:0]};
wire [19:0] snd_padded = { 1'b0, snd_in, 3'd0 };


hifi_1bit_dac u_dac
(
  .reset    ( rst        ),
  .clk      ( clk_dac    ),
  .clk_ena  ( 1'b1       ),
  .pcm_in   ( snd_padded ),
  .dac_out  ( snd_pwm    )
);
`endif
`else
assign snd_pwm = 1'b0;
`endif

`ifndef SIMULATION
user_io #(.STRLEN(CONF_STR_LEN)) u_userio(
    .clk_sys        ( clk_sys   ),
    .conf_str       ( CONF_STR  ),
    .SPI_CLK        ( SPI_SCK   ),
    .SPI_SS_IO      ( CONF_DATA0),
    .SPI_MISO       ( SPI_DO    ),
    .SPI_MOSI       ( SPI_DI    ),
    .joystick_0     ( joystick2 ),
    .joystick_1     ( joystick1 ),
    .status         ( status    ),
    .ypbpr          ( ypbpr     ),
    .scandoubler_disable ( scandoubler_disable ),
    // keyboard
    .ps2_kbd_clk    ( ps2_kbd_clk  ),
    .ps2_kbd_data   ( ps2_kbd_data ),
    // unused ports:
    .serial_strobe  ( 1'b0      ),
    .serial_data    ( 8'd0      ),
    .sd_lba         ( 32'd0     ),
    .sd_rd          ( 1'b0      ),
    .sd_wr          ( 1'b0      ),
    .sd_conf        ( 1'b0      ),
    .sd_sdhc        ( 1'b0      ),
    .sd_din         ( 8'd0      )
);
`else
assign joystick1 = 32'd0;
assign joystick2 = 32'd0;
assign status    = 32'd0;
assign ps2_kbd_data = 1'b0;
assign ps2_kbd_clk  = 1'b0;
assign scandoubler_disable = 1'b0;
assign ypbpr = 1'b0;
`endif

data_io #(.aw(22)) u_datain (
    .sck                ( SPI_SCK      ),
    .ss                 ( SPI_SS2      ),
    .sdi                ( SPI_DI       ),
    .clk_sdram          ( clk_rom      ),
    .downloading_sdram  ( downloading  ),
    .ioctl_addr         ( ioctl_addr   ),
    .ioctl_data         ( ioctl_data   ),
    .ioctl_wr           ( ioctl_wr     ),
    .index              ( /* unused*/  )
);

// OSD will only get simulated if SIMULATE_OSD is defined
`ifndef SIMULATE_OSD
`ifdef SIMULATION
`define BYPASS_OSD
`endif
`endif

// Do not simulate the scan doubler unless explicitly asked for it:
`ifndef SIM_SCANDOUBLER
`ifdef SIMULATION
`define NOSCANDOUBLER
`endif
`endif

`ifdef SIMINFO
initial begin
    $display("INFO: use -d SIMULATE_OSD to simulate the MiST OSD")
    $display("INFO: use -d SIM_SCANDOUBLER to simulate the VGA scan doubler")
end
`endif

wire [5:0] vga_r, vga_g, vga_b;
wire [3:0] osd_r, osd_g, osd_b;
wire       osd_hs, osd_vs;

`ifndef BYPASS_OSD
// include the on screen display
wire       HSync = ~hs;
wire       VSync = ~vs;
wire       CSync = ~(HSync ^ VSync);

osd #(.OSD_X_OFFSET(10'd0),.OSD_Y_OFFSET(10'd0),.OSD_COLOR(3'd4),.PXW(4)) 
u_osd (
   .clk_sys    ( clk_sys      ),
   .pxl_cen    ( pxl_cen      ),
   // spi for OSD
   .SPI_DI     ( SPI_DI       ),
   .SPI_SCK    ( SPI_SCK      ),
   .SPI_SS3    ( SPI_SS3      ),

   .rotate     ( osd_rotate   ),

   .R_in       ( game_r       ),
   .G_in       ( game_g       ),
   .B_in       ( game_b       ),
   .HSync      ( hs           ),
   .VSync      ( vs           ),

   .R_out      ( osd_r        ),
   .G_out      ( osd_g        ),
   .B_out      ( osd_b        ),
   .HS_out     ( osd_hs       ),
   .VS_out     ( osd_vs       )
);
`else 
assign osd_r  = game_r;
assign osd_g  = game_g;
assign osd_b  = game_b;
assign osd_hs = hs;
assign osd_vs = vs;
`endif

wire vga_vsync, vga_hsync;
`ifndef NOSCANDOUBLER
reg LHBL2, LVBL2;

always @(posedge clk_sys) begin
    LHBL2 <= LHBL;
    LVBL2 <= LVBL;
end

jtgng_vga u_scandoubler (
    .rst        ( rst           ),
    .clk_rgb    ( clk_sys       ),
    .cen6       ( pxl_cen       ),
    .clk_vga    ( clk_vga       ), // 25 MHz
    .red        ( osd_r         ),
    .green      ( osd_g         ),
    .blue       ( osd_b         ),
    .LHBL       ( LHBL2         ),
    .LVBL       ( LVBL2         ),
    .en_mixing  ( en_mixing     ),
    .vga_red    ( vga_r[5:1]    ),
    .vga_green  ( vga_g[5:1]    ),
    .vga_blue   ( vga_b[5:1]    ),
    .vga_hsync  ( vga_hsync     ),
    .vga_vsync  ( vga_vsync     )
);

// convert 5-bit colour to 6-bit colour
assign vga_r[0] = vga_r[5];
assign vga_g[0] = vga_g[5];
assign vga_b[0] = vga_b[5];
`else
// simulation only
assign vga_r = { 2'b0, osd_r };
assign vga_g = { 2'b0, osd_g };
assign vga_b = { 2'b0, osd_b };
assign vga_hsync  = osd_hs;
assign vga_vsync  = osd_vs;
`endif

`ifndef SIMULATION
wire [5:0] Y, Pb, Pr;

rgb2ypbpr u_rgb2ypbpr
(
    .red   ( osd_r   ),
    .green ( osd_g   ),
    .blue  ( osd_b   ),
    .y     ( Y       ),
    .pb    ( Pb      ),
    .pr    ( Pr      )
);

always @(posedge clk_sys) begin : rgb_mux
    if( ypbpr ) begin // RGB output
        // a minimig vga->scart cable expects a composite sync signal 
        // on the VGA_HS output and VCC on VGA_VS (to switch into rgb mode).
        VGA_R  <= Pr;
        VGA_G  <=  Y;
        VGA_B  <= Pb;
        VGA_HS <= CSync;
        VGA_VS <= 1'b1;
    end else begin // VGA output
        VGA_R  <= vga_r;
        VGA_G  <= vga_g;
        VGA_B  <= vga_b;
        VGA_HS <= vga_hsync;
        VGA_VS <= vga_vsync;
    end
end
// assign VGA_R = ypbpr?Pr:osd_r;
// assign VGA_G = ypbpr? Y:osd_g;
// assign VGA_B = ypbpr?Pb:osd_b;
// assign VGA_HS = (scandoubler_disable | ypbpr) ? CSync : HSync;
// assign VGA_VS = (scandoubler_disable | ypbpr) ? 1'b1 : VSync;
`else
assign VGA_R  = vga_r;
assign VGA_G  = vga_g;
assign VGA_B  = vga_b;
assign VGA_HS = hs;
assign VGA_VS = vs;
`endif

endmodule // jtgng_mist_base