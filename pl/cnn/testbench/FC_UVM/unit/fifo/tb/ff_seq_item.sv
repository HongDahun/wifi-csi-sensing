// ============================================================================
// Sequence / observation items
// ============================================================================

// ---------------- phase item : n 클럭 동안 pct% 확률로 we(또는 re) 구동 ----------------
class ff_phase_item extends uvm_sequence_item;
    `uvm_object_utils(ff_phase_item)

    int unsigned cycles;
    int unsigned pct;

    function new(string name = "ff_phase_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("%0d cycles @ %0d%%", cycles, pct);
    endfunction
endclass

// ---------------- Monitor observation item (클럭 1개 스냅샷) ----------------
class ff_cycle_item extends uvm_sequence_item;
    `uvm_object_utils(ff_cycle_item)

    bit rst_n, we, re, full, empty;
    bit [63:0] wdata, rdata;

    function new(string name = "ff_cycle_item");
        super.new(name);
    endfunction
endclass
