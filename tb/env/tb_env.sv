// Ambiente (env) do testbench: instancia os agents e, a partir da Fase C,
// o scoreboard e o monitor de cobertura funcional compartilhados.
class tb_env extends uvm_env;

    `uvm_component_utils(tb_env)

    mem_agent m_mem_agent;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_mem_agent = mem_agent::type_id::create("m_mem_agent", this);
    endfunction

endclass : tb_env
