"""Small directed and seeded programs; each checks results before TOHOST success.

Uses the existing assembler and ISS. Random ALU expected values are also computed
by a separate architectural register model. These are end-state checks, not an
independent external ISA compliance suite or per-retirement lockstep comparison.
"""
import random
import gen_test as g


def begin():
    g._prog.clear()
    g.li(31, g.TOHOST)


def finish():
    g.ins(g.ADDI(30, 0, 1))
    g.ins(g.SW(30, 0, 31))
    g.label("hang")
    g.jal(0, "hang")
    g.label("fail")
    g.ins(g.SW(30, 0, 31))
    g.jal(0, "hang")
    words = g.assemble()
    if len(words) * 4 >= g.SCRATCH:
        raise AssertionError("Test program overlaps scratch RAM")
    result = g.run_iss(words)
    if result != 1:
        raise AssertionError(f"ISS rejected generated program: test {result}")
    return words


def hazards():
    begin()
    # Youngest producer wins when EX/MEM and MEM/WB both match.
    g.ins(g.ADDI(1, 0, 7))
    g.ins(g.ADDI(1, 1, 2))
    g.ins(g.ADD(2, 1, 1))
    g.check_eq(2, 18, 2)
    # WB-to-ID write-first bypass at producer distance three.
    g.ins(g.ADDI(3, 0, 23))
    g.ins(g.ADDI(0, 0, 0))
    g.ins(g.ADDI(0, 0, 0))
    g.ins(g.ADDI(4, 3, 1))
    g.check_eq(4, 24, 3)
    g.li(10, g.SCRATCH)
    g.ins(g.ADDI(5, 0, 101))
    g.ins(g.SW(5, 0, 10))  # adjacent store data forwarding
    g.ins(g.LW(6, 0, 10))
    g.ins(g.SW(6, 4, 10))  # load -> store data dependency
    g.ins(g.LW(7, 4, 10))
    g.ins(g.ADD(8, 7, 7))  # load -> both ALU operands
    g.check_eq(8, 202, 4)
    g.ins(g.ADDI(9, 10, 8))
    g.ins(g.SW(5, 0, 9))  # forwarded store address
    g.ins(g.LW(11, 8, 10))
    g.check_eq(11, 101, 5)
    g.ins(g.ADDI(0, 0, 123))
    g.ins(g.LW(0, 0, 10))
    g.ins(g.ADDI(12, 0, 9))
    g.check_eq(0, 0, 6)
    g.check_eq(12, 9, 7)
    # A load result used by an immediately following taken branch.
    g.ins(g.LW(13, 0, 10))
    g.beq(13, 5, "load_branch")
    g.ins(g.SW(0, 4, 10))  # wrong path must never write
    g.ins(g.ADDI(7, 0, 0))
    g.label("load_branch")
    g.ins(g.LW(14, 4, 10))
    g.check_eq(14, 101, 8)
    g.check_eq(7, 101, 9)
    return finish()


def memory_lanes():
    begin()
    g.li(10, g.SCRATCH)
    for lane in range(4):
        g.li(1, 0x11223344)
        g.ins(g.SW(1, 0, 10))
        g.ins(g.ADDI(2, 0, 0x80 + lane))
        g.ins(g.SB(2, lane, 10))
        g.ins(g.LW(3, 0, 10))
        expected = (0x11223344 & ~(255 << (8 * lane))) | ((0x80 + lane) << (8 * lane))
        g.check_eq(3, expected, 2 + lane * 3)
        g.ins(g.LB(4, lane, 10))
        g.check_eq(4, g.u32(0x80 + lane - 256), 3 + lane * 3)
        g.ins(g.LBU(5, lane, 10))
        g.check_eq(5, 0x80 + lane, 4 + lane * 3)
    for lane in (0, 2):
        g.li(1, 0x11223344)
        g.ins(g.SW(1, 0, 10))
        g.li(2, 0x80fe)
        g.ins(g.SH(2, lane, 10))
        g.ins(g.LW(3, 0, 10))
        expected = (0x11223344 & ~(65535 << (8 * lane))) | (0x80fe << (8 * lane))
        g.check_eq(3, expected, 20 + lane)
        g.ins(g.LH(4, lane, 10))
        g.check_eq(4, 0xffff80fe, 24 + lane)
        g.ins(g.LHU(5, lane, 10))
        g.check_eq(5, 0x80fe, 28 + lane)
    return finish()


def control_flow():
    begin()
    branches = [(g.beq, 5, 5), (g.bne, 5, 6), (g.blt, -1, 1),
                (g.bge, 1, -1), (g.bltu, 1, -1), (g.bgeu, -1, 1)]
    for index, (branch, a, b) in enumerate(branches):
        g.li(1, a)
        g.li(2, b)
        g.ins(g.ADDI(3, 0, 0))
        branch(1, 2, f"taken{index}")
        g.ins(g.ADDI(3, 0, 99))
        g.ins(g.ADDI(3, 0, 88))
        g.label(f"taken{index}")
        g.check_eq(3, 0, 2 + index)
    # Both outcomes for every branch predicate.
    not_taken = [(g.beq, 5, 6), (g.bne, 5, 5), (g.blt, 1, -1),
                 (g.bge, -1, 1), (g.bltu, -1, 1), (g.bgeu, 1, -1)]
    for index, (branch, a, b) in enumerate(not_taken):
        g.li(1, a)
        g.li(2, b)
        g.ins(g.ADDI(30, 0, 20 + index))
        branch(1, 2, "fail")
    # Backward branch loop.
    g.ins(g.ADDI(5, 0, 3))
    g.label("loop")
    g.ins(g.ADDI(5, 5, -1))
    g.bne(5, 0, "loop")
    g.check_eq(5, 0, 30)
    # JALR must clear bit zero; immediate producer supplies its target.
    g.emit(lambda pc, labels: g.ADDI(6, 0, labels["indirect"] | 1))
    g.ins(g.JALR(7, 6, 0))
    g.ins(g.ADDI(30, 0, 31))
    g.ins(g.SW(30, 0, 31))
    g.label("indirect")
    g.emit(lambda pc, labels: g.ADDI(8, 0, labels["indirect"] - 8))
    g.bne(7, 8, "fail")
    return finish()


def seeded_alu(seed):
    begin()
    rng = random.Random(seed)
    state = [0] * 32
    for rd in range(1, 16):
        state[rd] = rng.choice([0, 1, 31, 32, 0x7fffffff, 0x80000000, 0xffffffff, rng.getrandbits(32)])
        g.li(rd, state[rd])
    for _ in range(128):
        rd, rs1, rs2 = (rng.randrange(16) for _ in range(3))
        a, b = state[rs1], state[rs2]
        f3 = rng.randrange(8)
        alternate = rng.randrange(2) == 1 and f3 in (0, 5)
        f7 = 0x20 if alternate else 0
        g.ins(g.R(f7, rs2, rs1, f3, rd, 0x33))
        sh = b & 31
        if f3 == 0: value = a - b if alternate else a + b
        elif f3 == 1: value = a << sh
        elif f3 == 2: value = int(g.sext(a, 32) < g.sext(b, 32))
        elif f3 == 3: value = int(a < b)
        elif f3 == 4: value = a ^ b
        elif f3 == 5: value = g.sext(a, 32) >> sh if alternate else a >> sh
        elif f3 == 6: value = a | b
        else: value = a & b
        if rd: state[rd] = g.u32(value)
    for rd in range(16):
        g.check_eq(rd, state[rd], rd + 2)
    return finish()


def immediate_edges():
    begin()
    tid = 2
    for a in [0, 0x80000000, 0x7fffffff, 0xffffffff]:
        g.li(1, a)
        for f3, imm, expected in [(0, -1, a - 1), (2, -1, int(g.sext(a, 32) < -1)),
                                 (3, -1, int(a < 0xffffffff)), (4, -1, a ^ 0xffffffff),
                                 (6, 1, a | 1), (7, 2047, a & 2047),
                                 (1, 31, a << 31), (5, 31, a >> 31),
                                 (5, 0x41f, g.sext(a, 32) >> 31)]:
            g.ins(g.I(imm, 1, f3, 2, 0x13))
            g.check_eq(2, g.u32(expected), tid)
            tid += 1
    return finish()


def cases():
    g._prog.clear()
    g.build()
    baseline = g.assemble()
    assert g.run_iss(baseline) == 1
    yield "baseline", baseline
    for name, function in [("hazards", hazards), ("memory_lanes", memory_lanes),
                           ("control_flow", control_flow), ("immediate_edges", immediate_edges)]:
        yield name, function()
    for seed in [0, 1, 7, 42, 2026, 0xc0de]:
        yield f"alu_seed_{seed}", seeded_alu(seed)
