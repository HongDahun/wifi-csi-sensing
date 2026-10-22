// ============================================================================
// Tests
//   ff_rand_test       : 랜덤 비율 phase 40개
//   ff_fill_drain_test : 가득 채우고(+초과 쓰기) 다 비우고(+초과 읽기) 반복
//   ff_simul_test      : count 0/1/2 근처 동시 push/pop (head 교체 경로)
//   ff_reset_test      : 트래픽 중간 동기 리셋 3회
// ============================================================================
class ff_base_test extends uvm_test;
    `uvm_component_utils(ff_base_test)

    ff_env       env;
    ff_vif       vif;
    int          depth;
    ff_phase_seq wseq, rseq;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = ff_env::type_id::create("env", this);
        if (!uvm_config_db#(ff_vif)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface(vif)를 config_db에서 찾지 못함")
        if (!uvm_config_db#(int)::get(this, "", "depth", depth)) depth = 512;
    endfunction

    // 자식 테스트가 wseq/rseq 에 phase 를 채움
    virtual function void build_phases();
    endfunction

    virtual task side_task();     // reset 주입 등
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        wseq = ff_phase_seq::type_id::create("wseq");
        rseq = ff_phase_seq::type_id::create("rseq");
        build_phases();
        wait (vif.rst_n === 1'b1);
        fork
            wseq.start(env.wr_sqr);
            rseq.start(env.rd_sqr);
            side_task();
        join
        repeat (5) @(posedge vif.clk);
        phase.drop_objection(this);
    endtask
endclass

// 랜덤 비율 phase 를 섞음
class ff_rand_test extends ff_base_test;
    `uvm_component_utils(ff_rand_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phases();
        repeat (40) begin
            int unsigned c = $urandom_range(800, 50);
            wseq.add(c, $urandom_range(100));
            rseq.add(c, $urandom_range(100));
        end
    endfunction
endclass

// 가득 채우고(+초과 쓰기) 다 비우고(+초과 읽기) 반복 -> full/empty/wrap
class ff_fill_drain_test extends ff_base_test;
    `uvm_component_utils(ff_fill_drain_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phases();
        repeat (3) begin
            wseq.add(depth + 20, 100);  rseq.add(depth + 20, 0);
            wseq.add(depth + 20, 0);    rseq.add(depth + 20, 100);
        end
        wseq.add(depth + 20, 100);  rseq.add(depth + 20, 0);     // full 에서
        wseq.add(200, 100);         rseq.add(200, 100);          // 동시 push/pop
        wseq.add(depth + 20, 0);    rseq.add(depth + 20, 100);
    endfunction
endclass

// count 0/1/2 근처에서 동시 push/pop (head 교체 경로 집중)
class ff_simul_test extends ff_base_test;
    `uvm_component_utils(ff_simul_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phases();
        wseq.add(3000, 50);   rseq.add(3000, 60);
        wseq.add(3000, 100);  rseq.add(3000, 100);
        wseq.add(3000, 70);   rseq.add(3000, 70);
    endfunction
endclass

// 트래픽 중간에 동기 리셋 (클럭은 계속 동작)
class ff_reset_test extends ff_base_test;
    `uvm_component_utils(ff_reset_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phases();
        wseq.add(4000, 70);  rseq.add(4000, 40);
    endfunction
    task side_task();
        repeat (3) begin
            repeat ($urandom_range(1200, 600)) @(posedge vif.clk);
            `uvm_info("TEST", "assert sync reset", UVM_LOW)
            vif.rst_n <= 1'b0;
            repeat ($urandom_range(4, 1)) @(posedge vif.clk);
            vif.rst_n <= 1'b1;
        end
    endtask
endclass
