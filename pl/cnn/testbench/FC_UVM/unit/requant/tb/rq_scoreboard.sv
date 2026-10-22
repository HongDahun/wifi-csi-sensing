// ============================================================================
// rq_scoreboard
//   - 입력마다 fc_requant(수학 스펙) 로 기대값 계산 -> 큐
//   - 출력과 순서대로 비교 : rq 값 + tag + latency(RQ_LATENCY)
//   - 기능 커버리지 (shift 범위, 출력 값, tie, 부호, back-to-back)
// ============================================================================
`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class rq_scoreboard extends uvm_component;
    `uvm_component_utils(rq_scoreboard)

    uvm_analysis_imp_in  #(rq_item, rq_scoreboard) in_imp;
    uvm_analysis_imp_out #(rq_item, rq_scoreboard) out_imp;
    rq_item exp_q[$];
    int n_chk, n_err;

    // coverage
    covergroup cg with function sample(int shift, byte y, bit tie, bit neg, bit b2b);
        option.per_instance = 1;
        cp_shift : coverpoint shift {
            bins neg    = {[$:-1]};
            bins zero   = {0};
            bins sh_small = {[1:15]};
            bins sh_mid   = {[16:31]};
            bins sh_large = {[32:63]};
            bins sh_huge  = {[64:$]};
        }
        cp_y : coverpoint y {
            bins sat_neg = {-127}; bins neg = {[-126:-1]}; bins zero = {0};
            bins pos = {[1:126]};  bins sat_pos = {127};
            illegal_bins m128 = {-128};
        }
        cp_tie  : coverpoint tie { bins tie = {1}; }
        cp_sign : coverpoint neg;
        cp_b2b  : coverpoint b2b { bins back_to_back = {1}; }
        x_tie_sign : cross cp_tie, cp_sign;
    endgroup
    longint last_in_cyc = -10;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        in_imp  = new("in_imp", this);
        out_imp = new("out_imp", this);
        cg = new();
    endfunction

    function void write_in(rq_item t);
        bit [95:0] p;
        p    = t.param();
        t.rq = fc_requant(t.acc, p);
        cg.sample(t.shift, t.rq, fc_requant_is_tie(t.acc, p),
                  fc_rq_prod(t.acc, p) < 0, (t.cyc - last_in_cyc) == 1);
        last_in_cyc = t.cyc;
        exp_q.push_back(t);
    endfunction

    function void write_out(rq_item t);
        rq_item e;
        n_chk++;
        if (exp_q.size() == 0) begin
            n_err++;
            `uvm_error("RQ_SB", $sformatf("unexpected rq_valid (rq=%0d tag=0x%03h)", t.rq, t.tag))
            return;
        end
        e = exp_q.pop_front();
        if (t.rq !== e.rq || t.tag !== e.tag || (t.cyc - e.cyc) != RQ_LATENCY) begin
            n_err++;
            `uvm_error("RQ_SB", $sformatf("%s -> DUT rq=%0d tag=0x%03h lat=%0d | REF rq=%0d tag=0x%03h lat=%0d",
                e.convert2string(), t.rq, t.tag, t.cyc - e.cyc, e.rq, e.tag, RQ_LATENCY))
        end
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (exp_q.size() != 0)
            `uvm_error("RQ_SB", $sformatf("%0d inputs never produced output", exp_q.size()))
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("RQ_SB", $sformatf("compares=%0d mismatches=%0d coverage=%0.1f%%",
                                     n_chk, n_err, cg.get_inst_coverage()), UVM_NONE)
    endfunction
endclass
