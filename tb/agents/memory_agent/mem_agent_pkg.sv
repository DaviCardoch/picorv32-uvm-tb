// Package do Memory Agent.
package mem_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "mem_map.svh"

    `include "rf_pkt_item.sv"
    `include "mem_txn.sv"
    `include "mem_sequencer.sv"
    `include "mem_driver.sv"
    `include "mem_monitor.sv"
    `include "mem_agent.sv"

endpackage : mem_agent_pkg
