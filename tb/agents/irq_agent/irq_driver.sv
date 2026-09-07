// Driver do IRQ Agent: pulsa a linha de IRQ solicitada por um ciclo
// (as IRQs do PicoRV32 sao "latched" por padrao, entao um pulso basta) e
// serializa os itens esperando o ciclo completo de atendimento: eoi[linha]
// sobe quando o handler entra e desce no retirq. So entao o item e
// concluido, destravando a sequence. Se o nucleo nunca atender, o timeout
// global do teste (e a assertiva de EOI) denunciam.
class irq_driver extends uvm_driver #(irq_item);

    `uvm_component_utils(irq_driver)

    virtual irq_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual irq_if)::get(this, "", "irq_vif", vif))
            `uvm_fatal("NOVIF", "irq_if nao encontrada no config_db")
    endfunction

    task run_phase(uvm_phase phase);
        vif.irq <= '0;
        forever begin
            seq_item_port.get_next_item(req);
            `uvm_info("IRQ", req.convert2string(), UVM_MEDIUM)

            repeat (req.pre_delay) @(posedge vif.clk);

            vif.irq[req.line] <= 1'b1;
            @(posedge vif.clk);
            vif.irq[req.line] <= 1'b0;

            // espera o atendimento completo (entrada e retorno do handler)
            @(posedge vif.clk iff vif.eoi[req.line]);
            @(posedge vif.clk iff !vif.eoi[req.line]);

            seq_item_port.item_done();
        end
    endtask

endclass : irq_driver
