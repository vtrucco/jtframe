// A simple OSD implementation. Can be hooked up between a cores
// VGA output and the physical VGA pins

module osd
(
    input         clk_sys,

    input         io_osd,
    input         io_strobe,
    input  [15:0] io_din,

    input  [1:0]  rotate, //[0] - rotate [1] - left or right

    input         clk_video,
    input  [23:0] din,
    output [23:0] dout,
    input         de_in,
    output reg    de_out,
    output reg    osd_status
);

parameter  OSD_X_OFFSET = 12'd0;
parameter  OSD_Y_OFFSET = 12'd0;
parameter  OSD_COLOR    =  3'd4;

localparam OSD_WIDTH    = 12'd256;
localparam OSD_HEIGHT   = 12'd64;

reg        osd_enable;
(* ramstyle = "no_rw_check" *) reg  [7:0] osd_buffer[0:4095];

`ifdef SIMULATION
initial begin : clear_mem
    integer cnt=0;
    for( cnt=0; cnt<4096; cnt=cnt+1 ) osd_buffer[cnt]=8'd0;
end
`endif

reg        info = 0;
reg  [8:0] infoh;
reg  [8:0] infow;
reg [11:0] infox;
reg [21:0] infoy;
reg [21:0] hrheight;

//////////// SPI RX
reg        highres = 0;
always@(posedge clk_sys) begin : SPIRX
    reg [11:0] bcnt;
    reg  [7:0] cmd;
    reg        has_cmd;
    reg        old_strobe;

    hrheight <= info ? infoh : (OSD_HEIGHT<<highres);

    old_strobe <= io_strobe;

    if(~io_osd) begin
        bcnt <= 0;
        has_cmd <= 0;
        cmd <= 0;
        if(cmd[7:4] == 4) osd_enable <= cmd[0];
    end else begin
        if(~old_strobe & io_strobe) begin
            if(!has_cmd) begin
                has_cmd <= 1;
                cmd <= io_din[7:0];
                // command 0x40: OSDCMDENABLE, OSDCMDDISABLE
                if(io_din[7:4] == 4) begin
                    if(!io_din[0]) {osd_status,highres} <= 0;
                    else {osd_status,info} <= {~io_din[2],io_din[2]};
                    bcnt <= 0;
                end
                // command 0x20: OSDCMDWRITE
                if(io_din[7:4] == 2) begin
                    if(io_din[3]) highres <= 1;
                    bcnt <= {io_din[3:0], 8'h00};
                end
            end else begin
                // command 0x40: OSDCMDENABLE, OSDCMDDISABLE
                if(cmd[7:4] == 4) begin
                    if(bcnt == 0) infox <= io_din[11:0];
                    if(bcnt == 1) infoy <= io_din[11:0];
                    if(bcnt == 2) infow <= {io_din[5:0], 3'b000};
                    if(bcnt == 3) infoh <= {io_din[5:0], 3'b000};
                end

                // command 0x20: OSDCMDWRITE
                if(cmd[7:4] == 2) osd_buffer[bcnt] <= io_din[7:0];

                bcnt <= bcnt + 1'd1;
            end
        end
    end
end

// CE_CTRL
(* direct_enable *) reg ce_pix;
integer pxcnt = 0;
always @(negedge clk_video) begin : CE_CTRL
    integer pixsz, pixcnt;
    reg deD;

    pxcnt <= pxcnt + 1;
    deD <= de_in;

    pixcnt <= pixcnt + 1;
    if(pixcnt == pixsz) pixcnt <= 0;
    ce_pix <= !pixcnt;

    if(~deD && de_in) pxcnt <= 0;

    if(deD && ~de_in) begin
        pixsz  <= (((pxcnt+1'b1) >> 9) > 1) ? (((pxcnt+1'b1) >> 9) - 1) : 0;
        pixcnt <= 0;
    end
end

reg [ 2:0] osd_de;
reg        osd_pixel;
reg [21:0] next_v_cnt;

reg v_cnt_below320, v_cnt_below640, v_cnt_below960;

reg [21:0] v_cnt;
reg [21:0] v_osd_start_320, v_osd_start_640, v_osd_start_960, v_osd_start_other;

reg [11:0] osd_buffer_addr;

`ifndef OSD_NOBCK
reg [7:0] bkg[8*256];

wire [7:0] back_byte = bkg[ osd_buffer_addr[11:1] ];
reg        back_pixel;
`else 
wire       back_pixel = 1'b1;
`endif

// pipeline the comparisons a bit
always @(posedge clk_video) if(ce_pix) begin
    v_cnt_below320 <= next_v_cnt < 320;
    v_cnt_below640 <= next_v_cnt < 640;
    v_cnt_below960 <= next_v_cnt < 960;
    v_osd_start_320   <= ((next_v_cnt-hrheight)>>1) + OSD_Y_OFFSET;
    v_osd_start_640   <= ((next_v_cnt-(hrheight<<1))>>1) + OSD_Y_OFFSET;
    v_osd_start_960   <= ((next_v_cnt-(hrheight + (hrheight<<1)))>>1) + OSD_Y_OFFSET;
    v_osd_start_other <= ((next_v_cnt-(hrheight<<2))>>1) + OSD_Y_OFFSET;
end

always @(posedge clk_video) begin : GEOMETRY
    reg        deD;
    reg  [1:0] osd_div;
    reg  [1:0] multiscan;
    reg  [7:0] osd_byte; 
    reg [23:0] h_cnt;
    reg [21:0] dsp_width;
    reg [21:0] osd_vcnt;
    reg [21:0] h_osd_start;
    reg [21:0] v_osd_start;
    reg [21:0] osd_hcnt;
    reg        osd_de1,osd_de2;
    reg  [1:0] osd_en;

    if(ce_pix) begin

        deD <= de_in;
        if(~&h_cnt) h_cnt <= h_cnt + 1'd1;

        if(~&osd_hcnt) osd_hcnt <= osd_hcnt + 1'd1;
        if (h_cnt == h_osd_start) begin
            osd_de[0] <= osd_en[1] && hrheight && (osd_vcnt < hrheight);
            osd_hcnt <= 0;
        end
        if (osd_hcnt+1 == (info ? infow : OSD_WIDTH)) osd_de[0] <= 0;

        // falling edge of de
        if(!de_in && deD) dsp_width <= h_cnt[21:0];

        // rising edge of de
        if(de_in && !deD) begin
            h_cnt <= 0;
            v_cnt <= next_v_cnt;
            next_v_cnt <= next_v_cnt+1'd1; 
            h_osd_start <= info ? infox : (((dsp_width - OSD_WIDTH)>>1) + OSD_X_OFFSET - 2'd2);

            if(h_cnt > {dsp_width, 2'b00}) begin
                v_cnt <= 0;
                next_v_cnt <= 'd1;

                osd_en <= (osd_en << 1) | osd_enable;
                if(~osd_enable) osd_en <= 0;

                if(v_cnt_below320) begin
                    multiscan <= 0;
                    v_osd_start <= info ? infoy : v_osd_start_320;
                end
                else if(v_cnt_below640) begin
                    multiscan <= 1;
                    v_osd_start <= info ? (infoy<<1) : v_osd_start_640;
                end
                else if(v_cnt_below960) begin
                    multiscan <= 2;
                    v_osd_start <= info ? (infoy + (infoy << 1)) : v_osd_start_960;
                end
                else begin
                    multiscan <= 3;
                    v_osd_start <= info ? (infoy<<2) : v_osd_start_other;
                end
            end

            osd_div <= osd_div + 1'd1;
            if(osd_div == multiscan) begin
                osd_div <= 0;
                if(~&osd_vcnt) osd_vcnt <= osd_vcnt + 1'd1;
            end
            if(v_osd_start == next_v_cnt) {osd_div, osd_vcnt} <= 0;
        end

        // pixels
        osd_buffer_addr <= rotate[0] ?
                    ({ osd_hcnt[7:4], osd_vcnt[7:0] } ^ { {4{~rotate[1]}}, {8{rotate[1]}} }) :
                    // no rotation
                    {osd_vcnt[6:3], osd_hcnt[7:0]};
        osd_byte  <= osd_buffer[osd_buffer_addr];
        osd_pixel <= osd_byte[ rotate[0] ?
                    ( osd_hcnt[3:1] ^ {4{~rotate[1]}} )
                    // no rotation
                    : osd_vcnt[2:0] ];
        `ifndef OSD_NOBCK
        back_pixel <= back_byte[ rotate[0]  ? 
                    (osd_hcnt[4:2] ^{3{~rotate[1]}}) :
                    // no rotation:
                    osd_vcnt[3:1]];
        `endif

        osd_de[2:1] <= osd_de[1:0];

    end
end

reg [23:0] rdout;
assign dout = rdout;

reg [23:0] osd_rdout, normal_rdout;
reg osd_mux;
reg de_dly;

always @(posedge clk_video) begin
    normal_rdout <= din;
    osd_rdout <= {{ {2{osd_pixel}}, {2{OSD_COLOR[2]&back_pixel}}, din[23:20]},// 23:16
                  { {2{osd_pixel}}, {2{OSD_COLOR[1]&back_pixel}}, din[15:10]},// 15:8
                  { {2{osd_pixel}}, {2{OSD_COLOR[0]&back_pixel}}, din[7:4]}}; //  7:0
    osd_mux <= ~osd_de[2];
    rdout  <= osd_mux ? normal_rdout : osd_rdout;
    de_dly <= de_in;
    de_out <= de_dly;
end

initial begin
bkg[   0]=8'h00; bkg[   1]=8'h00; bkg[   2]=8'h00; bkg[   3]=8'h00; bkg[   4]=8'h00; bkg[   5]=8'h00; bkg[   6]=8'h00; bkg[   7]=8'h00; bkg[   8]=8'h00; bkg[   9]=8'h00; bkg[  10]=8'h00; bkg[  11]=8'h00; bkg[  12]=8'h00; bkg[  13]=8'h00; bkg[  14]=8'h00; bkg[  15]=8'h00; 
bkg[  16]=8'h00; bkg[  17]=8'h00; bkg[  18]=8'h00; bkg[  19]=8'h00; bkg[  20]=8'h00; bkg[  21]=8'h00; bkg[  22]=8'h00; bkg[  23]=8'h00; bkg[  24]=8'h00; bkg[  25]=8'h00; bkg[  26]=8'h00; bkg[  27]=8'h00; bkg[  28]=8'h00; bkg[  29]=8'h00; bkg[  30]=8'h00; bkg[  31]=8'h00; 
bkg[  32]=8'h00; bkg[  33]=8'h00; bkg[  34]=8'h00; bkg[  35]=8'h00; bkg[  36]=8'h00; bkg[  37]=8'h00; bkg[  38]=8'h00; bkg[  39]=8'h00; bkg[  40]=8'h01; bkg[  41]=8'h01; bkg[  42]=8'h01; bkg[  43]=8'h01; bkg[  44]=8'h01; bkg[  45]=8'h01; bkg[  46]=8'h01; bkg[  47]=8'h01; 
bkg[  48]=8'h01; bkg[  49]=8'h01; bkg[  50]=8'h01; bkg[  51]=8'h01; bkg[  52]=8'h01; bkg[  53]=8'h01; bkg[  54]=8'h01; bkg[  55]=8'h01; bkg[  56]=8'h01; bkg[  57]=8'h01; bkg[  58]=8'h01; bkg[  59]=8'h01; bkg[  60]=8'h01; bkg[  61]=8'h01; bkg[  62]=8'h01; bkg[  63]=8'h01; 
bkg[  64]=8'h01; bkg[  65]=8'h01; bkg[  66]=8'h01; bkg[  67]=8'h01; bkg[  68]=8'h01; bkg[  69]=8'h01; bkg[  70]=8'h01; bkg[  71]=8'h01; bkg[  72]=8'h01; bkg[  73]=8'h01; bkg[  74]=8'h01; bkg[  75]=8'h01; bkg[  76]=8'h01; bkg[  77]=8'h01; bkg[  78]=8'h01; bkg[  79]=8'h01; 
bkg[  80]=8'h01; bkg[  81]=8'h01; bkg[  82]=8'h01; bkg[  83]=8'h01; bkg[  84]=8'h01; bkg[  85]=8'h01; bkg[  86]=8'h01; bkg[  87]=8'h01; bkg[  88]=8'h01; bkg[  89]=8'h01; bkg[  90]=8'h01; bkg[  91]=8'h01; bkg[  92]=8'h01; bkg[  93]=8'h01; bkg[  94]=8'h01; bkg[  95]=8'h01; 
bkg[  96]=8'h01; bkg[  97]=8'h01; bkg[  98]=8'h01; bkg[  99]=8'h01; bkg[ 100]=8'h01; bkg[ 101]=8'h01; bkg[ 102]=8'h01; bkg[ 103]=8'h01; bkg[ 104]=8'h01; bkg[ 105]=8'h01; bkg[ 106]=8'h01; bkg[ 107]=8'h01; bkg[ 108]=8'h01; bkg[ 109]=8'h01; bkg[ 110]=8'h01; bkg[ 111]=8'h01; 
bkg[ 112]=8'h01; bkg[ 113]=8'h01; bkg[ 114]=8'h01; bkg[ 115]=8'h01; bkg[ 116]=8'h01; bkg[ 117]=8'h01; bkg[ 118]=8'h01; bkg[ 119]=8'h01; bkg[ 120]=8'h01; bkg[ 121]=8'h01; bkg[ 122]=8'h01; bkg[ 123]=8'h01; bkg[ 124]=8'h01; bkg[ 125]=8'h01; bkg[ 126]=8'h01; bkg[ 127]=8'h01; 
bkg[ 128]=8'h01; bkg[ 129]=8'h01; bkg[ 130]=8'h01; bkg[ 131]=8'h01; bkg[ 132]=8'h01; bkg[ 133]=8'h01; bkg[ 134]=8'h01; bkg[ 135]=8'h01; bkg[ 136]=8'h01; bkg[ 137]=8'h01; bkg[ 138]=8'h01; bkg[ 139]=8'h01; bkg[ 140]=8'h01; bkg[ 141]=8'h01; bkg[ 142]=8'h01; bkg[ 143]=8'h01; 
bkg[ 144]=8'h01; bkg[ 145]=8'h01; bkg[ 146]=8'h01; bkg[ 147]=8'h01; bkg[ 148]=8'h01; bkg[ 149]=8'h01; bkg[ 150]=8'h01; bkg[ 151]=8'h01; bkg[ 152]=8'h01; bkg[ 153]=8'h01; bkg[ 154]=8'h01; bkg[ 155]=8'h01; bkg[ 156]=8'h01; bkg[ 157]=8'h01; bkg[ 158]=8'h01; bkg[ 159]=8'h01; 
bkg[ 160]=8'h01; bkg[ 161]=8'h01; bkg[ 162]=8'h01; bkg[ 163]=8'h01; bkg[ 164]=8'h01; bkg[ 165]=8'h01; bkg[ 166]=8'h01; bkg[ 167]=8'h01; bkg[ 168]=8'h01; bkg[ 169]=8'h01; bkg[ 170]=8'h01; bkg[ 171]=8'h01; bkg[ 172]=8'h01; bkg[ 173]=8'h01; bkg[ 174]=8'h01; bkg[ 175]=8'h01; 
bkg[ 176]=8'h01; bkg[ 177]=8'h01; bkg[ 178]=8'h01; bkg[ 179]=8'h01; bkg[ 180]=8'h01; bkg[ 181]=8'h01; bkg[ 182]=8'h01; bkg[ 183]=8'h01; bkg[ 184]=8'h01; bkg[ 185]=8'h01; bkg[ 186]=8'h01; bkg[ 187]=8'h01; bkg[ 188]=8'h01; bkg[ 189]=8'h01; bkg[ 190]=8'h01; bkg[ 191]=8'h01; 
bkg[ 192]=8'h01; bkg[ 193]=8'h01; bkg[ 194]=8'h01; bkg[ 195]=8'h01; bkg[ 196]=8'h01; bkg[ 197]=8'h01; bkg[ 198]=8'h01; bkg[ 199]=8'h01; bkg[ 200]=8'h01; bkg[ 201]=8'h01; bkg[ 202]=8'h01; bkg[ 203]=8'h01; bkg[ 204]=8'h01; bkg[ 205]=8'h01; bkg[ 206]=8'h01; bkg[ 207]=8'h01; 
bkg[ 208]=8'h01; bkg[ 209]=8'h01; bkg[ 210]=8'h01; bkg[ 211]=8'h01; bkg[ 212]=8'h01; bkg[ 213]=8'h01; bkg[ 214]=8'h01; bkg[ 215]=8'h01; bkg[ 216]=8'h01; bkg[ 217]=8'h01; bkg[ 218]=8'h01; bkg[ 219]=8'h01; bkg[ 220]=8'h01; bkg[ 221]=8'h01; bkg[ 222]=8'h01; bkg[ 223]=8'h01; 
bkg[ 224]=8'h01; bkg[ 225]=8'h01; bkg[ 226]=8'h01; bkg[ 227]=8'h01; bkg[ 228]=8'h01; bkg[ 229]=8'h01; bkg[ 230]=8'h01; bkg[ 231]=8'h01; bkg[ 232]=8'h01; bkg[ 233]=8'h01; bkg[ 234]=8'h01; bkg[ 235]=8'h01; bkg[ 236]=8'h01; bkg[ 237]=8'h01; bkg[ 238]=8'h01; bkg[ 239]=8'h01; 
bkg[ 240]=8'h01; bkg[ 241]=8'h01; bkg[ 242]=8'h01; bkg[ 243]=8'h01; bkg[ 244]=8'h01; bkg[ 245]=8'h01; bkg[ 246]=8'h01; bkg[ 247]=8'h01; bkg[ 248]=8'h01; bkg[ 249]=8'h01; bkg[ 250]=8'h01; bkg[ 251]=8'h01; bkg[ 252]=8'h01; bkg[ 253]=8'h01; bkg[ 254]=8'h01; bkg[ 255]=8'h01; 
bkg[ 256]=8'h00; bkg[ 257]=8'h00; bkg[ 258]=8'h00; bkg[ 259]=8'h00; bkg[ 260]=8'h00; bkg[ 261]=8'h00; bkg[ 262]=8'h00; bkg[ 263]=8'h00; bkg[ 264]=8'h00; bkg[ 265]=8'h00; bkg[ 266]=8'h00; bkg[ 267]=8'h00; bkg[ 268]=8'h00; bkg[ 269]=8'h00; bkg[ 270]=8'h00; bkg[ 271]=8'h00; 
bkg[ 272]=8'h00; bkg[ 273]=8'h00; bkg[ 274]=8'h00; bkg[ 275]=8'h00; bkg[ 276]=8'h00; bkg[ 277]=8'h00; bkg[ 278]=8'h00; bkg[ 279]=8'h00; bkg[ 280]=8'h00; bkg[ 281]=8'h00; bkg[ 282]=8'h00; bkg[ 283]=8'h00; bkg[ 284]=8'h00; bkg[ 285]=8'h00; bkg[ 286]=8'h00; bkg[ 287]=8'h00; 
bkg[ 288]=8'h00; bkg[ 289]=8'h00; bkg[ 290]=8'h00; bkg[ 291]=8'h00; bkg[ 292]=8'h00; bkg[ 293]=8'h00; bkg[ 294]=8'h00; bkg[ 295]=8'h00; bkg[ 296]=8'h01; bkg[ 297]=8'h01; bkg[ 298]=8'h01; bkg[ 299]=8'h01; bkg[ 300]=8'h01; bkg[ 301]=8'h01; bkg[ 302]=8'h01; bkg[ 303]=8'h01; 
bkg[ 304]=8'h01; bkg[ 305]=8'h01; bkg[ 306]=8'h01; bkg[ 307]=8'h01; bkg[ 308]=8'h01; bkg[ 309]=8'h01; bkg[ 310]=8'h01; bkg[ 311]=8'h01; bkg[ 312]=8'h01; bkg[ 313]=8'h01; bkg[ 314]=8'h01; bkg[ 315]=8'h01; bkg[ 316]=8'h01; bkg[ 317]=8'h01; bkg[ 318]=8'h01; bkg[ 319]=8'h01; 
bkg[ 320]=8'h01; bkg[ 321]=8'h01; bkg[ 322]=8'h01; bkg[ 323]=8'h01; bkg[ 324]=8'h01; bkg[ 325]=8'h01; bkg[ 326]=8'h01; bkg[ 327]=8'h01; bkg[ 328]=8'h01; bkg[ 329]=8'h01; bkg[ 330]=8'h01; bkg[ 331]=8'h01; bkg[ 332]=8'h01; bkg[ 333]=8'h01; bkg[ 334]=8'h01; bkg[ 335]=8'h01; 
bkg[ 336]=8'h01; bkg[ 337]=8'h01; bkg[ 338]=8'h01; bkg[ 339]=8'h01; bkg[ 340]=8'h01; bkg[ 341]=8'h01; bkg[ 342]=8'h01; bkg[ 343]=8'h01; bkg[ 344]=8'h01; bkg[ 345]=8'h01; bkg[ 346]=8'h01; bkg[ 347]=8'h01; bkg[ 348]=8'h01; bkg[ 349]=8'h01; bkg[ 350]=8'h01; bkg[ 351]=8'h01; 
bkg[ 352]=8'h01; bkg[ 353]=8'h01; bkg[ 354]=8'h01; bkg[ 355]=8'h01; bkg[ 356]=8'h01; bkg[ 357]=8'h01; bkg[ 358]=8'h01; bkg[ 359]=8'h01; bkg[ 360]=8'h01; bkg[ 361]=8'h01; bkg[ 362]=8'h01; bkg[ 363]=8'h01; bkg[ 364]=8'h01; bkg[ 365]=8'h01; bkg[ 366]=8'h01; bkg[ 367]=8'h01; 
bkg[ 368]=8'h01; bkg[ 369]=8'h01; bkg[ 370]=8'h01; bkg[ 371]=8'h01; bkg[ 372]=8'h01; bkg[ 373]=8'h01; bkg[ 374]=8'h01; bkg[ 375]=8'h01; bkg[ 376]=8'h01; bkg[ 377]=8'h01; bkg[ 378]=8'h01; bkg[ 379]=8'h01; bkg[ 380]=8'h01; bkg[ 381]=8'h01; bkg[ 382]=8'h01; bkg[ 383]=8'h01; 
bkg[ 384]=8'h01; bkg[ 385]=8'h01; bkg[ 386]=8'h01; bkg[ 387]=8'h01; bkg[ 388]=8'h01; bkg[ 389]=8'h01; bkg[ 390]=8'h01; bkg[ 391]=8'h01; bkg[ 392]=8'h01; bkg[ 393]=8'h01; bkg[ 394]=8'h01; bkg[ 395]=8'h01; bkg[ 396]=8'h01; bkg[ 397]=8'h01; bkg[ 398]=8'h01; bkg[ 399]=8'h01; 
bkg[ 400]=8'h01; bkg[ 401]=8'h01; bkg[ 402]=8'h01; bkg[ 403]=8'h01; bkg[ 404]=8'h01; bkg[ 405]=8'h01; bkg[ 406]=8'h01; bkg[ 407]=8'h01; bkg[ 408]=8'h01; bkg[ 409]=8'h01; bkg[ 410]=8'h01; bkg[ 411]=8'h01; bkg[ 412]=8'h01; bkg[ 413]=8'h01; bkg[ 414]=8'h01; bkg[ 415]=8'h01; 
bkg[ 416]=8'h01; bkg[ 417]=8'h01; bkg[ 418]=8'h01; bkg[ 419]=8'h01; bkg[ 420]=8'h01; bkg[ 421]=8'h01; bkg[ 422]=8'h01; bkg[ 423]=8'h01; bkg[ 424]=8'h01; bkg[ 425]=8'h01; bkg[ 426]=8'h01; bkg[ 427]=8'h01; bkg[ 428]=8'h01; bkg[ 429]=8'h01; bkg[ 430]=8'h01; bkg[ 431]=8'h01; 
bkg[ 432]=8'h01; bkg[ 433]=8'h01; bkg[ 434]=8'h01; bkg[ 435]=8'h01; bkg[ 436]=8'h01; bkg[ 437]=8'h01; bkg[ 438]=8'h01; bkg[ 439]=8'h01; bkg[ 440]=8'h01; bkg[ 441]=8'h01; bkg[ 442]=8'h01; bkg[ 443]=8'h01; bkg[ 444]=8'h01; bkg[ 445]=8'h01; bkg[ 446]=8'h01; bkg[ 447]=8'h01; 
bkg[ 448]=8'h01; bkg[ 449]=8'h01; bkg[ 450]=8'h01; bkg[ 451]=8'h01; bkg[ 452]=8'h01; bkg[ 453]=8'h01; bkg[ 454]=8'h01; bkg[ 455]=8'h01; bkg[ 456]=8'h01; bkg[ 457]=8'h01; bkg[ 458]=8'h01; bkg[ 459]=8'h01; bkg[ 460]=8'h01; bkg[ 461]=8'h01; bkg[ 462]=8'h01; bkg[ 463]=8'h01; 
bkg[ 464]=8'h01; bkg[ 465]=8'h01; bkg[ 466]=8'h01; bkg[ 467]=8'h01; bkg[ 468]=8'h01; bkg[ 469]=8'h01; bkg[ 470]=8'h01; bkg[ 471]=8'h01; bkg[ 472]=8'h01; bkg[ 473]=8'h01; bkg[ 474]=8'h01; bkg[ 475]=8'h01; bkg[ 476]=8'h01; bkg[ 477]=8'h01; bkg[ 478]=8'h01; bkg[ 479]=8'h01; 
bkg[ 480]=8'h01; bkg[ 481]=8'h01; bkg[ 482]=8'h01; bkg[ 483]=8'h01; bkg[ 484]=8'h01; bkg[ 485]=8'h01; bkg[ 486]=8'h01; bkg[ 487]=8'h01; bkg[ 488]=8'h01; bkg[ 489]=8'h01; bkg[ 490]=8'h01; bkg[ 491]=8'h01; bkg[ 492]=8'h01; bkg[ 493]=8'h01; bkg[ 494]=8'h01; bkg[ 495]=8'h01; 
bkg[ 496]=8'h01; bkg[ 497]=8'h01; bkg[ 498]=8'h01; bkg[ 499]=8'h01; bkg[ 500]=8'h01; bkg[ 501]=8'h01; bkg[ 502]=8'h01; bkg[ 503]=8'h01; bkg[ 504]=8'h01; bkg[ 505]=8'h01; bkg[ 506]=8'h01; bkg[ 507]=8'h01; bkg[ 508]=8'h01; bkg[ 509]=8'h01; bkg[ 510]=8'h01; bkg[ 511]=8'h01; 
bkg[ 512]=8'h00; bkg[ 513]=8'h00; bkg[ 514]=8'h00; bkg[ 515]=8'h00; bkg[ 516]=8'h00; bkg[ 517]=8'h00; bkg[ 518]=8'h00; bkg[ 519]=8'h00; bkg[ 520]=8'h00; bkg[ 521]=8'h00; bkg[ 522]=8'h00; bkg[ 523]=8'h00; bkg[ 524]=8'h00; bkg[ 525]=8'h00; bkg[ 526]=8'h00; bkg[ 527]=8'h00; 
bkg[ 528]=8'h00; bkg[ 529]=8'h00; bkg[ 530]=8'h00; bkg[ 531]=8'h00; bkg[ 532]=8'h00; bkg[ 533]=8'h00; bkg[ 534]=8'h00; bkg[ 535]=8'h00; bkg[ 536]=8'h00; bkg[ 537]=8'h00; bkg[ 538]=8'h00; bkg[ 539]=8'h00; bkg[ 540]=8'h00; bkg[ 541]=8'h00; bkg[ 542]=8'h00; bkg[ 543]=8'h00; 
bkg[ 544]=8'h00; bkg[ 545]=8'h00; bkg[ 546]=8'h00; bkg[ 547]=8'h00; bkg[ 548]=8'h00; bkg[ 549]=8'h00; bkg[ 550]=8'h00; bkg[ 551]=8'h00; bkg[ 552]=8'h01; bkg[ 553]=8'h01; bkg[ 554]=8'h01; bkg[ 555]=8'h01; bkg[ 556]=8'h01; bkg[ 557]=8'h01; bkg[ 558]=8'h01; bkg[ 559]=8'h01; 
bkg[ 560]=8'h01; bkg[ 561]=8'h01; bkg[ 562]=8'h01; bkg[ 563]=8'h01; bkg[ 564]=8'h01; bkg[ 565]=8'h01; bkg[ 566]=8'h01; bkg[ 567]=8'h01; bkg[ 568]=8'h01; bkg[ 569]=8'h01; bkg[ 570]=8'h01; bkg[ 571]=8'h01; bkg[ 572]=8'h01; bkg[ 573]=8'h01; bkg[ 574]=8'h01; bkg[ 575]=8'h01; 
bkg[ 576]=8'h01; bkg[ 577]=8'h01; bkg[ 578]=8'h01; bkg[ 579]=8'h01; bkg[ 580]=8'h01; bkg[ 581]=8'h01; bkg[ 582]=8'h01; bkg[ 583]=8'h01; bkg[ 584]=8'h01; bkg[ 585]=8'h01; bkg[ 586]=8'h01; bkg[ 587]=8'h01; bkg[ 588]=8'h01; bkg[ 589]=8'h01; bkg[ 590]=8'h01; bkg[ 591]=8'h01; 
bkg[ 592]=8'h01; bkg[ 593]=8'h01; bkg[ 594]=8'h01; bkg[ 595]=8'h01; bkg[ 596]=8'h01; bkg[ 597]=8'h01; bkg[ 598]=8'h01; bkg[ 599]=8'h01; bkg[ 600]=8'h01; bkg[ 601]=8'h01; bkg[ 602]=8'h01; bkg[ 603]=8'h01; bkg[ 604]=8'h01; bkg[ 605]=8'h01; bkg[ 606]=8'h01; bkg[ 607]=8'h01; 
bkg[ 608]=8'h01; bkg[ 609]=8'h01; bkg[ 610]=8'h01; bkg[ 611]=8'h01; bkg[ 612]=8'h01; bkg[ 613]=8'h01; bkg[ 614]=8'h01; bkg[ 615]=8'h01; bkg[ 616]=8'h01; bkg[ 617]=8'h01; bkg[ 618]=8'h01; bkg[ 619]=8'h01; bkg[ 620]=8'h01; bkg[ 621]=8'h01; bkg[ 622]=8'h01; bkg[ 623]=8'h01; 
bkg[ 624]=8'h01; bkg[ 625]=8'h01; bkg[ 626]=8'h01; bkg[ 627]=8'h01; bkg[ 628]=8'h01; bkg[ 629]=8'h01; bkg[ 630]=8'h01; bkg[ 631]=8'h01; bkg[ 632]=8'h01; bkg[ 633]=8'h01; bkg[ 634]=8'h01; bkg[ 635]=8'h01; bkg[ 636]=8'h01; bkg[ 637]=8'h01; bkg[ 638]=8'h01; bkg[ 639]=8'h01; 
bkg[ 640]=8'h01; bkg[ 641]=8'h01; bkg[ 642]=8'h01; bkg[ 643]=8'h01; bkg[ 644]=8'h01; bkg[ 645]=8'h01; bkg[ 646]=8'h01; bkg[ 647]=8'h01; bkg[ 648]=8'h01; bkg[ 649]=8'h01; bkg[ 650]=8'h01; bkg[ 651]=8'h01; bkg[ 652]=8'h01; bkg[ 653]=8'h01; bkg[ 654]=8'h01; bkg[ 655]=8'h01; 
bkg[ 656]=8'h01; bkg[ 657]=8'h01; bkg[ 658]=8'h01; bkg[ 659]=8'h01; bkg[ 660]=8'h01; bkg[ 661]=8'h01; bkg[ 662]=8'h01; bkg[ 663]=8'h01; bkg[ 664]=8'h01; bkg[ 665]=8'h01; bkg[ 666]=8'h01; bkg[ 667]=8'h01; bkg[ 668]=8'h01; bkg[ 669]=8'h01; bkg[ 670]=8'h01; bkg[ 671]=8'h01; 
bkg[ 672]=8'h01; bkg[ 673]=8'h01; bkg[ 674]=8'h01; bkg[ 675]=8'h01; bkg[ 676]=8'h01; bkg[ 677]=8'h01; bkg[ 678]=8'h01; bkg[ 679]=8'h01; bkg[ 680]=8'h01; bkg[ 681]=8'h01; bkg[ 682]=8'h01; bkg[ 683]=8'h01; bkg[ 684]=8'h01; bkg[ 685]=8'h01; bkg[ 686]=8'h01; bkg[ 687]=8'h01; 
bkg[ 688]=8'h01; bkg[ 689]=8'h01; bkg[ 690]=8'h01; bkg[ 691]=8'h01; bkg[ 692]=8'h01; bkg[ 693]=8'h01; bkg[ 694]=8'h01; bkg[ 695]=8'h01; bkg[ 696]=8'h01; bkg[ 697]=8'h01; bkg[ 698]=8'h01; bkg[ 699]=8'h01; bkg[ 700]=8'h01; bkg[ 701]=8'h01; bkg[ 702]=8'h01; bkg[ 703]=8'h01; 
bkg[ 704]=8'h01; bkg[ 705]=8'h01; bkg[ 706]=8'h01; bkg[ 707]=8'h01; bkg[ 708]=8'h01; bkg[ 709]=8'h01; bkg[ 710]=8'h01; bkg[ 711]=8'h01; bkg[ 712]=8'h01; bkg[ 713]=8'h01; bkg[ 714]=8'h01; bkg[ 715]=8'h01; bkg[ 716]=8'h01; bkg[ 717]=8'h01; bkg[ 718]=8'h01; bkg[ 719]=8'h01; 
bkg[ 720]=8'h01; bkg[ 721]=8'h01; bkg[ 722]=8'h01; bkg[ 723]=8'h01; bkg[ 724]=8'h01; bkg[ 725]=8'h01; bkg[ 726]=8'h01; bkg[ 727]=8'h01; bkg[ 728]=8'h01; bkg[ 729]=8'h01; bkg[ 730]=8'h01; bkg[ 731]=8'h01; bkg[ 732]=8'h01; bkg[ 733]=8'h01; bkg[ 734]=8'h01; bkg[ 735]=8'h01; 
bkg[ 736]=8'h01; bkg[ 737]=8'h01; bkg[ 738]=8'h01; bkg[ 739]=8'h01; bkg[ 740]=8'h01; bkg[ 741]=8'h01; bkg[ 742]=8'h01; bkg[ 743]=8'h01; bkg[ 744]=8'h01; bkg[ 745]=8'h01; bkg[ 746]=8'h01; bkg[ 747]=8'h01; bkg[ 748]=8'h01; bkg[ 749]=8'h01; bkg[ 750]=8'h01; bkg[ 751]=8'h01; 
bkg[ 752]=8'h01; bkg[ 753]=8'h01; bkg[ 754]=8'h01; bkg[ 755]=8'h01; bkg[ 756]=8'h01; bkg[ 757]=8'h01; bkg[ 758]=8'h01; bkg[ 759]=8'h01; bkg[ 760]=8'h01; bkg[ 761]=8'h01; bkg[ 762]=8'h01; bkg[ 763]=8'h01; bkg[ 764]=8'h01; bkg[ 765]=8'h01; bkg[ 766]=8'h01; bkg[ 767]=8'h01; 
bkg[ 768]=8'h00; bkg[ 769]=8'h00; bkg[ 770]=8'h00; bkg[ 771]=8'h00; bkg[ 772]=8'h00; bkg[ 773]=8'h00; bkg[ 774]=8'h00; bkg[ 775]=8'h00; bkg[ 776]=8'h00; bkg[ 777]=8'h00; bkg[ 778]=8'h00; bkg[ 779]=8'h00; bkg[ 780]=8'h00; bkg[ 781]=8'h00; bkg[ 782]=8'h00; bkg[ 783]=8'h00; 
bkg[ 784]=8'h00; bkg[ 785]=8'h00; bkg[ 786]=8'h00; bkg[ 787]=8'h00; bkg[ 788]=8'h00; bkg[ 789]=8'h00; bkg[ 790]=8'h00; bkg[ 791]=8'h00; bkg[ 792]=8'h00; bkg[ 793]=8'h00; bkg[ 794]=8'h00; bkg[ 795]=8'h00; bkg[ 796]=8'h00; bkg[ 797]=8'h00; bkg[ 798]=8'h00; bkg[ 799]=8'h00; 
bkg[ 800]=8'h00; bkg[ 801]=8'h00; bkg[ 802]=8'h00; bkg[ 803]=8'h00; bkg[ 804]=8'h00; bkg[ 805]=8'h00; bkg[ 806]=8'h00; bkg[ 807]=8'h00; bkg[ 808]=8'h01; bkg[ 809]=8'h01; bkg[ 810]=8'h01; bkg[ 811]=8'h01; bkg[ 812]=8'h01; bkg[ 813]=8'h01; bkg[ 814]=8'h01; bkg[ 815]=8'h01; 
bkg[ 816]=8'h01; bkg[ 817]=8'h01; bkg[ 818]=8'h01; bkg[ 819]=8'h01; bkg[ 820]=8'h01; bkg[ 821]=8'h01; bkg[ 822]=8'h01; bkg[ 823]=8'h01; bkg[ 824]=8'h01; bkg[ 825]=8'h01; bkg[ 826]=8'h01; bkg[ 827]=8'h01; bkg[ 828]=8'h01; bkg[ 829]=8'h01; bkg[ 830]=8'h01; bkg[ 831]=8'h01; 
bkg[ 832]=8'h01; bkg[ 833]=8'h01; bkg[ 834]=8'h01; bkg[ 835]=8'h01; bkg[ 836]=8'h01; bkg[ 837]=8'h01; bkg[ 838]=8'h01; bkg[ 839]=8'h01; bkg[ 840]=8'h01; bkg[ 841]=8'h01; bkg[ 842]=8'h01; bkg[ 843]=8'h01; bkg[ 844]=8'h01; bkg[ 845]=8'h01; bkg[ 846]=8'h01; bkg[ 847]=8'h01; 
bkg[ 848]=8'h01; bkg[ 849]=8'h01; bkg[ 850]=8'h01; bkg[ 851]=8'h01; bkg[ 852]=8'h01; bkg[ 853]=8'h01; bkg[ 854]=8'h01; bkg[ 855]=8'h01; bkg[ 856]=8'h01; bkg[ 857]=8'h01; bkg[ 858]=8'h01; bkg[ 859]=8'h01; bkg[ 860]=8'h01; bkg[ 861]=8'h01; bkg[ 862]=8'h01; bkg[ 863]=8'h01; 
bkg[ 864]=8'h01; bkg[ 865]=8'h01; bkg[ 866]=8'h01; bkg[ 867]=8'h01; bkg[ 868]=8'h01; bkg[ 869]=8'h01; bkg[ 870]=8'h01; bkg[ 871]=8'h01; bkg[ 872]=8'h01; bkg[ 873]=8'h01; bkg[ 874]=8'h01; bkg[ 875]=8'h01; bkg[ 876]=8'h01; bkg[ 877]=8'h01; bkg[ 878]=8'h01; bkg[ 879]=8'h01; 
bkg[ 880]=8'h01; bkg[ 881]=8'h01; bkg[ 882]=8'h01; bkg[ 883]=8'h01; bkg[ 884]=8'h01; bkg[ 885]=8'h01; bkg[ 886]=8'h01; bkg[ 887]=8'h01; bkg[ 888]=8'h01; bkg[ 889]=8'h01; bkg[ 890]=8'h01; bkg[ 891]=8'h01; bkg[ 892]=8'h01; bkg[ 893]=8'h01; bkg[ 894]=8'h01; bkg[ 895]=8'h01; 
bkg[ 896]=8'h01; bkg[ 897]=8'h01; bkg[ 898]=8'h01; bkg[ 899]=8'h01; bkg[ 900]=8'h01; bkg[ 901]=8'h01; bkg[ 902]=8'h01; bkg[ 903]=8'h01; bkg[ 904]=8'h01; bkg[ 905]=8'h01; bkg[ 906]=8'h01; bkg[ 907]=8'h01; bkg[ 908]=8'h01; bkg[ 909]=8'h01; bkg[ 910]=8'h01; bkg[ 911]=8'h01; 
bkg[ 912]=8'h01; bkg[ 913]=8'h01; bkg[ 914]=8'h01; bkg[ 915]=8'h01; bkg[ 916]=8'h01; bkg[ 917]=8'h01; bkg[ 918]=8'h01; bkg[ 919]=8'h01; bkg[ 920]=8'h01; bkg[ 921]=8'h01; bkg[ 922]=8'h01; bkg[ 923]=8'h01; bkg[ 924]=8'h01; bkg[ 925]=8'h01; bkg[ 926]=8'h01; bkg[ 927]=8'h01; 
bkg[ 928]=8'h01; bkg[ 929]=8'h01; bkg[ 930]=8'h01; bkg[ 931]=8'h01; bkg[ 932]=8'h01; bkg[ 933]=8'h01; bkg[ 934]=8'h01; bkg[ 935]=8'h01; bkg[ 936]=8'h01; bkg[ 937]=8'h01; bkg[ 938]=8'h01; bkg[ 939]=8'h01; bkg[ 940]=8'h01; bkg[ 941]=8'h01; bkg[ 942]=8'h01; bkg[ 943]=8'h01; 
bkg[ 944]=8'h01; bkg[ 945]=8'h01; bkg[ 946]=8'h01; bkg[ 947]=8'h01; bkg[ 948]=8'h01; bkg[ 949]=8'h01; bkg[ 950]=8'h01; bkg[ 951]=8'h01; bkg[ 952]=8'h01; bkg[ 953]=8'h01; bkg[ 954]=8'h01; bkg[ 955]=8'h01; bkg[ 956]=8'h01; bkg[ 957]=8'h01; bkg[ 958]=8'h01; bkg[ 959]=8'h01; 
bkg[ 960]=8'h01; bkg[ 961]=8'h01; bkg[ 962]=8'h01; bkg[ 963]=8'h01; bkg[ 964]=8'h01; bkg[ 965]=8'h01; bkg[ 966]=8'h01; bkg[ 967]=8'h01; bkg[ 968]=8'h01; bkg[ 969]=8'h01; bkg[ 970]=8'h01; bkg[ 971]=8'h01; bkg[ 972]=8'h01; bkg[ 973]=8'h01; bkg[ 974]=8'h01; bkg[ 975]=8'h01; 
bkg[ 976]=8'h01; bkg[ 977]=8'h01; bkg[ 978]=8'h01; bkg[ 979]=8'h01; bkg[ 980]=8'h01; bkg[ 981]=8'h01; bkg[ 982]=8'h01; bkg[ 983]=8'h01; bkg[ 984]=8'h01; bkg[ 985]=8'h01; bkg[ 986]=8'h01; bkg[ 987]=8'h01; bkg[ 988]=8'h01; bkg[ 989]=8'h01; bkg[ 990]=8'h01; bkg[ 991]=8'h01; 
bkg[ 992]=8'h01; bkg[ 993]=8'h01; bkg[ 994]=8'h01; bkg[ 995]=8'h01; bkg[ 996]=8'h01; bkg[ 997]=8'h01; bkg[ 998]=8'h01; bkg[ 999]=8'h01; bkg[1000]=8'h01; bkg[1001]=8'h01; bkg[1002]=8'h01; bkg[1003]=8'h01; bkg[1004]=8'h01; bkg[1005]=8'h01; bkg[1006]=8'h01; bkg[1007]=8'h01; 
bkg[1008]=8'h01; bkg[1009]=8'h01; bkg[1010]=8'h01; bkg[1011]=8'h01; bkg[1012]=8'h01; bkg[1013]=8'h01; bkg[1014]=8'h01; bkg[1015]=8'h01; bkg[1016]=8'h01; bkg[1017]=8'h01; bkg[1018]=8'h01; bkg[1019]=8'h01; bkg[1020]=8'h01; bkg[1021]=8'h01; bkg[1022]=8'h01; bkg[1023]=8'h01; 
bkg[1024]=8'h00; bkg[1025]=8'h00; bkg[1026]=8'h00; bkg[1027]=8'h00; bkg[1028]=8'h00; bkg[1029]=8'h00; bkg[1030]=8'h00; bkg[1031]=8'h00; bkg[1032]=8'h00; bkg[1033]=8'h00; bkg[1034]=8'h00; bkg[1035]=8'h00; bkg[1036]=8'h00; bkg[1037]=8'h00; bkg[1038]=8'h00; bkg[1039]=8'h00; 
bkg[1040]=8'h00; bkg[1041]=8'h00; bkg[1042]=8'h00; bkg[1043]=8'h00; bkg[1044]=8'h00; bkg[1045]=8'h00; bkg[1046]=8'h00; bkg[1047]=8'h00; bkg[1048]=8'h00; bkg[1049]=8'h00; bkg[1050]=8'h00; bkg[1051]=8'h00; bkg[1052]=8'h00; bkg[1053]=8'h00; bkg[1054]=8'h00; bkg[1055]=8'h00; 
bkg[1056]=8'h00; bkg[1057]=8'h00; bkg[1058]=8'h00; bkg[1059]=8'h00; bkg[1060]=8'h00; bkg[1061]=8'h00; bkg[1062]=8'h00; bkg[1063]=8'h00; bkg[1064]=8'h01; bkg[1065]=8'h01; bkg[1066]=8'h01; bkg[1067]=8'h01; bkg[1068]=8'h01; bkg[1069]=8'h01; bkg[1070]=8'h01; bkg[1071]=8'h01; 
bkg[1072]=8'h01; bkg[1073]=8'h01; bkg[1074]=8'h01; bkg[1075]=8'h01; bkg[1076]=8'h01; bkg[1077]=8'h01; bkg[1078]=8'h01; bkg[1079]=8'h01; bkg[1080]=8'h01; bkg[1081]=8'h01; bkg[1082]=8'h01; bkg[1083]=8'h01; bkg[1084]=8'h01; bkg[1085]=8'h01; bkg[1086]=8'h01; bkg[1087]=8'h01; 
bkg[1088]=8'h01; bkg[1089]=8'h01; bkg[1090]=8'h01; bkg[1091]=8'h01; bkg[1092]=8'h01; bkg[1093]=8'h01; bkg[1094]=8'h01; bkg[1095]=8'h01; bkg[1096]=8'h01; bkg[1097]=8'h01; bkg[1098]=8'h01; bkg[1099]=8'h01; bkg[1100]=8'h01; bkg[1101]=8'h01; bkg[1102]=8'h01; bkg[1103]=8'h01; 
bkg[1104]=8'h01; bkg[1105]=8'h01; bkg[1106]=8'h01; bkg[1107]=8'h01; bkg[1108]=8'h01; bkg[1109]=8'h01; bkg[1110]=8'h01; bkg[1111]=8'h01; bkg[1112]=8'h01; bkg[1113]=8'h01; bkg[1114]=8'h01; bkg[1115]=8'h01; bkg[1116]=8'h01; bkg[1117]=8'h01; bkg[1118]=8'h01; bkg[1119]=8'h01; 
bkg[1120]=8'h01; bkg[1121]=8'h01; bkg[1122]=8'h01; bkg[1123]=8'h01; bkg[1124]=8'h01; bkg[1125]=8'h01; bkg[1126]=8'h01; bkg[1127]=8'h01; bkg[1128]=8'h01; bkg[1129]=8'h01; bkg[1130]=8'h01; bkg[1131]=8'h01; bkg[1132]=8'h01; bkg[1133]=8'h01; bkg[1134]=8'h01; bkg[1135]=8'h01; 
bkg[1136]=8'h01; bkg[1137]=8'h01; bkg[1138]=8'h01; bkg[1139]=8'h01; bkg[1140]=8'h01; bkg[1141]=8'h01; bkg[1142]=8'h01; bkg[1143]=8'h01; bkg[1144]=8'h01; bkg[1145]=8'h01; bkg[1146]=8'h01; bkg[1147]=8'h01; bkg[1148]=8'h01; bkg[1149]=8'h01; bkg[1150]=8'h01; bkg[1151]=8'h01; 
bkg[1152]=8'h01; bkg[1153]=8'h01; bkg[1154]=8'h01; bkg[1155]=8'h01; bkg[1156]=8'h01; bkg[1157]=8'h01; bkg[1158]=8'h01; bkg[1159]=8'h01; bkg[1160]=8'h01; bkg[1161]=8'h01; bkg[1162]=8'h01; bkg[1163]=8'h01; bkg[1164]=8'h01; bkg[1165]=8'h01; bkg[1166]=8'h01; bkg[1167]=8'h01; 
bkg[1168]=8'h01; bkg[1169]=8'h01; bkg[1170]=8'h01; bkg[1171]=8'h01; bkg[1172]=8'h01; bkg[1173]=8'h01; bkg[1174]=8'h01; bkg[1175]=8'h01; bkg[1176]=8'h01; bkg[1177]=8'h01; bkg[1178]=8'h01; bkg[1179]=8'h01; bkg[1180]=8'h01; bkg[1181]=8'h01; bkg[1182]=8'h01; bkg[1183]=8'h01; 
bkg[1184]=8'h01; bkg[1185]=8'h01; bkg[1186]=8'h01; bkg[1187]=8'h01; bkg[1188]=8'h01; bkg[1189]=8'h01; bkg[1190]=8'h01; bkg[1191]=8'h01; bkg[1192]=8'h01; bkg[1193]=8'h01; bkg[1194]=8'h01; bkg[1195]=8'h01; bkg[1196]=8'h01; bkg[1197]=8'h01; bkg[1198]=8'h01; bkg[1199]=8'h01; 
bkg[1200]=8'h01; bkg[1201]=8'h01; bkg[1202]=8'h01; bkg[1203]=8'h01; bkg[1204]=8'h01; bkg[1205]=8'h01; bkg[1206]=8'h01; bkg[1207]=8'h01; bkg[1208]=8'h01; bkg[1209]=8'h01; bkg[1210]=8'h01; bkg[1211]=8'h01; bkg[1212]=8'h01; bkg[1213]=8'h01; bkg[1214]=8'h01; bkg[1215]=8'h01; 
bkg[1216]=8'h01; bkg[1217]=8'h01; bkg[1218]=8'h01; bkg[1219]=8'h01; bkg[1220]=8'h01; bkg[1221]=8'h01; bkg[1222]=8'h01; bkg[1223]=8'h01; bkg[1224]=8'h01; bkg[1225]=8'h01; bkg[1226]=8'h01; bkg[1227]=8'h01; bkg[1228]=8'h01; bkg[1229]=8'h01; bkg[1230]=8'h01; bkg[1231]=8'h01; 
bkg[1232]=8'h01; bkg[1233]=8'h01; bkg[1234]=8'h01; bkg[1235]=8'h01; bkg[1236]=8'h01; bkg[1237]=8'h01; bkg[1238]=8'h01; bkg[1239]=8'h01; bkg[1240]=8'h01; bkg[1241]=8'h01; bkg[1242]=8'h01; bkg[1243]=8'h01; bkg[1244]=8'h01; bkg[1245]=8'h01; bkg[1246]=8'h01; bkg[1247]=8'h01; 
bkg[1248]=8'h01; bkg[1249]=8'h01; bkg[1250]=8'h01; bkg[1251]=8'h01; bkg[1252]=8'h01; bkg[1253]=8'h01; bkg[1254]=8'h01; bkg[1255]=8'h01; bkg[1256]=8'h01; bkg[1257]=8'h01; bkg[1258]=8'h01; bkg[1259]=8'h01; bkg[1260]=8'h01; bkg[1261]=8'h01; bkg[1262]=8'h01; bkg[1263]=8'h01; 
bkg[1264]=8'h01; bkg[1265]=8'h01; bkg[1266]=8'h01; bkg[1267]=8'h01; bkg[1268]=8'h01; bkg[1269]=8'h01; bkg[1270]=8'h01; bkg[1271]=8'h01; bkg[1272]=8'h01; bkg[1273]=8'h01; bkg[1274]=8'h01; bkg[1275]=8'h01; bkg[1276]=8'h01; bkg[1277]=8'h01; bkg[1278]=8'h01; bkg[1279]=8'h01; 
bkg[1280]=8'h00; bkg[1281]=8'h00; bkg[1282]=8'h00; bkg[1283]=8'h00; bkg[1284]=8'h00; bkg[1285]=8'h00; bkg[1286]=8'h00; bkg[1287]=8'h00; bkg[1288]=8'h00; bkg[1289]=8'h00; bkg[1290]=8'h00; bkg[1291]=8'h00; bkg[1292]=8'h00; bkg[1293]=8'h00; bkg[1294]=8'h00; bkg[1295]=8'h00; 
bkg[1296]=8'h00; bkg[1297]=8'h00; bkg[1298]=8'h00; bkg[1299]=8'h00; bkg[1300]=8'h00; bkg[1301]=8'h00; bkg[1302]=8'h00; bkg[1303]=8'h00; bkg[1304]=8'h00; bkg[1305]=8'h00; bkg[1306]=8'h00; bkg[1307]=8'h00; bkg[1308]=8'h00; bkg[1309]=8'h00; bkg[1310]=8'h00; bkg[1311]=8'h00; 
bkg[1312]=8'h00; bkg[1313]=8'h00; bkg[1314]=8'h00; bkg[1315]=8'h00; bkg[1316]=8'h00; bkg[1317]=8'h00; bkg[1318]=8'h00; bkg[1319]=8'h00; bkg[1320]=8'h01; bkg[1321]=8'h01; bkg[1322]=8'h01; bkg[1323]=8'h01; bkg[1324]=8'h01; bkg[1325]=8'h01; bkg[1326]=8'h01; bkg[1327]=8'h01; 
bkg[1328]=8'h01; bkg[1329]=8'h01; bkg[1330]=8'h01; bkg[1331]=8'h01; bkg[1332]=8'h01; bkg[1333]=8'h01; bkg[1334]=8'h01; bkg[1335]=8'h01; bkg[1336]=8'h01; bkg[1337]=8'h01; bkg[1338]=8'h01; bkg[1339]=8'h01; bkg[1340]=8'h01; bkg[1341]=8'h01; bkg[1342]=8'h01; bkg[1343]=8'h01; 
bkg[1344]=8'h01; bkg[1345]=8'h01; bkg[1346]=8'h01; bkg[1347]=8'h01; bkg[1348]=8'h01; bkg[1349]=8'h01; bkg[1350]=8'h01; bkg[1351]=8'h01; bkg[1352]=8'h01; bkg[1353]=8'h01; bkg[1354]=8'h01; bkg[1355]=8'h01; bkg[1356]=8'h01; bkg[1357]=8'h01; bkg[1358]=8'h01; bkg[1359]=8'h01; 
bkg[1360]=8'h01; bkg[1361]=8'h01; bkg[1362]=8'h01; bkg[1363]=8'h01; bkg[1364]=8'h01; bkg[1365]=8'h01; bkg[1366]=8'h01; bkg[1367]=8'h01; bkg[1368]=8'h01; bkg[1369]=8'h01; bkg[1370]=8'h01; bkg[1371]=8'h01; bkg[1372]=8'h01; bkg[1373]=8'h01; bkg[1374]=8'h01; bkg[1375]=8'h01; 
bkg[1376]=8'h01; bkg[1377]=8'h01; bkg[1378]=8'h01; bkg[1379]=8'h01; bkg[1380]=8'h01; bkg[1381]=8'h01; bkg[1382]=8'h01; bkg[1383]=8'h01; bkg[1384]=8'h01; bkg[1385]=8'h01; bkg[1386]=8'h01; bkg[1387]=8'h01; bkg[1388]=8'h01; bkg[1389]=8'h01; bkg[1390]=8'h01; bkg[1391]=8'h01; 
bkg[1392]=8'h01; bkg[1393]=8'h01; bkg[1394]=8'h01; bkg[1395]=8'h01; bkg[1396]=8'h01; bkg[1397]=8'h01; bkg[1398]=8'h01; bkg[1399]=8'h01; bkg[1400]=8'h01; bkg[1401]=8'h01; bkg[1402]=8'h01; bkg[1403]=8'h01; bkg[1404]=8'h01; bkg[1405]=8'h01; bkg[1406]=8'h01; bkg[1407]=8'h01; 
bkg[1408]=8'h01; bkg[1409]=8'h01; bkg[1410]=8'h01; bkg[1411]=8'h01; bkg[1412]=8'h01; bkg[1413]=8'h01; bkg[1414]=8'h01; bkg[1415]=8'h01; bkg[1416]=8'h01; bkg[1417]=8'h01; bkg[1418]=8'h01; bkg[1419]=8'h01; bkg[1420]=8'h01; bkg[1421]=8'h01; bkg[1422]=8'h01; bkg[1423]=8'h01; 
bkg[1424]=8'h01; bkg[1425]=8'h01; bkg[1426]=8'h01; bkg[1427]=8'h01; bkg[1428]=8'h01; bkg[1429]=8'h01; bkg[1430]=8'h01; bkg[1431]=8'h01; bkg[1432]=8'h01; bkg[1433]=8'h01; bkg[1434]=8'h01; bkg[1435]=8'h01; bkg[1436]=8'h01; bkg[1437]=8'h01; bkg[1438]=8'h01; bkg[1439]=8'h01; 
bkg[1440]=8'h01; bkg[1441]=8'h01; bkg[1442]=8'h01; bkg[1443]=8'h01; bkg[1444]=8'h01; bkg[1445]=8'h01; bkg[1446]=8'h01; bkg[1447]=8'h01; bkg[1448]=8'h01; bkg[1449]=8'h01; bkg[1450]=8'h01; bkg[1451]=8'h01; bkg[1452]=8'h01; bkg[1453]=8'h01; bkg[1454]=8'h01; bkg[1455]=8'h01; 
bkg[1456]=8'h01; bkg[1457]=8'h01; bkg[1458]=8'h01; bkg[1459]=8'h01; bkg[1460]=8'h01; bkg[1461]=8'h01; bkg[1462]=8'h01; bkg[1463]=8'h01; bkg[1464]=8'h01; bkg[1465]=8'h01; bkg[1466]=8'h01; bkg[1467]=8'h01; bkg[1468]=8'h01; bkg[1469]=8'h01; bkg[1470]=8'h01; bkg[1471]=8'h01; 
bkg[1472]=8'h01; bkg[1473]=8'h01; bkg[1474]=8'h01; bkg[1475]=8'h01; bkg[1476]=8'h01; bkg[1477]=8'h01; bkg[1478]=8'h01; bkg[1479]=8'h01; bkg[1480]=8'h01; bkg[1481]=8'h01; bkg[1482]=8'h01; bkg[1483]=8'h01; bkg[1484]=8'h01; bkg[1485]=8'h01; bkg[1486]=8'h01; bkg[1487]=8'h01; 
bkg[1488]=8'h01; bkg[1489]=8'h01; bkg[1490]=8'h01; bkg[1491]=8'h01; bkg[1492]=8'h01; bkg[1493]=8'h01; bkg[1494]=8'h01; bkg[1495]=8'h01; bkg[1496]=8'h01; bkg[1497]=8'h01; bkg[1498]=8'h01; bkg[1499]=8'h01; bkg[1500]=8'h01; bkg[1501]=8'h01; bkg[1502]=8'h01; bkg[1503]=8'h01; 
bkg[1504]=8'h01; bkg[1505]=8'h01; bkg[1506]=8'h01; bkg[1507]=8'h01; bkg[1508]=8'h01; bkg[1509]=8'h01; bkg[1510]=8'h01; bkg[1511]=8'h01; bkg[1512]=8'h01; bkg[1513]=8'h01; bkg[1514]=8'h01; bkg[1515]=8'h01; bkg[1516]=8'h01; bkg[1517]=8'h01; bkg[1518]=8'h01; bkg[1519]=8'h01; 
bkg[1520]=8'h01; bkg[1521]=8'h01; bkg[1522]=8'h01; bkg[1523]=8'h01; bkg[1524]=8'h01; bkg[1525]=8'h01; bkg[1526]=8'h01; bkg[1527]=8'h01; bkg[1528]=8'h01; bkg[1529]=8'h01; bkg[1530]=8'h01; bkg[1531]=8'h01; bkg[1532]=8'h01; bkg[1533]=8'h01; bkg[1534]=8'h01; bkg[1535]=8'h01; 
bkg[1536]=8'h00; bkg[1537]=8'h00; bkg[1538]=8'h00; bkg[1539]=8'h00; bkg[1540]=8'h00; bkg[1541]=8'h00; bkg[1542]=8'h00; bkg[1543]=8'h00; bkg[1544]=8'h00; bkg[1545]=8'h00; bkg[1546]=8'h00; bkg[1547]=8'h00; bkg[1548]=8'h00; bkg[1549]=8'h00; bkg[1550]=8'h00; bkg[1551]=8'h00; 
bkg[1552]=8'h00; bkg[1553]=8'h00; bkg[1554]=8'h00; bkg[1555]=8'h00; bkg[1556]=8'h00; bkg[1557]=8'h00; bkg[1558]=8'h00; bkg[1559]=8'h00; bkg[1560]=8'h00; bkg[1561]=8'h00; bkg[1562]=8'h00; bkg[1563]=8'h00; bkg[1564]=8'h00; bkg[1565]=8'h00; bkg[1566]=8'h00; bkg[1567]=8'h00; 
bkg[1568]=8'h00; bkg[1569]=8'h00; bkg[1570]=8'h00; bkg[1571]=8'h00; bkg[1572]=8'h00; bkg[1573]=8'h00; bkg[1574]=8'h00; bkg[1575]=8'h00; bkg[1576]=8'h01; bkg[1577]=8'h01; bkg[1578]=8'h01; bkg[1579]=8'h01; bkg[1580]=8'h01; bkg[1581]=8'h01; bkg[1582]=8'h01; bkg[1583]=8'h01; 
bkg[1584]=8'h01; bkg[1585]=8'h01; bkg[1586]=8'h01; bkg[1587]=8'h01; bkg[1588]=8'h01; bkg[1589]=8'h01; bkg[1590]=8'h01; bkg[1591]=8'h01; bkg[1592]=8'h01; bkg[1593]=8'h01; bkg[1594]=8'h01; bkg[1595]=8'h01; bkg[1596]=8'h01; bkg[1597]=8'h01; bkg[1598]=8'h01; bkg[1599]=8'h01; 
bkg[1600]=8'h01; bkg[1601]=8'h01; bkg[1602]=8'h01; bkg[1603]=8'h01; bkg[1604]=8'h01; bkg[1605]=8'h01; bkg[1606]=8'h01; bkg[1607]=8'h01; bkg[1608]=8'h01; bkg[1609]=8'h01; bkg[1610]=8'h01; bkg[1611]=8'h01; bkg[1612]=8'h01; bkg[1613]=8'h01; bkg[1614]=8'h01; bkg[1615]=8'h01; 
bkg[1616]=8'h01; bkg[1617]=8'h01; bkg[1618]=8'h01; bkg[1619]=8'h01; bkg[1620]=8'h01; bkg[1621]=8'h01; bkg[1622]=8'h01; bkg[1623]=8'h01; bkg[1624]=8'h01; bkg[1625]=8'h01; bkg[1626]=8'h01; bkg[1627]=8'h01; bkg[1628]=8'h01; bkg[1629]=8'h01; bkg[1630]=8'h01; bkg[1631]=8'h01; 
bkg[1632]=8'h01; bkg[1633]=8'h01; bkg[1634]=8'h01; bkg[1635]=8'h01; bkg[1636]=8'h01; bkg[1637]=8'h01; bkg[1638]=8'h01; bkg[1639]=8'h01; bkg[1640]=8'h01; bkg[1641]=8'h01; bkg[1642]=8'h01; bkg[1643]=8'h01; bkg[1644]=8'h01; bkg[1645]=8'h01; bkg[1646]=8'h01; bkg[1647]=8'h01; 
bkg[1648]=8'h01; bkg[1649]=8'h01; bkg[1650]=8'h01; bkg[1651]=8'h01; bkg[1652]=8'h01; bkg[1653]=8'h01; bkg[1654]=8'h01; bkg[1655]=8'h01; bkg[1656]=8'h01; bkg[1657]=8'h01; bkg[1658]=8'h01; bkg[1659]=8'h01; bkg[1660]=8'h01; bkg[1661]=8'h01; bkg[1662]=8'h01; bkg[1663]=8'h01; 
bkg[1664]=8'h01; bkg[1665]=8'h01; bkg[1666]=8'h01; bkg[1667]=8'h01; bkg[1668]=8'h01; bkg[1669]=8'h01; bkg[1670]=8'h01; bkg[1671]=8'h01; bkg[1672]=8'h01; bkg[1673]=8'h01; bkg[1674]=8'h01; bkg[1675]=8'h01; bkg[1676]=8'h01; bkg[1677]=8'h01; bkg[1678]=8'h01; bkg[1679]=8'h01; 
bkg[1680]=8'h01; bkg[1681]=8'h01; bkg[1682]=8'h01; bkg[1683]=8'h01; bkg[1684]=8'h01; bkg[1685]=8'h01; bkg[1686]=8'h01; bkg[1687]=8'h01; bkg[1688]=8'h01; bkg[1689]=8'h01; bkg[1690]=8'h01; bkg[1691]=8'h01; bkg[1692]=8'h01; bkg[1693]=8'h01; bkg[1694]=8'h01; bkg[1695]=8'h01; 
bkg[1696]=8'h01; bkg[1697]=8'h01; bkg[1698]=8'h01; bkg[1699]=8'h01; bkg[1700]=8'h01; bkg[1701]=8'h01; bkg[1702]=8'h01; bkg[1703]=8'h01; bkg[1704]=8'h01; bkg[1705]=8'h01; bkg[1706]=8'h01; bkg[1707]=8'h01; bkg[1708]=8'h01; bkg[1709]=8'h01; bkg[1710]=8'h01; bkg[1711]=8'h01; 
bkg[1712]=8'h01; bkg[1713]=8'h01; bkg[1714]=8'h01; bkg[1715]=8'h01; bkg[1716]=8'h01; bkg[1717]=8'h01; bkg[1718]=8'h01; bkg[1719]=8'h01; bkg[1720]=8'h01; bkg[1721]=8'h01; bkg[1722]=8'h01; bkg[1723]=8'h01; bkg[1724]=8'h01; bkg[1725]=8'h01; bkg[1726]=8'h01; bkg[1727]=8'h01; 
bkg[1728]=8'h01; bkg[1729]=8'h01; bkg[1730]=8'h01; bkg[1731]=8'h01; bkg[1732]=8'h01; bkg[1733]=8'h01; bkg[1734]=8'h01; bkg[1735]=8'h01; bkg[1736]=8'h01; bkg[1737]=8'h01; bkg[1738]=8'h01; bkg[1739]=8'h01; bkg[1740]=8'h01; bkg[1741]=8'h01; bkg[1742]=8'h01; bkg[1743]=8'h01; 
bkg[1744]=8'h01; bkg[1745]=8'h01; bkg[1746]=8'h01; bkg[1747]=8'h01; bkg[1748]=8'h01; bkg[1749]=8'h01; bkg[1750]=8'h01; bkg[1751]=8'h01; bkg[1752]=8'h01; bkg[1753]=8'h01; bkg[1754]=8'h01; bkg[1755]=8'h01; bkg[1756]=8'h01; bkg[1757]=8'h01; bkg[1758]=8'h01; bkg[1759]=8'h01; 
bkg[1760]=8'h01; bkg[1761]=8'h01; bkg[1762]=8'h01; bkg[1763]=8'h01; bkg[1764]=8'h01; bkg[1765]=8'h01; bkg[1766]=8'h01; bkg[1767]=8'h01; bkg[1768]=8'h01; bkg[1769]=8'h01; bkg[1770]=8'h01; bkg[1771]=8'h01; bkg[1772]=8'h01; bkg[1773]=8'h01; bkg[1774]=8'h01; bkg[1775]=8'h01; 
bkg[1776]=8'h01; bkg[1777]=8'h01; bkg[1778]=8'h01; bkg[1779]=8'h01; bkg[1780]=8'h01; bkg[1781]=8'h01; bkg[1782]=8'h01; bkg[1783]=8'h01; bkg[1784]=8'h01; bkg[1785]=8'h01; bkg[1786]=8'h01; bkg[1787]=8'h01; bkg[1788]=8'h01; bkg[1789]=8'h01; bkg[1790]=8'h01; bkg[1791]=8'h01; 
bkg[1792]=8'h00; bkg[1793]=8'h00; bkg[1794]=8'h00; bkg[1795]=8'h00; bkg[1796]=8'h00; bkg[1797]=8'h00; bkg[1798]=8'h00; bkg[1799]=8'h00; bkg[1800]=8'h00; bkg[1801]=8'h00; bkg[1802]=8'h00; bkg[1803]=8'h00; bkg[1804]=8'h00; bkg[1805]=8'h00; bkg[1806]=8'h00; bkg[1807]=8'h00; 
bkg[1808]=8'h00; bkg[1809]=8'h00; bkg[1810]=8'h00; bkg[1811]=8'h00; bkg[1812]=8'h00; bkg[1813]=8'h00; bkg[1814]=8'h00; bkg[1815]=8'h00; bkg[1816]=8'h00; bkg[1817]=8'h00; bkg[1818]=8'h00; bkg[1819]=8'h00; bkg[1820]=8'h00; bkg[1821]=8'h00; bkg[1822]=8'h00; bkg[1823]=8'h00; 
bkg[1824]=8'h00; bkg[1825]=8'h00; bkg[1826]=8'h00; bkg[1827]=8'h00; bkg[1828]=8'h00; bkg[1829]=8'h00; bkg[1830]=8'h00; bkg[1831]=8'h00; bkg[1832]=8'h01; bkg[1833]=8'h01; bkg[1834]=8'h01; bkg[1835]=8'h01; bkg[1836]=8'h01; bkg[1837]=8'h01; bkg[1838]=8'h01; bkg[1839]=8'h01; 
bkg[1840]=8'h01; bkg[1841]=8'h01; bkg[1842]=8'h01; bkg[1843]=8'h01; bkg[1844]=8'h01; bkg[1845]=8'h01; bkg[1846]=8'h01; bkg[1847]=8'h01; bkg[1848]=8'h01; bkg[1849]=8'h01; bkg[1850]=8'h01; bkg[1851]=8'h01; bkg[1852]=8'h01; bkg[1853]=8'h01; bkg[1854]=8'h01; bkg[1855]=8'h01; 
bkg[1856]=8'h01; bkg[1857]=8'h01; bkg[1858]=8'h01; bkg[1859]=8'h01; bkg[1860]=8'h01; bkg[1861]=8'h01; bkg[1862]=8'h01; bkg[1863]=8'h01; bkg[1864]=8'h01; bkg[1865]=8'h01; bkg[1866]=8'h01; bkg[1867]=8'h01; bkg[1868]=8'h01; bkg[1869]=8'h01; bkg[1870]=8'h01; bkg[1871]=8'h01; 
bkg[1872]=8'h01; bkg[1873]=8'h01; bkg[1874]=8'h01; bkg[1875]=8'h01; bkg[1876]=8'h01; bkg[1877]=8'h01; bkg[1878]=8'h01; bkg[1879]=8'h01; bkg[1880]=8'h01; bkg[1881]=8'h01; bkg[1882]=8'h01; bkg[1883]=8'h01; bkg[1884]=8'h01; bkg[1885]=8'h01; bkg[1886]=8'h01; bkg[1887]=8'h01; 
bkg[1888]=8'h01; bkg[1889]=8'h01; bkg[1890]=8'h01; bkg[1891]=8'h01; bkg[1892]=8'h01; bkg[1893]=8'h01; bkg[1894]=8'h01; bkg[1895]=8'h01; bkg[1896]=8'h01; bkg[1897]=8'h01; bkg[1898]=8'h01; bkg[1899]=8'h01; bkg[1900]=8'h01; bkg[1901]=8'h01; bkg[1902]=8'h01; bkg[1903]=8'h01; 
bkg[1904]=8'h01; bkg[1905]=8'h01; bkg[1906]=8'h01; bkg[1907]=8'h01; bkg[1908]=8'h01; bkg[1909]=8'h01; bkg[1910]=8'h01; bkg[1911]=8'h01; bkg[1912]=8'h01; bkg[1913]=8'h01; bkg[1914]=8'h01; bkg[1915]=8'h01; bkg[1916]=8'h01; bkg[1917]=8'h01; bkg[1918]=8'h01; bkg[1919]=8'h01; 
bkg[1920]=8'h01; bkg[1921]=8'h01; bkg[1922]=8'h01; bkg[1923]=8'h01; bkg[1924]=8'h01; bkg[1925]=8'h01; bkg[1926]=8'h01; bkg[1927]=8'h01; bkg[1928]=8'h01; bkg[1929]=8'h01; bkg[1930]=8'h01; bkg[1931]=8'h01; bkg[1932]=8'h01; bkg[1933]=8'h01; bkg[1934]=8'h01; bkg[1935]=8'h01; 
bkg[1936]=8'h01; bkg[1937]=8'h01; bkg[1938]=8'h01; bkg[1939]=8'h01; bkg[1940]=8'h01; bkg[1941]=8'h01; bkg[1942]=8'h01; bkg[1943]=8'h01; bkg[1944]=8'h01; bkg[1945]=8'h01; bkg[1946]=8'h01; bkg[1947]=8'h01; bkg[1948]=8'h01; bkg[1949]=8'h01; bkg[1950]=8'h01; bkg[1951]=8'h01; 
bkg[1952]=8'h01; bkg[1953]=8'h01; bkg[1954]=8'h01; bkg[1955]=8'h01; bkg[1956]=8'h01; bkg[1957]=8'h01; bkg[1958]=8'h01; bkg[1959]=8'h01; bkg[1960]=8'h01; bkg[1961]=8'h01; bkg[1962]=8'h01; bkg[1963]=8'h01; bkg[1964]=8'h01; bkg[1965]=8'h01; bkg[1966]=8'h01; bkg[1967]=8'h01; 
bkg[1968]=8'h01; bkg[1969]=8'h01; bkg[1970]=8'h01; bkg[1971]=8'h01; bkg[1972]=8'h01; bkg[1973]=8'h01; bkg[1974]=8'h01; bkg[1975]=8'h01; bkg[1976]=8'h01; bkg[1977]=8'h01; bkg[1978]=8'h01; bkg[1979]=8'h01; bkg[1980]=8'h01; bkg[1981]=8'h01; bkg[1982]=8'h01; bkg[1983]=8'h01; 
bkg[1984]=8'h01; bkg[1985]=8'h01; bkg[1986]=8'h01; bkg[1987]=8'h01; bkg[1988]=8'h01; bkg[1989]=8'h01; bkg[1990]=8'h01; bkg[1991]=8'h01; bkg[1992]=8'h01; bkg[1993]=8'h01; bkg[1994]=8'h01; bkg[1995]=8'h01; bkg[1996]=8'h01; bkg[1997]=8'h01; bkg[1998]=8'h01; bkg[1999]=8'h01; 
bkg[2000]=8'h01; bkg[2001]=8'h01; bkg[2002]=8'h01; bkg[2003]=8'h01; bkg[2004]=8'h01; bkg[2005]=8'h01; bkg[2006]=8'h01; bkg[2007]=8'h01; bkg[2008]=8'h01; bkg[2009]=8'h01; bkg[2010]=8'h01; bkg[2011]=8'h01; bkg[2012]=8'h01; bkg[2013]=8'h01; bkg[2014]=8'h01; bkg[2015]=8'h01; 
bkg[2016]=8'h01; bkg[2017]=8'h01; bkg[2018]=8'h01; bkg[2019]=8'h01; bkg[2020]=8'h01; bkg[2021]=8'h01; bkg[2022]=8'h01; bkg[2023]=8'h01; bkg[2024]=8'h01; bkg[2025]=8'h01; bkg[2026]=8'h01; bkg[2027]=8'h01; bkg[2028]=8'h01; bkg[2029]=8'h01; bkg[2030]=8'h01; bkg[2031]=8'h01; 
bkg[2032]=8'h01; bkg[2033]=8'h01; bkg[2034]=8'h01; bkg[2035]=8'h01; bkg[2036]=8'h01; bkg[2037]=8'h01; bkg[2038]=8'h01; bkg[2039]=8'h01; bkg[2040]=8'h01; bkg[2041]=8'h01; bkg[2042]=8'h01; bkg[2043]=8'h01; bkg[2044]=8'h01; bkg[2045]=8'h01; bkg[2046]=8'h01; bkg[2047]=8'h01; 
end

endmodule