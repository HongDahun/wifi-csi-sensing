// ============================================================================
// ff_pkg : fc_fifo 유닛 UVM 환경
//   wr / rd 드라이버가 서로 독립적으로 확률 구동 (full/empty 무시하고도 구동
//   -> full 시 쓰기 버림, empty 시 읽기 무시가 맞는지 확인)
//   scoreboard 는 cycle-accurate 큐 모델 : 매 클럭 full/empty/rdata(FWFT) 비교
// ============================================================================
package ff_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef virtual ff_if #(64) ff_vif;

    `include "ff_seq_item.sv"
    `include "ff_sequence.sv"
    `include "ff_driver.sv"
    `include "ff_monitor.sv"
    `include "ff_scoreboard.sv"
    `include "ff_env.sv"
    `include "ff_test.sv"
endpackage
