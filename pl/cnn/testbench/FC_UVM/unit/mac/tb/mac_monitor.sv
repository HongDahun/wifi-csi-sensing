// ============================================================================
// mac_monitor : 입력 beat(mac_valid) -> in_ap / 출력(acc_valid) -> out_ap
// ============================================================================
class mac_monitor extends uvm_monitor;
    `uvm_component_utils(mac_monitor)

    virtual mac_if                     vif;
    uvm_analysis_port #(mac_beat_item) in_ap, out_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        in_ap  = new("in_ap", this);
        out_ap = new("out_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual mac_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        mac_beat_item t;
        longint cyc = 0;
        forever begin
            @(vif.mon_cb);
            cyc++;
            if (vif.mon_cb.rst_n !== 1'b1) continue;
            if (vif.mon_cb.mac_valid) begin
                t = mac_beat_item::type_id::create("in");
                t.act = vif.mon_cb.act_data;   t.wgt  = vif.mon_cb.weight_data;
                t.first = vif.mon_cb.mac_first; t.last = vif.mon_cb.mac_last;
                t.tag = vif.mon_cb.mac_tag;    t.cyc  = cyc;
                in_ap.write(t);
            end
            if (vif.mon_cb.acc_valid) begin
                t = mac_beat_item::type_id::create("out");
                t.acc = vif.mon_cb.acc;  t.tag = vif.mon_cb.acc_tag;  t.cyc = cyc;
                out_ap.write(t);
            end
        end
    endtask
endclass
