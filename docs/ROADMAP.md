# RISC-V Pipelined CPU + AXI Accelerator on Tang Nano 20K

Target board: **Tang Primer 20K** + Dock (Gowin **GW2A-18C**, `GW2A-LV18PG256C8/I7`, PBGA256, ~20.7k LUTs, block SRAM, **128 MB DDR3** on-board)
HDL: **Verilog-2001**
Sim first: **Verilator / Icarus Verilog**, then **Gowin EDA** for synthesis.

## Guiding goal
Run real **C programs** on the core, then offload heavy math (matrix-vector multiply) to an
**AXI-attached accelerator** so we can run a *tiny* transformer (llama2.c "stories" 260K–15M param
class, INT8/INT16) — a strong, honest resume story: "custom RV32IM soft-core + AXI4 systolic MAC
accelerator running a quantized language model."

## Reality check on the "LLM"
A full LLM won't fit or run fast. What *is* achievable and impressive:
- Port Andrej Karpathy's **llama2.c** (or a stripped `run.c`) to bare-metal RV32IM.
- The core runs the control/tokenizer/sampling; the **AXI accelerator** does the matmuls
  (the 90%+ of runtime). Weights streamed from DDR3.
- Start with the **260K-param tinystories** model, INT8 quantized. Tokens/sec will be low but real.

## Phases

### Phase 1 — RV32I 5-stage pipeline core (SIM ONLY)  ← we are here
- [x] Project scaffold
- [x] Datapath: IF, ID, EX, MEM, WB
- [x] Full forwarding (EX/MEM, MEM/WB -> EX)
- [x] Load-use hazard stall
- [x] Branch resolve in EX + flush
- [x] Testbench running a generated hex program (sim/tb_top.v + sim/sim_memory.v)
- [x] Self-checking test with a golden Python ISS (sim/gen_test.py -> program.hex)
- [x] Run program.hex through Verilog (Icarus) and confirm *** PASS ***
      — see docs/DESIGN_NOTES.md §3

### Phase 2 — C toolchain + bare-metal runtime
- [x] `riscv32-unknown-elf-gcc` build flow (crt0.S, linker script)
- [x] UART TX/RX (memory-mapped), 16-byte RX FIFO, and C UART driver
- [x] Resident checksummed UART monitor loads and executes RV32I applications
- [x] PC-side C build emits a Tera Term-ready upload stream
- [x] End-to-end serial RX/load/execute simulation
- [ ] Run a larger compute benchmark in sim
- [ ] riscv-tests / riscof compliance (subset)

### Phase 3 — Bring-up on Tang Primer 20K
- [ ] Gowin project, clock (27 MHz osc -> rPLL), reset
- [ ] BRAM for boot ROM + scratch RAM
- [x] UART TX/RX pins, LEDs, button constraints
- [ ] Flash and validate the UART monitor plus uploaded C on physical hardware

### Phase 4 — Add the M extension (mul/div)
- [ ] Multi-cycle multiplier/divider, pipeline stall handshake

### Phase 5 — Memory system for real workloads
- [ ] DDR3 controller via Gowin "DDR3 Memory Interface" IP (128 MB on the Dock)
- [ ] Simple cache or DMA

### Phase 6 — AXI accelerator
- [ ] AXI4-Lite control/status regs (start, done, base ptrs, dims)
- [ ] AXI4 (or stream) data path from DDR3
- [ ] INT8 MAC array (systolic or wide dot-product)
- [ ] Core-driver library, integrate into matmul kernel

### Phase 7 — Run the tiny model
- [ ] Port llama2.c inference, replace matmul with accelerator calls
- [ ] Stream weights, generate tokens over UART

## Layout
```
fpga_riscv/
  rtl/        synthesizable Verilog (core, soc, peripherals, accelerator)
  sim/        testbenches + hex programs
  sw/         C runtime, linker script, example programs, build scripts
  gowin/      Gowin EDA project + constraints (.cst, .sdc)
  docs/       this roadmap + design notes
```
