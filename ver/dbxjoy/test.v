`timescale 1ns / 1ps

module test;

reg  rst, clk;
wire [15:0] joystick_0, joystick_1;
wire [ 5:0] raw_joy;
wire [ 7:0] user_in;
wire        user_osd;
wire [ 7:0] user_out;
reg  [11:0] joy0_in, joy1_in;
wire [ 5:0] md_out;
wire        neo_out;
wire [ 1:0] start, coin;
reg         hs;

integer k=0, hs_cnt = 0;

//`ifdef MD
    assign {user_in[6],user_in[3],user_in[5],user_in[7],user_in[1],user_in[2]} = md_out;
//`else
//    assign user_in[5] = neo_out;
//    assign user_in[7:6] = 2'b11;
//    assign user_in[4:0] = user_out[4:0];
//`endif

initial begin
    rst = 1;
    #100 rst = 0;
end


initial begin
    clk = 0;
    forever #10.4 clk = ~clk;
end

always @(posedge clk) begin
    hs_cnt = hs_cnt==3076 ? 0 : hs_cnt+1;
    hs <= hs_cnt==0;
end

always @(posedge clk) begin
    k <= k+1;
    if( k[17:0]==0 ) begin
        joy0_in <= 12'd0;
        joy0_in[($random%8)+4]<=1;
        joy0_in[$random%4]<=1;
        joy1_in <= 12'd0;
        joy1_in[($random%8)+4]<=1;
        joy1_in[$random%4]<=1;
    end
    if( k[21] ) $finish;
end

split_md md_joy(
    .hs     ( hs          ),
    .joy0_in( joy0_in     ),
    .joy1_in( joy1_in     ),
    .sel    ( user_out[0] ),
    .split  ( user_out[4] ),
    .dbout  ( md_out      )
);

neogeo neo_joy(
    .clk        ( user_out[1] ),
    .loadb      ( user_out[0] ),
    .joy0_in    ( joy0_in     ),
    .joy1_in    ( joy1_in     ),
    .dout       ( neo_out     )
);

jtframe_dbxjoy uut(
    .rst      ( rst        ),
    .clk      ( clk        ),
    .hs       ( hs         ),

    .usb_joy0 ( 16'h0      ),
    .usb_joy1 ( 16'h0      ),

    .mix_joy0 ( joystick_0 ),
    .mix_joy1 ( joystick_1 ),
    .raw_joy  ( raw_joy    ),

    .start    ( start      ),
    .coin     ( coin       ),

    .user_osd ( user_osd   ),
    .user_in  ( user_in    ),
    .user_out ( user_out   )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

endmodule

////////////////////////////////////////////////////////////
module split_md(
    input         hs,
    input  [11:0] joy0_in,
    input  [11:0] joy1_in,
    input         sel,
    input         split,
    output [ 5:0] dbout
);

wire [5:0] db0, db1;

megadrive u_joy0(
    .hs     ( hs      ),
    .joy_in ( joy0_in ),
    .sel    ( sel     ),
    .dbout  ( db0     )
);

megadrive u_joy1(
    .hs     ( hs      ),
    .joy_in ( joy1_in ),
    .sel    ( sel     ),
    .dbout  ( db1     )
);

assign dbout = split ? db1 : db0;

endmodule

module megadrive(
    input      [11:0] joy_in,
    input             sel,
    input             hs,
    output reg [ 5:0] dbout
);

reg  [2:0] st  = 3'd0;
reg  [4:0] lock=5'd0;
reg        locked = 0;
reg        last_lin;

wire       lock_in = &st;

always @(negedge sel or posedge sel) begin
    if( !locked ) st <= st+1'd1 ;
end

always @(posedge hs) begin
    last_lin <= lock_in;
    if( lock_in && !last_lin ) begin
        locked <= 1;
        lock   <= 5'd0;
    end else if( locked ) begin
        lock <= lock+1;
        if( lock==5'd24 )
            locked <= 0;
    end
end

always @(*) begin
    case( st )
        default: dbout = ~6'd0;
        3'd2: dbout = { ~joy_in[7:6], 4'b1100 };
        3'd3: dbout = ~joy_in[5:0];
        3'd4: dbout = 6'b11_0000;
        3'd5: dbout = { 2'b11, ~joy_in[11:8] };
    endcase
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
