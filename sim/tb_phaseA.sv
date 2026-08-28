// Fase A -- bring-up passivo do PicoRV32, sem UVM. Wrapper simples com
// memoria de instrucao + RAM de dados seguindo o mapa de enderecos de
// tb/interfaces/mem_map.svh. Ver PLAN.md secoes 2-3.
//
// Objetivo: confirmar que o ambiente VCS/Verdi compila e simula o DUT real
// (nao um substituto), executando um programa de verdade (fw/phaseA_smoke.S)
// e observando o handshake mem_valid/mem_ready em forma de onda.

`timescale 1ns / 1ps
`include "mem_map.svh"

module tb_phaseA;

    // ---- clock / reset ----
    reg clk = 0;
    reg resetn = 0;
    always #5 clk = ~clk; // 100 MHz

    initial begin
        resetn = 0;
        repeat (10) @(posedge clk);
        resetn = 1;
    end

    // ---- interface nativa de memoria do PicoRV32 ----
    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    reg  [31:0] mem_rdata;
    wire [31:0] eoi;
    wire        trap;

    // Fase A nao tem IRQ Agent ainda (isso e a Fase D) -- linhas de IRQ
    // amarradas em zero e ENABLE_IRQ desligado no DUT.
    wire [31:0] irq = 32'b0;

    picorv32 #(
        .ENABLE_COUNTERS     (1),
        .ENABLE_COUNTERS64   (1),
        .ENABLE_REGS_16_31   (1),
        .ENABLE_REGS_DUALPORT(1),
        .COMPRESSED_ISA      (0),
        .ENABLE_MUL          (0),
        .ENABLE_DIV          (0),
        .ENABLE_IRQ          (0),
        .CATCH_MISALIGN      (1),
        .CATCH_ILLINSN       (1),
        .STACKADDR           (DATA_MEM_BASE + DATA_MEM_SIZE - 4),
        .PROGADDR_RESET      (INSTR_MEM_BASE)
    ) dut (
        .clk      (clk),
        .resetn   (resetn),
        .trap     (trap),

        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr (mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),

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

        .irq(irq),
        .eoi(eoi)
    );

    // ---- memoria de instrucao + RAM de dados (rascunho do mapa de
    // enderecos; os registradores emulados de RF em RF_REGS_BASE ainda nao
    // existem aqui -- entram como Memory Agent UVM na Fase B) ----
    reg [31:0] instr_mem [0 : INSTR_MEM_SIZE/4 - 1];
    reg [31:0] data_mem  [0 : DATA_MEM_SIZE/4 - 1];

    string firmware_hex;
    initial begin
        if (!$value$plusargs("firmware=%s", firmware_hex))
            firmware_hex = "../fw/firmware.hex";
        $readmemh(firmware_hex, instr_mem);
    end

    // Memoria sincrona com 1 ciclo de espera antes de mem_ready, para bater
    // com o handshake ilustrado na Figura 3.2 da monografia.
    always @(posedge clk) begin
        mem_ready <= 1'b0;
        if (mem_valid && !mem_ready) begin
            if (mem_addr >= INSTR_MEM_BASE && mem_addr < INSTR_MEM_BASE + INSTR_MEM_SIZE) begin
                mem_rdata <= instr_mem[(mem_addr - INSTR_MEM_BASE) >> 2];
                mem_ready <= 1'b1;
            end else if (mem_addr >= DATA_MEM_BASE && mem_addr < DATA_MEM_BASE + DATA_MEM_SIZE) begin
                if (mem_wstrb != 4'b0000) begin
                    if (mem_wstrb[0]) data_mem[(mem_addr - DATA_MEM_BASE) >> 2][ 7: 0] <= mem_wdata[ 7: 0];
                    if (mem_wstrb[1]) data_mem[(mem_addr - DATA_MEM_BASE) >> 2][15: 8] <= mem_wdata[15: 8];
                    if (mem_wstrb[2]) data_mem[(mem_addr - DATA_MEM_BASE) >> 2][23:16] <= mem_wdata[23:16];
                    if (mem_wstrb[3]) data_mem[(mem_addr - DATA_MEM_BASE) >> 2][31:24] <= mem_wdata[31:24];
                end else begin
                    mem_rdata <= data_mem[(mem_addr - DATA_MEM_BASE) >> 2];
                end
                mem_ready <= 1'b1;
            end else begin
                $display("[tb_phaseA] ERRO: acesso fora do mapa de enderecos conhecido em %08x (mem_instr=%0d, mem_wstrb=%04b) em t=%0t",
                          mem_addr, mem_instr, mem_wstrb, $time);
                $finish;
            end
        end
    end

    // ---- waveform para o Verdi ----
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_phaseA.vcd");
            $dumpvars(0, tb_phaseA);
        end
    end

    // ---- fim de simulacao ----
    initial begin
        repeat (2000) @(posedge clk);
        $display("[tb_phaseA] TIMEOUT -- nucleo nao chegou ao trap esperado (ecall)");
        $finish;
    end

    always @(posedge clk) begin
        if (resetn && trap) begin
            repeat (5) @(posedge clk);
            if (data_mem[0] === 32'd15)
                $display("[tb_phaseA] OK: trap (ecall) recebido, soma em DATA_MEM_BASE = %0d (esperado 15)", data_mem[0]);
            else
                $display("[tb_phaseA] FALHA: trap recebido mas soma = %0d (esperado 15)", data_mem[0]);
            $finish;
        end
    end

endmodule
