module jt7400( // ref: 74??00
    input       in1,  // pin: 1
    input       in2,  // pin: 2
    output      out3, // pin: 3
    input       in4,  // pin: 4
    input       in5,  // pin: 5
    output      out6, // pin: 6
    input       in9,  // pin: 9
    input       in10, // pin: 10
    output      out8, // pin: 8
    input       in12, // pin: 12
    input       in13, // pin: 13
    output      out11, // pin: 11
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign out3  = ~(in1 &in2 );
assign out6  = ~(in4 &in5 );
assign out8  = ~(in10&in9 );
assign out11 = ~(in12&in13);

endmodule

//////// Quad or gate
module jt7432( // ref: 74??32
    input       in1,  // pin: 1
    input       in2,  // pin: 2
    output      out3, // pin: 3
    input       in4,  // pin: 4
    input       in5,  // pin: 5
    output      out6, // pin: 6
    input       in9,  // pin: 9
    input       in10, // pin: 10
    output      out8, // pin: 8
    input       in12, // pin: 12
    input       in13, // pin: 13
    output      out11, // pin: 11
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign out3  = in1 |in2;
assign out6  = in4 |in5;
assign out8  = in10|in9;
assign out11 = in12|in13;

endmodule

module jt7437( // ref: 74??37
    input       in1,  // pin: 1
    input       in2,  // pin: 2
    output      out3, // pin: 3
    input       in4,  // pin: 4
    input       in5,  // pin: 5
    output      out6, // pin: 6
    input       in9,  // pin: 9
    input       in10, // pin: 10
    output      out8, // pin: 8
    input       in12, // pin: 12
    input       in13, // pin: 13
    output      out11, // pin: 11
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign out3  = ~(in1 &in2 );
assign out6  = ~(in4 &in5 );
assign out8  = ~(in10&in9 );
assign out11 = ~(in12&in13);

endmodule

module jt7402( // ref: 74??02
    output      out1, // pin: 1
    input       in2,  // pin: 2
    input       in3,  // pin: 3
    output      out4, // pin: 4
    input       in5,  // pin: 5
    input       in6,  // pin: 6
    input       in9,  // pin: 9
    input       in8,  // pin: 10
    output      out10,// pin: 8
    input       in12, // pin: 12
    input       in11, // pin: 13
    output      out13, // pin: 11
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign out1 = ~( in2| in3 );
assign out4 = ~( in5| in6 );
assign out10= ~( in9| in8 );
assign out13= ~(in12| in11);

endmodule

module jt7404( // ref: 74??04
    input       in1,   // pin: 1
    output      out2,  // pin: 2
    input       in3,   // pin: 3
    output      out4,  // pin: 4
    input       in5,   // pin: 5
    output      out6,  // pin: 6
    input       in9,   // pin: 9
    output      out8,  // pin: 8
    input       in11,  // pin: 11
    output      out10, // pin: 10
    input       in13,  // pin: 13
    output      out12, // pin: 12
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign out2  = ~in1;
assign out4  = ~in3;
assign out6  = ~in5;
assign out8  = ~in9;
assign out10 = ~in11;
assign out12 = ~in13;

endmodule


// synchronous presettable 4-bit binary counter, asynchronous clear
module jt74161( // ref: 74??161
    input            cet,   // pin: 10
    input            cep,   // pin: 7
    input            ld_b,  // pin: 9
    input            clk,   // pin: 2
    input            cl_b,  // pin: 1
    input      [3:0] d,     // pin: 6,5,4,3
    output reg [3:0] q,     // pin: 11,12,13,14
    output           ca,    // pin: 15
    input            VDD,   // pin: 16
    input            VSS    // pin: 8
 );

    assign ca = &{q, cet};

    initial q=4'd0;

    always @(posedge clk or negedge cl_b)
        if( !cl_b )
            q <= 4'd0;
        else begin
            if(!ld_b) q <= d;
            else if( cep&&cet ) q <= q+4'd1;
        end

endmodule // jt74161

// synchronous presettable 4-bit binary counter, synchronous clear
module jt74163(
    input cet,
    input cep,
    input ld_b,
    input clk,
    input cl_b,
    input [3:0] d,
    output reg [3:0] q,
    output ca
 );

    assign ca = &{q, cet};

    initial q=4'd0;

    always @(posedge clk)
        if( !cl_b )
            q <= 4'd0;
        else begin
            if(!ld_b) q <= d;
            else if( cep&&cet ) q <= q+4'd1;
        end

endmodule // jt74163

// Dual D-type flip-flop with set and reset; positive edge-trigger
module jt7474(  // ref: 74??74
    // first FF
    input      d1,      // pin: 2
    input      pr1_b,   // pin: 4
    input      cl1_b,   // pin: 1
    input      clk1,    // pin: 3
    output reg q1,      // pin: 5
    output     q1_b,    // pin: 6
    // second FF
    input      d2,      // pin: 12
    input      pr2_b,   // pin: 10
    input      cl2_b,   // pin: 13
    input      clk2,    // pin: 11
    output reg q2,      // pin: 9
    output     q2_b,    // pin: 8
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
);

    assign q1_b = ~q1;
    assign q2_b = ~q2;

    initial begin
        q1=1'b0;
        q2=1'b0;
    end

    always @( posedge clk1 or negedge cl1_b or negedge pr1_b )
        if( !pr1_b ) q1<= 1'b1;
        else if(!cl1_b) q1 <= 1'b0;
        else q1 <= d1;

    always @( posedge clk2 or negedge cl2_b or negedge pr2_b )
        if( !pr2_b ) q2<= 1'b1;
        else if(!cl2_b) q2 <= 1'b0;
        else q2 <= d2;
endmodule

// 3-to-8 line decoder/demultiplexer; inverting
module jt74138( // ref: 74??138
    input        e1_b,  // pin: 4
    input        e2_b,	// pin: 5
    input        e3,    // pin: 6
    input  [2:0] a,     // pin: 3,2,1
    output [7:0] y_b,   // pin: 7,9,10,11,12,13,14,15
    input        VDD,   // pin: 16
    input        VSS    // pin: 8
);
    reg [7:0] yb_nodly;
    always @(*)
        if( e1_b || e2_b || !e3 )
            yb_nodly <= 8'hff;
        else yb_nodly = ~ ( 8'b1 << a );
    assign #2 y_b = yb_nodly;
endmodule

// Dual 2-to-4 line decoder/demultiplexer
module jt74139(
    input   en1_b,
    input       [1:0]       a1,
    output      [3:0]       y1_b,
    input   en2_b,
    input       [1:0]       a2,
    output      [3:0]       y2_b
);
    assign #2 y1_b = en1_b ? 4'hf : ~( (4'b1)<<a1 );
    assign #2 y2_b = en2_b ? 4'hf : ~( (4'b1)<<a2 );
endmodule

module jt74112(
    input  pr_b,
    input  cl_b,
    input  clk_b,
    input  j,
    input  k,
    output reg q,
    output q_b
);

    assign q_b = ~q;

    initial q=1'b0;

    always @( negedge clk_b or negedge pr_b or negedge cl_b )
        if( !pr_b ) q <= 1'b1;
        else if( !cl_b ) q <= 1'b0;
        else if( !clk_b )
            case( {j,k} )
                2'b01: q<=1'b0;
                2'b10: q<=1'b1;
                2'b11: q<=~q;
            endcase // {j,k}

endmodule

// Octal bus transceiver; 3-state
module jt74245(
    inout [7:0] a,
    inout [7:0] b,
    input dir,
    input en_b
);

    assign #2 a = en_b || dir  ? 8'hzz : b;
    assign #2 b = en_b || !dir ? 8'hzz : a;

endmodule

// Octal D-type flip-flop with reset; positive-edge trigger
module jt74233(
    input [7:0] d,
    output reg [7:0] q,
    input cl_b, // CLEAR, reset
    input clk
);
    initial q=8'd0;
    always @(posedge clk or negedge cl_b)
        if( !cl_b ) q<=8'h0;
        else q<= d;

endmodule

// Hex D-type flip-flop with reset; positive-edge trigger
module jt74174( // ref: 74xx174
    input      [5:0] d,  // pin: 14,13,11,6,4,3
    output reg [5:0] q,  // pin: 15,12,10,7,5,2
    input         cl_b,  // pin: 9
    input         clk    // pin: 1
);
    initial q=6'd0;
    always @(posedge clk or negedge cl_b)
        if( !cl_b ) q<=6'h0;
        else q<= d;

endmodule

module jt74365( // ref: 74??365
    input  [5:0] A,     // pin: 2,4,6,14,12,10
    output [5:0] Y,     // pin: 3,5,7,13,11,9
    input        oe1_b, // pin: 1
    input        oe2_b, // pin: 15
    input        VDD,   // pin: 16
    input        VSS    // pin: 8
);
    assign #2 Y = (!oe1_b && !oe2_b) ? A : 6'bzz_zzzz;
endmodule

module jt74367( // ref: 74??367
    input  [5:0] A,     // pin: 14,12,10,6,4,2
    output [5:0] Y,     // pin: 13,11, 9,7,5,3
    input        oe1_b, // pin: 1
    input        oe2_b, // pin: 15
    input        VDD,   // pin: 16
    input        VSS    // pin: 8
);
    assign #2 Y[3:0] = !oe1_b ? A[3:0] : 4'hz;
    assign #2 Y[5:4] = !oe2_b ? A[5:4] : 2'hz;
endmodule

// 4-bit bidirectional universal shift register
module jt74194(
    input [3:0] D,
    input [1:0] S,
    input clk,
    input cl_b,
    input R,    // right
    input L,    // left
    output reg [3:0] Q
);
    // reg clk2;
    // always @(clk)
    //  clk2 = #1 clk;

    always @(posedge clk)
        if( !cl_b )
            Q <= 4'd0;
        else case( S )
            2'b10: Q <= { L, Q[3:1] };
            2'b01: Q <= { Q[2:0], R };
            2'b11: Q <= D;
        endcase
endmodule

module jt74157(
    input   sel,
    input   st_l,
    input   [3:0] A,
    input   [3:0] B,
    output  [3:0] Y
);
    reg [3:0] y_nodly;
    assign #2 Y = y_nodly;
    always @(*)
        if( st_l ) y_nodly = 4'd0;
        else y_nodly = sel ? B : A;

endmodule

// Octal D-type flip-flop with reset; positive-edge trigger
module jt74273(
    input   [7:0] d,
    input   clk,
    input   cl_b,
    output  reg [7:0] q
);

    always @(posedge clk or negedge cl_b)
        if(!cl_b)
            q <= 8'd0;
        else if(clk) q<=d;

endmodule

// 4-bit binary full adder with fast carry
module jt74283(
    input [3:0] a,
    input [3:0] b,
    input       cin,
    output  [3:0] s,
    output  cout
);
    assign #2 {cout,s} = a+b+cin;

endmodule

// Quad 2-input multiplexer; 3-state
module jt74257(
    input sel,
    input en_b,
    input [3:0] a,
    input [3:0] b,
    output [3:0] y
);

reg [3:0] y_nodly;
assign #2 y = y_nodly;

always @(*)
    if( !en_b )
        y_nodly = sel ? b : a;
    else
        y_nodly = 4'hz;

endmodule

// 8-bit addressable latch
module jt74259(
    input       D,
    input [2:0] A,
    input       LE_b,
    input       MR_b,
    output reg [7:0]    Q
);

initial Q=8'd0;

always @(*)
    if(!MR_b) Q=8'd0;
        else if(!LE_b) Q[A] <= D;

endmodule

///////////////////////////////////////////////////////7
// Non 74-series cells

// 5501 RAM. USed in Popeye
module RAM_5501( // ref: RAM_5501
    input  [7:0] A, // pin: 7,6,5,21,1,2,3,4
    input  [3:0] D, // pin: 15,13,11,9
    output [3:0] Q, // pin: 16,14,12,10
    input      WEn  // pin: 20
);

reg [3:0] mem [0:255];

always @(negedge WEn) begin
    mem[A] <= D;
end

always @(A,WEn) begin
    Q <= mem[A];
end

endmodule
/////////////////
module RAM_7063( // ref: RAM_7063
    input [5:0] A, // pin: 3,2,1,27,26,25
    input [8:0] I, // pin: 12,11,10,9,8,7,6,5,4,3,2,1,0
    inout [8:0] O, // pin: 16,17,18,19,20,21,22,23,24
    input WEn, // pin: 13
    input CEn  // pin: 15
);

reg [8:0] pre;
reg [8:0] mem[0:63];

assign O = CEn ? 9'hzzz : pre;

always @(nedgedge WEn) mem[A] <= I;
always @(A,WEn) pre <= mem[A];

endmodule
/////////////////
module rpullup( // ref: rpullup
    inout x // pin: 1
);

pullup pu(x);

endmodule