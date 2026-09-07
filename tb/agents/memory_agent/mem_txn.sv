// Transacao observada pelo monitor na interface nativa de memoria: um
// handshake completo (mem_valid && mem_ready). E o que alimenta o
// scoreboard e o monitor de cobertura funcional.
class mem_txn extends uvm_sequence_item;

    bit [31:0] addr;
    bit [31:0] wdata;
    bit [31:0] rdata;
    bit [ 3:0] wstrb;
    bit        instr;

    `uvm_object_utils_begin(mem_txn)
        `uvm_field_int(addr,  UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_ALL_ON)
        `uvm_field_int(wstrb, UVM_ALL_ON)
        `uvm_field_int(instr, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "mem_txn");
        super.new(name);
    endfunction

    function bit is_write();
        return wstrb != 4'b0000;
    endfunction

    function string convert2string();
        if (is_write())
            return $sformatf("WR addr=0x%08x wdata=0x%08x wstrb=%04b", addr, wdata, wstrb);
        else
            return $sformatf("%s addr=0x%08x rdata=0x%08x", instr ? "IF" : "RD", addr, rdata);
    endfunction

endclass : mem_txn
