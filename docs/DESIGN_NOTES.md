# Design Notes — RV32I core + AXI accelerator (Tang Primer 20K)

Companion to [ROADMAP.md](ROADMAP.md). This is the "how it fits together and how to
run it" reference. Keep it short; update as the design grows.

## 1. Current status (Phase 1)

A working RV32I 5-stage pipeline with a self-checking simulation harness.

| Module | File | Role |
|--------|------|------|
| `rv32i_core` | [rtl/rv32i_core.v](../rtl/rv32i_core.v) | IF/ID/EX/MEM/WB pipeline, forwarding, hazards |
| `decoder` | [rtl/decoder.v](../rtl/decoder.v) | instruction decode + immediates + control |
| `alu` | [rtl/alu.v](../rtl/alu.v) | 32-bit ALU |
| `regfile` | [rtl/regfile.v](../rtl/regfile.v) | 32×32 regs, write-first for WB→ID |
| `soc_top` | [rtl/soc_top.v](../rtl/soc_top.v) | core + RAM + duplex UART/FIFO + LEDs |
| `uart_tx` | [rtl/uart_tx.v](../rtl/uart_tx.v) | 8N1 UART transmitter |
| `uart_rx` | [rtl/uart_rx.v](../rtl/uart_rx.v) | 8N1 UART receiver feeding a 16-byte FIFO |
| `sim_memory` | [sim/sim_memory.v](../sim/sim_memory.v) | unified async-read RAM for sim |
| `tb_top` | [sim/tb_top.v](../sim/tb_top.v) | testbench, watches the tohost address |

Pipeline design choices:
- **Forwarding** from EX/MEM and MEM/WB into EX (both operands).
- **Load-use hazard**: 1-cycle stall (freeze PC + IF/ID, inject a bubble).
- **Branches/jumps resolved in EX**; on taken, flush IF/ID and the ID/EX bubble
  (2 squashed instructions). Simple and correct; a later optimization is a branch
  predictor to reduce the 2-cycle penalty.

### Board pinout (Tang Primer 20K Dock)

Device: **GW2A-LV18PG256C8/I7** (GW2A-18C, PBGA256). Dock IO banks are 3.3 V, so
constraints use `IO_TYPE=LVCMOS33` (the IDE may default new pins to LVCMOS18).

| Signal | Pin | Note |
|--------|-----|------|
| `clk` | H11 | 27 MHz crystal (core board) |
| `rst_n_btn` | T10 | active-low Dock key |
| `uart_tx_pin` | M11 | to BL702 USB-UART |
| `uart_rx_pin` | T13 | from BL702 USB-UART |
| `led[0..2]` | N16, N14, L14 | Dock user LEDs |

Constraints: [gowin/tangprimer20k.cst](../gowin/tangprimer20k.cst),
[gowin/tangprimer20k.sdc](../gowin/tangprimer20k.sdc).

## 2. Memory map

Simulation (`tb_top` + `sim_memory`, 16 KB unified):

| Address | Use |
|---------|-----|
| `0x0000_0000 …` | code + data (word 0 = reset vector) |
| `0x0000_0800` | test scratch region |
| `0x0000_1000` | **tohost** — store `1`=PASS, anything else=FAIL(code) |

Board SoC (`soc_top`): 4 KiB low RAM, plus MMIO at `0x8000_0000` (UART data;
write=TX, read=RX FIFO pop), `0x8000_0004` (UART status: TX busy, RX ready/full,
overrun and framing error), and `0x8000_0008` (LED register). The resident
monitor occupies `0x000..0x7FF`; uploaded applications use `0x800..0xDFF` and
the stack uses `0xE00..0xFFF`. The AXI accelerator (Phase 6) will get its own
MMIO window, e.g. `0x9000_0000`.

## 3. How to simulate (no GCC needed)

The test program is generated **and validated in Python** by a golden ISS, so you
can trust the vector before touching RTL:

```
cd fpga_riscv/sim
python gen_test.py        # prints "ISS: PASS" and writes program.hex
```

To run it through the actual Verilog (needs Icarus Verilog):

```
./run_sim.ps1             # Windows: generates hex, compiles, runs
# or:  make                (with iverilog + vvp on PATH)
```

A correct core prints `*** PASS ***`. A `*** FAIL *** code=N` tells you which
check (test id N, see `build()` in gen_test.py) diverged from the golden model.
This is the fastest debug loop: the ISS is the reference, the RTL must match it.

## 4. Toolchain path (Phase 2)

For real C programs use `riscv32-unknown-elf-gcc` with
`-march=rv32i -mabi=ilp32`. `sw/build.ps1` builds the resident monitor at
`0x000`; `sw/build_app.ps1` links an application at `0x800` and emits a
checksummed ASCII `.uart` stream that Tera Term can send. The bare-metal UART
driver polls TX busy before writes and RX ready before reads.

## 5. Accelerator plan (Phase 6) — the "GPU / AI card"

Two honest, board-sized workloads share one accelerator:

- **AI**: an INT8 **MAC array** (start with a wide dot-product unit, grow to a small
  systolic array). The CPU streams a matrix row + vector; the array returns the dot
  product. This is 90%+ of transformer/CNN runtime, so offloading it is the win.
- **Graphics** (to "run a game"): the same block also acts as a **framebuffer + blitter**
  driving **HDMI** (the Tang Primer 20K Dock has an HDMI connector). The CPU writes
  tiles/sprites to a BRAM/DDR3 framebuffer; a scan-out engine streams pixels to HDMI.

Control interface: **AXI4-Lite** register block (start, done/IRQ, source/dest base
pointers, dims, mode). Bulk data moves over **AXI4** (or a simpler stream) from
**DDR3** (128 MB on the Dock, via the Gowin "DDR3 Memory Interface" IP — big enough
for quantized weights and a framebuffer).

Suggested AXI4-Lite register draft:

| Offset | Reg | Meaning |
|--------|-----|---------|
| 0x00 | CTRL | bit0 start, bit1 irq_en |
| 0x04 | STATUS | bit0 busy, bit1 done |
| 0x08 | SRC_A | base pointer, operand A |
| 0x0C | SRC_B | base pointer, operand B |
| 0x10 | DST | base pointer, result |
| 0x14 | LEN | element count / dims |
| 0x18 | MODE | 0=matmul INT8, 1=blit, … |

## 6. Immediate next steps

1. Run `run_sim.ps1` (or the Gowin simulator) to confirm `*** PASS ***` on RTL.
2. Build `sw/build.ps1`, synthesize and flash the resident UART monitor, then
   send `sw/build/*.uart` application images from Tera Term.
3. Phase 4: add the M extension (multi-cycle mul/div with a stall handshake) and
   extend gen_test.py with MUL/DIV checks (the golden ISS grows the same way).
