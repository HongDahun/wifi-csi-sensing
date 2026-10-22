// ============================================================================
// rq_seq : mode 별 자극 생성
//   RAND        : 절반은 전범위 랜덤, 절반은 출력이 범위 안에 오도록 스케일 조정
//   TIE         : (acc+bias)*mult 가 정확히 (2k+1)*2^(s-1) -> .5 반올림
//   BOUNDARY    : int32 경계값 x shift 경계값
//   SHIFT_RANGE : shift 음수 큰 값 / 64 이상 (스펙 범위 확인용)
// ============================================================================
class rq_seq extends uvm_sequence #(rq_item);
    `uvm_object_utils(rq_seq)

    typedef enum {RAND, TIE, BOUNDARY, SHIFT_RANGE} mode_e;
    mode_e       mode    = RAND;
    int unsigned n       = 1000;
    int unsigned gap_pct = 30;
    int unsigned gap_max = 3;

    int bnd[] = '{32'h8000_0000, 32'h8000_0001, -1, 0, 1, 32'h7FFF_FFFF};

    function new(string name = "rq_seq");
        super.new(name);
    endfunction

    function int srange(int lo, int hi);
        return lo + int'($urandom_range(hi - lo));
    endfunction

    function void fill(rq_item it);
        int k, s;
        case (mode)
            RAND: begin
                if ($urandom_range(1)) begin
                    it.acc = $urandom; it.bias = $urandom; it.mult = $urandom;
                    it.shift = srange(0, 63);
                end else begin
                    it.acc   = srange(-(1 << 20), 1 << 20);
                    it.bias  = srange(-(1 << 16), 1 << 16);
                    it.mult  = srange(-1024, 1024);
                    it.shift = srange(16, 30);
                end
            end
            TIE: begin
                s        = srange(1, 20);
                k        = srange(-1000, 1000);
                it.mult  = ($urandom_range(1)) ? 1 : -1;
                it.bias  = srange(-1000, 1000);
                it.acc   = (2 * k + 1) * (1 << (s - 1)) - it.bias;
                it.shift = s;
            end
            BOUNDARY: begin
                it.acc   = bnd[$urandom_range(bnd.size() - 1)];
                it.bias  = bnd[$urandom_range(bnd.size() - 1)];
                it.mult  = bnd[$urandom_range(bnd.size() - 1)];
                case ($urandom_range(5))
                    0: it.shift = 0;   1: it.shift = 1;   2: it.shift = 31;
                    3: it.shift = 32;  4: it.shift = 62;  default: it.shift = 63;
                endcase
            end
            SHIFT_RANGE: begin
                it.acc  = srange(-(1 << 30), 1 << 30);
                it.bias = 0;
                it.mult = srange(-(1 << 20), 1 << 20);
                it.shift = $urandom_range(1) ? srange(-40, -1) : srange(64, 80);
            end
        endcase
        it.tag = $urandom;
        it.gap = ($urandom_range(99) < gap_pct) ? $urandom_range(gap_max, 1) : 0;
    endfunction

    task body();
        repeat (n) begin
            req = rq_item::type_id::create("req");
            start_item(req);
            fill(req);
            finish_item(req);
        end
    endtask
endclass

// ============================================================================
// rq_directed_seq : 지정한 item 을 순서대로 그대로 보냄 (fill 랜덤화 없음)
// ============================================================================
class rq_directed_seq extends uvm_sequence #(rq_item);
    `uvm_object_utils(rq_directed_seq)

    rq_item items[$];

    function new(string name = "rq_directed_seq");
        super.new(name);
    endfunction

    function void add(int acc, int bias, int mult, int shift, bit [8:0] tag, int unsigned gap);
        rq_item it = rq_item::type_id::create("it");
        it.acc = acc;  it.bias = bias;  it.mult = mult;  it.shift = shift;
        it.tag = tag;  it.gap  = gap;
        items.push_back(it);
    endfunction

    task body();
        foreach (items[i]) begin
            req = items[i];
            start_item(req);
            finish_item(req);
        end
    endtask
endclass
