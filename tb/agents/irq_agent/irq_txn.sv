// Transacao observada pelo monitor de IRQ: eventos nas linhas irq[] e na
// sinalizacao de fim de atendimento eoi[].
typedef enum { IRQ_PULSE, EOI_RISE, EOI_FALL } irq_evt_e;

class irq_txn extends uvm_sequence_item;

    irq_evt_e    kind;
    int unsigned line;

    `uvm_object_utils_begin(irq_txn)
        `uvm_field_enum(irq_evt_e, kind, UVM_ALL_ON)
        `uvm_field_int(line, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "irq_txn");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("%s linha=%0d", kind.name(), line);
    endfunction

endclass : irq_txn
