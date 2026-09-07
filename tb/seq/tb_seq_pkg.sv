// Package das sequences do testbench.
package tb_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import mem_agent_pkg::*;
    import irq_agent_pkg::*;

    `include "mem_seq_lib.sv"
    `include "irq_seq_lib.sv"

endpackage : tb_seq_pkg
