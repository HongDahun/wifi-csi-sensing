// ============================================================================
// mac_seq : 그룹 n 개 생성 (len 범위, beat 버블 확률, back-to-back 확률, 데이터 모드)
// ============================================================================
class mac_seq extends uvm_sequence #(mac_group_item);
    `uvm_object_utils(mac_seq)

    int unsigned n          = 200;
    int unsigned len_lo     = 1, len_hi = 40;
    int unsigned gap_pct    = 20;
    int unsigned b2b_pct    = 50;      // 그룹 사이 버블 없이 바로
    mac_group_item::dmode_e dmode = mac_group_item::D_RAND;
    bit          mix_modes  = 0;

    function new(string name = "mac_seq");
        super.new(name);
    endfunction

    task body();
        repeat (n) begin
            req = mac_group_item::type_id::create("req");
            start_item(req);
            req.len     = $urandom_range(len_hi, len_lo);
            req.tag     = $urandom;
            req.gap_pct = gap_pct;
            req.pre_gap = ($urandom_range(99) < b2b_pct) ? 0 : $urandom_range(5, 1);
            req.dmode   = mix_modes ? mac_group_item::dmode_e'($urandom_range(3)) : dmode;
            req.build_data();
            finish_item(req);
        end
    endtask
endclass
