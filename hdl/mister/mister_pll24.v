`timescale 1ns/1ps

module pll(
    input      refclk,
    output reg locked,
    output reg outclk_0,    // clk_rom, 108 MHz
    output reg outclk_1,    // SDRAM_CLK
    output reg outclk_2     // clk_sys, 24 MHz
);

assign locked = 1'b1;

`ifdef BASE_CLK
real base_clk = `BASE_CLK;
initial $display("INFO mister_pll24: base clock set to %f ns",base_clk);
`else
real base_clk = 9.259;
`endif

initial begin
    outclk_0 = 1'b0;
    forever outclk_0 = #(base_clk/2.0) ~outclk_0; // 108 MHz
end

reg [3:0] div=5'd0;

initial outclk_2=1'b0;

always @(posedge outclk_0) begin
    div <= div=='d8 ? 'd0 : div+'d1;
    case( div )
        5'd0: outclk_2 <= 1'b0;
        5'd2: outclk_2 <= 1'b1;
        5'd4: outclk_2 <= 1'b0;
        5'd7: outclk_2 <= 1'b1;
    endcase
end

`ifdef SDRAM_DELAY
real sdram_delay = `SDRAM_DELAY;
initial $display("INFO mister_pll24: SDRAM_CLK delay set to %f ns",sdram_delay);
assign #sdram_delay outclk_1 = outclk_0;
`else
initial $display("INFO mister_pll24: SDRAM_CLK delay set to 0 ns");
assign outclk_1 = outclk_0;
`endif

endmodule // pll