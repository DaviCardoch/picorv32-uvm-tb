// Scoreboard compartilhado (Secao 3.3 da monografia): checagem passiva,
// construida somente a partir do trafego observado pelo monitor no
// barramento, sem atalhos pelo driver.
//
// Modelo de referencia do firmware do transponder:
//   - a cada pacote, o nucleo le TAG_ID e CRC_STATUS;
//   - deve ecoar a tag em RESULT_TAG;
//   - deve escrever ACCEPT em RESULT_STATUS se o CRC era valido e REJECT
//     caso contrario.
// Qualquer divergencia indica que o nucleo nao executou o software
// corretamente (ou que o protocolo de barramento corrompeu dados).

`uvm_analysis_imp_decl(_mem)

class tb_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(tb_scoreboard)

    uvm_analysis_imp_mem #(mem_txn, tb_scoreboard) mem_imp;

    // estado do pacote corrente, montado a partir das leituras observadas
    protected bit [31:0] cur_tag;
    protected bit [31:0] cur_crc;
    protected bit        have_tag;
    protected bit        have_crc;

    int unsigned n_pkts_ok;
    int unsigned n_mismatch;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mem_imp = new("mem_imp", this);
    endfunction

    function void write_mem(mem_txn t);
        // leituras dos registradores emulados de RF
        if (!t.is_write() && !t.instr) begin
            if (t.addr == ADDR_TAG_ID) begin
                cur_tag  = t.rdata;
                have_tag = 1;
            end
            else if (t.addr == ADDR_CRC_STATUS) begin
                cur_crc  = t.rdata;
                have_crc = 1;
            end
        end
        // escritas de resultado pelo firmware
        else if (t.is_write()) begin
            if (t.addr == ADDR_RESULT_TAG) begin
                if (!have_tag) begin
                    `uvm_error("SB", "RESULT_TAG escrito sem leitura previa de TAG_ID")
                    n_mismatch++;
                end
                else if (t.wdata !== cur_tag) begin
                    `uvm_error("SB", $sformatf(
                        "RESULT_TAG divergente: esperado 0x%08x, observado 0x%08x",
                        cur_tag, t.wdata))
                    n_mismatch++;
                end
            end
            else if (t.addr == ADDR_RESULT_STATUS) begin
                bit [31:0] esperado;
                if (!have_crc) begin
                    `uvm_error("SB", "RESULT_STATUS escrito sem leitura previa de CRC_STATUS")
                    n_mismatch++;
                end
                else begin
                    esperado = (cur_crc == CRC_VALID) ? RESULT_ACCEPT : RESULT_REJECT;
                    if (t.wdata !== esperado) begin
                        `uvm_error("SB", $sformatf(
                            "veredito divergente p/ tag 0x%08x (crc=%0d): esperado %0d, observado %0d",
                            cur_tag, cur_crc, esperado, t.wdata))
                        n_mismatch++;
                    end
                    else begin
                        n_pkts_ok++;
                        `uvm_info("SB", $sformatf(
                            "pacote OK: tag=0x%08x crc=%0d veredito=%0d (total ok: %0d)",
                            cur_tag, cur_crc, t.wdata, n_pkts_ok), UVM_MEDIUM)
                    end
                end
                have_tag = 0;
                have_crc = 0;
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SB", $sformatf(
            "resumo: %0d pacotes verificados OK, %0d divergencias",
            n_pkts_ok, n_mismatch), UVM_LOW)
    endfunction

endclass : tb_scoreboard
