#!/usr/bin/env bash
# Fase A -- monta o firmware e compila/roda o bring-up passivo no VCS.
# Uso: cd sim && ./run_phaseA.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "== montando firmware =="
make -C ../fw

echo "== compilando no VCS =="
vcs -full64 -sverilog \
    +incdir+../tb/interfaces \
    ../rtl/picorv32/picorv32.v \
    tb_phaseA.sv \
    -o simv_phaseA \
    -debug_access+all \
    -l vcs_compile.log

echo "== simulando =="
./simv_phaseA +vcd +firmware=../fw/firmware.hex -l simv_phaseA.log
tail -n 20 simv_phaseA.log

echo
echo "Para depurar no Verdi: verdi -ssf tb_phaseA.vcd &"
