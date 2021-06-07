/*  This file is part of JT_FRAME.
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
    Date: 1-6-2021 */

module jtframe_cheat #(parameter AW=22)(
    input   rst,
    input   clk_rom,

    input   LVBL,

    // From/to game
    input  [AW-1:0] game_addr,
    input           game_rd,
    input           game_wr,
    input  [ 15:0]  game_din,
    input  [  1:0]  game_din_m,
    output reg      game_ack,
    output reg      game_dst,
    output reg      game_rdy,

    // From/to SDRAM bank 0
    output reg [AW-1:0] ba0_addr,
    output reg          ba0_rd,
    output reg          ba0_wr,
    input               ba0_ack,
    input               ba0_dst,
    input               ba0_rdy,
    output reg [ 15:0]  ba0_din,
    output reg [  1:0]  ba0_din_m,
    input      [ 15:0]  data_read,

    // control
    input  [ 31:0]  flags,
    output reg      led,

    // Communication with game module
    output reg [7:0] st_addr,
    input      [7:0] st_dout,
    input      [7:0] debug_bus,

    // Video RAM
    output reg [9:0] vram_addr,
    output reg [7:0] vram_dout,
    input      [7:0] vram_din,
    output reg       vram_we,
    output reg [1:0] vram_ctrl,

    // PBlaze Program
    input           prog_en,      // resets the address counter
    input           prog_wr,      // strobe for new data
    input  [7:0]    prog_data
);

localparam CHEATW=10;  // 12=>9kB (8 BRAM)
                       // 10=>2.25kB (2 BRAM), 9=>1.12kB (1 BRAM)

wire clk = clk_rom;

// Instruction ROM
wire [11:0] iaddr;
wire [17:0] idata;

// Ports
wire [ 7:0] pout, paddr;
reg  [ 7:0] pin=0;
wire        pwr, kwr, prd;

// interrupts
reg         irq=0, LVBL_last;
wire        iack;

reg  [3:0]  watchdog;
reg         prst=0;

always @(posedge clk) begin
    prst <= watchdog[3] | rst;
end

always @(posedge clk) begin
    if( prst ) begin
        irq       <= 0;
        LVBL_last <= 0;
    end else begin
        LVBL_last <= LVBL;
        if( !LVBL && LVBL_last ) irq <= 1;
        else if( iack ) irq <= 0;
    end
end

// Ports
reg  [ 7:0] ports[0:7];
wire [23:0] blaze_sdram_addr;
wire [15:0] blaze_sdram_din;
wire [ 1:0] blaze_sdram_din_m;

// SDRAM
reg  sdram_busy=0, pico_busy=0, owner=0, sdram_req=0, sdram_req_wr=0;

assign blaze_sdram_addr  = { ports[2], ports[1], ports[0] };
assign blaze_sdram_din   = { ports[4], ports[3] };
assign blaze_sdram_din_m = ports[5][1:0];

// VRAM
always @(posedge clk) begin
    if( rst ) begin
        vram_we    <= 0;
        vram_ctrl  <= 0;
    end else begin
        vram_we <= 0;
        if( (pwr|kwr) && paddr[7:3]==5'b0000_1 ) begin
            case( paddr[2:0] )
                0: vram_addr[4:0] <= pout[4:0];
                1: vram_addr[9:5] <= pout[4:0];
                2: { vram_we, vram_dout } <= { 1'b1, 1'b1, pout[6:0] };
                3: vram_ctrl <= pout[1:0];
            endcase
        end
    end
end

always @(posedge clk) begin
    if( (pwr|kwr) && paddr<=5 ) begin
        ports[ paddr[2:0] ] <= pout;
    end
    // Game status
    if( (pwr|kwr) && paddr==8'hc ) begin
        st_addr <= pout;
    end
    // SDRAM
    if( ba0_dst && owner ) begin
        {ports[7], ports[6]} <= data_read;
    end
    if( pwr && paddr[7] ) begin
        sdram_req <= 1;
        sdram_req_wr <= paddr[6];
    end
    if( ba0_ack && owner ) begin
        sdram_req <= 0;
    end
    // watchdog
    if( !LVBL && LVBL_last ) begin
        watchdog <= watchdog+1'd1;
    end
    if( (pwr && paddr[7:6]==2'b01) || prst )
        watchdog <= 0;
    // led
    if( prst )
        led <= 0;
    else if( (pwr|kwr) && paddr==6 )
        led <= pout[0];
end

always @(posedge clk) begin
    if(prst) begin
        pin <= 0;
    end else if(prd) begin
        if( paddr < 8 )
            pin <= ports[ paddr[2:0] ];
        else if( paddr[7:4]==1 ) begin
            case( paddr[1:0] )
                0: pin <= flags[ 7: 0];
                1: pin <= flags[15: 8];
                2: pin <= flags[23:16];
                3: pin <= flags[31:24];
            endcase
        end else if( paddr[7] ) begin
            pin <= { owner, pico_busy, LVBL, 5'b0 }; // 8'hc0 means that the SDRAM data is ready
        end else begin // VRAM or status
            case( paddr[3:0] )
                10: pin <= vram_din;
                13: pin <= st_dout;
                15: pin <= debug_bus;
                default: pin <= 0;
            endcase
        end
    end
end

// SDRAM arbitrer

always @(posedge clk) begin
    if( ba0_rdy ) begin
        sdram_busy <= 0;
        if( owner ) pico_busy <= 0;
    end
    if( !sdram_busy  ) begin
        if( game_rd || game_wr ) begin
            sdram_busy <= 1;
            owner <= 0;
        end else if( sdram_req ) begin
            sdram_busy <= 1;
            owner <= 1;
            pico_busy <= 1;
        end
    end
end

always @(*) begin
    ba0_addr  = owner ? blaze_sdram_addr  : game_addr;
    ba0_rd    = owner ? (sdram_req & ~sdram_req_wr) : game_rd;
    ba0_wr    = owner ? (sdram_req &  sdram_req_wr) : game_wr;
    ba0_din   = owner ? blaze_sdram_din   : game_din;
    ba0_din_m = owner ? blaze_sdram_din_m : game_din_m;
    game_dst  = ~owner & ba0_dst;
    game_rdy  = ~owner & ba0_rdy;
    game_ack  = ~owner & ba0_ack;
end

// PicoBlaze compatible module

pauloBlaze u_blaze(
    .clk            ( clk       ),
    .reset          ( prst      ),
    .sleep          ( 1'b0      ),

    .address        ( iaddr     ),
    .instruction    ( idata     ),
    .bram_enable    (           ),

    .in_port        ( pin       ),
    .out_port       ( pout      ),
    .port_id        ( paddr     ),
    .write_strobe   ( pwr       ),
    .k_write_strobe ( kwr       ),
    .read_strobe    ( prd       ),

    //.interrupt      ( irq       ),
    .interrupt      ( 1'b0      ), // The interrupt in pauloBlaze is buggy
    .interrupt_ack  ( iack      )
);

jtframe_cheat_rom #(.AW(CHEATW)) u_rom(
    .clk        ( clk       ),
    .iaddr      ( iaddr     ),
    .idata      ( idata     ),
    // PBlaze Program
    .prog_en    ( prog_en   ),      // resets the address counter
    .prog_wr    ( prog_wr   ),      // strobe for new data
    .prog_data  ( prog_data )
);

endmodule
