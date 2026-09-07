// Memory Agent: agrega sequencer + driver + monitor da interface nativa de
// memoria, seguindo o principio "um agent por interface" da arquitetura
// proposta na Secao 3.3 da monografia.
class mem_agent extends uvm_agent;

    `uvm_component_utils(mem_agent)

    mem_sequencer m_sequencer;
    mem_driver    m_driver;
    mem_monitor   m_monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_monitor = mem_monitor::type_id::create("m_monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            m_sequencer = mem_sequencer::type_id::create("m_sequencer", this);
            m_driver    = mem_driver::type_id::create("m_driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    endfunction

endclass : mem_agent
