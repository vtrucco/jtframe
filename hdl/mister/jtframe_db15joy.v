//============================================================================
//  JTFRAME by Jose Tejada Gomez. Twitter: @topapate
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module jtframe_db15joy(
 input         rst,
 input         clk,
 input         cen,
 // control
 input         scan,
 // pins to IO port
 output reg    joy_clk,
 output reg    loadb,
 input         din,
 // data read (active high)
 output reg    hooked,      // high if a db15 controller has been detected
 output reg    sample,      // high strobe when new data is available
 output [11:0] joy0,
 output [11:0] joy1
);

reg         last_clk, last_but0;
reg  [23:0] joy_latch, shr;
reg  [ 4:0] cnt;

always @(posedge clk, posedge rst) begin
    if( rst )
        joy_clk <= 0;
    else begin
        if( !scan )
            joy_clk <= 0;
        else begin
            if( cen )
                joy_clk <= ~joy_clk;
        end
    end
end

assign {
        joy1[ 7:4], // basic buttons
        joy1[11:8], // extra buttons
        joy0[11:8], // extra buttons
        joy1[0],  // R
        joy1[1],  // L
        joy1[2],  // D
        joy1[3],  // U
        joy0[0],  // R
        joy0[1],  // L
        joy0[2],  // D
        joy0[3],  // U
        joy0[ 7:4]// basic buttons
    } = joy_latch;


always @(posedge clk, posedge rst) begin
    if( rst ) begin
        shr       <= ~24'd0;
        joy_latch <= ~24'd0;
        last_clk  <= 0;
        loadb     <= 0;
        cnt       <= 5'd0;
        hooked    <= 0;
        last_but0 <= 0;
    end else begin
        last_clk <= joy_clk;

        if( joy0[4] && !last_but0 )
            hooked<=1;

        if( !scan ) begin
            cnt      <= 5'd0;
            joy_clk  <= 1'd0;
            loadb    <= 1'd0;
            sample   <= 1'd0;
        end else begin
            sample   <= joy_clk && !last_clk && cnt==5'd25;
            loadb    <= 1;
            if( joy_clk & ~last_clk ) begin
                if( cnt==5'd0 ) begin
                    joy_latch <= shr;
                    last_but0 <= joy0[4];
                end
                loadb <= cnt!=5'd25;
                cnt   <= cnt==5'd25 ? 5'd0 : cnt+1'd1;
                shr   <= { ~din, shr[23:1] };
            end
        end
    end
end

endmodule