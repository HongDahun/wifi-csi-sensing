// ============================================================================
// rq_if : requant_core 유닛 인터페이스
//  프로토콜 : param_rdata 는 acc_valid 가 들어간 "다음 클럭"에 유효해야 함
//             (requant_core 가 stage1 에서 param 을 조합으로 사용)
// ============================================================================
interface rq_if (input logic clk);
    logic        rst_n;
    logic [31:0] acc;
    logic        acc_valid;
    logic [8:0]  acc_tag;
    logic [95:0] param_rdata;
    logic [7:0]  rq;
    logic        rq_valid;
    logic [8:0]  rq_tag;

    clocking drv_cb @(posedge clk);
        default input #1step output #1;
        output acc, acc_valid, acc_tag, param_rdata;
        input  rst_n;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input rst_n, acc, acc_valid, acc_tag, param_rdata, rq, rq_valid, rq_tag;
    endclocking
endinterface
