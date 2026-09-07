# Monta os firmwares de teste em RV32I puro (sem libc) e gera os .hex
# consumidos por $readmemh no testbench.
# Requer o toolchain cruzado riscv64-linux-gnu (dnf install
# binutils-riscv64-linux-gnu gcc-riscv64-linux-gnu no Rocky Linux).
#
# Firmwares:
#   phaseA_smoke.hex  - bring-up passivo da Fase A (soma 1..5 + ecall)
#   uvm_fw.hex        - laco de polling de pacotes do testbench UVM (Fase B+)

CROSS   ?= riscv64-linux-gnu-
CC      := $(CROSS)gcc
LD      := $(CROSS)ld
OBJCOPY := $(CROSS)objcopy

# .S passa pelo pre-processador C (gcc); rv32i puro, sem codigo de startup.
# -I para as macros das instrucoes customizadas de IRQ do PicoRV32
CFLAGS  := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -c \
           -I../rtl/picorv32/firmware
LDFLAGS := -m elf32lriscv -T link.ld

# INSTR_MEM_SIZE = 16 KB (tb/interfaces/mem_map.svh) => 4096 palavras de 32 bits
NWORDS  := 4096

FIRMWARES := phaseA_smoke.hex uvm_fw.hex

.PHONY: all clean
.SECONDARY:   # preserva .o/.elf/.bin intermediarios (util p/ objdump)
all: $(FIRMWARES)

%.o: %.S
	$(CC) $(CFLAGS) -o $@ $<

%.elf: %.o link.ld
	$(LD) $(LDFLAGS) -o $@ $<

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.hex: %.bin makehex.py
	python3 makehex.py $< $(NWORDS) > $@

# nome legado usado por sim/tb_phaseA.sv
firmware.hex: phaseA_smoke.hex
	cp $< $@

clean:
	rm -f *.o *.elf *.bin *.hex
