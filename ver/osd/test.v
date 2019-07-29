module test;

reg clk;

initial begin
	clk = 0;
	forever #10 clk = ~clk;
end

wire [1:0] rotate = 2'b00;
wire [7:0] r,g,b;
wire de_out, osd_status;

osd dut(
	.clk_sys	( clk	     ),
	.io_osd	    ( 1'b0       ),
	.io_strobe  ( 1'b0       ),
	.io_din		( 16'd0      ),
	.rotate     ( rotate     ),
	.din		( 24'd0      ),
	.dout		( {r,g,b}    ),
	.de_in		( 1'b1       ),
	.de_out     ( de_out     ),
	.osd_status ( osd_status )
);

initial begin
    $dumpfile("test.lxt");	
	$dumpvars;	
	#1000_000 $finish;
end

endmodule