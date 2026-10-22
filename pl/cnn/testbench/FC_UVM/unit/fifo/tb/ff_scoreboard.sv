// ============================================================================
// ff_scoreboard : cycle-accurate 큐 모델
//   클럭 k 샘플 = 엣지 k 직전 상태 -> 모델(엣지 전 상태)과 플래그/rdata 비교 후
//   엣지 k 에서 일어나는 push/pop/reset 을 모델에 반영
// ============================================================================
class ff_scoreboard extends uvm_subscriber #(ff_cycle_item);
    `uvm_component_utils(ff_scoreboard)

    int        depth;
    bit [63:0] q[$];
    bit        seen_reset;
    int        n_chk, n_err, n_push, n_pop, n_drop_wr, n_drop_rd;

    // cnt_cat : 0,1,2 / 3=중간 / 4=depth-1 / 5=full
    covergroup cg with function sample(int cc, bit we, bit re, bit wrapped);
        option.per_instance = 1;
        cp_cnt : coverpoint cc {
            bins c0 = {0}; bins c1 = {1}; bins c2 = {2};
            bins mid = {3}; bins almost_full = {4}; bins full = {5};
        }
        cp_op : coverpoint {we, re} {
            bins idle = {2'b00}; bins wr = {2'b10}; bins rd = {2'b01}; bins both = {2'b11};
        }
        x_cnt_op : cross cp_cnt, cp_op;      // full+wr(버림), c0+rd(무시), c1+both(head 교체) 포함
        cp_wrap : coverpoint wrapped { bins wrapped = {1}; }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(int)::get(this, "", "depth", depth)) depth = 512;
    endfunction

    function int cnt_cat(int c);
        if (c <= 2)              return c;
        else if (c == depth)     return 5;
        else if (c == depth - 1) return 4;
        else                     return 3;
    endfunction

    function void err(string msg);
        n_err++;
        if (n_err <= 20) `uvm_error("FF_SB", msg)
    endfunction

    function void write(ff_cycle_item t);
        bit push, pop;
        if (!t.rst_n) begin         // 동기 리셋 : 이 엣지에서 비워짐
            q.delete();
            seen_reset = 1;
            return;
        end
        if (!seen_reset) return;

        // ---- 플래그 / 데이터 체크 (엣지 전 상태) ----
        n_chk++;
        if (t.full  !== (q.size() == depth)) err($sformatf("full=%0b but model count=%0d", t.full, q.size()));
        if (t.empty !== (q.size() == 0))     err($sformatf("empty=%0b but model count=%0d", t.empty, q.size()));
        if (q.size() > 0 && t.rdata !== q[0])
            err($sformatf("FWFT rdata=0x%016h expected 0x%016h (count=%0d)", t.rdata, q[0], q.size()));

        cg.sample(cnt_cat(q.size()), t.we, t.re, n_push > depth);

        // ---- 엣지에서의 동작 반영 ----
        push = t.we && (q.size() < depth);
        pop  = t.re && (q.size() > 0);
        if (t.we && !push) n_drop_wr++;
        if (t.re && !pop)  n_drop_rd++;
        if (pop)  begin q.pop_front(); n_pop++; end
        if (push) begin q.push_back(t.wdata); n_push++; end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("FF_SB", $sformatf("cycles=%0d push=%0d pop=%0d dropped_wr(full)=%0d ignored_rd(empty)=%0d mismatches=%0d coverage=%0.1f%%",
            n_chk, n_push, n_pop, n_drop_wr, n_drop_rd, n_err, cg.get_inst_coverage()), UVM_NONE)
    endfunction
endclass
