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

ba_requester #(1) u_ba0(
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

ba_requester #(0) u_ba1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .ba_addr    ( ba1_addr      ),
    .ba_rd      ( ba1_rd        ),
    .ba_rdy     ( ba1_rdy       ),
    .ba_ack     ( ba1_ack       ),
    .sdram_dq   ( dout          )
);

ba_requester #(0) u_ba2(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .ba_addr    ( ba2_addr      ),
    .ba_rd      ( ba2_rd        ),
    .ba_rdy     ( ba2_rdy       ),
    .ba_ack     ( ba2_ack       ),
    .sdram_dq   ( dout          )
);


ba_requester #(0) u_ba3(
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
    #500_000 $finish;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

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

parameter RW=0, IDLE=50;

reg [31:0] data_read;
reg        waiting, init_done;

initial begin
    init_done = 0;
    #104_500 init_done = 1;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ba_addr  <= 22'd0;
        ba_rd    <= 0;
        ba_wr    <= 0;
        waiting  <= 0;
    end else if(init_done) begin
        if( !waiting ) begin
            if( $urandom%100 > IDLE ) begin
                ba_addr[19:0] <= $urandom;
                if( $urandom%100>95 && RW) begin
                    ba_rd      <= 0;
                    ba_wr      <= 1;
                    ba_dout    <= $urandom;
                    ba_dout_m  <= $urandom;
                end else begin
                    ba_rd <= 1;
                    ba_wr <= 0;
                end
                waiting  <= 1;
            end
        end else begin
            if( ba_ack ) begin
                ba_rd <= 0;
                ba_wr <= 0;
            end
            if( ba_rdy ) begin
                waiting <= 0;
                data_read <= sdram_dq;
            end
        end
    end
end

endmodule
