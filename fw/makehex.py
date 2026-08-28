#!/usr/bin/env python3
#
# Adaptado de rtl/picorv32/firmware/makehex.py (Clifford Wolf / YosysHQ),
# "free and unencumbered software released into the public domain".
# Converte um binario cru (little-endian) em texto hexadecimal de uma
# palavra de 32 bits por linha, no formato que $readmemh espera para
# preencher `reg [31:0] mem [0:nwords-1]`.

from sys import argv

binfile = argv[1]
nwords = int(argv[2])

with open(binfile, "rb") as f:
    bindata = f.read()

assert len(bindata) <= 4 * nwords, "firmware maior que a memoria de instrucao (INSTR_MEM_SIZE)"
assert len(bindata) % 4 == 0, "binario nao esta alinhado em palavras de 32 bits"

for i in range(nwords):
    if i < len(bindata) // 4:
        w = bindata[4 * i: 4 * i + 4]
        print("%02x%02x%02x%02x" % (w[3], w[2], w[1], w[0]))
    else:
        print("0")
