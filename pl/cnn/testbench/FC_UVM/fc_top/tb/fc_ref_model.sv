// ============================================================================
// fc_ref_model : 레이어별 기대값 (requant 출력 rq / GELU 후 hidden / pose)
// ============================================================================
class fc_ref_model extends uvm_object;
    `uvm_object_utils(fc_ref_model)

    int  acc1 [N_H1];   byte rq1 [N_H1];   byte h1 [N_H1];
    int  acc2 [N_H2];   byte rq2 [N_H2];   byte h2 [N_H2];
    int  acc3 [N_OUT];  byte pose[N_OUT];  // FC3 는 GELU 없이 rq 그대로

    function new(string name = "fc_ref_model");
        super.new(name);
    endfunction

    function void compute(fc_cfg cfg);
        int acc;

        // FC1 : x1(5120) x W1 -> requant -> GELU(table 2)
        for (int o = 0; o < N_H1; o++) begin
            acc = 0;
            for (int k = 0; k < N_IN1; k++) acc += int'(cfg.x1[k]) * int'(cfg.w1[o][k]);
            acc1[o] = acc;
            rq1[o]  = fc_requant(acc, cfg.param[FC1_P_BASE + o]);
            h1[o]   = cfg.lut[fc_lut_addr(rq1[o], 0)];
        end

        // FC2 : h1(128) x W2 -> requant -> GELU(table 3)
        for (int o = 0; o < N_H2; o++) begin
            acc = 0;
            for (int k = 0; k < N_H1; k++) acc += int'(h1[k]) * int'(cfg.w2[o][k]);
            acc2[o] = acc;
            rq2[o]  = fc_requant(acc, cfg.param[FC2_P_BASE + o]);
            h2[o]   = cfg.lut[fc_lut_addr(rq2[o], 1)];
        end

        // FC3 : h2(128) x W3 -> requant
        for (int o = 0; o < N_OUT; o++) begin
            acc = 0;
            for (int k = 0; k < N_H2; k++) acc += int'(h2[k]) * int'(cfg.w3[o][k]);
            acc3[o] = acc;
            pose[o] = fc_requant(acc, cfg.param[FC3_P_BASE + o]);
        end
    endfunction

endclass
