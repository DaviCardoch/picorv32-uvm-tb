# Plano de implementação — testbench UVM do PicoRV32 (TCC2)

> Origem: discussão de encerramento do TCC1 (2026-08-28), a partir do plano de
> verificação já fechado em `tex/3_Metodologia.tex` do repositório da
> monografia (`UnB_CIC/`): DUT = PicoRV32, agents Memory + IRQ, scoreboard,
> cobertura funcional e assertivas SVA, metas OBJ-01..OBJ-07. Este repositório
> é separado do repositório da monografia (que é só LaTeX/escrita).

## 0. Onde o código mora

Este repo (`picorv32-uvm-tb/`) é o projeto de implementação em si, separado do
repositório da monografia. Estrutura inicial:

```
picorv32-uvm-tb/
├── rtl/picorv32/   # submódulo git de github.com/YosysHQ/picorv32, pinado em a473fc8 (ISC License)
├── tb/
│   ├── interfaces/ # mem_if.sv, irq_if.sv
│   ├── agents/     # memory_agent/, irq_agent/
│   ├── env/        # scoreboard, coverage collector, env
│   ├── seq/        # sequences (diretas e constrained-random)
│   ├── tests/      # base_test + testes específicos
│   └── sva/        # checkers de assertiva
├── sim/            # filelists (.f), scripts vcs/verdi, Makefile
└── fw/             # pequenos programas RV32I em asm/C usados como "firmware" de teste
```

## 1. Decisão de projeto a resolver antes de codificar

**Parte já decidida (Figura 3.2 / texto da Seção 3.2):** o PicoRV32 usa um
único barramento para busca de instrução e acesso a dados, diferenciado pelo
sinal `mem_instr`. O próprio texto que acompanha a Figura 3.2 já trata a
leitura do Tag ID como um acesso de dado (`mem_instr = 0`, "já que nenhuma
das duas é uma busca de instrução"), distinto de uma busca de instrução
(`mem_instr = 1`). Isso não precisa ser redecidido: instruções não devem vir
de dados aleatórios, senão o núcleo executa opcodes inválidos e trava antes
de chegar nos cenários de Tag ID/CRC (OBJ-01/OBJ-02).

**Parte ainda em aberto:** dentro do próprio barramento de dados
(`mem_instr = 0`), nem todo acesso é um pacote de Tag ID/CRC. Um programa
RV32I real também usa a memória de dados para pilha (push/pop de `ra`,
variáveis locais) e essas respostas precisam continuar coerentes, senão o
núcleo corrompe a pilha e trava antes de qualquer cenário relevante. Ou seja,
falta definir um **mapa de endereços** para o Memory Agent.

### 1.1 Mapa de endereços proposto (rascunho, a validar na Fase B)

O IRQ do PicoRV32 **não** passa pelo barramento de memória (é a porta
dedicada `irq[31:0]` + instruções customizadas `getq`/`setq`/`maskirq`/
`waitirq`/`retirq`), então o mapa abaixo só precisa resolver instrução vs.
RAM de dados vs. registrador emulado de RF:

| Faixa de endereço          | Tamanho | Uso                                            | Política de resposta do Memory Agent |
|-----------------------------|---------|-------------------------------------------------|----------------------------------------|
| `0x0000_0000`–`0x0000_3FFF` | 16 KB   | Memória de instrução (`mem_instr=1`)            | Sempre serve o firmware real pré-carregado (Fase A/B) |
| `0x0001_0000`–`0x0001_3FFF` | 16 KB   | RAM de dados (pilha crescendo de cima pra baixo, `.data`/`.bss`) | Memória associativa simples: devolve o que foi escrito antes; nunca randomizada |
| `0x1000_0000`               | 4 B     | `TAG_ID` — identificador do piloto recebido (somente leitura do ponto de vista do núcleo) | Valor vem da sequence ativa (OBJ-01: faixa completa, incluindo extremos) |
| `0x1000_0004`               | 4 B     | `CRC_STATUS` — resultado da checagem de CRC do pacote recebido | Codificado pela sequence: `0`=válido, `1`=inválido em 1 bit, `2`=inválido em múltiplos bits (bate direto com OBJ-02) |
| `0x1000_0008`               | 4 B     | `PKT_STATUS` — flag de "novo pacote disponível" (reservado; pode nascer fixo em 1 na Fase B e virar dinâmico depois) | Fase B: constante; depois pode variar por sequence |
| `0x1000_000C` em diante      | —       | Reservado (ex.: RSSI, ID de antena, se algum dia entrar no escopo) | Não implementado ainda |
| Qualquer outro endereço     | —       | Acesso fora do mapa conhecido                   | Tratar como erro/flag no scoreboard (útil como checagem extra, não estava nas metas originais) |

Esse mapa é um ponto de partida, não algo já fechado com o orientador nem
com o capítulo 3 da monografia — faz sentido revisar (endereços, largura dos
campos, se `PKT_STATUS` deveria existir desde já) junto com a implementação
real da Fase B, e só depois espelhar no capítulo de metodologia caso vire de
fato a decisão adotada.

## 2. Ambiente (WSL + Rocky Linux + VCS/Verdi)

**Status: validado em 2026-08-28.** VCS X-2025.06-SP2 e Verdi X-2025.06-SP2
instalados em `/opt/synopsys/`, `VCS_HOME`/`VERDI_HOME` setados, licença via
`LM_LICENSE_FILE=<porta>@<servidor>` (servidor de licenças da instituição) respondendo normalmente
(`vcs -full64 -help` roda sem erro de licença). Toolchain cruzado RISC-V
(`binutils-riscv64-linux-gnu`, `gcc-riscv64-linux-gnu`, alvo `rv32i`/`ilp32`)
instalado via `dnf` para montar firmware de teste sem precisar calcular
opcodes na mão.

Itens ainda pendentes da checklist original:

1. ~~Licença/`vcs -full64 -help`~~ — feito.
2. Confirmar qual biblioteca UVM vem empacotada com a versão de VCS
   (`$VCS_HOME/etc/uvm-1.2` ou similar) — define se compila com
   `-ntb_opts uvm-1.2` ou aponta pro `UVM_HOME` manualmente. Só entra de
   fato na Fase B (primeiro código UVM).
3. Rodar um "hello world" SystemVerilog/UVM trivial (um `uvm_test` que só
   imprime `uvm_info` e termina) pra confirmar que compilação
   (`vcs -sverilog ...`) e simulação (`./simv +UVM_TESTNAME=...`) fecham o
   ciclo antes de tocar no PicoRV32. Também Fase B.
4. ~~Compilar o PicoRV32 sozinho, sem testbench UVM~~ — feito na Fase A
   (ver abaixo).

## 3. Fases de implementação

**Fase A — Bring-up passivo (sem UVM ainda) — CONCLUÍDA em 2026-08-28**
Wrapper SV simples + memória de instrução pré-carregada rodando um
programinha (soma, loop, `ecall`) direto no VCS, visualizando em Verdi.
Objetivo: confirmar que dá pra carregar firmware na memória do testbench e
ler waveform do handshake `mem_valid`/`mem_ready` já documentado na figura de
handshake do capítulo 3 da monografia.

Implementado em `fw/phaseA_smoke.S` (RV32I puro, monta com o toolchain
`riscv64-linux-gnu-{as,ld,objcopy}` via `fw/Makefile`) e `sim/tb_phaseA.sv`
(instancia o `picorv32` nativo direto do submódulo, com memória de
instrução/dados seguindo `tb/interfaces/mem_map.svh` e 1 ciclo de espera por
transação, batendo com a Figura 3.2). Rodar com `sim/run_phaseA.sh`.
Resultado validado no VCS X-2025.06-SP2: soma 1+2+3+4+5 = 15 corretamente
gravada e relida na RAM de dados, `ecall` dispara `trap` e encerra a
simulação como esperado. Waveform (`tb_phaseA.vcd`) pronta pra abrir no
Verdi (`verdi -ssf tb_phaseA.vcd`), ainda não inspecionada visualmente por
Davi.

**Fase B — Interfaces e Memory Agent mínimo — CONCLUÍDA em 2026-09-07**
Interfaces `mem_if`/`irq_if`, Memory Agent completo com driver **reativo**
(o DUT é o mestre do barramento: o driver responde como escravo, com três
políticas conforme o mapa da Seção 1.1) e teste dirigido `rf_smoke_test`
(4 pacotes: extremos de tag + os 3 estados de CRC). Decisões tomadas nesta
fase: registradores de resultado `RESULT_TAG`/`RESULT_STATUS` no mapa (dão
ao scoreboard uma saída observável fim-a-fim através do software executado
pelo núcleo) e firmware `fw/uvm_fw.S` em loop eterno de polling (quem
encerra o teste é a objection UVM, não o firmware). Validada no VCS: os 4
pacotes processados corretamente, 0 UVM_ERROR.

**Fase C — Scoreboard + cobertura + urg — CONCLUÍDA em 2026-09-07**
`tb_scoreboard` passivo (modelo de referência montado só do tráfego do
monitor) e `tb_coverage` com OBJ-01/02/03 + cruzamento tag×CRC. Fluxo
`urg` com cobertura de código restrita ao DUT (`cm_hier.cfg`), relatório
HTML em `sim/urg_report/`. Validada: 4 pacotes OK / 0 divergências.

**Fase D — IRQ Agent — CONCLUÍDA em 2026-09-07**
IRQ Agent completo (pulso de 1 ciclo, serializado pelo ciclo de EOI),
handler de interrupção real no firmware (salva contexto em q2/q3, publica
o bitmask q1 no novo registrador `IRQ_ACK`, retorna com `retirq`),
scoreboard casando cada pulso com o reconhecimento, `cg_irq` com 32 bins
(OBJ-04) e o checker SVA de EOI via `bind` (OBJ-07, ancorado na busca da
codificação 0x0400000B de retirq). Validada: 3 IRQs dirigidas (linhas 3,
0, 31) com ciclo completo, SVAs com antecedente real, 0 erros.

**Fase E — Constrained-random + sequência virtual — CONCLUÍDA em 2026-09-07**
Distribuição ponderada de tag (extremos com peso explícito), janela "IRQ
ativa" cruzada com formato de instrução (completa OBJ-05), sequencer
virtual `tb_vseqr` + `mixed_rand_vseq` rodando pacotes e IRQs em paralelo,
teste `mixed_rand_test` configurável por plusargs. Validada: 30 pacotes +
20 IRQs random, 0 divergências.

**Fase F — Assertivas de barramento (OBJ-06) — CONCLUÍDA em 2026-09-07**
`mem_protocol_checker` via `bind`: estabilidade de valid/addr/controle até
o handshake e exclusão mútua escrita×fetch. Validada nos dois sentidos:
tráfego limpo passa (0 erros) e injeção proposital de erro
(`+inject_proto_err` força wstrb durante fetch) dispara as assertivas.

**Fase G — Regressão e fechamento — CONCLUÍDA em 2026-09-07**
`sim/run_regress.sh`: 2 dirigidos + 3 seeds do random (200 pacotes, 243
IRQs). Resultado: **todos os testes PASS, cobertura funcional consolidada
100%** (OBJ-01..05 fechados), assertivas com sucessos não-vacuosos e 0
falhas (OBJ-06/07). Cobertura de código do DUT: linha ~60%, cond ~55%,
toggle ~66%, branch ~49%.

## Próximos passos (pós Fase G)

1. **Análise de exclusões de cobertura de código** com o orientador: os
   buracos concentram-se em lógica desabilitada por configuração do core
   (ENABLE_MUL/DIV=0, COMPRESSED_ISA=0, trace, PCPI); escrever exclusões
   justificadas e recalcular o score é a discussão natural do capítulo 4
   (Análise) do TCC2.
2. **Figuras para a monografia**: waveforms no Verdi (handshake, ciclo de
   IRQ/EOI) e prints do relatório urg; ver a pendência de GUI do Verdi
   (WSLg/VcXsrv) nas notas do projeto.
3. Possíveis extensões (bônus): disparo *interno* real das IRQs 0..2
   (temporizador via instrução `timer`, instrução ilegal, acesso
   desalinhado), atrasos aleatórios de mem_ready no driver (wait states
   variáveis), mais seeds na regressão.
