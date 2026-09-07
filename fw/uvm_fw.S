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

#define RF_BASE_HI     0x10000      /* lui: 0x10000 << 12 = 0x1000_0000 */
#define OFF_TAG_ID     0
#define OFF_CRC_STATUS 4
#define OFF_PKT_STATUS 8
#define OFF_RESULT_TAG 12
#define OFF_RESULT_ST  16

#define RESULT_ACCEPT  1
#define RESULT_REJECT  2

    .section .text
    .globl _start

_start:
    j       main                     /* pula o vetor de interrupcao */

    /* PROGADDR_IRQ = 0x10: handler de interrupcao entra na Fase D */
    .balign 16
irq_vec:
    j       irq_vec                  /* nao deve ser alcancado antes da Fase D */

main:
    lui     s0, RF_BASE_HI           /* s0 = base dos registradores de RF (U) */

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
