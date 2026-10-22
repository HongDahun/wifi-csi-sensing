// ============================================================================
// ff_if : fc_fifo 유닛 인터페이스 (FWFT, 동기 리셋)
// ============================================================================
interface ff_if #(parameter int DW = 64) (input logic clk);
    logic          rst_n;
    logic          we, re;
    logic [DW-1:0] wdata, rdata;
    logic          full, empty;

    clocking wr_cb @(posedge clk);
        default input #1step output #1;
        output we, wdata;
        input  rst_n, full;
    endclocking

    clocking rd_cb @(posedge clk);
        default input #1step output #1;
        output re;
        input  rst_n, empty;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input rst_n, we, wdata, re, rdata, full, empty;
    endclocking
endinterface
