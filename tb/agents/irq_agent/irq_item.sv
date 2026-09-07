// Item de sequencia do IRQ Agent: uma solicitacao de interrupcao externa
// emulada (qual das 32 linhas pulsar e apos quantos ciclos), conforme a
// Secao 3.3 da monografia.
class irq_item extends uvm_sequence_item;

    rand int unsigned line;        // linha de IRQ (0..31)
    rand int unsigned pre_delay;   // ciclos de espera antes do pulso

    constraint c_line  { line inside {[0:31]}; }
    constraint c_delay { pre_delay inside {[1:50]}; }

    `uvm_object_utils_begin(irq_item)
        `uvm_field_int(line,      UVM_ALL_ON)
        `uvm_field_int(pre_delay, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "irq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("irq linha=%0d apos %0d ciclos", line, pre_delay);
    endfunction

endclass : irq_item
