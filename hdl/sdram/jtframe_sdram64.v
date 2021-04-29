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
    Date: 29-4-2021 */

// SDRAM is set to burst=2 (64 bits)

module jtframe_sdram64 #(
    parameter AW=22,
              HF=1,     // 1 for HF operation (idle cycles), 0 for LF operation
                        // HF operation starts at 66.6MHz (1/15ns)
              SHIFTED =0,
              BA0_LEN =64, // 1=16 bits, 2=32 bits, 4=64 bits
              BA1_LEN =64,
              BA2_LEN =64,
              BA3_LEN =64,
              PROG_LEN=64,
              RFSHCNT=9  // 8192 every 64ms or 1 every 7.8us ~ 8.2 per line (15kHz)
)(
    input               rst,
    input               clk,

    // requests
    input      [AW-1:0] ba0_addr,
    input      [AW-1:0] ba1_addr,
    input      [AW-1:0] ba2_addr,
    input      [AW-1:0] ba3_addr,
    input         [3:0] rd,
    input         [3:0] wr,
    input        [15:0] din,
    input        [ 1:0] din_m,  // write mask

    // programming
    input               prog_en,
    input      [AW-1:0] prog_addr,
    input               prog_rd,
    input               prog_wr,
    input        [15:0] prog_din,
    input        [ 1:0] prog_din_m,
    input        [ 1:0] prog_ba,
    output  reg         prog_dst,
    output  reg         prog_dok,
    output  reg         prog_rdy,

    input               rfsh, // triggers a distributed cycle of RFSHCNT refresh commands
                              // This is meant to be the horizontal blanking of a 15kHz video
                              // signal. Using HB as rfsh signal also prevents having a bank
                              // active for longer than tRAS_max (120us)

    output        [3:0] ack,
    output reg    [3:0] dst,
    output reg    [3:0] dok,
    output reg    [3:0] rdy,
    output reg   [15:0] dout,

    // SDRAM interface
    // SDRAM_A[12:11] and SDRAM_DQML/H are controlled in a way
    // that can be joined together thru an OR operation at a
    // higher level. This makes it possible to short the pins
    // of the SDRAM, as done in the MiSTer 128MB module
    inout       [15:0]  sdram_dq,       // SDRAM Data bus 16 Bits
    output reg  [12:0]  sdram_a,        // SDRAM Address bus 13 Bits
    output              sdram_dqml,     // SDRAM Low-byte Data Mask
    output              sdram_dqmh,     // SDRAM High-byte Data Mask
    output reg  [ 1:0]  sdram_ba,       // SDRAM Bank Address
    output              sdram_nwe,      // SDRAM Write Enable
    output              sdram_ncas,     // SDRAM Column Address Strobe
    output              sdram_nras,     // SDRAM Row Address Strobe
    output              sdram_ncs,      // SDRAM Chip Select
    output              sdram_cke       // SDRAM Chip Select
);

localparam BURSTLEN=(BA0_LEN>32 || BA1_LEN>32 ||BA2_LEN>32 ||BA3_LEN>32) ? 64 :(
                    (BA0_LEN>16 || BA1_LEN>16 ||BA2_LEN>16 ||BA3_LEN>16) ? 32 : 16);

//                             /CS /RAS /CAS /WE
localparam CMD_LOAD_MODE   = 4'b0___0____0____0, // 0
           CMD_REFRESH     = 4'b0___0____0____1, // 1
           CMD_PRECHARGE   = 4'b0___0____1____0, // 2
           CMD_ACTIVE      = 4'b0___0____1____1, // 3
           CMD_WRITE       = 4'b0___1____0____0, // 4
           CMD_READ        = 4'b0___1____0____1, // 5
           CMD_STOP        = 4'b0___1____1____0, // 6 Burst terminate
           CMD_NOP         = 4'b0___1____1____1, // 7
           CMD_INHIBIT     = 4'b1___0____0____0; // 8

wire  [3:0] br, bx0_cmd, bx1_cmd, bx2_cmd, bx3_cmd, rfsh_cmd,
            ba_dst, ba_dbusy, ba_dbusy64, ba_rdy, ba_dok,
            init_cmd, post_act, next_cmd, dqm_busy;
wire        init, all_dbusy, all_dbusy64, all_act, rfshing, rfsh_br;
reg   [3:0] bg, cmd, dbusy, dbusy64;
reg  [14:0] prio_lfsr;
wire [12:0] bx0_a, bx1_a, bx2_a, bx3_a, init_a, next_a, rfsh_a;
wire [ 1:0] next_ba, prio;

// prog signals
wire        pre_dst, pre_dok, pre_ack;
wire [12:0] pre_a;
wire [ 3:0] pre_cmd;
reg         prog_rst, prog_bg;

reg         rfsh_bg;
reg  [15:0] dq_pad;

assign {sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe } = cmd;
assign {sdram_dqmh, sdram_dqml} = sdram_a[12:11];
assign sdram_cke = 1;
assign all_dbusy   = |dbusy;
assign all_dbusy64 = |dbusy64;
assign all_act     = |post_act;
assign all_dqm     = |dqm_busy;

assign {next_ba, next_cmd, next_a } =
                        init ? { 2'd0, init_cmd, init_a } : (
                      rfshing? { 2'd0, rfsh_cmd, rfsh_a } : (
                      prog_en? { prog_ba, pre_cmd, pre_a} : (
                       bg[0] ? { 2'd0, bx0_cmd, bx0_a } : (
                       bg[1] ? { 2'd1, bx1_cmd, bx1_a } : (
                       bg[2] ? { 2'd2, bx2_cmd, bx2_a } : (
                       bg[3] ? { 2'd3, bx3_cmd, bx3_a } : {2'd0, 4'd7, 13'd0} ))))));

assign prio     = prio_lfsr[1:0];
assign sdram_dq = dq_pad;

always @(negedge clk) begin
    prog_rst <= !prog_en & rst;
end

always @(posedge clk) begin
    dst      <= ba_dst;
    rdy      <= ba_rdy;
    dbusy    <= ba_dbusy;
    dbusy64  <= ba_dbusy64;
    dok      <= ba_dok;
    dout     <= sdram_dq;
    cmd      <= next_cmd;

    // prog signals
    prog_dst <= pre_dst;
    prog_dok <= pre_dok;
    prog_rdy <= pre_rdy;

    sdram_ba      <= next_ba;
    sdram_a[10:0] <= next_a[10:0];

    dq_pad <= next_cmd == CMD_WRITE ? din : 16'hzzzz;
    if( next_cmd==CMD_LOAD_MODE || next_cmd==CMD_ACTIVE || next_cmd==CMD_READ )
        sdram_a[12:11] <= next_a[12:11];
    else if( next_cmd==CMD_WRITE )
        sdram_a[12:11] <= din_m;
    else
        sdram_a[12:11] <= 0;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prio_lfsr <= 1;
    end else begin
        prio_lfsr <= { prio_lfsr[0]^prio_lfsr[14], prio_lfsr[14:1] };
    end
end

jtframe_sdram64_init #(.HF(HF),.BURSTLEN(BURSTLEN)) u_init(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .init       ( init      ),
    .cmd        ( init_cmd  ),
    .sdram_a    ( init_a    )
);

jtframe_sdram64_rfsh #(.HF(HF),.RFSHCNT(RFSHCNT)) u_rfsh(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .start      ( rfsh      ),
    .br         ( rfsh_br   ),
    .bg         ( rfsh_bg   ),
    .rfshing    ( rfshing   ),
    .cmd        ( rfsh_cmd  ),
    .sdram_a    ( rfsh_a    )
);

jtframe_sdram64_bank #(
    .AW       ( AW      ),
    .HF       ( HF      ),
    .SHIFTED  ( SHIFTED ),
    .BALEN    ( PROG_LEN),
    .BURSTLEN ( BURSTLEN),
    // The programmer always precharges all banks
    // at the beginning of the operation
    .AUTOPRECH    ( 1   ),
    .PRECHARGE_ALL( 1   )
) u_prog(
    .rst        ( prog_rst   ),
    .clk        ( clk        ),

    // requests
    .addr       ( prog_addr  ),
    .rd         ( prog_rd    ),
    .wr         ( prog_wr    ),

    .ack        ( pre_ack    ),
    .dst        ( pre_dst    ),    // data starts
    .dbusy      (            ), // prog works alone
    .all_dbusy  ( 1'd0       ),

    .dbusy64    ( prog_busy  ),
    .all_dbusy64( 1'd0       ),

    .post_act   (            ),
    .all_act    ( 1'd0       ),

    .dqm_busy   (            ),
    .all_dqm    ( 1'd0       ),

    .dok        ( pre_dok    ),
    .rdy        ( pre_rdy    ),
    .set_prech  ( 1'd0       ),

    // SDRAM interface
    .br         ( pre_br     ), // bus request
    .bg         ( prog_bg    ), // bus grant

    .sdram_a    ( pre_a      ),
    .cmd        ( pre_cmd    )
);

jtframe_sdram64_bank #(
    .AW       ( AW      ),
    .HF       ( HF      ),
    .SHIFTED  ( SHIFTED ),
    .BURSTLEN ( BURSTLEN),
    .BALEN    ( BA0_LEN )
) u_bank0(
    .rst        ( rst        ),
    .clk        ( clk        ),

    // requests
    .addr       ( ba0_addr   ),
    .rd         ( rd[0]      ),
    .wr         ( wr[0]      ),

    .ack        ( ack[0]     ),
    .dst        ( ba_dst[0]  ),    // data starts
    .dbusy      ( ba_dbusy[0]),
    .all_dbusy  ( all_dbusy  ),

    .dbusy64    (ba_dbusy64[0]),
    .all_dbusy64( all_dbusy64),

    .post_act   ( post_act[0]),
    .all_act    ( all_act    ),

    .dqm_busy   ( dqm_busy[0]),
    .all_dqm    ( all_dqm    ),

    .dok        ( ba_dok[0]  ),
    .rdy        ( ba_rdy[0]  ),
    .set_prech  ( rfsh_bg    ),

    // SDRAM interface
    .br         ( br[0]      ), // bus request
    .bg         ( bg[0]      ), // bus grant

    .sdram_a    ( bx0_a      ),
    .cmd        ( bx0_cmd    )
);

jtframe_sdram64_bank #(
    .AW       ( AW      ),
    .HF       ( HF      ),
    .SHIFTED  ( SHIFTED ),
    .BURSTLEN ( BURSTLEN),
    .BALEN    ( BA1_LEN )
) u_bank1(
    .rst        ( rst        ),
    .clk        ( clk        ),

    // requests
    .addr       ( ba1_addr   ),
    .rd         ( rd[1]      ),
    .wr         ( wr[1]      ),

    .ack        ( ack[1]     ),
    .dst        ( ba_dst[1]  ),    // data starts
    .dbusy      ( ba_dbusy[1]),
    .all_dbusy  ( all_dbusy  ),

    .dbusy64    (ba_dbusy64[1]),
    .all_dbusy64( all_dbusy64),

    .post_act   ( post_act[1]),
    .all_act    ( all_act    ),
    .dok        ( ba_dok[1]  ),
    .rdy        ( ba_rdy[1]  ),
    .set_prech  ( rfsh_bg    ),

    .dqm_busy   ( dqm_busy[1]),
    .all_dqm    ( all_dqm    ),

    // SDRAM interface
    .br         ( br[1]      ), // bus request
    .bg         ( bg[1]      ), // bus grant

    .sdram_a    ( bx1_a      ),
    .cmd        ( bx1_cmd    )
);

jtframe_sdram64_bank #(
    .AW       ( AW      ),
    .HF       ( HF      ),
    .SHIFTED  ( SHIFTED ),
    .BURSTLEN ( BURSTLEN),
    .BALEN    ( BA2_LEN )
) u_bank2(
    .rst        ( rst        ),
    .clk        ( clk        ),

    // requests
    .addr       ( ba2_addr   ),
    .rd         ( rd[2]      ),
    .wr         ( wr[2]      ),

    .ack        ( ack[2]     ),
    .dst        ( ba_dst[2]  ),    // data starts
    .dbusy      ( ba_dbusy[2]),
    .all_dbusy  ( all_dbusy  ),

    .dbusy64    (ba_dbusy64[2]),
    .all_dbusy64( all_dbusy64),

    .post_act   ( post_act[2]),
    .all_act    ( all_act    ),
    .dok        ( ba_dok[2]  ),
    .rdy        ( ba_rdy[2]  ),
    .set_prech  ( rfsh_bg    ),

    .dqm_busy   ( dqm_busy[2]),
    .all_dqm    ( all_dqm    ),

    // SDRAM interface
    .br         ( br[2]      ), // bus request
    .bg         ( bg[2]      ), // bus grant

    .sdram_a    ( bx2_a      ),
    .cmd        ( bx2_cmd    )
);

jtframe_sdram64_bank #(
    .AW       ( AW      ),
    .HF       ( HF      ),
    .SHIFTED  ( SHIFTED ),
    .BURSTLEN ( BURSTLEN),
    .BALEN    ( BA3_LEN )
) u_bank3(
    .rst        ( rst        ),
    .clk        ( clk        ),

    // requests
    .addr       ( ba3_addr   ),
    .rd         ( rd[3]      ),
    .wr         ( wr[3]      ),

    .ack        ( ack[3]     ),
    .dst        ( ba_dst[3]  ),    // data starts
    .dbusy      ( ba_dbusy[3]),
    .all_dbusy  ( all_dbusy  ),

    .dbusy64    (ba_dbusy64[3]),
    .all_dbusy64( all_dbusy64),

    .post_act   ( post_act[3]),
    .all_act    ( all_act    ),
    .dok        ( ba_dok[3]  ),
    .rdy        ( ba_rdy[3]  ),
    .set_prech  ( rfsh_bg    ),

    .dqm_busy   ( dqm_busy[3]),
    .all_dqm    ( all_dqm    ),

    // SDRAM interface
    .br         ( br[3]      ), // bus request
    .bg         ( bg[3]      ), // bus grant

    .sdram_a    ( bx3_a      ),
    .cmd        ( bx3_cmd    )
);

always @(*) begin
    rfsh_bg = br==0 && !all_dbusy && !all_dqm && rfsh_br
           && !init && !all_act && rd==0 && wr==0
           && !(prog_en && (prog_rd || prog_wr )) && !prog_busy;
    if( init || rfshing || prog_en ) begin
        bg=0;
        prog_bg = pre_br & !rfshing;
    end else
    case( {br, prio[1:0]} )
        6'b0000_00: bg=4'b0000;
        6'b0000_01: bg=4'b0000;
        6'b0000_10: bg=4'b0000;
        6'b0000_11: bg=4'b0000;
        6'b0001_00: bg=4'b0001;
        6'b0001_01: bg=4'b0001;
        6'b0001_10: bg=4'b0001;
        6'b0001_11: bg=4'b0001;
        6'b0010_00: bg=4'b0010;
        6'b0010_01: bg=4'b0010;
        6'b0010_10: bg=4'b0010;
        6'b0010_11: bg=4'b0010;
        6'b0011_00: bg=4'b0001;
        6'b0011_01: bg=4'b0010;
        6'b0011_10: bg=4'b0001;
        6'b0011_11: bg=4'b0010;
        6'b0100_00: bg=4'b0100;
        6'b0100_01: bg=4'b0100;
        6'b0100_10: bg=4'b0100;
        6'b0100_11: bg=4'b0100;
        6'b0101_00: bg=4'b0001;
        6'b0101_01: bg=4'b0001;
        6'b0101_10: bg=4'b0100;
        6'b0101_11: bg=4'b0100;

        6'b0110_00: bg=4'b0010;
        6'b0110_01: bg=4'b0010;
        6'b0110_10: bg=4'b0100;
        6'b0110_11: bg=4'b0100;

        6'b0111_00: bg=4'b0001;
        6'b0111_01: bg=4'b0010;
        6'b0111_10: bg=4'b0100;
        6'b0111_11: bg=4'b0001;  //*0001

        6'b1000_00: bg=4'b1000;
        6'b1000_01: bg=4'b1000;
        6'b1000_10: bg=4'b1000;
        6'b1000_11: bg=4'b1000;

        6'b1001_00: bg=4'b0001;
        6'b1001_01: bg=4'b0001;
        6'b1001_10: bg=4'b1000;
        6'b1001_11: bg=4'b1000;

        6'b1010_00: bg=4'b0010;
        6'b1010_01: bg=4'b0010;
        6'b1010_10: bg=4'b1000;
        6'b1010_11: bg=4'b1000;

        6'b1011_00: bg=4'b0001;
        6'b1011_01: bg=4'b0010; //*0010
        6'b1011_10: bg=4'b0010;
        6'b1011_11: bg=4'b1000;

        6'b1100_00: bg=4'b1000;
        6'b1100_01: bg=4'b0100;
        6'b1100_10: bg=4'b0100;
        6'b1100_11: bg=4'b1000;

        6'b1101_00: bg=4'b0001;
        6'b1101_01: bg=4'b0100; //*0100
        6'b1101_10: bg=4'b0100;
        6'b1101_11: bg=4'b1000;

        6'b1110_00: bg=4'b1000; //*1000
        6'b1110_01: bg=4'b0010;
        6'b1110_10: bg=4'b0100;
        6'b1110_11: bg=4'b1000;

        6'b1111_00: bg=4'b0001;
        6'b1111_01: bg=4'b0010;
        6'b1111_10: bg=4'b0100;
        6'b1111_11: bg=4'b1000;
    endcase
end

endmodule