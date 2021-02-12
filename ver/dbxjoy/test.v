`timescale 1ns / 1ps

module test;

reg  rst, clk;
wire [15:0] joystick_0, joystick_1;
wire [ 5:0] joy_raw;
wire [ 7:0] user_in;
wire        user_osd;
wire [ 4:0] user_out;
reg  [11:0] joy_in;
wire [ 5:0] md_out;
wire        neo_out;

integer k=0;

`ifdef MD
    assign {user_in[6],user_in[3],user_in[5],user_in[7],user_in[1],user_in[2]} = md_out;
`else
    assign user_in[5] = neo_out;
    assign user_in[7:6] = 2'b11;
    assign user_in[4:0] = user_out[4:0];
`endif

initial begin
    rst = 1;
    #100 rst = 0;
end

initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

always @(posedge clk) begin
    k <= k+1;
    if( k[10:0]==0 ) begin
        joy_in <= 12'd0;
        joy_in[($random%8)+4]<=1;
        joy_in[$random%4]<=1;
    end
    if( k[16] ) $finish;
end

megadrive md_joy(
    .joy_in ( joy_in      ),
    .sel    ( user_out[0] ),
    .dbout  ( md_out      )
);

neogeo neo_joy(
    .clk        ( user_out[1] ),
    .loadb      ( user_out[0] ),
    .joy0_in    ( joy_in      ),
    .joy1_in    ( 12'h0       ),
    .dout       ( neo_out     )
);

jtframe_dbxjoy uut(
    .rst            ( rst        ),
    .clk            ( clk        ),
    .joystick_0_USB ( 16'h0      ),
    .joystick_1_USB ( 16'h0      ),
    .joystick_0     ( joystick_0 ),
    .joystick_1     ( joystick_1 ),
    .joy_raw        ( joy_raw    ),
    .user_osd       ( user_osd   ),
    .user_in        ( user_in    ),
    .user_out       ( user_out   )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

endmodule

////////////////////////////////////////////////////////////

module megadrive(
    input      [11:0] joy_in,
    input             sel,
    output reg [ 5:0] dbout
);

reg [1:0] st=2'd0;
reg       md6;

always @(negedge sel) begin
    st  <= st+1'd1;
    md6 <= st==2'd2;
end

always @(*) begin
    if( sel )
        dbout = md6 ? { ~joy_in[5:4], ~joy_in[11:8] } : ~joy_in[5:0];
    else
        dbout = md6 ? { ~joy_in[7:6], 4'b0 } : { ~joy_in[7:6], ~joy_in[3:2], 2'd00 };
end

endmodule

module neogeo(
    input             clk,
    input             loadb,
    input      [11:0] joy0_in,
    input      [11:0] joy1_in,
    output            dout
);

reg [23:0] latch;

assign dout = latch[0];

always @(posedge clk, negedge loadb) begin
    if( !loadb )
        latch <= ~{
            joy1_in[ 7:4],
            joy1_in[11:8],
            joy0_in[11:8],
            joy1_in[ 3:0],
            joy0_in[ 3:0],
            joy0_in[ 7:4]
        };
    else begin
        latch <= { 1'b1, latch[23:1] };
    end
end

endmodule
