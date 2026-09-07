#!/usr/bin/env bash
# Compila e roda o testbench UVM no VCS, acumulando cobertura de codigo
# (restrita ao DUT) e cobertura funcional (covergroups), e gera o relatorio
# urg em urg_report/ (abrir urg_report/dashboard.html em qualquer navegador).
#
# Uso: cd sim && ./run_uvm.sh [nome_do_teste] [+plusargs extras...]
# Ex.:  ./run_uvm.sh rf_smoke_test
#       ./run_uvm.sh rf_smoke_test +vcd +UVM_VERBOSITY=UVM_HIGH
set -euo pipefail
cd "$(dirname "$0")"

TEST="${1:-rf_smoke_test}"
shift || true

CM="line+cond+branch+tgl"

echo "== montando firmware =="
make -C ../fw uvm_fw.hex

echo "== compilando no VCS (UVM 1.2) =="
vcs -full64 -sverilog -ntb_opts uvm-1.2 \
    -timescale=1ns/1ps \
    -f files.f \
    -o simv_uvm \
    -debug_access+all \
    -cm ${CM} -cm_hier cm_hier.cfg \
    -l vcs_uvm_compile.log > /dev/null

echo "== simulando: ${TEST} =="
./simv_uvm +UVM_TESTNAME="${TEST}" +firmware=../fw/uvm_fw.hex \
    -cm ${CM} -cm_name "${TEST}" \
    "$@" -l "simv_${TEST}.log" > /dev/null || true

echo "== resumo UVM =="
grep -E "UVM_(ERROR|FATAL) :|\[SB\] resumo|\[COV\]" "simv_${TEST}.log" || true

echo "== relatorio de cobertura (urg) =="
urg -dir simv_uvm.vdb -format both -report urg_report > /dev/null
grep -A6 "Total Coverage Summary" urg_report/dashboard.txt 2>/dev/null | head -10 || true
grep -A8 "Total Groups Coverage Summary" urg_report/dashboard.txt 2>/dev/null | head -12 || true
