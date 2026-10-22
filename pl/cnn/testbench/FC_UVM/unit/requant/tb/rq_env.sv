// ============================================================================
// rq_env : sequencer + driver + monitor + scoreboard
// ============================================================================
class rq_env extends uvm_env;
    `uvm_component_utils(rq_env)

    uvm_sequencer #(rq_item) sqr;
    rq_driver     drv;
    rq_monitor    mon;
    rq_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(rq_item)::type_id::create("sqr", this);
        drv = rq_driver    ::type_id::create("drv", this);
        mon = rq_monitor   ::type_id::create("mon", this);
        sb  = rq_scoreboard::type_id::create("sb",  this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
        mon.in_ap.connect(sb.in_imp);
        mon.out_ap.connect(sb.out_imp);
    endfunction
endclass
