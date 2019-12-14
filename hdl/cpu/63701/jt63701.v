/******************************************************
    HD63701V0(Mode6) Compatible Processor Core
              Written by Tsuyoshi HASEGAWA 2013-14

    Modified by Jose Tejada to accept programming the PROM

*******************************************************/
module jt63701
(
    input         CLKx2,  // XTAL/EXTAL (200K~2.0MHz)

    input         RST,    // RES
    input         NMI,    // NMI
    input         IRQ,    // IRQ1

    output        WR,     // CS2. High for writting
    output    [15:0]  AD,   //  AS ? {PO4,PO3}
    output    [7:0] DO,   // ~AS ? {PO3}
    input     [7:0] DI,   //       {PI3}

    input     [7:0] PI1,    // Port1 IN
    output    [7:0] PO1,    //      OUT

    input     [4:0] PI2,    // Port2 IN
    output    [4:0] PO2,    //      OUT

    input     [7:0] PI6,    // Port6 IN
    output    [7:0] PO6,    //      OUT
    // PROM
    // PROM programming
    input    [13:0] prog_addr,
    input    [ 7:0] prom_din,
    input           prom_we,
    // for DEBUG
    output      [6:0] phase
);

`ifndef JT63701_SIMFILE
`define JT63701_SIMFILE
`endif

// Built-In Instruction ROM
wire en_birom = (AD[15:14]==4'b11);     // $C000-$FFFF
wire [7:0] biromd;

jtframe_prom #(.aw(14) `JT63701_SIMFILE) u_prom(
    .clk    ( CLKx2         ),
    .cen    ( 1'b1          ),
    .data   ( prom_din      ),
    .rd_addr( AD[13:0]      ),
    .wr_addr( prog_addr     ),
    .we     ( prom_we       ),
    .q      ( biromd        )
);

// Built-In WorkRAM
parameter BIRAM_START = 16'h40;
parameter BIRAM_END   = 16'h13F;
wire        en_biram = AD>=BIRAM_START && AD<=BIRAM_END;
wire [7:0]  biramd;
wire        biram_we = en_biram & WR;
// HD63701_BIRAM biram( CLKx2, AD, WR, DO, en_biram, biramd );

jtframe_ram #(.aw(8)) u_biram( // built-in RAM
    .clk    ( CLKx2       ),
    .cen    ( 1'b1        ),
    .data   ( DO          ),
    .addr   ( AD[7:0]     ),
    .we     ( biram_we    ),
    .q      ( biramd      )
);


// Built-In I/O Ports
wire      en_biio;
wire [7:0] biiod;
HD63701_IOPort iopt(
    .mcu_rst    ( RST       ),
    .mcu_clx2   ( CLKx2     ),
    .mcu_ad     ( AD        ),
    .mcu_wr     ( WR        ),
    .mcu_do     ( DO        ),
    .en_io      ( en_biio   ),
    .iod        ( biiod     ),
    .PI1        ( PI1       ),
    .PI2        ( PI2       ),
    .PI6        ( PI6       ),
    .PO1        ( PO1       ),
    .PO2        ( PO2       ),
    .PO6        ( PO6       )
);

// Built-In Timer
wire      irq2;
wire [3:0] irq2v;
wire      en_bitim;
wire [7:0] bitimd;
HD63701_Timer timer( RST, CLKx2, AD, WR, DO, irq2, irq2v, en_bitim, bitimd );


// Built-In Devices Data Selector
wire [7:0] biddi;
HD63701_BIDSEL bidsel
(
  biddi,
  en_birom, biromd,
  en_biram, biramd,
  en_biio , biiod, 
  en_bitim, bitimd,
  DI
);

// Processor Core
HD63701_Core core
(
  .CLKx2(CLKx2),.RST(RST),
  .NMI(NMI),.IRQ(IRQ),.IRQ2(irq2),.IRQ2V(irq2v),
  .RW(WR),.AD(AD),.DO(DO),.DI(biddi),
  .PH(phase[5:0])
);
assign phase[6] = irq2;

endmodule


module HD63701_BIDSEL(
  output [7:0] o,

  input e0, input [7:0] d0,
  input e1, input [7:0] d1,
  input e2, input [7:0] d2,
  input e3, input [7:0] d3,

  input [7:0] dx
);

assign o =  e0 ? d0 :
        e1 ? d1 :
        e2 ? d2 :
        e3 ? d3 :
        dx;

endmodule

/*
module HD63701_BIRAM(
  input             mcu_clx2,
  input      [15:0] mcu_ad,
  input             mcu_wr,
  input      [ 7:0] mcu_do,
  output            en_biram,
  output reg [ 7:0] biramd
);

assign en_biram = (mcu_ad[15: 7]==9'b1);  // $0080-$00FF
wire [6:0] biad = mcu_ad[6:0];

reg [7:0] bimem[0:127];
always @( posedge mcu_clx2 ) begin
  if (en_biram & mcu_wr) bimem[biad] <= mcu_do;
  else biramd <= bimem[biad];
end

endmodule
*/

module HD63701_IOPort (
    input              mcu_rst,
    input              mcu_clx2,
    input       [15:0] mcu_ad,
    input              mcu_wr,
    input        [7:0] mcu_do,

    output             en_io,
    output reg   [7:0] iod,

    input        [7:0] PI1,
    input        [4:0] PI2,
    input        [7:0] PI6,

    output reg   [7:0] PO1,
    output reg   [4:0] PO2,
    output reg   [7:0] PO6
);

always @( posedge mcu_clx2 or posedge mcu_rst ) begin
  if (mcu_rst) begin
    PO1 <= 8'hFF;
    PO2 <= 5'h1F;
    PO6 <= 8'hFF;
  end
  else begin
    if (mcu_wr) begin
        case( mcu_ad )
            16'h02: PO1 <= mcu_do;
            16'h03: PO2 <= mcu_do[4:0];
            16'h17: PO6 <= mcu_do;
        endcase
    end
  end
end

assign en_io = (mcu_ad==16'h2)|(mcu_ad==16'h3)|(mcu_ad==16'h17);

always @(*) begin
    case( mcu_ad[4:0] )
        5'h02: iod = PI1;
        5'h03: iod = {3'b111,PI2};
        5'h17: iod = PI6;
    endcase
end

endmodule


module HD63701_Timer(
    input           mcu_rst,
    input           mcu_clx2,
    input    [15:0] mcu_ad,
    input           mcu_wr,
    input    [ 7:0] mcu_do,

    output          mcu_irq2,
    output   [ 3:0] mcu_irq2v,

    output          en_timer,
    output   [ 7:0] timerd
);

reg        oci, oce;
reg [15:0] ocr, icr;
reg [16:0] frc;
reg [ 7:0] frt;
reg [ 7:0] rmc, rg5;

always @( posedge mcu_clx2 or posedge mcu_rst ) begin
    if (mcu_rst) begin
        oce <= 0;
        ocr <= 16'hFFFF;
        icr <= 16'hFFFF;
        frc <= 0;
        frt <= 0;
        rmc <= 8'h40;
        rg5 <= 0;
    end else begin
        frc <= frc+1;
        if (mcu_wr) begin
            case (mcu_ad)
                16'h05: rg5 <= mcu_do;
                16'h08: oce <= mcu_do[3];
                16'h09: frt <= mcu_do;
                16'h0A: frc <= {frt,mcu_do,1'h0};
                16'h0B: ocr[15:8] <= mcu_do;
                16'h0C: ocr[ 7:0] <= mcu_do;
                16'h0D: icr[15:8] <= mcu_do;
                16'h0E: icr[ 7:0] <= mcu_do;
                16'h14: rmc <= {mcu_do[7:6],6'h0};
                default:;
            endcase
        end
    end
end

always @( negedge mcu_clx2 or posedge mcu_rst ) begin
    if (mcu_rst) begin
        oci <= 0;
    end else begin
        case (mcu_ad)
            16'h0B: oci <= 0;
            16'h0C: oci <= 0;
            default: if (frc[16:1]==ocr) oci <= 1'b1;
        endcase
    end
end

assign mcu_irq2  = oci & oce;
assign mcu_irq2v = 4'h4;

assign en_timer = (mcu_ad==16'h05)|((mcu_ad>=16'h8)&(mcu_ad<=16'hE))|(mcu_ad==16'h14);

assign   timerd = (mcu_ad==16'h05) ? rg5 :
            (mcu_ad==16'h08) ? {1'b0,oci,2'b10,oce,3'b000}:
            (mcu_ad==16'h09) ? frc[16:9] :
            (mcu_ad==16'h0A) ? frc[ 8:1] :
            (mcu_ad==16'h0B) ? ocr[15:8] :
            (mcu_ad==16'h0C) ? ocr[ 7:0] :
            (mcu_ad==16'h0D) ? icr[15:8] :
            (mcu_ad==16'h0E) ? icr[ 7:0] :
            (mcu_ad==16'h14) ? rmc :
            8'h0;

endmodule

