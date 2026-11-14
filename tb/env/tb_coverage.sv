// Monitor de cobertura funcional compartilhado (Secao 3.3 da monografia).
// Amostrado exclusivamente a partir das transacoes observadas pelo monitor,
// cobrindo nesta fase:
//   OBJ-01: faixa completa de Tag ID, incluindo extremos
//   OBJ-02: validade de CRC (valido, invalido 1 bit, invalido multiplos)
//   OBJ-03: formatos de instrucao RV32I executados pelo nucleo
//   OBJ-02: cobertura cruzada validade de CRC x faixa de Tag ID
// A parte de IRQ (OBJ-04 e o cruzamento IRQ x instrucao) entra nas Fases
// D/E junto com o IRQ Agent.
class tb_coverage extends uvm_component;

    `uvm_component_utils(tb_coverage)

    uvm_analysis_imp_mem #(mem_txn, tb_coverage) mem_imp;
    uvm_analysis_imp_irq #(irq_txn, tb_coverage) irq_imp;

    // valores do pacote corrente (amostrados na conclusao do pacote)
    protected bit [31:0] pkt_tag;
    protected bit [31:0] pkt_crc;

    // formato da instrucao buscada corrente
    protected rv_fmt_e fmt;

    // linha da IRQ pulsada corrente
    protected int unsigned irq_linha;

    // 1 entre a solicitacao de IRQ e a queda de EOI: janela em que ha
    // concorrencia entre execucao/acesso a memoria e interrupcao (OBJ-05)
    protected bit irq_ativa;

    // OBJ-01 / OBJ-02: amostrado a cada pacote concluido
    // (escrita de RESULT_STATUS), quando tag e crc sao conhecidos
    covergroup cg_pkt;
        option.per_instance = 1;
        cp_tag: coverpoint pkt_tag {
            bins zero  = {32'h0000_0000};
            bins baixa = {[32'h0000_0001 : 32'h0000_FFFF]};
            bins media = {[32'h0001_0000 : 32'hFFFE_FFFF]};
            bins alta  = {[32'hFFFF_0000 : 32'hFFFF_FFFE]};
            bins max   = {32'hFFFF_FFFF};
        }
        cp_crc: coverpoint pkt_crc {
            bins valido    = {CRC_VALID};
            bins inv_1bit  = {CRC_INVALID_1BIT};
            bins inv_multi = {CRC_INVALID_MULTIBIT};
        }
        x_tag_crc: cross cp_tag, cp_crc;
    endgroup

    // OBJ-03 + OBJ-05: amostrado a cada busca de instrucao; o cruzamento
    // formato x IRQ ativa cobre os cenarios de concorrencia entre execucao
    // e interrupcao (so fecha quando IRQs chegam enquanto pacotes estao
    // sendo processados, o que motiva a sequencia virtual da Fase E)
    covergroup cg_instr;
        option.per_instance = 1;
        cp_fmt: coverpoint fmt {
            bins R      = {FMT_R};
            bins I      = {FMT_I};
            bins S      = {FMT_S};
            bins B      = {FMT_B};
            bins U      = {FMT_U};
            bins J      = {FMT_J};
            bins CUSTOM = {FMT_CUSTOM};
        }
        cp_irq_ativa: coverpoint irq_ativa {
            bins ocioso = {0};
            bins ativa  = {1};
        }
        x_fmt_irq: cross cp_fmt, cp_irq_ativa;
    endgroup

    // OBJ-04: as 32 linhas de IRQ (as linhas 0..2 sao tambem as fontes
    // internas do PicoRV32: temporizador, instrucao ilegal, erro de barramento)
    covergroup cg_irq;
        option.per_instance = 1;
        cp_linha: coverpoint irq_linha {
            bins linha[] = {[0:31]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mem_imp  = new("mem_imp", this);
        irq_imp  = new("irq_imp", this);
        cg_pkt   = new();
        cg_instr = new();
        cg_irq   = new();
    endfunction

    function void write_irq(irq_txn t);
        if (t.kind == IRQ_PULSE) begin
            irq_linha = t.line;
            irq_ativa = 1;
            cg_irq.sample();
        end
        else if (t.kind == EOI_FALL)
            irq_ativa = 0;
    endfunction

    function void write_mem(mem_txn t);
        // busca de instrucao: classifica o formato e amostra
        if (t.instr && !t.is_write()) begin
            fmt = rv32_fmt(t.rdata);
            cg_instr.sample();
        end
        // montagem do pacote corrente
        else if (!t.is_write() && t.addr == ADDR_TAG_ID)
            pkt_tag = t.rdata;
        else if (!t.is_write() && t.addr == ADDR_CRC_STATUS)
            pkt_crc = t.rdata;
        // pacote concluido: amostra tag, crc e o cruzamento
        else if (t.is_write() && t.addr == ADDR_RESULT_STATUS)
            cg_pkt.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf(
            "cobertura funcional: cg_pkt=%.1f%% (tag=%.1f%% crc=%.1f%% cruz=%.1f%%) cg_instr=%.1f%% (fmt x irq=%.1f%%) cg_irq=%.1f%%",
            cg_pkt.get_inst_coverage(),
            cg_pkt.cp_tag.get_inst_coverage(),
            cg_pkt.cp_crc.get_inst_coverage(),
            cg_pkt.x_tag_crc.get_inst_coverage(),
            cg_instr.get_inst_coverage(),
            cg_instr.x_fmt_irq.get_inst_coverage(),
            cg_irq.get_inst_coverage()), UVM_LOW)
    endfunction

endclass : tb_coverage
