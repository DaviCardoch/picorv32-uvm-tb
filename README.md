# picorv32-uvm-tb

Testbench UVM para verificacao funcional do nucleo RISC-V PicoRV32,
desenvolvido como parte do trabalho de conclusao de curso (CIC/UnB) sobre
verificacao do processador embarcado de um transponder de cronometragem
esportiva. O plano de verificacao implementado aqui e o do Capitulo 3 da
monografia (repositorio separado, `UnB_CIC/`): agents dedicados as
interfaces de memoria e de interrupcao, scoreboard e cobertura
compartilhados, e assertivas SVA anexadas ao DUT via bind.

## Arquitetura

```
tb_top (DUT: picorv32 nativo, ENABLE_IRQ=1)
└── test (base_test / rf_smoke_test / irq_smoke_test / mixed_rand_test)
    └── tb_env
        ├── mem_agent   (driver reativo: firmware + RAM + regs de RF emulados)
        ├── irq_agent   (pulsos nas 32 linhas de IRQ, serializado por EOI)
        ├── tb_scoreboard (modelo de referencia passivo sobre o barramento)
        ├── tb_coverage (OBJ-01..05: covergroups + cruzamentos)
        └── tb_vseqr    (sequencer virtual p/ estimulo misto)
    [bind no DUT] irq_eoi_checker (OBJ-07) + mem_protocol_checker (OBJ-06)
```

O PicoRV32 e o mestre do barramento, entao o driver do Memory Agent atua
como escravo com tres politicas de resposta (mapa em
`tb/interfaces/mem_map.svh`): memoria de instrucao serve o firmware real
(`fw/uvm_fw.S`), a RAM de dados e uma memoria associativa coerente, e os
registradores emulados de RF (TAG_ID/CRC_STATUS/...) sao servidos pelos
itens das sequences: e por ali que o estimulo constrained-random emula, em
nivel logico, o front-end analogico/RF do transponder.

## Requisitos

- WSL/Linux com Synopsys VCS + Verdi (testado com X-2025.06-SP2, UVM 1.2)
- Toolchain RISC-V para o firmware: `binutils-riscv64-linux-gnu` +
  `gcc-riscv64-linux-gnu` (alvo `-march=rv32i -mabi=ilp32`)
- `rtl/picorv32` e submodulo git: `git submodule update --init`

## Como rodar

```sh
cd sim

./run_phaseA.sh                  # bring-up sem UVM (Fase A)
./run_uvm.sh rf_smoke_test       # dirigido: 4 pacotes (extremos + 3 CRCs)
./run_uvm.sh irq_smoke_test      # dirigido: IRQs nas linhas 3, 0 e 31
./run_uvm.sh mixed_rand_test +num_pkts=50 +num_irqs=60   # random misto
./run_regress.sh                 # suite completa + cobertura consolidada
```

O relatorio de cobertura (codigo + funcional + assertivas) sai em
`sim/urg_report/dashboard.html`. Waveform: adicionar `+vcd` a qualquer
teste e abrir `tb_top.vcd` no Verdi.

Demonstracao de deteccao das assertivas de protocolo (termina com
UVM_ERROR de proposito):

```sh
./simv_uvm +UVM_TESTNAME=rf_smoke_test +firmware=../fw/uvm_fw.hex +inject_proto_err
./simv_uvm +UVM_TESTNAME=rf_smoke_test +firmware=../fw/uvm_fw.hex +inject_valid_err
./simv_uvm +UVM_TESTNAME=rf_smoke_test +firmware=../fw/uvm_fw.hex +inject_addr_err
```

`+inject_proto_err` dispara `a_ctrl_estavel` e `a_sem_escrita_em_fetch`;
`+inject_valid_err` dispara `a_valid_estavel`; `+inject_addr_err` dispara
`a_addr_estavel`.

Demonstracao de deteccao das assertivas de EOI, atrasando `eoi` na primeira
interrupcao do teste (N=1 dispara `a_eoi_sobe` e N=4 dispara `a_eoi_encerra`;
N=0 e N=3, respectivamente, ficam dentro do prazo e nao geram erro):

```sh
./simv_uvm +UVM_TESTNAME=irq_smoke_test +firmware=../fw/uvm_fw.hex +inject_eoi_sobe=1
./simv_uvm +UVM_TESTNAME=irq_smoke_test +firmware=../fw/uvm_fw.hex +inject_eoi_encerra=4
```

## Estado (regressao de referencia)

Suite: 2 dirigidos + 3 seeds do random misto (204 pacotes e 243 IRQs no
total). Resultado: todos os testes limpos, 0 divergencias de scoreboard,
cobertura funcional consolidada 100% (todas as metas OBJ-01..05 fechadas;
OBJ-06/07 via assertivas com sucessos nao-vacuosos e zero falhas).
Cobertura de codigo do DUT: linha ~60%, toggle ~66%, branch ~49%; os
buracos concentram-se em logica desabilitada por configuracao (MUL/DIV,
ISA comprimida, trace, PCPI), a analisar/excluir na etapa de fechamento.

`PLAN.md` registra o historico fase a fase (A ate G) com os resultados de
validacao de cada uma.
