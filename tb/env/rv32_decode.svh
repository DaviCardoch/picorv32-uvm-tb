// Decodificacao minima de formato de instrucao RV32I a partir do opcode
// (bits [6:0] da palavra buscada), para o coverpoint de tipos de instrucao
// (OBJ-03). O opcode custom0 (0001011) e usado pelas instrucoes de IRQ
// especificas do PicoRV32 (getq/setq/maskirq/waitirq/retirq/timer).
typedef enum {
    FMT_R,
    FMT_I,
    FMT_S,
    FMT_B,
    FMT_U,
    FMT_J,
    FMT_CUSTOM,   // instrucoes customizadas de IRQ do PicoRV32
    FMT_OUTRO
} rv_fmt_e;

function automatic rv_fmt_e rv32_fmt(bit [31:0] insn);
    case (insn[6:0])
        7'b0110011: return FMT_R;                    // OP (add, sub, ...)
        7'b0010011,                                   // OP-IMM (addi, ...)
        7'b0000011,                                   // LOAD (lw, ...)
        7'b1100111,                                   // JALR
        7'b1110011,                                   // SYSTEM (ecall, ebreak)
        7'b0001111: return FMT_I;                    // FENCE
        7'b0100011: return FMT_S;                    // STORE (sw, ...)
        7'b1100011: return FMT_B;                    // BRANCH (beq, ...)
        7'b0110111,                                   // LUI
        7'b0010111: return FMT_U;                    // AUIPC
        7'b1101111: return FMT_J;                    // JAL
        7'b0001011: return FMT_CUSTOM;               // custom0 (IRQ PicoRV32)
        default:    return FMT_OUTRO;
    endcase
endfunction
