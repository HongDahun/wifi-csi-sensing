// ============================================================================
// rq_item : requant 입력 1개 (acc + param) / monitor 관측 결과
// ============================================================================
class rq_item extends uvm_sequence_item;
    `uvm_object_utils(rq_item)

    int          acc, bias, mult, shift;
    bit [8:0]    tag;
    int unsigned gap;            // 앞에 쉬는 클럭
    // monitor 채움
    byte         rq;
    longint      cyc;

    function new(string name = "rq_item");
        super.new(name);
    endfunction

    function bit [95:0] param();
        return {shift[31:0], mult[31:0], bias[31:0]};
    endfunction

    function string convert2string();
        return $sformatf("acc=%0d bias=%0d mult=%0d shift=%0d tag=0x%03h",
                         acc, bias, mult, shift, tag);
    endfunction
endclass
