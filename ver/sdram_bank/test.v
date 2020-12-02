`timescale 1ns / 1ps

module test;

reg        rst, clk, init_done, waiting;

wire [21:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr;
wire [ 1:0] ba0_din_m;

wire [31:0] dout;
wire        ba0_rd, ba1_rd, ba2_rd, ba3_rd, ba0_wr,
            ba0_rdy, ba1_rdy, ba2_rdy, ba3_rdy,
            ba0_ack, ba1_ack, ba2_ack, ba3_ack,
            rfsh_en;
wire [15:0] ba0_din;

// sdram pins
wire [15:0] sdram_dq;
wire [12:0] sdram_a;
wire [ 1:0] sdram_dqm;
wire [ 1:0] sdram_ba;
wire        sdram_nwe;
wire        sdram_ncas;
wire        sdram_nras;
wire        sdram_ncs;
wire        sdram_cke;

assign rfsh_en = 1;

`ifndef PERIOD
`define PERIOD 10.416
`endif

localparam PERIOD=`PERIOD;

ba_requester #(0, 1,"sdram_bank0.hex") u_ba0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .ba_addr    ( ba0_addr      ),
    .ba_rd      ( ba0_rd        ),
    .ba_wr      ( ba0_wr        ),
    .ba_dout    ( ba0_din       ),
    .ba_dout_m  ( ba0_din_m     ),
    .ba_rdy     ( ba0_rdy       ),
    .ba_ack     ( ba0_ack       ),
    .sdram_dq   ( dout          )
);

ba_requester #(1, 0,"sdram_bank1.hex") u_ba1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .ba_addr    ( ba1_addr      ),
    .ba_rd      ( ba1_rd        ),
    .ba_rdy     ( ba1_rdy       ),
    .ba_ack     ( ba1_ack       ),
    .sdram_dq   ( dout          )
);

ba_requester #(2, 0,"sdram_bank2.hex") u_ba2(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .ba_addr    ( ba2_addr      ),
    .ba_rd      ( ba2_rd        ),
    .ba_rdy     ( ba2_rdy       ),
    .ba_ack     ( ba2_ack       ),
    .sdram_dq   ( dout          )
);


ba_requester #(3, 0,"sdram_bank3.hex") u_ba3(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .ba_addr    ( ba3_addr      ),
    .ba_rd      ( ba3_rd        ),
    .ba_rdy     ( ba3_rdy       ),
    .ba_ack     ( ba3_ack       ),
    .sdram_dq   ( dout          )
);

jtframe_sdram_bank #(.AW(22)) uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
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

    // ROM downloading
    .prog_en    ( 1'b0          ),
    .prog_addr  (               ),
    .prog_ba    (               ),     // bank
    .prog_rd    (               ),
    .prog_wr    (               ),
    .prog_din   (               ),
    .prog_din_m (               ),  // write mask
    .prog_rdy   (               ),
    // SDRAM pins
    .sdram_dq   ( sdram_dq      ),
    .sdram_a    ( sdram_a       ),
    .sdram_dqml ( sdram_dqm[0]  ),
    .sdram_dqmh ( sdram_dqm[1]  ),
    .sdram_ba   ( sdram_ba      ),
    .sdram_nwe  ( sdram_nwe     ),
    .sdram_ncas ( sdram_ncas    ),
    .sdram_nras ( sdram_nras    ),
    .sdram_ncs  ( sdram_ncs     ),
    .sdram_cke  ( sdram_cke     ),
    // Common signals
    .dout       ( dout          ),
    .rfsh_en    ( rfsh_en       )
);

mt48lc16m16a2 sdram(
    .Clk        ( clk       ),
    .Cke        ( sdram_cke ),
    .Dq         ( sdram_dq  ),
    .Addr       ( sdram_a   ),
    .Ba         ( sdram_ba  ),
    .Cs_n       ( sdram_ncs ),
    .Ras_n      ( sdram_nras),
    .Cas_n      ( sdram_ncas),
    .We_n       ( sdram_nwe ),
    .Dqm        ( sdram_dqm ),
    .downloading( 1'b0      ),
    .VS         ( 1'b0      ),
    .frame_cnt  ( 0         )
);

initial begin
    clk=0;
    forever #(PERIOD/2) clk=~clk;
end

initial begin
    rst=1;
    #100 rst=0;
    #5_000_000 $display("PASSED");
    $finish;
end

`ifdef DUMP
initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end
`endif

endmodule


module  ba_requester(
    input               rst,
    input               clk,
    output reg [21:0]   ba_addr,
    output reg          ba_rd,
    output reg          ba_wr,
    output reg [15:0]   ba_dout,
    output reg [ 1:0]   ba_dout_m,
    input               ba_rdy,
    input               ba_ack,
    input      [31:0]   sdram_dq
);

parameter BANK=0, RW=0, MEMFILE="sdram_bank1.hex",
          IDLE=50; // Use 100 or more to keep the bank idle

reg [31:0] data_read;
reg [15:0] mem_data[0:4*1024*1024-1];
reg        waiting, init_done;
reg        rd_cycle;

wire [31:0] expected = { mem_data[ba_addr+1], mem_data[ba_addr] };
wire [15:0] expected_low = mem_data[ba_addr];
wire [15:0] wr_masked = { ba_dout_m[1] ? expected_low[15:8] : ba_dout[15:8],
                          ba_dout_m[0] ? expected_low[ 7:0] : ba_dout[ 7:0] };

initial begin
    $readmemh( MEMFILE, mem_data );
    init_done = 0;
    #104_500 init_done = 1;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ba_addr  <= 22'd0;
        ba_rd    <= 0;
        ba_wr    <= 0;
        waiting  <= 0;
        rd_cycle <= 0;
    end else if(init_done) begin
        if( !waiting ) begin
            if( $urandom%100 > IDLE ) begin
                ba_addr[21:1] <= $urandom; // bit 0 not used for bursts of length 2
                if( $urandom%100>95 && RW) begin
                    ba_rd      <= 0;
                    ba_wr      <= 1;
                    ba_dout    <= $urandom;
                    ba_dout_m  <= $urandom;
                end else begin
                    ba_rd    <= 1;
                    ba_wr    <= 0;
                    rd_cycle <= 1;
                end
                waiting  <= 1;
            end
        end else begin
            if( ba_ack ) begin
                if( ba_wr ) begin
                    mem_data[ ba_addr ] <= wr_masked;
                end
                ba_rd <= 0;
                ba_wr <= 0;
            end
            if( ba_rdy ) begin
                rd_cycle  <= 0;
                waiting   <= 0;
                data_read <= sdram_dq;
                if( sdram_dq != expected && rd_cycle) begin
                    $display("Data read error at address %X (bank %1d). %X read, expected %X\n",
                        ba_addr, BANK, sdram_dq, expected );
                    $finish;
                end
            end
        end
    end
end

endmodule
