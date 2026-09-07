// Sequencer virtual: nao processa itens proprios, apenas guarda referencias
// aos sequencers dos dois agents para que sequencias virtuais coordenem
// estimulo de memoria e de interrupcao (mecanismo descrito na Secao 2 da
// monografia e previsto na Secao 3.3).
class tb_vseqr extends uvm_sequencer;

    `uvm_component_utils(tb_vseqr)

    mem_sequencer mem_seqr;
    irq_sequencer irq_seqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : tb_vseqr
