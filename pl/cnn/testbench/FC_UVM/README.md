# FC Accelerator UVM Verification

Wi-Fi CSI 기반 자세 추정 모델의 **FC(Fully-Connected) 가속기**를 UVM 1.2로 검증한 결과물입니다.
INT8 MAC → Requant → GELU(LUT) 파이프라인으로 FC1 → FC2 → FC3 세 레이어를 순서대로 실행해 24개 pose 출력을 만듭니다.

- Tool : Synopsys VCS W-2024.09-SP2, Verdi, URG
- Language : SystemVerilog, UVM 1.2

---

## 1. DUT 구조

```
            ┌──────────── fc_controller (IDLE / RUN / WAIT FSM) ───────────┐
            │                                                              │
 feat mem ─► flatten ─┐                                                    │
                      ├─► fc_mac ─► requant_core ─┬─► gelu_core ─► hidden_ram (bank0/1)
 FC1 weight ► fc_fifo ┤   (8-lane    (bias·mult·  │   (LUT)          │
 (FWFT, 512)          │    INT8,     shift,       │                  └─► FC2 / FC3 입력
 fcw mem ─────────────┘    3-stage)  round, sat)  └─► pose_buffer (FC3, 24 byte)
```

| 레이어 | 입력 | 출력 | 활성 함수 | 출력 위치 |
|---|---|---|---|---|
| FC1 | 5,120 (RX 5 × 128 word × 8 lane) | 128 | GELU | hidden_ram bank0 |
| FC2 | 128 | 128 | GELU | hidden_ram bank1 |
| FC3 | 128 | 24 | 없음 | pose_buffer |

- **fc_mac** : 64bit word 2개(activation, weight)를 8-lane INT8 곱 → adder tree → 32bit 누산. `first/last/tag` 로 출력 1개 단위를 구분
- **requant_core** : `y = sat±127( round_half_away( (acc + bias) × mult / 2^shift ) )`, 7-stage 파이프라인
- **fc_fifo** : FC1 weight 스트리밍용 FWFT FIFO (DEPTH 512)

---

## 2. 검증 전략

블록 단위로 먼저 정확도를 확인한 뒤, 전체 통합 환경에서 레이어 간 연결과 제어를 확인했습니다.

| 단계 | 대상 | 확인 내용 |
|---|---|---|
| Unit | `fc_fifo` | 클럭 단위 큐 모델, full/empty, FWFT head 교체, 동기 리셋 |
| Unit | `fc_mac` | 누산값 · tag · latency, 버블 중 쓰레기 입력 무시, 1~1000 beat 그룹 |
| Unit | `requant_core` | 반올림 tie, int32 경계값, shift 범위 (→ **버그 발견**) |
| Top | `fc_top` | FC1→FC2→FC3 인퍼런스 전체, FIFO backpressure/starvation, 제어 코너 |

### Reference model
`fc_ref_pkg` 는 RTL 구조를 따라 하지 않고 **수학 스펙으로 독립 구현**했습니다.
128bit 정수로 계산하고, 반올림도 RTL(offset−1 방식)과 다른 |v| 기준 half-away-from-zero로 구현해
RTL과 같은 실수를 공유하지 않도록 했습니다.

### Top TB 구성
```
fc_test ── fc_env ─┬─ fc_ctrl_agent (fc_start / fc_sel / pose read)
                   ├─ fc_fifo_agent (FC1 weight 스트리밍, gap/backpressure)
                   ├─ fc_monitor ──┬─► fc_scoreboard (fc_ref_model)
                   │               └─► fc_coverage
                   └─ fc_sva (bind)
fc_if : DUT 포트 + 외부 메모리 4종(feat / fcw / param / lut, 1-cycle sync read) 모델
```
Scoreboard는 최종 pose뿐 아니라 **requant 출력, hidden_ram 쓰기, pose 쓰기/읽기**를 단계별로 비교해
불일치가 나면 어느 블록 문제인지 바로 좁힐 수 있게 했습니다.

---

## 3. 결과

### Top (`fc_top/`)
| 테스트 | 내용 | 결과 |
|---|---|---|
| fc_smoke_test | 랜덤 데이터 인퍼런스 1회 | PASS |
| fc_rand_test | 인퍼런스 3회, FIFO gap 10% | PASS |
| fc_fifo_stress_test | FIFO 선적재(full/backpressure 1,338클럭) + 큰 gap(starvation) | PASS |
| fc_extreme_test | 누산 최대/최소 (−128×−128, −128×127) | PASS |
| fc_requant_corner_test | shift −4~4, 작은 mult → tie / 좌시프트 / 비포화 | PASS |
| fc_ctrl_corner_test | fc_sel=3 무시, 레이어 실행 중 fc_start 무시 | PASS |

레이어 지연 : FC1 81,934 / FC2 2,062 / FC3 397 cycles (= 출력 수 × 그룹 수 + 파이프라인)

### Unit (`unit/`)
| 블록 | 테스트 | 결과 |
|---|---|---|
| fifo | rand / fill_drain / simul / reset | 4/4 PASS |
| mac | rand / extreme / bubble | 3/3 PASS |
| requant | rand / tie / boundary / shift_range / bug_demo | 5/5 PASS (수정 후) |

### Coverage (DUT 기준)
| 대상 | Line | Cond | Toggle | FSM | Branch | Functional |
|---|---|---|---|---|---|---|
| fc_top (6개 테스트 머지) | 92.70 | 96.36 | 97.80 | 75.00 | 86.27 | 100 (cg_rq / cg_start / cg_fifo) |
| fifo | 100 | 100 | 77.27 | – | 100 | – |
| mac | 100 | 100 | 99.94 | – | 100 | – |
| requant | 93.27 | 100 | 99.85 | – | 79.41 | – |

> `urgReport/dashboard.txt` 의 Total 점수에는 UVM 패키지 코드가 포함되어 있어 실제보다 낮게 표시됩니다. 위 표는 `hierarchy.txt` 의 `dut` 인스턴스 기준입니다.

---

## 4. Bug Report : requant shift 범위 overflow

`rq_shift_range_test` (shift −40~−1, 64~80) 에서 **2,000건 중 785건 불일치**가 발생했습니다.

| 증상 | 예시 | DUT | REF |
|---|---|---|---|
| shift ≥ 65 에서 0 이어야 할 값이 −1 | acc=791260429, mult=296201, shift=65 | −1 | 0 |
| 큰 음수 shift 에서 포화 부호 반전 | acc=−329309601, mult=954385, shift=−16 | 127 | −127 |

**원인** (`bug_history/requant_before/rtl/requant_core.sv`)
1. 반올림 offset `65'sd1 <<< (shift−1)` 가 shift=65 일 때 65bit 부호 비트로 들어가 음수 offset이 됨
2. shift > 65 일 때 offset이 0이 되면서 음수 경로의 `−1` 만 남아 결과가 −1
3. 음수 shift는 `rounded <<< (−shift)` 를 65bit 안에서 수행해 상위 비트가 잘리면서 부호가 바뀜

**수정** (`unit/requant/rtl/requant_core.sv`)
- 반올림/시프트 경로를 66bit 로 확장하고 offset 생성을 `0 < shift ≤ 65` 로 제한
- shift > 65 는 0 으로 처리
- 음수 shift −1~−6 은 시프트 전에 범위 검사 후 포화, −7 이하는 부호에 따라 바로 ±127 포화

수정 전/후 같은 TB로 재실행해 shift_range 785 → 0, bug_demo 3 → 0 으로 확인했습니다.
(`bug_history/requant_before/logs/` vs `unit/requant/*.log`)

---

## 5. 실행 방법

각 폴더(`fc_top/`, `unit/fifo/`, `unit/mac/`, `unit/requant/`)에서:

```bash
make simv TEST=<test_name> SEED=<seed>   # 컴파일 + 단일 테스트
make regress                              # 전체 테스트 + PASS/FAIL 요약 + 커버리지 머지
make verdi TEST=<test_name>               # 파형 확인
make cov                                  # urg 리포트 생성
```

수정 전 requant 를 재현하려면 `bug_history/requant_before/rtl/requant_core.sv` 를
`unit/requant/rtl/` 에 덮어쓴 뒤 `make simv TEST=rq_shift_range_test` 를 실행합니다.

---

## 6. 폴더 구조

```
fc_uvm_verification/
├── fc_top/                 통합 검증 (rtl, tb, Makefile, 테스트 로그, urgReport 요약)
├── unit/
│   ├── fifo/
│   ├── mac/
│   └── requant/            버그 수정 후 버전
└── bug_history/
    └── requant_before/     수정 전 RTL + FAIL 로그
```

## 7. 향후 보완 사항
- requant 음수 shift −5, −6 의 비포화 경로 및 곱이 0 인 경로 directed 테스트 추가
- 통합 레벨 동작 중 리셋 테스트 추가 (controller S_RUN → S_IDLE 전이)
