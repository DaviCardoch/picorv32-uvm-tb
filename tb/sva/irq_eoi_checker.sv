// Checker SVA do ciclo de vida de EOI (OBJ-07), anexado ao DUT via bind
// (tb/sva/tb_bind.sv), conforme a tecnica descrita no Capitulo 2 da
// monografia. Observa apenas sinais de porta do picorv32.
//
// Semantica do PicoRV32 (README, "Custom Instructions for IRQ Handling"):
// eoi[] sobe quando o handler de interrupcao e iniciado e desce quando ele
// retorna via retirq. Nucleo multiciclo sem especulacao: toda instrucao
// buscada e executada, entao a busca de retirq e um bom ponto de
// ancoragem temporal.
module irq_eoi_checker #(
    parameter bit [31:0] PROGADDR_IRQ = 32'h0000_0010,
    parameter int unsigned MAX_CICLOS_EOI = 4
) (
    input logic        clk,
    input logic        resetn,
    input logic        mem_valid,
    input logic        mem_ready,
    input logic        mem_instr,
    input logic [31:0] mem_addr,
    input logic [31:0] mem_rdata,
    input logic [31:0] eoi
);

    // codificacao de retirq: f7=0000010, rs=0, f3=000, rd=0, opcode=custom0
    localparam bit [31:0] RETIRQ_INSN = 32'h0400_000B;

    wire fetch_ok     = mem_valid && mem_ready && mem_instr;
    wire retirq_fetch = fetch_ok && (mem_rdata == RETIRQ_INSN);
    wire vec_fetch    = fetch_ok && (mem_addr == PROGADDR_IRQ);

    // OBJ-07: apos a execucao de retirq, o EOI deve encerrar (todas as
    // linhas em zero) em ate MAX_CICLOS_EOI ciclos
    property p_eoi_encerra;
        @(posedge clk) disable iff (!resetn)
        retirq_fetch |-> ##[1:MAX_CICLOS_EOI] (eoi == 32'h0);
    endproperty
    a_eoi_encerra: assert property (p_eoi_encerra)
        else uvm_pkg::uvm_report_error("SVA",
            "OBJ-07: eoi nao encerrou no prazo apos retirq");

    // complementar: a entrada no handler (busca em PROGADDR_IRQ) deve vir
    // acompanhada da subida de EOI
    property p_eoi_sobe;
        @(posedge clk) disable iff (!resetn)
        vec_fetch |-> ##[0:1] (eoi != 32'h0);
    endproperty
    a_eoi_sobe: assert property (p_eoi_sobe)
        else uvm_pkg::uvm_report_error("SVA",
            "entrada no handler sem sinalizacao de EOI");

endmodule : irq_eoi_checker
