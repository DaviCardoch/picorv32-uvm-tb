// Teste dirigido da Fase D: tres interrupcoes em linhas representativas
// (3, 0 e 31), com o firmware em polling. Valida o ciclo completo:
// pulso do IRQ Agent -> handler no PicoRV32 -> escrita de IRQ_ACK
// (checada pelo scoreboard) -> retirq -> queda de EOI (checada pela
// assertiva SVA do OBJ-07).
class irq_smoke_test extends base_test;

    `uvm_component_utils(irq_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        irq_smoke_seq seq;
        phase.raise_objection(this);

        seq = irq_smoke_seq::type_id::create("seq");
        seq.start(m_env.m_irq_agent.m_sequencer);

        repeat (50) @(posedge m_env.m_mem_agent.m_monitor.vif.clk);

        phase.drop_objection(this);
    endtask

endclass : irq_smoke_test
