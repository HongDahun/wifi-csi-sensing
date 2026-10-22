// ============================================================================
// ff_env : wr/rd sequencer + driver, monitor, scoreboard
// ============================================================================
class ff_env extends uvm_env;
    `uvm_component_utils(ff_env)

    uvm_sequencer #(ff_phase_item) wr_sqr, rd_sqr;
    ff_wr_driver  wr_drv;
    ff_rd_driver  rd_drv;
    ff_monitor    mon;
    ff_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        wr_sqr = uvm_sequencer#(ff_phase_item)::type_id::create("wr_sqr", this);
        rd_sqr = uvm_sequencer#(ff_phase_item)::type_id::create("rd_sqr", this);
        wr_drv = ff_wr_driver ::type_id::create("wr_drv", this);
        rd_drv = ff_rd_driver ::type_id::create("rd_drv", this);
        mon    = ff_monitor   ::type_id::create("mon", this);
        sb     = ff_scoreboard::type_id::create("sb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        wr_drv.seq_item_port.connect(wr_sqr.seq_item_export);
        rd_drv.seq_item_port.connect(rd_sqr.seq_item_export);
        mon.ap.connect(sb.analysis_export);
    endfunction
endclass
