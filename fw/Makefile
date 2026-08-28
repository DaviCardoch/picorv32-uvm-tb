# Fase A -- monta o firmware minimo em RV32I puro (sem libc) e gera o
# firmware.hex consumido por $readmemh no wrapper de simulacao.
# Requer o toolchain cruzado `riscv64-linux-gnu-{as,ld,objcopy}` (dnf install
# binutils-riscv64-linux-gnu gcc-riscv64-linux-gnu no Rocky Linux).

CROSS   ?= riscv64-linux-gnu-
AS      := $(CROSS)as
LD      := $(CROSS)ld
OBJCOPY := $(CROSS)objcopy

ASFLAGS := -march=rv32i -mabi=ilp32
LDFLAGS := -m elf32lriscv -T link.ld

# INSTR_MEM_SIZE = 16 KB (tb/interfaces/mem_map.svh) => 4096 palavras de 32 bits
NWORDS  := 4096

.PHONY: all clean
all: firmware.hex

phaseA_smoke.o: phaseA_smoke.S
	$(AS) $(ASFLAGS) -o $@ $<

phaseA_smoke.elf: phaseA_smoke.o link.ld
	$(LD) $(LDFLAGS) -o $@ phaseA_smoke.o

phaseA_smoke.bin: phaseA_smoke.elf
	$(OBJCOPY) -O binary $< $@

firmware.hex: phaseA_smoke.bin makehex.py
	python3 makehex.py $< $(NWORDS) > $@

clean:
	rm -f phaseA_smoke.o phaseA_smoke.elf phaseA_smoke.bin firmware.hex
