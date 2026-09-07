// Teste dirigido da Fase B: quatro pacotes fixos (extremos de Tag ID e os
// tres estados de CRC) passando pelo caminho completo:
// sequence -> driver reativo -> firmware no PicoRV32 -> registradores de
// resultado observados pelo monitor.
class rf_smoke_test extends base_test;

    `uvm_component_utils(rf_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        rf_smoke_seq seq;
        phase.raise_objection(this);

        seq = rf_smoke_seq::type_id::create("seq");
        seq.start(m_env.m_mem_agent.m_sequencer);

        // drain: da tempo do ultimo handshake concluir e do monitor publicar
        repeat (50) @(posedge m_env.m_mem_agent.m_monitor.vif.clk);

        phase.drop_objection(this);
    endtask

endclass : rf_smoke_test
