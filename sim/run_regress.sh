#!/usr/bin/env bash
# Regressao da Fase G: compila uma vez, roda a suite (dirigidos + random
# com multiplos seeds), consolida pass/fail e mescla toda a cobertura
# (codigo + funcional + assertivas) num unico relatorio urg.
#
# Uso: cd sim && ./run_regress.sh
# Relatorio final: urg_report/dashboard.html (abrir no navegador)
set -uo pipefail
cd "$(dirname "$0")"

CM="line+cond+branch+tgl+assert"

echo "== montando firmware =="
make -C ../fw uvm_fw.hex > /dev/null

echo "== compilando =="
rm -rf simv_uvm.vdb urg_report
vcs -full64 -sverilog -ntb_opts uvm-1.2 \
    -timescale=1ns/1ps \
    -f files.f \
    -top tb_top \
    -o simv_uvm \
    -debug_access+all \
    -cm ${CM} -cm_hier cm_hier.cfg \
    -l vcs_uvm_compile.log > /dev/null

# teste|tag|plusargs
RUNS=(
    "rf_smoke_test|rf_smoke|"
    "irq_smoke_test|irq_smoke|"
    "mixed_rand_test|rand_s1|+ntb_random_seed=1 +num_pkts=50 +num_irqs=60"
    "mixed_rand_test|rand_s2|+ntb_random_seed=2 +num_pkts=50 +num_irqs=60"
    "mixed_rand_test|rand_s3|+ntb_random_seed=3 +num_pkts=100 +num_irqs=120"
)

echo "== rodando a suite =="
NFAIL=0
for run in "${RUNS[@]}"; do
    IFS="|" read -r test tag args <<< "$run"
    ./simv_uvm +UVM_TESTNAME="$test" +firmware=../fw/uvm_fw.hex \
        ${args} -cm ${CM} -cm_name "$tag" -l "simv_${tag}.log" > /dev/null 2>&1
    nerr=$(grep -E "^UVM_ERROR :" "simv_${tag}.log" | awk "{print \$3}")
    nfat=$(grep -E "^UVM_FATAL :" "simv_${tag}.log" | awk "{print \$3}")
    if [[ "${nerr:-1}" == "0" && "${nfat:-1}" == "0" ]]; then
        echo "  PASS  ${tag} (${test} ${args})"
    else
        echo "  FAIL  ${tag} (${test} ${args}) -- UVM_ERROR=${nerr:-?} UVM_FATAL=${nfat:-?}"
        NFAIL=$((NFAIL+1))
    fi
    grep -E "\[COV\] cobertura funcional" "simv_${tag}.log" | sed "s/^UVM_INFO.*\[COV\]/    cov:/" || true
done

echo "== cobertura consolidada (urg) =="
urg -dir simv_uvm.vdb -format both -report urg_report > /dev/null
grep -A3 "Total Coverage Summary" urg_report/dashboard.txt | head -6
grep -A6 "Total Groups Coverage Summary" urg_report/dashboard.txt | head -9

echo
if [[ $NFAIL -eq 0 ]]; then
    echo "REGRESSAO: PASS (todos os testes limpos)"
else
    echo "REGRESSAO: FAIL (${NFAIL} teste(s) com erro)"
fi
exit $NFAIL
