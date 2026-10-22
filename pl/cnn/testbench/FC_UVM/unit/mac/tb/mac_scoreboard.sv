// ============================================================================
// mac_scoreboard
//   - beat 마다 fc_lane_sum 누산 (first 에서 초기화) -> last 에서 기대값 큐
//   - 출력과 순서대로 비교 : acc + tag(first beat 의 tag) + latency(MAC_LATENCY)
//   - 기능 커버리지 (그룹 길이, 버블, back-to-back, acc 크기)
// ============================================================================
`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class mac_scoreboard extends uvm_component;
    `uvm_component_utils(mac_scoreboard)

    uvm_analysis_imp_in  #(mac_beat_item, mac_scoreboard) in_imp;
    uvm_analysis_imp_out #(mac_beat_item, mac_scoreboard) out_imp;

    mac_beat_item exp_q[$];
    int        cur_acc;
    bit [8:0]  cur_tag;
    int        cur_len;
    longint    last_end_cyc = -10;
    bit        gap_in_group;
    bit        b2b_now;
    longint    prev_beat_cyc;
    int        n_chk, n_err;

    covergroup cg with function sample(int len, bit gapped, bit b2b, int acc);
        option.per_instance = 1;
        cp_len : coverpoint len {
            bins one = {1}; bins short_ = {[2:15]}; bins fc23 = {16};
            bins mid = {[17:639]}; bins fc1 = {640}; bins long_ = {[641:$]};
        }
        cp_gap : coverpoint gapped { bins bubbles = {1}; bins dense = {0}; }
        cp_b2b : coverpoint b2b    { bins back_to_back = {1}; }
        cp_acc : coverpoint acc {
            bins big_neg = {[$:-16777216]}; bins neg = {[-16777215:-1]}; bins zero = {0};
            bins pos = {[1:16777215]};      bins big_pos = {[16777216:$]};
        }
        x_len_gap : cross cp_len, cp_gap;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        in_imp  = new("in_imp", this);
        out_imp = new("out_imp", this);
        cg = new();
    endfunction

    function void write_in(mac_beat_item t);
        mac_beat_item e;
        int s = fc_lane_sum(t.act, t.wgt);
        if (t.first) begin
            cur_acc = s;  cur_tag = t.tag;  cur_len = 1;
            gap_in_group = 0;
            b2b_now = (t.cyc - last_end_cyc) == 1;
        end else begin
            cur_acc += s;  cur_len++;          // int 32bit wrap = ACC_WIDTH 32 과 동일
            if (t.cyc - prev_beat_cyc > 1) gap_in_group = 1;
        end
        prev_beat_cyc = t.cyc;
        if (t.last) begin
            e = mac_beat_item::type_id::create("exp");
            e.acc = cur_acc;  e.tag = cur_tag;  e.cyc = t.cyc;
            exp_q.push_back(e);
            cg.sample(cur_len, gap_in_group, b2b_now, cur_acc);
            last_end_cyc = t.cyc;
        end
    endfunction

    function void write_out(mac_beat_item t);
        mac_beat_item e;
        n_chk++;
        if (exp_q.size() == 0) begin
            n_err++;
            `uvm_error("MAC_SB", $sformatf("unexpected acc_valid acc=%0d tag=0x%03h", t.acc, t.tag))
            return;
        end
        e = exp_q.pop_front();
        if (t.acc !== e.acc || t.tag !== e.tag || (t.cyc - e.cyc) != MAC_LATENCY) begin
            n_err++;
            if (n_err <= 20)
                `uvm_error("MAC_SB", $sformatf("DUT acc=%0d tag=0x%03h lat=%0d | REF acc=%0d tag=0x%03h lat=%0d",
                    $signed(t.acc), t.tag, t.cyc - e.cyc, e.acc, e.tag, MAC_LATENCY))
        end
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (exp_q.size() != 0)
            `uvm_error("MAC_SB", $sformatf("%0d groups without output", exp_q.size()))
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("MAC_SB", $sformatf("groups=%0d mismatches=%0d coverage=%0.1f%%",
                                      n_chk, n_err, cg.get_inst_coverage()), UVM_NONE)
    endfunction
endclass
