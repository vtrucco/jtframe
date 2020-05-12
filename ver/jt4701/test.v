`timescale 1ns/1ps

module test;

reg           clk;
reg           rst;
reg  [1:0]    x_in;
reg  [1:0]    y_in;
reg           rightn;
reg           leftn;
reg           middlen;
reg           x_rstn;
reg           y_rstn;
reg           csn;        // chip select
reg           uln;        // byte selection
reg           xn_y;       // select x or y for reading
wire          cfn;        // counter flag
wire          sfn;        // switch flag
wire [7:0]    dout;

reg  [7:0]    slowcnt;

initial begin
    rightn = 1;
    leftn  = 1;
    middlen= 1;
    x_rstn = 1;
    y_rstn = 1;
    csn    = 1;
    uln    = 1;
    xn_y   = 1;
    x_in   = 2'b0;
    y_in   = 2'b0;
    slowcnt= 0;
    rst    = 0;
    #5;
    rst    = 1;
    #105;
    rst    = 0;
    #10_000;
    $finish;
end

initial begin
    clk    = 0;
    forever #10 clk = ~clk;
end


always @(posedge clk) begin
    slowcnt <= slowcnt+3'd1;
    case( slowcnt[2:0] )
        3'd3: if( ~|slowcnt[7:4] ) x_in[0] <= ~x_in[0];
        3'd7: x_in[1] <= ~x_in[1];
    endcase
end

jt4701 UUT(
    .clk        ( clk        ),
    .rst        ( rst        ),
    .x_in       ( x_in       ),
    .y_in       ( y_in       ),
    .rightn     ( rightn     ),
    .leftn      ( leftn      ),
    .middlen    ( middlen    ),
    .x_rstn     ( x_rstn     ),
    .y_rstn     ( y_rstn     ),
    .csn        ( csn        ),
    .uln        ( uln        ),
    .xn_y       ( xn_y       ),
    .cfn        ( cfn        ),
    .sfn        ( sfn        ),
    .dout       ( dout       )
);

initial begin
    $dumpfile("test.lxt");  
    $dumpvars;  
end

endmodule