`timescale 1ns / 1ps
// ============================================================================
// fc_ref_pkg : 블록/유닛 TB 공용 golden 함수 (UVM 비의존)
//   RTL 구조를 따라 하지 않고 "수학적 스펙"으로 독립 구현
//   - 128bit 정수로 계산 (65bit 오버플로 없음)
//   - 반올림 : |v| 기준 half-away-from-zero (RTL 의 offset-1 트릭과 다른 방식)
// ============================================================================
package fc_ref_pkg;

    localparam int LUT_FC1_BASE = 512;   // table_sel = 2'b10
    localparam int LUT_FC2_BASE = 768;   // table_sel = 2'b11

    // (acc + bias) * mult  (정확값)
    function automatic logic signed [127:0] fc_rq_prod(int acc, bit [95:0] p);
        logic signed [127:0] v, b, m;
        v = acc;                       // sign-extend
        b = $signed(p[31:0]);
        m = $signed(p[63:32]);
        return (v + b) * m;
    endfunction

    // param = {shift[95:64], mult[63:32], bias[31:0]}
    // y = sat127( round_half_away( (acc+bias)*mult / 2^shift ) ), shift<=0 이면 * 2^-shift
    function automatic byte fc_requant(int acc, bit [95:0] p);
        logic signed [127:0] v, mag, q, r;
        int shift;
        v     = fc_rq_prod(acc, p);
        shift = $signed(p[95:64]);

        if (shift > 0) begin
            mag = (v < 0) ? -v : v;
            if (shift >= 120) q = 0;
            else              q = (mag + (128'sd1 <<< (shift - 1))) >>> shift;
            r = (v < 0) ? -q : q;
        end else if (-shift > 60) begin
            r = (v > 0) ? 128'sd1000 : (v < 0) ? -128'sd1000 : 128'sd0;   // 확실히 포화
        end else begin
            r = v <<< (-shift);
        end

        if (r > 127)       return 8'sd127;
        else if (r < -127) return -8'sd127;
        else               return byte'(r[7:0]);
    endfunction

    // 반올림 tie (정확히 .5) 인지 - 커버리지용
    function automatic bit fc_requant_is_tie(int acc, bit [95:0] p);
        logic signed [127:0] v, mag, half, mask;
        int shift;
        v     = fc_rq_prod(acc, p);
        shift = $signed(p[95:64]);
        if (shift <= 0 || shift >= 120) return 0;
        mag  = (v < 0) ? -v : v;
        half = 128'sd1 <<< (shift - 1);
        mask = (128'sd1 <<< shift) - 1;
        return ((mag & mask) == half);
    endfunction

    // INT8 -> offset-binary LUT 주소
    function automatic int fc_lut_addr(byte v, int layer);
        bit [7:0] idx;
        idx = {~v[7], v[6:0]};
        return ((layer == 0) ? LUT_FC1_BASE : LUT_FC2_BASE) + int'(idx);
    endfunction

    // 8-lane INT8 dot product (64bit word 2개)
    function automatic int fc_lane_sum(bit [63:0] a, bit [63:0] w);
        int s = 0;
        for (int i = 0; i < 8; i++)
            s += int'($signed(a[8*i +: 8])) * int'($signed(w[8*i +: 8]));
        return s;
    endfunction

endpackage
