import uvm_pkg::*;
import ff_pkg::*;

module tb_top ();
`ifndef FIFO_DEPTH
    `define FIFO_DEPTH 512
`endif
    localparam int DEPTH = `FIFO_DEPTH;

    logic clk;

    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    ff_if #(64) vif(.clk(clk));

    // ---------------- DUT ----------------
    fc_fifo #(.DATA_WIDTH(64), .DEPTH(DEPTH)) dut (
        .clk        (clk),
        .rst_n      (vif.rst_n),
        .fifo_we    (vif.we),
        .fifo_wdata (vif.wdata),
        .fifo_full  (vif.full),
        .fifo_re    (vif.re),
        .fifo_rdata (vif.rdata),
        .fifo_empty (vif.empty)
    );

    // ---------------- Reset & init ----------------
    initial begin
        vif.rst_n = 0; vif.we = 0; vif.re = 0; vif.wdata = 0;
        repeat (5) @(posedge clk);
        vif.rst_n <= 1;
    end

    // ---------------- UVM ----------------
    initial begin
        uvm_config_db#(ff_vif)::set(null, "*", "vif", vif);
        uvm_config_db#(int)::set(null, "*", "depth", DEPTH);
        run_test("ff_rand_test");
    end

    // ---------------- Waveform (Verdi) ----------------
    //   실행 시 +FSDB_FILE=xxx.fsdb 로 파일명 지정 (기본 ff_tb.fsdb)
    initial begin
        string fname;
        if (!$value$plusargs("FSDB_FILE=%s", fname)) fname = "ff_tb.fsdb";
        $fsdbDumpfile(fname);
        $fsdbDumpvars(0, tb_top);
    end
endmodule
