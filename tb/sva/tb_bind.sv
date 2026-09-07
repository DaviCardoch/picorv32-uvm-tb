// Anexa os checkers SVA ao DUT via bind: as assertivas passam a existir
// dentro de toda instancia do picorv32 sem tocar no RTL original.
bind picorv32 irq_eoi_checker #(
    .PROGADDR_IRQ(PROGADDR_IRQ)
) u_irq_eoi_chk (
    .clk      (clk),
    .resetn   (resetn),
    .mem_valid(mem_valid),
    .mem_ready(mem_ready),
    .mem_instr(mem_instr),
    .mem_addr (mem_addr),
    .mem_rdata(mem_rdata),
    .eoi      (eoi)
);
