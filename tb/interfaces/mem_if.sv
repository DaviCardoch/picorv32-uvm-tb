// Interface nativa de memoria do PicoRV32 (protocolo mem_valid/mem_ready
// descrito na Secao 3.2 da monografia). O nucleo e o mestre; o Memory Agent
// responde como escravo (driver reativo).
interface mem_if (input logic clk, input logic resetn);

    logic        mem_valid;
    logic        mem_instr;
    logic        mem_ready;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [ 3:0] mem_wstrb;
    logic [31:0] mem_rdata;

endinterface : mem_if
