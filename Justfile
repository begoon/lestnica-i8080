# LESTNICA-TAPE.GAM is the tape byte copy with a 5-byte prefix (E6 AA AA BB BB)
# where AAAA=start address, BBBB=end address, and a 3-byte trailer (E6 XX YY)
# where XXYY=checksum. LESTNICA.GAM is the raw binary (7712 bytes, org 0100h).

ci: build test

build:
    bunx asm8080 --split -l lestnica.asm

test:
    xxd LESTNICA.GAM >LESTNICA.GAM.hex
    xxd lestnica.bin >lestnica.bin.hex
    diff LESTNICA.GAM.hex lestnica.bin.hex

disasm:
    python3 disasm.py LESTNICA.GAM 0x100 >lestnica.asm
