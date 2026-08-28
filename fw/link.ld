/* Linker script minimo da Fase A: coloca .text no inicio da memoria de
 * instrucao (INSTR_MEM_BASE = 0x00000000 em tb/interfaces/mem_map.svh),
 * que tambem e o PROGADDR_RESET padrao do PicoRV32. Sem .data/.bss porque
 * o firmware da Fase A nao usa variaveis inicializadas nem a pilha. */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    INSTR_MEM (rx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        *(.text*)
    } > INSTR_MEM

    /DISCARD/ : { *(.riscv.attributes) *(.comment) *(.eh_frame) }
}
