module jtframe_z80wait #(parameter devcnt=2)(
    input       rst_n,
    input       clk,
    input       cpu_cen,
    // manage access to shared memory
    input  [devcnt-1:0] dev_cs,
    input  [devcnt-1:0] dev_busy,
    // manage access to ROM data from SDRAM
    input       rom_cs,
    input       rom_ok,

    output reg  wait_n
);

/////////////////////////////////////////////////////////////////
// wait_n generation
reg last_rom_cs, last_chwait;
wire rom_cs_posedge = !last_rom_cs && rom_cs;

reg [devcnt-1:0] dev_free, dev_clr;
reg rom_free, rom_clr;


always @(*) begin
    dev_clr = ~dev_free  | (~dev_busy & dev_free);
    rom_clr = ~rom_free  | ( rom_ok   & rom_free);
end

wire [devcnt-1:0] dev_req = dev_cs & dev_busy;
wire anydev_req = |dev_req;

always @(posedge clk or negedge rst_n)
    if( !rst_n ) begin
        wait_n   <= 1'b1;
        dev_free <= {devcnt{1'b0}};
        rom_free <= 1'b0;
    end else begin
        last_rom_cs <= rom_cs;

        if( anydev_req || rom_cs_posedge  ) begin
            dev_free <= dev_req | dev_free;
            if( rom_cs_posedge ) rom_free  <= 1'b1;
            wait_n <= 1'b0;
        end else begin
            wait_n   <= &{dev_clr, rom_clr};
            rom_free <= !rom_clr;
            dev_free <= ~dev_clr;
        end
    end


endmodule // jtframe_z80wait