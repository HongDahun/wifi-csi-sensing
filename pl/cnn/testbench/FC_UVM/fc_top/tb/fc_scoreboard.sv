// ============================================================================
// fc_scoreboard
//   - rq(requant 출력) / hidden write / pose write / pose read 를 ref model 과 비교
//   - hidden write 주소가 0,1,2,...,127 순서로 오는지 확인
//   - 인퍼런스 1회마다 이벤트 개수 확인 (check_inference)
// ============================================================================
class fc_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(fc_scoreboard)

    uvm_analysis_imp #(fc_obs_item, fc_scoreboard) imp;

    fc_ref_model rm;
    bit          armed;

    // per-inference counters
    int n_rq [3];
    int n_hid[2];
    int n_pwr, n_prd, n_done;

    // global
    int n_chk, n_err, n_infer_ok, n_infer;
    int max_err_print = 20;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        imp = new("imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        rm = fc_ref_model::type_id::create("rm");
    endfunction

    // 테스트가 데이터셋을 새로 만들 때마다 호출
    function void set_expected(fc_cfg cfg);
        rm.compute(cfg);
        armed  = 1;
        n_rq   = '{0, 0, 0};
        n_hid  = '{0, 0};
        n_pwr  = 0;
        n_prd  = 0;
        n_done = 0;
    endfunction

    function void cmp(string what, int addr, byte act, byte exp);
        n_chk++;
        if (act !== exp) begin
            n_err++;
            if (n_err <= max_err_print)
                `uvm_error("SB_MISMATCH",
                    $sformatf("%s[%0d] : DUT=%0d  REF=%0d", what, addr, act, exp))
        end
    endfunction

    function void write(fc_obs_item t);
        int       idx;
        bit [1:0] layer;

        if (!armed) return;

        case (t.kind)
            fc_obs_item::OBS_RQ: begin
                layer = t.tag[8:7];
                idx   = int'(t.tag[6:0]);
                case (layer)
                    SEL_FC1: begin n_rq[0]++; cmp("FC1.rq", idx, t.data, rm.rq1[idx]); end
                    SEL_FC2: begin n_rq[1]++; cmp("FC2.rq", idx, t.data, rm.rq2[idx]); end
                    SEL_FC3: begin
                        n_rq[2]++;
                        if (idx < N_OUT) cmp("FC3.rq", idx, t.data, rm.pose[idx]);
                        else `uvm_error("SB_TAG", $sformatf("FC3 rq tag index %0d >= %0d", idx, N_OUT))
                    end
                    default: `uvm_error("SB_TAG", $sformatf("illegal rq_tag layer 3 (tag=0x%03h)", t.tag))
                endcase
            end

            fc_obs_item::OBS_HIDDEN_WR: begin
                if (t.addr != n_hid[t.bank])
                    `uvm_error("SB_ORDER", $sformatf("hidden bank%0d write addr=%0d, expected %0d",
                                                     t.bank, t.addr, n_hid[t.bank]))
                n_hid[t.bank]++;
                if (t.bank == 0) cmp("FC1.gelu(bank0)", t.addr, t.data, rm.h1[t.addr]);
                else             cmp("FC2.gelu(bank1)", t.addr, t.data, rm.h2[t.addr]);
            end

            fc_obs_item::OBS_POSE_WR: begin
                n_pwr++;
                if (t.addr < N_OUT) cmp("pose_wr", t.addr, t.data, rm.pose[t.addr]);
                else `uvm_error("SB_ADDR", $sformatf("pose write addr %0d out of range", t.addr))
            end

            fc_obs_item::OBS_POSE_RD: begin
                n_prd++;
                if (t.addr < N_OUT) cmp("pose_rd", t.addr, t.data, rm.pose[t.addr]);
            end

            fc_obs_item::OBS_DONE: n_done++;

            default: ;
        endcase
    endfunction

    function void chk_cnt(string what, int act, int exp, ref bit ok);
        if (act != exp) begin
            ok = 0;
            `uvm_error("SB_COUNT", $sformatf("%s count = %0d, expected %0d", what, act, exp))
        end
    endfunction

    // 인퍼런스 1회 (FC1 -> FC2 -> FC3 -> pose read) 끝난 뒤 호출
    function void check_inference(int idx, int exp_done = 3);
        bit ok = 1;

        n_infer++;
        chk_cnt("FC1 rq",       n_rq[0],  N_H1,     ok);
        chk_cnt("FC2 rq",       n_rq[1],  N_H2,     ok);
        chk_cnt("FC3 rq",       n_rq[2],  N_OUT,    ok);
        chk_cnt("hidden bank0", n_hid[0], N_H1,     ok);
        chk_cnt("hidden bank1", n_hid[1], N_H2,     ok);
        chk_cnt("pose write",   n_pwr,    N_OUT,    ok);
        chk_cnt("pose read",    n_prd,    N_OUT,    ok);
        chk_cnt("fc_done",      n_done,   exp_done, ok);

        if (ok && n_err == 0) n_infer_ok++;

        `uvm_info("SB", $sformatf("inference #%0d : %s (checks so far=%0d, errors=%0d)",
                                  idx, (ok && n_err == 0) ? "OK" : "FAIL", n_chk, n_err), UVM_LOW)
        armed = 0;
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("SB", "=====================================", UVM_NONE)
        `uvm_info("SB", "======= Scoreboard 최종 리포트 =======", UVM_NONE)
        `uvm_info("SB", $sformatf("  inference  : %0d (ok %0d)", n_infer, n_infer_ok), UVM_NONE)
        `uvm_info("SB", $sformatf("  compares   : %0d", n_chk), UVM_NONE)
        `uvm_info("SB", $sformatf("  mismatches : %0d", n_err), UVM_NONE)
        `uvm_info("SB", "=====================================", UVM_NONE)

        if (n_err == 0 && n_chk > 0 && n_infer == n_infer_ok)
            `uvm_info("SB", "*** SCOREBOARD PASSED ***", UVM_NONE)
        else
            `uvm_error("SB", "*** SCOREBOARD FAILED ***")
    endfunction

endclass
