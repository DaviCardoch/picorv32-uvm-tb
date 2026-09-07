// Teste base: cria o env e define utilidades comuns (timeout, drain).
class base_test extends uvm_test;

    `uvm_component_utils(base_test)

    tb_env m_env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env = tb_env::type_id::create("m_env", this);
        uvm_top.set_timeout(1ms, 0);  // rede de seguranca contra travamento
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

endclass : base_test
