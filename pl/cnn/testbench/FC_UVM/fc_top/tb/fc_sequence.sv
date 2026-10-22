// ============================================================================
// Sequences
// ============================================================================

// FC1 웨이트 81,920 word 를 FIFO 순서대로 스트리밍
class fc_fifo_weight_seq extends uvm_sequence #(fc_fifo_item);
    `uvm_object_utils(fc_fifo_weight_seq)

    fc_cfg cfg;

    function new(string name = "fc_fifo_weight_seq");
        super.new(name);
    endfunction

    task body();
        fc_fifo_item item;

        for (int o = 0; o < N_H1; o++) begin
            for (int g = 0; g < FLAT_WORDS; g++) begin
                item = fc_fifo_item::type_id::create("item");
                start_item(item);
                item.data = cfg.fc1_w_word(o, g);
                item.gap  = ($urandom_range(99) < cfg.fifo_gap_pct)
                          ? $urandom_range(cfg.fifo_gap_max, 1) : 0;
                finish_item(item);
            end
        end
    endtask
endclass

// 레이어 1개 실행 (start pulse -> done 대기)
class fc_layer_seq extends uvm_sequence #(fc_ctrl_item);
    `uvm_object_utils(fc_layer_seq)

    bit [1:0]    sel         = SEL_FC1;
    bit          expect_done = 1;
    int unsigned timeout     = 3_000_000;

    function new(string name = "fc_layer_seq");
        super.new(name);
    endfunction

    task body();
        fc_ctrl_item item;

        item = fc_ctrl_item::type_id::create("item");
        start_item(item);
        item.kind        = fc_ctrl_item::RUN_LAYER;
        item.sel         = sel;
        item.expect_done = expect_done;
        item.timeout     = timeout;
        finish_item(item);
    endtask
endclass

// pose_buffer 24 byte 읽기
class fc_pose_read_seq extends uvm_sequence #(fc_ctrl_item);
    `uvm_object_utils(fc_pose_read_seq)

    function new(string name = "fc_pose_read_seq");
        super.new(name);
    endfunction

    task body();
        fc_ctrl_item item;

        item = fc_ctrl_item::type_id::create("item");
        start_item(item);
        item.kind = fc_ctrl_item::READ_POSE;
        finish_item(item);
    endtask
endclass
