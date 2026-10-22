// ============================================================================
// Sequence / observation items
// ============================================================================

// ---------------- Control agent item ----------------
class fc_ctrl_item extends uvm_sequence_item;

    typedef enum {RUN_LAYER, READ_POSE} kind_e;

    kind_e       kind        = RUN_LAYER;
    bit [1:0]    sel         = SEL_FC1;
    bit          expect_done = 1;        // 0 이면 timeout 동안 done 이 없어야 PASS
    int unsigned timeout     = 3_000_000;

    // response
    bit          done_seen;
    int unsigned latency;

    `uvm_object_utils_begin(fc_ctrl_item)
        `uvm_field_enum(kind_e, kind, UVM_ALL_ON)
        `uvm_field_int(sel, UVM_ALL_ON)
        `uvm_field_int(expect_done, UVM_ALL_ON)
        `uvm_field_int(timeout, UVM_ALL_ON)
        `uvm_field_int(done_seen, UVM_ALL_ON)
        `uvm_field_int(latency, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fc_ctrl_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "%s sel=%0d expect_done=%0b timeout=%0d",
            kind.name(),
            sel,
            expect_done,
            timeout);
    endfunction
endclass

// ---------------- FIFO write agent item ----------------
class fc_fifo_item extends uvm_sequence_item;

    bit [63:0]   data;
    int unsigned gap;      // we=0 으로 쉬는 클럭 수 (쓰기 전에)

    `uvm_object_utils_begin(fc_fifo_item)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(gap, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fc_fifo_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("data=0x%016h gap=%0d", data, gap);
    endfunction
endclass

// ---------------- Monitor observation item ----------------
class fc_obs_item extends uvm_sequence_item;

    typedef enum {OBS_RQ, OBS_HIDDEN_WR, OBS_POSE_WR, OBS_POSE_RD, OBS_START, OBS_DONE} kind_e;

    kind_e     kind;
    bit        bank;
    int        addr;
    byte       data;
    bit [8:0]  tag;
    bit [1:0]  sel;

    `uvm_object_utils_begin(fc_obs_item)
        `uvm_field_enum(kind_e, kind, UVM_ALL_ON)
        `uvm_field_int(bank, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(tag, UVM_ALL_ON)
        `uvm_field_int(sel, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fc_obs_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "%s bank=%0d addr=%0d data=%0d tag=0x%03h sel=%0d",
            kind.name(),
            bank,
            addr,
            data,
            tag,
            sel);
    endfunction
endclass
