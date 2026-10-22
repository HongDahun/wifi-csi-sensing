// ============================================================================
// mac_if : fc_mac 유닛 인터페이스
// ============================================================================
interface mac_if (input logic clk);
    logic        rst_n;
    logic [63:0] act_data, weight_data;
    logic        mac_valid, mac_first, mac_last;
    logic [8:0]  mac_tag;
    logic [31:0] acc;
    logic        acc_valid;
    logic [8:0]  acc_tag;

    clocking drv_cb @(posedge clk);
        default input #1step output #1;
        output act_data, weight_data, mac_valid, mac_first, mac_last, mac_tag;
        input  rst_n;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input rst_n, act_data, weight_data, mac_valid, mac_first, mac_last, mac_tag;
        input acc, acc_valid, acc_tag;
    endclocking
endinterface
