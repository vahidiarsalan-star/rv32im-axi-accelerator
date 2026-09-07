#!/usr/bin/env python3
"""
Self-checking RV32I test generator + golden ISS (no RISC-V GCC required).

Emits `program.hex` (one 32-bit word, hex, per line) for tb_top.v. The program
exercises the RV32I base ISA and, on success, stores 1 to the "tohost" address
(0x1000); on any failure it stores the failing test id (>= 2).

A built-in Python instruction-set simulator (ISS) runs the same program so the
*test vector itself* can be validated here, without a Verilog simulator: running
this file prints "ISS: PASS" when the program reaches the pass store. When you
run program.hex on the Verilog core, a PASS means its embedded result checks
passed; this is not a per-instruction trace comparison. A FAIL code identifies
the embedded check that broke.

Usage:  python gen_test.py
"""
import os
import sys

TOHOST  = 0x1000     # tb_top watches stores here: 1 => PASS, else FAIL(code)
SCRATCH = 0x800      # data scratch region for load/store tests

# ------------------------------------------------------------------ registers
REG = {f"x{i}": i for i in range(32)}
REG.update({
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4, "t0": 5, "t1": 6, "t2": 7,
    "s0": 8, "fp": 8, "s1": 9, "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14,
    "a5": 15, "a6": 16, "a7": 17, "s2": 18, "s3": 19, "s4": 20, "s5": 21,
    "s6": 22, "s7": 23, "s8": 24, "s9": 25, "s10": 26, "s11": 27, "t3": 28,
    "t4": 29, "t5": 30, "t6": 31,
})
def r(x):  return REG[x] if isinstance(x, str) else x
def u32(v): return v & 0xFFFFFFFF

# ------------------------------------------------------------------ encoders
def R(f7, rs2, rs1, f3, rd, op):
    return u32((f7 << 25) | (r(rs2) << 20) | (r(rs1) << 15) | (f3 << 12) | (r(rd) << 7) | op)
def I(imm, rs1, f3, rd, op):
    return u32(((imm & 0xFFF) << 20) | (r(rs1) << 15) | (f3 << 12) | (r(rd) << 7) | op)
def S(imm, rs2, rs1, f3, op):
    imm &= 0xFFF
    return u32(((imm >> 5) << 25) | (r(rs2) << 20) | (r(rs1) << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op)
def B(imm, rs2, rs1, f3, op):
    imm &= 0x1FFF
    b12 = (imm >> 12) & 1; b11 = (imm >> 11) & 1
    b10_5 = (imm >> 5) & 0x3F; b4_1 = (imm >> 1) & 0xF
    return u32((b12 << 31) | (b10_5 << 25) | (r(rs2) << 20) | (r(rs1) << 15) | (f3 << 12) | (b4_1 << 8) | (b11 << 7) | op)
def U(imm, rd, op):
    return u32((u32(imm) & 0xFFFFF000) | (r(rd) << 7) | op)
def J(imm, rd, op):
    imm &= 0x1FFFFF
    b20 = (imm >> 20) & 1; b10_1 = (imm >> 1) & 0x3FF
    b11 = (imm >> 11) & 1; b19_12 = (imm >> 12) & 0xFF
    return u32((b20 << 31) | (b10_1 << 21) | (b11 << 20) | (b19_12 << 12) | (r(rd) << 7) | op)

# instruction helpers (opcode/funct constants inline)
def LUI(rd, imm):    return U(imm, rd, 0x37)
def AUIPC(rd, imm):  return U(imm, rd, 0x17)
def ADDI(rd, a, i):  return I(i, a, 0x0, rd, 0x13)
def SLTI(rd, a, i):  return I(i, a, 0x2, rd, 0x13)
def ANDI(rd, a, i):  return I(i, a, 0x7, rd, 0x13)
def ADD(rd, a, b):   return R(0x00, b, a, 0x0, rd, 0x33)
def SUB(rd, a, b):   return R(0x20, b, a, 0x0, rd, 0x33)
def SLL(rd, a, b):   return R(0x00, b, a, 0x1, rd, 0x33)
def SLT(rd, a, b):   return R(0x00, b, a, 0x2, rd, 0x33)
def SLTU(rd, a, b):  return R(0x00, b, a, 0x3, rd, 0x33)
def XOR(rd, a, b):   return R(0x00, b, a, 0x4, rd, 0x33)
def SRL(rd, a, b):   return R(0x00, b, a, 0x5, rd, 0x33)
def SRA(rd, a, b):   return R(0x20, b, a, 0x5, rd, 0x33)
def OR(rd, a, b):    return R(0x00, b, a, 0x6, rd, 0x33)
def AND(rd, a, b):   return R(0x00, b, a, 0x7, rd, 0x33)
def SB(rs2, off, rs1): return S(off, rs2, rs1, 0x0, 0x23)
def SH(rs2, off, rs1): return S(off, rs2, rs1, 0x1, 0x23)
def SW(rs2, off, rs1): return S(off, rs2, rs1, 0x2, 0x23)
def LB(rd, off, rs1):  return I(off, rs1, 0x0, rd, 0x03)
def LH(rd, off, rs1):  return I(off, rs1, 0x1, rd, 0x03)
def LW(rd, off, rs1):  return I(off, rs1, 0x2, rd, 0x03)
def LBU(rd, off, rs1): return I(off, rs1, 0x4, rd, 0x03)
def LHU(rd, off, rs1): return I(off, rs1, 0x5, rd, 0x03)
def JALR(rd, rs1, i):  return I(i, rs1, 0x0, rd, 0x67)

# ------------------------------------------------------------------ assembler
# A tiny two-pass assembler with labels. Instructions needing a label offset are
# emitted as closures fn(pc, labels) -> word.
_prog = []          # list of ('L', name) | ('I', fn)
def label(name):    _prog.append(('L', name))
def emit(fn):       _prog.append(('I', fn))
def ins(word):      emit(lambda pc, L, w=word: w)          # fixed instruction

def split_imm(imm):
    """Split a 32-bit value into (hi20, lo12-signed) for LUI+ADDI."""
    imm = u32(imm)
    lo = imm & 0xFFF
    if lo >= 0x800:
        lo -= 0x1000
    hi = (imm - lo) >> 12
    return hi & 0xFFFFF, lo

def li(rd, imm):
    """Load a full 32-bit immediate (always LUI+ADDI so size is fixed)."""
    hi, lo = split_imm(imm)
    emit(lambda pc, L, rd=rd, hi=hi: LUI(rd, hi << 12))
    emit(lambda pc, L, rd=rd, lo=lo: ADDI(rd, rd, lo))

def _branch(f3):
    def mk(rs1, rs2, target):
        emit(lambda pc, L, a=rs1, b=rs2, t=target: B(L[t] - pc, b, a, f3, 0x63))
    return mk
beq  = _branch(0x0); bne  = _branch(0x1)
blt  = _branch(0x4); bge  = _branch(0x5)
bltu = _branch(0x6); bgeu = _branch(0x7)

def jal(rd, target):
    emit(lambda pc, L, rd=rd, t=target: J(L[t] - pc, rd, 0x6F))

def assemble():
    labels = {}
    pc = 0
    for kind, val in _prog:
        if kind == 'L':
            labels[val] = pc
        else:
            pc += 4
    words, pc = [], 0
    for kind, val in _prog:
        if kind == 'L':
            continue
        words.append(u32(val(pc, labels)))
        pc += 4
    return words

# ------------------------------------------------------------------ test body
# Reserved registers: x29=expected, x30=fail-code, x31=tohost address.
def check_eq(reg_val, expected, tid):
    """If reg_val != expected, store tid to tohost and stop (branch to fail)."""
    li('t5', tid)          # x30 fail code
    li('t4', expected)     # x29 expected value
    bne(reg_val, 't4', 'fail')

def build():
    li('t6', TOHOST)                       # x31 = tohost

    # --- arithmetic / logic (keep x1=5, x2=7 through the shift+SLT group) ---
    ins(ADDI('x1', 'zero', 5));  check_eq('x1', 5, 2)          # ADDI
    ins(ADDI('x2', 'zero', 7))
    ins(ADD('x3', 'x1', 'x2'));  check_eq('x3', 12, 3)         # ADD
    ins(SUB('x4', 'x2', 'x1'));  check_eq('x4', 2, 4)          # SUB
    li('x5', 0xFF0); li('x6', 0x0FF)
    ins(AND('x7', 'x5', 'x6'));  check_eq('x7', 0x0F0, 5)      # AND
    ins(OR('x8', 'x5', 'x6'));   check_eq('x8', 0xFFF, 6)      # OR
    ins(XOR('x9', 'x5', 'x6'));  check_eq('x9', 0xF0F, 7)      # XOR
    ins(ADDI('x10', 'zero', 1))
    ins(SLL('x11', 'x10', 'x1')); check_eq('x11', 32, 8)       # SLL by x1=5
    li('x12', 0x100)
    ins(SRL('x13', 'x12', 'x1')); check_eq('x13', 8, 9)        # SRL by 5
    li('x14', 0xFFFFFFE0)                                       # -32
    ins(ADDI('x15', 'zero', 1))
    ins(SRA('x16', 'x14', 'x15')); check_eq('x16', 0xFFFFFFF0, 10)  # SRA -32>>1=-16
    ins(SLT('x17', 'x1', 'x2'));   check_eq('x17', 1, 11)      # SLT 5<7
    ins(SLTU('x18', 'x2', 'x1'));  check_eq('x18', 0, 12)      # SLTU 7<5 false
    ins(SLTI('x19', 'x1', 10));    check_eq('x19', 1, 13)      # SLTI 5<10
    ins(LUI('x20', 0x12345000));   check_eq('x20', 0x12345000, 14)  # LUI

    # --- AUIPC: difference of two consecutive AUIPCs is exactly 4 (pc-indep) ---
    ins(AUIPC('x21', 0))
    ins(AUIPC('x22', 0))
    ins(SUB('x23', 'x22', 'x21')); check_eq('x23', 4, 15)      # AUIPC

    # --- loads / stores (x2 now repurposed as the scratch base pointer) ---
    li('x2', SCRATCH)
    li('x3', 0xDEADBEEF)
    ins(SW('x3', 0, 'x2'))
    ins(LW('x4', 0, 'x2'));        check_eq('x4', 0xDEADBEEF, 16)   # SW/LW
    li('x5', 0xAB)
    ins(SB('x5', 4, 'x2'))
    ins(LBU('x6', 4, 'x2'));       check_eq('x6', 0xAB, 17)         # SB/LBU
    ins(LB('x7', 4, 'x2'));        check_eq('x7', 0xFFFFFFAB, 18)   # LB sign-ext
    li('x8', 0x1234)
    ins(SH('x8', 8, 'x2'))
    ins(LHU('x9', 8, 'x2'));       check_eq('x9', 0x1234, 19)       # SH/LHU
    li('x10', 0x8765)
    ins(SH('x10', 12, 'x2'))
    ins(LH('x11', 12, 'x2'));      check_eq('x11', 0xFFFF8765, 20)  # LH sign-ext

    # --- load-use hazard: consumer immediately after a load (needs the stall) ---
    li('x12', 0x55)
    ins(SW('x12', 16, 'x2'))
    ins(LW('x13', 16, 'x2'))
    ins(ADDI('x13', 'x13', 1));    check_eq('x13', 0x56, 21)        # load-use

    # --- control flow: forward branch taken (BEQ), plus BLT/BGEU signed/unsigned ---
    ins(ADDI('x14', 'zero', 0))
    beq('zero', 'zero', 'skip_beq')
    ins(ADDI('x14', 'zero', 99))                                    # must be skipped
    label('skip_beq')
    check_eq('x14', 0, 22)                                          # BEQ taken

    li('x15', 0xFFFFFFFF)                                           # -1
    ins(ADDI('x16', 'zero', 1))
    ins(ADDI('x17', 'zero', 0))
    blt('x15', 'x16', 'skip_blt')                                   # -1 < 1 signed
    ins(ADDI('x17', 'zero', 55))
    label('skip_blt')
    check_eq('x17', 0, 23)                                          # BLT signed

    ins(ADDI('x18', 'zero', 0))
    bgeu('x1', 'x1', 'skip_bgeu')                                   # 5 >= 5 unsigned
    ins(ADDI('x18', 'zero', 66))
    label('skip_bgeu')
    check_eq('x18', 0, 24)                                          # BGEU taken

    # --- JAL / JALR round trip ---
    ins(ADDI('x19', 'zero', 0))
    jal('ra', 'func1')                                              # call
    check_eq('x19', 123, 25)                                        # returned & set

    # --- success ---
    label('pass')
    ins(ADDI('t5', 'zero', 1))
    ins(SW('t5', 0, 't6'))                                          # store 1 -> tohost
    label('hang')
    jal('zero', 'hang')

    # --- failure sink: x30 holds the failing test id ---
    label('fail')
    ins(SW('t5', 0, 't6'))
    jal('zero', 'hang')

    # --- subroutine: sets x19=123 and returns via ra ---
    label('func1')
    ins(ADDI('x19', 'zero', 123))
    ins(JALR('zero', 'ra', 0))

# ------------------------------------------------------------------ golden ISS
def sext(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v

def run_iss(words, max_steps=200000):
    MEMB = 0x2000
    mem = bytearray(MEMB)
    for i, w in enumerate(words):
        mem[i * 4:i * 4 + 4] = u32(w).to_bytes(4, 'little')
    reg = [0] * 32
    pc = 0
    def load(addr, size, signed):
        v = int.from_bytes(mem[addr:addr + size], 'little')
        return sext(v, size * 8) if signed else v
    for _ in range(max_steps):
        inst = int.from_bytes(mem[pc:pc + 4], 'little')
        op = inst & 0x7F
        rd = (inst >> 7) & 0x1F
        f3 = (inst >> 12) & 0x7
        rs1 = (inst >> 15) & 0x1F
        rs2 = (inst >> 20) & 0x1F
        f7 = (inst >> 25) & 0x7F
        a, b = reg[rs1], reg[rs2]
        imm_i = sext(inst >> 20, 12)
        imm_s = sext(((inst >> 25) << 5) | ((inst >> 7) & 0x1F), 12)
        imm_b = sext(((inst >> 31) << 12) | (((inst >> 7) & 1) << 11) |
                     (((inst >> 25) & 0x3F) << 5) | (((inst >> 8) & 0xF) << 1), 13)
        imm_u = inst & 0xFFFFF000
        imm_j = sext(((inst >> 31) << 20) | (((inst >> 12) & 0xFF) << 12) |
                     (((inst >> 20) & 1) << 11) | (((inst >> 21) & 0x3FF) << 1), 21)
        npc = u32(pc + 4)
        wb = None                                   # (rd, value) to write back

        if op == 0x37:                              # LUI
            wb = (rd, imm_u)
        elif op == 0x17:                            # AUIPC
            wb = (rd, u32(pc + imm_u))
        elif op == 0x6F:                            # JAL
            wb = (rd, npc); npc = u32(pc + imm_j)
        elif op == 0x67:                            # JALR
            wb = (rd, npc); npc = u32((a + imm_i) & ~1)
        elif op == 0x63:                            # BRANCH
            sa, sb = sext(a, 32), sext(b, 32)
            take = {0x0: a == b, 0x1: a != b, 0x4: sa < sb,
                    0x5: sa >= sb, 0x6: a < b, 0x7: a >= b}[f3]
            if take:
                npc = u32(pc + imm_b)
        elif op == 0x03:                            # LOAD
            addr = u32(a + imm_i)
            val = {0x0: lambda: load(addr, 1, True),
                   0x1: lambda: load(addr, 2, True),
                   0x2: lambda: load(addr, 4, False),
                   0x4: lambda: load(addr, 1, False),
                   0x5: lambda: load(addr, 2, False)}[f3]()
            wb = (rd, u32(val))
        elif op == 0x23:                            # STORE
            addr = u32(a + imm_s)
            size = {0x0: 1, 0x1: 2, 0x2: 4}[f3]
            if addr == TOHOST:
                return u32(b)                       # tohost write ends the run
            mem[addr:addr + size] = (b & ((1 << (size * 8)) - 1)).to_bytes(size, 'little')
        elif op in (0x13, 0x33):                    # OP-IMM / OP
            src2 = imm_i if op == 0x13 else b
            sh = (src2 & 0x1F)
            if f3 == 0x0:
                res = a - b if (op == 0x33 and f7 == 0x20) else a + src2
            elif f3 == 0x1:
                res = a << sh
            elif f3 == 0x2:
                res = 1 if sext(a, 32) < sext(src2, 32) else 0
            elif f3 == 0x3:
                res = 1 if u32(a) < u32(src2) else 0
            elif f3 == 0x4:
                res = a ^ src2
            elif f3 == 0x5:
                res = (sext(a, 32) >> sh) if f7 == 0x20 else (u32(a) >> sh)
            elif f3 == 0x6:
                res = a | src2
            else:
                res = a & src2
            wb = (rd, u32(res))
        else:
            raise RuntimeError(f"ISS: illegal instruction {inst:#010x} at pc={pc:#x}")

        if wb is not None and wb[0] != 0:
            reg[wb[0]] = u32(wb[1])
        pc = npc
    raise RuntimeError("ISS: timeout (no tohost write)")

# ------------------------------------------------------------------ main
def main():
    build()
    words = assemble()

    result = run_iss(words)
    if result == 1:
        print(f"ISS: PASS  ({len(words)} instructions)")
    else:
        print(f"ISS: FAIL  test id={result}")
        sys.exit(1)

    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "program.hex")
    with open(path, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")
    print(f"wrote {len(words)} words -> {os.path.normpath(path)}")

if __name__ == "__main__":
    main()
