// ============================================================================
// fc_coverage : 기능 커버리지
//   cg_rq    : 레이어 x requant 출력 구간 (포화 ±127 포함, -128 은 illegal)
//   cg_start : fc_sel x (idle / busy 중 start)
//   cg_fifo  : full, full 상태 쓰기(backpressure), FC1 중 starvation
// ============================================================================
class fc_coverage extends uvm_subscriber #(fc_obs_item);
    `uvm_component_utils(fc_coverage)

    virtual fc_if vif;

    bit       busy;
    bit [1:0] cur_sel;

    covergroup cg_rq with function sample(bit [1:0] layer, byte val);
        option.per_instance = 1;

        cp_layer : coverpoint layer {
            bins fc1 = {0};
            bins fc2 = {1};
            bins fc3 = {2};
        }

        cp_val : coverpoint val {
            bins sat_neg = {-127};
            bins neg     = {[-126:-1]};
            bins zero    = {0};
            bins pos     = {[1:126]};
            bins sat_pos = {127};
            illegal_bins minus128 = {-128};
        }

        x_layer_val : cross cp_layer, cp_val;
    endgroup

    covergroup cg_start with function sample(bit [1:0] sel, bit busy_now);
        option.per_instance = 1;

        cp_sel : coverpoint sel {
            bins fc1     = {0};
            bins fc2     = {1};
            bins fc3     = {2};
            bins illegal = {3};
        }

        cp_busy : coverpoint busy_now {
            bins idle = {0};
            bins busy = {1};
        }

        x_sel_busy : cross cp_sel, cp_busy;
    endgroup

    covergroup cg_fifo with function sample(bit full, bit full_we, bit starve);
        option.per_instance = 1;

        cp_full   : coverpoint full    { bins hit = {1}; }
        cp_bp     : coverpoint full_we { bins hit = {1}; }
        cp_starve : coverpoint starve  { bins hit = {1}; }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_rq    = new();
        cg_start = new();
        cg_fifo  = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db #(virtual fc_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface(vif)를 config_db에서 찾지 못함")
    endfunction

    function void write(fc_obs_item t);
        if (t.kind == fc_obs_item::OBS_RQ)
            cg_rq.sample(t.tag[8:7], t.data);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(vif.mon_cb);

            if (vif.mon_cb.rst_n !== 1'b1) begin
                busy = 0;
                continue;
            end

            if (vif.mon_cb.fc_start) begin
                cg_start.sample(vif.mon_cb.fc_sel, busy);
                if (!busy && vif.mon_cb.fc_sel != 2'd3) begin
                    busy    = 1;
                    cur_sel = vif.mon_cb.fc_sel;
                end
            end

            if (vif.mon_cb.fc_done) busy = 0;

            cg_fifo.sample(vif.mon_cb.fc1_fifo_full,
                           vif.mon_cb.fc1_fifo_full && vif.mon_cb.fc1_fifo_we,
                           busy && (cur_sel == SEL_FC1) && vif.mon_cb.fc1_fifo_empty);
        end
    endtask

    function void report_phase(uvm_phase phase);
        real total;

        super.report_phase(phase);

        total = (cg_rq.get_inst_coverage() + cg_start.get_inst_coverage()
                 + cg_fifo.get_inst_coverage()) / 3.0;

        `uvm_info("COV", "==============================", UVM_NONE)
        `uvm_info("COV", "=== Functional Coverage ===", UVM_NONE)
        `uvm_info("COV", $sformatf("전체      : %6.2f %%", total), UVM_NONE)
        `uvm_info("COV", $sformatf("cg_rq     : %6.2f %%", cg_rq.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("cg_start  : %6.2f %%", cg_start.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("cg_fifo   : %6.2f %%", cg_fifo.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", "==============================", UVM_NONE)

        if (total < 100.0) begin
            `uvm_warning("COV", "Coverage 100% 미달. 테스트별 커버리지는 make regress 로 머지해서 확인")
        end
    endfunction

endclass
