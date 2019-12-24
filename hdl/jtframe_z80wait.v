module jtframe_z80wait #(parameter devcnt=2)(
    input       rst_n,
    input       clk,
    input       cen_in,
    output reg  cen_out,
    output reg  gate,
    // manage access to shared memory
    input  [devcnt-1:0] dev_busy,
    // manage access to ROM data from SDRAM
    input       rom_cs,
    input       rom_ok
);

/////////////////////////////////////////////////////////////////
// wait_n generation
reg last_rom_cs, last_chwait;
wire rom_cs_posedge = !last_rom_cs && rom_cs;

wire anydev_busy = |dev_busy;
wire bad_rom = rom_cs && !rom_ok;

reg waitn;

always @(negedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        cen_out     <= 1'b1;
        last_rom_cs <= 1'b0;
        gate        <= 1'b1;
    end else begin
        last_rom_cs <= rom_cs;
        if(rom_cs_posedge) 
            waitn<=1'b0;
        else if(rom_ok||!rom_cs) waitn <= 1'b1;
        cen_out <= cen_in & waitn & ~anydev_busy;
        gate    <= waitn & ~anydev_busy;
    end
end

endmodule // jtframe_z80wait