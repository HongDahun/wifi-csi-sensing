import uvm_pkg::*;
import fc_pkg::*;

module tb_top ();
    logic clk;

    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    fc_if fif(.clk(clk));

    // ---------------- DUT ----------------
    fc_top dut (
        .clk            (fif.clk),
        .rst_n          (fif.rst_n),
        .fc_start       (fif.fc_start),
        .fc_sel         (fif.fc_sel),
        .fc_done        (fif.fc_done),
        .feat_raddr     (fif.feat_raddr),
        .feat_rdata     (fif.feat_rdata),
        .fc1_fifo_we    (fif.fc1_fifo_we),
        .fc1_fifo_wdata (fif.fc1_fifo_wdata),
        .fc1_fifo_full  (fif.fc1_fifo_full),
        .fc1_fifo_empty (fif.fc1_fifo_empty),
        .fcw_raddr      (fif.fcw_raddr),
        .fcw_rdata      (fif.fcw_rdata),
        .fc_param_raddr (fif.fc_param_raddr),
        .fc_param_rdata (fif.fc_param_rdata),
        .fc_lut_raddr   (fif.fc_lut_raddr),
        .fc_lut_rdata   (fif.fc_lut_rdata),
        .pose_raddr     (fif.pose_raddr),
        .pose_rdata     (fif.pose_rdata)
    );

    // ---------------- White-box probes ----------------
    assign fif.hidden_we    = dut.hidden_we;
    assign fif.hidden_wbank = dut.hidden_wbank;
    assign fif.hidden_waddr = dut.hidden_waddr;
    assign fif.hidden_wdata = dut.hidden_wdata;
    assign fif.pose_we      = dut.pose_we;
    assign fif.pose_waddr   = dut.pose_waddr;
    assign fif.pose_wdata   = dut.pose_wdata;
    assign fif.rq_valid     = dut.rq_valid;
    assign fif.rq           = dut.rq;
    assign fif.rq_tag       = dut.rq_tag;

    // ---------------- Assertions ----------------
    bind fc_top fc_sva u_fc_sva (
        .clk            (clk),
        .rst_n          (rst_n),
        .fc_start       (fc_start),
        .fc_sel         (fc_sel),
        .fc_done        (fc_done),
        .fc1_fifo_we    (fc1_fifo_we),
        .fc1_fifo_full  (fc1_fifo_full),
        .fc1_fifo_empty (fc1_fifo_empty),
        .fifo_re        (fifo_re),
        .mac_valid      (mac_valid),
        .mac_first      (mac_first),
        .mac_last       (mac_last),
        .acc_valid      (acc_valid),
        .rq_valid       (rq_valid),
        .pose_we        (pose_we),
        .pose_waddr     (pose_waddr),
        .feat_raddr     (feat_raddr),
        .fcw_raddr      (fcw_raddr),
        .fc_param_raddr (fc_param_raddr)
    );

    // ---------------- Reset & init ----------------
    initial begin
        fif.rst_n          = 1'b0;
        fif.fc_start       = 1'b0;
        fif.fc_sel         = 2'd0;
        fif.fc1_fifo_we    = 1'b0;
        fif.fc1_fifo_wdata = '0;
        fif.pose_raddr     = '0;
        fif.pose_rd_en     = 1'b0;
        repeat (10) @(posedge clk);
        fif.rst_n <= 1'b1;
    end

    // ---------------- UVM ----------------
    initial begin
        uvm_config_db#(virtual fc_if)::set(null, "*", "vif", fif);
        uvm_top.set_timeout(200ms, 0);
        run_test("fc_smoke_test");
    end

    // ---------------- Waveform (Verdi) ----------------
    //   실행 시 +FSDB_FILE=xxx.fsdb 로 파일명 지정 (기본 fc_tb.fsdb)
    initial begin
        string fname;
        if (!$value$plusargs("FSDB_FILE=%s", fname)) fname = "fc_tb.fsdb";
        $fsdbDumpfile(fname);
        $fsdbDumpvars(0, tb_top);
    end
endmodule
