`ifndef MEM_MAP_SVH
`define MEM_MAP_SVH

// Mapa de endereços do Memory Agent -- rascunho, ver PLAN.md secao 1.1.
// Ainda nao validado contra uma implementacao real; revisar na Fase B.

// Memoria de instrucao (mem_instr = 1): 16 KB a partir do reset vector padrao
// do PicoRV32 (PROGADDR_RESET = 0x00000000).
localparam int unsigned INSTR_MEM_BASE  = 32'h0000_0000;
localparam int unsigned INSTR_MEM_SIZE  = 32'h0000_4000; // 16 KB

// RAM de dados (mem_instr = 0, pilha/variaveis do firmware): 16 KB.
// Stack pointer inicial sugerido = DATA_MEM_BASE + DATA_MEM_SIZE - 4.
localparam int unsigned DATA_MEM_BASE   = 32'h0001_0000;
localparam int unsigned DATA_MEM_SIZE   = 32'h0000_4000; // 16 KB

// Registradores emulados do front-end RF (mem_instr = 0), somente leitura
// do ponto de vista do nucleo.
localparam int unsigned RF_REGS_BASE    = 32'h1000_0000;

localparam int unsigned ADDR_TAG_ID     = RF_REGS_BASE + 32'h0; // OBJ-01 (leitura)
localparam int unsigned ADDR_CRC_STATUS = RF_REGS_BASE + 32'h4; // OBJ-02 (leitura)
localparam int unsigned ADDR_PKT_STATUS = RF_REGS_BASE + 32'h8; // 1 = novo pacote disponivel (leitura)

// Registradores de resultado, escritos pelo firmware apos processar cada
// pacote (decisao da Fase B): dao ao scoreboard uma saida observavel para
// comparar com o modelo de referencia (aceita se CRC valido, rejeita caso
// contrario), fechando a checagem fim-a-fim atraves do software executado
// pelo nucleo.
localparam int unsigned ADDR_RESULT_TAG    = RF_REGS_BASE + 32'hC;  // tag processada (escrita)
localparam int unsigned ADDR_RESULT_STATUS = RF_REGS_BASE + 32'h10; // veredito (escrita)

// Codificacao de CRC_STATUS (bate com o coverpoint de validade de CRC, OBJ-02).
localparam int unsigned CRC_VALID           = 32'd0;
localparam int unsigned CRC_INVALID_1BIT    = 32'd1;
localparam int unsigned CRC_INVALID_MULTIBIT= 32'd2;

// Codificacao de RESULT_STATUS escrita pelo firmware.
localparam int unsigned RESULT_ACCEPT = 32'd1;
localparam int unsigned RESULT_REJECT = 32'd2;

`endif // MEM_MAP_SVH
