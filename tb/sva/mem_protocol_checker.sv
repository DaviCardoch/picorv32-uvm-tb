// Checker SVA do protocolo nativo de memoria (OBJ-06), anexado ao DUT via
// bind. Monitora continuamente as tres propriedades da Tabela de objetivos
// da monografia, sobre o handshake descrito na Secao 3.2:
//
//   1. mem_valid permanece alto ate mem_ready aceitar a transferencia;
//   2. os sinais de endereco/dado/controle permanecem estaveis enquanto a
//      transferencia esta pendente;
//   3. nunca ha escrita (mem_wstrb ativo) em uma busca de instrucao
//      (mem_instr alto).
module mem_protocol_checker (
    input logic        clk,
    input logic        resetn,
    input logic        mem_valid,
    input logic        mem_ready,
    input logic        mem_instr,
    input logic [31:0] mem_addr,
    input logic [31:0] mem_wdata,
    input logic [ 3:0] mem_wstrb
);

    // transferencia pendente: solicitada e ainda nao aceita
    wire pendente = mem_valid && !mem_ready;

    // 1. estabilidade de mem_valid ate mem_ready
    property p_valid_estavel;
        @(posedge clk) disable iff (!resetn)
        pendente |=> mem_valid;
    endproperty
    a_valid_estavel: assert property (p_valid_estavel)
        else uvm_pkg::uvm_report_error("SVA",
            "OBJ-06: mem_valid caiu antes de mem_ready");

    // 2. estabilidade de endereco e controle durante o handshake
    property p_addr_estavel;
        @(posedge clk) disable iff (!resetn)
        pendente |=> $stable(mem_addr);
    endproperty
    a_addr_estavel: assert property (p_addr_estavel)
        else uvm_pkg::uvm_report_error("SVA",
            "OBJ-06: mem_addr mudou durante o handshake");

    property p_ctrl_estavel;
        @(posedge clk) disable iff (!resetn)
        pendente |=> ($stable(mem_wstrb) && $stable(mem_instr) && $stable(mem_wdata));
    endproperty
    a_ctrl_estavel: assert property (p_ctrl_estavel)
        else uvm_pkg::uvm_report_error("SVA",
            "OBJ-06: wstrb/instr/wdata mudaram durante o handshake");

    // 3. escrita e busca de instrucao sao mutuamente exclusivas
    property p_sem_escrita_em_fetch;
        @(posedge clk) disable iff (!resetn)
        mem_valid |-> !(mem_instr && mem_wstrb != 4'b0000);
    endproperty
    a_sem_escrita_em_fetch: assert property (p_sem_escrita_em_fetch)
        else uvm_pkg::uvm_report_error("SVA",
            "OBJ-06: mem_wstrb ativo com mem_instr alto");

endmodule : mem_protocol_checker
