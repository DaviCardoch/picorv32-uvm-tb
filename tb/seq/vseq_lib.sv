// Sequencias virtuais: coordenam os dois agents pelo sequencer virtual.
// (Incluidas em tb_test_pkg, pois dependem de tb_vseqr do tb_env_pkg.)

// Estimulo misto constrained-random: pacotes de RF e interrupcoes em
// paralelo. E o cenario que fecha o cruzamento formato x IRQ ativa
// (OBJ-05): interrupcoes chegando enquanto o firmware processa pacotes.
class mixed_rand_vseq extends uvm_sequence;

    `uvm_object_utils(mixed_rand_vseq)
    `uvm_declare_p_sequencer(tb_vseqr)

    int unsigned num_pkts = 30;
    int unsigned num_irqs = 20;

    function new(string name = "mixed_rand_vseq");
        super.new(name);
    endfunction

    virtual task body();
        rf_pkt_base_seq pkt_seq;
        irq_base_seq    irq_seq;

        pkt_seq = rf_pkt_base_seq::type_id::create("pkt_seq");
        irq_seq = irq_base_seq::type_id::create("irq_seq");
        pkt_seq.num_pkts = num_pkts;
        irq_seq.num_irqs = num_irqs;

        fork
            pkt_seq.start(p_sequencer.mem_seqr, this);
            irq_seq.start(p_sequencer.irq_seqr, this);
        join
    endtask

endclass : mixed_rand_vseq
