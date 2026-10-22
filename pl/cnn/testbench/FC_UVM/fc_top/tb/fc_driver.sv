// ============================================================================
// fc_ctrl_driver : fc_start / fc_sel 구동, fc_done 대기, pose 버퍼 읽기
// ============================================================================
class fc_ctrl_driver extends uvm_driver #(fc_ctrl_item);

    `uvm_component_utils(fc_ctrl_driver)

    virtual fc_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fc_if)::get(
            this, "", "vif", vif))
            `uvm_fatal(get_type_name(),
                "virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        // 초기화
        vif.drv_cb.fc_start   <= 1'b0;
        vif.drv_cb.fc_sel     <= 2'd0;
        vif.drv_cb.pose_raddr <= 5'd0;
        vif.drv_cb.pose_rd_en <= 1'b0;

        // reset 해제 대기
        wait (vif.rst_n === 1'b1);

        forever begin
            fc_ctrl_item req;
            seq_item_port.get_next_item(req);
            `uvm_info("CTRL_DRV", {"start : ", req.convert2string()}, UVM_HIGH)

            case (req.kind)
                fc_ctrl_item::RUN_LAYER: do_layer(req);
                fc_ctrl_item::READ_POSE: do_pose_read();
            endcase

            seq_item_port.item_done();
        end
    endtask

    // 1-cycle start pulse -> fc_done 대기
    task do_layer(fc_ctrl_item it);
        int unsigned cyc;

        @(vif.drv_cb);
        vif.drv_cb.fc_sel   <= it.sel;
        vif.drv_cb.fc_start <= 1'b1;

        @(vif.drv_cb);
        vif.drv_cb.fc_start <= 1'b0;

        it.done_seen = 0;
        cyc = 0;
        while (cyc < it.timeout) begin
            @(vif.drv_cb);
            cyc++;
            if (vif.drv_cb.fc_done) begin
                it.done_seen = 1;
                break;
            end
        end
        it.latency = cyc;

        if (it.expect_done && !it.done_seen)
            `uvm_error("CTRL_TIMEOUT",
                $sformatf("fc_sel=%0d : fc_done not seen within %0d cycles", it.sel, it.timeout))
        else if (!it.expect_done && it.done_seen)
            `uvm_error("CTRL_UNEXP_DONE",
                $sformatf("fc_sel=%0d : unexpected fc_done after %0d cycles", it.sel, cyc))
        else if (it.done_seen)
            `uvm_info("CTRL_DRV",
                $sformatf("FC%0d done, latency = %0d cycles", it.sel + 1, cyc), UVM_LOW)
        else
            `uvm_info("CTRL_DRV",
                $sformatf("fc_sel=%0d : no done for %0d cycles (expected)", it.sel, cyc), UVM_LOW)
    endtask

    // pose_raddr 0..23 를 1클럭씩 구동 (monitor 가 1클럭 뒤 rdata 와 짝지음)
    task do_pose_read();
        for (int a = 0; a < N_OUT; a++) begin
            @(vif.drv_cb);
            vif.drv_cb.pose_raddr <= 5'(a);
            vif.drv_cb.pose_rd_en <= 1'b1;
        end

        @(vif.drv_cb);
        vif.drv_cb.pose_rd_en <= 1'b0;
        repeat (2) @(vif.drv_cb);
    endtask

endclass

// ============================================================================
// fc_fifo_driver : FC1 웨이트 스트리밍 (PS/DMA 역할)
//  - fc1_fifo_full 이면 we 를 유지한 채 대기 (full 상태 쓰기는 DUT 가 버림)
//  - 아이템 사이 gap 으로 FIFO starvation 유도
// ============================================================================
class fc_fifo_driver extends uvm_driver #(fc_fifo_item);

    `uvm_component_utils(fc_fifo_driver)

    virtual fc_if vif;

    int unsigned n_written;
    int unsigned n_full_stall;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fc_if)::get(
            this, "", "vif", vif))
            `uvm_fatal(get_type_name(),
                "virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        // 초기화
        vif.drv_cb.fc1_fifo_we    <= 1'b0;
        vif.drv_cb.fc1_fifo_wdata <= '0;

        // reset 해제 대기
        wait (vif.rst_n === 1'b1);

        forever begin
            fc_fifo_item req;
            seq_item_port.try_next_item(req);

            if (req == null) begin
                vif.drv_cb.fc1_fifo_we <= 1'b0;
                @(vif.drv_cb);
                continue;
            end

            repeat (req.gap) begin
                vif.drv_cb.fc1_fifo_we <= 1'b0;
                @(vif.drv_cb);
            end

            vif.drv_cb.fc1_fifo_we    <= 1'b1;
            vif.drv_cb.fc1_fifo_wdata <= req.data;
            @(vif.drv_cb);

            // 이 엣지에서 full 이었으면 쓰기가 안 들어갔으므로 유지
            while (vif.drv_cb.fc1_fifo_full) begin
                n_full_stall++;
                @(vif.drv_cb);
            end

            n_written++;
            seq_item_port.item_done();
        end
    endtask

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("FIFO_DRV",
            $sformatf("words written = %0d, full-stall cycles = %0d", n_written, n_full_stall),
            UVM_LOW)
    endfunction

endclass
