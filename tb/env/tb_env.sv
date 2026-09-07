// Ambiente (env) do testbench: agents + scoreboard e monitor de cobertura
// funcional compartilhados, conforme a arquitetura da Secao 3.3 da
// monografia (o IRQ Agent entra na Fase D).
class tb_env extends uvm_env;

    `uvm_component_utils(tb_env)

    mem_agent     m_mem_agent;
    tb_scoreboard m_scoreboard;
    tb_coverage   m_coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_mem_agent  = mem_agent::type_id::create("m_mem_agent", this);
        m_scoreboard = tb_scoreboard::type_id::create("m_scoreboard", this);
        m_coverage   = tb_coverage::type_id::create("m_coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_mem_agent.m_monitor.ap.connect(m_scoreboard.mem_imp);
        m_mem_agent.m_monitor.ap.connect(m_coverage.mem_imp);
    endfunction

endclass : tb_env
