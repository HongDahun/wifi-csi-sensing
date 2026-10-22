// ============================================================================
// fc_ctrl_agent : 제어 (fc_start / fc_sel / pose read)
// ============================================================================
class fc_ctrl_agent extends uvm_agent;
    `uvm_component_utils(fc_ctrl_agent)

    uvm_sequencer #(fc_ctrl_item) sqr;
    fc_ctrl_driver drv;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(fc_ctrl_item)::type_id::create("sqr", this);
        drv = fc_ctrl_driver::type_id::create("drv", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

// ============================================================================
// fc_fifo_agent : FC1 웨이트 FIFO 쓰기
// ============================================================================
class fc_fifo_agent extends uvm_agent;
    `uvm_component_utils(fc_fifo_agent)

    uvm_sequencer #(fc_fifo_item) sqr;
    fc_fifo_driver drv;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(fc_fifo_item)::type_id::create("sqr", this);
        drv = fc_fifo_driver::type_id::create("drv", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
