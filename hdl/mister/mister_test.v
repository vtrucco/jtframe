`timescale 1ns/1ps

// Test bench for MiSTer
// This only verifies the core module "emu"
// The framework is not simulated

/* verilator lint_off STMTDLY */

module mister_test;

wire [31:0] frame_cnt;
wire VGA_HS, VGA_VS;

wire            downloading;
wire    [21:0]  ioctl_addr;
wire    [ 7:0]  ioctl_data;
wire cen12, cen6, cen3, cen1p5, clk, clk27, rst;
wire [21:0]  sdram_addr;
wire [15:0]  data_read;
wire SPI_SCK, SPI_DO, SPI_DI, SPI_SS2, CONF_DATA0;

wire [15:0] SDRAM_DQ;
wire [12:0] SDRAM_A;
wire [ 1:0] SDRAM_BA;
wire SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE,  SDRAM_nCAS,
     SDRAM_nRAS, SDRAM_nCS,  SDRAM_CLK,  SDRAM_CKE;

wire [15:0] AUDIO_L, AUDIO_R;
wire        AUDIO_S;

wire        LED_USER;
wire  [1:0] LED_POWER;
wire  [1:0] LED_DISK;

wire         CLK_50M;
wire         RESET;
wire  [44:0] HPS_BUS;

// VGA signals
wire        VGA_CLK;
wire        VGA_CE;
wire  [7:0] VGA_R;
wire  [7:0] VGA_G;
wire  [7:0] VGA_B;
wire        VGA_HS;
wire        VGA_VS;
wire        VGA_DE;

// HDMI signals are basically ignored in this simulation
wire        HDMI_CLK;
wire        HDMI_CE;
wire  [7:0] HDMI_R;
wire  [7:0] HDMI_G;
wire  [7:0] HDMI_B;
wire        HDMI_HS;
wire        HDMI_VS;
wire        HDMI_DE;
wire  [1:0] HDMI_SL;
wire  [7:0] HDMI_ARX;
wire  [7:0] HDMI_ARY;
`ifdef CLK24
    parameter CLK_SPEED=24;
`else
    parameter CLK_SPEED=12;
`endif

mist_dump u_dump(
    .VGA_VS     ( VGA_VS    ),
    .led        ( led       ),
    .frame_cnt  ( frame_cnt )
);

test_harness #(.sdram_instance(0),.GAME_ROMNAME(`GAME_ROM_PATH),
    .TX_LEN(887808), .CLK_SPEED(CLK_SPEED) ) u_harness(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .clk27       ( clk27         ),
    .cen12       ( cen12         ),
    .cen6        ( cen6          ),
    .cen3        ( cen3          ),
    .cen1p5      ( cen1p5        ),
    .downloading ( downloading   ),
    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_data  ( ioctl_data    ),
    .SPI_SCK     ( SPI_SCK       ),
    .SPI_SS2     ( SPI_SS2       ),
    .SPI_DI      ( SPI_DI        ),
    .SPI_DO      ( SPI_DO        ),
    .CONF_DATA0  ( CONF_DATA0    ),
    // Video dumping. VGA_ signals are equal to game signals in simulation.
    .HS          ( VGA_HS    ),
    .VS          ( VGA_VS    ),
    .red         ( VGA_R[3:0]),
    .green       ( VGA_G[3:0]),
    .blue        ( VGA_B[3:0]),
    .frame_cnt   ( frame_cnt ),
    // SDRAM
    .SDRAM_DQ    ( SDRAM_DQ  ),
    .SDRAM_A     ( SDRAM_A   ),
    .SDRAM_DQML  ( SDRAM_DQML),
    .SDRAM_DQMH  ( SDRAM_DQMH),
    .SDRAM_nWE   ( SDRAM_nWE ),
    .SDRAM_nCAS  ( SDRAM_nCAS),
    .SDRAM_nRAS  ( SDRAM_nRAS),
    .SDRAM_nCS   ( SDRAM_nCS ),
    .SDRAM_BA    ( SDRAM_BA  ),
    .SDRAM_CLK   ( SDRAM_CLK ),
    .SDRAM_CKE   ( SDRAM_CKE ),
    // unused
    .H0          ( 1'bz      ),
    .autorefresh ( 1'bz      ),
    .sdram_addr  ( 22'bz     ),
    .data_read   (),
    .loop_rst    (),
    .ioctl_wr    ()
);

`ifdef SIM_UART
wire UART_RX, UART_TX;
assign UART_RX = UART_TX; // make a loop!
`endif


emu UUT(
    .CLK_50M    (  CLK_50M      ),
    .RESET      (  RESET        ),
    .HPS_BUS    (  HPS_BUS      ),
    // VGA
    .VGA_CLK    (  VGA_CLK      ),
    .VGA_CE     (  VGA_CE       ),
    .VGA_R      (  VGA_R        ),
    .VGA_G      (  VGA_G        ),
    .VGA_B      (  VGA_B        ),
    .VGA_HS     (  VGA_HS       ),
    .VGA_VS     (  VGA_VS       ),
    .VGA_DE     (  VGA_DE       ),
    // HDMI -- all ignored --
    .HDMI_CLK   (  HDMI_CLK     ),
    .HDMI_CE    (  HDMI_CE      ),
    .HDMI_R     (  HDMI_R       ),
    .HDMI_G     (  HDMI_G       ),
    .HDMI_B     (  HDMI_B       ),
    .HDMI_HS    (  HDMI_HS      ),
    .HDMI_VS    (  HDMI_VS      ),
    .HDMI_DE    (  HDMI_DE      ),
    .HDMI_SL    (  HDMI_SL      ),
    .HDMI_ARX   (  HDMI_ARX     ),
    .HDMI_ARY   (  HDMI_ARY     ),
    // LEDs
    .LED_USER   (  LED_USER     ),
    .LED_POWER  (  LED_POWER    ),
    .LED_DISK   (  LED_DISK     ),
    // AUDIO
    .AUDIO_L    (  AUDIO_L      ),
    .AUDIO_R    (  AUDIO_R      ),
    .AUDIO_S    (  AUDIO_S      ),
    // SDRAM
    .SDRAM_CLK  (  SDRAM_CLK    ),
    .SDRAM_CKE  (  SDRAM_CKE    ),
    .SDRAM_A    (  SDRAM_A      ),
    .SDRAM_BA   (  SDRAM_BA     ),
    .SDRAM_DQ   (  SDRAM_DQ     ),
    .SDRAM_DQML (  SDRAM_DQML   ),
    .SDRAM_DQMH (  SDRAM_DQMH   ),
    .SDRAM_nCS  (  SDRAM_nCS    ),
    .SDRAM_nCAS (  SDRAM_nCAS   ),
    .SDRAM_nRAS (  SDRAM_nRAS   ),
    .SDRAM_nWE  (  SDRAM_nWE    )
);

endmodule