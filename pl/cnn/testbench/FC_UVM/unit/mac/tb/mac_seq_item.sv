// ============================================================================
// Sequence / observation items
// ============================================================================

// ---------------- 그룹 item : 출력 1개 = len 개 beat ----------------
class mac_group_item extends uvm_sequence_item;
    `uvm_object_utils(mac_group_item)

    typedef enum {D_RAND, D_MAX, D_MIN, D_SPARSE} dmode_e;
    int unsigned len;
    bit [8:0]    tag;
    int unsigned gap_pct;          // beat 사이 버블 확률
    int unsigned pre_gap;          // 그룹 앞 버블 (0 이면 back-to-back)
    dmode_e      dmode;
    bit [63:0]   act[], wgt[];

    function new(string name = "mac_group_item");
        super.new(name);
    endfunction

    function byte gen(bit is_act);
        case (dmode)
            D_MAX:    return -8'sd128;
            D_MIN:    return is_act ? -8'sd128 : 8'sd127;
            D_SPARSE: return ($urandom_range(99) < 70) ? 8'sd0 : byte'($urandom_range(255));
            default:  return byte'($urandom_range(255));
        endcase
    endfunction

    function void build_data();
        act = new[len];  wgt = new[len];
        foreach (act[i]) for (int b = 0; b < 8; b++) begin
            act[i][8*b +: 8] = gen(1);
            wgt[i][8*b +: 8] = gen(0);
        end
    endfunction

    function string convert2string();
        return $sformatf("len=%0d tag=0x%03h mode=%s", len, tag, dmode.name());
    endfunction
endclass

// ---------------- Monitor observation item (입력 beat / 출력 acc) ----------------
class mac_beat_item extends uvm_sequence_item;
    `uvm_object_utils(mac_beat_item)

    bit [63:0] act, wgt;
    bit        first, last;
    bit [8:0]  tag;
    int        acc;
    longint    cyc;

    function new(string name = "mac_beat_item");
        super.new(name);
    endfunction
endclass
