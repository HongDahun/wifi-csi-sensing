// ============================================================================
// fc_cfg : 테스트 knob + 한 번의 인퍼런스에 쓰이는 전체 데이터셋
//   x1[5120], W1[128][5120], W2[128][128], W3[24][128], param[512], lut[1024]
// ============================================================================
class fc_cfg extends uvm_object;
    `uvm_object_utils(fc_cfg)

    typedef enum {DATA_RAND, DATA_MAX, DATA_MIN, DATA_SPARSE} data_mode_e;

    // ---------------- Knobs ----------------
    data_mode_e  data_mode       = DATA_RAND;
    bit          requant_corner  = 0;          // shift -4~4, 작은 mult, 범위 안쪽 값 위주
    int unsigned fifo_gap_pct    = 0;          // 워드마다 gap 넣을 확률(%)
    int unsigned fifo_gap_max    = 1;          // gap 최대 클럭
    int unsigned fc1_start_delay = 0;          // FIFO 선적재 후 FC1 시작 (full 유도)
    int unsigned num_infer       = 1;
    int unsigned layer_timeout   = 3_000_000;  // cycles

    // ---------------- Data ----------------
    byte       x1    [N_IN1];
    byte       w1    [N_H1][N_IN1];
    byte       w2    [N_H2][N_H1];
    byte       w3    [N_OUT][N_H2];
    bit [95:0] param [512];
    byte       lut   [1024];

    function new(string name = "fc_cfg");
        super.new(name);
    endfunction

    // ---------------- Random helpers ----------------
    function int srange(int lo, int hi);
        return lo + int'($urandom_range(hi - lo));
    endfunction

    function byte gen_act();
        case (data_mode)
            DATA_MAX, DATA_MIN: return -8'sd128;
            DATA_SPARSE:        return ($urandom_range(99) < 80) ? 8'sd0 : byte'($urandom_range(255));
            default:            return byte'($urandom_range(255));
        endcase
    endfunction

    function byte gen_wt();
        case (data_mode)
            DATA_MAX:    return -8'sd128;   // (-128)*(-128) -> 최대 양수 누산
            DATA_MIN:    return 8'sd127;    // (-128)*( 127) -> 최대 음수 누산
            DATA_SPARSE: return ($urandom_range(99) < 80) ? 8'sd0 : byte'($urandom_range(255));
            default:     return byte'($urandom_range(255));
        endcase
    endfunction

    // 출력 분포가 포화에만 몰리지 않도록 레이어별로 스케일을 고른다.
    // corner 모드는 acc 를 보고 bias 를 역산해서 (acc+bias) 가 ±400 근처가 되게 함
    // -> shift -4~4, mult -3~3 에서 반올림 tie / 비포화 / 좌시프트 경로가 모두 나옴
    function bit [95:0] pick_param(int acc, int layer);
        int b, m, s;
        if (requant_corner) begin
            s = srange(-4, 4);
            m = srange(-3, 3);
            b = srange(-400, 400) - acc;
        end else if (layer == 0) begin
            s = 24;
            m = srange(500, 4000);
            b = srange(-100_000, 100_000);
        end else begin
            s = 20;
            m = srange(300, 1500);
            b = srange(-15_000, 15_000);
        end
        return {s[31:0], m[31:0], b[31:0]};
    endfunction

    // ---------------- Dataset generation ----------------
    function void randomize_data();
        byte h1 [N_H1];
        byte h2 [N_H2];
        int  acc;

        foreach (x1[k])     x1[k]     = gen_act();
        foreach (w1[o, k])  w1[o][k]  = gen_wt();
        foreach (w2[o, k])  w2[o][k]  = gen_wt();
        foreach (w3[o, k])  w3[o][k]  = gen_wt();
        foreach (lut[i])    lut[i]    = gen_act();   // GELU 출력 = 다음 레이어 activation
        foreach (param[i])  param[i]  = '0;

        // 파라미터는 레이어 순서대로 (corner 모드가 acc 를 필요로 함)
        for (int o = 0; o < N_H1; o++) begin
            acc = 0;
            for (int k = 0; k < N_IN1; k++) acc += int'(x1[k]) * int'(w1[o][k]);
            param[FC1_P_BASE + o] = pick_param(acc, 0);
            h1[o] = lut[fc_lut_addr(fc_requant(acc, param[FC1_P_BASE + o]), 0)];
        end
        for (int o = 0; o < N_H2; o++) begin
            acc = 0;
            for (int k = 0; k < N_H1; k++) acc += int'(h1[k]) * int'(w2[o][k]);
            param[FC2_P_BASE + o] = pick_param(acc, 1);
            h2[o] = lut[fc_lut_addr(fc_requant(acc, param[FC2_P_BASE + o]), 1)];
        end
        for (int o = 0; o < N_OUT; o++) begin
            acc = 0;
            for (int k = 0; k < N_H2; k++) acc += int'(h2[k]) * int'(w3[o][k]);
            param[FC3_P_BASE + o] = pick_param(acc, 2);
        end
    endfunction

    // ---------------- Packing (byte i -> bits [8i+7:8i]) ----------------
    function bit [63:0] feat_word(int g);
        bit [63:0] w;
        for (int i = 0; i < 8; i++) w[8*i +: 8] = x1[8*g + i];
        return w;
    endfunction

    // FIFO 순서 : out 0 의 group 0..639, out 1 의 group 0..639, ...
    function bit [63:0] fc1_w_word(int o, int g);
        bit [63:0] w;
        for (int i = 0; i < 8; i++) w[8*i +: 8] = w1[o][8*g + i];
        return w;
    endfunction

    // fcw_raddr = BASE + out*16 + group
    function bit [63:0] fcw_word(int addr);
        bit [63:0] w;
        int o, g, a;
        w = '0;
        if (addr < FC3_W_BASE) begin
            o = addr / GROUPS23;  g = addr % GROUPS23;
            if (o < N_H2) for (int i = 0; i < 8; i++) w[8*i +: 8] = w2[o][8*g + i];
        end else begin
            a = addr - FC3_W_BASE;
            o = a / GROUPS23;     g = a % GROUPS23;
            if (o < N_OUT) for (int i = 0; i < 8; i++) w[8*i +: 8] = w3[o][8*g + i];
        end
        return w;
    endfunction

    // ---------------- Load memory models in fc_if ----------------
    function void load_mems(virtual fc_if vif);
        for (int g = 0; g < FLAT_WORDS; g++) vif.feat_mem[g]  = feat_word(g);
        for (int a = 0; a < 4096; a++)       vif.fcw_mem[a]   = fcw_word(a);
        for (int p = 0; p < 512; p++)        vif.param_mem[p] = param[p];
        for (int l = 0; l < 1024; l++)       vif.lut_mem[l]   = lut[l];
    endfunction

endclass
