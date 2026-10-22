VCS_OPTS = -full64 -sverilog
VCS_OPTS += -ntb_opts uvm-1.2
VCS_OPTS += -timescale=1ns/1ps
VCS_OPTS += -debug_access+all -kdb -lca
VCS_OPTS += -cm line+cond+fsm+tgl+branch+assert
VCS_OPTS += -cm_dir coverage.vdb
VCS_INCDIR = +incdir+tb +incdir+rtl
VCS_OUTPUT = -o simv -l comp.log
VCS_SRC_FILES = ./rtl/fc_mac.sv \
                ./tb/fc_ref_pkg.sv ./tb/mac_if.sv ./tb/mac_pkg.sv ./tb/tb_top.sv

TEST ?= mac_rand_test
SEED ?= 1
INFO_LEVEL ?= UVM_LOW
TESTS ?= mac_rand_test mac_extreme_test mac_bubble_test

SIMV_OPTS = +UVM_TESTNAME=$(TEST)
SIMV_OPTS += +UVM_VERBOSITY=$(INFO_LEVEL)
SIMV_OPTS += +ntb_random_seed=$(SEED)
SIMV_OPTS += +FSDB_FILE=$(TEST).fsdb
SIMV_OPTS += -cm line+cond+fsm+tgl+branch+assert
SIMV_OPTS += -cm_dir coverage.vdb
SIMV_OPTS += -cm_name $(TEST)_$(SEED)
SIMV_OPTS += -l $(TEST).log


.PHONY: all compile sim comp simv regress verdi cov cov_gui clean

all: simv

# 설계가 바뀌면 이전 커버리지 데이터와 머지가 안 되므로 새로 만든다
# (simv/csrc 도 지워야 VCS 증분 컴파일이 coverage.vdb 를 다시 생성함)
compile:
	@rm -rf coverage.vdb simv simv.daidir csrc
	@vcs  $(VCS_OPTS) $(VCS_INCDIR) $(VCS_SRC_FILES) $(VCS_OUTPUT)
	@echo "타겟 [$@]"

sim:
	@./simv $(SIMV_OPTS)
	@echo "타겟 [$@] : $(TEST) (seed=$(SEED)) -> $(TEST).log"

# SPI 프로젝트와 같은 이름의 별칭
comp: compile

simv: compile
	@$(MAKE) --no-print-directory sim
	@echo "의존 타겟 [$<]"
	@echo "타겟 [$@]"

# 전체 테스트 + PASS/FAIL 요약 + 커버리지 머지
regress: compile
	@for t in $(TESTS); do \
	    $(MAKE) --no-print-directory sim TEST=$$t SEED=$$RANDOM > /dev/null; \
	    E=$$(grep -E "^UVM_ERROR\s*:\s*[0-9]+" $$t.log | awk '{print $$3}'); \
	    F=$$(grep -E "^UVM_FATAL\s*:\s*[0-9]+" $$t.log | awk '{print $$3}'); \
	    if [ "$$E" = "0" ] && [ "$$F" = "0" ]; then echo "PASS  $$t"; else echo "FAIL  $$t (ERR=$$E FATAL=$$F)"; fi; \
	done
	@urg -dir coverage.vdb -report urgReport -format both > /dev/null
	@echo "커버리지 리포트 : urgReport/dashboard.html"

verdi:
	@verdi -ssf $(TEST).fsdb -dbdir simv.daidir &

cov:
	@urg -dir coverage.vdb -report urgReport -format both
	@echo "커버리지 리포트 : urgReport/dashboard.html"

cov_gui:
	@verdi -cov -covdir coverage.vdb &

clean:
	@rm -rf simv* csrc *.log *.key *.h *.fsdb coverage.vdb urgReport vdCovLog verdiLog novas* .fsm.sch.verilog.xml
	@echo "결과물 정리 중 ..."
