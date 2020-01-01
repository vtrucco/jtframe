/*  This file is part of JT_FRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 1-1-2020 */

module jtframe_rom_wait(
    input       rst_n,
    input       clk,
    input       cen_in,
    output  reg cen_out,
    output      gate,
    // manage access to ROM data from SDRAM
    input       rom_cs,
    input       rom_ok
);

/////////////////////////////////////////////////////////////////
// wait_n generation
reg last_rom_cs;
wire rom_cs_posedge = !last_rom_cs && rom_cs;

reg       locked;
assign gate = !(rom_cs_posedge || locked );
wire bus_ok = rom_ok||!rom_cs;


always @(posedge clk)
    cen_out <= cen_in & gate;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        last_rom_cs <= 1'b1;
        locked      <= 1'b0;
    end else begin
        last_rom_cs <= rom_cs;
        if(rom_cs_posedge ) begin
            locked  <= 1'b1;
        end
        else if( bus_ok ) begin
            locked <= 1'b0;
        end
    end
end

endmodule

module jtframe_dual_wait #(parameter devcnt=2)(
    input       rst_n,
    input       clk,
    input  [1:0]     cen_in,
    output reg [1:0] cen_out,
    output           gate,
    // manage access to shared memory
    input  [devcnt-1:0] dev_busy,
    // manage access to ROM data from SDRAM
    input       rom_cs,
    input       rom_ok
);

/////////////////////////////////////////////////////////////////
// wait_n generation
reg last_rom_cs;
wire rom_cs_posedge = !last_rom_cs && rom_cs;

reg [1:0] mark, gated_at;
reg       locked, latched;
assign gate = !(rom_cs_posedge || dev_busy || locked || latched);
wire bus_ok = (rom_ok||!rom_cs) && !dev_busy;

always @(posedge clk, negedge rst_n) begin
    if( !rst_n ) begin
        gated_at <= 1'b0;
        latched  <= 1'b0;
    end else begin
        if(cen_in[0]) mark <= 2'b01;
        if(cen_in[1]) mark <= 2'b10;
        if(locked) begin
            gated_at <= mark;
            latched  <= 1'b1;
        end
        latched <= locked;
        if(bus_ok && !locked && latched) begin
            if( gated_at[0] & cen_in[1] ) latched <= 1'b0;
            if( gated_at[1] & cen_in[0] ) latched <= 1'b0;
        end
    end
end

always @(posedge clk)
    cen_out <= cen_in & {2{gate}};


always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        last_rom_cs <= 1'b1;
        locked      <= 1'b0;
    end else begin
        last_rom_cs <= rom_cs;
        if(rom_cs_posedge || dev_busy) begin
            locked  <= 1'b1;
        end
        else if( bus_ok ) begin
            locked <= 1'b0;
        end
    end
end

endmodule

module jtframe_z80wait #(parameter devcnt=2)(
    input       rst_n,
    input       clk,
    input       cen_in,
    output reg  cen_out,
    output      gate,
    // manage access to shared memory
    input  [devcnt-1:0] dev_busy,
    // manage access to ROM data from SDRAM
    input       rom_cs,
    input       rom_ok
);

/////////////////////////////////////////////////////////////////
// wait_n generation
reg last_rom_cs;
wire rom_cs_posedge = !last_rom_cs && rom_cs;

reg       locked;
assign gate = !(rom_cs_posedge || dev_busy || locked );
wire bus_ok = (rom_ok||!rom_cs) && !dev_busy;

always @(posedge clk)
    cen_out <= cen_in & gate;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        last_rom_cs <= 1'b1;
        locked      <= 1'b0;
    end else begin
        last_rom_cs <= rom_cs;
        if(rom_cs_posedge || dev_busy) begin
            locked  <= 1'b1;
        end
        else if( bus_ok ) begin
            locked <= 1'b0;
        end
    end
end


endmodule // jtframe_z80wait