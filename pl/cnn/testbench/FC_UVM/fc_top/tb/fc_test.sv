// ============================================================================
// Tests
//   fc_smoke_test          : 랜덤 데이터 1회, FIFO gap 없음
//   fc_rand_test           : 랜덤 데이터 3회, FIFO gap 10%
//   fc_fifo_stress_test    : FIFO 선적재(full/backpressure) + 큰 gap(starvation)
//   fc_extreme_test        : 누산 최대/최소 (-128*-128, -128*127) -> 포화 경로
//   fc_requant_corner_test : shift -4~4 / 작은 mult -> 반올림 tie, 좌시프트, 비포화
//   fc_ctrl_corner_test    : fc_sel=3 무시, busy 중 fc_start 무시 확인
// ============================================================================

class fc_base_test extends uvm_test;
    `uvm_component_utils(fc_base_test)

    fc_env        env;
    fc_cfg        cfg;
    virtual fc_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // 자식 테스트가 knob 을 바꾸는 곳
    virtual function void configure_cfg();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg = fc_cfg::type_id::create("cfg");
        configure_cfg();
        env = fc_env::type_id::create("env", this);
        if(!uvm_config_db #(virtual fc_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface(vif)를 config_db에서 찾지 못함")
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    // ---------------- helpers ----------------
    task run_layer(bit [1:0] sel, bit expect_done = 1, int unsigned wait_cycles = 0);
        fc_layer_seq seq;

        seq = fc_layer_seq::type_id::create("seq");
        seq.sel         = sel;
        seq.expect_done = expect_done;
        seq.timeout     = expect_done ? cfg.layer_timeout : wait_cycles;
        seq.start(env.ctrl_agt.sqr);
    endtask

    task read_pose();
        fc_pose_read_seq seq;

        seq = fc_pose_read_seq::type_id::create("seq");
        seq.start(env.ctrl_agt.sqr);
    endtask

    // 레이어 실행 중에 병렬로 돌릴 훅 (ctrl_corner 에서 사용)
    virtual task during_layer(bit [1:0] sel);
    endtask

    // FC1 -> FC2 -> FC3 -> pose read 1회
    virtual task run_inference(int idx);
        fc_fifo_weight_seq wseq;

        cfg.randomize_data();
        cfg.load_mems(vif);
        env.scb.set_expected(cfg);
        `uvm_info("TEST", $sformatf("=== inference #%0d (mode=%s, corner=%0b) ===",
                                    idx, cfg.data_mode.name(), cfg.requant_corner), UVM_LOW)

        wseq = fc_fifo_weight_seq::type_id::create("wseq");
        wseq.cfg = cfg;

        fork
            wseq.start(env.fifo_agt.sqr);
            begin
                repeat (cfg.fc1_start_delay) @(posedge vif.clk);
                fork
                    run_layer(SEL_FC1);
                    during_layer(SEL_FC1);
                join
            end
        join

        fork run_layer(SEL_FC2); during_layer(SEL_FC2); join
        fork run_layer(SEL_FC3); during_layer(SEL_FC3); join

        read_pose();
        repeat (5) @(posedge vif.clk);
        env.scb.check_inference(idx);
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        wait (vif.rst_n === 1'b1);
        repeat (5) @(posedge vif.clk);

        for (int i = 0; i < cfg.num_infer; i++) run_inference(i);

        repeat (20) @(posedge vif.clk);

        phase.drop_objection(this);
    endtask

endclass

// ----------------------------------------------------------------------------
class fc_smoke_test extends fc_base_test;
    `uvm_component_utils(fc_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void configure_cfg();
        cfg.num_infer = 1;
    endfunction
endclass

// ----------------------------------------------------------------------------
class fc_rand_test extends fc_base_test;
    `uvm_component_utils(fc_rand_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void configure_cfg();
        cfg.num_infer       = 3;
        cfg.fifo_gap_pct    = 10;
        cfg.fifo_gap_max    = 4;
        cfg.fc1_start_delay = $urandom_range(300);
    endfunction
endclass

// ----------------------------------------------------------------------------
// FIFO 는 FC1 이 매 클럭 1 word 씩 소비하므로, 실행 중에는 거의 차지 않는다.
// -> FC1 시작 전에 선적재해서 full / backpressure 를 만들고,
//    큰 gap 으로 FC1 실행 중 starvation(empty 로 stall) 을 만든다.
//    gap 50% x 평균 8.5클럭 -> word 당 약 5.25클럭, 512 word 가 차는 데 약 2700클럭
//    -> delay 4000 (여유 포함). 1000 이면 약 190 word 라 full 에 도달하지 못함
class fc_fifo_stress_test extends fc_base_test;
    `uvm_component_utils(fc_fifo_stress_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void configure_cfg();
        cfg.num_infer       = 1;
        cfg.fifo_gap_pct    = 50;
        cfg.fifo_gap_max    = 16;
        cfg.fc1_start_delay = 4000;
        cfg.layer_timeout   = 5_000_000;
    endfunction
endclass

// ----------------------------------------------------------------------------
class fc_extreme_test extends fc_base_test;
    `uvm_component_utils(fc_extreme_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void configure_cfg();
        cfg.num_infer = 2;
    endfunction

    task run_inference(int idx);
        cfg.data_mode = (idx == 0) ? fc_cfg::DATA_MAX : fc_cfg::DATA_MIN;
        super.run_inference(idx);
    endtask
endclass

// ----------------------------------------------------------------------------
class fc_requant_corner_test extends fc_base_test;
    `uvm_component_utils(fc_requant_corner_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void configure_cfg();
        cfg.num_infer      = 2;
        cfg.requant_corner = 1;
    endfunction
endclass

// ----------------------------------------------------------------------------
// 1) fc_sel=3 : start 가 무시되고 done 이 나오면 안 됨
// 2) 각 레이어 실행 중 다른 fc_sel 로 fc_start 를 찔러도 결과가 바뀌면 안 됨
//    (DUT 가 잘못 재시작하면 FIFO 고갈 -> timeout 또는 scoreboard mismatch)
//    FC1 중 -> sel 1, FC2 중 -> sel 2, FC3 중 -> sel 0 과 sel 3 (illegal) 두 번
class fc_ctrl_corner_test extends fc_base_test;
    `uvm_component_utils(fc_ctrl_corner_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void configure_cfg();
        cfg.num_infer = 1;
    endfunction

    // poke 시점은 레이어 시작 기준 누적 클럭
    //   FC1 중 : 2000 -> sel 1
    //   FC2 중 : 200  -> sel 2
    //   FC3 중 : 50 -> sel 0, 150 -> sel 3 (illegal)   ※ FC3 는 약 400 클럭이라 둘 다 busy 중
    // -> busy 중 sel 0/1/2/3 을 모두 찌름 (cg_start x_sel_busy 100%)
    task during_layer(bit [1:0] sel);
        int unsigned at [$];
        bit [1:0]    poke_sel [$];
        int unsigned elapsed;

        case (sel)
            SEL_FC1: begin at = '{2000};    poke_sel = '{2'd1};       end
            SEL_FC2: begin at = '{200};     poke_sel = '{2'd2};       end
            default: begin at = '{50, 150}; poke_sel = '{2'd0, 2'd3}; end
        endcase

        elapsed = 0;
        foreach (at[i]) begin
            repeat (at[i] - elapsed) @(vif.drv_cb);

            `uvm_info("TEST", $sformatf("poke fc_start (sel=%0d) while FC%0d busy",
                                        poke_sel[i], sel + 1), UVM_LOW)

            vif.drv_cb.fc_sel   <= poke_sel[i];
            vif.drv_cb.fc_start <= 1'b1;
            @(vif.drv_cb);
            vif.drv_cb.fc_start <= 1'b0;
            vif.drv_cb.fc_sel   <= sel;

            elapsed = at[i] + 1;
        end
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        wait (vif.rst_n === 1'b1);
        repeat (5) @(posedge vif.clk);

        `uvm_info("TEST", "=== illegal fc_sel = 3 ===", UVM_LOW)
        run_layer(2'd3, 0, 500);

        run_inference(0);
        repeat (20) @(posedge vif.clk);

        phase.drop_objection(this);
    endtask
endclass
