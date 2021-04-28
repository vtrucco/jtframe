
module jtframe_sdram64_rfsh #(parameter HF=1, RFSHCNT=8)
(
    input               rst,
    input               clk,

    input               start,
    output   reg        br,
    input               bg,
    output   reg        rfshing,
    output   reg  [3:0] cmd,
    output       [12:0] sdram_a
);

localparam STW=3+7-(HF==1? 0 : 4);

//                             /CS /RAS /CAS /WE
localparam CMD_LOAD_MODE   = 4'b0___0____0____0, // 0
           CMD_REFRESH     = 4'b0___0____0____1, // 1
           CMD_PRECHARGE   = 4'b0___0____1____0, // 2
           CMD_ACTIVE      = 4'b0___0____1____1, // 3
           CMD_WRITE       = 4'b0___1____0____0, // 4
           CMD_READ        = 4'b0___1____0____1, // 5
           CMD_STOP        = 4'b0___1____1____0, // 6 Burst terminate
           CMD_NOP         = 4'b0___1____1____1, // 7
           CMD_INHIBIT     = 4'b1___0____0____0; // 8

assign sdram_a = 13'h400;   // used for precharging all banks

reg     [4:0] cnt;
reg [STW-1:0] st;
reg           last_start;
wire    [5:0] next_cnt;

assign next_cnt = {1'b0, cnt} + RFSHCNT[5:0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st      <= 1;
        cmd     <= CMD_NOP;
        cnt     <= 0;
        br      <= 0;
        rfshing <= 0;
    end else begin
        last_start <= start;
        if( start && !last_start ) begin
            cnt <= next_cnt[5] ? ~5'h0 : next_cnt[4:0]; // carry over from previous "frame"
        end
        if( cnt!=0 && !rfshing ) begin
            br  <= 1;
            st  <= 1;
        end
        if( bg ) begin
            br      <= 0;
            rfshing <= 1;
        end
        if( rfshing )
            st <= { st[STW-2:0], st[STW-1] };
        if( st[STW-1] ) begin
            rfshing <= 0;
            cnt <= cnt - 1'd1;
        end
        cmd <= st[0] ? CMD_PRECHARGE : ( st[HF?2:1] ? CMD_REFRESH : CMD_NOP );
    end
end

endmodule