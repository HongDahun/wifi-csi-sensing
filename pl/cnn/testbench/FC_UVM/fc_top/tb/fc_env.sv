// ============================================================================
// fc_env
//   monitor 는 두 agent 를 가로질러 DUT 화이트박스 신호까지 보므로 env 에 둔다
// ============================================================================
class fc_env extends uvm_env;
    `uvm_component_utils(fc_env)

    fc_ctrl_agent ctrl_agt;
    fc_fifo_agent fifo_agt;
    fc_monitor    mon;
    fc_scoreboard scb;
    fc_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ctrl_agt = fc_ctrl_agent::type_id::create("ctrl_agt", this);
        fifo_agt = fc_fifo_agent::type_id::create("fifo_agt", this);
        mon      = fc_monitor::type_id::create("mon", this);
        scb      = fc_scoreboard::type_id::create("scb", this);
        cov      = fc_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon.ap.connect(scb.imp);
        mon.ap.connect(cov.analysis_export);
    endfunction
endclass
