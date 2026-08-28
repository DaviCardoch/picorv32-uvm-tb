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

**Fase B — Interfaces e Memory Agent mínimo**
- `mem_if` (interface SV com clocking block) para os sinais `mem_*`.
- Transação (`uvm_sequence_item`) representando uma resposta de memória
  (instrução válida vs. pacote de dado com Tag ID/CRC).
- Driver, sequencer, monitor do Memory Agent, aplicando a distinção
  instrução/dado da Seção 1.
- Um teste dirigido (não random ainda): sobe o núcleo, ele busca algumas
  instruções, faz uma leitura de "Tag ID" com CRC válido. Rodar em VCS,
  depurar em Verdi (waveform + navegador de hierarquia UVM).

**Fase C — Scoreboard mínimo + primeiro coverpoint**
Scoreboard que apenas confere que toda transação de leitura observada pelo
monitor bate com o que o driver decidiu enviar (checagem passiva simples).
Adicionar o `covergroup` de faixa de Tag ID (OBJ-01) e rodar cobertura pela
primeira vez (`urg`/Verdi coverage) — mesmo que baixa, serve pra validar que
o pipeline de coverage database está funcionando.

**Fase D — IRQ Agent**
Repetir o padrão da Fase B/C para interrupções: sequencer/driver/monitor de
IRQ, teste dirigido levantando uma IRQ e checando a assertiva de EOI
(OBJ-07) — boa candidata a já nascer em SVA (`bind` no DUT) em vez de
checagem em SystemVerilog puro no scoreboard.

**Fase E — Sequences constrained-random + cobertura cruzada**
Sequences que geram Tag ID em toda a faixa (incluindo extremos), CRC
válido/inválido (1 bit vs. múltiplos bits), e tipos de instrução variados.
Cross coverage IRQ × tipo de instrução e CRC × Tag ID (OBJ-05). Se a
ordenação entre os dois sequencers precisar ser coordenada (ex.: IRQ
chegando no meio de uma leitura), entra a sequência virtual mencionada no
capítulo 2 da monografia.

**Fase F — Assertivas de barramento (OBJ-06)**
Estabilidade de `mem_valid`/`mem_addr` até o handshake, ausência de
`mem_wstrb` ativo com `mem_instr` alto — direto em SVA, bindado no DUT,
checável isoladamente até com testes dirigidos da Fase B.

**Fase G — Regressão e fechamento de cobertura**
Rodar a suíte completa em regressão, usar o coverage browser do Verdi pra
achar buracos, ajustar constraints/pesos das sequences, iterar até bater um
critério de cobertura razoável para reportar no capítulo 4 (Análise) do
TCC2.

## Próximo passo concreto

Fase A concluída. Antes de partir pra Fase B (Memory Agent UVM real), vale
Davi abrir `sim/tb_phaseA.vcd` no Verdi pra conferir visualmente o handshake
`mem_valid`/`mem_ready` contra a Figura 3.2 — é rápido e serve como primeiro
contato com o Verdi neste projeto. Depois disso, a Fase B começa por
descobrir a biblioteca UVM empacotada no VCS (item 2 pendente da seção 2) e
só então escrever a primeira transação/sequencer/driver do Memory Agent.
