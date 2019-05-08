`timescale 1ns/1ps

module mister_pll_48(
    input      refclk,
    output reg locked,
    output reg outclk_0,    // clk_sys, 48 MHz
    output reg outclk_1,    // SDRAM_CLK = clk_sys delayed
);

assign locked = 1'b1;

`ifdef BASE_CLK
real base_clk = `BASE_CLK;
initial $display("INFO mister_pll24: base clock set to %f ns",base_clk);
`else
real base_clk = 20.833; // 48 MHz
`endif

initial begin
    outclk_0 = 1'b0;
    forever outclk_0 = #(base_clk/2.0) ~outclk_0; // 108 MHz
end

reg div=1'b0;

`ifndef SDRAM_DELAY
`define SDRAM_DELAY 4
`endif

real sdram_delay = `SDRAM_DELAY;
initial $display("INFO mister_pll24: SDRAM_CLK delay set to %f ns",sdram_delay);
assign #sdram_delay outclk_1 = outclk_0;

endmodule // pll