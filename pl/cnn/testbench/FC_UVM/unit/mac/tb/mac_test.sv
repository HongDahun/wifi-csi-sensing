// ============================================================================
// Tests
//   mac_rand_test    : 랜덤 길이 1~40 + 1-beat 연속 + 16-beat(FC2/FC3 형태)
//   mac_extreme_test : 640-beat 최대 양수/음수, 1-beat 최대, 700~1000-beat 누산
//   mac_bubble_test  : 버블 많음 (쓰레기 first/last/tag 무시 확인)
// ============================================================================
class mac_base_test extends uvm_test;
    `uvm_component_utils(mac_base_test)

    mac_env        env;
    virtual mac_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = mac_env::type_id::create("env", this);
        if (!uvm_config_db#(virtual mac_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface(vif)를 config_db에서 찾지 못함")
    endfunction

    virtual task stimulus();
    endtask

    task run_s(int unsigned n, int unsigned lo, int unsigned hi, int unsigned gap,
               mac_group_item::dmode_e m = mac_group_item::D_RAND, bit rmode = 1);
        mac_seq s = mac_seq::type_id::create("s");
        s.n = n;  s.len_lo = lo;  s.len_hi = hi;  s.gap_pct = gap;
        s.dmode = m;  s.mix_modes = rmode;
        s.start(env.sqr);
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        wait (vif.rst_n === 1'b1);
        stimulus();
        repeat (MAC_LATENCY + 10) @(posedge vif.clk);
        phase.drop_objection(this);
    endtask
endclass

class mac_rand_test extends mac_base_test;
    `uvm_component_utils(mac_rand_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task stimulus();
        run_s(500, 1, 40, 20);
        run_s(100, 1, 1, 0);       // 1-beat 그룹 연속 (first=last)
        run_s(50, 16, 16, 0);      // FC2/FC3 형태
    endtask
endclass

class mac_extreme_test extends mac_base_test;
    `uvm_component_utils(mac_extreme_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task stimulus();
        run_s(5, 640, 640, 0, mac_group_item::D_MAX, 0);   // FC1 최대 양수
        run_s(5, 640, 640, 0, mac_group_item::D_MIN, 0);   // FC1 최대 음수
        run_s(20, 1, 1, 0, mac_group_item::D_MAX, 0);
        run_s(5, 700, 1000, 10, mac_group_item::D_MAX, 0); // FC1 보다 긴 누산
    endtask
endclass

class mac_bubble_test extends mac_base_test;
    `uvm_component_utils(mac_bubble_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task stimulus();
        run_s(300, 1, 30, 60);     // 버블 많음 (쓰레기 first/last/tag 무시 확인)
        run_s(20, 640, 640, 30);
    endtask
endclass
