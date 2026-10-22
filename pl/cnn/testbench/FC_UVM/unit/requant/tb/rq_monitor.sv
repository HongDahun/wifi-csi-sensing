// ============================================================================
// rq_monitor : 입력(acc, tag + 다음 클럭 param) -> in_ap / 출력(rq, tag) -> out_ap
// ============================================================================
class rq_monitor extends uvm_monitor;
    `uvm_component_utils(rq_monitor)

    virtual rq_if                 vif;
    uvm_analysis_port #(rq_item)  in_ap, out_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        in_ap  = new("in_ap", this);
        out_ap = new("out_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rq_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        rq_item pend, t;
        bit     have = 0;
        longint cyc  = 0;
        forever begin
            @(vif.mon_cb);
            cyc++;
            if (vif.mon_cb.rst_n !== 1'b1) begin have = 0; continue; end
            if (have) begin       // 이전 클럭 acc 의 param
                {pend.shift, pend.mult, pend.bias} = vif.mon_cb.param_rdata;
                in_ap.write(pend);
                have = 0;
            end
            if (vif.mon_cb.acc_valid) begin
                pend      = rq_item::type_id::create("in");
                pend.acc  = vif.mon_cb.acc;
                pend.tag  = vif.mon_cb.acc_tag;
                pend.cyc  = cyc;
                have      = 1;
            end
            if (vif.mon_cb.rq_valid) begin
                t     = rq_item::type_id::create("out");
                t.rq  = vif.mon_cb.rq;
                t.tag = vif.mon_cb.rq_tag;
                t.cyc = cyc;
                out_ap.write(t);
            end
        end
    endtask
endclass
