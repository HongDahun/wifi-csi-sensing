// ============================================================================
// fc_monitor : 포트 + 화이트박스 프로브 관찰
//   OBS_RQ        : requant 출력 (모든 레이어)       -> requant/MAC 오류 국소화
//   OBS_HIDDEN_WR : hidden_ram 쓰기 (GELU 후)        -> GELU/LUT 주소 확인
//   OBS_POSE_WR   : pose_buffer 쓰기
//   OBS_POSE_RD   : pose 포트 읽기 (1-cycle sync read 경로)
//   OBS_START/DONE: 제어 이벤트
// ============================================================================
class fc_monitor extends uvm_monitor;
    `uvm_component_utils(fc_monitor)

    virtual fc_if vif;

    uvm_analysis_port #(fc_obs_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db #(virtual fc_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface(vif)를 config_db에서 찾지 못함")
    endfunction

    function void send(fc_obs_item::kind_e k, bit bank, int addr, byte data,
                       bit [8:0] tag = '0, bit [1:0] sel = '0);
        fc_obs_item tr;

        tr = fc_obs_item::type_id::create("tr");
        tr.kind = k;
        tr.bank = bank;
        tr.addr = addr;
        tr.data = data;
        tr.tag  = tag;
        tr.sel  = sel;

        `uvm_info("MON", tr.convert2string(), UVM_DEBUG)

        ap.write(tr);
    endfunction

    task run_phase(uvm_phase phase);
        bit       prev_en;
        bit [4:0] prev_addr;

        prev_en = 0;

        forever begin
            @(vif.mon_cb);

            if (vif.mon_cb.rst_n !== 1'b1) begin
                prev_en = 0;
                continue;
            end

            if (vif.mon_cb.fc_start)
                send(fc_obs_item::OBS_START, 0, 0, 0, '0, vif.mon_cb.fc_sel);
            if (vif.mon_cb.fc_done)
                send(fc_obs_item::OBS_DONE, 0, 0, 0);

            if (vif.mon_cb.rq_valid)
                send(fc_obs_item::OBS_RQ, 0, int'(vif.mon_cb.rq_tag[6:0]),
                     byte'(vif.mon_cb.rq), vif.mon_cb.rq_tag);

            if (vif.mon_cb.hidden_we)
                send(fc_obs_item::OBS_HIDDEN_WR, vif.mon_cb.hidden_wbank,
                     int'(vif.mon_cb.hidden_waddr), byte'(vif.mon_cb.hidden_wdata));

            if (vif.mon_cb.pose_we)
                send(fc_obs_item::OBS_POSE_WR, 0, int'(vif.mon_cb.pose_waddr),
                     byte'(vif.mon_cb.pose_wdata));

            // pose_rdata(현재 엣지) <-> pose_raddr(이전 엣지)
            if (prev_en)
                send(fc_obs_item::OBS_POSE_RD, 0, int'(prev_addr), byte'(vif.mon_cb.pose_rdata));

            prev_en   = vif.mon_cb.pose_rd_en;
            prev_addr = vif.mon_cb.pose_raddr;
        end
    endtask
endclass
