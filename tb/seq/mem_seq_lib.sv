// Sequences do Memory Agent.

// Base: envia num_pkts pacotes de RF. As derivadas controlam como cada
// pacote e preenchido.
class rf_pkt_base_seq extends uvm_sequence #(rf_pkt_item);

    `uvm_object_utils(rf_pkt_base_seq)

    int unsigned num_pkts = 4;

    function new(string name = "rf_pkt_base_seq");
        super.new(name);
    endfunction

    virtual task body();
        repeat (num_pkts) begin
            req = rf_pkt_item::type_id::create("req");
            start_item(req);
            if (!req.randomize())
                `uvm_error("RAND", "randomize() falhou")
            finish_item(req);
        end
    endtask

endclass : rf_pkt_base_seq

// Smoke dirigida (Fase B): quatro pacotes fixos cobrindo os extremos de
// Tag ID e os tres estados de CRC, para validar o caminho completo
// sequence -> driver -> firmware -> registradores de resultado.
class rf_smoke_seq extends rf_pkt_base_seq;

    `uvm_object_utils(rf_smoke_seq)

    function new(string name = "rf_smoke_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] tags [4] = '{32'h0000_0000, 32'hFFFF_FFFF, 32'h1234_5678, 32'hCAFE_BABE};
        bit [31:0] crcs [4] = '{CRC_VALID, CRC_VALID, CRC_INVALID_1BIT, CRC_INVALID_MULTIBIT};
        foreach (tags[i]) begin
            req = rf_pkt_item::type_id::create("req");
            start_item(req);
            req.tag_id     = tags[i];
            req.crc_status = crcs[i];
            finish_item(req);
        end
    endtask

endclass : rf_smoke_seq
