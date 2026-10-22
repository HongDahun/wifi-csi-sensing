// ============================================================================
// rq_pkg : requant_core 유닛 UVM 환경
//   driver     : acc 를 넣고 1클럭 뒤 param 을 넣는 파이프라인 구동,
//                필요 없는 클럭엔 param/acc 에 쓰레기값 (무시되는지 확인)
//   monitor    : 입력(acc, tag + 다음 클럭 param) / 출력(rq, tag)
//   scoreboard : 수학 스펙 ref(fc_requant) 와 비교 + tag + latency(7) 확인
// ============================================================================
package rq_pkg;
    import uvm_pkg::*;
    import fc_ref_pkg::*;   // fc_requant, fc_requant_is_tie, fc_rq_prod (golden 함수)
    `include "uvm_macros.svh"

    localparam int RQ_LATENCY = 7;

    `include "rq_seq_item.sv"
    `include "rq_sequence.sv"
    `include "rq_driver.sv"
    `include "rq_monitor.sv"
    `include "rq_scoreboard.sv"
    `include "rq_env.sv"
    `include "rq_test.sv"
endpackage
