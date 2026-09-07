// Monitor do IRQ Agent: observa passivamente as linhas irq[] e eoi[] e
// publica um irq_txn a cada borda relevante (pulso de solicitacao, subida
// e descida de EOI), alimentando scoreboard e cobertura.
class irq_monitor extends uvm_monitor;

    `uvm_component_utils(irq_monitor)

    virtual irq_if vif;
    uvm_analysis_port #(irq_txn) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual irq_if)::get(this, "", "irq_vif", vif))
            `uvm_fatal("NOVIF", "irq_if nao encontrada no config_db")
    endfunction

    task run_phase(uvm_phase phase);
        logic [31:0] prev_irq = '0;
        logic [31:0] prev_eoi = '0;
        forever begin
            @(posedge vif.clk);
            if (vif.resetn) begin
                for (int i = 0; i < 32; i++) begin
                    if (vif.irq[i] && !prev_irq[i]) publish(IRQ_PULSE, i);
                    if (vif.eoi[i] && !prev_eoi[i]) publish(EOI_RISE, i);
                    if (!vif.eoi[i] && prev_eoi[i]) publish(EOI_FALL, i);
                end
            end
            prev_irq = vif.irq;
            prev_eoi = vif.eoi;
        end
    endtask

    protected function void publish(irq_evt_e kind, int unsigned line);
        irq_txn t = irq_txn::type_id::create("t");
        t.kind = kind;
        t.line = line;
        `uvm_info("MON", t.convert2string(), UVM_MEDIUM)
        ap.write(t);
    endfunction

endclass : irq_monitor
