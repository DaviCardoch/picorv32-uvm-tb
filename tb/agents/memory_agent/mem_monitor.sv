// Monitor do Memory Agent: observa passivamente o barramento mem_* e
// publica uma mem_txn a cada handshake completo (mem_valid && mem_ready),
// alimentando scoreboard e cobertura via analysis port.
class mem_monitor extends uvm_monitor;

    `uvm_component_utils(mem_monitor)

    virtual mem_if vif;
    uvm_analysis_port #(mem_txn) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual mem_if)::get(this, "", "mem_vif", vif))
            `uvm_fatal("NOVIF", "mem_if nao encontrada no config_db")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            if (vif.resetn && vif.mem_valid && vif.mem_ready) begin
                mem_txn t = mem_txn::type_id::create("t");
                t.addr  = vif.mem_addr;
                t.wdata = vif.mem_wdata;
                t.rdata = vif.mem_rdata;
                t.wstrb = vif.mem_wstrb;
                t.instr = vif.mem_instr;
                if (t.addr >= RF_REGS_BASE && t.addr < RF_REGS_BASE + 32'h100)
                    `uvm_info("MON", t.convert2string(), UVM_MEDIUM)
                else
                    `uvm_info("MON", t.convert2string(), UVM_HIGH)
                ap.write(t);
            end
        end
    endtask

endclass : mem_monitor
