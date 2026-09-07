// Sequences do IRQ Agent.

// Base: dispara num_irqs interrupcoes com linha e atraso randomizados.
class irq_base_seq extends uvm_sequence #(irq_item);

    `uvm_object_utils(irq_base_seq)

    int unsigned num_irqs = 4;

    function new(string name = "irq_base_seq");
        super.new(name);
    endfunction

    virtual task body();
        repeat (num_irqs) begin
            req = irq_item::type_id::create("req");
            start_item(req);
            if (!req.randomize())
                `uvm_error("RAND", "randomize() falhou")
            finish_item(req);
        end
    endtask

endclass : irq_base_seq

// Smoke dirigida (Fase D): tres pulsos em linhas representativas, incluindo
// os extremos (0 e 31). A linha 0 tambem e a fonte interna do temporizador,
// aqui disparada externamente.
class irq_smoke_seq extends irq_base_seq;

    `uvm_object_utils(irq_smoke_seq)

    function new(string name = "irq_smoke_seq");
        super.new(name);
    endfunction

    virtual task body();
        int unsigned linhas [3] = '{3, 0, 31};
        foreach (linhas[i]) begin
            req = irq_item::type_id::create("req");
            start_item(req);
            req.line      = linhas[i];
            req.pre_delay = 10 + 10*i;
            finish_item(req);
        end
    endtask

endclass : irq_smoke_seq
