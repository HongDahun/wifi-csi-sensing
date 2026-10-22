import uvm_pkg::*;
import mac_pkg::*;

module tb_top ();
    logic clk;

    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    mac_if vif(.clk(clk));

    // ---------------- DUT ----------------
    fc_mac #(.ACC_WIDTH(32), .TAG_WIDTH(9)) dut (
        .clk         (clk),
        .rst_n       (vif.rst_n),
        .act_data    (vif.act_data),
        .weight_data (vif.weight_data),
        .mac_valid   (vif.mac_valid),
        .mac_first   (vif.mac_first),
        .mac_last    (vif.mac_last),
        .mac_tag     (vif.mac_tag),
        .acc         (vif.acc),
        .acc_valid   (vif.acc_valid),
        .acc_tag     (vif.acc_tag)
    );

    // ---------------- Reset & init ----------------
    initial begin
        vif.rst_n = 0; vif.mac_valid = 0; vif.mac_first = 0; vif.mac_last = 0;
        vif.act_data = 0; vif.weight_data = 0; vif.mac_tag = 0;
        repeat (5) @(posedge clk);
        vif.rst_n <= 1;
    end

    // ---------------- UVM ----------------
    initial begin
        uvm_config_db#(virtual mac_if)::set(null, "*", "vif", vif);
        run_test("mac_rand_test");
    end

    // ---------------- Waveform (Verdi) ----------------
    //   실행 시 +FSDB_FILE=xxx.fsdb 로 파일명 지정 (기본 mac_tb.fsdb)
    initial begin
        string fname;
        if (!$value$plusargs("FSDB_FILE=%s", fname)) fname = "mac_tb.fsdb";
        $fsdbDumpfile(fname);
        $fsdbDumpvars(0, tb_top);
    end
endmodule
