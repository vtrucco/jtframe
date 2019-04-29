`timescale 1ns/1ps

module jtgng_pll0(
    input    inclk0,
    output   reg c1,      // 12
    output   reg c2,      // 96
    output       c3,     // 96 (shifted by -2.5ns)
    output   locked
);

assign locked = 1'b1;

`ifdef BASE_CLK
real base_clk = `BASE_CLK;
initial $display("INFO: base clock set to %f ns",base_clk);
`else
real base_clk = 9.259;
`endif

initial begin
    c2 = 1'b0;
    // forever c2 = #(10.417/2) ~c2; // 96 MHz
    forever c2 = #(base_clk/2.0) ~c2; // 108 MHz
end

reg [3:0] div=5'd0;

initial c1=1'b0;

`ifndef CLK24
    always @(posedge c2) begin
        div <= div=='d8 ? 'd0 : div+'d1;
        if ( div=='d0 ) c1 <= 1'b0;
        if ( div=='d4 ) c1 <= 1'b1;

    end
`else
    always @(posedge c2) begin
        div <= div=='d8 ? 'd0 : div+'d1;
        case( div )
            5'd0: c1 <= 1'b0;
            5'd2: c1 <= 1'b1;
            5'd4: c1 <= 1'b0;
            5'd7: c1 <= 1'b1;
        endcase
    end
`endif

`ifdef SDRAM_DELAY
real sdram_delay = `SDRAM_DELAY;
initial $display("INFO: SDRAM_CLK delay set to %f ns",sdram_delay);
assign #sdram_delay c3 = c2;
`else
initial $display("INFO: SDRAM_CLK delay set to 2.5 ns");
assign #2.5 c3 = c2;
`endif

endmodule // jtgng_pll0


module jtgng_pll1 (
    input inclk0,
    output reg c0     // 25
);

initial begin
    c0 = 1'b0;
    forever c0 = #20 ~c0;
end

endmodule // jtgng_pll1


////////////////////////////////////////////////////
////////////////////////////////////////////////////
// 20 MHz PLL

module jtframe_pll20_fast(
    input    inclk0,
    output   reg c0,     // 20
    output   reg c1,     // 80
    output   reg c2,     // 80 (shifted by -2.5ns)
    output   locked
);

    assign locked = 1'b1;

    `ifdef BASE_CLK
    real base_clk = `BASE_CLK;
    initial $display("INFO: base clock set to %f ns",base_clk);
    `else
    real base_clk = 12.5; // 80 MHz
    `endif

    initial begin
        c1 = 1'b0;
        forever c1 = #(base_clk/2.0) ~c1; // 80 MHz
    end

    reg [1:0] div=2'd0;

    assign c0 = div[1];

    always @(posedge c1) begin
        div <= div+'d1;
    end

    `ifdef SDRAM_DELAY
    real sdram_delay = `SDRAM_DELAY;
    initial $display("INFO: SDRAM_CLK delay set to %f ns",sdram_delay);
    `else
    initial $display("INFO: SDRAM_CLK delay set to 0 ns");
    real sdram_delay = 0;
    `endif

    initial begin
        c2 = 1'b0;
        #(sdram_delay);
        forever c2 = #(base_clk/2.0) ~c2; // 80 MHz
    end
endmodule