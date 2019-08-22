module test;

reg clk;

initial begin
	clk = 0;
	forever #10 clk = ~clk;
end

wire [1:0] rotate = 2'b00;
wire [7:0] r,g,b;
wire de_out, osd_status;

reg io_osd, io_strobe;
reg [15:0] io_din;

osd dut(
	.clk_sys	( clk	     ),
	.io_osd	    ( io_osd     ),
	.io_strobe  ( io_strobe  ),
	.io_din		( io_din     ),
	.rotate     ( rotate     ),

	.clk_video	( clk      	 ),
	.din		( 24'd0      ),
	.dout		( {r,g,b}    ),
	.de_in		( 1'b1       ),
	.de_out     ( de_out     ),
	.osd_status ( osd_status )
);

initial begin
    $dumpfile("test.lxt");	
	$dumpvars;	
	#100_000 $finish;
end

initial begin
	io_osd    = 1'b0;
	io_strobe = 1'b0;
	io_din    = 16'd0;
	#100;
	io_osd    = 1'b1;
	io_din    = 16'h41;
	#40;
	io_strobe = 1'b1;
	#40;
	io_strobe = 1'b0;
	io_osd    = 1'b0;
end

endmodule