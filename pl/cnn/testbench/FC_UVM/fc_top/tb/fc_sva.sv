`include "uvm_macros.svh"
// ============================================================================
// fc_sva : fc_top 에 bind 되는 프로토콜/범위 assertion
// ============================================================================
module fc_sva (
    input logic        clk,
    input logic        rst_n,
    input logic        fc_start,
    input logic [1:0]  fc_sel,
    input logic        fc_done,
    input logic        fc1_fifo_we,
    input logic        fc1_fifo_full,
    input logic        fc1_fifo_empty,
    input logic        fifo_re,
    input logic        mac_valid,
    input logic        mac_first,
    input logic        mac_last,
    input logic        acc_valid,
    input logic        rq_valid,
    input logic        pose_we,
    input logic [4:0]  pose_waddr,
    input logic [9:0]  feat_raddr,
    input logic [11:0] fcw_raddr,
    input logic [8:0]  fc_param_raddr
);
    import uvm_pkg::*;

    default clocking cb @(posedge clk); endclocking
    default disable iff (!rst_n);

    // ---------------- Control ----------------
    a_done_pulse : assert property (fc_done |=> !fc_done)
        else `uvm_error("SVA", "fc_done asserted longer than 1 cycle")

    a_no_x_ctrl : assert property (!$isunknown({fc_done, mac_valid, acc_valid, rq_valid, pose_we}))
        else `uvm_error("SVA", "X/Z on control/valid signals")

    // ---------------- FIFO ----------------
    a_pop_not_empty : assert property (fifo_re |-> !fc1_fifo_empty)
        else `uvm_error("SVA", "fifo_re while FIFO empty")

    a_full_empty_excl : assert property (!(fc1_fifo_full && fc1_fifo_empty))
        else `uvm_error("SVA", "FIFO full and empty at the same time")

    // ---------------- MAC flags ----------------
    a_flag_needs_valid : assert property ((mac_first || mac_last) |-> mac_valid)
        else `uvm_error("SVA", "mac_first/mac_last without mac_valid")

    // ---------------- Address range ----------------
    a_feat_range : assert property (feat_raddr < 10'd640)
        else `uvm_error("SVA", $sformatf("feat_raddr out of range: %0d", feat_raddr))

    a_fcw_range : assert property (fcw_raddr < 12'd2432)    // FC3 : 2048 + 24*16
        else `uvm_error("SVA", $sformatf("fcw_raddr out of range: %0d", fcw_raddr))

    a_param_range : assert property (acc_valid |-> (fc_param_raddr < 9'd280))  // 256 + 24
        else `uvm_error("SVA", $sformatf("fc_param_raddr out of range: %0d", fc_param_raddr))

    a_pose_waddr : assert property (pose_we |-> (pose_waddr < 5'd24))
        else `uvm_error("SVA", $sformatf("pose_waddr out of range: %0d", pose_waddr))

    // ---------------- Cover ----------------
    c_fifo_full      : cover property ($rose(fc1_fifo_full));
    c_backpressure   : cover property (fc1_fifo_we && fc1_fifo_full);
    c_starve_resume  : cover property (fc1_fifo_empty ##1 fifo_re);
    c_illegal_sel    : cover property (fc_start && fc_sel == 2'd3);
    c_first_and_last : cover property (mac_valid && mac_first && mac_last);  // 1-group 출력 (현재 설정에선 불가)

endmodule
