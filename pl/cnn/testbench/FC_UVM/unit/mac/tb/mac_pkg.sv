// ============================================================================
// mac_pkg : fc_mac 유닛 UVM 환경
//   item = 출력 1개(그룹) : len 개 beat, first=첫 beat, last=마지막 beat
//   - beat 사이 버블(valid=0) 에는 data/first/last/tag 에 쓰레기값
//   - first 가 아닌 beat 의 tag 도 쓰레기값 (acc_tag 는 first beat 의 tag 여야 함)
//   - len=1 (first=last 동시) 포함 : fc_top 에서는 안 나오는 경로
//   scoreboard : beat 를 받아 lane 합 누산 -> 기대 acc/tag, latency 4 확인
// ============================================================================
package mac_pkg;
    import uvm_pkg::*;
    import fc_ref_pkg::*;   // fc_lane_sum (golden 함수)
    `include "uvm_macros.svh"

    localparam int MAC_LATENCY = 4;   // last beat -> acc_valid

    `include "mac_seq_item.sv"
    `include "mac_sequence.sv"
    `include "mac_driver.sv"
    `include "mac_monitor.sv"
    `include "mac_scoreboard.sv"
    `include "mac_env.sv"
    `include "mac_test.sv"
endpackage
