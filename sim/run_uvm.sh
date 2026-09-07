#!/usr/bin/env bash
# Compila e roda o testbench UVM no VCS.
# Uso: cd sim && ./run_uvm.sh [nome_do_teste] [+plusargs extras...]
# Ex.:  ./run_uvm.sh rf_smoke_test
#       ./run_uvm.sh rf_smoke_test +vcd +UVM_VERBOSITY=UVM_HIGH
set -euo pipefail
cd "$(dirname "$0")"

TEST="${1:-rf_smoke_test}"
shift || true

echo "== montando firmware =="
make -C ../fw uvm_fw.hex

echo "== compilando no VCS (UVM 1.2) =="
vcs -full64 -sverilog -ntb_opts uvm-1.2 \
    -timescale=1ns/1ps \
    -f files.f \
    -o simv_uvm \
    -debug_access+all \
    -l vcs_uvm_compile.log > /dev/null

echo "== simulando: ${TEST} =="
./simv_uvm +UVM_TESTNAME="${TEST}" +firmware=../fw/uvm_fw.hex "$@" -l "simv_${TEST}.log" > /dev/null || true

echo "== resumo =="
grep -E "UVM_(ERROR|FATAL) :|TEST.*(PASS|FAIL)|--- UVM Report" "simv_${TEST}.log" || true
tail -n 5 "simv_${TEST}.log"
