// ============================================================================
// fc_if : fc_top 검증용 인터페이스
//  - DUT 포트 + 화이트박스 프로브(hidden/pose write, requant 출력)
//  - 외부 메모리 4종(feat / fcw / param / lut) 모델 내장 : 1-cycle sync read
//    -> fc_controller 가 주소를 조합으로 내고 mac_valid 를 1클럭 뒤 레지스터로
//       내보내므로, feat/fcw/lut 는 "정확히 1클럭" 읽기 지연이어야 정렬이 맞음
// ============================================================================
interface fc_if(input logic clk);

    // ---------------- Geometry ----------------
    localparam int FEAT_DEPTH  = 640;   // RX_NUM(5) * WORDS_PER_RX(128)
    localparam int FCW_DEPTH   = 4096;  // 12-bit addr
    localparam int PARAM_DEPTH = 512;   // 9-bit addr
    localparam int LUT_DEPTH   = 1024;  // 10-bit addr

    logic        rst_n;

    // ---------------- Control ----------------
    logic        fc_start;
    logic [1:0]  fc_sel;
    logic        fc_done;

    // ---------------- FC1 weight FIFO ----------------
    logic        fc1_fifo_we;
    logic [63:0] fc1_fifo_wdata;
    logic        fc1_fifo_full;
    logic        fc1_fifo_empty;

    // ---------------- External memories (DUT side) ----------------
    logic [9:0]  feat_raddr;
    logic [63:0] feat_rdata;
    logic [11:0] fcw_raddr;
    logic [63:0] fcw_rdata;
    logic [8:0]  fc_param_raddr;
    logic [95:0] fc_param_rdata;
    logic [9:0]  fc_lut_raddr;
    logic [7:0]  fc_lut_rdata;

    // ---------------- Pose read port ----------------
    logic [4:0]  pose_raddr;
    logic [7:0]  pose_rdata;
    logic        pose_rd_en;     // TB 전용 마커 (DUT 에는 연결 안 됨)

    // ---------------- White-box probes (tb_top 에서 assign) ----------------
    logic        hidden_we;
    logic        hidden_wbank;
    logic [6:0]  hidden_waddr;
    logic [7:0]  hidden_wdata;
    logic        pose_we;
    logic [4:0]  pose_waddr;
    logic [7:0]  pose_wdata;
    logic        rq_valid;
    logic [7:0]  rq;
    logic [8:0]  rq_tag;

    // ---------------- Memory models ----------------
    logic [63:0] feat_mem  [FEAT_DEPTH];
    logic [63:0] fcw_mem   [FCW_DEPTH];
    logic [95:0] param_mem [PARAM_DEPTH];
    logic [7:0]  lut_mem   [LUT_DEPTH];

    // 1-cycle sync read
    always_ff @(posedge clk) begin
        feat_rdata     <= feat_mem[feat_raddr];
        fcw_rdata      <= fcw_mem[fcw_raddr];
        fc_param_rdata <= param_mem[fc_param_raddr];
        fc_lut_rdata   <= lut_mem[fc_lut_raddr];
    end

    // ---------------- Clocking blocks ----------------
    clocking drv_cb @(posedge clk);
        default input #1step output #1;
            output fc_start;
            output fc_sel;
            output fc1_fifo_we;
            output fc1_fifo_wdata;
            output pose_raddr;
            output pose_rd_en;
            input  rst_n;
            input  fc_done;
            input  fc1_fifo_full;
            input  fc1_fifo_empty;
            input  pose_rdata;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
            input rst_n;
            input fc_start;
            input fc_sel;
            input fc_done;
            input fc1_fifo_we;
            input fc1_fifo_full;
            input fc1_fifo_empty;
            input pose_raddr;
            input pose_rdata;
            input pose_rd_en;
            input hidden_we;
            input hidden_wbank;
            input hidden_waddr;
            input hidden_wdata;
            input pose_we;
            input pose_waddr;
            input pose_wdata;
            input rq_valid;
            input rq;
            input rq_tag;
    endclocking

    modport DRV(clocking drv_cb, input clk);
    modport MON(clocking mon_cb, input clk);
endinterface
