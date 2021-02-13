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
    Date: 7-3-2019 */

module jtframe_mister #(parameter
    BUTTONS                 = 2,
    GAME_INPUTS_ACTIVE_LOW  =1'b1,
    CONF_STR                = "",
    COLORW                  = 4,
    VIDEO_WIDTH             = 384,
    VIDEO_HEIGHT            = 224
)(
    input           clk_sys,
    input           clk_rom,
    input           pll_locked,
    // interface with microcontroller
    output [31:0]   status,
    inout  [45:0]   HPS_BUS,
    output [ 1:0]   buttons,
    // LED
    input        [1:0] game_led,
    // Base video
    input [COLORW-1:0] game_r,
    input [COLORW-1:0] game_g,
    input [COLORW-1:0] game_b,
    input           LHBL,
    input           LVBL,
    input           hs,
    input           vs,
    input           pxl_cen,
    input           pxl2_cen,
    // SDRAM interface
    inout  [15:0]   SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output [12:0]   SDRAM_A,        // SDRAM Address bus 13 Bits
    output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output [ 1:0]   SDRAM_BA,       // SDRAM Bank Address
    input           SDRAM_CLK,      // SDRAM Clock
    output          SDRAM_CKE,      // SDRAM Clock Enable

    // Signals to rotate the screen
    `ifdef JTFRAME_VERTICAL
    output          FB_EN,
    output  [4:0]   FB_FORMAT,
    output [11:0]   FB_WIDTH,
    output [11:0]   FB_HEIGHT,
    output [31:0]   FB_BASE,
    output [13:0]   FB_STRIDE,
    input           FB_VBL,
    input           FB_LL,
    output          FB_FORCE_BLANK,

    // Palette control for 8bit modes.
    // Ignored for other video modes.
    output          FB_PAL_CLK,
    output  [7:0]   FB_PAL_ADDR,
    output [23:0]   FB_PAL_DOUT,
    input  [23:0]   FB_PAL_DIN,
    output          FB_PAL_WR,

    output          DDRAM_CLK,
    input           DDRAM_BUSY,
    output  [7:0]   DDRAM_BURSTCNT,
    output [28:0]   DDRAM_ADDR,
    input  [63:0]   DDRAM_DOUT,
    input           DDRAM_DOUT_READY,
    output          DDRAM_RD,
    output [63:0]   DDRAM_DIN,
    output  [7:0]   DDRAM_BE,
    output          DDRAM_WE,
    `endif

    // ROM programming
    output       [24:0] ioctl_addr,
    output       [ 7:0] ioctl_data,
    output              ioctl_rom_wr,
    // NVRAM
    input        [ 7:0] ioctl_data2sd,
    output reg          ioctl_ram,

    input               dwnld_busy,
    output reg          downloading,

    input        [21:0] prog_addr,
    input        [15:0] prog_data,
    input        [ 1:0] prog_mask,
    input        [ 1:0] prog_ba,
    input               prog_we,
    input               prog_rd,
    output              prog_rdy,
    output              prog_ack,
    // ROM access from game
    input        [21:0] ba0_addr,
    input               ba0_rd,
    input               ba0_wr,
    input        [15:0] ba0_din,
    input        [ 1:0] ba0_din_m,  // write mask
    output              ba0_rdy,
    output              ba0_ack,
    input        [21:0] ba1_addr,
    input               ba1_rd,
    output              ba1_rdy,
    output              ba1_ack,
    input        [21:0] ba2_addr,
    input               ba2_rd,
    output              ba2_rdy,
    output              ba2_ack,
    input        [21:0] ba3_addr,
    input               ba3_rd,
    output              ba3_rdy,
    output              ba3_ack,

    input               rfsh_en,   // ok to refresh
    output       [31:0] sdram_dout,

    // User port
    output              db9_en,
    output              USER_OSD,
    output       [ 1:0] USER_MODE,
    input        [ 7:0] USER_IN,
    output       [ 7:0] USER_OUT,
//////////// board
    output          rst,      // synchronous reset
    output          rst_n,    // asynchronous reset
    output          game_rst,
    output          game_rst_n,
    // reset forcing signals:
    input           rst_req,
    // joystick
    output  [ 9:0]  game_joystick1,
    output  [ 9:0]  game_joystick2,
    output  [ 9:0]  game_joystick3,
    output  [ 9:0]  game_joystick4,
    output  [15:0]  joystick_analog_0,
    output  [15:0]  joystick_analog_1,
    output  [ 3:0]  game_coin,
    output  [ 3:0]  game_start,
    output          game_service,
    // DIP and OSD settings
    output  [11:0]  hdmi_arx,
    output  [11:0]  hdmi_ary,
    output  [ 1:0]  rotate,

    output          enable_fm,
    output          enable_psg,

    output          dip_test,
    // scan doubler
    output    [7:0] scan2x_r,
    output    [7:0] scan2x_g,
    output    [7:0] scan2x_b,
    output          scan2x_hs,
    output          scan2x_vs,
    output          scan2x_clk,
    output          scan2x_cen,
    output          scan2x_de,
    output    [1:0] scan2x_sl,
    // non standard:
    output            dip_pause,
    inout             dip_flip,
    output    [ 1:0]  dip_fxlevel,
    output    [31:0]  dipsw,
    // Debug
    output            LED,
    output    [ 3:0]  gfx_en
);

localparam [7:0] IDX_ROM   = 8'h0,
                 IDX_MOD   = 8'h1,
                 IDX_NVRAM = 8'h2,
                 IDX_DIPSW = 8'd254;

wire [21:0] gamma_bus;

wire [ 7:0] ioctl_index;
wire        ioctl_wr;
wire        ioctl_download;

wire [ 3:0] hoffset, voffset;

wire [15:0] joystick1, joystick2, joystick3, joystick4,
            hps_joy0, hps_joy1;
wire        ps2_kbd_clk, ps2_kbd_data;
wire        force_scan2x, direct_video;
wire [ 5:0] raw_joy;       // DB9 support

reg  [ 6:0] core_mod;

wire        hs_resync, vs_resync;


assign { voffset, hoffset } = status[31:24];
assign db9_en = status[13];

`ifdef JTFRAME_VERTICAL
assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;
`endif

always @(posedge clk_sys) begin
    downloading <= ioctl_download && ioctl_index==IDX_ROM;
    ioctl_ram   <= ioctl_download && ioctl_index==IDX_NVRAM;
end

jtframe_resync u_resync(
    .clk        ( clk_sys       ),
    .pxl_cen    ( pxl_cen       ),
    .hs_in      ( hs            ),
    .vs_in      ( vs            ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .hoffset    ( hoffset       ),
    .voffset    ( voffset       ),
    .hs_out     ( hs_resync     ),
    .vs_out     ( vs_resync     )
);


assign ioctl_rom_wr = ioctl_wr && (ioctl_index==IDX_ROM || ioctl_index==IDX_NVRAM);

`ifndef JTFRAME_MRA_DIP
    // DIP switches through regular OSD options
    assign dipsw        = status;
`else
    // Dip switches through MRA file
    // Support for 32 bits only for now.
    reg  [ 7:0] dsw[4];

    `ifndef SIMULATION
        assign dipsw = {dsw[3],dsw[2],dsw[1],dsw[0]};
    `else // SIMULATION:
        `ifndef JTFRAME_SIM_DIPS
            assign dipsw = ~32'd0;
        `else
            assign dipsw = `JTFRAME_SIM_DIPS;
        `endif
    `endif


    always @(posedge clk_rom) begin
        if (ioctl_wr && (ioctl_index==IDX_DIPSW) && !ioctl_addr[24:2]) dsw[ioctl_addr[1:0]] <= ioctl_data;
    end
`endif

always @(posedge clk_rom, posedge rst) begin
    if( rst ) begin
        core_mod <= 7'b01; // see readme file for documentation on each bit
    end else begin
        // The ioctl_addr[0]==1'b0 condition is needed in case JTFRAME_MR_FASTIO is enabled
        // as it always creates two write events and the second would delete the data of the first
        if (ioctl_wr && (ioctl_index==IDX_MOD) && ioctl_addr[0]==1'b0) core_mod <= ioctl_data[6:0];
    end
end

`ifndef JTFRAME_MR_FASTIO
    `ifdef JTFRAME_CLK96
        `define JTFRAME_MR_FASTIO 1
    `else
      `define JTFRAME_MR_FASTIO 0
    `endif
`endif

localparam JTFRAME_MR_FASTIO=`JTFRAME_MR_FASTIO;

wire [15:0] status_menumask;

assign status_menumask[15:1] = 15'd0;
assign status_menumask[0]    = direct_video;

wire [1:0] db_coin, db_start;

jtframe_dbxjoy #(.BUTTONS(BUTTONS)) u_dbxjoy(
    .rst      ( rst       ),
    .clk      ( clk_rom   ),

    .usb_joy0 ( hps_joy0  ),
    .usb_joy1 ( hps_joy1  ),
    .raw_joy  ( raw_joy   ),

    .mix_joy0 ( joystick1 ),
    .mix_joy1 ( joystick2 ),

    .coin     ( db_coin   ),
    .start    ( db_start  ),
    // User port
    .user_osd ( USER_OSD  ),
    .user_in  ( USER_IN   ),
    .user_out ( USER_OUT  )
);

hps_io #( .STRLEN($size(CONF_STR)/8), .PS2DIV(32), .WIDE(JTFRAME_MR_FASTIO) ) u_hps_io
(
    .clk_sys         ( clk_rom        ),
    .HPS_BUS         ( HPS_BUS        ),
    .conf_str        ( CONF_STR       ),

    .buttons         ( buttons        ),
    .status          ( status         ),
    .status_menumask ( status_menumask),
    .gamma_bus       ( gamma_bus      ),
    .direct_video    ( direct_video   ),
    .forced_scandoubler(force_scan2x  ),

    .ioctl_download  ( ioctl_download ),
    .ioctl_wr        ( ioctl_wr       ),
    .ioctl_addr      ( ioctl_addr     ),
    .ioctl_dout      ( ioctl_data     ),
    .ioctl_din       ( ioctl_data2sd  ),
    .ioctl_index     ( ioctl_index    ),
    // NVRAM support
    .ioctl_upload    (                ), // no need
    .ioctl_rd        (                ), // no need

    .joystick_0      ( hps_joy0       ),
    .joystick_1      ( hps_joy1       ),
    .joystick_2      ( joystick3      ),
    .joystick_3      ( joystick4      ),
    .joystick_analog_0( joystick_analog_0   ),
    .joystick_analog_1( joystick_analog_1   ),
    .raw_joy         ( raw_joy        ),
    .ps2_kbd_clk_out ( ps2_kbd_clk    ),
    .ps2_kbd_data_out( ps2_kbd_data   ),
    // Unused:
    .ps2_key         (                ),
    .RTC             (                ),
    .TIMESTAMP       (                ),
    .ps2_mouse       (                ),
    .ps2_mouse_ext   (                ),
    .ioctl_file_ext  (                )
);

jtframe_board #(
    .BUTTONS               ( BUTTONS              ),
    .GAME_INPUTS_ACTIVE_LOW(GAME_INPUTS_ACTIVE_LOW),
    .COLORW                ( COLORW               ),
    .VIDEO_WIDTH           ( VIDEO_WIDTH          ),
    .VIDEO_HEIGHT          ( VIDEO_HEIGHT         )
) u_board(
    .rst            ( rst             ),
    .rst_n          ( rst_n           ),
    .game_rst       ( game_rst        ),
    .game_rst_n     ( game_rst_n      ),
    .rst_req        ( rst_req         ),
    .pll_locked     ( pll_locked      ),
    .downloading    ( dwnld_busy      ),

    .clk_sys        ( clk_sys         ),
    .clk_rom        ( clk_rom         ),

    .core_mod       ( core_mod        ),
    // joystick
    .ps2_kbd_clk    ( ps2_kbd_clk     ),
    .ps2_kbd_data   ( ps2_kbd_data    ),
    .board_joystick1( joystick1       ),
    .board_joystick2( joystick2       ),
    .board_joystick3( joystick3       ),
    .board_joystick4( joystick4       ),
    .game_joystick1 ( game_joystick1  ),
    .game_joystick2 ( game_joystick2  ),
    .game_joystick3 ( game_joystick3  ),
    .game_joystick4 ( game_joystick4  ),

    .db_coin        ( db_coin         ),
    .db_start       ( db_start        ),
    .game_coin      ( game_coin       ),
    .game_start     ( game_start      ),
    .game_service   ( game_service    ),
    // DIP and OSD settings
    .status         ( status          ),
    .enable_fm      ( enable_fm       ),
    .enable_psg     ( enable_psg      ),
    .dip_test       ( dip_test        ),
    .dip_pause      ( dip_pause       ),
    .dip_flip       ( dip_flip        ),
    .dip_fxlevel    ( dip_fxlevel     ),
    // screen
    .gamma_bus      ( gamma_bus       ),
    .direct_video   ( direct_video    ),
    .hdmi_arx       ( hdmi_arx        ),
    .hdmi_ary       ( hdmi_ary        ),
    .rotate         ( rotate          ),
    // LED
    .osd_shown      ( 1'b0            ),
    .game_led       ( game_led        ),
    .led            ( LED             ),
    // Scan doubler output
    .scan2x_r       ( scan2x_r        ),
    .scan2x_g       ( scan2x_g        ),
    .scan2x_b       ( scan2x_b        ),
    .scan2x_hs      ( scan2x_hs       ),
    .scan2x_vs      ( scan2x_vs       ),
    .scan2x_clk     ( scan2x_clk      ),
    .scan2x_cen     ( scan2x_cen      ),
    .scan2x_de      ( scan2x_de       ),
    .scan2x_enb     ( ~force_scan2x   ),
    .scan2x_sl      ( scan2x_sl       ),

    // SDRAM interface
    // Bank 0: allows R/W
    .ba0_addr   ( ba0_addr      ),
    .ba0_rd     ( ba0_rd        ),
    .ba0_wr     ( ba0_wr        ),
    .ba0_din    ( ba0_din       ),
    .ba0_din_m  ( ba0_din_m     ),  // write mask
    .ba0_rdy    ( ba0_rdy       ),
    .ba0_ack    ( ba0_ack       ),

    // Bank 1: Read only
    .ba1_addr   ( ba1_addr      ),
    .ba1_rd     ( ba1_rd        ),
    .ba1_rdy    ( ba1_rdy       ),
    .ba1_ack    ( ba1_ack       ),

    // Bank 2: Read only
    .ba2_addr   ( ba2_addr      ),
    .ba2_rd     ( ba2_rd        ),
    .ba2_rdy    ( ba2_rdy       ),
    .ba2_ack    ( ba2_ack       ),

    // Bank 3: Read only
    .ba3_addr   ( ba3_addr      ),
    .ba3_rd     ( ba3_rd        ),
    .ba3_rdy    ( ba3_rdy       ),
    .ba3_ack    ( ba3_ack       ),

    // ROM-load interface
    .prog_addr  ( prog_addr     ),
    .prog_ba    ( prog_ba       ),
    .prog_rd    ( prog_rd       ),
    .prog_we    ( prog_we       ),
    .prog_data  ( prog_data     ),
    .prog_mask  ( prog_mask     ),
    .prog_rdy   ( prog_rdy      ),
    .prog_ack   ( prog_ack      ),
    // SDRAM interface
    .SDRAM_DQ   ( SDRAM_DQ      ),
    .SDRAM_A    ( SDRAM_A       ),
    .SDRAM_DQML ( SDRAM_DQML    ),
    .SDRAM_DQMH ( SDRAM_DQMH    ),
    .SDRAM_nWE  ( SDRAM_nWE     ),
    .SDRAM_nCAS ( SDRAM_nCAS    ),
    .SDRAM_nRAS ( SDRAM_nRAS    ),
    .SDRAM_nCS  ( SDRAM_nCS     ),
    .SDRAM_BA   ( SDRAM_BA      ),
    .SDRAM_CKE  ( SDRAM_CKE     ),

    // Common signals
    .sdram_dout ( sdram_dout    ),
    .rfsh_en    ( rfsh_en       ),

    // Base video
    .osd_rotate     ( rotate          ),
    .game_r         ( game_r          ),
    .game_g         ( game_g          ),
    .game_b         ( game_b          ),
    .LHBL           ( LHBL            ),
    .LVBL           ( LVBL            ),
    .hs             ( hs_resync       ),
    .vs             ( vs_resync       ),
    .pxl_cen        ( pxl_cen         ),
    .pxl2_cen       ( pxl2_cen        ),
    // Debug
    .gfx_en         ( gfx_en          )
);

`ifdef JTFRAME_VERTICAL
screen_rotate u_rotate(
    .CLK_VIDEO      ( scan2x_clk        ),
    .CE_PIXEL       ( scan2x_cen        ),

    .VGA_R          ( scan2x_r          ),
    .VGA_G          ( scan2x_g          ),
    .VGA_B          ( scan2x_b          ),
    .VGA_HS         ( scan2x_hs         ),
    .VGA_VS         ( scan2x_vs         ),
    .VGA_DE         ( scan2x_de         ),

    .rotate_ccw     ( 1'b0              ),
    .no_rotate      ( ~rotate[0]        ),

    .FB_EN          ( FB_EN             ),
    .FB_FORMAT      ( FB_FORMAT         ),
    .FB_WIDTH       ( FB_WIDTH          ),
    .FB_HEIGHT      ( FB_HEIGHT         ),
    .FB_BASE        ( FB_BASE           ),
    .FB_STRIDE      ( FB_STRIDE         ),
    .FB_VBL         ( FB_VBL            ),
    .FB_LL          ( FB_LL             ),

    .DDRAM_CLK      ( DDRAM_CLK         ),
    .DDRAM_BUSY     ( DDRAM_BUSY        ),
    .DDRAM_BURSTCNT ( DDRAM_BURSTCNT    ),
    .DDRAM_ADDR     ( DDRAM_ADDR        ),
    .DDRAM_DIN      ( DDRAM_DIN         ),
    .DDRAM_BE       ( DDRAM_BE          ),
    .DDRAM_WE       ( DDRAM_WE          ),
    .DDRAM_RD       ( DDRAM_RD          )
);
`endif

endmodule
