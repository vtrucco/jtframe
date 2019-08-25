module jtframe_mister(
    input           clk_sys,
    input           clk_rom,
    input           pll_locked,
    // interface with microcontroller
    output [31:0]   status,
    inout  [44:0]   HPS_BUS,
    output [ 1:0]   buttons,
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
    // ROM load
    output [21:0]   ioctl_addr,
    output [ 7:0]   ioctl_data,
    output          ioctl_wr,
    input  [21:0]   prog_addr,
    input  [ 7:0]   prog_data,
    input  [ 1:0]   prog_mask,
    input           prog_we,
    output          downloading,
    // ROM access from game
    input           sdram_req,
    output          sdram_ack,
    input  [21:0]   sdram_addr,
    output [31:0]   data_read,
    output          data_rdy,
    output          loop_rst,
    input           refresh_en,
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
    output  [ 1:0]  game_coin,
    output  [ 1:0]  game_start,
    output          game_service,
    // DIP and OSD settings
    output  [ 7:0]  hdmi_arx,
    output  [ 7:0]  hdmi_ary,
    output  [ 1:0]  rotate,
    output          en_mixing,
    output  [ 2:0]  scanlines,
    output          force_scan2x,

    output          enable_fm,
    output          enable_psg,

    output          dip_test,
    // non standard:
    output          dip_pause,
    output          dip_flip,     // A change in dip_flip implies a reset
    output  [ 1:0]  dip_fxlevel,
    // Debug
    output          LED,
    output   [3:0]  gfx_en
);

parameter SIGNED_SND=1'b0;
parameter THREE_BUTTONS=1'b0;
parameter GAME_INPUTS_ACTIVE_LOW=1'b1;
parameter CONF_STR = "";

assign LED  = downloading;

// control
wire [15:0]   joystick1, joystick2;
wire          ps2_kbd_clk, ps2_kbd_data;
wire [2:0]    hpsio_nc; // top 3 bits of ioctl_addr are ignored


hps_io #(.STRLEN($size(CONF_STR)/8)) u_hps_io
(
    .clk_sys         ( clk_sys      ),
    .HPS_BUS         ( HPS_BUS      ),
    .conf_str        ( CONF_STR     ),

    .buttons         ( buttons      ),
    .status          ( status       ),
    .forced_scandoubler(force_scan2x),

    .ioctl_download  ( downloading  ),
    .ioctl_wr        ( ioctl_wr     ),
    .ioctl_addr      ( {hpsio_nc, ioctl_addr } ),
    .ioctl_dout      ( ioctl_data   ),

    .joystick_0      ( joystick1    ),
    .joystick_1      ( joystick2    ),
    .ps2_kbd_clk_out ( ps2_kbd_clk  ),
    .ps2_kbd_data_out( ps2_kbd_data )
    //.ps2_key       ( ps2_key       )
);


jtframe_board #(.THREE_BUTTONS(THREE_BUTTONS),
    .GAME_INPUTS_ACTIVE_LOW(GAME_INPUTS_ACTIVE_LOW)
) u_board(
    .rst            ( rst             ),
    .rst_n          ( rst_n           ),
    .game_rst       ( game_rst        ),
    .game_rst_n     ( game_rst_n      ),
    .rst_req        ( rst_req         ),
    .downloading    ( downloading     ),

    .clk_sys        ( clk_sys         ),
    .clk_rom        ( clk_rom         ),
    // joystick
    .ps2_kbd_clk    ( ps2_kbd_clk     ),
    .ps2_kbd_data   ( ps2_kbd_data    ),
    .board_joystick1( joystick1[9:0]  ),
    .board_joystick2( joystick2[9:0]  ),
`ifndef SIM_INPUTS
    .game_joystick1 ( game_joystick1  ),
    .game_joystick2 ( game_joystick2  ),
    .game_coin      ( game_coin       ),
    .game_start     ( game_start      ),
`endif
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
    .hdmi_arx       ( hdmi_arx        ),
    .hdmi_ary       ( hdmi_ary        ),
    .rotate         ( rotate          ),
    .en_mixing      ( en_mixing       ),
    .scanlines      ( scanlines       ),
    // SDRAM interface
    .SDRAM_DQ       ( SDRAM_DQ        ),
    .SDRAM_A        ( SDRAM_A         ),
    .SDRAM_DQML     ( SDRAM_DQML      ),
    .SDRAM_DQMH     ( SDRAM_DQMH      ),
    .SDRAM_nWE      ( SDRAM_nWE       ),
    .SDRAM_nCAS     ( SDRAM_nCAS      ),
    .SDRAM_nRAS     ( SDRAM_nRAS      ),
    .SDRAM_nCS      ( SDRAM_nCS       ),
    .SDRAM_BA       ( SDRAM_BA        ),
    .SDRAM_CKE      ( SDRAM_CKE       ),
    // SDRAM controller
    .loop_rst       ( loop_rst        ),
    .sdram_addr     ( sdram_addr      ),
    .sdram_req      ( sdram_req       ),
    .sdram_ack      ( sdram_ack       ),
    .data_read      ( data_read       ),
    .data_rdy       ( data_rdy        ),
    .refresh_en     ( refresh_en      ),
    .prog_addr      ( prog_addr       ),
    .prog_data      ( prog_data       ),
    .prog_mask      ( prog_mask       ),
    .prog_we        ( prog_we         ),
    // Debug
    .gfx_en         ( gfx_en          )
);

endmodule