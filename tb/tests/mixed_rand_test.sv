// Teste constrained-random da Fase E: pacotes de RF e interrupcoes em
// paralelo via sequencia virtual. Quantidades configuraveis por plusarg
// (+num_pkts=N +num_irqs=M) para uso em regressao.
class mixed_rand_test extends base_test;

    `uvm_component_utils(mixed_rand_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        mixed_rand_vseq vseq;
        int unsigned n;
        phase.raise_objection(this);

        vseq = mixed_rand_vseq::type_id::create("vseq");
        if ($value$plusargs("num_pkts=%d", n)) vseq.num_pkts = n;
        if ($value$plusargs("num_irqs=%d", n)) vseq.num_irqs = n;
        `uvm_info("TEST", $sformatf("estimulo misto: %0d pacotes, %0d IRQs",
                  vseq.num_pkts, vseq.num_irqs), UVM_LOW)

        vseq.start(m_env.m_vseqr);

        repeat (50) @(posedge m_env.m_mem_agent.m_monitor.vif.clk);

        phase.drop_objection(this);
    endtask

endclass : mixed_rand_test
