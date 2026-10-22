package fc_pkg;
    import uvm_pkg::*;
    import fc_ref_pkg::*;   // fc_requant, fc_lut_addr (golden 함수)
    `include "uvm_macros.svh"

    // ---------------- DUT Geometry (fc_top 기본 파라미터와 일치) ----------------
    localparam int RX_NUM       = 5;
    localparam int WORDS_PER_RX = 128;
    localparam int FLAT_WORDS   = RX_NUM * WORDS_PER_RX;  // 640 word (64bit)
    localparam int N_IN1        = FLAT_WORDS * 8;         // 5120 int8 입력
    localparam int N_H1         = 128;                    // FC1 출력
    localparam int N_H2         = 128;                    // FC2 출력
    localparam int N_OUT        = 24;                     // FC3 출력 (pose)
    localparam int GROUPS23     = 16;                     // FC2/FC3 : 128 / 8

    localparam int FC2_W_BASE   = 0;
    localparam int FC3_W_BASE   = 2048;
    localparam int FC1_P_BASE   = 0;
    localparam int FC2_P_BASE   = 128;
    localparam int FC3_P_BASE   = 256;

    localparam bit [1:0] SEL_FC1 = 2'd0;
    localparam bit [1:0] SEL_FC2 = 2'd1;
    localparam bit [1:0] SEL_FC3 = 2'd2;

    `include "fc_cfg.sv"
    `include "fc_seq_item.sv"
    `include "fc_sequence.sv"
    `include "fc_ref_model.sv"
    `include "fc_driver.sv"
    `include "fc_monitor.sv"
    `include "fc_agent.sv"
    `include "fc_scoreboard.sv"
    `include "fc_coverage.sv"
    `include "fc_env.sv"
    `include "fc_test.sv"
endpackage
