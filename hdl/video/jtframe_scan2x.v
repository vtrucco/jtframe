`timescale 1ns/1ps

module jtframe_scan2x #(parameter DW=12, HLEN=256)(
    input       rst_n,
    input       clk,
    input       base_cen,
    input       basex2_cen,
    input       [DW-1:0]    base_pxl,
    input       HS,

    output  reg [DW-1:0]    x2_pxl,
    output  reg x2_HS
);

localparam AW=HLEN<=256 ? 8 : (HLEN<=512 ? 9:10 );

reg [DW-1:0] mem0[0:HLEN-1];
reg [DW-1:0] mem1[0:HLEN-1];
reg oddline;
reg [AW-1:0] wraddr, rdaddr, hscnt0, hscnt1;
reg last_HS;

always @(posedge clk) last_HS <= HS;

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

always @(posedge clk or negedge rst_n)
    if( !rst_n ) begin
        x2_HS <= 1'b0;
    end else begin
        if( HS  && !last_HS ) hscnt1 <= wraddr;
        if( !HS &&  last_HS ) hscnt0 <= wraddr;
        if( rdaddr == hscnt0 ) x2_HS <= 1'b0;
        if( rdaddr == hscnt1 ) x2_HS <= 1'b1;
    end

endmodule // jtframe_scan2x