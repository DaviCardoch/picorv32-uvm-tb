/*
 * Fase A -- programa minimo de bring-up (RV32I puro, sem chamadas de
 * biblioteca). Soma 1+2+3+4+5 em loop, guarda o resultado na RAM de dados,
 * le de volta, e encerra a simulacao de proposito via `ecall` (o PicoRV32
 * trata ecall/ebreak como instrucao invalida quando CATCH_ILLINSN=1, o que
 * levanta `trap` -- e o testbench usa esse sinal para dar $finish).
 *
 * Ver PLAN.md secao 1.1 para o mapa de enderecos (INSTR_MEM_BASE=0x0,
 * DATA_MEM_BASE=0x00010000).
 */

    .section .text
    .globl _start

_start:
    li      t0, 5           # t0 = contador do loop, comeca em 5 e decresce
    li      t1, 0           # t1 = acumulador da soma
    lui     t2, 0x10         # t2 = 0x00010000 (DATA_MEM_BASE)

sum_loop:
    add     t1, t1, t0       # sum += contador
    addi    t0, t0, -1       # contador--
    bnez    t0, sum_loop     # repete enquanto contador != 0

    sw      t1, 0(t2)        # guarda a soma (esperado: 15) na RAM de dados
    lw      t3, 0(t2)        # le de volta (exercita o caminho de leitura)

    ecall                     # trap intencional -> fim da simulacao da Fase A

hang:
    j       hang              # rede de seguranca; nao deveria ser alcancado
