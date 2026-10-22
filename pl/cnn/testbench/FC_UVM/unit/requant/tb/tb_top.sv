import uvm_pkg::*;
import rq_pkg::*;

module tb_top ();
    logic clk;

    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    rq_if vif(.clk(clk));

    // ---------------- DUT ----------------
    requant_core #(.TAG_WIDTH(9)) dut (
        .clk         (clk),
        .rst_n       (vif.rst_n),
        .acc         (vif.acc),
        .acc_valid   (vif.acc_valid),
        .acc_tag     (vif.acc_tag),
        .param_rdata (vif.param_rdata),
        .rq          (vif.rq),
        .rq_valid    (vif.rq_valid),
        .rq_tag      (vif.rq_tag)
    );

    // ---------------- Reset & init ----------------
    initial begin
        vif.rst_n = 0; vif.acc_valid = 0; vif.acc = 0; vif.acc_tag = 0; vif.param_rdata = 0;
        repeat (5) @(posedge clk);
        vif.rst_n <= 1;
    end

    // ---------------- UVM ----------------
    initial begin
        uvm_config_db#(virtual rq_if)::set(null, "*", "vif", vif);
        run_test("rq_rand_test");
    end

    // ---------------- Waveform (Verdi) ----------------
    //   실행 시 +FSDB_FILE=xxx.fsdb 로 파일명 지정 (기본 rq_tb.fsdb)
    initial begin
        string fname;
        if (!$value$plusargs("FSDB_FILE=%s", fname)) fname = "rq_tb.fsdb";
        $fsdbDumpfile(fname);
        $fsdbDumpvars(0, tb_top);
    end
endmodule
