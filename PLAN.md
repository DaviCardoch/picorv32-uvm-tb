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
├── rtl/            # PicoRV32 (submódulo git do repo oficial cliffordwolf/picorv32)
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

O PicoRV32 usa **um único barramento** para busca de instrução e acesso a
dados, diferenciado só pelo sinal `mem_instr`. Isso significa que o Memory
Agent não pode simplesmente randomizar toda resposta em `mem_rdata`: se ele
responder lixo também nos fetches de instrução (`mem_instr=1`), o núcleo
executa opcodes inválidos e trava/gera exceção quase imediatamente, sem nunca
chegar nos cenários de Tag ID/CRC que são o objetivo real (OBJ-01/OBJ-02).

Ou seja, o driver do Memory Agent precisa, na prática, de **duas políticas de
resposta**:

- `mem_instr = 1` → serve instruções válidas de um programa RV32I real
  pré-carregado (um "firmware" mínimo compilado com o `riscv-gnu-toolchain`
  ou escrito à mão em assembly), para o núcleo ter algo coerente pra
  executar;
- `mem_instr = 0` → é onde entra a emulação do restante do transponder: aqui
  sim o driver injeta os pacotes com Tag ID/CRC (válidos, corrompidos etc.)
  conforme as sequences constrained-random.

Vale decidir isso logo e, se fizer sentido, registrar essa distinção
explicitamente na Seção 3.3 do capítulo de metodologia da monografia (é uma
consequência direta do protocolo que já está descrito lá, só não está
explicitado ainda).

## 2. Ambiente (WSL + Rocky Linux + VCS/Verdi)

Antes de escrever UVM, validar a base:

1. Confirmar licença acessível (`LM_LICENSE_FILE` ou servidor) e
   `vcs -full64 -help` rodando sem erro dentro do WSL.
2. Confirmar qual biblioteca UVM vem empacotada com a versão de VCS
   (`$VCS_HOME/etc/uvm-1.2` ou similar) — define se compila com
   `-ntb_opts uvm-1.2` ou aponta pro `UVM_HOME` manualmente.
3. Rodar um "hello world" SystemVerilog/UVM trivial (um `uvm_test` que só
   imprime `uvm_info` e termina) pra confirmar que compilação
   (`vcs -sverilog ...`) e simulação (`./simv +UVM_TESTNAME=...`) fecham o
   ciclo antes de tocar no PicoRV32.
4. Puxar o PicoRV32 (`github.com/YosysHQ/picorv32`) e compilar **sozinho, sem
   testbench UVM**, com um wrapper simples (`mem_ready` sempre alto, memória
   associativa simples) só pra confirmar que o core em si simula e executa
   um programa trivial. Isso separa bugs de "ambiente/DUT" de bugs de
   "testbench".

## 3. Fases de implementação

**Fase A — Bring-up passivo (sem UVM ainda)**
Wrapper SV simples + memória de instrução pré-carregada rodando um
programinha (soma, loop, `ecall`) direto no VCS, visualizando em Verdi.
Objetivo: confirmar que dá pra carregar firmware na memória do testbench e
ler waveform do handshake `mem_valid`/`mem_ready` já documentado na figura de
handshake do capítulo 3 da monografia.

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

Começar pela **Fase A** (bring-up do PicoRV32 sozinho, sem UVM): rápido,
valida o ambiente VCS/Verdi de ponta a ponta, e evita descobrir problemas de
licença/toolchain só depois de já ter escrito agents inteiros.
