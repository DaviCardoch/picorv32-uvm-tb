// Driver reativo do Memory Agent. Diferente do padrao classico (driver
// inicia transacoes), aqui o DUT e o mestre do barramento: o driver
// responde aos acessos do nucleo, com tres politicas conforme o mapa de
// enderecos (PLAN.md secao 1.1):
//
//   1. Memoria de instrucao: serve o firmware real pre-carregado, nunca
//      randomizada (senao o nucleo executa opcodes invalidos e trava).
//   2. RAM de dados: memoria associativa coerente (pilha/variaveis).
//   3. Registradores emulados de RF: e por onde o estimulo entra. Quando o
//      firmware le PKT_STATUS e ha um rf_pkt_item pendente da sequence, o
//      driver anuncia pacote disponivel e serve TAG_ID/CRC_STATUS daquele
//      item; a escrita de RESULT_STATUS pelo firmware conclui o item
//      (item_done), destravando o finish_item da sequence.
//
// Cada resposta tem 1 ciclo de espera antes de mem_ready, batendo com o
// handshake da Figura 3.2 da monografia.
class mem_driver extends uvm_driver #(rf_pkt_item);

    `uvm_component_utils(mem_driver)

    virtual mem_if vif;

    // memoria de instrucao (firmware) e RAM de dados
    logic [31:0] instr_mem [0 : INSTR_MEM_SIZE/4 - 1];
    logic [31:0] data_mem  [bit [31:0]];   // associativa (esparsa)

    // pacote de RF corrente vindo da sequence
    protected rf_pkt_item cur_pkt;
    protected bit         pkt_active;
    protected event       pkt_done_ev;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        string fw_hex;
        super.build_phase(phase);
        if (!uvm_config_db#(virtual mem_if)::get(this, "", "mem_vif", vif))
            `uvm_fatal("NOVIF", "mem_if nao encontrada no config_db")
        if (!$value$plusargs("firmware=%s", fw_hex))
            fw_hex = "../fw/uvm_fw.hex";
        $readmemh(fw_hex, instr_mem);
        `uvm_info("FW", $sformatf("firmware carregado de %s", fw_hex), UVM_LOW)
    endfunction

    task run_phase(uvm_phase phase);
        fork
            responder_loop();
        join_none
        // laco de consumo de itens da sequence: um pacote por vez, o
        // item_done so ocorre quando o firmware terminou de processa-lo
        forever begin
            seq_item_port.get_next_item(cur_pkt);
            `uvm_info("PKT", $sformatf("pacote pendente: %s", cur_pkt.convert2string()), UVM_MEDIUM)
            pkt_active = 1;
            @(pkt_done_ev);
            pkt_active = 0;
            seq_item_port.item_done();
        end
    endtask

    // Responde os acessos do nucleo (escravo do barramento).
    protected task responder_loop();
        vif.mem_ready <= 1'b0;
        vif.mem_rdata <= '0;
        forever begin
            @(posedge vif.clk);
            vif.mem_ready <= 1'b0;
            if (vif.resetn && vif.mem_valid && !vif.mem_ready)
                respond();
        end
    endtask

    protected task respond();
        bit [31:0] addr = vif.mem_addr;

        // 1. memoria de instrucao (leituras; busca de instrucao ou dado)
        if (addr >= INSTR_MEM_BASE && addr < INSTR_MEM_BASE + INSTR_MEM_SIZE) begin
            if (vif.mem_wstrb != 4'b0000) begin
                `uvm_error("MAPA", $sformatf("escrita em memoria de instrucao: 0x%08x", addr))
            end
            vif.mem_rdata <= instr_mem[(addr - INSTR_MEM_BASE) >> 2];
            vif.mem_ready <= 1'b1;
        end
        // 2. RAM de dados
        else if (addr >= DATA_MEM_BASE && addr < DATA_MEM_BASE + DATA_MEM_SIZE) begin
            bit [31:0] widx = (addr - DATA_MEM_BASE) >> 2;
            if (vif.mem_wstrb != 4'b0000) begin
                logic [31:0] cur = data_mem.exists(widx) ? data_mem[widx] : '0;
                if (vif.mem_wstrb[0]) cur[ 7: 0] = vif.mem_wdata[ 7: 0];
                if (vif.mem_wstrb[1]) cur[15: 8] = vif.mem_wdata[15: 8];
                if (vif.mem_wstrb[2]) cur[23:16] = vif.mem_wdata[23:16];
                if (vif.mem_wstrb[3]) cur[31:24] = vif.mem_wdata[31:24];
                data_mem[widx] = cur;
            end else begin
                vif.mem_rdata <= data_mem.exists(widx) ? data_mem[widx] : '0;
            end
            vif.mem_ready <= 1'b1;
        end
        // 3. registradores emulados de RF
        else if (addr == ADDR_PKT_STATUS && vif.mem_wstrb == 4'b0000) begin
            vif.mem_rdata <= pkt_active ? 32'd1 : 32'd0;
            vif.mem_ready <= 1'b1;
        end
        else if (addr == ADDR_TAG_ID && vif.mem_wstrb == 4'b0000) begin
            vif.mem_rdata <= pkt_active ? cur_pkt.tag_id : '0;
            vif.mem_ready <= 1'b1;
        end
        else if (addr == ADDR_CRC_STATUS && vif.mem_wstrb == 4'b0000) begin
            vif.mem_rdata <= pkt_active ? cur_pkt.crc_status : '0;
            vif.mem_ready <= 1'b1;
        end
        else if (addr == ADDR_RESULT_TAG && vif.mem_wstrb != 4'b0000) begin
            vif.mem_ready <= 1'b1;
        end
        else if (addr == ADDR_RESULT_STATUS && vif.mem_wstrb != 4'b0000) begin
            vif.mem_ready <= 1'b1;
            if (pkt_active)
                ->pkt_done_ev;   // firmware concluiu o pacote corrente
        end
        else if (addr == ADDR_IRQ_ACK && vif.mem_wstrb != 4'b0000) begin
            vif.mem_ready <= 1'b1;   // reconhecimento de IRQ pelo handler
        end
        // 4. fora do mapa conhecido
        else begin
            `uvm_error("MAPA", $sformatf(
                "acesso fora do mapa: addr=0x%08x wstrb=%04b instr=%0d",
                addr, vif.mem_wstrb, vif.mem_instr))
            vif.mem_rdata <= '0;
            vif.mem_ready <= 1'b1;
        end
    endtask

endclass : mem_driver
