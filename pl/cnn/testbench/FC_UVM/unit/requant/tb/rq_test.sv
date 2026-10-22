// ============================================================================
// Tests
//   rq_rand_test        : 랜덤 5000개 back-to-back + 5000개 버블 40%
//   rq_tie_test         : 정확히 .5 반올림 (half-away-from-zero)
//   rq_boundary_test    : int32 경계값 x shift {0,1,31,32,62,63}
//   rq_shift_range_test : shift -40..-1 / 64..80 (스펙 범위 확인용)
// ============================================================================
class rq_base_test extends uvm_test;
    `uvm_component_utils(rq_base_test)

    rq_env        env;
    virtual rq_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = rq_env::type_id::create("env", this);
        if (!uvm_config_db#(virtual rq_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface(vif)를 config_db에서 찾지 못함")
    endfunction

    virtual task stimulus();
    endtask

    task run_seq(rq_seq::mode_e m, int unsigned n, int unsigned gap_pct = 30);
        rq_seq s = rq_seq::type_id::create("s");
        s.mode = m;  s.n = n;  s.gap_pct = gap_pct;
        s.start(env.sqr);
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        wait (vif.rst_n === 1'b1);
        stimulus();
        repeat (RQ_LATENCY + 10) @(posedge vif.clk);
        phase.drop_objection(this);
    endtask
endclass

class rq_rand_test extends rq_base_test;
    `uvm_component_utils(rq_rand_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task stimulus();
        run_seq(rq_seq::RAND, 5000, 0);    // back-to-back
        run_seq(rq_seq::RAND, 5000, 40);   // 버블 섞어서
    endtask
endclass

class rq_tie_test extends rq_base_test;
    `uvm_component_utils(rq_tie_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task stimulus();
        run_seq(rq_seq::TIE, 3000);
    endtask
endclass

class rq_boundary_test extends rq_base_test;
    `uvm_component_utils(rq_boundary_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task stimulus();
        run_seq(rq_seq::BOUNDARY, 3000);
    endtask
endclass

// 스펙 범위 확인용 : shift < -1 (큰 좌시프트) / shift >= 64
// 실패하면 (1) RTL 버그 후보이거나 (2) 스펙에 shift 허용 범위를 명시해야 함
class rq_shift_range_test extends rq_base_test;
    `uvm_component_utils(rq_shift_range_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task stimulus();
        run_seq(rq_seq::SHIFT_RANGE, 2000);
    endtask
endclass

// 버그 시연용 : 정상 대조군 1개 + shift 범위 버그 후보 3개
//   item 앞에 20클럭 간격 -> 파이프라인(latency 7) 안에서 서로 겹치지 않음
//   item 별 REF 값과 rq_valid 상승 시각을 UVM_INFO 로 출력 (비교/에러는 scoreboard 가 수행)
class rq_bug_demo_test extends rq_base_test;
    `uvm_component_utils(rq_bug_demo_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task stimulus();
        rq_directed_seq s = rq_directed_seq::type_id::create("s");
        s.add(1000000,     0, 100,    20,  1, 20);   // 1. 정상 대조군
        s.add(791260429,   0, 296201, 65,  2, 20);   // 2. shift=65
        s.add(-651666804,  0, 293545, 68,  3, 20);   // 3. shift=68
        s.add(-329309601,  0, 954385, -16, 4, 20);   // 4. shift=-16
        foreach (s.items[i])
            `uvm_info("DEMO", $sformatf("item%0d %s -> REF rq=%0d", i + 1,
                s.items[i].convert2string(), fc_requant(s.items[i].acc, s.items[i].param())), UVM_LOW)
        fork
            watch();
        join_none
        s.start(env.sqr);
    endtask

    // acc_valid / rq_valid 상승 시각과 그때의 DUT 값
    task watch();
        fork
            forever begin
                @(posedge vif.acc_valid);
                `uvm_info("DEMO", $sformatf("acc_valid rise @ %0t tag=%0d", $time, vif.acc_tag), UVM_LOW)
            end
            forever begin
                @(posedge vif.rq_valid);
                `uvm_info("DEMO", $sformatf("rq_valid  rise @ %0t tag=%0d DUT rq=%0d",
                    $time, vif.rq_tag, $signed(vif.rq)), UVM_LOW)
            end
        join
    endtask
endclass
