// ============================================================================
// ff_wr_driver : phase 동안 pct% 확률로 we 구동 (full 여부와 무관)
//  - 데이터 = {랜덤 32bit, 증가 카운터 32bit} (디버그 쉬움)
// ============================================================================
class ff_wr_driver extends uvm_driver #(ff_phase_item);
    `uvm_component_utils(ff_wr_driver)

    ff_vif     vif;
    bit [63:0] cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(ff_vif)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        vif.wr_cb.we <= 0;
        forever begin
            seq_item_port.try_next_item(req);
            if (req == null) begin vif.wr_cb.we <= 0; @(vif.wr_cb); continue; end
            repeat (req.cycles) begin
                vif.wr_cb.we    <= ($urandom_range(99) < req.pct);
                vif.wr_cb.wdata <= {$urandom, 32'(cnt)};
                cnt++;
                @(vif.wr_cb);
            end
            seq_item_port.item_done();
        end
    endtask
endclass

// ============================================================================
// ff_rd_driver : phase 동안 pct% 확률로 re 구동 (empty 여부와 무관)
// ============================================================================
class ff_rd_driver extends uvm_driver #(ff_phase_item);
    `uvm_component_utils(ff_rd_driver)

    ff_vif vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(ff_vif)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        vif.rd_cb.re <= 0;
        forever begin
            seq_item_port.try_next_item(req);
            if (req == null) begin vif.rd_cb.re <= 0; @(vif.rd_cb); continue; end
            repeat (req.cycles) begin
                vif.rd_cb.re <= ($urandom_range(99) < req.pct);
                @(vif.rd_cb);
            end
            seq_item_port.item_done();
        end
    endtask
endclass
