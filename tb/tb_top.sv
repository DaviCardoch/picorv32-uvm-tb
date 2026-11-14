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

    // Injecao proposital nas demais assertivas do OBJ-06: a falha dura um
    // ciclo, durante a primeira transferencia pendente, e e aplicada na borda
    // de descida para que nucleo, driver, monitor e assertivas leiam o mesmo
    // valor na borda de subida (nao faz parte da regressao normal):
    //   +inject_valid_err: mem_valid cai antes de mem_ready (a_valid_estavel)
    //   +inject_addr_err: mem_addr muda antes de mem_ready (a_addr_estavel)
    // Em um reg, o release mantem o valor forcado, por isso o valor original
    // e restaurado logo em seguida.
    logic [31:0] addr_err_valor;

    initial begin
        if ($test$plusargs("inject_valid_err")) begin
            wait (resetn);
            @(posedge clk iff (mif.mem_valid && !mif.mem_ready));
            @(negedge clk);
            force dut.mem_valid = 1'b0;
            @(negedge clk);
            release dut.mem_valid;
            dut.mem_valid = 1'b1;
        end
        else if ($test$plusargs("inject_addr_err")) begin
            wait (resetn);
            @(posedge clk iff (mif.mem_valid && !mif.mem_ready));
            @(negedge clk);
            addr_err_valor = dut.mem_addr;
            force dut.mem_addr = addr_err_valor ^ 32'h4;
            @(negedge clk);
            release dut.mem_addr;
            dut.mem_addr = addr_err_valor;
        end
    end

    // Injecao proposital de falha em EOI, para demonstrar que as assertivas
    // do OBJ-07 detectam o erro de fato. N e o numero de ciclos que a falha
    // dura apos a busca de referencia, e so a primeira interrupcao e atingida
    // (nao faz parte da regressao normal):
    //   +inject_eoi_sobe=N: eoi fica em zero do pulso ate N ciclos apos a
    //   busca no vetor (a_eoi_sobe deve disparar a partir de N=1)
    //   +inject_eoi_encerra=N: eoi fica ativo ate N ciclos apos a busca de
    //   retirq (a_eoi_encerra deve disparar a partir de N=4)
    // Em um reg, o release mantem o valor forcado, por isso o valor correto
    // e restaurado logo em seguida.
    int unsigned eoi_err_ciclos;
    logic [31:0] eoi_err_valor;

    initial begin
        if ($value$plusargs("inject_eoi_sobe=%d", eoi_err_ciclos)) begin
            wait (resetn);
            @(posedge clk iff (iif.irq != '0));
            eoi_err_valor = iif.irq;
            force dut.eoi = 32'h0;
            @(posedge clk iff (mif.mem_valid && mif.mem_ready && mif.mem_instr
                               && mif.mem_addr == 32'h0000_0010));
            repeat (eoi_err_ciclos) @(posedge clk);
            release dut.eoi;
            dut.eoi = eoi_err_valor;
        end
        else if ($value$plusargs("inject_eoi_encerra=%d", eoi_err_ciclos)) begin
            wait (resetn);
            @(posedge clk iff (mif.mem_valid && mif.mem_ready && mif.mem_instr
                               && mif.mem_rdata == 32'h0400_000B));
            eoi_err_valor = dut.eoi;
            force dut.eoi = eoi_err_valor;
            repeat (eoi_err_ciclos) @(posedge clk);
            release dut.eoi;
            dut.eoi = 32'h0;
        end
    end

endmodule : tb_top
