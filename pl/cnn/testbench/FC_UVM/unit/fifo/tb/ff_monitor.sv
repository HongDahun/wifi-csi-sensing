// ============================================================================
// ff_monitor : 매 클럭 rst_n / we / wdata / re / rdata / full / empty 스냅샷
// ============================================================================
class ff_monitor extends uvm_monitor;
    `uvm_component_utils(ff_monitor)

    ff_vif vif;
    uvm_analysis_port #(ff_cycle_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(ff_vif)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        ff_cycle_item t;
        forever begin
            @(vif.mon_cb);
            t = ff_cycle_item::type_id::create("t");
            t.rst_n = (vif.mon_cb.rst_n === 1'b1);
            t.we    = vif.mon_cb.we;     t.wdata = vif.mon_cb.wdata;
            t.re    = vif.mon_cb.re;     t.rdata = vif.mon_cb.rdata;
            t.full  = vif.mon_cb.full;   t.empty = vif.mon_cb.empty;
            ap.write(t);
        end
    endtask
endclass
