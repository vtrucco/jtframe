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
    Date: 25-9-2019 */

module jtframe_cheat #(parameter
        AW=22,
parameter [AW-1:0] CHEAT_ADDR==0,
          [  15:0] CHEAT_VAL==0,
          [   1:0] CHEAT_MASK==2,
          [   5:0] FRAME_CNT=6'd59
)(
    input   rst,
    input   clk_rom,

    input   LVBL,
    input   enable,

    // From/to game
    input  [AW-1:0] game_addr,
    input           game_rd,
    input           game_wr,
    input  [ 15:0]  game_din,
    input  [  1:0]  game_din_m,
    output          game_rdy,

    // From/to SDRAM bank 0
    output [AW-1:0] ba0_addr,
    output          ba0_rd,
    output          ba0_wr,
    output [ 15:0]  ba0_din,
    output [  1:0]  ba0_din_m,
    input  [ 15:0]  data_read,

    input           ba0_dst,
    input           ba0_rdy,

    // PBlaze Program
    input           prog_en,      // resets the address counter
    input           prog_wr,      // strobe for new data
    input  [7:0]    prog_data
);

wire clk = clk_rom;

// Instruction ROM
wire [11:0] iaddr;
wire [ 7:0] idata;

// Ports
wire [ 7:0] pout, paddr;
reg  [17:0] pin;
wire        pwr, kwr, prd;

// interrupts
reg         irq, LVBL_last;
wire        iack;

always @(posedge clk) begin
    LVBL_last <= LVBL;
    if( !LVBL && LVBL_last ) irq <= 1;
    else if( iack ) irq <= 0;
end

// Ports
reg [7:0] ports[0:7];
wire [23:0] blaze_sdram_addr;
wire [15:0] blaze_sdram_din;
wire [ 1:0] blaze_sdram_din_m;

assign blaze_sdram_addr  = { ports[2], ports[1], ports[0] };
assign blaze_sdram_din   = { ports[4], ports[3] };
assign blaze_sdram_din_m = ports[5][1:0];

always @(posedge clk) begin
    if( pwr && paddr<=5 ) begin
        ports[ paddr[2:0] ] <= pout;
    end
    if( ba0_dst ) begin
        {ports[7], ports[6]} <= data_read;
    end
    if( pwr && paddr[7] ) begin
        sdram_req <= 1;
        sdran_req_wr <= paddr[6];
    end
end

always @(*) begin
    pin = 0;
    if( paddr < 8 )
        pin = ports[ paddr[2:0] ];
end

// SDRAM arbitrer

pauloBlaze u_blaze(
    .clk            ( clk       ),
    .reset          ( rst       ),
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

    .interrupt      ( irq       ),
    .interrupt_ack  ( iack      )
);

// 8 to 18 bit conversion
reg  [15:0] prog_fifo;
reg  [ 8:0] st;
reg         last_en, prog_post;
reg  [17:0] prog_word;

always @(posedge clk) begin
    last_en <= prog_en;
    if( prog_en & ~last_en ) begin
        word_cnt  <= 0;
        prog_post <= 0;
    end else begin
        if( prog_wr ) begin
            prog_fifo <= { prog_data, prog_fifo[15:8] };
            word_cnt  <= word_cnt[3] ? 4'd0 : word_cnt + 4'd1;
            case( word_cnt )
                2: begin
                    word_we   <= 1;
                    prog_word <= { prog_data[1:0], prog_fifo };
                end
                4: begin
                    word_we   <= 1;
                    prog_word <= { prog_data[3:0], prog_fifo[15:2] };
                end
                6: begin
                    word_we   <= 1;
                    prog_word <= { prog_data[5:0], prog_fifo[15:4] };
                end
                8: begin
                    word_we   <= 1;
                    prog_word <= { prog_data[7:0], prog_fifo[15:6] };
                end
                default: word_we <= 0;
            endcase
        end else begin
            word_we <= 0;
        end
    end
end

jtframe_prom #(.dw(18),aw(12)) u_irom(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_word ),
    .rd_addr( iaddr     ),
    .wr_addr( prog_addr ),
    .we     ( word_we   ),
    .q      ( idata     )
);

endmodule
