`timescale 1ns/1ps

module jtframe_scan2x #(parameter DW=12, HLEN=256)(
    input       rst_n,
    input       clk,
    input       base_cen,
    input       basex2_cen,
    input       [DW-1:0]    base_pxl,
    output  reg [DW-1:0]    x2_pxl
);

localparam AW=HLEN<=256 ? 8 : (HLEN<=512 ? 9:10 );

reg [DW-1:0] mem0[0:HLEN-1];
reg [DW-1:0] mem1[0:HLEN-1];
reg oddline;
reg [AW-1:0] wraddr, rdaddr;

always@(posedge clk or negedge rst_n)
    if( !rst_n ) begin
        wraddr  <= {AW{1'b0}};
        rdaddr  <= {AW{1'b0}};
        oddline <= 1'b0;
    end else
    if( basex2_cen ) begin
        rdaddr <= rdaddr < (HLEN-1) ? (rdaddr+1) : 0;
        x2_pxl <= oddline ? mem0[rdaddr] : mem1[rdaddr];
        if( base_cen ) begin
            if( wraddr==HLEN-1 ) oddline <= ~oddline;
            wraddr <= wraddr < (HLEN-1) ? (wraddr+1) : 0;
            if( oddline )
                mem1[wraddr] <= base_pxl;
            else
                mem0[wraddr] <= base_pxl;
        end 
    end

endmodule // jtframe_scan2x