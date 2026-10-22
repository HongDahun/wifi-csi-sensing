// ============================================================================
// mac_env : sequencer + driver + monitor + scoreboard
// ============================================================================
class mac_env extends uvm_env;
    `uvm_component_utils(mac_env)

    uvm_sequencer #(mac_group_item) sqr;
    mac_driver     drv;
    mac_monitor    mon;
    mac_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(mac_group_item)::type_id::create("sqr", this);
        drv = mac_driver    ::type_id::create("drv", this);
        mon = mac_monitor   ::type_id::create("mon", this);
        sb  = mac_scoreboard::type_id::create("sb",  this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
        mon.in_ap.connect(sb.in_imp);
        mon.out_ap.connect(sb.out_imp);
    endfunction
endclass
