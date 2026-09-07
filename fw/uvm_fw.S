/*
 * Firmware do testbench UVM (Fase B em diante). Emula o software embarcado
 * do transponder em nivel minimo: fica em polling no registrador PKT_STATUS
 * e, a cada pacote de RF anunciado pelo Memory Agent, le TAG_ID e
 * CRC_STATUS, decide aceitar (CRC valido) ou rejeitar, e escreve o veredito
 * nos registradores de resultado, que o scoreboard observa pelo barramento.
 *
 * O laco roda para sempre; quem encerra a simulacao e o proprio UVM
 * (objection do teste), nao o firmware.
 *
 * O trecho principal exercita os seis formatos de instrucao do RV32I
 * (R, I, S, B, U, J), o que alimenta o coverpoint de tipos de instrucao
 * (OBJ-03) sem esforco extra.
 *
 * Mapa de enderecos: tb/interfaces/mem_map.svh (base RF = 0x1000_0000).
 */

#include "custom_ops.S"              /* macros getq/setq/retirq/maskirq (repo picorv32, dominio publico) */

#define RF_BASE_HI     0x10000      /* lui: 0x10000 << 12 = 0x1000_0000 */
#define OFF_TAG_ID     0
#define OFF_CRC_STATUS 4
#define OFF_PKT_STATUS 8
#define OFF_RESULT_TAG 12
#define OFF_RESULT_ST  16
#define OFF_IRQ_ACK    20

#define RESULT_ACCEPT  1
#define RESULT_REJECT  2

    .section .text
    .globl _start

_start:
    j       main                     /* pula o vetor de interrupcao */

    /* PROGADDR_IRQ = 0x10: entrada de interrupcao do PicoRV32 */
    .balign 16
irq_vec:
    j       irq_handler

main:
    lui     s0, RF_BASE_HI           /* s0 = base dos registradores de RF (U) */
    picorv32_maskirq_insn(zero, zero) /* habilita todas as 32 linhas de IRQ */

poll:
    lw      t0, OFF_PKT_STATUS(s0)   /* ha pacote novo? (I) */
    beqz    t0, poll                 /* (B) */

    lw      t1, OFF_TAG_ID(s0)       /* le o identificador do piloto */
    lw      t2, OFF_CRC_STATUS(s0)   /* le o resultado da checagem de CRC */

    add     t4, t1, t2               /* formato R para cobertura; valor sem uso */

    sw      t1, OFF_RESULT_TAG(s0)   /* ecoa a tag processada (S) */

    li      t3, RESULT_ACCEPT
    beqz    t2, publish              /* CRC_VALID == 0 -> aceita */
    li      t3, RESULT_REJECT
publish:
    sw      t3, OFF_RESULT_ST(s0)    /* veredito: conclui o pacote corrente */

    j       poll                     /* (J) */

/*
 * Handler de interrupcao. Na entrada, o hardware do PicoRV32 poe o endereco
 * de retorno em q0 e o bitmask das IRQs a atender em q1, e o sinal eoi[]
 * correspondente sobe; ele desce quando retirq devolve o controle. O
 * handler preserva t0/t1 em q2/q3, publica o bitmask atendido em IRQ_ACK
 * (evidencia observavel para o scoreboard) e retorna.
 */
irq_handler:
    picorv32_setq_insn(q2, t0)       /* salva t0 */
    picorv32_setq_insn(q3, t1)       /* salva t1 */

    picorv32_getq_insn(t0, q1)       /* bitmask das IRQs desta invocacao */
    lui     t1, RF_BASE_HI
    sw      t0, OFF_IRQ_ACK(t1)      /* publica o reconhecimento */

    picorv32_getq_insn(t0, q2)       /* restaura t0 */
    picorv32_getq_insn(t1, q3)       /* restaura t1 */
    picorv32_retirq_insn()           /* retorna; eoi desce (alvo do OBJ-07) */
