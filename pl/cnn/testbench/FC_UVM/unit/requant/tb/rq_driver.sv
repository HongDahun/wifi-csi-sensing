// ============================================================================
// rq_driver : acc 를 넣고 1클럭 뒤 그 item 의 param 을 넣는 파이프라인 구동
//  - 필요 없는 클럭엔 param/acc 에 쓰레기값 (DUT 가 무시하는지 확인)
// ============================================================================
class rq_driver extends uvm_driver #(rq_item);
    `uvm_component_utils(rq_driver)

    virtual rq_if vif;
    bit [95:0]    pend;
    bit           pend_v;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rq_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface not found")
    endfunction

    function bit [95:0] garbage96();
        return {$urandom, $urandom, $urandom};
    endfunction

    task idle_cycle();
        vif.drv_cb.acc_valid   <= 1'b0;
        vif.drv_cb.acc         <= $urandom;
        vif.drv_cb.acc_tag     <= $urandom;
        vif.drv_cb.param_rdata <= pend_v ? pend : garbage96();
        pend_v = 0;
        @(vif.drv_cb);
    endtask

    task run_phase(uvm_phase phase);
        vif.drv_cb.acc_valid <= 1'b0;
        wait (vif.rst_n === 1'b1);
        // reset 해제 엣지와 같은 time step 에서 깨어나므로 클럭 1개 정렬
        // (없으면 첫 item 이 같은 time step 의 둘째 item 에 덮어써짐)
        @(vif.drv_cb);
        forever begin
            seq_item_port.try_next_item(req);
            if (req == null) begin idle_cycle(); continue; end
            repeat (req.gap) idle_cycle();
            vif.drv_cb.acc         <= req.acc;
            vif.drv_cb.acc_valid   <= 1'b1;
            vif.drv_cb.acc_tag     <= req.tag;
            vif.drv_cb.param_rdata <= pend_v ? pend : garbage96();   // 이전 item 의 param
            pend   = req.param();
            pend_v = 1;
            @(vif.drv_cb);
            seq_item_port.item_done();
        end
    endtask
endclass
