// IRQ Agent: agrega sequencer + driver + monitor da interface de
// interrupcao, segundo agent da arquitetura proposta na Secao 3.3.
class irq_agent extends uvm_agent;

    `uvm_component_utils(irq_agent)

    irq_sequencer m_sequencer;
    irq_driver    m_driver;
    irq_monitor   m_monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_monitor = irq_monitor::type_id::create("m_monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            m_sequencer = irq_sequencer::type_id::create("m_sequencer", this);
            m_driver    = irq_driver::type_id::create("m_driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    endfunction

endclass : irq_agent
