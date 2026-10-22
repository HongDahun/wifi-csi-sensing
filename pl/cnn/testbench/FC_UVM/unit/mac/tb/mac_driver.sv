// ============================================================================
// mac_driver : 그룹 1개를 len 개 beat 로 구동
//  - beat 사이 버블 : valid=0 + data/first/last/tag 쓰레기값
//  - first 가 아닌 beat 의 tag 는 쓰레기값
// ============================================================================
class mac_driver extends uvm_driver #(mac_group_item);
    `uvm_component_utils(mac_driver)

    virtual mac_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual mac_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface not found")
    endfunction

    task bubble();
        vif.drv_cb.mac_valid   <= 1'b0;
        vif.drv_cb.act_data    <= {$urandom, $urandom};
        vif.drv_cb.weight_data <= {$urandom, $urandom};
        vif.drv_cb.mac_first   <= $urandom;
        vif.drv_cb.mac_last    <= $urandom;
        vif.drv_cb.mac_tag     <= $urandom;
        @(vif.drv_cb);
    endtask

    task run_phase(uvm_phase phase);
        vif.drv_cb.mac_valid <= 1'b0;
        wait (vif.rst_n === 1'b1);
        // reset 해제 엣지와 같은 time step 에서 깨어나므로 클럭 1개 정렬
        // (없으면 첫 beat 가 같은 time step 의 다음 구동에 덮어써짐)
        @(vif.drv_cb);
        forever begin
            seq_item_port.try_next_item(req);
            if (req == null) begin bubble(); continue; end
            repeat (req.pre_gap) bubble();
            for (int i = 0; i < req.len; i++) begin
                if (i > 0) while ($urandom_range(99) < req.gap_pct) bubble();
                vif.drv_cb.mac_valid   <= 1'b1;
                vif.drv_cb.act_data    <= req.act[i];
                vif.drv_cb.weight_data <= req.wgt[i];
                vif.drv_cb.mac_first   <= (i == 0);
                vif.drv_cb.mac_last    <= (i == req.len - 1);
                vif.drv_cb.mac_tag     <= (i == 0) ? req.tag : 9'($urandom);
                @(vif.drv_cb);
            end
            seq_item_port.item_done();
        end
    endtask
endclass
