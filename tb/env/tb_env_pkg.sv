// Package do ambiente do testbench.
package tb_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import mem_agent_pkg::*;
    import irq_agent_pkg::*;

    `include "rv32_decode.svh"
    `include "tb_scoreboard.sv"
    `include "tb_coverage.sv"
    `include "tb_env.sv"

endpackage : tb_env_pkg
