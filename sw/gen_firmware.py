#!/usr/bin/env python3
"""
Minimal RV32I assembler + demo firmware generator (no RISC-V GCC required).

Generates firmware.hex (one 32-bit word, hex, per line) that $readmemh loads
into the SoC RAM. The demo:
  - transmits "HELLO\r\n" over the memory-mapped UART
  - toggles the LEDs
  - delays, then repeats forever

Run:  python gen_firmware.py
Outputs firmware.hex into ../gowin/ and ../sim/.
"""
import os

# ---------------- register names ----------------
REG = {f"x{i}": i for i in range(32)}
REG.update({
    "zero":0,"ra":1,"sp":2,"gp":3,"tp":4,"t0":5,"t1":6,"t2":7,
    "s0":8,"fp":8,"s1":9,"a0":10,"a1":11,"a2":12,"a3":13,"a4":14,
    "a5":15,"a6":16,"a7":17,"s2":18,"s3":19,"s4":20,"s5":21,"s6":22,
    "s7":23,"s8":24,"s9":25,"s10":26,"s11":27,"t3":28,"t4":29,"t5":30,"t6":31,
})
def r(x): return REG[x] if isinstance(x, str) else x

def u32(v): return v & 0xFFFFFFFF

# ---------------- encoders ----------------
def R(f7,rs2,rs1,f3,rd,op): return u32((f7<<25)|(r(rs2)<<20)|(r(rs1)<<15)|(f3<<12)|(r(rd)<<7)|op)
def I(imm,rs1,f3,rd,op):    return u32(((imm&0xFFF)<<20)|(r(rs1)<<15)|(f3<<12)|(r(rd)<<7)|op)
def S(imm,rs2,rs1,f3,op):
    imm&=0xFFF
    return u32(((imm>>5)<<25)|(r(rs2)<<20)|(r(rs1)<<15)|(f3<<12)|((imm&0x1F)<<7)|op)
def B(imm,rs2,rs1,f3,op):
    imm&=0x1FFF
    b12=(imm>>12)&1; b11=(imm>>11)&1; b10_5=(imm>>5)&0x3F; b4_1=(imm>>1)&0xF
    return u32((b12<<31)|(b10_5<<25)|(r(rs2)<<20)|(r(rs1)<<15)|(f3<<12)|(b4_1<<8)|(b11<<7)|op)
def U(imm,rd,op):           return u32((u32(imm)&0xFFFFF000)|(r(rd)<<7)|op)
def J(imm,rd,op):
    imm&=0x1FFFFF
    b20=(imm>>20)&1; b10_1=(imm>>1)&0x3FF; b11=(imm>>11)&1; b19_12=(imm>>12)&0xFF
    return u32((b20<<31)|(b10_1<<21)|(b11<<20)|(b19_12<<12)|(r(rd)<<7)|op)

# instruction helpers (subset)
def LUI(rd,imm):   return U(imm,rd,0x37)
def ADDI(rd,rs1,i):return I(i,rs1,0x0,rd,0x13)
def ADD(rd,a,b):   return R(0x00,b,a,0x0,rd,0x33)
def SUB(rd,a,b):   return R(0x20,b,a,0x0,rd,0x33)
def XOR(rd,a,b):   return R(0x00,b,a,0x4,rd,0x33)
def ANDI(rd,rs1,i):return I(i,rs1,0x7,rd,0x13)
def SW(rs2,off,rs1):return S(off,rs2,rs1,0x2,0x23)
def LW(rd,off,rs1): return I(off,rs1,0x2,rd,0x03)
def LBU(rd,off,rs1):return I(off,rs1,0x4,rd,0x03)
def BEQ(a,b,off):  return B(off,b,a,0x0,0x63)
def BNE(a,b,off):  return B(off,b,a,0x1,0x63)
def JAL(rd,off):   return J(off,rd,0x6F)
def JALR(rd,rs1,i):return I(i,rs1,0x0,rd,0x67)

# ---------------- two-pass assembler over a tiny program ----------------
# We use absolute word placement; branches/jumps computed from labels.
UART_DATA = 0x80000000
UART_STAT = 0x80000004
LED_ADDR  = 0x80000008

def assemble():
    """Explicit, correct, single flat program with local label resolution."""
    items = []   # ("lbl",name) | ("ins", fn)
    def L(n): items.append(("lbl", n))
    def E(fn): items.append(("ins", fn))

    # r: a7 = 0x80000000 (peripheral base)
    E(lambda pc: LUI("a7", 0x80000000))
    E(lambda pc: ADDI("t0", "zero", 0x3F))   # LED mask
    E(lambda pc: ADDI("s0", "zero", 0))      # LED state

    L("main")
    for ci, ch in enumerate(b"HELLO\r\n"):
        E(lambda pc, c=ch: ADDI("a0", "zero", c))
        L(f"wait{ci}")
        E(lambda pc: LW("t1", 0x04, "a7"))                       # status
        E(lambda pc, t=f"wait{ci}", lbls=None: BNE("t1","zero", LBLS[t]-pc))
        E(lambda pc: SW("a0", 0x00, "a7"))                       # tx byte

    # toggle LEDs
    E(lambda pc: XOR("s0", "s0", "t0"))
    E(lambda pc: SW("s0", 0x08, "a7"))

    # delay: t2 = 0x200000; loop until zero
    E(lambda pc: LUI("t2", 0x00200000))
    L("delay")
    E(lambda pc: ADDI("t2", "t2", -1))
    E(lambda pc, : BNE("t2","zero", LBLS["delay"]-pc))

    # back to main
    E(lambda pc, : JAL("zero", LBLS["main"]-pc))

    # ---- two passes to resolve labels ----
    global LBLS
    LBLS = {}
    pc = 0
    for kind, val in items:
        if kind == "lbl": LBLS[val] = pc
        else: pc += 4
    words = []
    pc = 0
    for kind, val in items:
        if kind == "lbl": continue
        words.append(val(pc)); pc += 4
    return words

def main():
    words = assemble()
    here = os.path.dirname(os.path.abspath(__file__))
    for outdir in [os.path.join(here,"..","gowin"), os.path.join(here,"..","sim")]:
        os.makedirs(outdir, exist_ok=True)
        path = os.path.join(outdir, "firmware.hex")
        with open(path,"w") as f:
            for w in words:
                f.write(f"{w:08x}\n")
        print(f"wrote {len(words)} words -> {os.path.normpath(path)}")

if __name__ == "__main__":
    main()
