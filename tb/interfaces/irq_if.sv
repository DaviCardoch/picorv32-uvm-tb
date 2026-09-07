// Interface de interrupcao do PicoRV32: 32 linhas de IRQ dirigidas pelo
// IRQ Agent e a sinalizacao de fim de atendimento (EOI) observada de volta.
interface irq_if (input logic clk, input logic resetn);

    logic [31:0] irq;
    logic [31:0] eoi;

endinterface : irq_if
