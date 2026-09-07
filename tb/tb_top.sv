// Topo do testbench UVM: clock/reset, interfaces, DUT (picorv32 nativo) e
// entrada no runtime UVM via run_test().
`timescale 1ns / 1ps

module tb_top;

    import uvm_pkg::*;
    import mem_agent_pkg::*;   // constantes do mapa de enderecos
    import tb_test_pkg::*;

    logic clk = 0;
    logic resetn = 0;

    always #5 clk = ~clk;   // 100 MHz

    initial begin
        resetn = 0;
        repeat (10) @(posedge clk);
        resetn = 1;
    end

    mem_if mif (clk, resetn);
    irq_if iif (clk, resetn);

    // Ate a Fase D (IRQ Agent), as linhas de interrupcao ficam em zero.
    initial iif.irq = '0;

    picorv32 #(
        .ENABLE_COUNTERS     (1),
        .ENABLE_COUNTERS64   (1),
        .ENABLE_REGS_16_31   (1),
        .ENABLE_REGS_DUALPORT(1),
        .COMPRESSED_ISA      (0),
        .ENABLE_MUL          (0),
        .ENABLE_DIV          (0),
        .ENABLE_IRQ          (1),
        .ENABLE_IRQ_QREGS    (1),
        .ENABLE_IRQ_TIMER    (1),
        .CATCH_MISALIGN      (1),
        .CATCH_ILLINSN       (1),
        .STACKADDR           (DATA_MEM_BASE + DATA_MEM_SIZE - 4),
        .PROGADDR_RESET      (INSTR_MEM_BASE),
        .PROGADDR_IRQ        (32'h0000_0010)
    ) dut (
        .clk      (clk),
        .resetn   (resetn),
        .trap     (),

        .mem_valid(mif.mem_valid),
        .mem_instr(mif.mem_instr),
        .mem_ready(mif.mem_ready),
        .mem_addr (mif.mem_addr),
        .mem_wdata(mif.mem_wdata),
        .mem_wstrb(mif.mem_wstrb),
        .mem_rdata(mif.mem_rdata),

        .mem_la_read (),
        .mem_la_write(),
        .mem_la_addr (),
        .mem_la_wdata(),
        .mem_la_wstrb(),

        .pcpi_valid(),
        .pcpi_insn (),
        .pcpi_rs1  (),
        .pcpi_rs2  (),
        .pcpi_wr   (1'b0),
        .pcpi_rd   (32'b0),
        .pcpi_wait (1'b0),
        .pcpi_ready(1'b0),

        .irq(iif.irq),
        .eoi(iif.eoi)
    );

    initial begin
        uvm_config_db#(virtual mem_if)::set(null, "*", "mem_vif", mif);
        uvm_config_db#(virtual irq_if)::set(null, "*", "irq_vif", iif);
        run_test();
    end

    // waveform opcional (+vcd)
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_top.vcd");
            $dumpvars(0, tb_top);
        end
    end

    // Injecao proposital de violacao de protocolo (+inject_proto_err), para
    // demonstrar que o checker SVA do OBJ-06 detecta o erro de fato (a
    // simulacao DEVE terminar com UVM_ERROR nesse modo; nao faz parte da
    // regressao normal).
    initial begin
        if ($test$plusargs("inject_proto_err")) begin
            wait (resetn);
            // espera uma busca de instrucao em andamento e forca wstrb
            @(posedge clk iff (mif.mem_valid && mif.mem_instr));
            force dut.mem_wstrb = 4'b1111;
            repeat (2) @(posedge clk);
            release dut.mem_wstrb;
        end
    end

endmodule : tb_top
