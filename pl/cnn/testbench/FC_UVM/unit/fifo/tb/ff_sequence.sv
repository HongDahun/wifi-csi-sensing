// ============================================================================
// ff_phase_seq : phase 리스트를 순서대로 보내는 시퀀스
// ============================================================================
class ff_phase_seq extends uvm_sequence #(ff_phase_item);
    `uvm_object_utils(ff_phase_seq)

    int unsigned cyc[$];
    int unsigned pct[$];

    function new(string name = "ff_phase_seq");
        super.new(name);
    endfunction

    function void add(int unsigned c, int unsigned p);
        cyc.push_back(c);
        pct.push_back(p);
    endfunction

    task body();
        foreach (cyc[i]) begin
            req = ff_phase_item::type_id::create("req");
            start_item(req);
            req.cycles = cyc[i];
            req.pct    = pct[i];
            finish_item(req);
        end
    endtask
endclass
